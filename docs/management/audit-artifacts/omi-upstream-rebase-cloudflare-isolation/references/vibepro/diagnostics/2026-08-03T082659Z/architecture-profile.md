# 構造プロファイル

| 項目 | 内容 |
|------|------|
| Run ID | 2026-08-03T082659Z |
| 種別 | unknown |
| 描画方式 | - |
| パッケージ管理 | npm |
| 言語 | go, javascript, python, ruby, rust, typescript |
| API route | なし |
| DB | なし |
| 認証 | なし |
| 配信 | - |

## View

| View | 判定 |
|------|------|
| Structure | pages |
| Runtime | 0 entrypoints |
| Data | - |
| Security | 0 auth boundaries, 17 secret files |
| Deployment | - |
| Quality | .github/workflows/backend-checks.yml, .github/workflows/backend-hermetic-e2e.yml, .github/workflows/backend-unit-tests.yml, .github/workflows/deploy_docs.yml, .github/workflows/desktop-backend-contracts.yml, .github/workflows/desktop-checks.yml, .github/workflows/desktop-swift-ci.yml, .github/workflows/desktop-windows-ci.yml, .github/workflows/desktop_auto_release.yml, .github/workflows/desktop_backend_auto_dev.yml, .github/workflows/desktop_backend_prod.yml, .github/workflows/desktop_backend_recover_prod.yml, .github/workflows/desktop_beta_admission_control.yml, .github/workflows/desktop_breakglass_credential_preflight.yml, .github/workflows/desktop_breakglass_rollout_beta.yml, .github/workflows/desktop_promote_beta.yml, .github/workflows/desktop_promote_prod.yml, .github/workflows/desktop_publish_preview.yml, .github/workflows/desktop_qualify_beta.yml, .github/workflows/desktop_recover_beta.yml, .github/workflows/desktop_release_doctor.yml, .github/workflows/desktop_retry_beta_qualification.yml, .github/workflows/desktop_rollback_beta.yml, .github/workflows/desktop_windows_release.yml, .github/workflows/entellegence_issues.yml, .github/workflows/entelligence-pr-reviewer.yml, .github/workflows/firmware_release.yml, .github/workflows/gcp_admin.yml, .github/workflows/gcp_app.yml, .github/workflows/gcp_backend.yml, .github/workflows/gcp_backend_agent_proxy.yml, .github/workflows/gcp_backend_agent_proxy_auto_deploy.yml, .github/workflows/gcp_backend_auto_dev.yml, .github/workflows/gcp_backend_listen_helm.yml, .github/workflows/gcp_backend_pusher.yml, .github/workflows/gcp_backend_pusher_auto_deploy.yml, .github/workflows/gcp_diarizer.yml, .github/workflows/gcp_firestore_indexes.yml, .github/workflows/gcp_frontend.yml, .github/workflows/gcp_llm_gateway.yml, .github/workflows/gcp_memory_maintenance_job.yml, .github/workflows/gcp_memory_maintenance_job_auto_dev.yml, .github/workflows/gcp_models.yml, .github/workflows/gcp_nllb_translation.yml, .github/workflows/gcp_notifications_job.yml, .github/workflows/gcp_parakeet.yml, .github/workflows/gcp_personas.yml, .github/workflows/gcp_plugins.yml, .github/workflows/guardrail-baseline-pulse.yml, .github/workflows/main.yml, .github/workflows/mobile-app-checks.yml, .github/workflows/mobile_internal_build.yml, .github/workflows/onboarding_figma_sync.yml, .github/workflows/openapi-contract.yml, .github/workflows/opentofu-development-wif-pilot-validate.yml, .github/workflows/opentofu-development-wif-pilot.yml, .github/workflows/opentofu-foundation-validate.yml, .github/workflows/parakeet_gpu_tests.yml, .github/workflows/pr-declined-comment.yml, .github/workflows/public-build-config-preflight.yml, .github/workflows/publish_omi_cli.yml, .github/workflows/python-cli-ci.yml, .github/workflows/release-eligibility.yml, .github/workflows/repo-checks.yml, .github/workflows/repo-hygiene.yml, .github/workflows/runtime_image_contracts.yml, .github/workflows/sdk-rust.yml, .github/workflows/sync-docs.yml, .github/workflows/sync_ledger_fence_cutover.yml, .github/workflows/task-recommendation-live-eval.yml, .github/workflows/web-checks.yml, .github/workflows/windows-preflight-portability.yml |

## 適用チェック

- secrets
- xss
- dependency-graph
- code-quality

## 根拠

- package_json: package.json omi-memory-ingestion-pipeline
