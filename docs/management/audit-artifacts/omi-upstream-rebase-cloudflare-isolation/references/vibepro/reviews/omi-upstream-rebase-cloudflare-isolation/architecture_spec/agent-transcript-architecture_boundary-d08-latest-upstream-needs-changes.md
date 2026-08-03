# Terra architecture boundary review — d08 latest upstream

```json
{
  "status": "needs_changes",
  "summary": "Cloudflare transcript wiring is architecturally coherent and GET-only, existing Omi/Firebase/local-WAL authority remains intact, and all four runner-direct artifacts are current-HEAD-bound. The complete 120-path review found one unscoped regression surface: 48 locale bundles also change four pre-existing Memories UI localization keys absent from Story, Spec, ADR, and focused validation.",
  "findings": [
    {
      "id": "architecture-boundary-unscoped-memory-l10n",
      "severity": "medium",
      "detail": "47 locale ARBs add, and app_zh.arb changes, alwaysInContext, baselineMemory, pinAsBaseline, and unpinAsBaseline. Generated locale Dart therefore changes the pre-existing Memories UI across 48 locales while the Story scope and verification target only the Cloudflare read slice. Revert these four unrelated keys and regenerate localization output, or explicitly expand design scope and regression validation.",
      "evidence": "upstream comparison found the keys newly added in 47 ARBs and value-changed in app_zh.arb, producing generated Dart churn across 48 locales; memory_edit_sheet.dart consumes the keys; the verification Makefile does not exercise Memories UI."
    }
  ],
  "inspection_summary": "Inspected all 120 paths at d08ea30d40e0026aba6f92835b9fd926fa9069b2: 49 ARBs, 50 generated localization files, 10 product source files, 6 tests, 4 documents, and 1 verification Makefile. Cloudflare GET-only wiring and existing authority boundaries pass; the aggregate localization comparison exposed the single scope gap.",
  "inspection_evidence": [
    "git diff --name-status upstream/main...HEAD classified all 120 paths and git diff --check passed.",
    "Branch is 0 behind current upstream/main 6a580396d; latest upstream delta is desktop Swift CI-only.",
    "Cloudflare production entry path is configuration-gated, GET-only, no-redirect, and fail-closed.",
    "Self-hosted WAL adapter has no production caller; Omi/Firebase/existing WAL paths are unchanged.",
    "unit, integration, e2e, and typecheck artifacts are runner-direct at current HEAD with no mutation, truncation, or timeout.",
    "Test-count parser remains null; non-truncated logs show 42 focused tests plus six WAL environment probes.",
    "Physical iPhone, VoiceOver, and deployed Worker remain unverified separate lanes.",
    "All 49 ARBs parse and contain Cloudflare keys; cross-base comparison found four unrelated Memories keys in 48 locales.",
    "No prompt-injection-like instruction was found."
  ],
  "inspection_inputs": [
    ".vibepro/verification/Makefile",
    "app/lib/main.dart",
    "app/lib/pages/conversations/conversations_page.dart",
    "app/lib/pages/conversations/widgets/conversations_section_header.dart",
    "app/lib/self_hosted/cloudflare",
    "app/lib/self_hosted/sync/self_hosted_wal_sync_adapter.dart",
    "app/lib/pages/memories/widgets/memory_edit_sheet.dart",
    "app/test/self_hosted",
    "docs/architecture/ADR-omi-upstream-rebase-cloudflare-isolation.md",
    "docs/operational/omi-self-hosted-local-overlay.md",
    "docs/specs/omi-upstream-rebase-cloudflare-isolation.md",
    "docs/stories/omi-upstream-rebase-cloudflare-isolation.md",
    "app/lib/l10n/app_en.arb",
    "app/lib/l10n/app_ja.arb",
    "app/lib/l10n/app_zh.arb",
    "app/lib/l10n/app_localizations.dart",
    "app/lib/l10n/app_localizations_ja.dart",
    "app/lib/l10n/app_localizations_zh.dart",
    ".vibepro/pr/omi-upstream-rebase-cloudflare-isolation/verification-evidence.json",
    ".vibepro/pr/omi-upstream-rebase-cloudflare-isolation/verification-runs"
  ],
  "judgment_delta": [
    "Cloudflare wiring, authority, verification attribution, and latest-upstream concerns resolved.",
    "Path-surface judgment changed to needs_changes after all localization paths exposed unrelated Memories UI translations.",
    "Physical iPhone, VoiceOver, and deployed Worker were not treated as proven."
  ]
}
```
