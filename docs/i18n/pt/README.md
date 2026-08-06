<!-- Last-touched: 2026-08-06 — licence list completed and the "memory-safe" claim corrected. -->
[English](../../../README.md) · **Português** — a versão em inglês é a autoritativa, consulte [`TRANSLATIONS.md`](../../../TRANSLATIONS.md)

> **Esta tradução é uma cortesia.** Se algo aqui entrar em conflito com a versão em inglês, o inglês
> prevalece sempre. As traduções podem ficar desatualizadas. Verifique sempre as decisões de segurança
> e de licenciamento no original em inglês.

# Freehold Mail

**Pare de alugar a sua caixa de entrada.** Uma stack de e-mail completa e auto-hospedada — servidor
de e-mail em Rust, cliente web moderno.

> *Freehold* (propriedade plena): um bem que é inteiramente seu, sem proprietário acima de si e sem
> contrato para renovar. É essa a diferença entre executar isto e alugar uma caixa de correio a
> alguém cujo modelo de negócio são os seus dados.

[![CI](https://github.com/Novaza-ai/freeholdmail/actions/workflows/ci.yml/badge.svg)](https://github.com/Novaza-ai/freeholdmail/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](../../../LICENSE)
[![Components: AGPL-3.0](https://img.shields.io/badge/components-AGPL--3.0-orange.svg)](../../../THIRD_PARTY_LICENSES.md)
[![Status: pre-1.0](https://img.shields.io/badge/status-pre--1.0-yellow.svg)](../../../CHANGELOG.md)

<p align="center">
  <img src="../../../docs/media/inbox.png" alt="A caixa de entrada do Freehold Mail: barra lateral de pastas, lista de mensagens e painel de leitura" width="820">
</p>

Servidor de e-mail, webmail e terminação TLS — ligados entre si, com um instalador que gera os seus
segredos e indica exatamente que registos DNS deve configurar. SSO opcional quando o quiser, ausente
quando não o quiser.

> **Estado: pre-1.0.** A edição predefinida foi testada de ponta a ponta — uma mensagem real percorre
> SMTP → caixa de correio → IMAP. A edição com SSO arranca e a sua base de dados e a descoberta OIDC
> estão verificadas, mas a versão do Keycloak que é distribuída e o fluxo de login no navegador não
> estão. Leia [Lacunas conhecidas](../../../CHANGELOG.md#known-gaps-do-not-publish-without-deciding-these)
> antes de depender disto.

---

## Veja funcionar

O webmail inclui um tour guiado. Este é esse tour, gravado sobre uma stack real — as mensagens são
entregues por SMTP e lidas de volta por IMAP pelo `scripts/seed_demo.py`, não são simuladas:

<p align="center">
  <img src="../../../docs/media/tour.gif" alt="Tour guiado do webmail: barra lateral, composição, pesquisa, lista de mensagens, painel de leitura, etiquetas, contactos, definições, atalhos de teclado" width="820">
</p>

Todas as imagens aqui são regeradas por script, nunca retocadas — consulte
[`docs/media/README.md`](../../../docs/media/README.md) para os comandos.

## Por que isto existe

Auto-hospedar e-mail costuma ser uma de duas coisas: um fim de semana inteiro para colar Postfix,
Dovecot, Rspamd e um webmail — ou uma caixa de correio alojada onde outra pessoa lê os seus
metadados. O Freehold Mail é a terceira opção: um único repositório que monta uma stack moderna que executa
você mesmo, numa máquina que controla. O servidor de e-mail e o webmail são escritos em linguagens
com segurança de memória; o nginx e o PostgreSQL são escritos em C, por isso «segurança de memória» descreve
as partes que escolhemos, não a stack inteira.

**O que é:** orquestração. Ficheiros Compose, uma configuração nginx, um instalador e documentação
honesta. **O que não é:** um fork ou uma reescrita do servidor de e-mail de ninguém.

## Duas edições

| Edição | Inclui | Login | Testado E2E |
|---------|----------|-------|------------|
| **Full Mail** (predefinida) | servidor de e-mail + webmail + nginx | nome de conta/senha nativos | ✅ sim |
| **Mail + SSO** | o acima **+ Keycloak + PostgreSQL** | OIDC/SSO | ⚠️ parcial — a stack arranca, a base de dados e a descoberta OIDC estão verificadas no Keycloak 24; a configuração 26.0 distribuída e o ciclo completo de login no navegador ainda não foram medidos. Consulte [Lacunas conhecidas](../../../CHANGELOG.md#known-gaps-do-not-publish-without-deciding-these) |

Nunca toca no Keycloak a menos que queira SSO; ele vive num ficheiro de overlay opcional.

## Início rápido

Requisitos: um host Linux com Docker e Compose v2, um domínio que controle, as portas
25/465/587/993/80/443 acessíveis e um certificado TLS.

```bash
git clone https://github.com/Novaza-ai/freeholdmail && cd freeholdmail
./install.sh
```

> **Acabou de alugar um servidor, ou está prestes a fazê-lo?** Leia primeiro
> [`docs/HOSTING.md`](../../../docs/HOSTING.md). Vai de um VPS vazio até uma caixa de correio a
> funcionar, com um comando de verificação em cada passo, e nomeia a única coisa que não poderá
> corrigir depois: **a maioria dos provedores baratos bloqueia a porta 25 de saída**, o que torna o
> e-mail impossível por melhor que configure isto. Também tem valores medidos de RAM, CPU e disco
> para que alugue o tamanho certo em vez de adivinhar.

O instalador pergunta pela sua edição e domínio e, depois:

1. gera segredos aleatórios fortes em `.env` (modo 600, `umask 077` — nada hardcoded);
2. fixa as imagens dos containers por digest;
3. resolve os seus caminhos do Let's Encrypt (os symlinks `live/` não funcionam dentro de containers);
4. levanta a stack e imprime os comandos para criar a sua primeira caixa de correio.

Em seguida crie uma caixa de correio e entre em `https://<your-domain>`:

```bash
# domain, then user — the roles field is required, or SMTP AUTH refuses the account
curl -u admin:$STALWART_FALLBACK_ADMIN_SECRET -X POST http://127.0.0.1:8080/api/principal \
  -H 'Content-Type: application/json' -d '{"type":"domain","name":"example.com"}'

curl -u admin:$STALWART_FALLBACK_ADMIN_SECRET -X POST http://127.0.0.1:8080/api/principal \
  -H 'Content-Type: application/json' \
  -d '{"type":"individual","name":"you@example.com","secrets":["<password>"],
       "emails":["you@example.com"],"roles":["user"]}'
```

Por fim, configure os seus registos DNS — [`docs/DNS.md`](../../../docs/DNS.md) tem MX, SPF, DKIM e
DMARC.

## Arquitetura

```
Browser ─HTTPS─▶ nginx ─┬─ /  and  /api/*  ─▶ Bulwark webmail (FE)   :3000
                        ├─ /jmap, /.well-known/jmap ─▶ Stalwart  :8080/JMAP
                        └─ /.well-known/openid-configuration ─▶ Keycloak (SSO edition)
SMTP/IMAP clients ───────────────────────────────▶ Stalwart  :25 :465 :587 :993
```

`/api/*` pertence ao webmail, que serve aí as suas próprias rotas de configuração e de sessão. Só
`/jmap` e a descoberta JMAP chegam ao servidor de e-mail; a sua API de administração não é
deliberadamente exposta através do proxy.

Cada caixa é um container independente e substituível. Do front end ao back end a ligação é **apenas
de rede** — JMAP sobre HTTP, sem qualquer ligação de código. É essa fronteira que permite que este
repositório seja MIT enquanto cada componente mantém a sua própria licença.

## Como se compara

| | Freehold Mail | Mailu / Mailcow | docker-mailserver | Google Workspace |
|---|---|---|---|---|
| Servidor de e-mail | Stalwart (Rust, nativo em JMAP) | Postfix + Dovecot | Postfix + Dovecot | — |
| Webmail incluído | ✅ | ✅ | ❌ (use o seu) | ✅ |
| JMAP | ✅ | ❌ | ❌ | ❌ |
| SSO/OIDC | ✅ edição opcional | parcial | ❌ | ✅ |
| Os dados são seus | ✅ | ✅ | ✅ | ❌ |
| Maturidade | **pre-1.0** | madura | madura | comercial |

Mailu, Mailcow e docker-mailserver são excelentes e muito mais testados em produção. Escolha o
Freehold Mail se quiser especificamente um servidor de e-mail em Rust, nativo em JMAP, com webmail e
SSO opcional num só lugar.

## Escopo, com honestidade

**Agora:** caixas de correio, SMTP/IMAP/JMAP, webmail, TLS, SSO opcional — um substituto credível
para uma caixa de correio alojada.

**Agora não:** e-mail de marketing/em massa, newsletters, caixas de entrada partilhadas de equipa,
ticketing, ferramentas de migração de outros fornecedores ou um painel de controlo gerido. O envio em
massa, em particular, é uma disciplina de entregabilidade e não um interruptor de funcionalidade —
não parta do princípio de que existe.

**Roteiro:** consulte [`ROADMAP.md`](../../../ROADMAP.md) — no curto prazo o foco é a confiabilidade
(SSO verificado no Keycloak distribuído, linha atual do servidor de e-mail upstream, entregabilidade
medida num domínio real). Mais adiante queremos que esta stack seja aquela que os agentes de software
podem usar com segurança: um servidor MCP sobre JMAP e credenciais por agente, com escopo limitado e
revogáveis, em vez de entregar a sua senha a um bot. Nada disso está construído ainda, e o projeto
deliberadamente não tem o nome disso. **Contribuições no trabalho sobre agentes são bem-vindas —
consulte "Help wanted" no roteiro.**

## ⚖️ Licença

- **Este repositório** (orquestração, configuração, instalador, documentação): **MIT** — consulte
  [`LICENSE`](../../../LICENSE).
- **Os programas que ele implanta mantêm as suas próprias licenças** e são obtidos como imagens
  publicadas; este repositório não contém nenhum do código-fonte deles:
  - Stalwart Mail Server — **AGPL-3.0-only OR SELv1** *(licença dupla; não "or later")*
  - Bulwark Webmail — **AGPL-3.0-only**
  - Keycloak — **Apache-2.0** *(edição SSO)*
  - PostgreSQL — **PostgreSQL License** *(edição SSO)*
  - nginx — **BSD-2-Clause**

Se **modificar** o Stalwart ou o Bulwark e o servir a terceiros, a AGPL exige que publique o
código-fonte modificado *desse componente*. Executar as imagens não modificadas não exige isso.
Detalhes: [`THIRD_PARTY_LICENSES.md`](../../../THIRD_PARTY_LICENSES.md) e
[`NOTICE`](../../../NOTICE).

## Segurança

O open relay é recusado, a submissão exige autenticação e os mecanismos de senha (`PLAIN`/`LOGIN`) só
são oferecidos depois de STARTTLS — tudo medido, não presumido. Existem também fraquezas reais com as
quais tem de contar, incluindo uma API de administração upstream que devolve as senhas das contas em
texto simples. **Leia [`SECURITY.md`](../../../SECURITY.md) antes de expor isto à internet.**

## Testes e operações

Ambos estão no repositório — pode reproduzir você mesmo todas as afirmações acima:

```bash
tests/test_config.sh      # static: both editions validate, no secrets, digests pinned … (~seconds)
tests/test_e2e.sh         # real: stack up → send a message → read it back over IMAP (~2 min)
tests/test_e2e.sh --sso   # same, plus Keycloak + PostgreSQL
```

O `test_e2e.sh` constrói uma stack descartável em portas apenas de loopback, com os seus próprios
volumes e nomes de containers, e desmonta-a ao sair — não perturba uma implantação em execução.
Consulte [`tests/README.md`](../../../tests/README.md), incluindo o que estes testes deliberadamente
**não** cobrem.

As operações do dia a dia — cópias de segurança, renovação de certificados, gestão de caixas de
correio, atualizações, playbooks de incidentes — estão em
[`docs/RUNBOOK.md`](../../../docs/RUNBOOK.md). Os pré-requisitos estão em
[`docs/REQUIREMENTS.md`](../../../docs/REQUIREMENTS.md).

## Como contribuir

Consulte [`CONTRIBUTING.md`](../../../CONTRIBUTING.md). Há uma regra da casa: afirmações sobre o
comportamento em execução precisam de medições, não de "funciona na minha máquina".

Quem decide o quê, como tornar-se mantenedor e o que lhe acontece se este projeto for algum dia
abandonado: [`GOVERNANCE.md`](../../../GOVERNANCE.md). De quem esperar uma resposta, e uma declaração
honesta do bus factor: [`MAINTAINERS.md`](../../../MAINTAINERS.md).

## Quem constrói isto

Liderado por **Daika Ginza** — [GitHub](https://github.com/daikaginza) ·
[Substack](https://substack.com/@daikaginza) ·
[LinkedIn](https://www.linkedin.com/in/daikaginza/) — com
[@anhkk1245](https://github.com/anhkk1245), na
**[Novaza Solution JSC](https://novaza.ai)**.

Executamos os componentes desta stack (Stalwart e Bulwark) em produção para o nosso próprio e-mail, e
construímos o Freehold Mail para empacotar essa arquitetura para quem a quiser auto-hospedar.
Licenciado sob MIT; consulte [`LICENSE`](../../../LICENSE) e [`NOTICE`](../../../NOTICE).

Equipa completa, como as decisões são tomadas e como aderir:
[`MAINTAINERS.md`](../../../MAINTAINERS.md) · [`GOVERNANCE.md`](../../../GOVERNANCE.md).

> O gráfico de contribuidores do GitHub atualmente credita apenas o `dependabot`, porque os nossos
> commits são assinados sob uma identidade de empresa que não está associada a uma conta GitHub. Se
> contribuir, faça commit com o seu próprio nome e e-mail — aí será creditado corretamente. O
> `MAINTAINERS.md` explica como estamos a resolver isto para a equipa.

---

Sem qualquer afiliação com a Stalwart Labs, o projeto Bulwark ou o Keycloak.
