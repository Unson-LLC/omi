# architecture boundary preflight — rebased strict HEAD `52ff0989`

- Story: `omi-upstream-rebase-cloudflare-isolation`
- Stage / role: `architecture_spec` / `architecture_boundary`
- Verdict: `PASS` for the architecture-boundary review only
- Reviewed HEAD: `52ff0989b7476dc8e624f0c2e3fbb58115addf46`
- Current upstream / merge-base: `275a4886291a6527de9850b470835bf9cad9c37b`
- Worktree: `/Users/ksato/workspace/code/.worktrees/omi-worktrees/omi-upstream-rebase-cloudflare-isolation`

This verdict is not PR-ready or release approval. The current VibePro PR gate
sidecar remains `needs_verification` / `ready_for_pr_create=false`; its unresolved
lifecycle and visual/release evidence must not be silently treated as cleared by
this focused architecture review.

## Rebase and all-path inspection

The worktree was clean, and `git merge-base upstream/main HEAD` equals the current
upstream SHA above. The `upstream/main...HEAD` diff has 121 paths: 99 l10n
ARB/generated files, 10 runtime/wiring files, 6 focused tests, 5 documentation
files, and 1 verification Makefile. `git diff --check` passed. Required-path,
l10n-memory, and forbidden-path guards passed in the integration target; no changed
path is a Worker/Workers, iOS, Android, Firebase, env/secret/credential, or
entitlement file.

The four incoming upstream commits are confined to
`desktop/macos/Desktop/Sources/` and `desktop/macos/Desktop/Tests/`:

1. `81a9fe595`: Floating Bar notification-preview policy/settings/tests.
2. `3c2edc3fd`: the same desktop notification policy/service/tests.
3. `377edf7e2`: desktop `DefaultsKey` and shortcut settings.
4. `275a48862`: desktop `DefaultsKey` merge resolution.

Their changed-path set has no intersection with this branch's 121 paths. A direct
comparison from the prior strict reviewed object `ff1bbfd...` to `52ff0989...` also
has no change in `app/lib/self_hosted`, conversations wiring, `main.dart`, or the
focused self-hosted tests. The rebase therefore introduces no new conflict or
behavioral coupling into this slice.

## Architecture-boundary result

### Existing database state

No branch path changes a schema, migration, persistence model, database API, or
existing WAL implementation. `main.dart` adds only the Cloudflare provider to the
composition root. The existing upload reconciler text remains upstream-owned and
is not touched by the branch diff. The self-hosted adapter has no reference from
`LocalWalSyncImpl` or the existing WAL reconciler.

### Read-only Cloudflare boundary

`CloudflareTranscriptConfiguration` requires a safe URL and nonblank token; missing
or invalid configuration disables the feature without HTTP. The only new HTTP
request construction is `http.Request('GET', uri)`, with redirects disabled,
timeouts, bearer header handling, fail-closed JSON/shape validation, and safe
exceptions. List and detail routes are reads only. No `POST`, `PUT`, `PATCH`,
upload, ack, or deletion path is introduced.

### No-op WAL adapter isolation

`NoopSelfHostedWalSyncAdapter.schedule()` validates only a nonempty ID and returns
`disabled` or `deferred`. It does not own a file, invoke HTTP, mutate the existing
WAL state machine, upload, acknowledge, or delete. Reference inspection finds the
adapter only in its own source and focused tests, not in `LocalWalSyncImpl` or the
existing reconciler.

### Documents and local configuration boundary

Story, Spec, ADR, and operational overlay agree on the same slice: config-gated
Cloudflare list/detail reads plus a future-facing no-op adapter seam. They retain
Firebase, signing, entitlements, Worker deployment, and secret values outside the
tracked product diff. The 49 ARBs and 50 generated l10n outputs are one generated
surface, not an independent runtime or database lane.

## Mandatory lenses

### regression_guard — PASS

At `52ff0989`, both commands passed:

```text
make -C .vibepro/verification integration
make -C .vibepro/verification typecheck
```

Integration ran the strict current-base diff guards, 42 focused Cloudflare/WAL
Flutter tests, and six compile-time WAL environment cases. It covers disabled-no-
request, HTTPS/loopback URL policy, pagination and malformed response rejection,
safe errors, existing Omi header fallback, and deferred/disabled adapter outcomes.
Typecheck reported `No issues found!` for the changed Flutter surfaces.

### path_surface_coverage — PASS

The inspected paths cover input defines, configuration validation, provider
composition, conversations entry/fallback, list/detail outputs and localized
errors, HTTP contract parsing, the standalone WAL seam, focused fixtures, generated
l10n, docs/runbook, verification guards, and the four rebased upstream desktop
paths. Disabled, invalid, network-error, malformed-response, Omi-zero, and
environment branches are explicit rather than silently suppressed.

## Evidence boundaries and residuals

- Physical iPhone, VoiceOver, deployed Cloudflare Worker, and production telemetry
  remain `未確認`; hermetic integration and its `e2e` compatibility alias do not
  prove them.
- The default `flutter gen-l10n` upstream-origin warning boundary (47 locales × 4
  keys) remains recorded and is neither suppressed nor treated as runtime proof.
- `.vibepro/pr/.../verification-evidence.json` is current-HEAD bound to `52ff0989`
  for unit, e2e alias, integration, and typecheck. Its managed-worktree locality
  and unparsed-run-count warnings remain visible, rather than being converted into
  an architecture finding or a release claim.

## Judgment delta

Initial concern: the four new upstream commits might touch database, Omi UI, or
notification dependencies in a way that bypasses the self-hosted isolation.
Conclusion: their paths are desktop notification-preview settings only and have no
intersection with the branch. Current-HEAD integration/typecheck and direct source
inspection preserve database state, the configuration-gated GET-only Cloudflare
adapter, and the disconnected no-op WAL seam. No architecture-boundary change is
required.
