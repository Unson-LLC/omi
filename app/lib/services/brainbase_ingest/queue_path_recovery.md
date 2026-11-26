# R2 音声キューの保存先復旧

## Story
アプリの更新後も、端末に残った音声の転送を再開できる。

## Spec・受け入れ条件
- 新しい manifest はキューディレクトリからのファイル名を保存する。
- 既存の相対ファイル名と旧アプリコンテナの絶対パスは、現在のキューディレクトリ内の同じファイルへ解決する。
- キュー外のファイルを読み取り・削除しない。
- 転送が失敗した場合、キューと音声を保持する。
- complete 成功後にのみ項目を削除する。項目を除いた manifest の保存を先に終え、そのあとで音声を削除する。
  保存と削除の間でプロセスが終わっても、残るのは参照されない音声だけになる。
- キューを開くとき、manifest のどの項目も参照しない `.wav`（キューディレクトリ直下の通常ファイルのみ）を削除する。
  シンボリックリンクと `.wav` 以外は触らない。
- 項目の音声がローカルに無い場合は presign で照合する。`alreadyUploaded` なら complete を送り直して項目を回収する。
  未アップロードなら `corruptedItems` に移して manifest に残し、後続のチャンクの転送を止めない。
  presign や complete が恒久的な 4xx を返した場合も同じく `corruptedItems` に移す。5xx・通信失敗・401・403・408・425・429 は項目を残して再試行する。
  パスが不正な項目やシンボリックリンクは、これまでどおり項目を保持して転送を止める。
- finalize が恒久的な 4xx（401・403・408・425・429 を除く）で拒否された session は `rejectedFinalizeSessions` に移し、
  再試行しない。5xx と通信失敗は finalize intent を保持して再試行する。
- 移動前の manifest を再読込する回帰テストで、転送するバイトと削除対象を確認する。
- upload session の作成成功後は `activeSessionId` を manifest に保存する。
- queue の再オープン時は、音声が生成済みの前プロセスの `activeSessionId` と、旧 manifest に残った item の
  `sessionId` を finalize intent に回収してから新しい session を開始する。
- active session は、明示的な停止で finalize intent に移るまで finalize しない。未送信 item が
  残る間は finalize を実行せず、finalize の失敗も intent を保持して再試行する。
- item がすべて削除済みで、active marker と finalize intent のどちらもない旧 session は、
  remote の session ID を安全に推測できないため自動回復しない。

- 音声がない active session は停止・再起動時に破棄し、空セッションの finalize エラーで後続処理を止めない。
- 全音声が転送済みでも active marker を保持し、再起動後に finalize する。
- manifest は一時ファイルからの置換で保存し、既存ファイルを先に削除しない。
- アプリ起動時は録音や BLE 再接続を待たずに `resumePendingUploads()` を呼び、既存キューを一度だけ開いて
  retry timer と drain を開始する。起動処理はこのネットワーク処理を待たず、設定が無効なら何もしない。
- `resumePendingUploads()` と `start()` は drain を待たない。`_serial` に載るのはローカルのキューを開く処理だけで、
  転送中や応答待ちの drain があっても `start()` は 250ms 以内に戻る。manifest の保存は p95 で 25ms 以内。
- drain の実行中に来た drain の要求は捨てずに覚えておき、実行中の drain が正常に終わったらもう1回まわす。
  エラーで止まった drain は retry timer に任せる。

## 影響範囲
独自 R2 音声キューの永続化と復旧。通常 WAL、認証先、音声形式、BLE 接続は変更しない。
