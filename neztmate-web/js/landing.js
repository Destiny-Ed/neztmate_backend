(function () {
  const CFG = window.NeztMateConfig || {};
  const DEFAULT_PRIVACY = 'privacy.html';
  const DEFAULT_TERMS = 'terms.html';
  const DEFAULT_SUPPORT = 'support@neztmate.com';
  const PLATFORM_HOME = CFG.platformHomeUrl || 'https://neztmate.com';

  const params = new URLSearchParams(location.search);
  const partnerParam = (params.get('partner') || params.get('slug') || '').toLowerCase().trim();
  const slug = (partnerParam || CFG.defaultPartnerSlug || 'neztmate').toLowerCase().trim();

  /**
   * White-label / partner-hosted mode:
   * - Explicit ?partner=... (including neztmate) → partner site UX
   * - Or slug resolved to non-neztmate
   * Platform marketing site = no partner query param
   */
  const isPartnerHosted = Boolean(partnerParam) || slug !== 'neztmate';
  const isPlatformSite = !isPartnerHosted;

  document.documentElement.classList.toggle('partner-hosted', isPartnerHosted);
  document.documentElement.classList.toggle('platform-site', isPlatformSite);

  function setYear() {
    const y = document.getElementById('year');
    if (y) y.textContent = new Date().getFullYear();
  }
  setYear();

  document.querySelectorAll('.role-tab').forEach((tab) => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.role-tab').forEach((t) => t.classList.remove('active'));
      document.querySelectorAll('.role-panel').forEach((p) => p.classList.remove('active'));
      tab.classList.add('active');
      const panel = document.getElementById('panel-' + tab.dataset.role);
      if (panel) panel.classList.add('active');
    });
  });

  function applyPlatformOnlyVisibility() {
    document.querySelectorAll('[data-platform-only]').forEach((el) => {
      el.classList.toggle('hidden', isPartnerHosted);
      if (isPartnerHosted) el.style.display = 'none';
      else el.style.removeProperty('display');
    });

    const powered = document.getElementById('powered-by');
    const poweredBottom = document.getElementById('powered-by-bottom');
    if (isPartnerHosted) {
      if (powered) {
        powered.style.display = 'block';
        powered.innerHTML =
          'Powered by <a href="' +
          PLATFORM_HOME +
          '" target="_blank" rel="noopener">NeztMate</a>';
      }
      if (poweredBottom) {
        poweredBottom.style.display = 'inline';
        poweredBottom.innerHTML =
          'Powered by <a href="' +
          PLATFORM_HOME +
          '" target="_blank" rel="noopener">NeztMate</a>';
      }
    } else {
      if (powered) powered.style.display = 'none';
      if (poweredBottom) poweredBottom.style.display = 'none';
    }
  }

  applyPlatformOnlyVisibility();

  function applyStoreAndLegal(partner) {
    const play =
      partner.playStoreUrl ||
      partner.play_store_url ||
      CFG.playStoreUrl ||
      '#';
    const ios =
      partner.appStoreUrl ||
      partner.app_store_url ||
      CFG.appStoreUrl ||
      '#';

    document.querySelectorAll('[data-store="play"]').forEach((el) => {
      el.href = play;
    });
    document.querySelectorAll('[data-store="ios"]').forEach((el) => {
      el.href = ios;
    });

    const privacy =
      partner.privacyUrl || partner.privacy_url || CFG.defaultPrivacyUrl || DEFAULT_PRIVACY;
    const terms = partner.termsUrl || partner.terms_url || CFG.defaultTermsUrl || DEFAULT_TERMS;

    const privacyEl = document.getElementById('footer-privacy');
    const termsEl = document.getElementById('footer-terms');
    if (privacyEl) privacyEl.href = privacy;
    if (termsEl) termsEl.href = terms;

    const support =
      partner.supportEmail || partner.support_email || CFG.defaultSupportEmail || DEFAULT_SUPPORT;
    document.querySelectorAll('[data-brand-support]').forEach((el) => {
      if (el.tagName === 'A') {
        el.href = 'mailto:' + support;
        el.textContent = support;
      } else el.textContent = support;
    });

    const copyright =
      partner.copyright ||
      partner.copyrightText ||
      null;
    const line = document.getElementById('copyright-line');
    if (line) {
      const year = new Date().getFullYear();
      const brand = partner.name || 'NeztMate';
      if (copyright) {
        line.textContent = copyright.replace('{year}', String(year)).replace('{name}', brand);
      } else {
        line.innerHTML =
          '© <span id="year">' +
          year +
          '</span> <span data-brand-name>' +
          brand +
          '</span>. All rights reserved.';
      }
    }
  }

  const samples = CFG.samplePartners || {};
  const fallback = samples[slug] || samples.neztmate || {
    name: 'NeztMate',
    slug: 'neztmate',
    tagline: 'Find, rent & manage homes with less stress',
    primaryColor: '#0d9488',
    secondaryColor: '#0f766e',
    supportEmail: DEFAULT_SUPPORT,
  };

  function normalizePartner(raw) {
    const p = raw?.partner || raw || {};
    return {
      id: p.id || p.partnerId || slug,
      name: p.name || p.displayName || fallback.name,
      slug: (p.slug || slug).toLowerCase(),
      tagline: p.tagline || p.description || fallback.tagline,
      primaryColor: p.primaryColor || p.primary_color || fallback.primaryColor,
      secondaryColor: p.secondaryColor || p.secondary_color || fallback.secondaryColor,
      logoUrl: p.logoUrl || p.logo_url || fallback.logoUrl || null,
      supportEmail: p.supportEmail || p.support_email || DEFAULT_SUPPORT,
      playStoreUrl: p.playStoreUrl || p.play_store_url || CFG.playStoreUrl,
      appStoreUrl: p.appStoreUrl || p.app_store_url || CFG.appStoreUrl,
      privacyUrl: p.privacyUrl || p.privacy_url || '',
      termsUrl: p.termsUrl || p.terms_url || '',
      copyright: p.copyright || p.copyrightText || '',
    };
  }

  function applyAll(partner) {
    if (window.NeztMateTheme) NeztMateTheme.apply(partner, { isPartnerHosted });
    applyStoreAndLegal(partner);
    applyPlatformOnlyVisibility();
  }

  applyAll(normalizePartner(fallback));

  if (window.NeztMateApi) {
    NeztMateApi.getPartnerConfig(slug)
      .then((data) => {
        const partner = normalizePartner(data);
        applyAll(partner);
        localStorage.setItem('neztmate_partner_slug', slug);
        localStorage.setItem('neztmate_partner_cache', JSON.stringify(partner));
      })
      .catch(() => {
        applyAll(normalizePartner(fallback));
      });

    if (isPlatformSite) {
      loadPartnersStrip();
    }
  }

  async function loadPartnersStrip() {
    const grid = document.getElementById('partners-grid');
    const status = document.getElementById('partners-status');
    if (!grid || isPartnerHosted) return;

    try {
      const data = await NeztMateApi.listActivePartners();
      let list = data.partners || data || [];
      if (!Array.isArray(list)) list = [];
      list = list.filter((p) => p && p.isActive !== false && p.name);
      if (!list.length) throw new Error('empty');

      grid.innerHTML = list
        .map((p) => {
          const color = p.primaryColor || '#0d9488';
          const s = p.slug || '';
          const tagline = p.tagline || 'Property partner on NeztMate';
          const href = s ? 'index.html?partner=' + encodeURIComponent(s) : '#';
          const logo = p.logoUrl
            ? '<img src="' +
              p.logoUrl +
              '" alt="" width="40" height="40" style="width:40px;height:40px;border-radius:10px;object-fit:cover" />'
            : '<div class="icon" style="background:' +
              color +
              '22;color:' +
              color +
              '">' +
              (p.name || '?').charAt(0).toUpperCase() +
              '</div>';
          return (
            '<a class="card partner-card" href="' +
            href +
            '" style="text-decoration:none;color:inherit;border-top:3px solid ' +
            color +
            '">' +
            logo +
            '<h3 style="margin-top:.75rem">' +
            (p.name || 'Partner') +
            '</h3><p>' +
            tagline +
            '</p>' +
            (s ? '<p class="muted" style="margin-top:.5rem;font-size:.8rem">/' + s + '</p>' : '') +
            '</a>'
          );
        })
        .join('');
      if (status) status.textContent = list.length + ' active partner' + (list.length === 1 ? '' : 's');
    } catch (e) {
      const samplesList = Object.values(CFG.samplePartners || {});
      if (samplesList.length) {
        grid.innerHTML = samplesList
          .map((p) => {
            const color = p.primaryColor || '#0d9488';
            return (
              '<a class="card partner-card" href="index.html?partner=' +
              encodeURIComponent(p.slug) +
              '" style="text-decoration:none;color:inherit;border-top:3px solid ' +
              color +
              '"><div class="icon" style="background:' +
              color +
              '22;color:' +
              color +
              '">' +
              p.name.charAt(0) +
              '</div><h3 style="margin-top:.75rem">' +
              p.name +
              '</h3><p>' +
              (p.tagline || '') +
              '</p></a>'
            );
          })
          .join('');
        if (status) status.textContent = 'Sample partners (connect public partners API when ready).';
      } else if (status) {
        status.textContent = 'Partners will appear here once published.';
      }
    }
  }
})();
