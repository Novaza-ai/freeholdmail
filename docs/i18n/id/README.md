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

[English](../../../README.md) · **Bahasa Indonesia** — Versi bahasa Inggris adalah acuan resmi, lihat [`TRANSLATIONS.md`](../../../TRANSLATIONS.md)

> **Terjemahan ini disediakan sebagai bentuk kemudahan.** Jika isinya bertentangan dengan versi bahasa Inggris,
> versi bahasa Inggris selalu yang berlaku. Terjemahan dapat tertinggal dari versi terbaru. Selalu verifikasi
> keputusan terkait keamanan dan lisensi terhadap naskah asli bahasa Inggris.

# Freehold Mail

**Berhenti menyewa kotak masuk Anda.** Mail stack self-hosted yang lengkap — mail server Rust,
klien web modern.

> *Freehold* (hak milik penuh): properti yang sepenuhnya Anda miliki, tanpa tuan tanah dan tanpa
> sewa yang harus diperpanjang. Itulah perbedaan antara menjalankan ini sendiri dan menyewa kotak
> surat dari pihak yang model bisnisnya adalah data Anda.

[![CI](https://github.com/Novaza-ai/freeholdmail/actions/workflows/ci.yml/badge.svg)](https://github.com/Novaza-ai/freeholdmail/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](../../../LICENSE)
[![Components: AGPL-3.0](https://img.shields.io/badge/components-AGPL--3.0-orange.svg)](../../../THIRD_PARTY_LICENSES.md)
[![Status: pre-1.0](https://img.shields.io/badge/status-pre--1.0-yellow.svg)](../../../CHANGELOG.md)

<p align="center">
  <img src="../../../docs/media/inbox.png" alt="Kotak masuk Freehold Mail: sidebar folder, daftar pesan, dan panel baca" width="820">
</p>

Mail server, webmail, dan terminasi TLS — sudah dirangkai menjadi satu, dengan installer yang
membuat secret Anda dan memberi tahu persis record DNS mana yang harus disetel. SSO tersedia
sebagai opsi saat Anda menginginkannya, dan tidak ada saat Anda tidak.

> **Status: pre-1.0.** Edisi default telah diuji end to end — sebuah pesan nyata melintas
> SMTP → kotak surat → IMAP. Edisi SSO dapat dijalankan serta database dan OIDC discovery-nya
> sudah diverifikasi, tetapi versi Keycloak yang disertakan dan alur login di browser belum.
> Baca [Celah yang diketahui](../../../CHANGELOG.md#known-gaps-do-not-publish-without-deciding-these)
> sebelum Anda bergantung pada ini.

---

## Lihat cara kerjanya

Webmail-nya menyertakan guided tour. Berikut adalah tour tersebut, direkam terhadap stack sungguhan —
pesan-pesannya dikirim melalui SMTP dan dibaca kembali melalui IMAP oleh `scripts/seed_demo.py`,
bukan mock:

<p align="center">
  <img src="../../../docs/media/tour.gif" alt="Guided tour webmail: sidebar, compose, pencarian, daftar pesan, panel baca, tag, kontak, pengaturan, pintasan keyboard" width="820">
</p>

Setiap gambar di sini diregenerasi oleh skrip, tidak pernah disunting ulang — lihat
[`docs/media/README.md`](../../../docs/media/README.md) untuk perintahnya.

## Mengapa ini ada

Melakukan self-hosting email biasanya berarti menghabiskan akhir pekan untuk merekatkan Postfix,
Dovecot, Rspamd, dan sebuah webmail — atau memakai kotak surat hosted di mana orang lain membaca
metadata Anda. Freehold Mail adalah opsi ketiga: satu repo yang merakit stack modern yang Anda
jalankan sendiri, di mesin yang Anda kendalikan. Mail server dan webmail ditulis dalam bahasa yang
memory-safe; nginx dan PostgreSQL ditulis dalam C, jadi "memory-safe" menggambarkan bagian yang
kami pilih, bukan keseluruhan stack.

**Apa ini:** orkestrasi. File Compose, sebuah konfigurasi nginx, sebuah installer, dan dokumentasi
yang jujur. **Apa ini bukan:** fork atau penulisan ulang mail server milik siapa pun.

## Dua edisi

| Edisi | Mencakup | Login | Teruji E2E |
|---------|----------|-------|------------|
| **Full Mail** (default) | mail server + webmail + nginx | username/password native | ✅ ya |
| **Mail + SSO** | semua di atas **+ Keycloak + PostgreSQL** | OIDC/SSO | ⚠️ sebagian — stack dapat dijalankan, database dan OIDC discovery terverifikasi pada Keycloak 24; konfigurasi 26.0 yang disertakan dan perjalanan bolak-balik login di browser belum diukur. Lihat [Celah yang diketahui](../../../CHANGELOG.md#known-gaps-do-not-publish-without-deciding-these) |

Anda tidak pernah menyentuh Keycloak kecuali Anda menginginkan SSO; ia berada di sebuah file overlay opsional.

## Mulai cepat

Kebutuhan: sebuah host Linux dengan Docker dan Compose v2, domain yang Anda kendalikan, port
25/465/587/993/80/443 yang dapat dijangkau, dan sebuah sertifikat TLS.

```bash
git clone https://github.com/Novaza-ai/freeholdmail && cd freeholdmail
./install.sh
```

> **Baru saja menyewa server, atau akan menyewa?** Baca [`docs/HOSTING.md`](../../../docs/HOSTING.md)
> lebih dulu. Dokumen itu membawa Anda dari VPS kosong sampai kotak surat yang berfungsi, dengan
> perintah verifikasi di setiap langkah, dan menyebutkan satu hal yang tidak dapat Anda perbaiki
> setelahnya: **sebagian besar penyedia murah memblokir port 25 keluar**, yang membuat email menjadi
> mustahil sebaik apa pun Anda mengonfigurasi ini. Dokumen itu juga memuat angka RAM, CPU, dan disk
> hasil pengukuran agar Anda menyewa ukuran yang tepat alih-alih menebak.

Installer akan menanyakan edisi dan domain Anda, lalu:

1. membuat secret acak yang kuat ke dalam `.env` (mode 600, `umask 077` — tidak ada yang di-hardcode);
2. mengunci image container berdasarkan digest;
3. menyelesaikan path Let's Encrypt Anda (symlink `live/` tidak berfungsi di dalam container);
4. menjalankan stack dan mencetak perintah untuk membuat kotak surat pertama Anda.

Selanjutnya buat sebuah kotak surat dan masuk di `https://<your-domain>`:

```bash
# domain, then user — the roles field is required, or SMTP AUTH refuses the account
curl -u admin:$STALWART_FALLBACK_ADMIN_SECRET -X POST http://127.0.0.1:8080/api/principal \
  -H 'Content-Type: application/json' -d '{"type":"domain","name":"example.com"}'

curl -u admin:$STALWART_FALLBACK_ADMIN_SECRET -X POST http://127.0.0.1:8080/api/principal \
  -H 'Content-Type: application/json' \
  -d '{"type":"individual","name":"you@example.com","secrets":["<password>"],
       "emails":["you@example.com"],"roles":["user"]}'
```

Terakhir, setel record DNS Anda — [`docs/DNS.md`](../../../docs/DNS.md) memuat MX, SPF, DKIM, dan DMARC.

## Arsitektur

```
Browser ─HTTPS─▶ nginx ─┬─ /  and  /api/*  ─▶ Bulwark webmail (FE)   :3000
                        ├─ /jmap, /.well-known/jmap ─▶ Stalwart  :8080/JMAP
                        └─ /.well-known/openid-configuration ─▶ Keycloak (SSO edition)
SMTP/IMAP clients ───────────────────────────────▶ Stalwart  :25 :465 :587 :993
```

`/api/*` adalah milik webmail, yang menyajikan route konfigurasi dan session-nya sendiri di sana.
Hanya `/jmap` dan JMAP discovery yang mencapai mail server; API admin-nya sengaja tidak diekspos
melalui proxy.

Setiap kotak adalah container independen yang dapat ditukar. Hubungan front end ke back end
**hanya lewat jaringan** — JMAP di atas HTTP, tanpa linking kode. Batas itulah yang memungkinkan
repo ini berlisensi MIT sementara setiap komponen tetap memakai lisensinya sendiri.

## Perbandingan dengan yang lain

| | Freehold Mail | Mailu / Mailcow | docker-mailserver | Google Workspace |
|---|---|---|---|---|
| Mail server | Stalwart (Rust, JMAP-native) | Postfix + Dovecot | Postfix + Dovecot | — |
| Webmail disertakan | ✅ | ✅ | ❌ (sediakan sendiri) | ✅ |
| JMAP | ✅ | ❌ | ❌ | ❌ |
| SSO/OIDC | ✅ edisi opsional | sebagian | ❌ | ✅ |
| Data dipegang oleh Anda | ✅ | ✅ | ✅ | ❌ |
| Kematangan | **pre-1.0** | matang | matang | komersial |

Mailu, Mailcow, dan docker-mailserver sangat baik dan jauh lebih teruji di lapangan. Pilih
Freehold Mail jika Anda secara khusus menginginkan mail server Rust yang JMAP-native beserta webmail
dan SSO opsional dalam satu tempat.

## Cakupan, secara jujur

**Sekarang:** kotak surat, SMTP/IMAP/JMAP, webmail, TLS, SSO opsional — pengganti yang kredibel
untuk kotak surat hosted.

**Belum sekarang:** email marketing/massal, newsletter, kotak masuk bersama untuk tim, ticketing,
perkakas migrasi dari penyedia lain, atau control panel terkelola. Pengiriman massal khususnya
adalah disiplin deliverability, bukan sekadar sakelar fitur — jangan berasumsi ia tersedia.

**Roadmap:** lihat [`ROADMAP.md`](../../../ROADMAP.md) — jangka dekatnya adalah kelayakan untuk
dipercaya (SSO terverifikasi pada Keycloak yang disertakan, jalur mail server upstream terkini,
deliverability yang diukur pada domain nyata). Lebih jauh ke depan kami ingin stack ini menjadi
stack yang dapat dipakai software agent dengan aman: sebuah server MCP di atas JMAP, serta
kredensial per-agent yang tercakup terbatas dan dapat dicabut, alih-alih menyerahkan password Anda
kepada sebuah bot. Semua itu belum dibangun, dan nama proyek ini sengaja tidak diambil dari hal
tersebut. **Kontribusi untuk pekerjaan agent sangat diharapkan — lihat "Help wanted" di roadmap.**

## ⚖️ Lisensi

- **Repo ini** (orkestrasi, konfigurasi, installer, dokumentasi): **MIT** — lihat [`LICENSE`](../../../LICENSE).
- **Program-program yang di-deploy tetap memakai lisensinya sendiri** dan diambil sebagai
  image yang dipublikasikan; repo ini tidak memuat source mereka sama sekali:
  - Stalwart Mail Server — **AGPL-3.0-only OR SELv1** *(lisensi ganda; bukan "or later")*
  - Bulwark Webmail — **AGPL-3.0-only**
  - Keycloak — **Apache-2.0** *(edisi SSO)*
  - PostgreSQL — **PostgreSQL License** *(edisi SSO)*
  - nginx — **BSD-2-Clause**

Jika Anda **memodifikasi** Stalwart atau Bulwark dan menyajikannya kepada orang lain, AGPL mewajibkan
Anda mempublikasikan source yang dimodifikasi *dari komponen tersebut*. Menjalankan image tanpa
modifikasi tidak mewajibkan hal itu.
Detail: [`THIRD_PARTY_LICENSES.md`](../../../THIRD_PARTY_LICENSES.md) dan [`NOTICE`](../../../NOTICE).

## Keamanan

Open relay ditolak, submission mewajibkan autentikasi, dan mekanisme password
(`PLAIN`/`LOGIN`) hanya ditawarkan setelah STARTTLS — semuanya diukur, bukan diasumsikan. Ada pula
kelemahan nyata yang harus Anda antisipasi, termasuk API admin upstream yang mengembalikan password
akun dalam bentuk cleartext. **Baca [`SECURITY.md`](../../../SECURITY.md) sebelum mengekspos ini ke
internet.**

## Pengujian dan operasi

Keduanya ada di dalam repo — Anda dapat mereproduksi sendiri setiap klaim di atas:

```bash
tests/test_config.sh      # static: both editions validate, no secrets, digests pinned … (~seconds)
tests/test_e2e.sh         # real: stack up → send a message → read it back over IMAP (~2 min)
tests/test_e2e.sh --sso   # same, plus Keycloak + PostgreSQL
```

`test_e2e.sh` membangun stack sekali pakai pada port loopback-only dengan volume dan nama
container-nya sendiri, lalu membongkarnya saat keluar — ia tidak akan mengganggu deployment yang
sedang berjalan. Lihat [`tests/README.md`](../../../tests/README.md), termasuk apa saja yang sengaja
**tidak** dicakup oleh pengujian ini.

Operasi day-2 — backup, perpanjangan sertifikat, pengelolaan kotak surat, upgrade, playbook
insiden — ada di [`docs/RUNBOOK.md`](../../../docs/RUNBOOK.md). Prasyaratnya ada di
[`docs/REQUIREMENTS.md`](../../../docs/REQUIREMENTS.md).

## Berkontribusi

Lihat [`CONTRIBUTING.md`](../../../CONTRIBUTING.md). Satu aturan rumah: klaim tentang perilaku saat
runtime memerlukan pengukuran, bukan "works on my machine".

Siapa yang memutuskan apa, bagaimana menjadi maintainer, dan apa yang terjadi pada Anda jika proyek
ini suatu saat ditinggalkan: [`GOVERNANCE.md`](../../../GOVERNANCE.md). Dari siapa Anda dapat
mengharapkan balasan, dan pernyataan jujur tentang bus factor:
[`MAINTAINERS.md`](../../../MAINTAINERS.md).

## Siapa yang membangun ini

Dipimpin oleh **Daika Ginza** — [GitHub](https://github.com/daikaginza) ·
[Substack](https://substack.com/@daikaginza) ·
[LinkedIn](https://www.linkedin.com/in/daikaginza/) — bersama
[@anhkk1245](https://github.com/anhkk1245), di
**[Novaza Solution JSC](https://novaza.ai)**.

Kami menjalankan komponen-komponen stack ini (Stalwart dan Bulwark) di produksi untuk email kami
sendiri, dan kami membangun Freehold Mail untuk mengemas arsitektur tersebut bagi siapa pun yang
ingin melakukan self-hosting. Berlisensi MIT; lihat [`LICENSE`](../../../LICENSE) dan
[`NOTICE`](../../../NOTICE).

Tim lengkap, bagaimana keputusan dibuat, dan cara bergabung:
[`MAINTAINERS.md`](../../../MAINTAINERS.md) · [`GOVERNANCE.md`](../../../GOVERNANCE.md).

> Grafik kontributor GitHub saat ini hanya mengkredit `dependabot`, karena commit kami dibuat dengan
> identitas perusahaan yang tidak tertaut ke sebuah akun GitHub. Jika Anda berkontribusi, lakukan
> commit dengan nama dan email Anda sendiri — Anda akan dikreditkan dengan benar di sana.
> `MAINTAINERS.md` menjelaskan bagaimana kami memperbaiki hal ini untuk tim.

---

Tidak berafiliasi dengan Stalwart Labs, proyek Bulwark, atau Keycloak.
