# runtime_contract final review transcript — ff1 budget audit

- Story: `omi-upstream-rebase-cloudflare-isolation`
- Review stage / role: `implementation` / `runtime_contract`
- Reviewed HEAD: `ff1bbfd35b9c26b19796cb591daa07abf09699e9`
- Comparison base: `upstream/main` = `e28f753be6b212b20482719ee325fc62b6e975f2`
- Worktree: `/Users/ksato/workspace/code/.worktrees/omi-worktrees/omi-upstream-rebase-cloudflare-isolation`
- Verdict: `pass` (runtime-contract scope only; this is not PR or release approval)

## Inspection summary

The worktree was clean before inspection and the merge-base of `upstream/main` and
the reviewed HEAD was `e28f753be6b212b20482719ee325fc62b6e975f2`. The full
`upstream/main...HEAD` diff contains 121 paths: 99 localization inputs/generated
outputs, 10 runtime/wiring paths, 6 focused tests, 5 documents, and the
verification Makefile. `git diff --check` passed and the changed-path scan found
no Worker/Workers, iOS, Android, Firebase, environment/secret/credential, or
entitlement path.

The final `ff1bbfd` commit itself changes only
`docs/management/decisions/2026-08-03-budget-override-omi-upstream-rebase-cloudflare-isolation-8e338e4d.md`.
It records a review-budget approval; it does not add a runtime path, configuration,
credential, deployment, or permission. No runtime-contract change was introduced
after the preceding reviewed code state.

## Runtime-contract findings

### Cloudflare transcript boundary

- Configuration is opt-in: a nonblank token and a structurally safe Worker URL are
  both required. HTTPS is accepted; HTTP is accepted only for loopback.
- The API creates only `http.Request('GET', ...)` requests, disables redirects,
  uses bounded timeouts, and reads the list/detail transcript routes only. It has
  no upload, acknowledgement, delete, or write request path.
- Disabled configuration returns no sessions without invoking HTTP. Invalid
  responses, repeated cursors, malformed chunks, failures, and timeouts are
  validated or rendered through safe generic UI copy; bearer tokens are not put in
  the errors.

### Existing Omi UI and zero state

- `ConversationsSectionHeader` preserves the existing disabled Cloudflare/Omi-zero
  outcome (`SizedBox`) and keeps normal daily-summary and Omi headers available.
- A configured Cloudflare entry is additive for the Omi-zero case. The list and
  detail pages distinguish loading, empty, error, retry, and no-transcript states.
- Widget tests cover both configured and disabled/invalid configurations, English
  and Japanese error/semantic labels, and retry replacement; error text does not
  surface the API error.

### WAL adapter boundary

- `NoopSelfHostedWalSyncAdapter` is a standalone interface/adapter. Its only
  observable result is `disabled` or `deferred`; it is not wired into the existing
  WAL reconciler.
- A repository reference scan found no call site that could upload, acknowledge,
  or delete WAL records through this adapter. Environment tests cover disabled,
  malformed, public-HTTP, valid-HTTPS, loopback-HTTP, and sync-flag-off inputs.

## Mandatory lenses

### regression_guard — pass

Focused integration ran on the reviewed HEAD:

```text
make -C .vibepro/verification integration
```

It passed `git diff --check`, required-path and forbidden-path guards, the
localization-memory guard, 42 focused Flutter tests, and six isolated WAL
environment cases. The integration guards would fail if the required Cloudflare
implementation/test surface disappeared or a forbidden deploy/secret/mobile
surface entered the diff. A subsequent:

```text
make -C .vibepro/verification typecheck
```

reported `No issues found!` for the changed app paths and focused tests. This gives
regression evidence for the changed UI, configuration, API parsing, and no-op WAL
contracts; it is not a claim of device or deployed-service behavior.

### path_surface_coverage — pass

Inputs and output surfaces were traced across compile-time configuration, URL
validation, HTTP list/detail parsing, provider error retention, conversations
header fallback, list/detail UI states, localization source/generated outputs,
WAL environment mode, test fixtures, documentation, and verification artifacts.
All new network behavior is contained in the Cloudflare read API. The final budget
document is a decision artifact only. The verification evidence file records
`expected_head_sha`, `current_head_sha`, command before/after SHAs, and clean
worktree digests as `ff1bbfd35b9c26b19796cb591daa07abf09699e9`; no HEAD movement is
recorded during those commands.

## Evidence boundary and residuals

- `e2e` in `.vibepro/verification/Makefile` is a hermetic compatibility alias for
  integration. It is useful regression evidence, but is not represented as real
  device, accessibility, or deployed Worker E2E proof.
- iPhone hardware, VoiceOver, and a deployed Cloudflare Worker were not inspected
  in this review and remain `未確認`.
- The upstream-derived default `flutter gen-l10n` untranslated warnings (47 locales
  × 4 keys) remain a known warning boundary. This review neither suppresses them
  nor upgrades them to runtime proof.
- The VibePro verification evidence is HEAD-bound to `ff1bbfd`; its non-blocking
  `managed_worktree_locality` and unparsed-run-count warnings are retained rather
  than silently treated as proof of a managed-worktree lifecycle.

## Judgment delta

Initial concern: the final budget-approval commit could have broadened the runtime
or weakened release evidence. Final conclusion: it is documentation-only, while
the current-HEAD verification artifact and an independent re-run confirm the
configuration-gated, GET-only Cloudflare contract, preserved existing UI fallback,
and no-op WAL boundary. No runtime-contract finding requires changes.

## Inspected inputs

- `app/lib/main.dart`
- `app/lib/pages/conversations/conversations_page.dart`
- `app/lib/pages/conversations/widgets/conversations_section_header.dart`
- `app/lib/self_hosted/cloudflare/`
- `app/lib/self_hosted/sync/self_hosted_wal_sync_adapter.dart`
- `app/test/self_hosted/cloudflare/`
- `app/test/self_hosted/sync/`
- `.vibepro/verification/Makefile`
- `.vibepro/pr/omi-upstream-rebase-cloudflare-isolation/verification-evidence.json`
- `docs/management/decisions/2026-08-03-budget-override-omi-upstream-rebase-cloudflare-isolation-8e338e4d.md`
