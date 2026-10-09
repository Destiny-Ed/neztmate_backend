# Resend email service

## Env

```bash
RESEND_API_KEY=re_xxxxxxxx          # required
RESEND_FROM_EMAIL=NeztMate <onboarding@neztmate.com>
RESEND_REPLY_TO=support@neztmate.com   # optional
```

Verify the domain at https://resend.com/domains and use a matching `from` address.

## APIs (auth required)

| Method | Path | Who | Body |
|--------|------|-----|------|
| POST | `/emails/send` | any authed | `{ to, subject, html, text?, tags? }` |
| POST | `/emails/campaign` | admin / landowner / manager | `{ subject, html, text?, role?, partnerId?, limit? }` |
| POST | `/emails/welcome` | elevated | `{ userId }` |

New email/password sign-ups automatically receive a welcome email (non-blocking).
