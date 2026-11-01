#!/usr/bin/env python3
"""Keep at most N images (tags) per project in the Nexus Docker repository.

Nexus OSS cleanup policies can only filter by age / last download / name regex; they cannot say "keep the
newest N". This script does exactly that: for every image name (= project, e.g. x-ai/expat8-backend) it
keeps the N most recently pushed tags and deletes the rest through the Nexus REST API. Then it runs
Nexus' own "Docker - Delete unused manifests and images" and "Admin - Compact blob store" tasks so the
disk space is actually released.

Deleting a tag does not free its layers: Nexus keeps the layer blobs forever, so without a second step the
disk fills with layers nobody references (tens of GB were found this way). After the tag cleanup the script
therefore also reclaims those orphans, safely:
  1. read every manifest of every tag through the registry API -> the set of layers/configs still in use;
  2. move blobs of the Docker repo that no manifest references (and that are older than --orphan-min-age-hours,
     so an upload in flight is never touched) into /nexus-data/quarantine/<date>/ inside the Nexus container;
  3. verify every referenced layer is still served by the registry; if anything is missing, put everything back;
  4. delete quarantine folders older than --quarantine-days (default 7) for good.
Skipped entirely (nothing is moved) if any manifest could not be read.

Never deleted, whatever their age:
  * the floating `latest` tag (it does not count towards N);
  * tags used by containers currently running on this host (so a rollback target never vanishes
    from under a live service).

Dry run by default: nothing is deleted without --apply.

    nexus_prune_images.py                # show the plan
    nexus_prune_images.py --apply        # delete, then GC + compact
    nexus_prune_images.py --keep 3 --repo docker --nexus http://10.113.213.9:18081

Credentials come from the existing `docker login` of the registry host in ~/.docker/config.json
(an account with permission to delete components); nothing secret is stored in this file.
"""
import argparse
import base64
import collections
import json
import pathlib
import subprocess
import sys
import re
import time
import urllib.error
import urllib.request

REGISTRY_HOST = "docker.x51.vn"
KEEP_ALWAYS = {"latest"}


def load_auth(host):
    config = json.loads((pathlib.Path.home() / ".docker/config.json").read_text())
    token = config["auths"][host]["auth"]
    base64.b64decode(token)  # fail early if the entry is malformed
    return token


class Nexus:
    def __init__(self, base, auth):
        self.base = base.rstrip("/")
        self.auth = auth

    def call(self, method, path, expect_json=True):
        request = urllib.request.Request(
            self.base + path, method=method, headers={"Authorization": "Basic " + self.auth}
        )
        with urllib.request.urlopen(request, timeout=120) as response:
            body = response.read()
        return json.loads(body) if expect_json and body else None

    def components(self, repository):
        items, token = [], None
        while True:
            suffix = f"&continuationToken={token}" if token else ""
            page = self.call("GET", f"/service/rest/v1/components?repository={repository}{suffix}")
            items += page["items"]
            token = page.get("continuationToken")
            if not token:
                return items

    def delete_component(self, component_id):
        self.call("DELETE", f"/service/rest/v1/components/{component_id}", expect_json=False)

    def task_by_type(self, task_type):
        items = self.call("GET", f"/service/rest/v1/tasks?type={task_type}")["items"]
        return items[0] if items else None

    def run_task_and_wait(self, task_type, timeout_seconds):
        task = self.task_by_type(task_type)
        if task is None:
            print(f"task {task_type}: not configured, skipped")
            return
        self.call("POST", f"/service/rest/v1/tasks/{task['id']}/run", expect_json=False)
        deadline = time.time() + timeout_seconds
        time.sleep(3)
        while time.time() < deadline:
            current = self.task_by_type(task_type)
            if current["currentState"] == "WAITING":
                print(f"task {task['name']}: {current['lastRunResult']}")
                return
            time.sleep(5)
        print(f"task {task['name']}: still running after {timeout_seconds}s (it will finish on its own)")


def running_tags(host):
    """`{image name: {tags}}` of containers running on this host that come from the registry."""
    try:
        images = subprocess.run(
            ["docker", "ps", "--format", "{{.Image}}"], capture_output=True, text=True, check=True
        ).stdout.split()
    except (OSError, subprocess.CalledProcessError):
        return {}
    protected = collections.defaultdict(set)
    for image in images:
        if image.startswith(host + "/") and ":" in image.rsplit("/", 1)[-1]:
            name, tag = image[len(host) + 1 :].rsplit(":", 1)
            protected[name].add(tag)
    return protected


def plan(components, keep, protected):
    by_name = collections.defaultdict(list)
    for component in components:
        pushed = max((asset.get("lastModified") or "" for asset in component.get("assets", [])), default="")
        by_name[component["name"]].append((pushed, component["version"], component["id"]))
    deletions = []
    for name, rows in sorted(by_name.items()):
        rows.sort(reverse=True)  # newest push first, tag name breaks ties
        candidates = [row for row in rows if row[1] not in KEEP_ALWAYS]
        for pushed, tag, component_id in candidates[keep:]:
            if tag in protected.get(name, set()):
                print(f"keep   {name}:{tag}  (used by a running container)")
                continue
            deletions.append((name, tag, pushed, component_id))
    return by_name, deletions


BLOB_ROOT = "/nexus-data/blobs/default/content"
QUARANTINE_ROOT = "/nexus-data/quarantine"
LAYER_NAME = re.compile(r"/blobs/sha256:([0-9a-f]{64})$")
ACCEPT = ", ".join(
    [
        "application/vnd.docker.distribution.manifest.v2+json",
        "application/vnd.docker.distribution.manifest.list.v2+json",
        "application/vnd.oci.image.manifest.v1+json",
        "application/vnd.oci.image.index.v1+json",
    ]
)


class Registry:
    """The Docker v2 API of the Nexus docker connector (HTTP port of the repository)."""

    def __init__(self, base, auth):
        self.base = base.rstrip("/")
        self.auth = auth

    def request(self, method, path, accept=None):
        headers = {"Authorization": "Basic " + self.auth}
        if accept:
            headers["Accept"] = accept
        return urllib.request.urlopen(
            urllib.request.Request(self.base + path, method=method, headers=headers), timeout=120
        )

    def get_json(self, path, accept=None):
        with self.request("GET", path, accept) as response:
            return json.load(response)

    def has_blob(self, repository, digest):
        try:
            with self.request("HEAD", f"/v2/{repository}/blobs/{digest}"):
                return True
        except urllib.error.HTTPError:
            return False

    def referenced_digests(self):
        """`{digest: repository}` of every layer/config/child manifest any tag points to, or None on error."""
        referenced, failed = {}, []

        def walk(repository, reference):
            try:
                manifest = self.get_json(f"/v2/{repository}/manifests/{reference}", ACCEPT)
            except (urllib.error.URLError, ValueError) as error:
                failed.append(f"{repository}:{reference} ({error})")
                return
            for child in manifest.get("manifests", []):  # image index / manifest list
                referenced[child["digest"]] = repository
                walk(repository, child["digest"])
            if "config" in manifest:
                referenced[manifest["config"]["digest"]] = repository
            for layer in manifest.get("layers", []):
                referenced[layer["digest"]] = repository

        for repository in self.get_json("/v2/_catalog?n=10000")["repositories"]:
            for tag in self.get_json(f"/v2/{repository}/tags/list").get("tags") or []:
                walk(repository, tag)
        for message in failed:
            print(f"cannot read manifest {message}", file=sys.stderr)
        return None if failed else referenced


def in_nexus(command, stdin=None):
    """Runs a shell command inside the Nexus container (the blob store is only reachable from there)."""
    return subprocess.run(
        ["docker", "exec", "-i", "nexus", "sh", "-c", command],
        input=stdin, capture_output=True, text=True, check=True,
    ).stdout


def unreferenced_layers(referenced_digests, min_age_seconds):
    """`[(path relative to the blob root, size)]` of layer blobs no manifest uses, old enough to be safe."""
    listing = in_nexus(
        f"cd {BLOB_ROOT} && find . -name '*.properties' | xargs grep -H '^@BlobStore.blob-name='"
    )
    candidates = []
    for line in listing.splitlines():
        path, _, name = line.partition(":@BlobStore.blob-name=")
        match = LAYER_NAME.search(name.replace("\\:", ":"))
        if match and "sha256:" + match.group(1) not in referenced_digests:
            candidates.append(path[2:-len(".properties")])  # strip "./" and ".properties"
    if not candidates:
        return []
    now = time.time()
    found = []
    for start in range(0, len(candidates), 400):
        chunk = candidates[start : start + 400]
        stat = in_nexus(f"cd {BLOB_ROOT} && stat -c '%Y %s %n' " + " ".join(f"'{p}.bytes'" for p in chunk))
        for row in stat.splitlines():
            modified, size, name = row.split(" ", 2)
            if now - int(modified) >= min_age_seconds:
                found.append((name[: -len(".bytes")], int(size)))
    return found


def move_blobs(paths, source_root, target_root):
    """Moves `<path>.bytes` + `<path>.properties` for each relative path, keeping the folder layout."""
    script = (
        'while read p; do for e in bytes properties; do '
        f'mkdir -p "{target_root}/$(dirname "$p")" && mv "{source_root}/$p.$e" "{target_root}/$p.$e"; '
        "done; done"
    )
    in_nexus(script, stdin="\n".join(paths) + "\n")


def reclaim_orphan_layers(registry, args):
    referenced = registry.referenced_digests()
    if not referenced:
        print("orphan layers: skipped (a manifest could not be read, or the registry is empty)")
        return 1
    orphans = unreferenced_layers(referenced, args.orphan_min_age_hours * 3600)
    gigabytes = sum(size for _, size in orphans) / 1e9
    print(f"{len(referenced)} layers in use; {len(orphans)} unreferenced layers ({gigabytes:.1f} GB) old enough to reclaim")
    if not orphans or not args.apply:
        return 0
    stamp = time.strftime("%Y%m%d-%H%M%S")
    target = f"{QUARANTINE_ROOT}/{stamp}"
    paths = [path for path, _ in orphans]
    move_blobs(paths, BLOB_ROOT, target)
    missing = [d for d, repository in referenced.items() if not registry.has_blob(repository, d)]
    if missing:
        print(f"FAILED: {len(missing)} layers in use are no longer served; restoring everything", file=sys.stderr)
        move_blobs(paths, target, BLOB_ROOT)
        return 1
    print(f"moved {len(orphans)} layers ({gigabytes:.1f} GB) to {target}; all {len(referenced)} layers in use still served")
    return 0


def purge_quarantine(days):
    removed = in_nexus(
        f"mkdir -p {QUARANTINE_ROOT} && find {QUARANTINE_ROOT} -mindepth 1 -maxdepth 1 -type d -mtime +{days} "
        "| while read d; do echo $d; rm -rf \"$d\"; done"
    )
    for folder in removed.split():
        print(f"purged old quarantine {folder}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--nexus", default="http://10.113.213.9:18081")
    parser.add_argument("--repo", default="docker")
    parser.add_argument("--keep", type=int, default=5, help="tags to keep per image name (default 5)")
    parser.add_argument("--apply", action="store_true", help="actually delete (default: dry run)")
    parser.add_argument("--gc-timeout", type=int, default=1800, help="seconds to wait for GC / compaction")
    parser.add_argument("--registry", default="http://10.113.213.9:18093", help="docker connector (v2 API) of the repo")
    parser.add_argument("--no-orphans", action="store_true", help="skip reclaiming unreferenced layers")
    parser.add_argument("--orphan-min-age-hours", type=int, default=24)
    parser.add_argument("--quarantine-days", type=int, default=7)
    args = parser.parse_args()
    if args.keep < 1:
        sys.exit("--keep must be at least 1")

    auth = load_auth(REGISTRY_HOST)
    nexus = Nexus(args.nexus, auth)
    components = nexus.components(args.repo)
    by_name, deletions = plan(components, args.keep, running_tags(REGISTRY_HOST))
    print(f"{len(components)} images in '{args.repo}', {len(by_name)} projects, keep {args.keep} per project")
    for name, tag, pushed, _ in deletions:
        print(f"delete {name}:{tag}  (pushed {pushed[:19]})")
    print(f"{len(deletions)} to delete" + ("" if args.apply else "  [dry run, nothing changed; use --apply]"))
    failures = 0
    if args.apply and deletions:
        for name, tag, _, component_id in deletions:
            try:
                nexus.delete_component(component_id)
                print(f"deleted {name}:{tag}")
            except urllib.error.URLError as error:
                failures += 1
                print(f"FAILED  {name}:{tag}: {error}", file=sys.stderr)
        # Deleting a tag only unlinks it: Nexus frees the manifests in this task, the layers in the step below.
        nexus.run_task_and_wait("repository.docker.gc", args.gc_timeout)
    if not args.no_orphans:
        failures += reclaim_orphan_layers(Registry(args.registry, auth), args)
        if args.apply:
            purge_quarantine(args.quarantine_days)
    if args.apply:
        nexus.run_task_and_wait("blobstore.compact", args.gc_timeout)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
