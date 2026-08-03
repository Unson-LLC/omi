# Independent preview review: human_usability

- Story: `omi-upstream-rebase-cloudflare-isolation`
- Reviewed HEAD: `fe24e061df2b95dde64667ef0bc8236187cd5dca`
- Verdict: `pass`

## Scope and evidence boundary

This review covers the opt-in, GET-only Cloudflare transcript list/detail UI and the thin Omi integration points. It does not claim physical iPhone, VoiceOver, deployed Worker, production telemetry, capture upload, acknowledgement, deletion, or WAL write evidence. Those are explicitly unverified.

## Inspected inputs

1. `app/lib/self_hosted/cloudflare/cloudflare_transcripts_page.dart`: loading, empty, scoped error/retry, list semantics, selectable detail text, and localized metadata.
2. `app/lib/self_hosted/cloudflare/cloudflare_transcript_provider.dart` and `cloudflare_transcript_api.dart`: configuration-gated reads, GET-only requests, redirects disabled, and error containment.
3. `app/lib/pages/conversations/widgets/conversations_section_header.dart`, `app/lib/pages/conversations/conversations_page.dart`, and `app/lib/main.dart`: the only UI/provider integration is an opt-in entry; disabled configuration preserves the original zero-conversation behavior.
4. `app/test/self_hosted/cloudflare/cloudflare_transcripts_page_test.dart`: focused current-head execution passed 14/14 on 2026-08-03. It covers configured entry -> list -> detail, disabled/invalid-config hiding, empty detail/list, localized error/retry in English and Japanese, retry recovery, and semantic labels/buttons.
5. `.vibepro/pr/omi-upstream-rebase-cloudflare-isolation/verification-runs/e2e.log`: current-head hermetic run records API/model/provider/UI and WAL-boundary coverage without promoting it to physical E2E.
6. `.vibepro/qa/omi-cloudflare-current/visual-residual.json` and `residual-analysis.md`: four list/detail/empty/error probes are bound to this HEAD and pass with 0% mean absolute residual against the stated baselines. Current list and error images were also inspected.
7. `app/lib/l10n/app_en.arb`, `app/lib/l10n/app_ja.arb`, and `app/lib/l10n/app_es.arb`: new visible and semantic strings are localized; generated localization Dart is present as the ARB-derived output.

## Mandatory lenses

### regression_guard

The header renders only when existing Omi state, daily recaps, or valid Cloudflare configuration warrants it. With Cloudflare disabled, the original empty header remains absent; when Omi/daily-summary headers already exist, they remain visible. The Cloudflare page is isolated to the new provider and has scoped error/retry behavior, while the adapter is outside the UI path and remains no-op. Focused tests prove the pre-fix disabled/header behavior and configured navigation path, not only the happy path.

### path_surface_coverage

The reviewed paths cover configuration invalid/disabled, configured entry, pagination/read response parsing, list/detail rendering, empty, error, retry, English/Japanese semantic metadata, and visual list/detail/empty/error surfaces. API/provider failures do not place underlying messages in the UI. Documentation and tests retain the distinction between hermetic compatibility evidence and unverified Worker/device/runtime evidence.

## Judgment delta

Initial concern: adding an entry to a zero-conversation Omi page could hide or change existing empty/daily-summary behavior, and Worker errors could surface unlocalized or unsafe details. Final conclusion: current-head source plus focused widget/semantics tests show the entry is configuration-gated, preserves the existing headers/empty boundary when disabled, and presents localized scoped error/retry states without API error text. Visual residual evidence covers the four visible states at 0%; the non-hermetic proof boundary remains explicit.

## Findings

None for this role. Physical iPhone/VoiceOver, deployed Worker, and production telemetry remain unverified rather than passing evidence.
