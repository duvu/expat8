# Copilot Instructions

## Expat8 Backend Deploy Workflow (Z440)

When the user asks to deploy `expat8-backend`, always use this exact sequence:

1. Build image from repository backend source:
   - `docker build -t docker.x51.vn/x-ai/expat8-backend:<TAG> backend`
2. Push image to registry:
   - `docker push docker.x51.vn/x-ai/expat8-backend:<TAG>`
3. Update deploy stack file:
   - `~/deployment/worker-z440/docker-compose.yml`
   - Set `expat8-backend` image to the new tag.
4. Redeploy from deployment directory (not local repo compose):
   - `cd ~/deployment/worker-z440`
   - `docker compose up -d --force-recreate expat8-backend`
5. Verify:
   - `docker compose ps expat8-backend`
   - `curl -i -sS http://10.113.213.9:18787/health | head -n 5`

## Important

- Do **not** treat local compose in the source repo as production deploy.
- Do **not** stop after local `expat8-backend-1` is healthy; deployment target is `expat8-backend` in `~/deployment/worker-z440`.
- Prefer timestamp tags in format `YYYYMMDD.HHMM`.