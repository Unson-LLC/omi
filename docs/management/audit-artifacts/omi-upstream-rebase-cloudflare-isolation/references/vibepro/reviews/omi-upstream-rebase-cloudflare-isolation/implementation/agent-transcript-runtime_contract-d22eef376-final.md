# runtime_contract review transcript

- Story: `omi-upstream-rebase-cloudflare-isolation`
- Stage/role: `implementation:runtime_contract`
- Agent: `/root/omi_gate_evidence_review`
- Model: `gpt-5.6-terra` / high
- Session: `final-frozen-runtime-contract-d22eef376`
- HEAD: `d22eef376b0281f782de2dbadbb0528f431c5238`
- Judgment: `needs_changes`

## Summary

read-only list/detail、明示的 no-op WAL、OSS fallback、dart-define opt-in、ARB/l10n、release/rollback 境界は成立している。一方で、Worker schema の整数制約と transport 失敗時の安全な domain-error 境界に2件の契約差分がある。

## Findings

1. `sequence-type-contract-is-not-enforced` (medium)
   - `chunk.sequence` は JSON integer が契約だが、`int.tryParse(value.toString())` により数値文字列を受理する。
   - `value is int` に限定し、文字列・null・小数・boolを拒否する contract test が必要。
2. `raw-transport-errors-can-cross-the-scoped-safe-error-boundary` (medium)
   - `TimeoutException` と `FormatException` 以外の transport 例外が raw のまま Provider/UI へ伝播し得る。
   - 既知の domain exception は維持し、それ以外を固定・値なしの `CloudflareTranscriptApiException` に変換し、token/URL/request/response値がUI文字列へ出ない回帰テストが必要。

## Evidence boundary

全76 changed paths と current frozen HEAD の unit/integration/e2e/typecheck 証拠を確認した。物理 iPhone と deployed Worker は未確認のままであり、hermetic test や HTTP/build を実機・デプロイ成功へ昇格していない。

## Judgment delta

current-HEAD verification は green だったが、Specとの独立照合で未網羅の2契約差分を確認したため、PASS候補から `needs_changes` へ変更した。修正範囲は Cloudflare read module と追加回帰テストに限定でき、blockではない。
