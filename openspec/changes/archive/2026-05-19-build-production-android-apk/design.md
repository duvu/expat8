## Context

The project already supports Android release builds and signed Play Store bundles. A release APK also exists in practice, but the release contract does not explicitly promise it as a first-class deliverable. That makes sideload and internal distribution flows easy to overlook.

This change formalizes the APK as a production artifact while keeping the bundle path unchanged.

## Goals / Non-Goals

**Goals:**
- Make signed production APK output an explicit release artifact.
- Preserve the existing release bundle path for Play Console submissions.
- Keep release signing and environment define requirements aligned across APK and AAB builds.
- Ensure release verification covers installability on emulator/device.

**Non-Goals:**
- Changing Android package identity or signing key management.
- Changing app runtime logic, API behavior, or backend contracts.
- Reworking the release keystore process.

## Decisions

- Treat APK and AAB as parallel release outputs.
  - Rationale: Play Store still wants a bundle, but sideloading and internal QA benefit from a signed APK.
  - Alternative considered: make APK only a debug-side artifact; rejected because production distribution needs a signed release build.

- Keep the same `--dart-define` inputs for both release outputs.
  - Rationale: release APK and AAB must compile the same binary configuration to avoid environment drift.
  - Alternative considered: separate APK-specific defines; rejected because it increases maintenance and risk.

- Reuse the existing operator-managed release keystore for both outputs.
  - Rationale: signing behavior should remain uniform and auditable.
  - Alternative considered: a separate APK signing key; rejected because it adds unnecessary operational overhead.

## Risks / Trade-offs

- [Release command confusion] → Operators may not know which build to use; mitigate with explicit release docs and task checklist updates.
- [Artifact drift] → APK and AAB could be built from different environment values if commands diverge; mitigate by documenting the same required `--dart-define` set for both.
- [Installability regressions] → A release APK can still fail to install on target devices; mitigate with an emulator/device smoke check as part of verification.
