# Gate evidence final review — aa5ce5d

## 結論

**NEEDS_CHANGES**。これは製品実装の機能不良を示す結論ではなく、VibePro の
PR readiness evidence が strict HEAD `aa5ce5dea66e1c24364187c34eccd781ee7b0f31`
に対して整合していないためのゲート不通過である。`pr-prepare.json` は
`overall_status=needs_verification`、`pr_create_allowed=false`、未解決
`blocking_gate_count=7` を報告している。したがって、この状態で PR を作成しては
ならない。

## 対象と固定条件

- worktree: `/Users/ksato/workspace/code/.worktrees/omi-worktrees/omi-upstream-rebase-cloudflare-isolation`
- strict HEAD: `aa5ce5dea66e1c24364187c34eccd781ee7b0f31`
- base: `upstream/main@57ca482edc3bc14ce9bc90c2b46acf9f18daae88`
- 比較差分: 122 paths。分類は Make 1 / ARB 49 / generated l10n 50 / runtime 7 / tests 6 / docs 6 / wiring 3。
- `git status --porcelain=v1` は空、`git diff --check upstream/main...HEAD` は無出力。
- このレビューでは製品、Git、VibePro の状態を変更していない。保存した変更は本トランスクリプトだけである。

## 確認できた肯定的な証拠

1. `verification-runs/{unit,integration,typecheck,e2e}.json` はいずれも
   `status=pass`、`exit_code=0`、`evidence_source=runner_direct`、HEAD の前後が
   strict HEAD と一致し、worktree の hash/status も前後で不変、timeout/truncation
   なしである。
2. 直接ログは unit/integration/e2e で Cloudflare API の malformed JSON と
   non-object session 拒否を含む 42 tests pass、および6本の WAL シナリオをそれぞれ
   pass と記録する。typecheck は `Analyzing 5 items` / `No issues found`。
3. 実装・テスト・Story/spec/ADR は、HTTPS または loopback HTTP の設定 gate、
   `GET`、redirect 無追従、`transcript_char_count` 優先、WAL の upload/ack/delete
   を行わない no-op を整合して記述する。差分に native/Firebase/Worker 実装や秘密値の
   追加は確認されなかった。
4. 現在 HEAD に束縛された visual residual は2件とも clean worktree で `pass`、
   MAE 0% である（`omi-cloudflare-current` は閾値0%、story ID は閾値5%）。

## Findings

### P1 — 集約 verification evidence は runner-direct 証跡として使えない

`verification-evidence.json` の e2e 記録は `evidence_source=self_reported` であり、
`verify record --artifact` が runner artifact から与えられた `evidence_source=runner_direct`、
HEAD、worktree hash、log/timeout 等の caller keys を拒否した警告を保持している。
個別の `verification-runs/*.json` は current strict HEAD に対する直接実行の肯定証拠だが、
この自己申告の集約記録へコピーして runner-direct とみなすことはできない。

**必要な是正:** 同一 clean worktree と strict HEAD で VibePro の `verify run` 経路を
用いて必要な command を再記録し、自己申告 artifact を介さず current aggregate evidence
を再生成する。その後に `pr prepare` を再実行する。

### P1 — readiness SoT の7ゲートが未解決で、gate review も stale

`pr-prepare.json` は Common Judgment Spine（`current_reality`、`failure_modes`、
`done_evidence` 不足）、Visual QA の stale binding（別の dirty worktree fingerprint）、
strict HEAD が旧 `52ff0989b747` の gate_evidence / pr_split_scope、agent review、
artifact consistency、dispatch preflight を未解決としている。Visual residual 2件は
current clean HEAD に束縛されているが、readiness SoT の参照を自動的に置換しない。

**必要な是正:** current residual を authoritative な visual evidence として再照合し、
Common Judgment Spine の3要素を current source/run evidence に結び付ける。strict HEAD
`aa5ce5d` で gate_evidence と pr_split_scope を記録し、`pr prepare` 後に
`pr_create_allowed=true` と未解決 block がないことを確認する。scope は
`needs_clean_branch` / `clean_branch_or_split_pr` のため、別途 split 判断を完了する。

## 境界と未確認

- 現行 e2e は Makefile の compatibility alias で、deployed Worker、物理 iPhone、
  VoiceOver、production runtime の E2E を実証しない。
- GET-only、設定 gate、redirect 無効、WAL no-op はコードとローカル runner の証拠。
  外部通信、永続化、クラウド実行の成功を意味しない。
- Architecture / runtime / preview の current role evidence は肯定的だが、PR作成判断は
  `pr-prepare.json` の readiness SoT を優先する。

## 判断差分

前回 strict HEAD `52ff0989b747` に対する gate evidence は新 HEAD へ継承できない。
今回 `aa5ce5d` の直接 runner artifacts と2件の clean residual は追加の肯定証拠だが、
集約 self-reported artifact、Common Judgment Spine、visual binding、split gate が未解決の
ため、最終判定は PASS から **NEEDS_CHANGES** となる。
