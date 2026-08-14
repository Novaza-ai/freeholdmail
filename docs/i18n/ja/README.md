<!-- Last-touched: 2026-08-06 — licence list completed and the "memory-safe" claim corrected. -->
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../../../docs/media/logo-dark.png">
    <img src="../../../docs/media/logo.png" width="460"
         alt="Freehold Mail — lifelong ownership, secure connection">
  </picture>
</p>

<p align="center">
  <a href="https://github.com/Novaza-ai/freeholdmail/actions/workflows/ci.yml"><img src="https://github.com/Novaza-ai/freeholdmail/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://scorecard.dev/viewer/?uri=github.com/Novaza-ai/freeholdmail"><img src="https://api.scorecard.dev/projects/github.com/Novaza-ai/freeholdmail/badge" alt="OpenSSF Scorecard"></a>
  <a href="https://www.bestpractices.dev/projects/14076"><img src="https://www.bestpractices.dev/projects/14076/badge" alt="OpenSSF Best Practices"></a>
  <a href="https://github.com/Novaza-ai/freeholdmail/attestations"><img src="https://img.shields.io/badge/SLSA-Build%20L2-brightgreen.svg" alt="SLSA Build Level 2"></a>
  <a href="https://github.com/Novaza-ai/freeholdmail/releases/latest"><img src="https://img.shields.io/badge/SBOM-SPDX-blue.svg" alt="SBOM: SPDX"></a>
  <a href="../../../.github/dependabot.yml"><img src="https://img.shields.io/badge/Dependabot-enabled-025E8C.svg" alt="Dependabot enabled"></a>
</p>

<p align="center">
  <a href="https://github.com/stalwartlabs/stalwart"><img src="https://img.shields.io/badge/mail%20server-Rust-orange.svg" alt="Mail server: Rust"></a>
  <a href="https://jmap.io"><img src="https://img.shields.io/badge/JMAP-native-blueviolet.svg" alt="JMAP native"></a>
  <a href="https://github.com/Novaza-ai/freeholdmail/releases/latest"><img src="https://img.shields.io/github/v/release/Novaza-ai/freeholdmail?label=release" alt="Latest release"></a>
</p>

<p align="center">
  <a href="../../../CHANGELOG.md"><img src="https://img.shields.io/badge/SemVer-2.0.0-blue.svg" alt="Semantic Versioning 2.0.0"></a>
  <a href="../../../CHANGELOG.md"><img src="https://img.shields.io/badge/Keep%20a%20Changelog-1.1.0-orange.svg" alt="Keep a Changelog 1.1.0"></a>
  <a href="../../../CODE_OF_CONDUCT.md"><img src="https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg" alt="Contributor Covenant 2.1"></a>
  <a href="../../../LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <a href="../../../THIRD_PARTY_LICENSES.md"><img src="https://img.shields.io/badge/components-AGPL--3.0-orange.svg" alt="Components: AGPL-3.0"></a>
  <a href="../../../CHANGELOG.md"><img src="https://img.shields.io/badge/status-pre--1.0-yellow.svg" alt="Status: pre-1.0"></a>
</p>

[English](../../../README.md) · **日本語** — 英語版が正典です。[`TRANSLATIONS.md`](../../../TRANSLATIONS.md) を参照してください

> **この翻訳は参考用です。** 内容が英語版と矛盾する場合は、常に英語版が優先されます。
> 翻訳は遅れることがあります。セキュリティやライセンスに関わる判断は、必ず英語版の原文で確認してください。

# Freehold Mail

**受信箱を借りるのはもうやめましょう。** 完全な自己ホスト型メールスタック — Rust 製メールサーバーと
モダンな Web クライアント。

> *Freehold*（自由保有権）: 地主も更新すべき賃貸契約も存在せず、完全に自分のものである資産のこと。
> これを自分で動かすことと、あなたのデータを収益源とする誰かから受信箱を借りることの違いが、まさにそれです。

<p align="center">
  <img src="../../../docs/media/inbox.png" alt="Freehold Mail の受信箱: フォルダーのサイドバー、メッセージ一覧、閲覧ペイン" width="820">
</p>

メールサーバー、Webmail、TLS 終端 — これらを配線し、シークレットを生成して、設定すべき DNS
レコードを正確に提示するインストーラーが付属します。SSO は必要なときだけ有効にでき、不要なら存在しません。

> **ステータス: pre-1.0。** 既定エディションはエンドツーエンドでテスト済みです — 実際のメッセージが
> SMTP → メールボックス → IMAP を通過します。SSO エディションは起動し、データベースと OIDC ディスカバリーは
> 検証済みですが、同梱の Keycloak バージョンとブラウザーのログインフローは未検証です。依存する前に
> [既知のギャップ](../../../CHANGELOG.md#known-gaps-do-not-publish-without-deciding-these) をお読みください。

---

## 動作を見る

Webmail にはガイドツアーが内蔵されています。以下はそのツアーを実際のスタックに対して記録したものです —
メッセージはモックではなく、`scripts/seed_demo.py` によって SMTP で配送され IMAP で読み戻されています。

<p align="center">
  <img src="../../../docs/media/tour.gif" alt="Webmail のガイドツアー: サイドバー、作成、検索、メッセージ一覧、閲覧ペイン、タグ、連絡先、設定、キーボードショートカット" width="820">
</p>

ここにある画像はすべてスクリプトで再生成されており、加工は一切していません — コマンドは
[`docs/media/README.md`](../../../docs/media/README.md) を参照してください。

## なぜ存在するのか

メールの自己ホストは通常、Postfix・Dovecot・Rspamd・Webmail を週末かけて繋ぎ合わせるか、
あるいは誰かがあなたのメタデータを読むホスティング型メールボックスを使うかの二択です。
Freehold Mail は第三の選択肢です — モダンなスタックを、あなたが管理するマシン上で自分で動かす
ための単一リポジトリです。メールサーバーと Webmail はメモリ安全な言語で書かれていますが、nginx と
PostgreSQL は C です。つまり「メモリ安全」はスタック全体ではなく、私たちが選んだ部分を指します。

**これは何か:** オーケストレーションです。Compose ファイル、nginx 設定、インストーラー、そして正直なドキュメント。
**これは何ではないか:** 誰かのメールサーバーのフォークでも書き直しでもありません。

## 2 つのエディション

| エディション | 含まれるもの | ログイン | E2E テスト済み |
|---------|----------|-------|------------|
| **Full Mail**（既定） | メールサーバー + Webmail + nginx | ネイティブのユーザー名/パスワード | ✅ はい |
| **Mail + SSO** | 上記 **+ Keycloak + PostgreSQL** | OIDC/SSO | ⚠️ 部分的 — スタックは起動し、データベースと OIDC ディスカバリーは Keycloak 24 で検証済み。同梱の 26.0 の設定とブラウザーのログイン往復は未計測。[既知のギャップ](../../../CHANGELOG.md#known-gaps-do-not-publish-without-deciding-these) を参照 |

SSO が不要なら Keycloak に触れることはありません。オプションのオーバーレイファイルに分離されています。

## クイックスタート

必要なもの: Docker と Compose v2 が動く Linux ホスト、自分が管理するドメイン、到達可能な
25/465/587/993/80/443 ポート、そして TLS 証明書。

```bash
git clone https://github.com/Novaza-ai/freeholdmail && cd freeholdmail
./install.sh
```

> **サーバーを借りたばかり、あるいはこれから借りますか？** まず [`docs/HOSTING.md`](../../../docs/HOSTING.md)
> をお読みください。まっさらな VPS から動作するメールボックスまでを、各ステップに検証コマンド付きで案内します。
> そして**後から絶対に直せない一点**を明示しています: **安価なプロバイダーの多くは送信側のポート 25 を
> 遮断しており**、どれだけ完璧に設定してもメール送信は不可能になります。適切なサイズを推測ではなく選べるよう、
> 実測した RAM・CPU・ディスクの数値も掲載しています。

インストーラーはエディションとドメインを尋ね、その後:

1. 強力なランダムシークレットを `.env` に生成します（モード 600、`umask 077` — ハードコードは一切なし）;
2. コンテナイメージをダイジェストで固定します;
3. Let's Encrypt のパスを解決します（`live/` のシンボリックリンクはコンテナ内では機能しません）;
4. スタックを起動し、最初のメールボックスを作成するコマンドを表示します。

その後メールボックスを作成し、`https://<your-domain>` でログインします:

```bash
# domain, then user — the roles field is required, or SMTP AUTH refuses the account
curl -u admin:$STALWART_FALLBACK_ADMIN_SECRET -X POST http://127.0.0.1:8080/api/principal \
  -H 'Content-Type: application/json' -d '{"type":"domain","name":"example.com"}'

curl -u admin:$STALWART_FALLBACK_ADMIN_SECRET -X POST http://127.0.0.1:8080/api/principal \
  -H 'Content-Type: application/json' \
  -d '{"type":"individual","name":"you@example.com","secrets":["<password>"],
       "emails":["you@example.com"],"roles":["user"]}'
```

最後に DNS レコードを設定します — MX、SPF、DKIM、DMARC は
[`docs/DNS.md`](../../../docs/DNS.md) にあります。

## アーキテクチャ

```
Browser ─HTTPS─▶ nginx ─┬─ /  and  /api/*  ─▶ Bulwark webmail (FE)   :3000
                        ├─ /jmap, /.well-known/jmap ─▶ Stalwart  :8080/JMAP
                        └─ /.well-known/openid-configuration ─▶ Keycloak (SSO edition)
SMTP/IMAP clients ───────────────────────────────▶ Stalwart  :25 :465 :587 :993
```

`/api/*` は Webmail のものであり、Webmail は自身の設定とセッションのルートをそこで提供します。
メールサーバーに到達するのは `/jmap` と JMAP ディスカバリーだけで、その管理 API は意図的に
プロキシ経由で公開していません。

各ボックスは独立した交換可能なコンテナです。フロントエンドとバックエンドの間は**ネットワークのみ** —
HTTP 上の JMAP であり、コードのリンクはありません。この境界こそが、各コンポーネントが自身の
ライセンスを保ったまま、このリポジトリを MIT にできる理由です。

## 他との比較

| | Freehold Mail | Mailu / Mailcow | docker-mailserver | Google Workspace |
|---|---|---|---|---|
| メールサーバー | Stalwart（Rust、JMAP ネイティブ） | Postfix + Dovecot | Postfix + Dovecot | — |
| RAM（アイドル時・実測） | **218–288 MiB** | mailcow: 6 GiB min (docs) | — | — |
| Webmail 同梱 | ✅ | ✅ | ❌（別途用意） | ✅ |
| JMAP | ✅ | ❌ | ❌ | ❌ |
| SSO/OIDC | ✅ オプションのエディション | 部分的 | ❌ | ✅ |
| データを自分で保持 | ✅ | ✅ | ✅ | ❌ |
| 成熟度 | **pre-1.0** | 成熟 | 成熟 | 商用 |

Mailu、Mailcow、docker-mailserver はいずれも優れており、実戦経験もはるかに豊富です。
JMAP ネイティブな Rust 製メールサーバーを、Webmail とオプションの SSO とともに一箇所で
欲しい場合にのみ Freehold Mail を選んでください。

## 正直なスコープ

**現在:** メールボックス、SMTP/IMAP/JMAP、Webmail、TLS、オプションの SSO — ホスティング型
メールボックスの現実的な代替になります。

**現在は対象外:** マーケティング/一括メール、ニュースレター、チーム共有受信箱、チケット管理、
他プロバイダーからの移行ツール、マネージドのコントロールパネル。特に一括送信は機能スイッチではなく
到達性の規律であり、できるものと想定しないでください。

**ロードマップ:** [`ROADMAP.md`](../../../ROADMAP.md) を参照してください — 短期の焦点は信頼性です
（同梱の Keycloak 上での SSO 検証、上流メールサーバーの最新ライン、実ドメインでの到達性計測）。
さらに先では、このスタックをソフトウェアエージェントが安全に使えるものにしたいと考えています:
JMAP 上の MCP サーバーと、ボットにパスワードを渡す代わりの、スコープ付きで失効可能なエージェント単位の
資格情報です。いずれもまだ実装されておらず、プロジェクト名も意図的にそれを名乗っていません。
**エージェント関連の貢献を歓迎します — ロードマップの「Help wanted」を参照してください。**

## ⚖️ ライセンス

- **このリポジトリ**（オーケストレーション、設定、インストーラー、ドキュメント）: **MIT** —
  [`LICENSE`](../../../LICENSE) を参照。
- **デプロイされるプログラムはそれぞれ自身のライセンスを保持**し、公開イメージとして取得されます。
  このリポジトリにそれらのソースは一切含まれません:
  - Stalwart Mail Server — **AGPL-3.0-only OR SELv1**（デュアルライセンス。"or later" ではない）
  - Bulwark Webmail — **AGPL-3.0-only**
  - Keycloak — **Apache-2.0**（SSO 版）
  - PostgreSQL — **PostgreSQL License**（SSO 版）
  - nginx — **BSD-2-Clause**

Stalwart または Bulwark を**改変して**他者に提供する場合、AGPL は*そのコンポーネントの*改変後ソースの
公開を要求します。未改変のイメージを実行するだけなら要求されません。詳細は
[`THIRD_PARTY_LICENSES.md`](../../../THIRD_PARTY_LICENSES.md) と [`NOTICE`](../../../NOTICE)。

## セキュリティ

オープンリレーは拒否され、送信には認証が必要で、パスワード方式（`PLAIN`/`LOGIN`）は STARTTLS の
後にのみ提示されます — すべて推測ではなく実測です。同時に、計画に織り込むべき実在の弱点もあります。
アカウントのパスワードを平文で返す上流の管理 API もその一つです。
**インターネットに公開する前に [`SECURITY.md`](../../../SECURITY.md) を必ずお読みください。**

## テストと運用

どちらもリポジトリに含まれています — 上記のすべての主張はご自身で再現できます:

```bash
tests/test_config.sh      # static: both editions validate, no secrets, digests pinned … (~seconds)
tests/test_e2e.sh         # real: stack up → send a message → read it back over IMAP (~2 min)
tests/test_e2e.sh --sso   # same, plus Keycloak + PostgreSQL
```

`test_e2e.sh` はループバック専用ポート上に、独自のボリュームとコンテナ名を持つ使い捨てスタックを構築し、
終了時に破棄します — 稼働中のデプロイを妨げることはありません。これらのテストが意図的に
**カバーしていない**範囲も含め、[`tests/README.md`](../../../tests/README.md) を参照してください。

日常運用 — バックアップ、証明書更新、メールボックス管理、アップグレード、インシデント対応 — は
[`docs/RUNBOOK.md`](../../../docs/RUNBOOK.md) にあります。前提条件は
[`docs/REQUIREMENTS.md`](../../../docs/REQUIREMENTS.md)。

## コントリビュート

[`CONTRIBUTING.md`](../../../CONTRIBUTING.md) を参照してください。ハウスルールが一つあります:
実行時の挙動に関する主張には計測値が必要であり、「自分の環境では動く」は根拠になりません。

誰が何を決めるのか、メンテナーになる方法、そしてこのプロジェクトが放棄された場合どうなるのかは
[`GOVERNANCE.md`](../../../GOVERNANCE.md)。誰から返信が来るのか、そしてバス係数の正直な表明は
[`MAINTAINERS.md`](../../../MAINTAINERS.md)。

## 誰が作っているのか

**Daika Ginza** が主導しています — [GitHub](https://github.com/daikaginza) ·
[Substack](https://substack.com/@daikaginza) ·
[LinkedIn](https://www.linkedin.com/in/daikaginza/) — そして
[@anhkk1245](https://github.com/anhkk1245)、所属は
**[Novaza Solution JSC](https://novaza.ai)**。

私たちはこのスタックのコンポーネント（Stalwart と Bulwark）を自社のメールとして本番運用しており、
その構成を自己ホストしたい人のためにパッケージ化したのが Freehold Mail です。MIT ライセンスです。
[`LICENSE`](../../../LICENSE) と [`NOTICE`](../../../NOTICE) を参照してください。

チーム全体、意思決定の方法、参加の仕方:
[`MAINTAINERS.md`](../../../MAINTAINERS.md) · [`GOVERNANCE.md`](../../../GOVERNANCE.md)。

> GitHub のコントリビューターグラフは現在 `dependabot` しか表示していません。私たちのコミットが、
> GitHub アカウントに紐づいていない企業アイデンティティで署名されているためです。貢献する際は
> ご自身の名前とメールアドレスでコミットしてください — そちらでは正しくクレジットされます。
> チームに対してこれをどう解消するかは `MAINTAINERS.md` に記載しています。

---

Stalwart Labs、Bulwark プロジェクト、Keycloak とは提携関係にありません。
