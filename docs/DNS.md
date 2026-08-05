<!-- Last-touched: 2026-08-04 — new repo scaffold: DNS setup guide -->
# DNS records for your mail domain

Replace `example.com` / `mail.example.com` with your values. Deliverability depends
almost entirely on getting these right.

| Type | Host | Value | Purpose |
|------|------|-------|---------|
| A / AAAA | `mail.example.com` | your server IP | reach the server |
| MX | `example.com` | `10 mail.example.com.` | where mail is delivered |
| TXT (SPF) | `example.com` | `v=spf1 mx -all` | authorize your server to send |
| TXT (DKIM) | `<selector>._domainkey.example.com` | public key from Stalwart | sign outgoing mail |
| TXT (DMARC) | `_dmarc.example.com` | `v=DMARC1; p=quarantine; rua=mailto:postmaster@example.com` | policy + reports |
| PTR (reverse DNS) | (set at your host/ISP) | `mail.example.com` | many providers reject mail without it |

## Notes

- **DKIM key**: generate/read it from Stalwart after first start, then publish the TXT record.
- **PTR/rDNS**: set on the hosting provider side (not in your zone) — critical for delivery.
- **Ports**: 25 outbound is blocked by many clouds; request an unblock or use a smart host.
- Verify with: `dig MX example.com`, `dig TXT example.com`, and a tool like mail-tester.com.
