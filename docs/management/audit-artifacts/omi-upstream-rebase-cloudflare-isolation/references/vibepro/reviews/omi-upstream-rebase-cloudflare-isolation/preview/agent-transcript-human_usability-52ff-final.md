# Human usability review transcript — current HEAD final

- Story: `omi-upstream-rebase-cloudflare-isolation`
- Stage / role: `preview / human_usability`
- Reviewer model: `gpt-5.6-terra` / high
- Frozen HEAD: `52ff0989b7476dc8e624f0c2e3fbb58115addf46`
- Base: `upstream/main@275a4886291a6527de9850b470835bf9cad9c37b`
- Result: `NEEDS_CHANGES`
- Product-code changes made by reviewer: none

## Decision

The current Flutter widget implementation and focused tests support localized,
self-describing list/detail/error states. All Cloudflare localization keys are
complete and generated output is byte-stable. The supplied screenshot evidence,
however, does not depict that current widget implementation and has no recorded
flow provenance. It therefore cannot satisfy the requested widget-and-screenshot
human-usability review. The role remains `NEEDS_CHANGES` until screenshots are
captured from the current Flutter widget/harness and bound to the flow that made
them.

This role decision is separate from global PR readiness. At review time,
`pr-prepare.json` reports `overall_status=needs_verification` and
`ready_for_pr_create=false`; the previous `ff1bbfd35b9c...` human-usability
result is stale against this frozen HEAD.

## Frozen git state and changed-path coverage

Initial read-only checks:

- `git rev-parse HEAD` = `52ff0989b7476dc8e624f0c2e3fbb58115addf46`
- `git rev-parse upstream/main` = `275a4886291a6527de9850b470835bf9cad9c37b`
- merge-base = the same upstream SHA
- `git diff --check upstream/main...HEAD` = clean
- `git status --short --untracked-files=all` = empty
- diff = 121 files, 2,553 insertions, 74 deletions

All 121 paths were classified and inspected:

| Surface | Count | Audit |
|---|---:|---|
| ARB localization inputs | 49 | JSON comparison against upstream plus key/value/placeholder checks |
| Generated localization Dart | 50 | three-key coverage in every file plus isolated byte comparison |
| Product Dart | 10 | wiring, section entry, list/detail states, API/provider/model/configuration, no-op WAL seam |
| Focused tests | 6 | Cloudflare API/config/provider/widget and WAL no-op/environment boundaries |
| Story/spec/ADR/runbook/budget decision | 5 | scope, acceptance, rollback, evidence boundary, budget-only authorization |
| VibePro verification Makefile | 1 | strict diff inventory, targeted tests, analyzer, E2E compatibility alias |
| Unknown/unclassified | 0 | none |

The 10 product paths are `app/lib/main.dart`, the Conversations page and section
header, six files under `app/lib/self_hosted/cloudflare/`, the Cloudflare page,
and `app/lib/self_hosted/sync/self_hosted_wal_sync_adapter.dart`. The six test
paths cover the four Cloudflare units/widgets and two WAL adapter probes. The
budget decision is review-budget authority only and explicitly does not waive
tests or elevate device/deploy evidence.

## Widget-level usability and accessibility inspection

The current source in
`app/lib/self_hosted/cloudflare/cloudflare_transcripts_page.dart` provides:

- initial loading progress;
- localized list empty state;
- populated, pull-to-refresh list;
- localized list/detail error copy and localized Retry action;
- no presentation of `provider.error` or raw API exception text;
- visible session id and metadata;
- visible metadata formatted as localized `Status: <status>`, optional localized
  date/time, and localized character count;
- a button Semantics node whose localized label includes session id and metadata,
  with child semantics excluded to avoid duplicate announcements;
- detail loading/error/no-transcript states, visible metadata, a localized
  metadata Semantics label, selectable transcript text, and retry recovery.

`ConversationsSectionHeader` gives the opt-in Cloudflare entry a localized
tooltip, retains it for a configured Omi-zero state, hides it for disabled or
invalid configuration, and preserves the existing Conversations/Daily Recaps
headers. The focused widget tests exercise English and Japanese list/detail
errors, raw-error exclusion, visible and semantic metadata, button semantics,
empty states, disabled/invalid entry behavior, Omi-zero navigation, and retry.

Physical VoiceOver behavior is not inferred from these semantics tests.

## Finding 1 — current visual residual does not depict the current widget

Severity: high evidence-integrity / review blocker.

`.vibepro/qa/omi-cloudflare-current/visual-residual.json` is bound to this HEAD
and reports four compared probes at 0% MAE, but its source has both
`flow_run_id=null` and `flow_verification_json=null`. Each `current` PNG is
byte-identical to its baseline PNG.

Direct inspection shows material contradictions with the current widget and
tests:

- `cloudflare-list.png` displays `transcribed · 28`; current source renders
  `Status: transcribed · 28 characters` in English.
- `cloudflare-detail.png` displays only transcript paragraphs; current source
  renders the session metadata above the selectable transcript.
- `cloudflare-error.png` displays `Cloudflare transcript request failed.`;
  current English localization is
  `Cloudflare transcripts couldn't be loaded. Try again.`

The empty screenshot happens to match the current English empty copy, but one
matching state does not resolve the other contradictions. A 0% residual only
proves equality with these baselines, not execution of the current Flutter
widget. Capture list/detail/empty/error from a deterministic current-widget
harness, retain the flow/run artifact, then compare against reviewed baselines.
Do not update a baseline merely to make the residual zero.

## Localization audit and finding 2

The tracked product localization is internally sound:

- 49 ARBs and 50 generated localization files were audited.
- `cloudflareTranscriptListEmptyMessage`,
  `cloudflareTranscriptLoadError`, and
  `cloudflareTranscriptSessionSemantics` exist in all 49 ARBs and all 50
  generated files.
- All values are non-empty.
- Every semantics value retains both `{sessionId}` and `{metadata}`.
- JSON comparison against `upstream/main` found exactly these three logical keys
  changed in every ARB; generated diffs contain all three keys in all 50 files.

Independent reproduction was performed outside the repository from a
`git archive HEAD app` copy with Flutter 3.41.9. After offline dependency
resolution, default `flutter gen-l10n` produced 50 generated files with
`byte_differences=0` against frozen HEAD.

The command also emitted 47 locale warnings, each for four untranslated Memories
keys: `alwaysInContext`, `baselineMemory`, `pinAsBaseline`, and
`unpinAsBaseline`. Those keys are present only in English and Chinese in both
current HEAD and upstream, so this is an upstream-derived warning baseline, not
a Cloudflare key omission.

`.vibepro/qa/omi-cloudflare-current/l10n-reproducibility-7b2614c.md` is stale and
must not be used as current proof: it is bound to `7b2614c...` and states
`Untranslated warnings: zero`, contradicting the current independent default
generation. Replace or retire that note with current-HEAD evidence that retains
the 47 locales x 4 warning result while also recording byte stability.

## Current verification evidence

`.vibepro/pr/omi-upstream-rebase-cloudflare-isolation/verification-evidence.json`
was updated at `2026-08-03T01:08:11.970Z`. Unit, integration, typecheck, and the
E2E-named compatibility alias all pass with runner-direct evidence, unchanged
HEAD before/after, and strict binding to
`52ff0989b7476dc8e624f0c2e3fbb58115addf46`.

- Unit output SHA-256:
  `672febc3e5a6a773418889df3dcb94305578e3640285e9acb70faaeff32abcd7`
- Integration output SHA-256:
  `aba5063a1f4d6d486acb55b087defa08d6bb794123c53c73eeb27263427da7de`
- Typecheck output SHA-256:
  `32fa48f30267b83006fe962e5f50f9d9a617971fe5afcb99c5552c97cde3215f`
- E2E compatibility output SHA-256:
  `c7c5ed9385cc04a44a30e76c1d679a59b0165375fea191adabfcea2c10489967`

The unit/integration/E2E-alias logs show 42 focused tests plus six WAL environment
probes; typecheck reports `No issues found!`. The records show no timeout,
truncation, tree mutation, HEAD movement, or worktree change. The Makefile
explicitly defines `e2e` as an alias of hermetic integration evidence.

## Evidence boundary retained

- Physical iPhone: **UNVERIFIED**
- VoiceOver: **UNVERIFIED**
- Deployed/live Cloudflare Worker: **UNVERIFIED**
- Production telemetry: **UNVERIFIED**
- Recording/upload/ack/delete: outside this read-only slice and unverified
- HTTP 200, analyzer/build success, widget tests, hermetic API tests, and the
  E2E-named compatibility alias are not elevated to physical-device or deployed
  end-to-end proof.

## Judgment delta

Initial judgment: likely PASS because the current widget and strict-HEAD tests
cover the required states and localization.

Final judgment: `NEEDS_CHANGES` because direct screenshot inspection showed that
the current visual artifacts contradict the current widget text/layout and lack
flow provenance. Localization implementation remains acceptable and byte-stable,
but its stale QA note also needs correction so it does not erase the reproduced
47 locales x 4 upstream-derived warning baseline.
