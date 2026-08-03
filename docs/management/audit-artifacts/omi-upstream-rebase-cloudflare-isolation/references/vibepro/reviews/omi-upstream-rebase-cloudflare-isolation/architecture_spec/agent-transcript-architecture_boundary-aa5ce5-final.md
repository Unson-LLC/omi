# architecture boundary 最終レビュー — strict HEAD `aa5ce5d`

- Story: `omi-upstream-rebase-cloudflare-isolation`
- Stage / role: `architecture_spec` / `architecture_boundary`
- Reviewer: independent Codex subagent (`gpt-5.6-terra`, high)
- Reviewed HEAD: `aa5ce5dea66e1c24364187c34eccd781ee7b0f31`
- Base: `upstream/main` `57ca482edc3bc14ce9bc90c2b46acf9f18daae88`
- Previous architecture review HEAD: `5fe478bbaf613f472642ce3011720f0f266e0fcd`
- Review mode: read-only。製品コードおよび別repoは変更していない。

```json
{
  "status": "pass",
  "summary": "aa5ce5d の architecture boundary は pass。Cloudflare は設定有効時だけの read-only GET 一覧/詳細に限定され、redirect は無効、WAL adapter は production 未接続の disabled/deferred no-op のままである。前回 strict HEAD からの差分は desktop changelog CI の harness 除外と review budget decision のみで、Cloudflare/WAL/会話UI/l10n/Story/ADR/spec の契約には差分がない。",
  "inspection_summary": "現HEAD、upstream/main...HEAD の122 path diff、前review HEADとの差分、Story/ADR/spec、Cloudflare設定/API/Provider/UI接続、既存WAL authority、ARB/生成l10n、focused tests、現HEADに直接bindされたunit/integration/typecheck/e2eの各artifactと生ログを直接確認した。",
  "inspection_evidence": "unit/integration/typecheck/e2e は全て runner_direct、head_sha/head_sha_before/head_sha_after=aa5ce5d、exit 0、tree/head/worktree不変、非truncate。unit/integration/e2e の各logに42 focused tests passと6 dart-define WAL scenarios pass、typecheck logに No issues found! を確認。",
  "inspection_inputs": [
    "git rev-parse HEAD; git merge-base upstream/main HEAD; git diff upstream/main...HEAD; git diff --check upstream/main...HEAD",
    "git diff 5fe478bbaf613f472642ce3011720f0f266e0fcd..aa5ce5dea66e1c24364187c34eccd781ee7b0f31",
    ".github/scripts/check-desktop-changelog.py; .github/scripts/test_desktop_changelog.py",
    "docs/management/decisions/2026-08-03-budget-override-omi-upstream-rebase-cloudflare-isolation-c26d8124.md",
    "docs/stories/omi-upstream-rebase-cloudflare-isolation.md",
    "docs/specs/omi-upstream-rebase-cloudflare-isolation.md",
    "docs/architecture/ADR-omi-upstream-rebase-cloudflare-isolation.md",
    "app/lib/self_hosted/cloudflare/cloudflare_transcript_configuration.dart",
    "app/lib/self_hosted/cloudflare/cloudflare_transcript_api.dart",
    "app/lib/self_hosted/cloudflare/cloudflare_transcript_provider.dart",
    "app/lib/self_hosted/cloudflare/cloudflare_transcripts_page.dart",
    "app/lib/self_hosted/sync/self_hosted_wal_sync_adapter.dart",
    "app/lib/main.dart; app/lib/pages/conversations/conversations_page.dart; app/lib/pages/conversations/widgets/conversations_section_header.dart",
    "app/lib/services/wals/local_wal_sync.dart; app/lib/services/wals/wal_syncs.dart; app/lib/services/wals/sync_reconciler.dart",
    "app/lib/l10n/app_*.arb; app/lib/l10n/app_localizations*.dart",
    "app/test/self_hosted/cloudflare/*.dart; app/test/self_hosted/sync/*.dart",
    ".vibepro/verification/Makefile",
    ".vibepro/pr/omi-upstream-rebase-cloudflare-isolation/verification-runs/{unit,integration,typecheck,e2e}.{json,log}",
    ".vibepro/pr/omi-upstream-rebase-cloudflare-isolation/pr-prepare.json"
  ],
  "judgment_delta": [
    "懸念: 5fe478b からの最終再ベースがCloudflare/WAL/既存データ経路を変える可能性。結論: 厳密差分はdesktop changelogのCI harness除外2ファイルと、review budget decision 1ファイルだけで、app、focused tests、Story/ADR/spec、ARB/生成l10nには差分なし。",
    "懸念: 現HEADで過去の検証artifactが古くなり、boundary passの根拠にならない可能性。結論: 4 laneすべてをrunner_directかつaa5ce5d前後一致のartifact/logで再確認した。unit/integration/e2eは42 focused testsと6 define cases、typecheckは変更対象のanalyzerを直接実行している。",
    "懸念: 外部Worker read integrationがwrite権限、unsafe URL、redirect追従、または既存WAL所有権へ漏れる可能性。結論: 唯一のHTTP request constructionはGETでfollowRedirects=false/maxRedirects=0、configはtoken・HTTPS/loopback HTTP・credentials/query/fragment不許可を強制し、adapterはdisabled/deferredだけを返してproduction callerを持たない。",
    "懸念: l10n生成物とe2eという名称が実機/deployed proofを暗黙に昇格させる可能性。結論: 49 ARBに3 key、50生成Dartに対応実装を確認し、ADRのARB正本契約と一致する。Makefileはe2eをhermetic integration compatibility aliasと明記し、実機/deployed証拠ではない。"
  ],
  "findings": []
}
```

## boundary 判定

### Cloudflare read-only / config-gated

`CloudflareTranscriptConfiguration` は空tokenを無効化し、HTTPSまたはloopback HTTP以外、credentials、query、fragmentを拒否する。未設定・不正設定時はAPIがlistを空、detailを安全な例外で閉じ、HTTPを発行しない。`CloudflareTranscriptHttpApi` の唯一のHTTP request作成は `GET` であり、`followRedirects=false` と `maxRedirects=0` を設定する。list/detailの非2xx、timeout、不正JSON、response shape不正は非秘密値の例外へfail-closedする。`POST`、upload、ack、deleteの実装は確認されない。

### 既存データ/WAL/OSSの責務

`database_state`/`databaseState`、schema、migration、既存 `app/lib/services/wals`、capture、sync providerの変更は committed diff にない。`NoopSelfHostedWalSyncAdapter` は `disabled` または `deferred` のみを返し、upload/acknowledgeをしないことを実装・コメントともに明記する。参照は実装自身とfocused testに限られ、`LocalWalSyncImpl`、`WalSyncs`、reconciler、captureからproduction接続されていない。既存OSSへの変更はProvider compositionとConversations入口だけである。

### UI / l10n / test surface

`main.dart` はCloudflare Providerをcomposition rootへ追加し、Conversations headerは設定有効時だけCloudflare入口を表示する。focused widget/provider testsはOmi-zero、disabled時の既存header、daily-summary、invalid config、empty/error/retry、localized semanticsをカバーする。49 ARB sourceすべてにCloudflare 3 keyがあり、50 generated localization Dart outputとabstract localization contractに対応する。ADRはARBを正本、Dartを機械生成物と定義しており、実装と一致する。

## 現HEAD検証証跡

| Lane | 実行結果 | strict HEAD binding | 境界 |
| --- | --- | --- | --- |
| unit | 42 focused tests + 6 define scenarios pass | aa5ce5d前後一致、worktree不変 | hermetic |
| integration | 42 focused tests + 6 define scenarios pass | aa5ce5d前後一致、worktree不変 | hermetic integration |
| typecheck | changed Flutter surfaces: `No issues found!` | aa5ce5d前後一致、worktree不変 | static |
| e2e | 42 focused tests + 6 define scenarios pass | aa5ce5d前後一致、worktree不変 | Makefile上はintegration compatibility alias |

各laneには managed-worktree-locality（required=false）とtest-count parserのwarningが残る。artifact rootと実行root、expected/current HEAD は一致し、生ログからtest件数を直接確認した。warningを消去・成功扱いに置換していない。

## 全体gateと未確認境界

`pr-prepare.json` の `overall_status=needs_verification` / `ready_for_pr_create=false` は、他stageのstrict-head review/gate evidence未更新による全体PR readinessの状態である。本roleのsource/spec/architecture passをPR作成・release承認へ昇格しない。

物理iPhone、実機VoiceOver、deployed Cloudflare Worker、production telemetry/customer outcome、録音からupload/ack/deleteまでのWAL lifecycleは **未確認**。このレビューのhermetic test/e2e alias、HTTP 200、build/analyze成功から、それらの完了を主張しない。

レビュー開始時には既存のuncommitted `.gitignore` 変更を観測したが、変更も評価対象への取り込みもしていない。最終確認時の対象worktreeはcleanである。commit-tree判定は厳密に `aa5ce5d` に固定する。
