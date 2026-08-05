<!-- Last-touched: 2026-08-04 — bản dịch đầu tiên, dịch từ README.md cùng ngày. -->
[English](../../../README.md) · **Tiếng Việt** — bản tiếng Anh là bản có thẩm quyền, xem [`TRANSLATIONS.md`](../../../TRANSLATIONS.md)

> ⚠️ Bản dịch có thể lạc hậu so với bản gốc. Khi có mâu thuẫn, [`README.md`](../../../README.md)
> tiếng Anh là bản đúng.

# Freehold Mail

**Đừng đi thuê hộp thư của chính mình.** Một bộ mail stack self-hosted hoàn chỉnh — mail
server viết bằng Rust, web client hiện đại.

> *Freehold* là thuật ngữ pháp lý: tài sản bạn **sở hữu đứt**, không có địa chủ, không có
> hợp đồng thuê phải gia hạn. Đó chính là khác biệt giữa việc tự vận hành bộ này và việc
> thuê hộp thư từ một bên mà mô hình kinh doanh của họ là dữ liệu của bạn.

[![CI](https://github.com/Novaza-ai/freeholdmail/actions/workflows/ci.yml/badge.svg)](https://github.com/Novaza-ai/freeholdmail/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](../../../LICENSE)
[![Components: AGPL-3.0](https://img.shields.io/badge/components-AGPL--3.0-orange.svg)](../../../THIRD_PARTY_LICENSES.md)
[![Status: pre-1.0](https://img.shields.io/badge/status-pre--1.0-yellow.svg)](../../../CHANGELOG.md)

<p align="center">
  <img src="../../../docs/media/inbox.png" alt="Hộp thư Freehold Mail: sidebar thư mục, danh sách thư và khung đọc" width="820">
</p>

Mail server, webmail và TLS termination — đã đấu nối sẵn với nhau, kèm một trình cài đặt tự
sinh secret cho bạn và in ra chính xác những bản ghi DNS cần đặt. SSO là tuỳ chọn: có khi
bạn cần, và hoàn toàn vắng mặt khi bạn không cần.

> **Trạng thái: pre-1.0.** Edition mặc định đã được kiểm thử đầu-cuối — một email thật đi
> qua SMTP → hộp thư → IMAP. Edition SSO thì khởi động được, database và OIDC discovery đã
> xác minh, nhưng phiên bản Keycloak đang khai và luồng đăng nhập qua trình duyệt thì chưa.
> Hãy đọc [Known gaps](../../../CHANGELOG.md#known-gaps-do-not-publish-without-deciding-these) trước
> khi bạn dựa vào bộ này.

---

## Xem nó chạy

Webmail có sẵn một tour hướng dẫn. Đây chính là tour đó, quay trên một stack thật — các
email được gửi qua SMTP và đọc lại qua IMAP bằng `scripts/seed_demo.py`, không phải dữ liệu
giả:

<p align="center">
  <img src="../../../docs/media/tour.gif" alt="Tour hướng dẫn webmail: sidebar, soạn thư, tìm kiếm, danh sách thư, khung đọc, nhãn, danh bạ, cài đặt, phím tắt" width="820">
</p>

Mọi hình ở đây đều được sinh lại bằng script, không chỉnh sửa tay — xem
[`docs/media/README.md`](../../../docs/media/README.md) để biết lệnh.

## Vì sao dự án này tồn tại

Tự vận hành email thường rơi vào một trong hai kịch bản: mất cả cuối tuần chắp vá Postfix,
Dovecot, Rspamd và một webmail — hoặc dùng hộp thư thuê, nơi người khác đọc metadata của
bạn. Freehold Mail là lựa chọn thứ ba: một repo lắp ghép sẵn một stack hiện đại,
memory-safe, do bạn tự chạy trên máy do bạn kiểm soát.

**Nó là gì:** phần orchestration. Các file compose, một cấu hình nginx, một trình cài đặt,
và tài liệu trung thực. **Nó không phải là gì:** không phải bản fork hay viết lại mail
server của ai cả.

## Hai edition

| Edition | Gồm những gì | Đăng nhập | Đã test E2E |
|---------|--------------|-----------|-------------|
| **Full Mail** (mặc định) | mail server + webmail + nginx | tài khoản/mật khẩu tự thân | ✅ có |
| **Mail + SSO** | như trên **+ Keycloak + PostgreSQL** | OIDC/SSO | ⚠️ một phần — stack khởi động được, database và OIDC discovery đã xác minh trên Keycloak 24; cấu hình cho bản 26.0 đang khai và vòng đăng nhập qua trình duyệt thì chưa đo. Xem [Known gaps](../../../CHANGELOG.md#known-gaps-do-not-publish-without-deciding-these) |

Bạn không phải đụng đến Keycloak trừ khi muốn dùng SSO; nó nằm trong một file overlay tuỳ chọn.

## Bắt đầu nhanh

Yêu cầu: một máy Linux có Docker và Compose v2, một domain bạn sở hữu, các cổng
25/465/587/993/80/443 truy cập được, và một chứng chỉ TLS.

```bash
git clone https://github.com/Novaza-ai/freeholdmail && cd freeholdmail
./install.sh
```

> **Vừa thuê server, hoặc sắp thuê?** Đọc [`docs/HOSTING.md`](../../../docs/HOSTING.md) trước. Tài liệu
> đó đi từ một VPS trắng tới hộp thư chạy được, mỗi bước kèm lệnh kiểm chứng, và nói thẳng thứ
> duy nhất **không sửa được về sau**: đa số nhà cung cấp giá rẻ **chặn cổng 25 chiều ra**, khiến
> việc gửi mail bất khả thi dù bạn cấu hình hoàn hảo. Nó cũng có số liệu RAM, CPU, đĩa **đo
> thật** để bạn thuê đúng cỡ thay vì đoán.

Trình cài đặt sẽ hỏi bạn chọn edition nào và domain là gì, sau đó:

1. sinh secret ngẫu nhiên mạnh vào `.env` (mode 600, `umask 077` — không hardcode gì cả);
2. ghim (pin) các container image theo digest;
3. giải quyết đường dẫn Let's Encrypt của bạn (symlink `live/` không dùng được bên trong container);
4. dựng stack lên và in ra các lệnh để tạo hộp thư đầu tiên.

Sau đó tạo một hộp thư rồi đăng nhập tại `https://<your-domain>`:

```bash
# domain, then user — the roles field is required, or SMTP AUTH refuses the account
curl -u admin:$STALWART_FALLBACK_ADMIN_SECRET -X POST http://127.0.0.1:8080/api/principal \
  -H 'Content-Type: application/json' -d '{"type":"domain","name":"example.com"}'

curl -u admin:$STALWART_FALLBACK_ADMIN_SECRET -X POST http://127.0.0.1:8080/api/principal \
  -H 'Content-Type: application/json' \
  -d '{"type":"individual","name":"you@example.com","secrets":["<password>"],
       "emails":["you@example.com"],"roles":["user"]}'
```

Cuối cùng là đặt các bản ghi DNS — [`docs/DNS.md`](../../../docs/DNS.md) có đủ MX, SPF, DKIM và DMARC.

## Kiến trúc

```
Browser ─HTTPS─▶ nginx ─┬─ /  and  /api/*  ─▶ Bulwark webmail (FE)   :3000
                        ├─ /jmap, /.well-known/jmap ─▶ Stalwart  :8080/JMAP
                        └─ /.well-known/openid-configuration ─▶ Keycloak (SSO edition)
SMTP/IMAP clients ───────────────────────────────▶ Stalwart  :25 :465 :587 :993
```

`/api/*` thuộc về webmail — nó tự phục vụ cấu hình và session ở đó. Chỉ `/jmap` và JMAP
discovery mới đi tới mail server; admin API của mail server cố ý không lộ qua proxy.

Mỗi khối là một container độc lập, thay thế được. Front end nối với back end **chỉ qua
mạng** — JMAP trên HTTP, không link code. Chính ranh giới đó cho phép repo này mang giấy
phép MIT trong khi từng thành phần vẫn giữ giấy phép riêng của nó.

## So sánh

| | Freehold Mail | Mailu / Mailcow | docker-mailserver | Google Workspace |
|---|---|---|---|---|
| Mail server | Stalwart (Rust, JMAP-native) | Postfix + Dovecot | Postfix + Dovecot | — |
| Có sẵn webmail | ✅ | ✅ | ❌ (tự lo) | ✅ |
| JMAP | ✅ | ❌ | ❌ | ❌ |
| SSO/OIDC | ✅ edition tuỳ chọn | một phần | ❌ | ✅ |
| Dữ liệu thuộc về bạn | ✅ | ✅ | ✅ | ❌ |
| Độ chín | **pre-1.0** | đã chín | đã chín | thương mại |

Mailu, Mailcow và docker-mailserver đều xuất sắc và dày dạn trận mạc hơn nhiều. Hãy chọn
Freehold Mail nếu bạn cụ thể muốn một mail server viết bằng Rust, JMAP-native, kèm webmail
và SSO tuỳ chọn, gói gọn ở một chỗ.

## Phạm vi, nói thẳng

**Hiện có:** hộp thư, SMTP/IMAP/JMAP, webmail, TLS, SSO tuỳ chọn — đủ để thay thế một hộp
thư thuê.

**Chưa có:** email marketing/gửi hàng loạt, newsletter, hộp thư dùng chung cho nhóm,
ticketing, công cụ di trú từ nhà cung cấp khác, hay control panel có người quản trị. Riêng
gửi hàng loạt là cả một bộ môn về deliverability, không phải một cái công tắc bật lên —
đừng mặc định là có.

**Lộ trình:** xem [`ROADMAP.md`](../../../ROADMAP.md) — trước mắt là làm cho đáng tin (xác minh SSO
trên đúng bản Keycloak đang khai, lên dòng mail server hiện hành của upstream, ghim digest
mọi image, đo deliverability trên domain thật). Xa hơn, chúng tôi muốn đây là bộ stack mà
software agent có thể dùng một cách an toàn: một MCP server chạy trên JMAP, và credential
riêng cho từng agent — có giới hạn phạm vi, thu hồi được — thay vì đưa mật khẩu của bạn cho
một con bot. **Chưa có thứ nào trong số đó được xây**, và dự án cố ý không lấy tên theo
chúng. **Rất mong có người đóng góp phần agent — xem mục "Help wanted" trong lộ trình.**

## ⚖️ Giấy phép

- **Repo này** (orchestration, config, installer, tài liệu): **MIT** — xem [`LICENSE`](../../../LICENSE).
- **Các chương trình mà nó triển khai vẫn giữ giấy phép riêng** và được kéo về dưới dạng
  image đã publish; repo này không chứa mã nguồn của chúng:
  - Stalwart Mail Server — **AGPL-3.0**
  - Bulwark Webmail — **AGPL-3.0**
  - Keycloak — **Apache-2.0**

Nếu bạn **sửa đổi** Stalwart hoặc Bulwark rồi phục vụ cho người khác, AGPL buộc bạn phải
công bố mã nguồn đã sửa *của chính thành phần đó*. Chạy image nguyên bản thì không phát sinh
nghĩa vụ này. Chi tiết: [`THIRD_PARTY_LICENSES.md`](../../../THIRD_PARTY_LICENSES.md) và
[`NOTICE`](../../../NOTICE). *(Văn bản giấy phép chỉ có hiệu lực pháp lý ở bản tiếng Anh.)*

## Bảo mật

Open relay bị từ chối, gửi thư bắt buộc xác thực, và các cơ chế mật khẩu (`PLAIN`/`LOGIN`)
chỉ được cấp sau STARTTLS — tất cả đều **đã đo**, không phải phỏng đoán. Nhưng cũng có
những điểm yếu thật mà bạn phải tính đến, trong đó có một admin API của upstream trả về mật
khẩu tài khoản ở dạng cleartext. **Hãy đọc [`SECURITY.md`](../../../SECURITY.md) trước khi mở bộ này
ra internet.** *(File SECURITY.md chỉ có bản tiếng Anh — đó là bản có thẩm quyền.)*

## Kiểm thử và vận hành

Cả hai đều nằm trong repo — bạn tự tái lập được mọi tuyên bố ở trên:

```bash
tests/test_config.sh      # static: both editions validate, no secrets, digests pinned … (~seconds)
tests/test_e2e.sh         # real: stack up → send a message → read it back over IMAP (~2 min)
tests/test_e2e.sh --sso   # same, plus Keycloak + PostgreSQL
```

`test_e2e.sh` dựng một stack dùng-một-lần trên các cổng chỉ bind loopback, với volume và tên
container riêng, và luôn dọn sạch khi kết thúc — nó sẽ không làm phiền một bản triển khai
đang chạy. Xem [`tests/README.md`](../../../tests/README.md), gồm cả phần **cố ý không** kiểm thử.

Vận hành hằng ngày — sao lưu, gia hạn chứng chỉ, quản lý hộp thư, nâng cấp, xử lý sự cố —
nằm ở [`docs/RUNBOOK.md`](../../../docs/RUNBOOK.md). Điều kiện tiên quyết ở
[`docs/REQUIREMENTS.md`](../../../docs/REQUIREMENTS.md).

## Đóng góp

Xem [`CONTRIBUTING.md`](../../../CONTRIBUTING.md). Một luật nội bộ: mọi tuyên bố về hành vi lúc chạy
phải có số đo, không phải "chạy được trên máy tôi".

Ai quyết định điều gì, làm sao để trở thành maintainer, và chuyện gì xảy ra với bạn nếu dự án
này bị bỏ rơi: [`GOVERNANCE.md`](../../../GOVERNANCE.md). Ai sẽ trả lời bạn, kèm tuyên bố thẳng thắn
rằng **dự án hiện chỉ có một maintainer**: [`MAINTAINERS.md`](../../../MAINTAINERS.md).

## Ai xây dự án này

Dẫn dắt bởi **Daika Ginza** — [GitHub](https://github.com/daikaginza) ·
[Substack](https://substack.com/@daikaginza) ·
[LinkedIn](https://www.linkedin.com/in/daikaginza/) — cùng
[@anhkk1245](https://github.com/anhkk1245), tại
**[Novaza Solution JSC](https://novaza.ai)**.

Chúng tôi chạy các thành phần của stack này (Stalwart và Bulwark) trong môi trường production
cho hệ thống mail của chính mình, và xây Freehold Mail để đóng gói kiến trúc đó cho bất kỳ ai
muốn tự vận hành. Giấy phép MIT; xem [`LICENSE`](../../../LICENSE) và [`NOTICE`](../../../NOTICE).

Toàn bộ team, cách ra quyết định, và cách tham gia:
[`MAINTAINERS.md`](../../../MAINTAINERS.md) · [`GOVERNANCE.md`](../../../GOVERNANCE.md).

> Đồ thị contributor của GitHub hiện chỉ ghi nhận `dependabot`, vì các commit của chúng tôi
> ký dưới danh nghĩa pháp nhân không gắn với tài khoản GitHub nào. Nếu bạn đóng góp, hãy
> commit bằng tên và email của chính bạn — bạn sẽ được ghi nhận đúng ở đó. `MAINTAINERS.md`
> giải thích cách chúng tôi đang khắc phục điều này cho team.

---

Không có liên kết chính thức với Stalwart Labs, dự án Bulwark, hay Keycloak.
