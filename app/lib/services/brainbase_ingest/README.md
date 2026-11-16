# Brainbase R2 ingest lane

This optional personal-use lane mirrors Omi BLE audio into 30-second WAV
chunks. Chunks are written to app support storage before upload, retried after
network failures or app restarts, and deleted only after the Worker confirms
them. Omi's existing WAL and WebSocket paths remain authoritative and do not
wait for this network lane.

Enable it at build time:

```bash
flutter run \
  --dart-define=BRAINBASE_INGEST_URL=https://brainbase-omi-ingest.unson.workers.dev \
  --dart-define=BRAINBASE_INGEST_TOKEN="$BRAINBASE_INGEST_TOKEN"
```

If either define is absent, the lane is a no-op. Do not commit the token. A
`dart-define` secret can be extracted from a distributed application binary,
so this authentication model is only suitable for the owner's private build.
Replace it with device registration and short-lived credentials before any
third-party distribution.

## 保存済み音声の同期

VibePro Story: `omi-offline-sync-recovery`

個人用 `local_dev` ビルドでは、同じ `BRAINBASE_INGEST_URL` / token を
保存済みWALの送信と完了確認にも使う。標準OmiのAPI設定を書き換えず、
`SyncUploadGate` のアカウント境界と送信の直列化を維持する。
production系プロファイルの送信先は変更しない（INV-DATA-1）。

受入条件:

- S-001: 保存済み音声をWorkerへ送信し、`cloudflare:` ジョブを同じWorkerで照合する。
- S-002: 対象セッションの `transcribed` 確認後だけ同期済みにする。
  空の文字起こしも正常な完了として扱う。認証失敗、404、通信障害、不明な状態では
  音声とジョブIDを保持する。
- S-003: 再試行用の記録を端末に保存し、同じ送信の再開時は既存セッションを使う。
  元の録音時刻と音声形式を引き継ぐ。
- S-004: デバイスからの転送率は実際の転送進捗を表示する。
  クラウドへの未送信件数をデバイス転送の母数として引き継がない。

この変更は既存の文字起こし本文を書き換えない。サーバーから完了を確認できない
音声を消すこともない。ロールバック時は `cloudflare:` ジョブと音声を保持し、
完了照合に対応したビルドで再開する。
