# Architecture boundary re-review — strict HEAD `5fe478b`

- Story: `omi-upstream-rebase-cloudflare-isolation`
- Stage / role: `architecture_spec` / `architecture_boundary`
- Reviewer: independent Codex subagent (`gpt-5.6-terra`, high)
- Reviewed HEAD: `5fe478bbaf613f472642ce3011720f0f266e0fcd`
- Base: `upstream/main` `d962001223d97edefad61e09c0d514efd8c42b0b`
- Prior reviewed HEAD: `52ff0989b7476dc8e624f0c2e3fbb58115addf46`
- Review mode: read-only inspection; no product/source code was changed

```json
{
  "status": "pass",
  "summary": "The current HEAD preserves the approved architecture boundary. Cloudflare remains a configuration-gated, read-only GET list/detail slice; redirects are disabled; the WAL adapter remains an unconnected disabled/deferred seam; and the only rebase delta from the prior reviewed HEAD is an unrelated macOS e2e coverage declaration.",
  "inspection_summary": "Independently inspected the exact current commit and upstream diff, Story/Spec/ADR, Cloudflare configuration/API/provider/UI composition, the WAL seam and existing WAL authority paths, l10n sources/generated outputs, focused tests, and current-HEAD unit artifact/log. The committed 121-path delta is classified as 99 l10n, 10 runtime, 6 tests, 5 docs, and 1 verification Makefile; git diff --check is clean.",
  "inspection_evidence": "git diff 52ff0989..5fe478b changes only desktop/macos/e2e/flows/notifications-settings.yaml by adding FloatingBarNotificationPreviewPolicy.swift to covers. .vibepro/pr/omi-upstream-rebase-cloudflare-isolation/verification-runs/unit.json records runner exit 0 at 5fe478b before/after with unchanged sampled worktree; unit.log ends with 42 focused tests passed and six dart-define WAL scenarios passed.",
  "inspection_inputs": [
    "git rev-parse HEAD; git diff upstream/main...HEAD; git diff --check upstream/main...HEAD; git diff 52ff0989..HEAD",
    "docs/stories/omi-upstream-rebase-cloudflare-isolation.md",
    "docs/specs/omi-upstream-rebase-cloudflare-isolation.md",
    "docs/architecture/ADR-omi-upstream-rebase-cloudflare-isolation.md",
    "app/lib/self_hosted/cloudflare/cloudflare_transcript_configuration.dart",
    "app/lib/self_hosted/cloudflare/cloudflare_transcript_api.dart",
    "app/lib/self_hosted/cloudflare/cloudflare_transcript_provider.dart",
    "app/lib/self_hosted/cloudflare/cloudflare_transcripts_page.dart",
    "app/lib/self_hosted/sync/self_hosted_wal_sync_adapter.dart",
    "app/lib/main.dart",
    "app/lib/pages/conversations/conversations_page.dart",
    "app/lib/pages/conversations/widgets/conversations_section_header.dart",
    "app/lib/services/wals/local_wal_sync.dart; app/lib/services/wals/wal_syncs.dart; app/lib/services/wals/sync_reconciler.dart",
    "app/lib/l10n/app_*.arb; app/lib/l10n/app_localizations*.dart",
    "app/test/self_hosted/cloudflare/*.dart; app/test/self_hosted/sync/*.dart",
    ".vibepro/pr/omi-upstream-rebase-cloudflare-isolation/verification-runs/unit.json",
    ".vibepro/pr/omi-upstream-rebase-cloudflare-isolation/verification-runs/unit.log"
  ],
  "judgment_delta": [
    "Initial concern: rebasing from 52ff0989 onto d962001 might introduce an upstream coupling into database state, Cloudflare, WAL, or Conversations. Final conclusion: the exact old-to-current diff is one macOS notification e2e coverage-list line, with no intersection with those surfaces.",
    "Initial concern: a Worker read slice could acquire write authority or redirect/unsafe-configuration exposure. Final conclusion: the sole request construction is http.Request('GET', uri), followRedirects is false, maxRedirects is zero, configuration rejects empty token, public HTTP, credentials, query, and fragment, and tests cover disabled-no-request and unsafe endpoints.",
    "Initial concern: the self-hosted seam could alter existing database/WAL lifecycle. Final conclusion: no committed diff touches database_state/schema/migration or existing app/lib/services/wals authority paths; NoopSelfHostedWalSyncAdapter only returns disabled/deferred and has no production caller, upload, acknowledgement, deletion, or LocalWalSyncImpl connection.",
    "Initial concern: broad l10n generation could hide a separate runtime surface. Final conclusion: 49 ARB sources contain all three Cloudflare keys and 50 generated localization Dart outputs implement the same contract; ADR identifies ARB as the source of truth and generated Dart as derived output.",
    "Initial concern: current verification may be stale after the rebase. Final conclusion: the directly inspected current-head unit artifact is bound to 5fe478b before/after and reports no worktree/HEAD change; its raw log confirms 42 focused tests plus six configuration scenarios. Non-required managed-worktree-locality and count-parsing warnings remain visible and are not promoted to runtime or release proof."
  ],
  "findings": []
}
```

## Mandatory lenses

### regression_guard — PASS

- `database_state`: no committed diff match for `database_state`/`databaseState`, and no changed database/schema/migration or existing WAL authority path. The current composition adds only `CloudflareTranscriptProvider` and a thin Conversations header entry.
- Cloudflare is disabled without a valid URL and nonblank token. Valid endpoints are HTTPS or loopback HTTP; credentials, query, fragment, and public HTTP are rejected. The API has only `GET` request construction, uses a bearer header only for the request, disables redirects, and fail-closes timeout, non-2xx, JSON, and response-shape failures without exposing the token.
- `NoopSelfHostedWalSyncAdapter` is deliberately write-free and disconnected: its outcomes are `disabled`/`deferred`, and direct reference inspection finds it only in its implementation and focused tests. Existing `LocalWalSyncImpl`, `WalSyncs`, capture, and reconciler ownership are unchanged.
- The focused widget/provider tests cover disabled configuration, original Omi-zero and daily-summary headers, configured Omi-zero navigation, list/detail empty/error/retry/semantics, and localized error output. Unit evidence reports all 42 focused tests passed, plus six compile-time configuration cases.

### path_surface_coverage — PASS

- The whole `upstream/main...HEAD` inventory is accounted for: 99 l10n paths (49 ARB plus 50 generated Dart), 10 runtime/wiring paths, 6 focused tests, 5 documentation paths, and 1 verification Makefile. `git diff --check` reports no whitespace errors.
- Input/fallback surfaces were inspected: absent/whitespace token, malformed URL, public HTTP, valid HTTPS, loopback HTTP, disabled sync flag, malformed Worker response, repeated cursor, empty/error/retry UI, Omi-zero fallback, and daily-summary header preservation.
- Worker implementation/deployment is a separate repository/runtime boundary: no Worker, wrangler, Firebase, native mobile, secret, entitlement, migration, or database path occurs in the committed diff. The Worker endpoint is consumed only as the documented external read contract.
- l10n is not silently treated as a separate behavior lane: ARB is the stated source of truth, generated Dart is derived, and the current tree has the three Cloudflare keys in every 49 ARBs and corresponding generated implementations in 50 Dart outputs.

## Evidence boundary retained

Physical iPhone behavior, real VoiceOver operation, deployed Cloudflare Worker behavior, production telemetry, and the recording-to-upload-to-acknowledgement-to-delete journey are **未確認**. The hermetic focused unit suite demonstrates the isolated app contract only; it is neither device E2E nor deployed-Worker proof.

The working tree currently has an unrelated uncommitted `.gitignore` modification that ignores VibePro/worktree artifacts. It was neither modified nor included in the commit-tree verdict; the review is fixed to `5fe478b`.
