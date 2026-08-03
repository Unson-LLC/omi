# human_usability review transcript — ff1 budget audit

## Result

`pass`

The current frozen HEAD satisfies the preview `human_usability` role. The
Cloudflare list/detail surface exposes understandable loading, empty, error,
retry, list metadata, and detail states without surfacing raw API errors. The
budget decision document is an audit artifact only and does not change the
runtime or user-visible surface. This role verdict does not assert global PR
readiness.

## Frozen scope and repository state

- Repository: `/Users/ksato/workspace/code/.worktrees/omi-worktrees/omi-upstream-rebase-cloudflare-isolation`
- Reviewed HEAD: `ff1bbfd35b9c26b19796cb591daa07abf09699e9`
- `upstream/main`: `e28f753be6b212b20482719ee325fc62b6e975f2`
- Merge base: `e28f753be6b212b20482719ee325fc62b6e975f2`
- Ahead/behind: 26/0
- Worktree: clean before the transcript was authored
- `git diff --check upstream/main...HEAD`: pass
- Diff: 121 files, 2,553 insertions, 74 deletions

The direct delta from `b458de453` to the reviewed HEAD is one added file:
`docs/management/decisions/2026-08-03-budget-override-omi-upstream-rebase-cloudflare-isolation-8e338e4d.md`.
It records a human-approved review-budget digest and explicitly excludes
waivers, test skipping, device/deploy evidence elevation, and product-scope
expansion. It contains no runtime configuration or UI behavior.

## Mandatory lens: regression_guard

Status: `pass`

- Configured Cloudflare remains reachable when Omi has zero conversations;
  disabled or invalid configuration leaves the prior Omi zero state unchanged
  and hides the Cloudflare entry.
- Existing Omi conversation and Daily Recap headers remain present when their
  pre-existing states require them.
- List and detail failures remain scoped to the Cloudflare pages and provide a
  retry action. The UI renders the ARB-backed generic error and does not render
  `CloudflareTranscriptApiException` text or response details.
- List rows show status, localized recorded/created time when present, and
  localized character count. The same metadata is included in an explicit
  session semantics label; list rows are marked as buttons.
- Detail preserves the detail-specific empty-transcript message and orders
  transcript chunks through the validated model path.
- The API remains bearer-authenticated `GET` only with redirects disabled;
  disabled configuration sends no request. The WAL seam remains a no-op that
  returns only `disabled` or `deferred`.
- Widget fixtures would fail the pre-fix behaviors: they assert that raw API
  errors are absent, English and Japanese localized errors/retry text are
  present, metadata text is labeled, semantics includes the session identity
  and metadata, button semantics exists, and retry replaces the error with the
  transcript.
- The current budget record cannot regress these behaviors because the final
  HEAD delta after the preceding product commit is documentation-only.

## Mandatory lens: path_surface_coverage

Status: `pass`

Every path in `git diff --name-only upstream/main...HEAD` was classified; the
classifier totals 121 and has zero unknown paths:

- 49 ARB sources: every `app/lib/l10n/app_*.arb`
- 50 generated localization files: every
  `app/lib/l10n/app_localizations*.dart`
- 10 product source files:
  - `app/lib/main.dart`
  - `app/lib/pages/conversations/conversations_page.dart`
  - `app/lib/pages/conversations/widgets/conversations_section_header.dart`
  - `app/lib/self_hosted/cloudflare/cloudflare_transcript_api.dart`
  - `app/lib/self_hosted/cloudflare/cloudflare_transcript_configuration.dart`
  - `app/lib/self_hosted/cloudflare/cloudflare_transcript_exception.dart`
  - `app/lib/self_hosted/cloudflare/cloudflare_transcript_models.dart`
  - `app/lib/self_hosted/cloudflare/cloudflare_transcript_provider.dart`
  - `app/lib/self_hosted/cloudflare/cloudflare_transcripts_page.dart`
  - `app/lib/self_hosted/sync/self_hosted_wal_sync_adapter.dart`
- 6 focused tests:
  - `app/test/self_hosted/cloudflare/cloudflare_transcript_api_test.dart`
  - `app/test/self_hosted/cloudflare/cloudflare_transcript_configuration_test.dart`
  - `app/test/self_hosted/cloudflare/cloudflare_transcript_provider_test.dart`
  - `app/test/self_hosted/cloudflare/cloudflare_transcripts_page_test.dart`
  - `app/test/self_hosted/sync/self_hosted_wal_sync_adapter_environment_test.dart`
  - `app/test/self_hosted/sync/self_hosted_wal_sync_adapter_test.dart`
- 5 documentation/audit paths: Story, Spec, ADR, local-overlay runbook, and the
  current budget-decision record
- 1 verification contract: `.vibepro/verification/Makefile`

The inspected inputs cover configuration, API and model parsing, provider
state, list/detail UI, legacy Omi header fallback, generated localization,
tests, verification/report surfaces, operational documentation, and the budget
audit record. Suppressed raw errors are replaced with a visible localized error
and retry rather than disappearing silently.

## Human usability inspection

- `CloudflareTranscriptsPage` has distinct initial loading, empty, error/retry,
  and populated list states.
- `CloudflareTranscriptDetailPage` has distinct loading, error/retry, empty
  transcript, metadata, and transcript-content states.
- `ConversationsSectionHeader` exposes a tooltip/semantic label for the
  Cloudflare entry and does not remove the legacy header states.
- `_sessionMetadata` prefixes raw Worker status with localized `statusLabel`,
  formats date/time with the active locale, and uses localized character-count
  formatting. Raw status remains source data; it is no longer an unlabeled
  value.
- `_SessionTile` combines session identity and metadata in a localized
  semantics string and excludes duplicate child semantics.
- Widget tests exercise the complete Omi-zero-to-list-to-detail path, disabled
  and invalid-config fallback, Omi and Daily Recap preservation, list/detail
  empty states, English/Japanese localized failures, visible metadata,
  semantics metadata, and detail retry.

The existing visual comparison is strict-HEAD stale in `pr-prepare.json`, but
the user-facing page source and its widget-test source are byte-identical to the
previous reviewed visual binding (`ae313b...` and `0e5ea2...`). This review does
not elevate that static comparison to current physical-device or VoiceOver
evidence.

## Localization generation audit

- ARB source count: 49
- Generated Dart count: 50
- `cloudflareTranscriptListEmptyMessage`: present in 49/49 ARBs and 50/50
  generated files
- `cloudflareTranscriptLoadError`: present in 49/49 ARBs and 50/50 generated
  files
- `cloudflareTranscriptSessionSemantics`: present in 49/49 ARBs and 50/50
  generated files
- All 49 session-semantics values are non-empty and retain both `{sessionId}`
  and `{metadata}` placeholders.
- The three Cloudflare keys have 48, 49, and 48 distinct localized values,
  respectively; they are not silently inherited as one English string.

An isolated archive of this exact HEAD was generated outside the repository.
After exact Flutter `3.41.9` `flutter pub get --offline`, default
`flutter gen-l10n` produced 50 generated files and all 50 were byte-identical to
the reviewed HEAD.

Default generation still emits four untranslated-message warnings in each of
47 locales for `alwaysInContext`, `baselineMemory`, `pinAsBaseline`, and
`unpinAsBaseline`. Those keys exist only in `app_en.arb` and `app_zh.arb` both
at current HEAD and at `upstream/main`; therefore the 47 locales x 4 warning
baseline is upstream-derived and remains explicitly unresolved. It is not
reported as zero warnings and is not attributed to the Cloudflare strings.

## Current verification evidence

`.vibepro/pr/omi-upstream-rebase-cloudflare-isolation/verification-evidence.json`
was updated at `2026-08-03T00:52:35.986Z`. Its four commands are `pass`, have
`runner_direct` provenance, and bind both git context and strict content binding
to `ff1bbfd35b9c26b19796cb591daa07abf09699e9`.

- Integration: rerun at `2026-08-03T00:50:26.633Z`, output SHA-256
  `faba1164ade21d859acd1f22becef9ddb8c4083de222be3c203e3c8fccef855b`
- Unit: output SHA-256
  `5621f33f8ba6dd51a912208c78f09dd209242d92ee44a0cd1f4b4ab5d8783605`
- Typecheck: output SHA-256
  `9ca7ac321d1b533af6250fb66fd34719614fadcc0439905ed21e7948fae2eb1a`
- E2E-named compatibility alias: rerun at `2026-08-03T00:52:35.368Z`, output
  SHA-256
  `ac6d557846553b440602317a0792d3e92cc827f533a1827a9722a0894196bc28`

The unit/integration logs show 42 focused tests followed by six passing WAL
environment probes. Typecheck reports `No issues found!`. All raw runs record no
timeout, output truncation, tree mutation, HEAD movement, or worktree change.
VibePro warns that counts were not parsed automatically, so the counts above
come from direct log inspection rather than an aggregate count field.

The Makefile explicitly defines `e2e` as a compatibility alias of hermetic
integration evidence. Its success is not treated as an end-to-end device or
deployed-runtime result.

## Evidence boundaries retained

- Physical iPhone behavior: unverified
- VoiceOver behavior: unverified
- Deployed/live Cloudflare Worker: unverified
- Production telemetry: unverified
- Recording/upload/ack/delete flow: outside this read-only slice and unverified
- HTTP 200, Flutter build, analyzer success, and hermetic tests: not promoted to
  E2E proof
- Global PR readiness: `pr-prepare.json` remains
  `overall_status=needs_verification` and `ready_for_pr_create=false`; this
  human-usability verdict does not override other stale or unresolved gates

## Findings

None.

## Judgment delta

- Initial concern: the final budget commit might stale or alter the
  user-visible surface. Final judgment: it adds only a tracked review-budget
  audit document and changes no runtime/UI path.
- Initial concern: all-locales additions or the Memories cleanup might make
  generated localization non-reproducible. Final judgment: exact Flutter 3.41.9
  regeneration after package resolution is 50/50 byte-identical; the remaining
  47 locales x 4 warnings exactly match the upstream baseline.
- Initial concern: passing automated evidence might overstate human-perceived
  readiness. Final judgment: source and widget-test evidence supports this
  preview role, while physical iPhone, VoiceOver, deployed Worker, and true E2E
  remain explicitly unverified.

## Review mutation boundary

No product, test, documentation, configuration, or git state was changed. The
only authored artifact is this requested ignored review transcript.
