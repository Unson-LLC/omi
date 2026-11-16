# Story: 録音の実時間で文字起こしを表示する

利用者として、会話の本文を実際の録音時間に沿って読みたい。30秒の音声をsequence番号から1秒として表示していたため、異なる区間を誤って短い間隔で表示していた。

## 受け入れ条件とSpec
- チャンクをsequence順に並べ、先行チャンクのduration_secondsを累積する。無音チャンクも含める。
- segments_jsonの局所start/endを累積時間へ加算する。負数、非有限値、逆転、duration超過、空本文を含むメタデータは採用しない。
- メタデータが一部でも不正ならチャンク全体のtextを保持し、既知の音声時間を使う。duration不明時は長さ0として保持し、1秒を作らない。不明区間以降の絶対時刻は保証できない。
- 認識本文、認証、アップロード、Worker側の保存データは書き換えない。

対象: brainbase_transcript_client.dart、brainbase_conversation_source.dart。対応する2つのサービス単体テストで順序、無音、局所時刻、メタデータ不正、本文保持を検証する。実機の表示確認は未実施。

Worker側の無音時誤生成は https://github.com/Unson-LLC/brainbase-omi/pull/4 で扱う。
