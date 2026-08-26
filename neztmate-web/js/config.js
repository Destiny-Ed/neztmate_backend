window.NeztMateConfig = {
  apiBase:
    window.NEZTMATE_API_BASE ||
    localStorage.getItem('neztmate_api_base') ||
    'https://neztmate-backend.onrender.com',

  defaultPartnerSlug: 'neztmate',

  // Google OAuth Web Client ID (Google Cloud Console → APIs & Services → Credentials)
  // Authorized JS origins: http://127.0.0.1:5500, https://your-domain.com
  // Firebase web config (same project as Flutter — required for platform Google login)
  firebase: {
    apiKey: window.NEZTMATE_FIREBASE_API_KEY || localStorage.getItem('neztmate_firebase_api_key') || 'YOUR_FIREBASE_WEB_API_KEY',
    authDomain: window.NEZTMATE_FIREBASE_AUTH_DOMAIN || 'next-mate.firebaseapp.com',
    projectId: window.NEZTMATE_FIREBASE_PROJECT_ID || 'next-mate',
    appId: window.NEZTMATE_FIREBASE_APP_ID || localStorage.getItem('neztmate_firebase_app_id') || 'YOUR_FIREBASE_APP_ID',
    messagingSenderId: window.NEZTMATE_FIREBASE_MESSAGING_SENDER_ID || '',
  },

  // Optional: GIS client id (not used for platform admin Firebase login)
  googleClientId:
    window.NEZTMATE_GOOGLE_CLIENT_ID ||
    localStorage.getItem('neztmate_google_client_id') ||
    'YOUR_GOOGLE_WEB_CLIENT_ID.apps.googleusercontent.com',


  platformHomeUrl: 'https://neztmate.com',
  defaultPrivacyUrl: 'privacy.html',
  defaultTermsUrl: 'terms.html',
  defaultSupportEmail: 'support@neztmate.com',

  playStoreUrl: 'https://play.google.com/store/apps/details?id=com.neztmate.app',
  appStoreUrl: 'https://apps.apple.com/app/neztmate/id0000000000',

  samplePartners: {
    neztmate: {
      id: 'neztmate',
      name: 'NeztMate',
      slug: 'neztmate',
      tagline: 'Find, rent & manage homes with less stress',
      primaryColor: '#0d9488',
      secondaryColor: '#0f766e',
      logoUrl: null,
      supportEmail: 'hello@neztmate.com',
    },
    demo: {
      id: 'demo',
      name: 'Demo Homes',
      slug: 'demo',
      tagline: 'Sample partner experience powered by NeztMate',
      primaryColor: '#7c3aed',
      secondaryColor: '#5b21b6',
      logoUrl: null,
      supportEmail: 'demo@neztmate.com',
    },
    acme: {
      id: 'acme',
      name: 'Acme Property',
      slug: 'acme',
      tagline: 'Homes managed with clarity',
      primaryColor: '#0369a1',
      secondaryColor: '#0c4a6e',
      logoUrl: null,
      supportEmail: 'hello@acme.example',
    },
  },
};
