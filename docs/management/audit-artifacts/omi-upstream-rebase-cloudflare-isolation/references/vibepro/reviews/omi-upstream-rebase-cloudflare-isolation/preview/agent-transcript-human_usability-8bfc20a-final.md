# Terra human usability review — 8bfc20a

- Model: `gpt-5.6-terra`
- Reasoning effort: `high`
- Session: `/root/omi_human_usability_final`
- Frozen HEAD: `8bfc20a0408aec7003164d3f7038883a4748c4c1`
- Status: `needs_changes`

## Summary

Current HEAD preserves read-only list/detail behavior, configured and unconfigured fallback, empty/error/retry states, and the existing Omi header. Three repairable usability gaps remain: API exceptions bypass ARB and surface in English; session metadata combines a raw status with an unlabeled character count; and generated l10n output is not reproducible with the verification Flutter SDK. Physical iPhone, VoiceOver, and deployed Worker evidence remain unverified.

## Inspection

The reviewer classified and inspected all 77 changed paths against actual source, six changed test files, Story/Spec/ADR/runbook, generated localization files, current-HEAD verification artifacts, and the four static visual probes. The focused transcript-page widget suite was independently rerun with 8 passing tests.

Evidence:

- `.vibepro/reviews/omi-upstream-rebase-cloudflare-isolation/preview/review-request-human_usability.md`
- `.vibepro/pr/omi-upstream-rebase-cloudflare-isolation/pr-prepare.json`
- `.vibepro/pr/omi-upstream-rebase-cloudflare-isolation/verification-runs/`
- `.vibepro/qa/omi-cloudflare-current/visual-residual.json`

## Findings

1. `human-usability-cloudflare-error-copy-bypasses-arb` (medium): safe English API exception messages reach user-visible list/detail error text directly, including under Japanese locale. Keep safe error classification at the API boundary and localize at presentation boundaries; cover English and Japanese error widgets.
2. `human-usability-session-metadata-not-self-describing` (medium): list metadata such as `transcribed · 28` does not explain the number visually or to accessibility services. Localize the status and character-count label or add an explicit localized semantics label, with semantics-tree coverage.
3. `human-usability-l10n-generation-not-reproducible-with-verification-sdk` (low): regenerating with Flutter 3.41.9 changes all generated localization Dart files, predominantly formatting/trailing commas. Pin and record the generator SDK or regenerate with the fixed verification environment.

## Judgment delta

- Current-HEAD tests and static screenshots initially supported a pass candidate; direct source inspection showed that presentation error copy bypasses the Story's ARB SSOT requirement.
- Standard controls provide baseline interaction semantics, but raw status and an unlabeled numeric count are not self-describing.
- Fresh generation showed no missing new getter, but did show snapshot non-reproducibility under the verification SDK.
- Static visual residual evidence is not physical-device or VoiceOver proof and was not elevated.
