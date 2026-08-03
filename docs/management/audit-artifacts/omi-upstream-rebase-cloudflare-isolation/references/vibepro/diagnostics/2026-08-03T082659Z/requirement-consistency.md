# Requirement Consistency

| 項目 | 内容 |
|------|------|
| Status | pass |
| Invariants | 6 |
| Scenario Gaps | 0 |
| Contradictions | 0 |
| Scanned Code Files | 0 |
| Requirement Sources | 1 |
| Spec Refs | 0 |
| Architecture Refs | 1 |
| Policy Refs | 0 |
| Domain Contract Refs | 0 |
| Responsibility Authority Matches | 0 |
| Responsibility Authority Unknowns | 0 |
| Structured Inherited Behavior Declarations | 0 |
| Legacy Keyword Resolutions | 0 |

## Invariants

- REQ-INV-001: operator actionはdart-definesでWorker URLとtokenを設定することだけであり、既存Omi機能の振る舞いは変えない。 (story:docs/stories/omi-upstream-rebase-cloudflare-isolation.md)
- REQ-INV-002: 生成l10nはARB由来の派生物、local overlay documentは設定境界として扱い、Cloudflare側のデータ書込み経路を追加しない。 (story:docs/stories/omi-upstream-rebase-cloudflare-isolation.md)
- REQ-INV-003: timeout、non-2xx、malformed JSON、認可拒否はscoped UI errorとして当該画面に限定し、retry以外の書込み・WAL mutationを行わない。 (story:docs/stories/omi-upstream-rebase-cloudflare-isolation.md)
- REQ-INV-004: Firebase project、署名、entitlementのtracked製品設定への組込み (story:docs/stories/omi-upstream-rebase-cloudflare-isolation.md)
- REQ-SRC-001: Cloudflare APIを既存 backend/http/api/conversations.dart に追加：OSS会話APIの責務とWorker契約が混ざるため採用しない。 (architecture:docs/architecture/ADR-omi-upstream-rebase-cloudflare-isolation.md)
- REQ-SRC-002: dart-define のURL/tokenが未設定または不正なら機能は無効で、Cloudflare requestを送らず既存Omi会話表示を維持する。 (architecture:docs/architecture/ADR-omi-upstream-rebase-cloudflare-isolation.md)

## Scenario Gaps

- なし

## Potential Contradictions

- なし

## Structured Inherited Behavior Declarations

- なし

## Legacy Keyword Resolution Deprecations

- なし

## Requirement Sources

- architecture: docs/architecture/ADR-omi-upstream-rebase-cloudflare-isolation.md: ADR: Cloudflareセルフホスト差分をadapter境界へ隔離する

## Responsibility Authority

- status: not_generated
- matched responsibilities: 0
- matched contract clauses: 0
- missing evidence: 0
- stale evidence: 0
- unregistered candidates: 0
