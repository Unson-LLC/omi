# omi CI を専用 self-hosted Linux runner (wsl-linux-7/-8) のみに寄せる

## Problem Frame

2026-10-15 16:20 から、omi リポジトリが使える runner は runner group `omi-dedicated` の
`nucbox-evo-x2-wsl-linux-7` と `nucbox-evo-x2-wsl-linux-8` の2台だけになった（ラベルは
`self-hosted, Linux, X64, wsl-linux, ...`）。PR #13 の時点では次の job が、この2台では拾われない。

- `[self-hosted, Windows]` を指定した job が4つ（`desktop-windows-ci.yml/build-windows`、
  `python-cli-ci.yml/windows-acl`、`windows-preflight-portability.yml/portability`、
  `desktop_windows_release.yml/build-and-publish`）。omi から使える Windows runner は無いので、
  キューに永遠に残る。
- `ubuntu-latest`（GitHub-hosted）のまま残っていた `desktop_auto_release.yml/plan-and-tag`。

## Constraints

- runner を指すラベルは既存と同じ `[self-hosted, Linux, wsl-linux]` を使う。omi に許可された
  runner group は `omi-dedicated`（wsl-linux-7/-8）だけなので、このラベルで他の runner には届かない。
- runner の操作・キューの操作はしない（Maintainer の担当）。push は1回、draft のまま、手動の再実行なし。
- macOS / Xcode の job（`desktop-swift-ci.yml`、`mobile-app-checks.yml` の iOS、
  `onboarding_figma_sync.yml`）は Linux では動かないので、今回は変えない。
- `.github/ci-budget.yaml` の inventory と契約テストは workflow と一致させる。

## Options

1. **4つの Windows job を削除し、`ubuntu-latest` を `[self-hosted, Linux, wsl-linux]` に置き換える（採用）。**
   job が1つだけの `windows-preflight-portability.yml` はファイルごと削除。
   `desktop_windows_release.yml` は `plan-and-tag` だけが残るので、fork では dispatch しないよう注記する。
   Windows の build ステップを読んでいた vitest 2件と、`ubuntu-latest` を期待していた契約テストを合わせて直す。
2. Windows job を `if: false` で止めて残す。ラベルが残り、キュー待ちの誤解と inventory のずれが続くので不採用。
3. `desktop_windows_release.yml` 全体を削除する。plan-and-tag（Linux）まで消えるため、指示の範囲を超えるので今回は見送り、判断を Director に残す。

### 2026-10-15 Director 決定の反映
- `desktop_windows_release.yml` はファイルごと削除した（PR 内の変更なので戻せる）。参照していた checks-manifest・desktop-windows-ci の paths・ci-budget も更新した。
- `desktop_auto_release.yml` は毎時の schedule をやめ、workflow_dispatch のみにした。アプリのキーを使う処理を共有 self-hosted で自動実行しないため。契約テスト `test_auto_release_is_manual_dispatch_only` に置き換えた。
- macOS・Xcode の job は触っていない。例外の候補で、佐藤さんの判断待ち。
