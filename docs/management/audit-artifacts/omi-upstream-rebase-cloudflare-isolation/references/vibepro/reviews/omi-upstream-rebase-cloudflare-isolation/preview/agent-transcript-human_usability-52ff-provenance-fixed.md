# Human usability re-review — current visual provenance fixed

- Story: `omi-upstream-rebase-cloudflare-isolation`
- Stage / role: `preview / human_usability`
- Reviewer: `/root/omi_human_usability_final` (`gpt-5.6-terra`, high)
- Frozen HEAD: `52ff0989b7476dc8e624f0c2e3fbb58115addf46`
- Base: `upstream/main@275a4886291a6527de9850b470835bf9cad9c37b`
- Result: `PASS`
- Findings: none
- Product/test/docs changes made by reviewer: none

## Decision

The two prior `NEEDS_CHANGES` findings are resolved. The four current PNGs now
depict the current Flutter widget states, and a retained deterministic golden
harness plus producer manifest binds those files to the current source and
frozen HEAD. The current l10n note no longer claims zero warnings; it records
the independently reproduced 47 locales x 4 upstream-derived warning baseline
while retaining byte-identical generated output.

This is a role-level `PASS`, not a global PR-ready decision.
`pr-prepare.json` still reports `overall_status=needs_verification`,
`ready_for_pr_create=false`, and a blocked execution gate because the previous
human-usability result is recorded and the later strict-HEAD gate reviews are
stale. The coordinator must record this replacement result and then proceed
through the serial review stages.

## Frozen state and 121-path coverage

- `git rev-parse HEAD`: `52ff0989b7476dc8e624f0c2e3fbb58115addf46`
- merge base: `275a4886291a6527de9850b470835bf9cad9c37b`
- worktree before this transcript: clean
- `git diff --check upstream/main...HEAD`: pass
- changed paths: 121, with zero unknown paths
- classification: 49 ARB sources, 50 generated localization Dart files,
  10 product Dart files, 6 focused tests, 5 Story/Spec/ADR/runbook/audit docs,
  and 1 VibePro verification Makefile

The inspected non-l10n surface covers app/provider wiring, the Conversations
entry and legacy fallback, Cloudflare configuration/API/models/provider,
list/detail UI, the disabled/deferred WAL seam, Cloudflare and WAL tests, and
the aligned Story/Spec/ADR/runbook/budget boundary. The docs continue to call
the Worker read surface read-only and explicitly separate local evidence from
deployed Worker and physical-iPhone evidence.

## Resolution of prior finding 1: current-widget PNG provenance

The retained canonical producer is
`.vibepro/qa/omi-cloudflare-current/harness/omi_cloudflare_current_visual_golden_test.dart`.
It imports the product `CloudflareTranscriptsPage`, detail page, provider,
models, API, and generated localizations. It fixes a 390x844 viewport at DPR 1,
uses a deterministic in-process `CloudflareTranscriptApi` fixture, and asserts
the exact current strings before writing each golden. The temporary
`app/test/omi_cloudflare_current_visual_golden_test.dart` is absent, consistent
with the documented copy-run-remove lifecycle.

Independent hash checks matched `producer.json`:

- harness: `910681b31a0624022fe6b1b414502dfdf5904a54dc1cc01f1fb427c2a6b29efc`
- page source: `ae313b2245b975c3db5a49af161178abb2f22662181ee412189d7ff9b0aa086c`
- provider source: `adbf88e557c021572188be1aa13372744c58ac4562336cc835b32432ffea64de`
- model source: `b70c9dafc39a84dd1166557cfd381518c2182ba8c2a16990e0d13ea395e1f7ad`
- list PNG: `6e0226d0d4cfebe28b5d12661c360b5460abc7b22ed63a4d62e522f3b4100e0c`
- detail PNG: `b3489be7a23345565736a2b98c96b2b9b88caebc957f9616c2a242563fd69a14`
- empty PNG: `0ec3ceafe7c31b1e2d683eebac489a6a894e17f43b9478c7aed1932ad3086c4f`
- error PNG: `97f704ff58ddb7b84514bd776fbbf2c67f6fc9c08c46648017464aa2ee72a225`

Direct inspection of all four PNGs confirms the current semantics:

- list: `Status: transcribed · 12 characters`
- detail: the same metadata followed by `Hello Cloudflare`
- empty: `No Cloudflare transcripts are available yet.`
- error: `Cloudflare transcripts couldn't be loaded. Try again.` plus `Retry`

All PNGs are 390x844. Each current hash equals its reviewed baseline hash, and
the Story-specific visual residual reports four compared probes, 0% MAE, 5%
threshold, status `pass`, and exact current HEAD. Unlike the superseded copied
legacy images, the zero residual is now supported by a retained current-product
producer and exact source/output hashes.

`flow_run_id` and `flow_verification_json` remain `null` truthfully. The tracked
root package has no Playwright dependency/script, so `vibepro verify flow`
reports `needs_setup`; no tracked manifest was modified to manufacture a run.
This does not invalidate the deterministic Flutter widget-golden provenance,
but it remains outside browser-flow evidence.

## Resolution of prior finding 2: l10n warnings

`.vibepro/qa/omi-cloudflare-current/l10n-reproducibility-52ff0989.md` is bound
to this exact HEAD and records Flutter 3.41.9 / Dart 3.11.5, 50 generated files,
zero byte differences after generation, and 47 locales x 4 warnings = 188.
The stale `7b2614c` note is no longer present in the current QA directory.

Independent static recount confirmed:

- 49 ARBs and 50 generated localization Dart files
- all three Cloudflare keys present and non-empty in 49/49 ARBs and represented
  in 50/50 generated files
- among the 48 non-English ARBs, one has no missing English-template keys and
  47 each miss exactly four keys
- the four-key union is `alwaysInContext`, `baselineMemory`, `pinAsBaseline`,
  and `unpinAsBaseline`

This matches the exact-HEAD external regeneration already inspected: 50/50
generated files byte-identical and 47 x 4 warnings. The warning baseline is no
longer falsely reported as zero and is not caused by the Cloudflare strings.

## Current widget and focused-test semantics

The product widget projects loading, empty, scoped localized error/retry,
populated list, detail loading/error/empty/content, and pull-to-refresh states.
It does not render raw provider/API errors. List metadata labels Worker status,
uses locale-aware date/time, and localizes character count. List rows expose a
localized button semantics label containing session identity plus metadata and
exclude duplicate child semantics; detail metadata has its own localized
semantics label above selectable transcript text.

The focused widget tests assert English and Japanese error/retry copy, absence
of raw errors, visible list/detail metadata, session/button semantics, empty
states, Omi-zero navigation, disabled/invalid configuration fallback, retained
legacy headers, and retry recovery. Current strict-HEAD verification records
unit, integration, typecheck, and the hermetic E2E-compatibility alias as pass;
the alias is not treated as physical-device or deployed-runtime E2E.

## Evidence boundaries retained

- Physical iPhone: **UNVERIFIED**
- VoiceOver: **UNVERIFIED**
- Deployed/live Cloudflare Worker: **UNVERIFIED**
- Production telemetry: **UNVERIFIED**
- Recording/upload/ack/delete: outside this read-only slice and unverified
- Browser/Playwright flow: **UNVERIFIED / needs setup**
- Flutter widget goldens and semantics tests are local deterministic evidence,
  not device accessibility or production outcome proof

## Judgment delta

`NEEDS_CHANGES -> PASS`: the stale/copied legacy screenshots were replaced by
four exact-current widget goldens with a retained deterministic harness and
HEAD/source/output hash provenance, and the stale zero-warning l10n claim was
replaced by exact-HEAD evidence that preserves the reproduced 47 x 4 warning
baseline while confirming zero generated byte differences.

## Review mutation boundary

No product, test, documentation, configuration, baseline, or git state was
changed. The only authored artifact is this requested ignored review transcript.
