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
  <a href="https://github.com/stalwartlabs/stalwart"><img src="https://img.shields.io/badge/mail%20server-Rust-orange.svg" alt="Mail server: Rust"></a>
  <a href="https://jmap.io"><img src="https://img.shields.io/badge/JMAP-native-blueviolet.svg" alt="JMAP native"></a>
  <a href="https://github.com/Novaza-ai/freeholdmail/attestations"><img src="https://img.shields.io/badge/SLSA-Build%20L2-brightgreen.svg" alt="SLSA Build Level 2"></a>
  <a href="https://github.com/Novaza-ai/freeholdmail/releases/latest"><img src="https://img.shields.io/badge/SBOM-SPDX-blue.svg" alt="SBOM: SPDX"></a>
  <a href="../../../LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <a href="../../../THIRD_PARTY_LICENSES.md"><img src="https://img.shields.io/badge/components-AGPL--3.0-orange.svg" alt="Components: AGPL-3.0"></a>
  <a href="../../../CHANGELOG.md"><img src="https://img.shields.io/badge/status-pre--1.0-yellow.svg" alt="Status: pre-1.0"></a>
</p>

[English](../../../README.md) · **Français** — La version anglaise fait foi, voir [`TRANSLATIONS.md`](../../../TRANSLATIONS.md)

> **Cette traduction est fournie à titre de courtoisie.** En cas de contradiction avec la version
> anglaise, c'est toujours l'anglais qui prévaut. Les traductions peuvent accuser du retard.
> Vérifiez toujours les décisions de sécurité et de licence sur l'original anglais.

# Freehold Mail

**Cessez de louer votre boîte de réception.** Une pile de messagerie complète et auto-hébergée —
serveur de messagerie en Rust, client web moderne.

> *Freehold* (pleine propriété) : un bien que vous possédez entièrement, sans propriétaire bailleur
> ni bail à renouveler. C'est là toute la différence entre faire tourner ceci et louer une boîte aux
> lettres à quelqu'un dont le modèle économique, ce sont vos données.

<p align="center">
  <img src="../../../docs/media/inbox.png" alt="La boîte de réception de Freehold Mail : barre latérale des dossiers, liste des messages et volet de lecture" width="820">
</p>

Serveur de messagerie, webmail et terminaison TLS — le tout câblé ensemble, avec un installateur qui
génère vos secrets et vous indique exactement quels enregistrements DNS créer. Le SSO est optionnel :
présent quand vous le voulez, absent sinon.

> **Statut : pré-1.0.** L'édition par défaut a été testée de bout en bout — un vrai message parcourt
> SMTP → boîte aux lettres → IMAP. L'édition SSO démarre, et sa base de données ainsi que la
> découverte OIDC sont vérifiées, mais la version de Keycloak livrée et le parcours de connexion dans
> le navigateur ne le sont pas. Lisez [Lacunes connues](../../../CHANGELOG.md#known-gaps-do-not-publish-without-deciding-these)
> avant de vous appuyer dessus.

---

## Le voir fonctionner

Le webmail embarque une visite guidée. Voici cette visite, enregistrée sur une pile réelle — les
messages sont livrés via SMTP puis relus via IMAP par `scripts/seed_demo.py`, ils ne sont pas
simulés :

<p align="center">
  <img src="../../../docs/media/tour.gif" alt="Visite guidée du webmail : barre latérale, rédaction, recherche, liste des messages, volet de lecture, étiquettes, contacts, paramètres, raccourcis clavier" width="820">
</p>

Toutes les images présentes ici sont régénérées par script, jamais retouchées — voir
[`docs/media/README.md`](../../../docs/media/README.md) pour les commandes.

## Pourquoi ce projet existe

Auto-héberger sa messagerie, c'est en général soit un week-end passé à assembler Postfix, Dovecot,
Rspamd et un webmail — soit une boîte aux lettres hébergée où quelqu'un d'autre lit vos métadonnées.
Freehold Mail est la troisième option : un dépôt unique qui assemble une pile moderne, que vous
faites tourner vous-même, sur une machine que vous contrôlez. Le serveur de messagerie et le webmail
sont écrits dans des langages sûrs en mémoire ; nginx et PostgreSQL sont en C, donc « sûr en
mémoire » décrit les parties que nous avons choisies, pas la pile entière.

**Ce que c'est :** de l'orchestration. Des fichiers Compose, une configuration nginx, un installateur
et une documentation honnête. **Ce que ce n'est pas :** un fork ou une réécriture du serveur de
messagerie de qui que ce soit.

## Deux éditions

| Édition | Comprend | Connexion | Testée E2E |
|---------|----------|-----------|------------|
| **Full Mail** (par défaut) | serveur de messagerie + webmail + nginx | nom d'utilisateur/mot de passe natifs | ✅ oui |
| **Mail + SSO** | ce qui précède **+ Keycloak + PostgreSQL** | OIDC/SSO | ⚠️ partiel — la pile démarre, la base de données et la découverte OIDC sont vérifiées sur Keycloak 24 ; la configuration 26.0 livrée et l'aller-retour de connexion dans le navigateur ne sont pas encore mesurés. Voir [Lacunes connues](../../../CHANGELOG.md#known-gaps-do-not-publish-without-deciding-these) |

Vous ne touchez jamais à Keycloak sauf si vous voulez le SSO ; il réside dans un fichier de surcharge
(overlay) optionnel.

## Démarrage rapide

Prérequis : un hôte Linux avec Docker et Compose v2, un domaine que vous contrôlez, les ports
25/465/587/993/80/443 joignables, et un certificat TLS.

```bash
git clone https://github.com/Novaza-ai/freeholdmail && cd freeholdmail
./install.sh
```

> **Vous venez de louer un serveur, ou êtes sur le point de le faire ?** Lisez d'abord
> [`docs/HOSTING.md`](../../../docs/HOSTING.md). Ce document va d'un VPS nu jusqu'à une boîte aux
> lettres fonctionnelle, avec une commande de vérification à chaque étape, et il nomme la seule chose
> que vous ne pourrez pas corriger après coup : **la plupart des hébergeurs bon marché bloquent le
> port 25 sortant**, ce qui rend la messagerie impossible quelle que soit la qualité de votre
> configuration. Il donne aussi des chiffres mesurés de RAM, de CPU et de disque, pour que vous louiez
> la bonne taille au lieu de deviner.

L'installateur vous demande votre édition et votre domaine, puis :

1. génère des secrets aléatoires forts dans `.env` (mode 600, `umask 077` — rien n'est codé en dur) ;
2. épingle les images de conteneurs par empreinte (digest) ;
3. résout vos chemins Let's Encrypt (les liens symboliques `live/` ne fonctionnent pas à l'intérieur des conteneurs) ;
4. démarre la pile et affiche les commandes pour créer votre première boîte aux lettres.

Créez ensuite une boîte aux lettres et connectez-vous sur `https://<your-domain>` :

```bash
# domain, then user — the roles field is required, or SMTP AUTH refuses the account
curl -u admin:$STALWART_FALLBACK_ADMIN_SECRET -X POST http://127.0.0.1:8080/api/principal \
  -H 'Content-Type: application/json' -d '{"type":"domain","name":"example.com"}'

curl -u admin:$STALWART_FALLBACK_ADMIN_SECRET -X POST http://127.0.0.1:8080/api/principal \
  -H 'Content-Type: application/json' \
  -d '{"type":"individual","name":"you@example.com","secrets":["<password>"],
       "emails":["you@example.com"],"roles":["user"]}'
```

Enfin, configurez vos enregistrements DNS — [`docs/DNS.md`](../../../docs/DNS.md) couvre MX, SPF, DKIM
et DMARC.

## Architecture

```
Browser ─HTTPS─▶ nginx ─┬─ /  and  /api/*  ─▶ Bulwark webmail (FE)   :3000
                        ├─ /jmap, /.well-known/jmap ─▶ Stalwart  :8080/JMAP
                        └─ /.well-known/openid-configuration ─▶ Keycloak (SSO edition)
SMTP/IMAP clients ───────────────────────────────▶ Stalwart  :25 :465 :587 :993
```

`/api/*` appartient au webmail, qui y expose ses propres routes de configuration et de session. Seuls
`/jmap` et la découverte JMAP atteignent le serveur de messagerie ; son API d'administration n'est
délibérément pas exposée à travers le proxy.

Chaque bloc est un conteneur indépendant et interchangeable. La liaison entre le front-end et le
back-end est **uniquement réseau** — du JMAP sur HTTP, sans liaison de code. C'est cette frontière qui
permet à ce dépôt d'être sous MIT tandis que chaque composant conserve sa propre licence.

## Comparaison

| | Freehold Mail | Mailu / Mailcow | docker-mailserver | Google Workspace |
|---|---|---|---|---|
| Serveur de messagerie | Stalwart (Rust, JMAP natif) | Postfix + Dovecot | Postfix + Dovecot | — |
| RAM au repos (mesurée) | **218–288 MiB** | mailcow: 6 GiB min (docs) | — | — |
| Webmail inclus | ✅ | ✅ | ❌ (à fournir vous-même) | ✅ |
| JMAP | ✅ | ❌ | ❌ | ❌ |
| SSO/OIDC | ✅ édition optionnelle | partiel | ❌ | ✅ |
| Vous détenez les données | ✅ | ✅ | ✅ | ❌ |
| Maturité | **pré-1.0** | mature | mature | commercial |

Mailu, Mailcow et docker-mailserver sont excellents et bien plus éprouvés au combat. Choisissez
Freehold Mail si vous voulez spécifiquement un serveur de messagerie en Rust, nativement JMAP, avec un
webmail et un SSO optionnel réunis au même endroit.

## Le périmètre, honnêtement

**Aujourd'hui :** boîtes aux lettres, SMTP/IMAP/JMAP, webmail, TLS, SSO optionnel — un remplacement
crédible pour une boîte aux lettres hébergée.

**Pas aujourd'hui :** e-mailing marketing ou en masse, newsletters, boîtes de réception partagées
d'équipe, ticketing, outils de migration depuis d'autres fournisseurs, ou un panneau de contrôle
managé. L'envoi en masse, en particulier, est une discipline de délivrabilité et non une option à
activer — ne le présumez pas.

**Feuille de route :** voir [`ROADMAP.md`](../../../ROADMAP.md) — à court terme, la priorité est la
fiabilité (SSO vérifié sur le Keycloak livré, ligne amont actuelle du serveur de messagerie,
délivrabilité mesurée sur un domaine réel). Plus loin, nous voulons que cette pile soit celle que les
agents logiciels peuvent utiliser en toute sécurité : un serveur MCP au-dessus de JMAP, et des
identifiants par agent, cantonnés et révocables, plutôt que de confier votre mot de passe à un bot.
Rien de tout cela n'est encore construit, et le projet n'a délibérément pas été nommé d'après cela.
**Les contributions sur le volet agents sont les bienvenues — voir « Help wanted » dans la feuille de
route.**

## ⚖️ Licence

- **Ce dépôt** (orchestration, configuration, installateur, documentation) : **MIT** — voir [`LICENSE`](../../../LICENSE).
- **Les programmes qu'il déploie conservent leurs propres licences** et sont récupérés sous forme
  d'images publiées ; ce dépôt ne contient aucune de leurs sources :
  - Stalwart Mail Server — **AGPL-3.0-only OR SELv1** *(double licence ; pas « or later »)*
  - Bulwark Webmail — **AGPL-3.0-only**
  - Keycloak — **Apache-2.0** *(édition SSO)*
  - PostgreSQL — **PostgreSQL License** *(édition SSO)*
  - nginx — **BSD-2-Clause**

Si vous **modifiez** Stalwart ou Bulwark et le mettez à disposition d'autrui, l'AGPL vous impose de
publier les sources modifiées *de ce composant*. Exécuter les images non modifiées ne l'impose pas.
Détails : [`THIRD_PARTY_LICENSES.md`](../../../THIRD_PARTY_LICENSES.md) et [`NOTICE`](../../../NOTICE).

## Sécurité

Le relais ouvert est refusé, la soumission exige une authentification, et les mécanismes par mot de
passe (`PLAIN`/`LOGIN`) ne sont proposés qu'après STARTTLS — le tout mesuré, non supposé. Il existe
aussi de vraies faiblesses que vous devez anticiper, dont une API d'administration amont qui renvoie
les mots de passe des comptes en clair. **Lisez [`SECURITY.md`](../../../SECURITY.md) avant d'exposer
ceci à Internet.**

## Tests et exploitation

Les deux sont dans le dépôt — vous pouvez reproduire vous-même chacune des affirmations ci-dessus :

```bash
tests/test_config.sh      # static: both editions validate, no secrets, digests pinned … (~seconds)
tests/test_e2e.sh         # real: stack up → send a message → read it back over IMAP (~2 min)
tests/test_e2e.sh --sso   # same, plus Keycloak + PostgreSQL
```

`test_e2e.sh` construit une pile jetable sur des ports en boucle locale uniquement, avec ses propres
volumes et noms de conteneurs, et la démonte en sortant — elle ne perturbera pas un déploiement en
cours d'exécution. Voir [`tests/README.md`](../../../tests/README.md), y compris ce que ces tests ne
couvrent délibérément **pas**.

L'exploitation au quotidien (« day-2 ») — sauvegardes, renouvellement des certificats, gestion des
boîtes aux lettres, mises à niveau, procédures d'incident — se trouve dans
[`docs/RUNBOOK.md`](../../../docs/RUNBOOK.md). Les prérequis sont dans
[`docs/REQUIREMENTS.md`](../../../docs/REQUIREMENTS.md).

## Contribuer

Voir [`CONTRIBUTING.md`](../../../CONTRIBUTING.md). Une règle de la maison : les affirmations sur le
comportement à l'exécution demandent des mesures, pas un « ça marche sur ma machine ».

Qui décide quoi, comment devenir mainteneur, et ce qu'il advient de vous si ce projet est un jour
abandonné : [`GOVERNANCE.md`](../../../GOVERNANCE.md). De qui attendre une réponse, et un exposé
honnête du facteur bus : [`MAINTAINERS.md`](../../../MAINTAINERS.md).

## Qui construit ce projet

Dirigé par **Daika Ginza** — [GitHub](https://github.com/daikaginza) ·
[Substack](https://substack.com/@daikaginza) ·
[LinkedIn](https://www.linkedin.com/in/daikaginza/) — avec
[@anhkk1245](https://github.com/anhkk1245), chez
**[Novaza Solution JSC](https://novaza.ai)**.

Nous exploitons les composants de cette pile (Stalwart et Bulwark) en production pour notre propre
messagerie, et nous avons construit Freehold Mail pour empaqueter cette architecture à destination de
quiconque veut l'auto-héberger. Sous licence MIT ; voir [`LICENSE`](../../../LICENSE) et
[`NOTICE`](../../../NOTICE).

L'équipe complète, la manière dont les décisions sont prises, et comment nous rejoindre :
[`MAINTAINERS.md`](../../../MAINTAINERS.md) · [`GOVERNANCE.md`](../../../GOVERNANCE.md).

> Le graphe des contributeurs de GitHub ne crédite actuellement que `dependabot`, parce que nos
> commits ont pour auteur une identité d'entreprise qui n'est liée à aucun compte GitHub. Si vous
> contribuez, faites vos commits sous vos propres nom et adresse e-mail — vous y serez correctement
> crédité. `MAINTAINERS.md` explique comment nous corrigeons cela pour l'équipe.

---

Sans affiliation avec Stalwart Labs, le projet Bulwark ou Keycloak.
