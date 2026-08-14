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
  <a href="../../../LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <a href="../../../THIRD_PARTY_LICENSES.md"><img src="https://img.shields.io/badge/components-AGPL--3.0-orange.svg" alt="Components: AGPL-3.0"></a>
  <a href="../../../CHANGELOG.md"><img src="https://img.shields.io/badge/status-pre--1.0-yellow.svg" alt="Status: pre-1.0"></a>
</p>

[English](../../../README.md) · **繁體中文** — 以英文版為準，請參閱 [`TRANSLATIONS.md`](../../../TRANSLATIONS.md)

> **本翻譯僅供參考。** 若與英文版有任何衝突，一律以英文版為準。翻譯內容可能落後於英文原文。
> 涉及安全性與授權條款的判斷，請務必回頭以英文原文查證。

# Freehold Mail

**別再租用你的收件匣。** 一套完整的自架郵件系統 —— Rust 寫成的郵件伺服器，搭配現代化的
網頁用戶端。

> *Freehold*（永久產權）：完全歸你所有的財產，沒有房東，也沒有需要續約的租約。
> 自己執行這套系統，和向一個以你的資料為商業模式的人租用信箱，差別就在這裡。

<p align="center">
  <img src="../../../docs/media/inbox.png" alt="Freehold Mail 收件匣：資料夾側邊欄、郵件清單與閱讀窗格" width="820">
</p>

郵件伺服器、Webmail 與 TLS 終結 —— 全都串接就緒，並附上一個安裝程式：它會為你產生密鑰，
並明確告訴你該設定哪些 DNS 記錄。需要 SSO 時可以啟用，不需要時它根本不存在。

> **狀態：pre-1.0。** 預設版本已完成端對端測試 —— 一封真實郵件走完 SMTP → 信箱 → IMAP。
> SSO 版本可以啟動，其資料庫與 OIDC 探索均已驗證，但隨附的 Keycloak 版本與瀏覽器登入流程
> 尚未驗證。在你依賴本專案之前，請先閱讀
> [已知落差](../../../CHANGELOG.md#known-gaps-do-not-publish-without-deciding-these)。

---

## 看它實際運作

Webmail 內建一段導覽。以下就是那段導覽，錄製自一套真實運行的系統 —— 郵件是由
`scripts/seed_demo.py` 透過 SMTP 實際投遞、再經 IMAP 讀回，而非模擬：

<p align="center">
  <img src="../../../docs/media/tour.gif" alt="Webmail 導覽：側邊欄、撰寫郵件、搜尋、郵件清單、閱讀窗格、標籤、聯絡人、設定、鍵盤快捷鍵" width="820">
</p>

這裡的每一張圖都由指令碼重新產生，從未修圖 —— 指令請見
[`docs/media/README.md`](../../../docs/media/README.md)。

## 為什麼會有這個專案

自架電子郵件通常只有兩種結果：花一個週末把 Postfix、Dovecot、Rspamd 和某個 Webmail 黏在一起；
或者用代管信箱，讓別人讀你的中繼資料。Freehold Mail 是第三個選項：用一個儲存庫，組裝出一套現代的
系統，由你自己在你掌控的機器上執行。郵件伺服器與 Webmail 使用記憶體安全的語言；nginx 與
PostgreSQL 是 C 寫的，所以「記憶體安全」描述的是我們所選的那部分，而不是整套系統。

**它是什麼：** 編排（orchestration）。Compose 檔案、一份 nginx 設定、一個安裝程式，以及誠實的文件。
**它不是什麼：** 任何人郵件伺服器的分支或重寫。

## 兩種版本

| 版本 | 包含 | 登入方式 | 端對端測試 |
|---------|----------|-------|------------|
| **Full Mail**（預設） | 郵件伺服器 + Webmail + nginx | 原生使用者名稱／密碼 | ✅ 是 |
| **Mail + SSO** | 上述內容 **+ Keycloak + PostgreSQL** | OIDC/SSO | ⚠️ 部分 —— 系統可以啟動，資料庫與 OIDC 探索已在 Keycloak 24 上驗證；隨附的 26.0 設定與瀏覽器登入的完整往返尚未實測。參見[已知落差](../../../CHANGELOG.md#known-gaps-do-not-publish-without-deciding-these) |

除非你想要 SSO，否則永遠不必碰 Keycloak；它放在一個選用的 overlay 檔案裡。

## 快速開始

需求條件：一台裝有 Docker 與 Compose v2 的 Linux 主機、一個你掌控的網域、可連通的
25/465/587/993/80/443 連接埠，以及一張 TLS 憑證。

```bash
git clone https://github.com/Novaza-ai/freeholdmail && cd freeholdmail
./install.sh
```

> **剛租下伺服器，或正打算租？** 請先閱讀 [`docs/HOSTING.md`](../../../docs/HOSTING.md)。
> 它帶你從一台空白 VPS 走到可用的信箱，每一步都附有驗證指令，並且點名了那件你事後無法補救的事：
> **多數廉價供應商會封鎖對外的 25 連接埠**，那樣不論你把這套系統設定得多好，郵件都不可能寄得出去。
> 文中也有實測的記憶體、CPU 與磁碟數據，讓你租到正確的規格，而不是靠猜。

安裝程式會詢問你要用哪個版本與哪個網域，然後：

1. 在 `.env` 中產生高強度的隨機密鑰（權限 600、`umask 077` —— 沒有任何硬編碼）；
2. 以摘要（digest）鎖定容器映像檔；
3. 解析你的 Let's Encrypt 路徑（`live/` 符號連結在容器內無法運作）；
4. 啟動整套系統，並印出建立第一個信箱所需的指令。

接著建立信箱，並在 `https://<your-domain>` 登入：

```bash
# domain, then user — the roles field is required, or SMTP AUTH refuses the account
curl -u admin:$STALWART_FALLBACK_ADMIN_SECRET -X POST http://127.0.0.1:8080/api/principal \
  -H 'Content-Type: application/json' -d '{"type":"domain","name":"example.com"}'

curl -u admin:$STALWART_FALLBACK_ADMIN_SECRET -X POST http://127.0.0.1:8080/api/principal \
  -H 'Content-Type: application/json' \
  -d '{"type":"individual","name":"you@example.com","secrets":["<password>"],
       "emails":["you@example.com"],"roles":["user"]}'
```

最後設定你的 DNS 記錄 —— [`docs/DNS.md`](../../../docs/DNS.md) 收錄了 MX、SPF、DKIM 與 DMARC。

## 架構

```
Browser ─HTTPS─▶ nginx ─┬─ /  and  /api/*  ─▶ Bulwark webmail (FE)   :3000
                        ├─ /jmap, /.well-known/jmap ─▶ Stalwart  :8080/JMAP
                        └─ /.well-known/openid-configuration ─▶ Keycloak (SSO edition)
SMTP/IMAP clients ───────────────────────────────▶ Stalwart  :25 :465 :587 :993
```

`/api/*` 屬於 Webmail，它在那裡提供自己的設定與工作階段路由。只有 `/jmap` 與 JMAP 探索會抵達
郵件伺服器；它的管理 API 被刻意排除在代理之外，不對外開放。

圖中每一個方塊都是獨立、可抽換的容器。前端到後端**只有網路**連線 —— HTTP 之上的 JMAP，
沒有程式碼層級的連結。正是這條邊界，讓本儲存庫得以採用 MIT，而各個元件保留各自的授權條款。

## 橫向比較

| | Freehold Mail | Mailu / Mailcow | docker-mailserver | Google Workspace |
|---|---|---|---|---|
| 郵件伺服器 | Stalwart（Rust，原生 JMAP） | Postfix + Dovecot | Postfix + Dovecot | — |
| 內建 Webmail | ✅ | ✅ | ❌（需自備） | ✅ |
| JMAP | ✅ | ❌ | ❌ | ❌ |
| SSO/OIDC | ✅ 選用版本 | 部分 | ❌ | ✅ |
| 資料由你掌握 | ✅ | ✅ | ✅ | ❌ |
| 成熟度 | **pre-1.0** | 成熟 | 成熟 | 商業產品 |

Mailu、Mailcow 與 docker-mailserver 都很優秀，而且久經實戰考驗。只有在你特別想要一套原生 JMAP、
以 Rust 寫成的郵件伺服器，並把 Webmail 與選用的 SSO 集中在一處時，才選 Freehold Mail。

## 誠實的範圍

**現在有：** 信箱、SMTP/IMAP/JMAP、Webmail、TLS、選用的 SSO —— 足以可信地取代一個代管信箱。

**現在沒有：** 行銷／大量郵件、電子報、團隊共用收件匣、工單系統、從其他供應商遷移的工具，
或代管式控制台。尤其是大量寄送，那是一門送達率的功夫，不是一個功能開關 —— 別想當然耳。

**路線圖：** 見 [`ROADMAP.md`](../../../ROADMAP.md) —— 近期重點是可信度（在隨附的 Keycloak 上
驗證 SSO、跟上上游郵件伺服器的當前版本線、在真實網域上實測送達率）。更長遠來看，我們希望這套系統
成為軟體代理程式能夠安全使用的那一套：一個架在 JMAP 之上的 MCP 伺服器，以及範圍受限、可撤銷、
依代理程式各自獨立的認證憑據，而不是把密碼交給機器人。這些都還沒有做出來，專案名稱也刻意沒有以此命名。
**歡迎在代理程式這塊貢獻 —— 參見路線圖中的「Help wanted」。**

## ⚖️ 授權條款

- **本儲存庫**（編排、設定、安裝程式、文件）：**MIT** —— 見 [`LICENSE`](../../../LICENSE)。
- **它部署的程式各自保留自己的授權條款**，並以已發佈的映像檔形式拉取；本儲存庫不含它們的任何原始碼：
  - Stalwart Mail Server —— **AGPL-3.0-only OR SELv1**（雙重授權，不是 "or later"）
  - Bulwark Webmail —— **AGPL-3.0-only**
  - Keycloak —— **Apache-2.0**（SSO 版）
  - PostgreSQL —— **PostgreSQL License**（SSO 版）
  - nginx —— **BSD-2-Clause**

如果你**修改** Stalwart 或 Bulwark 並對外提供服務，AGPL 要求你公開*該元件*修改後的原始碼。
執行未經修改的映像檔則不需要。詳情見
[`THIRD_PARTY_LICENSES.md`](../../../THIRD_PARTY_LICENSES.md) 與 [`NOTICE`](../../../NOTICE)。

## 安全性

開放中繼一律拒絕，郵件遞交必須通過驗證，密碼機制（`PLAIN`/`LOGIN`）只在 STARTTLS 之後才提供 ——
這些全都是實測出來的，不是假設。同時也存在你必須事先規劃因應的真實弱點，其中包括一個會以明文
回傳帳號密碼的上游管理 API。**在把它暴露到網際網路之前，請先閱讀
[`SECURITY.md`](../../../SECURITY.md)。**

## 測試與維運

兩者都在儲存庫裡 —— 上面的每一項主張你都可以自己重現：

```bash
tests/test_config.sh      # static: both editions validate, no secrets, digests pinned … (~seconds)
tests/test_e2e.sh         # real: stack up → send a message → read it back over IMAP (~2 min)
tests/test_e2e.sh --sso   # same, plus Keycloak + PostgreSQL
```

`test_e2e.sh` 會在僅綁定回送位址的連接埠上，以自己的磁碟區與容器名稱建立一套用完即丟的系統，
並在結束時拆除 —— 它不會干擾正在執行中的部署。請參閱
[`tests/README.md`](../../../tests/README.md)，其中也說明了這些測試刻意**不**涵蓋的範圍。

日常維運 —— 備份、憑證續期、信箱管理、升級、事故處理手冊 —— 見
[`docs/RUNBOOK.md`](../../../docs/RUNBOOK.md)。前置需求見
[`docs/REQUIREMENTS.md`](../../../docs/REQUIREMENTS.md)。

## 參與貢獻

見 [`CONTRIBUTING.md`](../../../CONTRIBUTING.md)。有一條家規：關於執行時行為的主張需要實測數據，
而不是「在我的機器上可以跑」。

誰決定什麼、如何成為維護者，以及萬一這個專案被棄置你會怎麼樣：
[`GOVERNANCE.md`](../../../GOVERNANCE.md)。該期待誰回覆你，以及關於巴士係數的誠實說明：
[`MAINTAINERS.md`](../../../MAINTAINERS.md)。

## 誰在打造它

由 **Daika Ginza** 主導 —— [GitHub](https://github.com/daikaginza) ·
[Substack](https://substack.com/@daikaginza) ·
[LinkedIn](https://www.linkedin.com/in/daikaginza/) —— 並有
[@anhkk1245](https://github.com/anhkk1245) 參與，隸屬於
**[Novaza Solution JSC](https://novaza.ai)**。

我們在正式環境中以這套系統的元件（Stalwart 與 Bulwark）承載自己的郵件，並打造了 Freehold Mail，
把那套架構打包給任何想自架的人使用。採用 MIT 授權條款；見
[`LICENSE`](../../../LICENSE) 與 [`NOTICE`](../../../NOTICE)。

完整團隊、決策如何做成，以及如何加入：
[`MAINTAINERS.md`](../../../MAINTAINERS.md) · [`GOVERNANCE.md`](../../../GOVERNANCE.md)。

> GitHub 的貢獻者圖表目前只列出 `dependabot`，因為我們的提交是以一個未連結 GitHub 帳號的
> 公司身分署名。如果你參與貢獻，請用你自己的姓名與電子郵件提交 —— 你會在那裡被正確記錄。
> `MAINTAINERS.md` 說明了我們打算如何為團隊解決這件事。

---

與 Stalwart Labs、Bulwark 專案或 Keycloak 均無隸屬關係。
