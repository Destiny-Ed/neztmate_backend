(function () {
  const CFG = window.NeztMateConfig || {};
  const API = CFG.apiBase || 'https://neztmate-backend.onrender.com';
  const playDefault = CFG.playStoreUrl || 'https://play.google.com/store/apps/details?id=com.neztmate.app';
  const appStoreDefault = CFG.appStoreUrl || 'https://apps.apple.com/app/neztmate';

  const grid = document.getElementById('listings-grid');
  const empty = document.getElementById('listings-empty');
  const statusEl = document.getElementById('listings-status');
  const modal = document.getElementById('app-download-modal');
  const searchInput = document.getElementById('listings-search');
  const cityInput = document.getElementById('listings-city');
  const stateInput = document.getElementById('listings-state');
  const minBedInput = document.getElementById('listings-beds');
  const maxRentInput = document.getElementById('listings-max-rent');

  /** Same partner resolution as landing branding: ?partner= / ?slug= → localStorage → default */
  const urlParams = new URLSearchParams(window.location.search);
  const partnerParam = (urlParams.get('partner') || urlParams.get('slug') || '').toLowerCase().trim();
  const slug = (
    partnerParam ||
    localStorage.getItem('neztmate_partner_slug') ||
    CFG.defaultPartnerSlug ||
    'neztmate'
  )
    .toLowerCase()
    .trim();

  /** @type {{ id: string, name?: string, slug?: string, playStoreUrl?: string, appStoreUrl?: string } | null} */
  let partnerConfig = null;

  function money(n) {
    if (typeof n !== 'number' || Number.isNaN(n)) return '—';
    return '₦' + n.toLocaleString('en-NG', { maximumFractionDigits: 0 });
  }

  function esc(s) {
    return String(s ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function photo(unit, property) {
    const u = unit || {};
    const p = property || {};
    const urls = u.photoUrls || u.images || p.photoUrls || p.images || [];
    if (Array.isArray(urls) && urls.length && typeof urls[0] === 'string') return urls[0];
    return 'assets/logo_bg.png';
  }

  function normalizePartner(raw) {
    const p = (raw && (raw.partner || raw)) || {};
    const samples = CFG.samplePartners || {};
    const fallback = samples[slug] || samples.neztmate || {};
    return {
      id: String(p.id || p.partnerId || fallback.id || '').trim(),
      name: p.name || p.displayName || fallback.name || 'NeztMate',
      slug: String(p.slug || slug).toLowerCase(),
      primaryColor: p.primaryColor || p.primary_color || fallback.primaryColor,
      secondaryColor: p.secondaryColor || p.secondary_color || fallback.secondaryColor,
      logoUrl: p.logoUrl || p.logo_url || fallback.logoUrl || null,
      playStoreUrl: p.playStoreUrl || p.play_store_url || CFG.playStoreUrl || playDefault,
      appStoreUrl: p.appStoreUrl || p.app_store_url || CFG.appStoreUrl || appStoreDefault,
      tagline: p.tagline || p.description || fallback.tagline || '',
    };
  }

  function applyBranding(partner) {
    if (window.NeztMateTheme && typeof window.NeztMateTheme.apply === 'function') {
      try {
        window.NeztMateTheme.apply(partner, {
          isPartnerHosted: Boolean(partnerParam) || slug !== 'neztmate',
        });
      } catch (_) {}
    }
    document.querySelectorAll('[data-brand-name]').forEach(function (el) {
      el.textContent = partner.name || 'NeztMate';
    });
    var playA = document.getElementById('modal-play-link');
    var iosA = document.getElementById('modal-ios-link');
    if (playA) playA.href = partner.playStoreUrl || playDefault;
    if (iosA) iosA.href = partner.appStoreUrl || appStoreDefault;
  }

  /** Load partner config used for site branding; partnerId is required for listings. */
  async function resolvePartner() {
    // Prefer cached config from landing (same branding session)
    try {
      const cached = JSON.parse(localStorage.getItem('neztmate_partner_cache') || 'null');
      if (cached && cached.id && (!cached.slug || cached.slug === slug)) {
        partnerConfig = normalizePartner(cached);
        if (partnerConfig.id) {
          applyBranding(partnerConfig);
          return partnerConfig;
        }
      }
    } catch (_) {}

    try {
      let data;
      if (window.NeztMateApi && typeof window.NeztMateApi.getPartnerConfig === 'function') {
        data = await window.NeztMateApi.getPartnerConfig(slug);
      } else {
        const res = await fetch(API + '/partners/config?slug=' + encodeURIComponent(slug), {
          headers: { Accept: 'application/json' },
        });
        data = await res.json().catch(function () {
          return {};
        });
        if (!res.ok) throw new Error((data && data.message) || 'Partner config failed');
      }
      partnerConfig = normalizePartner(data);
      if (!partnerConfig.id) {
        throw new Error('Partner id missing from config');
      }
      localStorage.setItem('neztmate_partner_slug', slug);
      localStorage.setItem('neztmate_partner_cache', JSON.stringify(partnerConfig));
      applyBranding(partnerConfig);
      return partnerConfig;
    } catch (e) {
      // Sample fallback only if it has a real id (dev samples)
      const samples = CFG.samplePartners || {};
      const fb = normalizePartner(samples[slug] || samples.neztmate || {});
      if (fb.id && fb.id !== slug) {
        partnerConfig = fb;
        applyBranding(partnerConfig);
        return partnerConfig;
      }
      // Last resort: some deployments use slug as partnerId
      partnerConfig = normalizePartner({ id: slug, slug: slug, name: (samples[slug] || {}).name });
      if (!partnerConfig.id) {
        throw e;
      }
      applyBranding(partnerConfig);
      return partnerConfig;
    }
  }

  function openModal(unit, property) {
    const title = document.getElementById('modal-unit-title');
    const sub = document.getElementById('modal-unit-sub');
    const brand = (partnerConfig && partnerConfig.name) || 'NeztMate';
    if (title) {
      title.textContent =
        (unit && (unit.title || unit.unitNumber || unit.name)) ||
        (property && property.name) ||
        'This home';
    }
    if (sub) {
      const loc = [property && property.city, property && property.state].filter(Boolean).join(', ');
      sub.textContent = loc
        ? 'Available on ' + brand + ' in ' + loc + '. Download the app to view full details and apply.'
        : 'Download the ' + brand + ' app to view full details, chat, and apply for this home.';
    }
    if (modal) modal.classList.remove('hidden');
    document.body.style.overflow = 'hidden';
  }

  function closeModal() {
    if (modal) modal.classList.add('hidden');
    document.body.style.overflow = '';
  }

  function card(item) {
    const unit = item.unit || item;
    const property = item.property || {};
    const title = esc(unit.title || unit.unitNumber || property.name || 'Unit');
    const loc = esc(
      [property.city, property.state, property.address].filter(Boolean).slice(0, 2).join(', ') || 'Nigeria'
    );
    const beds = unit.bedrooms != null ? unit.bedrooms + ' bed' : '';
    const baths = unit.bathrooms != null ? unit.bathrooms + ' bath' : '';
    const meta = [beds, baths].filter(Boolean).join(' · ');
    const rent = money(typeof unit.monthlyRent === 'number' ? unit.monthlyRent : Number(unit.monthlyRent));
    const img = esc(photo(unit, property));

    return (
      '<article class="listing-card" data-unit-id="' +
      esc(unit.id || '') +
      '">' +
      '<div class="listing-card-img" style="background-image:url(\'' +
      img +
      '\')"></div>' +
      '<div class="listing-card-body">' +
      '<div class="listing-card-top"><strong>' +
      title +
      '</strong><span class="listing-rent">' +
      rent +
      '<small>/mo</small></span></div>' +
      '<p class="listing-loc muted">' +
      loc +
      '</p>' +
      (meta ? '<p class="listing-meta muted">' + esc(meta) + '</p>' : '') +
      '<button type="button" class="btn btn-primary btn-sm listing-cta">View & apply</button>' +
      '</div></article>'
    );
  }

  async function load() {
    if (!grid) return;
    statusEl && (statusEl.textContent = 'Loading homes…');
    grid.innerHTML = '';
    empty && (empty.style.display = 'none');

    try {
      if (!partnerConfig || !partnerConfig.id) {
        await resolvePartner();
      }
      const partnerId = partnerConfig && partnerConfig.id;
      if (!partnerId) {
        throw new Error('Partner configuration required. Open this site with ?partner=your-slug');
      }

      const params = new URLSearchParams();
      params.set('partnerId', partnerId);
      const city = (cityInput && cityInput.value.trim()) || '';
      const state = (stateInput && stateInput.value.trim()) || '';
      const beds = (minBedInput && minBedInput.value) || '';
      const maxRent = (maxRentInput && maxRentInput.value) || '';
      if (city) params.set('city', city);
      if (state) params.set('state', state);
      if (beds) params.set('minBedrooms', beds);
      if (maxRent) params.set('maxRent', maxRent);

      const res = await fetch(API + '/units/available?' + params.toString(), {
        headers: {
          Accept: 'application/json',
          'x-partner-slug': slug,
        },
      });
      const data = await res.json().catch(function () {
        return {};
      });
      if (!res.ok) throw new Error(data.message || 'Could not load listings');

      let list = data.units || data || [];
      if (!Array.isArray(list)) list = [];

      const q = ((searchInput && searchInput.value) || '').trim().toLowerCase();
      if (q) {
        list = list.filter(function (item) {
          const u = item.unit || item;
          const p = item.property || {};
          const blob = [u.title, u.unitNumber, u.name, p.name, p.city, p.state, p.address]
            .join(' ')
            .toLowerCase();
          return blob.indexOf(q) >= 0;
        });
      }

      statusEl &&
        (statusEl.textContent = list.length
          ? list.length + ' home' + (list.length === 1 ? '' : 's') + ' available'
          : '');

      if (!list.length) {
        empty && (empty.style.display = 'block');
        if (empty) {
          empty.textContent =
            'No listed homes for this partner yet. Check back soon or download the app for more options.';
        }
        return;
      }

      grid.innerHTML = list.map(card).join('');
      grid.querySelectorAll('.listing-card').forEach(function (el, i) {
        el.addEventListener('click', function () {
          const item = list[i];
          openModal(item.unit || item, item.property || {});
        });
      });
    } catch (e) {
      statusEl && (statusEl.textContent = e.message || 'Failed to load');
      empty && (empty.style.display = 'block');
      if (empty) {
        empty.textContent =
          e.message || 'Unable to load listings right now. Please try again later.';
      }
    }
  }

  document.querySelectorAll('[data-close-modal]').forEach(function (btn) {
    btn.addEventListener('click', closeModal);
  });
  if (modal) {
    modal.addEventListener('click', function (e) {
      if (e.target === modal) closeModal();
    });
  }
  document.getElementById('listings-refresh') &&
    document.getElementById('listings-refresh').addEventListener('click', load);
  document.getElementById('listings-filter-btn') &&
    document.getElementById('listings-filter-btn').addEventListener('click', load);

  // Preserve partner query on internal links
  if (partnerParam) {
    document.querySelectorAll('a[href]').forEach(function (a) {
      try {
        const href = a.getAttribute('href');
        if (!href || href.startsWith('http') || href.startsWith('#') || href.startsWith('mailto:')) return;
        if (href.indexOf('partner=') >= 0 || href.indexOf('slug=') >= 0) return;
        const u = new URL(href, window.location.origin);
        if (!u.searchParams.get('partner') && !u.searchParams.get('slug')) {
          u.searchParams.set('partner', partnerParam);
          a.setAttribute('href', u.pathname + u.search + u.hash);
        }
      } catch (_) {}
    });
  }

  resolvePartner()
    .then(function () {
      return load();
    })
    .catch(function (e) {
      statusEl && (statusEl.textContent = e.message || 'Partner config required');
      empty && (empty.style.display = 'block');
      if (empty) {
        empty.textContent =
          'Could not load partner branding/config. Use ?partner=your-slug on this page.';
      }
    });
})();
