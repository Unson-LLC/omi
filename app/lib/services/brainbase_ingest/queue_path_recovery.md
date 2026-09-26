# R2 音声キューの保存先復旧

## Story
アプリの更新後も、端末に残った音声の転送を再開できる。

## Spec・受け入れ条件
- 新しい manifest はキューディレクトリからのファイル名を保存する。
- 既存の相対ファイル名と旧アプリコンテナの絶対パスは、現在のキューディレクトリ内の同じファイルへ解決する。
- キュー外のファイルを読み取り・削除しない。
- ファイルが見つからない場合や転送が失敗した場合、キューと音声を保持する。
- complete 成功後にのみファイルと項目を削除する。
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

## 影響範囲
独自 R2 音声キューの永続化と復旧。通常 WAL、認証先、音声形式、BLE 接続は変更しない。
