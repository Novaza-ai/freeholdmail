<!-- Last-touched: 2026-08-05 — initial Simplified Chinese translation. -->
[English](../../../README.md) · **简体中文** — 英文版为准，参见 [`TRANSLATIONS.md`](../../../TRANSLATIONS.md)

> **本翻译仅供参考。** 如与英文版有任何冲突，一律以英文版为准。翻译可能滞后。
> 涉及安全与许可证的判断，请务必以英文原文为准。

# Freehold Mail

**别再租用你的收件箱。** 一套完整的自托管邮件系统 —— Rust 编写的邮件服务器，加上现代化的 Web 客户端。

> *Freehold*（永久产权）：完全属于你的财产，没有房东，也没有需要续签的租约。
> 自己运行这套系统，与向一个以你的数据为商业模式的人租用邮箱，区别正在于此。

[![CI](https://github.com/Novaza-ai/freeholdmail/actions/workflows/ci.yml/badge.svg)](https://github.com/Novaza-ai/freeholdmail/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](../../../LICENSE)
[![Components: AGPL-3.0](https://img.shields.io/badge/components-AGPL--3.0-orange.svg)](../../../THIRD_PARTY_LICENSES.md)
[![Status: pre-1.0](https://img.shields.io/badge/status-pre--1.0-yellow.svg)](../../../CHANGELOG.md)

<p align="center">
  <img src="../../../docs/media/inbox.png" alt="Freehold Mail 收件箱：文件夹侧栏、邮件列表与阅读窗格" width="820">
</p>

邮件服务器、Webmail 与 TLS 终结 —— 已经连接就绪，并附带一个安装程序：它为你生成密钥，
并准确告诉你需要设置哪些 DNS 记录。需要时可启用 SSO，不需要时它根本不存在。

> **状态：pre-1.0。** 默认版本已完成端到端测试 —— 一封真实邮件经由 SMTP → 邮箱 → IMAP 完整流转。
> SSO 版本可以启动，其数据库与 OIDC 发现已验证，但随附的 Keycloak 版本与浏览器登录流程尚未验证。
> 在依赖本项目之前，请阅读
> [已知差距](../../../CHANGELOG.md#known-gaps-do-not-publish-without-deciding-these)。

---

## 看它运行

Webmail 内置了一个引导教程。下面就是该教程在真实运行的系统上录制的结果 —— 邮件由
`scripts/seed_demo.py` 通过 SMTP 真实投递、再经 IMAP 读回，并非模拟：

<p align="center">
  <img src="../../../docs/media/tour.gif" alt="Webmail 引导教程：侧栏、写信、搜索、邮件列表、阅读窗格、标签、联系人、设置、键盘快捷键" width="820">
</p>

这里的每一张图都由脚本重新生成，从不修图 —— 命令见
[`docs/media/README.md`](../../../docs/media/README.md)。

## 为什么会有这个项目

自托管邮件通常只有两种结局：花一个周末把 Postfix、Dovecot、Rspamd 和某个 Webmail 拼在一起；
或者用一个托管邮箱，让别人读你的元数据。Freehold Mail 是第三种选择：用一个仓库，把一套现代、
内存安全的系统组装起来，运行在你自己掌控的机器上。

**它是什么：** 编排（orchestration）。Compose 文件、一份 nginx 配置、一个安装程序，以及诚实的文档。
**它不是什么：** 任何人邮件服务器的分支或重写。

## 两个版本

| 版本 | 包含 | 登录方式 | 端到端测试 |
|---------|----------|-------|------------|
| **Full Mail**（默认） | 邮件服务器 + Webmail + nginx | 原生用户名/密码 | ✅ 是 |
| **Mail + SSO** | 以上内容 **+ Keycloak + PostgreSQL** | OIDC/SSO | ⚠️ 部分 —— 系统可启动，数据库与 OIDC 发现已在 Keycloak 24 上验证；随附的 26.0 配置与浏览器登录往返尚未实测。参见[已知差距](../../../CHANGELOG.md#known-gaps-do-not-publish-without-deciding-these) |

除非你想要 SSO，否则完全不必接触 Keycloak；它位于一个可选的 overlay 文件中。

## 快速开始

前提条件：一台装有 Docker 与 Compose v2 的 Linux 主机、一个你拥有的域名、可访问的
25/465/587/993/80/443 端口，以及一份 TLS 证书。

```bash
git clone https://github.com/Novaza-ai/freeholdmail && cd freeholdmail
./install.sh
```

> **刚租下服务器，或正准备租？** 请先阅读 [`docs/HOSTING.md`](../../../docs/HOSTING.md)。
> 它带你从一台空白 VPS 走到可用邮箱，每一步都配有验证命令，并且点明了**事后无法补救的那一件事**：
> **多数廉价服务商封锁出站 25 端口**，那样无论配置多完美，邮件都发不出去。文中还有实测的
> 内存、CPU 与磁盘数据，让你按数据而非猜测来选配置。

安装程序会询问你选择哪个版本和域名，然后：

1. 在 `.env` 中生成高强度随机密钥（权限 600，`umask 077` —— 不含任何硬编码）；
2. 以摘要（digest）固定容器镜像；
3. 解析你的 Let's Encrypt 路径（`live/` 符号链接在容器内无法工作）；
4. 启动整套系统，并打印创建第一个邮箱所需的命令。

随后创建邮箱，并在 `https://<your-domain>` 登录：

```bash
# domain, then user — the roles field is required, or SMTP AUTH refuses the account
curl -u admin:$STALWART_FALLBACK_ADMIN_SECRET -X POST http://127.0.0.1:8080/api/principal \
  -H 'Content-Type: application/json' -d '{"type":"domain","name":"example.com"}'

curl -u admin:$STALWART_FALLBACK_ADMIN_SECRET -X POST http://127.0.0.1:8080/api/principal \
  -H 'Content-Type: application/json' \
  -d '{"type":"individual","name":"you@example.com","secrets":["<password>"],
       "emails":["you@example.com"],"roles":["user"]}'
```

最后设置 DNS 记录 —— MX、SPF、DKIM 与 DMARC 见
[`docs/DNS.md`](../../../docs/DNS.md)。

## 架构

```
Browser ─HTTPS─▶ nginx ─┬─ /  and  /api/*  ─▶ Bulwark webmail (FE)   :3000
                        ├─ /jmap, /.well-known/jmap ─▶ Stalwart  :8080/JMAP
                        └─ /.well-known/openid-configuration ─▶ Keycloak (SSO edition)
SMTP/IMAP clients ───────────────────────────────▶ Stalwart  :25 :465 :587 :993
```

`/api/*` 属于 Webmail，它在那里提供自己的配置与会话路由。只有 `/jmap` 与 JMAP 发现会到达
邮件服务器；其管理 API 被刻意排除在代理之外。

每个方框都是独立、可替换的容器。前端与后端之间**只有网络** —— HTTP 之上的 JMAP，不存在代码链接。
正是这条边界，让本仓库可以采用 MIT，而每个组件各自保留自己的许可证。

## 横向对比

| | Freehold Mail | Mailu / Mailcow | docker-mailserver | Google Workspace |
|---|---|---|---|---|
| 邮件服务器 | Stalwart（Rust，原生 JMAP） | Postfix + Dovecot | Postfix + Dovecot | — |
| 自带 Webmail | ✅ | ✅ | ❌（需自备） | ✅ |
| JMAP | ✅ | ❌ | ❌ | ❌ |
| SSO/OIDC | ✅ 可选版本 | 部分 | ❌ | ✅ |
| 数据归你所有 | ✅ | ✅ | ✅ | ❌ |
| 成熟度 | **pre-1.0** | 成熟 | 成熟 | 商业产品 |

Mailu、Mailcow 和 docker-mailserver 都很优秀，且久经实战考验。只有当你明确需要一套原生 JMAP、
Rust 编写的邮件服务器，并希望 Webmail 与可选 SSO 集中在一处时，才选择 Freehold Mail。

## 诚实的范围

**现在有：** 邮箱、SMTP/IMAP/JMAP、Webmail、TLS、可选 SSO —— 足以可信地替代一个托管邮箱。

**现在没有：** 营销/群发邮件、新闻通讯、团队共享收件箱、工单系统、从其他服务商迁移的工具，
或托管式控制面板。尤其是群发，它是一门投递率的功夫，而不是一个功能开关，请不要想当然。

**路线图：** 见 [`ROADMAP.md`](../../../ROADMAP.md) —— 近期重点是可信度（在随附的 Keycloak 上
验证 SSO、跟进上游邮件服务器的当前版本线、在真实域名上实测投递率）。更远的目标是让这套系统成为
软件智能体可以安全使用的基础设施：一个基于 JMAP 的 MCP 服务器，以及按智能体划分、可撤销的受限凭据，
而不是把密码交给机器人。这些都尚未实现，项目名称也刻意没有以此命名。
**欢迎在智能体方向上贡献 —— 参见路线图中的「Help wanted」。**

## ⚖️ 许可证

- **本仓库**（编排、配置、安装程序、文档）：**MIT** —— 见 [`LICENSE`](../../../LICENSE)。
- **它部署的程序各自保留自己的许可证**，以已发布镜像的形式拉取；本仓库不含它们的任何源代码：
  - Stalwart Mail Server —— **AGPL-3.0**
  - Bulwark Webmail —— **AGPL-3.0**
  - Keycloak —— **Apache-2.0**

如果你**修改** Stalwart 或 Bulwark 并对外提供服务，AGPL 要求你公开*该组件*修改后的源代码。
运行未经修改的镜像则不需要。详情见
[`THIRD_PARTY_LICENSES.md`](../../../THIRD_PARTY_LICENSES.md) 与 [`NOTICE`](../../../NOTICE)。

## 安全

开放中继被拒绝，投递必须认证，密码机制（`PLAIN`/`LOGIN`）只在 STARTTLS 之后才提供 ——
这些都是实测结果，不是假设。同时也存在你必须纳入规划的真实弱点，其中包括一个会以明文返回
账户密码的上游管理 API。**在把它暴露到互联网之前，请阅读
[`SECURITY.md`](../../../SECURITY.md)。**

## 测试与运维

两者都在仓库中 —— 上面的每一项主张你都可以自行复现：

```bash
tests/test_config.sh      # static: both editions validate, no secrets, digests pinned … (~seconds)
tests/test_e2e.sh         # real: stack up → send a message → read it back over IMAP (~2 min)
tests/test_e2e.sh --sso   # same, plus Keycloak + PostgreSQL
```

`test_e2e.sh` 会在仅绑定回环地址的端口上，用自己的卷与容器名构建一套一次性系统，并在退出时拆除 ——
它不会干扰正在运行的部署。请参阅 [`tests/README.md`](../../../tests/README.md)，其中也说明了这些测试
**刻意不覆盖**的范围。

日常运维 —— 备份、证书续期、邮箱管理、升级、事故处置 —— 见
[`docs/RUNBOOK.md`](../../../docs/RUNBOOK.md)。前提条件见
[`docs/REQUIREMENTS.md`](../../../docs/REQUIREMENTS.md)。

## 参与贡献

见 [`CONTRIBUTING.md`](../../../CONTRIBUTING.md)。有一条内部规矩：关于运行时行为的主张需要实测数据，
而不是「在我机器上能跑」。

谁来决定什么、如何成为维护者，以及如果这个项目被弃置你会怎样：
[`GOVERNANCE.md`](../../../GOVERNANCE.md)。谁会回复你，以及关于「巴士系数」的诚实说明：
[`MAINTAINERS.md`](../../../MAINTAINERS.md)。

## 谁在构建它

由 **Daika Ginza** 主导 —— [GitHub](https://github.com/daikaginza) ·
[Substack](https://substack.com/@daikaginza) ·
[LinkedIn](https://www.linkedin.com/in/daikaginza/) —— 与
[@anhkk1245](https://github.com/anhkk1245) 一起，在
**[Novaza Solution JSC](https://novaza.ai)**。

我们在生产环境中用这套系统的组件（Stalwart 与 Bulwark）承载自己的邮件，并把这套架构打包成
Freehold Mail，供任何想自托管的人使用。采用 MIT 许可证；见
[`LICENSE`](../../../LICENSE) 与 [`NOTICE`](../../../NOTICE)。

完整团队、决策方式与加入方法：
[`MAINTAINERS.md`](../../../MAINTAINERS.md) · [`GOVERNANCE.md`](../../../GOVERNANCE.md)。

> GitHub 的贡献者图谱目前只显示 `dependabot`，因为我们的提交使用了一个未绑定 GitHub 账号的
> 公司身份来署名。如果你参与贡献，请用你自己的姓名与邮箱提交 —— 那样你会被正确记录。
> `MAINTAINERS.md` 说明了我们打算如何为团队解决这个问题。

---

与 Stalwart Labs、Bulwark 项目或 Keycloak 均无隶属关系。
