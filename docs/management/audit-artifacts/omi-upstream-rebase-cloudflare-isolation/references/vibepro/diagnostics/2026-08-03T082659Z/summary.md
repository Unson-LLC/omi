# VibePro 診断サマリー

| 項目 | 内容 |
|------|------|
| Run ID | 2026-08-03T082659Z |
| Story | Omi OSS最新版への再ベースとCloudflareセルフホスト差分の隔離 |
| Story ID | omi-upstream-rebase-cloudflare-isolation |
| 診断フェーズ | design_input |
| VibePro Runtime | vibepro@0.2.0-beta.2 commit=37418424323e dirty=true |
| 種別 | unknown |
| 描画方式 | - |
| 適用チェック | secrets, xss, dependency-graph, code-quality |
| graphify nodes | 102003 |
| graphify edges | 285905 |
| 共通スキャン対象 | 10839件 |
| 秘密情報候補 | 627件 (block: 71件, review: 134件, info: 422件) |
| XSSリスク候補 | 68件 (block: 0件, review: 62件, info: 6件) |
| UI旧トークン候補 | 0件 (block: 0件, review: 0件, info: 0件) |
| UI操作信頼性候補 | 0件 (block: 0件, review: 0件, info: 0件) |
| UIコンポーネント種別 | - |
| Gesture Interaction Gate | not_generated |
| Gesture Interaction候補 | 0件 (block: 0件, review: 0件, info: 0件) |
| Terminal Link契約 | ok |
| Terminal Link候補 | 0件 (block: 0件, review: 0件, info: 0件) |
| Flow Design Gate | pass |
| Flow Design UI走査 | 7件 |
| Flow Design検出候補 | 0件 |
| 重いdev script候補 | 0件 (block: 0件, review: 0件, info: 0件) |
| runtime probe plan | available (1 commands) |
| DB未ページング候補 | 0件 (block: 0件, review: 0件, info: 0件) |
| 認可前bulk DB候補 | 0件 (block: 0件, review: 0件, info: 0件) |
| 重複query形状候補 | 0件 (block: 0件, review: 0件, info: 0件) |
| 責務混在候補 | 0件 (block: 0件, review: 0件, info: 0件) |
| リファクタリング機会 | 0件 |
| リファクタリングcampaign | 0件 |
| API route | 0件 |
| Network Contract | pass |
| API client call | 0件 |
| API route欠落 | 0件 |
| Requirement Gate | pass |
| 要件不変条件 | 6件 |
| シナリオ確認候補 | 0件 |
| 要件矛盾候補 | 0件 |
| Performance Metrics | 0件 |
| Performance Comparable | 0件 |
| Performance Unknown | 0件 |
| 検出事項 | 2件 |

## アーキテクチャView

| View | 判定 |
|------|------|
| Structure | pages |
| Runtime | 0 entrypoints |
| Data | - |
| Security | 0 auth boundaries, 17 secret files |
| Deployment | - |
| Quality | .github/workflows/backend-checks.yml, .github/workflows/backend-hermetic-e2e.yml, .github/workflows/backend-unit-tests.yml, .github/workflows/deploy_docs.yml, .github/workflows/desktop-backend-contracts.yml, .github/workflows/desktop-checks.yml, .github/workflows/desktop-swift-ci.yml, .github/workflows/desktop-windows-ci.yml, .github/workflows/desktop_auto_release.yml, .github/workflows/desktop_backend_auto_dev.yml, .github/workflows/desktop_backend_prod.yml, .github/workflows/desktop_backend_recover_prod.yml, .github/workflows/desktop_beta_admission_control.yml, .github/workflows/desktop_breakglass_credential_preflight.yml, .github/workflows/desktop_breakglass_rollout_beta.yml, .github/workflows/desktop_promote_beta.yml, .github/workflows/desktop_promote_prod.yml, .github/workflows/desktop_publish_preview.yml, .github/workflows/desktop_qualify_beta.yml, .github/workflows/desktop_recover_beta.yml, .github/workflows/desktop_release_doctor.yml, .github/workflows/desktop_retry_beta_qualification.yml, .github/workflows/desktop_rollback_beta.yml, .github/workflows/desktop_windows_release.yml, .github/workflows/entellegence_issues.yml, .github/workflows/entelligence-pr-reviewer.yml, .github/workflows/firmware_release.yml, .github/workflows/gcp_admin.yml, .github/workflows/gcp_app.yml, .github/workflows/gcp_backend.yml, .github/workflows/gcp_backend_agent_proxy.yml, .github/workflows/gcp_backend_agent_proxy_auto_deploy.yml, .github/workflows/gcp_backend_auto_dev.yml, .github/workflows/gcp_backend_listen_helm.yml, .github/workflows/gcp_backend_pusher.yml, .github/workflows/gcp_backend_pusher_auto_deploy.yml, .github/workflows/gcp_diarizer.yml, .github/workflows/gcp_firestore_indexes.yml, .github/workflows/gcp_frontend.yml, .github/workflows/gcp_llm_gateway.yml, .github/workflows/gcp_memory_maintenance_job.yml, .github/workflows/gcp_memory_maintenance_job_auto_dev.yml, .github/workflows/gcp_models.yml, .github/workflows/gcp_nllb_translation.yml, .github/workflows/gcp_notifications_job.yml, .github/workflows/gcp_parakeet.yml, .github/workflows/gcp_personas.yml, .github/workflows/gcp_plugins.yml, .github/workflows/guardrail-baseline-pulse.yml, .github/workflows/main.yml, .github/workflows/mobile-app-checks.yml, .github/workflows/mobile_internal_build.yml, .github/workflows/onboarding_figma_sync.yml, .github/workflows/openapi-contract.yml, .github/workflows/opentofu-development-wif-pilot-validate.yml, .github/workflows/opentofu-development-wif-pilot.yml, .github/workflows/opentofu-foundation-validate.yml, .github/workflows/parakeet_gpu_tests.yml, .github/workflows/pr-declined-comment.yml, .github/workflows/public-build-config-preflight.yml, .github/workflows/publish_omi_cli.yml, .github/workflows/python-cli-ci.yml, .github/workflows/release-eligibility.yml, .github/workflows/repo-checks.yml, .github/workflows/repo-hygiene.yml, .github/workflows/runtime_image_contracts.yml, .github/workflows/sdk-rust.yml, .github/workflows/sync-docs.yml, .github/workflows/sync_ledger_fence_cutover.yml, .github/workflows/task-recommendation-live-eval.yml, .github/workflows/web-checks.yml, .github/workflows/windows-preflight-portability.yml |

## API境界

- api-boundary は適用されていない

## Network Contract

- Status: pass
- Routes: 0
- API client calls: 0
- Missing routes: 0
- Dynamic calls: 0
- Server function replacements: 0
- 問題なし

## ゲート状態

- production-readiness: block - 公開前に必ず解消すべき項目がある

## Requirement Consistency

- Status: pass
- Invariants: 6
- Scenario Gaps: 0
- Contradictions: 0

## Flow Design

- Status: pass
- UI Files: 7
- Silent Noops: 0
- Selection Side Effects: 0
- Question Dead Ends: 0
- Dead UI States: 0
- Value Alignment: 0

## Performance Evidence

# VibePro Performance Evidence

Story: omi-upstream-rebase-cloudflare-isolation
Metrics: 0
Runs: 0
Comparable: 0
Not comparable: 0

- No performanceMetrics are defined for this story.


## 主な検出事項

- VP-STATIC-002: 秘密情報の可能性がある値が含まれている（Critical）
- VP-STATIC-003: XSS につながり得る DOM 操作がある（High）

## 文脈品質ノート

- VP-GRAPH-002: 推論された依存関係がある（info）

## 診断レビュー

- Status: needs_review
- 未レビュー: 2件
- suggested implementation_gap: 2件
- suggested detector_gap: 0件
- 正本: finding-review.md と evidence.json の finding_review

## リファクタリング差分

- 比較対象の両runにリファクタリング機会なし

## 次アクション候補

- なし
