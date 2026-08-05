<!-- Last-touched: 2026-08-05 — initial Hindi translation. -->
[English](../../../README.md) · **हिन्दी** — अंग्रेज़ी संस्करण ही प्रामाणिक है, देखें [`TRANSLATIONS.md`](../../../TRANSLATIONS.md)

> **यह अनुवाद केवल सुविधा के लिए है।** यदि इसमें और अंग्रेज़ी संस्करण में कोई विरोधाभास हो, तो
> हमेशा अंग्रेज़ी ही मान्य होगी। अनुवाद पीछे रह सकते हैं। security और licence से जुड़े हर निर्णय को
> हमेशा अंग्रेज़ी मूल के विरुद्ध सत्यापित करें।

# Freehold Mail

**अपना inbox किराए पर लेना बंद कीजिए।** एक सम्पूर्ण, self-hosted मेल स्टैक — Rust मेल सर्वर,
आधुनिक वेब क्लाइंट।

> *Freehold*: वह सम्पत्ति जो पूरी तरह आपकी अपनी है — न कोई मकान-मालिक, न कोई पट्टा जिसे नवीनीकृत
> करना पड़े। इसे स्वयं चलाने और ऐसे किसी से mailbox किराए पर लेने में, जिसका व्यापार-मॉडल ही
> आपका डेटा है, यही अंतर है।

[![CI](https://github.com/Novaza-ai/freeholdmail/actions/workflows/ci.yml/badge.svg)](https://github.com/Novaza-ai/freeholdmail/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](../../../LICENSE)
[![Components: AGPL-3.0](https://img.shields.io/badge/components-AGPL--3.0-orange.svg)](../../../THIRD_PARTY_LICENSES.md)
[![Status: pre-1.0](https://img.shields.io/badge/status-pre--1.0-yellow.svg)](../../../CHANGELOG.md)

<p align="center">
  <img src="../../../docs/media/inbox.png" alt="Freehold Mail का inbox: फ़ोल्डर साइडबार, संदेश सूची और रीडिंग पेन" width="820">
</p>

मेल सर्वर, webmail और TLS termination — आपस में जुड़े हुए, साथ में एक installer जो आपके secrets
बनाता है और ठीक-ठीक बताता है कि कौन-से DNS रिकॉर्ड सेट करने हैं। SSO वैकल्पिक है — जब चाहिए तब
मौजूद, जब नहीं चाहिए तब बिलकुल अनुपस्थित।

> **स्थिति: pre-1.0.** डिफ़ॉल्ट edition की end-to-end जाँच हो चुकी है — एक वास्तविक संदेश
> SMTP → mailbox → IMAP की यात्रा करता है। SSO edition शुरू होता है और उसका database तथा OIDC
> discovery सत्यापित हैं, लेकिन जो Keycloak संस्करण भेजा जाता है और ब्राउज़र का लॉगिन फ़्लो
> सत्यापित नहीं हैं। इस पर निर्भर होने से पहले
> [ज्ञात कमियाँ](../../../CHANGELOG.md#known-gaps-do-not-publish-without-deciding-these) पढ़ें।

---

## इसे काम करते देखिए

Webmail के साथ एक गाइडेड टूर आता है। यह वही टूर है, जिसे एक वास्तविक स्टैक पर रिकॉर्ड किया गया —
संदेश mock नहीं हैं, उन्हें `scripts/seed_demo.py` द्वारा SMTP से डिलीवर किया जाता है और IMAP से
वापस पढ़ा जाता है:

<p align="center">
  <img src="../../../docs/media/tour.gif" alt="Webmail का गाइडेड टूर: साइडबार, कम्पोज़, खोज, संदेश सूची, रीडिंग पेन, टैग, संपर्क, सेटिंग्स, कीबोर्ड शॉर्टकट" width="820">
</p>

यहाँ की हर तस्वीर स्क्रिप्ट से दोबारा बनाई जाती है, कभी रीटच नहीं की जाती — कमांड के लिए देखें
[`docs/media/README.md`](../../../docs/media/README.md)।

## यह क्यों मौजूद है

ईमेल self-host करना आमतौर पर या तो Postfix, Dovecot, Rspamd और किसी webmail को जोड़ने में बीता
एक पूरा सप्ताहांत होता है — या फिर एक hosted mailbox, जहाँ कोई और आपका metadata पढ़ता है।
Freehold Mail तीसरा विकल्प है: एक ही repo जो आधुनिक, memory-safe स्टैक को इकट्ठा करता है, जिसे
आप स्वयं, अपने नियंत्रण की मशीन पर चलाते हैं।

**यह क्या है:** orchestration। Compose फ़ाइलें, एक nginx config, एक installer, और ईमानदार
दस्तावेज़। **यह क्या नहीं है:** किसी के मेल सर्वर का fork या rewrite नहीं।

## दो editions

| Edition | इसमें शामिल | लॉगिन | E2E परीक्षित |
|---------|----------|-------|------------|
| **Full Mail** (डिफ़ॉल्ट) | मेल सर्वर + webmail + nginx | नेटिव username/password | ✅ हाँ |
| **Mail + SSO** | उपरोक्त **+ Keycloak + PostgreSQL** | OIDC/SSO | ⚠️ आंशिक — स्टैक शुरू होता है, database और OIDC discovery Keycloak 24 पर सत्यापित; जो 26.0 config भेजा जाता है और ब्राउज़र लॉगिन का पूरा चक्र अभी मापा नहीं गया। देखें [ज्ञात कमियाँ](../../../CHANGELOG.md#known-gaps-do-not-publish-without-deciding-these) |

जब तक आपको SSO न चाहिए, आप Keycloak को छूते तक नहीं; वह एक वैकल्पिक overlay फ़ाइल में रहता है।

## क्विकस्टार्ट

आवश्यकताएँ: Docker और Compose v2 वाला एक Linux होस्ट, आपके नियंत्रण का एक domain, पहुँच-योग्य
25/465/587/993/80/443 पोर्ट, और एक TLS प्रमाणपत्र।

```bash
git clone https://github.com/Novaza-ai/freeholdmail && cd freeholdmail
./install.sh
```

> **अभी-अभी सर्वर किराए पर लिया है, या लेने वाले हैं?** पहले [`docs/HOSTING.md`](../../../docs/HOSTING.md)
> पढ़ें। यह एक खाली VPS से चालू mailbox तक ले जाता है, हर चरण पर एक सत्यापन कमांड के साथ, और उस
> एक चीज़ का नाम लेता है जिसे आप बाद में ठीक नहीं कर सकते: **अधिकांश सस्ते प्रोवाइडर outbound
> पोर्ट 25 ब्लॉक करते हैं**, जिससे मेल असंभव हो जाता है — चाहे आप इसे कितनी ही अच्छी तरह
> कॉन्फ़िगर करें। इसमें मापे गए RAM, CPU और डिस्क के आँकड़े भी हैं, ताकि आप अंदाज़े के बजाय सही
> आकार किराए पर लें।

Installer आपसे आपका edition और domain पूछता है, फिर:

1. मज़बूत रैंडम secrets बनाकर `.env` में डालता है (mode 600, `umask 077` — कुछ भी hardcoded नहीं);
2. container images को digest से पिन करता है;
3. आपके Let's Encrypt पाथ हल करता है (`live/` symlink कंटेनरों के भीतर काम नहीं करते);
4. स्टैक को ऊपर लाता है और आपका पहला mailbox बनाने की कमांड प्रिंट करता है।

फिर एक mailbox बनाइए और `https://<your-domain>` पर लॉगिन कीजिए:

```bash
# domain, then user — the roles field is required, or SMTP AUTH refuses the account
curl -u admin:$STALWART_FALLBACK_ADMIN_SECRET -X POST http://127.0.0.1:8080/api/principal \
  -H 'Content-Type: application/json' -d '{"type":"domain","name":"example.com"}'

curl -u admin:$STALWART_FALLBACK_ADMIN_SECRET -X POST http://127.0.0.1:8080/api/principal \
  -H 'Content-Type: application/json' \
  -d '{"type":"individual","name":"you@example.com","secrets":["<password>"],
       "emails":["you@example.com"],"roles":["user"]}'
```

अंत में अपने DNS रिकॉर्ड सेट कीजिए — MX, SPF, DKIM और DMARC
[`docs/DNS.md`](../../../docs/DNS.md) में हैं।

## आर्किटेक्चर

```
Browser ─HTTPS─▶ nginx ─┬─ /  and  /api/*  ─▶ Bulwark webmail (FE)   :3000
                        ├─ /jmap, /.well-known/jmap ─▶ Stalwart  :8080/JMAP
                        └─ /.well-known/openid-configuration ─▶ Keycloak (SSO edition)
SMTP/IMAP clients ───────────────────────────────▶ Stalwart  :25 :465 :587 :993
```

`/api/*` webmail का है, जो अपने स्वयं के configuration और session रूट वहीं परोसता है। मेल सर्वर
तक केवल `/jmap` और JMAP discovery पहुँचते हैं; उसका admin API जानबूझकर proxy के ज़रिए उजागर
नहीं किया गया है।

हर बॉक्स एक स्वतंत्र, अदला-बदली योग्य container है। फ़्रंट एंड से बैक एंड तक संबंध **केवल
नेटवर्क** का है — HTTP पर JMAP, कोई code linking नहीं। यही सीमा इस repo को MIT रहने देती है,
जबकि हर component अपनी licence बनाए रखता है।

## तुलना कैसी है

| | Freehold Mail | Mailu / Mailcow | docker-mailserver | Google Workspace |
|---|---|---|---|---|
| मेल सर्वर | Stalwart (Rust, JMAP-native) | Postfix + Dovecot | Postfix + Dovecot | — |
| Webmail शामिल | ✅ | ✅ | ❌ (अपना लाइए) | ✅ |
| JMAP | ✅ | ❌ | ❌ | ❌ |
| SSO/OIDC | ✅ वैकल्पिक edition | आंशिक | ❌ | ✅ |
| डेटा आपके पास रहता है | ✅ | ✅ | ✅ | ❌ |
| परिपक्वता | **pre-1.0** | परिपक्व | परिपक्व | व्यावसायिक |

Mailu, Mailcow और docker-mailserver बेहतरीन हैं और कहीं ज़्यादा युद्ध-परखे हुए हैं। Freehold Mail
तभी चुनिए जब आपको विशेष रूप से एक JMAP-native, Rust मेल सर्वर, साथ में webmail और वैकल्पिक SSO,
एक ही जगह चाहिए।

## दायरा, ईमानदारी से

**अभी:** mailboxes, SMTP/IMAP/JMAP, webmail, TLS, वैकल्पिक SSO — एक hosted mailbox का
विश्वसनीय विकल्प।

**अभी नहीं:** मार्केटिंग/बल्क ईमेल, न्यूज़लेटर, साझा टीम inbox, ticketing, दूसरे प्रोवाइडरों से
migration टूलिंग, या कोई managed control panel। विशेष रूप से बल्क भेजना एक deliverability
अनुशासन है, कोई फ़ीचर टॉगल नहीं — इसे मान कर मत चलिए।

**रोडमैप:** देखें [`ROADMAP.md`](../../../ROADMAP.md) — निकट अवधि में लक्ष्य भरोसेमंदी है (जो
Keycloak भेजा जाता है उस पर SSO सत्यापित हो, upstream मेल-सर्वर की मौजूदा लाइन, और एक वास्तविक
domain पर मापी गई deliverability)। उससे आगे हम चाहते हैं कि यह स्टैक वही बने जिसे सॉफ़्टवेयर
एजेंट सुरक्षित रूप से इस्तेमाल कर सकें: JMAP पर एक MCP सर्वर, और किसी bot को अपना पासवर्ड देने के
बजाय प्रति-एजेंट scoped, निरस्त करने योग्य credentials। इसमें से कुछ भी अभी बना नहीं है, और
प्रोजेक्ट का नाम जानबूझकर उस पर नहीं रखा गया है। **एजेंट से जुड़े काम पर योगदान चाहिए —
रोडमैप में "Help wanted" देखें।**

## ⚖️ लाइसेंस

- **यह repo** (orchestration, config, installer, docs): **MIT** — देखें [`LICENSE`](../../../LICENSE)।
- **जिन प्रोग्रामों को यह डिप्लॉय करता है, वे अपनी-अपनी licence बनाए रखते हैं** और प्रकाशित
  images के रूप में खींचे जाते हैं; इस repo में उनका कोई source नहीं है:
  - Stalwart Mail Server — **AGPL-3.0**
  - Bulwark Webmail — **AGPL-3.0**
  - Keycloak — **Apache-2.0**

यदि आप Stalwart या Bulwark को **संशोधित** करके दूसरों को परोसते हैं, तो AGPL आपसे *उस component
का* संशोधित source प्रकाशित करने की माँग करता है। अपरिवर्तित images चलाने से यह माँग नहीं बनती।
विवरण: [`THIRD_PARTY_LICENSES.md`](../../../THIRD_PARTY_LICENSES.md) और [`NOTICE`](../../../NOTICE)।

## सुरक्षा

Open relay अस्वीकृत है, submission के लिए authentication अनिवार्य है, और password mechanisms
(`PLAIN`/`LOGIN`) केवल STARTTLS के बाद ही पेश किए जाते हैं — यह सब मापा गया है, मान कर नहीं चला
गया। साथ ही कुछ वास्तविक कमज़ोरियाँ भी हैं जिनके लिए आपको योजना बनानी होगी, जिनमें एक upstream
admin API शामिल है जो अकाउंट के पासवर्ड cleartext में लौटाता है। **इसे इंटरनेट पर उजागर करने से
पहले [`SECURITY.md`](../../../SECURITY.md) पढ़ें।**

## टेस्ट और संचालन

दोनों repo में मौजूद हैं — ऊपर किया गया हर दावा आप स्वयं दोहरा सकते हैं:

```bash
tests/test_config.sh      # static: both editions validate, no secrets, digests pinned … (~seconds)
tests/test_e2e.sh         # real: stack up → send a message → read it back over IMAP (~2 min)
tests/test_e2e.sh --sso   # same, plus Keycloak + PostgreSQL
```

`test_e2e.sh` केवल loopback पोर्ट पर, अपने अलग volumes और container नामों के साथ एक अस्थायी स्टैक
बनाता है और बाहर निकलते समय उसे हटा देता है — यह किसी चालू deployment में खलल नहीं डालेगा।
देखें [`tests/README.md`](../../../tests/README.md), जिसमें यह भी है कि ये टेस्ट जानबूझकर क्या
**नहीं** देखते।

Day-2 संचालन — बैकअप, प्रमाणपत्र नवीनीकरण, mailbox प्रबंधन, अपग्रेड, incident playbook —
[`docs/RUNBOOK.md`](../../../docs/RUNBOOK.md) में हैं। पूर्व-आवश्यकताएँ
[`docs/REQUIREMENTS.md`](../../../docs/REQUIREMENTS.md) में हैं।

## योगदान

देखें [`CONTRIBUTING.md`](../../../CONTRIBUTING.md)। एक घर का नियम: runtime व्यवहार के बारे में
दावों के लिए माप चाहिए, "मेरी मशीन पर तो चलता है" नहीं।

कौन क्या तय करता है, maintainer कैसे बनें, और अगर यह प्रोजेक्ट कभी छोड़ दिया गया तो आपका क्या
होगा: [`GOVERNANCE.md`](../../../GOVERNANCE.md)। जवाब किससे मिलने की उम्मीद रखें, और bus factor
का ईमानदार बयान: [`MAINTAINERS.md`](../../../MAINTAINERS.md)।

## इसे कौन बनाता है

नेतृत्व **Daika Ginza** का — [GitHub](https://github.com/daikaginza) ·
[Substack](https://substack.com/@daikaginza) ·
[LinkedIn](https://www.linkedin.com/in/daikaginza/) — साथ में
[@anhkk1245](https://github.com/anhkk1245), संस्था
**[Novaza Solution JSC](https://novaza.ai)**।

हम इस स्टैक के components (Stalwart और Bulwark) को अपनी ही मेल के लिए production में चलाते हैं,
और Freehold Mail हमने इसलिए बनाया ताकि वह आर्किटेक्चर हर उस व्यक्ति के लिए पैक किया जा सके जो
इसे self-host करना चाहता है। MIT-licensed; देखें [`LICENSE`](../../../LICENSE) और
[`NOTICE`](../../../NOTICE)।

पूरी टीम, निर्णय कैसे लिए जाते हैं, और कैसे जुड़ें:
[`MAINTAINERS.md`](../../../MAINTAINERS.md) · [`GOVERNANCE.md`](../../../GOVERNANCE.md)।

> GitHub का contributor ग्राफ़ फ़िलहाल केवल `dependabot` को श्रेय देता है, क्योंकि हमारे commits
> एक कंपनी पहचान के तहत लिखे जाते हैं जो किसी GitHub अकाउंट से जुड़ी नहीं है। यदि आप योगदान करते
> हैं, तो अपने ही नाम और ईमेल से commit कीजिए — वहाँ आपको ठीक से श्रेय मिलेगा।
> `MAINTAINERS.md` बताता है कि हम टीम के लिए इसे कैसे ठीक कर रहे हैं।

---

Stalwart Labs, Bulwark प्रोजेक्ट, या Keycloak से कोई संबद्धता नहीं है।
