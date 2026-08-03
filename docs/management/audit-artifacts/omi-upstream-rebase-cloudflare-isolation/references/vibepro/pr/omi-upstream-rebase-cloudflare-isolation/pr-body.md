## 判断
- このPRで判断すること: Omi OSS最新版への再ベースとCloudflareセルフホスト差分の隔離 を満たすための Runtime / Contract Docs / Tests 変更として、このPRを受け入れてよいか。
- Story: omi-upstream-rebase-cloudflare-isolation - Omi OSS最新版への再ベースとCloudflareセルフホスト差分の隔離
- 正本: [docs/stories/omi-upstream-rebase-cloudflare-isolation.md](docs/stories/omi-upstream-rebase-cloudflare-isolation.md)
- 変更範囲: 122 files / Runtime / Contract Docs / Tests
- 設計/Story: [docs/stories/omi-upstream-rebase-cloudflare-isolation.md](docs/stories/omi-upstream-rebase-cloudflare-isolation.md), [docs/architecture/ADR-omi-upstream-rebase-cloudflare-isolation.md](docs/architecture/ADR-omi-upstream-rebase-cloudflare-isolation.md), [docs/specs/omi-upstream-rebase-cloudflare-isolation.md](docs/specs/omi-upstream-rebase-cloudflare-isolation.md)
- 実装: app/lib/l10n/app_ar.arb, app/lib/l10n/app_be.arb, app/lib/l10n/app_bg.arb, ...and 106 more
- テスト: app/test/self_hosted/cloudflare/cloudflare_transcript_api_test.dart, app/test/self_hosted/cloudflare/cloudflare_transcript_configuration_test.dart, app/test/self_hosted/cloudflare/cloudflare_transcript_provider_test.dart, ...and 3 more

## 経緯
- 要求: Omi OSS最新版への再ベースとCloudflareセルフホスト差分の隔離
- 要求ID: omi-upstream-rebase-cloudflare-isolation
- 発生経緯: Story文書から経緯を抽出できませんでした。
## なぜこの PR か (TP-001 by codex)
BasedHardware/omiの最新mainを基準に、Cloudflareセルフホスト会話参照を独立モジュールと薄い接続点へ隔離する。既存の動作済みスパイクは参照用に保存し、生成済みl10n Dartや個人用Firebase・署名・entitlementは製品差分へ持ち込まない。

Failure-Class: none

## リスク合成 (TP-002)
Cloudflare設定が無効な環境では既存OSS経路を維持し、有効時もGET専用・リダイレクト禁止の境界を越えないことが主要な安全条件になる。


## 原因
- 旧forkは `origin/main` より1 commit先で大量の未コミット変更を含み、`upstream/main` から3,642 commits遅れた検証スパイクである。そのまま差分を積み増すと、OSS更新、Cloudflare Worker、個人端末のFirebase/署名設定が同じ変更面に混ざり、同期経路の安全性を継続して検証できない。

## 解決
- Story文書を更新: [docs/stories/omi-upstream-rebase-cloudflare-isolation.md](docs/stories/omi-upstream-rebase-cloudflare-isolation.md)

## 受入判定スコープ
- 判定単位: Story
- Story ID: omi-upstream-rebase-cloudflare-isolation
- Task ID: なし
- 対象受入基準: 30件


## Release Notes

### Change Summary
Story文書を更新: [docs/stories/omi-upstream-rebase-cloudflare-isolation.md](docs/stories/omi-upstream-rebase-cloudflare-isolation.md)

### Compatibility
なし

### User Action
なし

## レビュー観点
- Gate: 未解決の必須Gateはありません。ただしリリース判断Warning: Managed Worktree Gate。 詳細はVibePro証跡の Gate DAG / Gate Enforcement を確認してください。
- Scope: 差分範囲の説明または分割判断が必要。理由: 差分が 122 files あり、レビュー可能な目安 30 files を超えている; baseからのcommitが 32 件あるため履歴確認が必要だが、別Story lineageは検出されていない / split=keep_current_pr_atomic_scope
- Scope lineage evidence: -
- 分割判断: atomic accepted: requirements-ssot、runtime-behavior、misc-follow-upは同じread-only縦スライスの契約と接続点を検証するため不可分である。生成l10nはARB由来の派生物、overlay docは設定境界であり、これらを分割すると契約と実装の原子性が失われる。 / 自動勧告: split_recommended / split_by_lane_then_prepare / lanes: requirements-ssot, runtime-behavior, misc-follow-up / 採用: keep_current_pr_atomic_scope
- 管理worktree: needs_review
- Storyの受け入れ基準と実装差分が対応しているか
- 主要ソース差分: app/lib/l10n/app_ar.arb, app/lib/l10n/app_be.arb, app/lib/l10n/app_bg.arb, app/lib/l10n/app_bn.arb, ...
- テスト差分: app/test/self_hosted/cloudflare/cloudflare_transcript_api_test.dart, app/test/self_hosted/cloudflare/cloudflare_transcript_configuration_test.dart, app/test/self_hosted/cloudflare/cloudflare_transcript_provider_test.dart, app/test/self_hosted/cloudflare/cloudflare_transcripts_page_test.dart, ...
- Risk: 最新診断gateが block

## 確認
- [ ] 手動確認または対象テストを追記する
- 最終E2E: pass: Current-head hermetic E2E replay passed; version_stamp probe binds the verification runner to expected artifact HEAD 9465b75d22cffe230b956bc43f4459931ac9c470, while deployed runtime remains unverified.（[.vibepro/pr/omi-upstream-rebase-cloudflare-isolation/verification-runs/e2e.json](.vibepro/pr/omi-upstream-rebase-cloudflare-isolation/verification-runs/e2e.json)）

## 詳細
- 証跡: [.vibepro/pr/omi-upstream-rebase-cloudflare-isolation/](.vibepro/pr/omi-upstream-rebase-cloudflare-isolation/)
- PR準備: [.vibepro/pr/omi-upstream-rebase-cloudflare-isolation/pr-prepare.json](.vibepro/pr/omi-upstream-rebase-cloudflare-isolation/pr-prepare.json)
- 判断索引: [.vibepro/pr/omi-upstream-rebase-cloudflare-isolation/decision-index.summary.json](.vibepro/pr/omi-upstream-rebase-cloudflare-isolation/decision-index.summary.json)（bounded summary / 全文: [.vibepro/pr/omi-upstream-rebase-cloudflare-isolation/decision-index.json](.vibepro/pr/omi-upstream-rebase-cloudflare-isolation/decision-index.json)）
- Gate: ready_for_review
- 実行状態: ready
- Scope: needs_clean_branch / clean_branch_or_split_pr
- Runtime: vibepro@0.2.0-beta.2 37418424323e detached/package dirty (story=omi-upstream-rebase-cloudflare-isolation)
