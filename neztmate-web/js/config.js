window.NeztMateConfig = {
  apiBase:
    window.NEZTMATE_API_BASE ||
    localStorage.getItem('neztmate_api_base') ||
    'https://neztmate-backend.onrender.com',

  defaultPartnerSlug: 'neztmate',

  playStoreUrl: 'https://play.google.com/store/apps/details?id=com.neztmate.app',
  appStoreUrl: 'https://apps.apple.com/app/neztmate/id0000000000',

  googleClientId: '803085696518-ua8hbea5hhu80r67b28e4ae66mhvs64e.apps.googleusercontent.com',

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
