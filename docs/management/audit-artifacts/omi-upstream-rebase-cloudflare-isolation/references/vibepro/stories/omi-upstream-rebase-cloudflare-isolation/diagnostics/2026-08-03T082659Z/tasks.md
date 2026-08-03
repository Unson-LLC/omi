# VibePro 生成タスク

| 項目 | 内容 |
|------|------|
| Story | Omi OSS最新版への再ベースとCloudflareセルフホスト差分の隔離 |
| Story ID | omi-upstream-rebase-cloudflare-isolation |
| Run ID | 2026-08-03T082659Z |
| Gate | block |
| タスク数 | 4 |

| ID | Finding | 優先度 | 対象 | 方針 | 状態 |
|----|---------|--------|------|------|------|
| VP-TASK-STATIC-002-BLOCK | VP-STATIC-002 | critical | 3件 | manual-review | todo |
| VP-TASK-STATIC-002-REVIEW | VP-STATIC-002 | high | 44件 | manual-review | todo |
| omi-upstream-rebase-cloudflare-isolation-source-alignment-review | - | high | 0件 | source-alignment-review | done |
| VP-TASK-STATIC-003 | VP-STATIC-003 | high | 21件 | manual-review | todo |

## VP-TASK-STATIC-002-BLOCK: 秘密情報の可能性がある値が含まれている（即時対応）

- Source: finding / VP-STATIC-002
- Execution: proposal_only / mutates_repository=false
- Target files: backend/.env.dev.template, backend/.env.local-dev.template, backend/.env.offline.template
- Target groups: -
- Read first: backend/.env.dev.template, backend/.env.local-dev.template, backend/.env.offline.template
- Recommended strategy: manual-review

完了条件:
- 公開前に該当値を削除し、必要な値はサーバー側または安全な環境変数管理へ移す。

## VP-TASK-STATIC-002-REVIEW: 秘密情報の可能性がある値が含まれている（要確認）

- Source: finding / VP-STATIC-002
- Execution: proposal_only / mutates_repository=false
- Target files: .github/scripts/test_check_deployment_secret_boundary.py, .github/scripts/test_publish_desktop_candidate_tag.py, backend/charts/backend-secrets/dev_omi_backend_secrets_values.yaml, backend/charts/backend-secrets/prod_omi_backend_secrets_values.yaml, backend/llm_gateway/routers/anthropic_messages.py, backend/routers/auth.py, backend/routers/google_calendar.py, backend/routers/integrations.py, backend/routers/mcp_sse.py, backend/routers/task_integrations.py, backend/scripts/smoke_mcp_chatgpt_review.py, backend/testing/e2e/test_task_integrations.py, backend/utils/conversations/calendar_linking.py, backend/utils/llm/clients.py, backend/utils/llm/gateway_anthropic.py, backend/utils/llm/providers.py, backend/utils/mcp_client.py, backend/utils/other/hume.py, backend/utils/retrieval/tools/calendar_tools.py, desktop/windows/e2e/datasources.spec.mjs, desktop/windows/e2e/gpu-fallback.spec.mjs, desktop/windows/e2e/onboarding-layout.spec.mjs, desktop/windows/e2e/onboarding-permission.spec.mjs, desktop/windows/src/renderer/src/lib/analytics.ts, desktop/windows/src/renderer/src/lib/omiApi.generated.ts, mcp/src/mcp_server_omi/server.py, omi/firmware/scripts/devkit/play_sound_on_friend.py, plugins/hume-ai/app.py, plugins/import/manual-import/app.py, plugins/omi-dropbox-app/main.py, plugins/omi-github-app/agent_providers.py, plugins/omi-github-app/claude_code_agentic.py, plugins/omi-github-app/claude_coder.py, plugins/omi-github-app/issue_detector.py, plugins/omi-github-app/main.py, plugins/omi-google-calendar-app/main.py, plugins/omi-linear-app/main.py, plugins/omi-notion-app/main.py, plugins/omi-twitter-chat-tools-app/main.py, plugins/omi-whoop-app/main.py, sdks/python-cli/omi_cli/config.py, web/admin/lib/services/omi-api/omiApi.generated.ts, web/app/src/lib/omiApi.generated.ts, web/personas-open-source/src/lib/omiApi.generated.ts
- Target groups: -
- Read first: .github/scripts/test_check_deployment_secret_boundary.py, .github/scripts/test_publish_desktop_candidate_tag.py, backend/charts/backend-secrets/dev_omi_backend_secrets_values.yaml, backend/charts/backend-secrets/prod_omi_backend_secrets_values.yaml, backend/llm_gateway/routers/anthropic_messages.py, backend/routers/auth.py, backend/routers/google_calendar.py, backend/routers/integrations.py, backend/routers/mcp_sse.py, backend/routers/task_integrations.py, backend/scripts/smoke_mcp_chatgpt_review.py, backend/testing/e2e/test_task_integrations.py, backend/utils/conversations/calendar_linking.py, backend/utils/llm/clients.py, backend/utils/llm/gateway_anthropic.py, backend/utils/llm/providers.py, backend/utils/mcp_client.py, backend/utils/other/hume.py, backend/utils/retrieval/tools/calendar_tools.py, desktop/windows/e2e/datasources.spec.mjs, desktop/windows/e2e/gpu-fallback.spec.mjs, desktop/windows/e2e/onboarding-layout.spec.mjs, desktop/windows/e2e/onboarding-permission.spec.mjs, desktop/windows/src/renderer/src/lib/analytics.ts, desktop/windows/src/renderer/src/lib/omiApi.generated.ts, mcp/src/mcp_server_omi/server.py, omi/firmware/scripts/devkit/play_sound_on_friend.py, plugins/hume-ai/app.py, plugins/import/manual-import/app.py, plugins/omi-dropbox-app/main.py, plugins/omi-github-app/agent_providers.py, plugins/omi-github-app/claude_code_agentic.py, plugins/omi-github-app/claude_coder.py, plugins/omi-github-app/issue_detector.py, plugins/omi-github-app/main.py, plugins/omi-google-calendar-app/main.py, plugins/omi-linear-app/main.py, plugins/omi-notion-app/main.py, plugins/omi-twitter-chat-tools-app/main.py, plugins/omi-whoop-app/main.py, sdks/python-cli/omi_cli/config.py, web/admin/lib/services/omi-api/omiApi.generated.ts, web/app/src/lib/omiApi.generated.ts, web/personas-open-source/src/lib/omiApi.generated.ts
- Recommended strategy: manual-review

完了条件:
- 公開前に該当値を削除し、必要な値はサーバー側または安全な環境変数管理へ移す。

## omi-upstream-rebase-cloudflare-isolation-source-alignment-review: Story/Spec/ADR不整合をレビューする

- Source: source_alignment_finding / omi-upstream-rebase-cloudflare-isolation-source-alignment-review
- Execution: proposal_only / mutates_repository=false
- Target files: -
- Target groups: -
- Read first: -
- Recommended strategy: source-alignment-review

完了条件:
- 各潜在バグ候補について、Story/Spec/ADR/コードのどれを修正するか判断している
- Graphifyのhub/communityを読んだ上で影響範囲を説明できる
- 要件が正しい場合はレビュー済み理由を正本またはPR本文に残している

## VP-TASK-STATIC-003: XSS につながり得る DOM 操作がある

- Source: finding / VP-STATIC-003
- Execution: proposal_only / mutates_repository=false
- Target files: backend/database/redis_db.py, backend/database/sync_jobs.py, backend/migrations/002_populate_historical_usage.py, backend/migrations/003_report_top_transcription_users.py, backend/parakeet/gpu_worker.py, backend/parakeet/stream_handler.py, backend/parakeet/transcribe.py, backend/utils/fair_use.py, backend/utils/sync/backfill.py, plugins/composio/templates/notion_import.html, plugins/db.py, plugins/import/manual-import/index.html, plugins/iq_rating/main.py, plugins/omi-clickup-app/main.py, plugins/omi-slack-app/main.py, plugins/omi-twitter-app/main_simple.py, plugins/templates/chatgpt/index.html, plugins/templates/setup_zapier.html, plugins/templates/subscription/index.html, scripts/low_conv_high_transcription.py, scripts/transcription_vs_conversations.py
- Target groups: -
- Read first: backend/database/redis_db.py, backend/database/sync_jobs.py, backend/migrations/002_populate_historical_usage.py, backend/migrations/003_report_top_transcription_users.py, backend/parakeet/gpu_worker.py, backend/parakeet/stream_handler.py, backend/parakeet/transcribe.py, backend/utils/fair_use.py, backend/utils/sync/backfill.py, plugins/composio/templates/notion_import.html, plugins/db.py, plugins/import/manual-import/index.html, plugins/iq_rating/main.py, plugins/omi-clickup-app/main.py, plugins/omi-slack-app/main.py, plugins/omi-twitter-app/main_simple.py, plugins/templates/chatgpt/index.html, plugins/templates/setup_zapier.html, plugins/templates/subscription/index.html, scripts/low_conv_high_transcription.py, scripts/transcription_vs_conversations.py
- Recommended strategy: manual-review

完了条件:
- ユーザー入力をHTMLとして挿入しない。必要な場合はサニタイズし、textContentなど安全な代替を使う。