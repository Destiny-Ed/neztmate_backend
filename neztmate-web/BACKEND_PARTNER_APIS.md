# Partner APIs to add (backend)

## Routes

```dart
// features/partners/routes/partner_routes.dart
import 'package:neztmate_backend/features/partners/handler/partner_handler.dart';
import 'package:shelf_router/shelf_router.dart';

/// Mount public: router.mount('/partners/', partnerPublicRoutes(...).call);
Router partnerPublicRoutes(PartnerHandler handler) {
  final router = Router();
  router.get('/config', handler.getPublicConfig); // ?slug=
  router.post('/requests', handler.submitPartnerRequest);
  router.get('/<id>', handler.getPartnerById);
  return router;
}

/// Mount with auth middleware
Router partnerProtectedRoutes(PartnerHandler handler) {
  final router = Router();

  // Partner admin (scoped to JWT partnerId)
  router.get('/me', handler.getMyPartner);
  router.patch('/me', handler.updateMyPartner);
  router.patch('/me/branding', handler.updateMyBranding);

  // Platform admin
  router.get('/', handler.listPartners);
  router.post('/', handler.createPartner);
  router.patch('/<id>', handler.updatePartner);
  router.patch('/<id>/status', handler.setPartnerStatus);

  router.get('/requests', handler.listPartnerRequests);
  router.patch('/requests/<id>', handler.updatePartnerRequest);

  return router;
}
```

## Public config response (required for full web branding)

```json
{
  "partner": {
    "id": "neztmate",
    "name": "NeztMate",
    "slug": "neztmate",
    "tagline": "Find, rent & manage homes with less stress",
    "primaryColor": "#0d9488",
    "secondaryColor": "#0f766e",
    "logoUrl": null,
    "supportEmail": "hello@neztmate.com",
    "status": "active"
  }
}
```

## Auth login changes

1. **Always require** `fcmToken` (and optionally `platform`: `ios|android|web`).
2. **Partner admin / normal users**: require `partnerId`.
3. **Platform admin**: allow login **without** `partnerId` when:
   - user role is `platform_admin` / `super_admin`, or
   - body contains `"loginAs": "platform_admin"` and credentials match a platform admin user.
4. JWT for platform admin: `{ "sub", "role": "platform_admin" }` — no partnerId required.
5. JWT for everyone else: must include `partnerId`.
6. Auth middleware: if role is `platform_admin`, skip empty-partnerId rejection; else require partnerId.

### Example login body

Partner:
```json
{
  "email": "ops@acme.com",
  "password": "...",
  "partnerId": "acme",
  "fcmToken": "web-admin-...",
  "platform": "web"
}
```

Platform:
```json
{
  "email": "admin@neztmate.com",
  "password": "...",
  "fcmToken": "web-admin-...",
  "platform": "web",
  "loginAs": "platform_admin"
}
```

## Partner model fields (Firestore `partners`)

- id, name, slug, tagline
- primaryColor, secondaryColor, logoUrl
- supportEmail, supportPhone, website
- status: active | suspended | pending
- createdAt, updatedAt

## Partner request model (`partner_requests`)

- companyName, contactName, email, phone
- proposedSlug, website, cities, portfolioSize, message
- status: pending | contacted | approved | rejected
- createdAt
