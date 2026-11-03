(function () {
  const CFG = window.NeztMateConfig || {};
  const API = CFG.apiBase || 'https://neztmate-backend.onrender.com';
  const playDefault = CFG.playStoreUrl || 'https://play.google.com/store/apps/details?id=com.neztmate.app';
  const appStoreDefault = CFG.appStoreUrl || 'https://apps.apple.com/app/neztmate';

  const grid = document.getElementById('listings-grid');
  const empty = document.getElementById('listings-empty');
  const statusEl = document.getElementById('listings-status');
  const downloadModal = document.getElementById('app-download-modal');
  const detailsModal = document.getElementById('unit-details-modal');
  const searchInput = document.getElementById('listings-search');
  const cityInput = document.getElementById('listings-city');
  const stateInput = document.getElementById('listings-state');
  const minBedInput = document.getElementById('listings-beds');
  const maxRentInput = document.getElementById('listings-max-rent');

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

  /** @type {{ unit: any, property: any } | null} */
  let currentListing = null;
  /** @type {{ type: string, url: string }[]} */
  let mediaItems = [];
  let mediaIndex = 0;

  function money(n) {
    if (typeof n !== 'number' || Number.isNaN(n)) return '—';
    return '₦' + n.toLocaleString('en-NG', { maximumFractionDigits: 0 });
  }

  function esc(s) {
    return String(s ?? '')
      .replace(/&/g, '&')
      .replace(/</g, '<')
      .replace(/>/g, '>')
      .replace(/"/g, '"');
  }

  function photo(unit, property) {
    const u = unit || {};
    const p = property || {};
    const urls = u.photoUrls || u.images || p.photoUrls || p.images || [];
    if (Array.isArray(urls) && urls.length && typeof urls[0] === 'string') return urls[0];
    return 'assets/logo_bg.png';
  }

  function buildMedia(unit, property) {
    const items = [];
    const u = unit || {};
    const p = property || {};
    const video = u.videoUrl || u.video_url || '';
    if (video) items.push({ type: 'video', url: video });
    const photos = [].concat(u.photoUrls || u.images || [], p.photoUrls || p.images || []);
    photos.forEach(function (url) {
      if (typeof url === 'string' && url) items.push({ type: 'image', url: url });
    });
    if (!items.length) items.push({ type: 'image', url: 'assets/logo_bg.png' });
    return items;
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

  async function resolvePartner() {
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
      const samples = CFG.samplePartners || {};
      const fb = normalizePartner(samples[slug] || samples.neztmate || {});
      if (fb.id && fb.id !== slug) {
        partnerConfig = fb;
        applyBranding(partnerConfig);
        return partnerConfig;
      }
      partnerConfig = normalizePartner({ id: slug, slug: slug, name: (samples[slug] || {}).name });
      if (!partnerConfig.id) {
        throw e;
      }
      applyBranding(partnerConfig);
      return partnerConfig;
    }
  }

  function renderMediaStage() {
    const stage = document.getElementById('unit-details-media-stage');
    const dots = document.getElementById('unit-media-dots');
    if (!stage) return;

    // Pause any playing video
    stage.querySelectorAll('video').forEach(function (v) {
      try {
        v.pause();
      } catch (_) {}
    });

    const item = mediaItems[mediaIndex] || mediaItems[0];
    if (!item) {
      stage.innerHTML = '';
      return;
    }

    if (item.type === 'video') {
      stage.innerHTML =
        '<video src="' +
        esc(item.url) +
        '" controls playsinline preload="metadata" poster="' +
        esc((mediaItems.find(function (m) {
          return m.type === 'image';
        }) || {}).url || '') +
        '"></video>';
    } else {
      stage.innerHTML = '<img src="' + esc(item.url) + '" alt="Unit photo" />';
    }

    if (dots) {
      dots.innerHTML = mediaItems
        .map(function (_, i) {
          return '<span class="media-dot' + (i === mediaIndex ? ' active' : '') + '"></span>';
        })
        .join('');
    }
  }

  function openDetails(unit, property) {
    currentListing = { unit: unit || {}, property: property || {} };
    mediaItems = buildMedia(unit, property);
    mediaIndex = 0;

    const titleEl = document.getElementById('unit-details-title');
    const rentEl = document.getElementById('unit-details-rent');
    const locEl = document.getElementById('unit-details-loc');
    const chipsEl = document.getElementById('unit-details-chips');
    const aboutEl = document.getElementById('unit-details-about');
    const amenitiesEl = document.getElementById('unit-details-amenities');
    const amenitiesWrap = document.getElementById('unit-details-amenities-wrap');
    const feesEl = document.getElementById('unit-details-fees');
    const feesWrap = document.getElementById('unit-details-fees-wrap');

    const title =
      (unit && (unit.title || unit.unitNumber || unit.name)) ||
      (property && property.name) ||
      'Unit';
    if (titleEl) titleEl.textContent = title;

    const rent = typeof unit.monthlyRent === 'number' ? unit.monthlyRent : Number(unit.monthlyRent);
    if (rentEl) {
      rentEl.innerHTML = money(rent) + '<small>/mo</small>';
    }

    const loc = [property.address, property.city, property.state].filter(Boolean).join(', ');
    if (locEl) locEl.textContent = loc || 'Nigeria';

    const chips = [];
    if (unit.bedrooms != null) chips.push(unit.bedrooms + ' bed');
    if (unit.bathrooms != null) chips.push(unit.bathrooms + ' bath');
    if (unit.squareFeet != null) chips.push(unit.squareFeet + ' sqft');
    if (unit.status) chips.push(String(unit.status));
    if (chipsEl) {
      chipsEl.innerHTML = chips.map(function (c) {
        return '<span class="unit-chip">' + esc(c) + '</span>';
      }).join('');
    }

    const about =
      unit.description ||
      property.description ||
      (property.name
        ? 'Unit at ' + property.name + (loc ? ' · ' + loc : '') + '.'
        : 'Browse this home’s photos and video, then apply in the app.');
    if (aboutEl) aboutEl.textContent = about;

    // Amenities from unit features / amenities arrays or map
    let amenities = [];
    if (Array.isArray(unit.amenities)) amenities = unit.amenities;
    else if (Array.isArray(unit.features)) amenities = unit.features;
    else if (unit.customFeatures && typeof unit.customFeatures === 'object') {
      amenities = Object.keys(unit.customFeatures).filter(function (k) {
        return unit.customFeatures[k];
      });
    }
    if (unit.balcony) amenities.push('Balcony');
    if (unit.furnished) amenities.push('Furnished');
    if (unit.petFriendly) amenities.push('Pet friendly');
    if (unit.airConditioning) amenities.push('Air conditioning');
    amenities = amenities.filter(Boolean);
    if (amenitiesEl && amenitiesWrap) {
      if (amenities.length) {
        amenitiesWrap.style.display = '';
        amenitiesEl.innerHTML = amenities
          .map(function (a) {
            return '<span class="unit-chip">' + esc(a) + '</span>';
          })
          .join('');
      } else {
        amenitiesWrap.style.display = 'none';
        amenitiesEl.innerHTML = '';
      }
    }

    // Fees if present
    const fees = unit.fees || unit.unitFees || [];
    if (feesEl && feesWrap) {
      if (Array.isArray(fees) && fees.length) {
        feesWrap.style.display = '';
        feesEl.innerHTML = fees
          .map(function (f) {
            const name = f.name || f.label || 'Fee';
            const amt = typeof f.amount === 'number' ? money(f.amount) : f.amount || '';
            const tag = f.isOneTime ? 'one-time' : 'recurring';
            return esc(name) + ': ' + esc(String(amt)) + ' (' + tag + ')';
          })
          .join('<br/>');
      } else {
        feesWrap.style.display = 'none';
        feesEl.innerHTML = '';
      }
    }

    renderMediaStage();

    if (detailsModal) detailsModal.classList.remove('hidden');
    document.body.style.overflow = 'hidden';
  }

  function closeDetails() {
    const stage = document.getElementById('unit-details-media-stage');
    if (stage) {
      stage.querySelectorAll('video').forEach(function (v) {
        try {
          v.pause();
        } catch (_) {}
      });
    }
    if (detailsModal) detailsModal.classList.add('hidden');
    if (!downloadModal || downloadModal.classList.contains('hidden')) {
      document.body.style.overflow = '';
    }
  }

  function openDownloadModal(unit, property) {
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
        ? 'Finish applying for this home on ' + brand + ' in ' + loc + '. Download the app to submit your application.'
        : 'Download the ' + brand + ' app to complete your application, chat with the landlord, and manage your lease.';
    }
    if (downloadModal) downloadModal.classList.remove('hidden');
    document.body.style.overflow = 'hidden';
  }

  function closeDownloadModal() {
    if (downloadModal) downloadModal.classList.add('hidden');
    if (!detailsModal || detailsModal.classList.contains('hidden')) {
      document.body.style.overflow = '';
    }
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
    const hasVideo = !!(unit.videoUrl || unit.video_url);

    return (
      '<article class="listing-card" data-unit-id="' +
      esc(unit.id || '') +
      '">' +
      '<div class="listing-card-img" style="background-image:url(\'' +
      img +
      '\')">' +
      (hasVideo
        ? '<span style="position:absolute;right:10px;bottom:10px;background:rgba(0,0,0,.55);color:#fff;font-size:11px;font-weight:700;padding:4px 8px;border-radius:999px">▶ Video</span>'
        : '') +
      '</div>' +
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
      '<button type="button" class="btn btn-primary btn-sm listing-cta">View details</button>' +
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
      // Position relative for video badge
      grid.querySelectorAll('.listing-card-img').forEach(function (el) {
        el.style.position = 'relative';
      });
      grid.querySelectorAll('.listing-card').forEach(function (el, i) {
        el.addEventListener('click', function () {
          const item = list[i];
          openDetails(item.unit || item, item.property || {});
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

  // Details modal controls
  document.querySelectorAll('[data-close-details]').forEach(function (btn) {
    btn.addEventListener('click', closeDetails);
  });
  if (detailsModal) {
    detailsModal.addEventListener('click', function (e) {
      if (e.target === detailsModal) closeDetails();
    });
  }
  document.getElementById('unit-media-prev') &&
    document.getElementById('unit-media-prev').addEventListener('click', function (e) {
      e.stopPropagation();
      if (!mediaItems.length) return;
      mediaIndex = (mediaIndex - 1 + mediaItems.length) % mediaItems.length;
      renderMediaStage();
    });
  document.getElementById('unit-media-next') &&
    document.getElementById('unit-media-next').addEventListener('click', function (e) {
      e.stopPropagation();
      if (!mediaItems.length) return;
      mediaIndex = (mediaIndex + 1) % mediaItems.length;
      renderMediaStage();
    });

  // Apply → open download modal (after viewing details)
  document.getElementById('unit-details-apply') &&
    document.getElementById('unit-details-apply').addEventListener('click', function () {
      const unit = (currentListing && currentListing.unit) || {};
      const property = (currentListing && currentListing.property) || {};
      openDownloadModal(unit, property);
    });

  document.querySelectorAll('[data-close-modal]').forEach(function (btn) {
    btn.addEventListener('click', closeDownloadModal);
  });
  if (downloadModal) {
    downloadModal.addEventListener('click', function (e) {
      if (e.target === downloadModal) closeDownloadModal();
    });
  }

  document.getElementById('listings-refresh') &&
    document.getElementById('listings-refresh').addEventListener('click', load);
  document.getElementById('listings-filter-btn') &&
    document.getElementById('listings-filter-btn').addEventListener('click', load);

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
