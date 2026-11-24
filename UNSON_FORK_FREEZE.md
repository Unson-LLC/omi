# Unson-LLC/omi Fork Freeze Notice (Option A — Phase 1)

- **Effective Date:** 2026-11-25
- **Decision Reference:** Item #78 (Operator-approved 2-phase closed-boundary Omi plan for Brainbase Medical Vertical)

## Policy

1. **Upstream tracking is frozen.** Do not merge `BasedHardware/omi:main` into this fork. Stale upstream merge PRs (#13, #16) are closed and non-mobile/scheduled upstream workflows (`guardrail-baseline-pulse.yml`, `desktop_*`, `backend-*`, `gcp_*`, `jit_qa_*`, etc.) are disabled.
2. **Closed-boundary rule (zero third-party cloud).** Audio and transcript payloads must go only to Unson / customer-controlled closed endpoints (`brainbase-omi` Take Cloudflare or Matsu on-prem). Never route audio or transcripts through `api.omi.me` or Plaud.
3. **Phase 1 scope on this fork.** Only surgical stability fixes required for the owner's physical iPhone E2E pilot (PR #9 `HttpPoolManager`, PR #10 crash-safe `drain()` + container path recovery) are accepted on `main`.
4. **Build locality.** Never clone or build this Flutter/iOS repository on `unson-lightsail`. Dart checks run on Public GitHub Actions (`ubuntu-latest`); physical iOS signing and install run single-shot on Mac mini local only.
5. **Phase 2 sunset.** After Phase 1 physical E2E proves the closed boundary and `knowledge_event.v1` bridge, this fork will be archived once the lightweight Unson-owned BLE/WAL client (`sdks/device` protocol, zero Firebase, short-lived leased device auth) ships for Take and Matsu.
