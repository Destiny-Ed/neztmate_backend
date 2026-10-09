# Resend email service

## Env

```bash
RESEND_API_KEY=re_xxxxxxxx          # required
RESEND_FROM_EMAIL=NeztMate <onboarding@neztmate.com>
RESEND_REPLY_TO=support@neztmate.com   # optional
RESEND_LOGO_URL=https://neztmate.com/assets/logo_bg.png  # optional override
```

Verify the domain at https://resend.com/domains and use a matching `from` address.

## APIs (auth required)

| Method | Path | Who | Body |
|--------|------|-----|------|
| POST | `/emails/send` | any authed | `{ to, subject, html, text?, tags? }` |
| POST | `/emails/campaign` | admin / landowner / manager | `{ subject, html, text?, role?, partnerId?, limit? }` |
| POST | `/emails/welcome` | elevated | `{ userId }` |

New email/password sign-ups automatically receive a welcome email (non-blocking).

## Logo in email body

Emails embed the NeztMate logo from:

```
https://neztmate.com/assets/logo_bg.png
```

Override with:

```bash
RESEND_LOGO_URL=https://neztmate.com/assets/your-logo.png
```

Use a publicly reachable **HTTPS** PNG/JPG (not SVG for widest client support). Prefer a ~160–320px wide asset under ~100KB.

## Sender avatar (inbox icon)

The circle icon next to the sender name is **not** controlled by HTML. To show the NeztMate brand instead of a generic person:

1. **Gravatar** (quick): create a Gravatar for the exact `from` address (e.g. `onboarding@neztmate.com`) with the NeztMate logo.
2. **Google Workspace**: set the profile photo for that mailbox if you use Google mail for the domain.
3. **BIMI** (best, Gmail/Apple): publish a BIMI DNS record + verified SVG logo + DMARC `p=quarantine` or `reject`. See https://resend.com/docs/dashboard/domains/bimi

Until BIMI/Gravatar is set, clients will keep showing a default avatar even when the body logo displays correctly.
