# NeztMate Web — Landing + Admin

## Public site
- `index.html` — App landing (tenants, landowners, managers, artisans) + download CTAs
- `partners.html` — Become a partner explainer + request form
- **No admin link** in the public nav (open `/admin/` directly)

## Partner slug landing
```
index.html?partner=demo
index.html?slug=acme
```
Loads `GET /partners/config?slug=…`. On failure, uses sample branding from `js/config.js`.

## Admin (`/admin/`)
- Login → NeztMate API (`partnerId` required on token)
- Dashboard, properties, payments, notifications
- **Partner requests** inbox (API or localStorage fallback)

## Backend endpoints to add (if missing)
```
POST /partners/requests   (public) — body from partners form
GET  /partners/requests   (admin)  — list for follow-up
GET  /partners/config?slug=
```

## Configure
Edit `js/config.js`:
- `apiBase`
- `playStoreUrl` / `appStoreUrl`
- `samplePartners` for offline slug demos

## Run
```bash
npx serve .
```
