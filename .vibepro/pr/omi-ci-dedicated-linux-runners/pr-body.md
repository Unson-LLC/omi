## omi CI を専用 self-hosted Linux runner (wsl-linux-7/-8) のみに寄せる

Story: `omi-ci-dedicated-linux-runners`
SSOT: local

### 成果ケース連携
- 状態: `none`
- 理由コード: `not_linked`

### VibePro runtime identity
- package: `vibepro@0.2.0-beta.30`
- source: `npm_package` at `/Volumes/UNSON-DRIVE/codex-runtime-staging/node-caches/npm-cache/_npx/e0f82dd780a6134d/node_modules/vibepro`
- entrypoint: `/Volumes/UNSON-DRIVE/codex-runtime-staging/node-caches/npm-cache/_npx/e0f82dd780a6134d/node_modules/vibepro/bin/vibepro.js`
- source SHA: `34f5dea61e97730e464999da83a6ecba9f2e09b5`
- identity digest: `6fd7c55d09ca635d77807bf2ccc4415100d29b3dac2d77d9236206b1a97280aa`

### Story document
- no story document found (informational only; does not block PR creation)

### Acceptance criteria
- no acceptance criteria found in the story document

### Spec
- no accepted spec found for this story

### Semantic sufficiency
- answer resolution: `unavailable`
- automatic continuation: `false`
- counterexample status: `unavailable`
- warnings: none
- outcome coverage:
  - internal_output: `unknown` (declared=0, answer_resolved=0, verification=unknown)
  - downstream_outcome: `unknown` (declared=0, answer_resolved=0, verification=unknown)
  - canonical_readback: `unknown` (declared=0, answer_resolved=0, verification=unknown)

### Multi-tenant architecture
- status: not_applicable

### Verification evidence
- [unit] pass — `pytest -q .github/scripts/test_plan_desktop_release.py .github/scripts/test_desktop_windows_ci_contract.py .github/scripts/test_check_ci_budget.py .github/scripts/test_check_runner_cost_policy.py` (runtime `6fd7c55d09ca635d77807bf2ccc4415100d29b3dac2d77d9236206b1a97280aa`)
  - 自由記述summaryは参考情報であり、計算済み件数の権威ではありません

### タスク権限
- 人間作成タスク: 未検出
- 受理済みauthority: 未検出
- 生成proposal: 未検出

### Development Judgment
- available: false
- status: not_recorded
- lifecycle: not_started
- applicable: not_recorded
- input adopted: false
- actionable: false
- advisory: true
- blocking: false
- plan binding: none
- plan effect: no_effect
- disposition: none
- disposition effect: none
- pending disposition: false
- pending outcome: false
- next: vibepro judgment applicability record . --id omi-ci-dedicated-linux-runners --applicable yes|no --reason <text>

### Review
- recorded: false
- complete: false
- status: not_recorded
- blocking reasons: none

### Changed files
- A	.agent-artifacts/sync-lineage-dedupe/AUDIO-COVERAGE-DESIGN.md
- A	.agent-artifacts/ui-evidence/11801/001-desktop-macos-wake-word-enabled.png
- A	.agent-artifacts/ui-evidence/11801/002-desktop-macos-before-wake-word.png
- A	.agent-artifacts/ui-evidence/11801/evidence.json
- A	.agent-artifacts/ui-evidence/11864/001-desktop-macos-silence-notifications-setting.png
- A	.agent-artifacts/ui-evidence/11864/evidence.json
- A	.agent-artifacts/ui-evidence/20647/001-mobile-android-import-transcript-files.png
- A	.agent-artifacts/ui-evidence/20647/evidence.json
- A	.agent-artifacts/ui-evidence/20874/001-mobile-ios-offline-sync-before-top.png
- A	.agent-artifacts/ui-evidence/20874/002-mobile-ios-offline-sync-before-middle.png
- A	.agent-artifacts/ui-evidence/20874/003-mobile-ios-offline-sync-before-bottom.png
- A	.agent-artifacts/ui-evidence/20874/004-mobile-ios-offline-sync-after.png
- A	.agent-artifacts/ui-evidence/20874/005-mobile-ios-offline-sync-after-files.png
- A	.agent-artifacts/ui-evidence/20874/006-mobile-ios-offline-sync-simulator-list.png
- A	.agent-artifacts/ui-evidence/20874/007-mobile-ios-offline-sync-simulator-files.png
- A	.agent-artifacts/ui-evidence/20874/evidence.json
- A	.agent-artifacts/ui-evidence/20909-task-assistant-credit/001-desktop-macos-reported-credit-error.png
- A	.agent-artifacts/ui-evidence/20909-task-assistant-credit/002-desktop-macos-credit-recovery-fixture.png
- A	.agent-artifacts/ui-evidence/20909-task-assistant-credit/evidence.json
- A	.agent-artifacts/ui-evidence/20917/001-mobile-ios-onboarding-speech-skip-to-setup.png
- A	.agent-artifacts/ui-evidence/20917/002-mobile-ios-onboarding-speech-profile-step.png
- A	.agent-artifacts/ui-evidence/20917/evidence.json
- A	.agent-artifacts/ui-evidence/20985/001-mobile-ios-speak-into-omi-light.png
- A	.agent-artifacts/ui-evidence/20985/002-mobile-ios-ask-a-question-light.png
- A	.agent-artifacts/ui-evidence/20985/003-mobile-ios-turn-off-light.png
- A	.agent-artifacts/ui-evidence/20985/004-mobile-ios-double-tap-light.png
- A	.agent-artifacts/ui-evidence/20985/005-mobile-ios-all-set-light.png
- A	.agent-artifacts/ui-evidence/20985/006-mobile-ios-turn-off-dark.png
- A	.agent-artifacts/ui-evidence/20985/007-mobile-ios-double-tap-dark.png
- A	.agent-artifacts/ui-evidence/20985/008-mobile-ios-rating-prompt-light.png
- A	.agent-artifacts/ui-evidence/20985/evidence.json
- A	.agent-artifacts/ui-evidence/21001/001-mobile-ios-first-summary-enjoying-ask.png
- A	.agent-artifacts/ui-evidence/21001/002-mobile-ios-native-rating-sheet-after-yes.png
- A	.agent-artifacts/ui-evidence/21001/evidence.json
- A	.agent-artifacts/ui-evidence/21084/001-mobile-ios-conversation-opened.png
- A	.agent-artifacts/ui-evidence/21084/002-mobile-ios-enjoying-omi-ask-1s.png
- A	.agent-artifacts/ui-evidence/21084/evidence.json
- A	.agent-artifacts/ui-evidence/21101/001-mobile-ios-settings-device-no-phone-calls.png
- A	.agent-artifacts/ui-evidence/21101/002-mobile-ios-record-button-no-options-badge.png
- A	.agent-artifacts/ui-evidence/21101/003-mobile-ios-pendant-sheet-no-phone-call.png
- A	.agent-artifacts/ui-evidence/21101/evidence.json
- A	.agent-artifacts/ui-evidence/agent-connect-ingress/001-web-developers-home.png
- A	.agent-artifacts/ui-evidence/agent-connect-ingress/002-web-oauth-prompt-expanded.png
- A	.agent-artifacts/ui-evidence/agent-connect-ingress/003-web-mcp-key-created-handoff.png
- A	.agent-artifacts/ui-evidence/agent-connect-ingress/004-web-mcp-key-secure-prompt.png
- A	.agent-artifacts/ui-evidence/agent-connect-ingress/005-web-key-fallback-warning.png
- A	.agent-artifacts/ui-evidence/agent-connect-ingress/006-web-dev-api-secure-prompt.png
- A	.agent-artifacts/ui-evidence/agent-connect-ingress/007-web-profile-menu-no-developer-row.png
- A	.agent-artifacts/ui-evidence/agent-connect-ingress/008-web-mobile-width-developers.png
- A	.agent-artifacts/ui-evidence/agent-connect-ingress/009-web-mobile-width-secure-prompt.png
- A	.agent-artifacts/ui-evidence/agent-connect-ingress/010-desktop-macos-settings-connect-agent.png
- A	.agent-artifacts/ui-evidence/agent-connect-ingress/011-desktop-macos-connect-sheet-developer-link.png
- A	.agent-artifacts/ui-evidence/agent-connect-ingress/012-mobile-ios-settings-connect-agent-row.png
- A	.agent-artifacts/ui-evidence/agent-connect-ingress/013-mobile-ios-developer-settings-header.png
- A	.agent-artifacts/ui-evidence/agent-connect-ingress/evidence.json
- A	.agent-artifacts/ui-evidence/android-auth-integration-hangs/001-mobile-android-referral-retry.png
- A	.agent-artifacts/ui-evidence/android-auth-integration-hangs/002-mobile-android-referral-browser.png
- A	.agent-artifacts/ui-evidence/android-auth-integration-hangs/003-mobile-android-integration-retry.png
- A	.agent-artifacts/ui-evidence/android-auth-integration-hangs/004-mobile-android-integration-auth-pending.png
- A	.agent-artifacts/ui-evidence/android-auth-integration-hangs/evidence.json
- A	.agent-artifacts/ui-evidence/anthropic-byok-billing/001-desktop-macos-reported-billing-copy.png
- A	.agent-artifacts/ui-evidence/anthropic-byok-billing/evidence.json
- A	.agent-artifacts/ui-evidence/chat-edit-receipts-item-links/001-mobile-ios-chat-edit-receipts-dark.png
- A	.agent-artifacts/ui-evidence/chat-edit-receipts-item-links/002-mobile-ios-chat-edit-receipts-after-undo.png
- A	.agent-artifacts/ui-evidence/chat-edit-receipts-item-links/003-mobile-ios-chat-edit-receipts-light.png
- A	.agent-artifacts/ui-evidence/chat-edit-receipts-item-links/004-web-item-link-fallback-iphone.png
- A	.agent-artifacts/ui-evidence/chat-edit-receipts-item-links/005-web-item-link-fallback-desktop.png
- A	.agent-artifacts/ui-evidence/chat-edit-receipts-item-links/evidence.json
- A	.agent-artifacts/ui-evidence/dream-report-mobile/001-mobile-android-dream-report-latest-pass.png
- A	.agent-artifacts/ui-evidence/dream-report-mobile/002-mobile-android-dream-report-older-passes.png
- A	.agent-artifacts/ui-evidence/dream-report-mobile/003-mobile-android-dream-report-light.png
- A	.agent-artifacts/ui-evidence/dream-report-mobile/004-mobile-android-dream-report-empty.png
- A	.agent-artifacts/ui-evidence/dream-report-mobile/evidence.json
- A	.agent-artifacts/ui-evidence/dream-review-context/001-mobile-ios-spelling-card.png
- A	.agent-artifacts/ui-evidence/dream-review-context/002-mobile-ios-spelling-context.png
- A	.agent-artifacts/ui-evidence/dream-review-context/evidence.json
- A	.agent-artifacts/ui-evidence/dream-review-mobile/001-mobile-android-home-review-entry-card.png
- A	.agent-artifacts/ui-evidence/dream-review-mobile/002-mobile-android-review-question-cards.png
- A	.agent-artifacts/ui-evidence/dream-review-mobile/003-mobile-android-sheet-who-said-this.png
- A	.agent-artifacts/ui-evidence/dream-review-mobile/004-mobile-android-sheet-task-dismiss-reasons.png
- A	.agent-artifacts/ui-evidence/dream-review-mobile/005-mobile-android-sheet-same-person.png
- A	.agent-artifacts/ui-evidence/dream-review-mobile/006-mobile-android-conversation-chips-inline-question.png
- A	.agent-artifacts/ui-evidence/dream-review-mobile/007-mobile-android-person-page.png
- A	.agent-artifacts/ui-evidence/dream-review-mobile/008-mobile-android-organization-page.png
- A	.agent-artifacts/ui-evidence/dream-review-mobile/009-mobile-android-project-page.png
- A	.agent-artifacts/ui-evidence/dream-review-mobile/010-mobile-android-recent-changes.png
- A	.agent-artifacts/ui-evidence/dream-review-mobile/011-mobile-android-tasks-grouped-by-project.png
- A	.agent-artifacts/ui-evidence/dream-review-mobile/012-mobile-android-review-caught-up.png
- A	.agent-artifacts/ui-evidence/dream-review-mobile/evidence.json
- A	.agent-artifacts/ui-evidence/dream-suggestions-mobile/001-mobile-android-review-dream-suggestions.png
- A	.agent-artifacts/ui-evidence/dream-suggestions-mobile/002-mobile-android-review-dream-suggestions-light.png
- A	.agent-artifacts/ui-evidence/dream-suggestions-mobile/003-mobile-android-dream-suggestion-sheet.png
- A	.agent-artifacts/ui-evidence/dream-suggestions-mobile/004-mobile-android-dream-suggestion-sheet-light.png
- A	.agent-artifacts/ui-evidence/dream-suggestions-mobile/evidence.json
- A	.agent-artifacts/ui-evidence/item-list-links-macos/001-desktop-macos-item-list-light.png
- A	.agent-artifacts/ui-evidence/item-list-links-macos/002-desktop-macos-item-list-dark.png
- A	.agent-artifacts/ui-evidence/item-list-links-macos/003-desktop-macos-item-list-loading.png
- A	.agent-artifacts/ui-evidence/item-list-links-macos/004-desktop-macos-item-list-empty.png
- A	.agent-artifacts/ui-evidence/item-list-links-macos/evidence.json
- A	.agent-artifacts/ui-evidence/items-list-link/001-mobile-ios-item-list-sheet-dark.png
- ... and 6714 more

