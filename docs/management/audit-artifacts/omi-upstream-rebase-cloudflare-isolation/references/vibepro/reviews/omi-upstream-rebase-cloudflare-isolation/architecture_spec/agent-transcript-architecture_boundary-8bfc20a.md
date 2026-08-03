# Architecture boundary review transcript

- Story: `omi-upstream-rebase-cloudflare-isolation`
- HEAD: `8bfc20a0408aec7003164d3f7038883a4748c4c1`
- Reviewer: `/root/omi_gate_evidence_review` (separate Terra review session)
- Result: PASS

## Summary

`upstream/main...HEAD` の 77 paths を l10n 52、runtime 10、tests 6、docs 9 として全件確認した。A-D 隔離境界、GET-only Cloudflare module、未配線 no-op WAL、Cloudflare 無効時の OSS fallback、ARB 正本の生成 l10n、release/rollback、`risk_surfaces=database_state` は整合する。物理 iPhone と deployed Worker は未確認で、本判定には含めない。

## Findings resolved

1. `sequence-type-contract-is-not-enforced`: API validation は `value is int` のみ許可し、model も `_requiredJsonInt` で再検証する。`cloudflare_transcript_api_test.dart` は文字列、null、小数、bool を API/model 双方で拒否する。
2. `raw-transport-errors-can-cross-the-scoped-safe-error-boundary`: 未知 transport 例外は固定文言 `CloudflareTranscriptApiException.transportFailure` へ変換する。ClientException 内の sentinel、Bearer token、Worker URL が例外文言へ出ない回帰テストを確認した。

## Architecture evidence

- A: Cloudflare API/model/provider/UI は `app/lib/self_hosted/cloudflare/` に閉じる。
- B: OSS direct-touch は `main.dart` の Provider 登録と Conversations 入口のみ。
- C: sync adapter は disabled/deferred のみを返し、upload/ack/delete/WAL mutation を行わない。
- D: Worker runtime は別 repo 境界、l10n は英日 ARB を正本とし、運用差分は Story/Spec/ADR/runbook に閉じる。
- 差分に DB/migration/Firebase/Worker deploy path はない。
- focused API tests 20/20 pass、current-HEAD unit/typecheck pass。
- 旧 HEAD の integration/e2e は current-HEAD 証拠として不使用。

## Judgment delta

前回は sequence 型緩和と raw transport 例外表示のため NEEDS_CHANGES だった。current HEAD では runtime source と pre-fix-failing regression tests の双方で解消を確認したため PASS とした。database_state 境界は変更差分に DB mutation がなく、WAL adapter も未配線かつ no-op であるため preflight として closed。物理 iPhone、deployed Worker、production telemetry は未確認のまま分離する。
