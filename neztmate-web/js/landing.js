(function () {
  const CFG = window.NeztMateConfig || {};
  const y = document.getElementById('year');
  if (y) y.textContent = new Date().getFullYear();

  document.querySelectorAll('.role-tab').forEach((tab) => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.role-tab').forEach((t) => t.classList.remove('active'));
      document.querySelectorAll('.role-panel').forEach((p) => p.classList.remove('active'));
      tab.classList.add('active');
      const panel = document.getElementById('panel-' + tab.dataset.role);
      if (panel) panel.classList.add('active');
    });
  });

  const play = CFG.playStoreUrl || '#';
  const ios = CFG.appStoreUrl || '#';
  document.querySelectorAll('[data-store="play"]').forEach((el) => (el.href = play));
  document.querySelectorAll('[data-store="ios"]').forEach((el) => (el.href = ios));

  const params = new URLSearchParams(location.search);
  const slug = (
    params.get('partner') ||
    params.get('slug') ||
    CFG.defaultPartnerSlug ||
    'neztmate'
  )
    .toLowerCase()
    .trim();

  const samples = CFG.samplePartners || {};
  const fallback = samples[slug] || samples.neztmate;

  function normalizePartner(raw) {
    const p = raw?.partner || raw || {};
    return {
      id: p.id || p.partnerId || slug,
      name: p.name || p.displayName || fallback.name,
      slug: p.slug || slug,
      tagline: p.tagline || p.description || fallback.tagline,
      primaryColor: p.primaryColor || p.primary_color || fallback.primaryColor,
      secondaryColor: p.secondaryColor || p.secondary_color || fallback.secondaryColor,
      logoUrl: p.logoUrl || p.logo_url || fallback.logoUrl,
      supportEmail: p.supportEmail || p.support_email || 'support@neztmate.com',
    };
  }

  if (window.NeztMateTheme) {
    NeztMateTheme.apply(normalizePartner(fallback));
  }

  if (window.NeztMateApi) {
    NeztMateApi.getPartnerConfig(slug)
      .then((data) => {
        const partner = normalizePartner(data);
        if (window.NeztMateTheme) NeztMateTheme.apply(partner);
        localStorage.setItem('neztmate_partner_slug', slug);
        localStorage.setItem('neztmate_partner_cache', JSON.stringify(partner));
      })
      .catch(() => {
        if (window.NeztMateTheme) NeztMateTheme.apply(normalizePartner(fallback));
      });

    loadPartnersStrip();
  }

  async function loadPartnersStrip() {
    const grid = document.getElementById('partners-grid');
    const status = document.getElementById('partners-status');
    if (!grid) return;

    try {
      const data = await NeztMateApi.listActivePartners();
      let list = data.partners || data || [];
      if (!Array.isArray(list)) list = [];

      // Only active partners with a public-facing name
      list = list.filter((p) => p && (p.isActive !== false) && p.name);

      // Prefer not to only show self if many exist; still show neztmate if alone
      if (!list.length) {
        throw new Error('empty');
      }

      grid.innerHTML = list
        .map((p) => {
          const color = p.primaryColor || '#0d9488';
          const slug = p.slug || '';
          const tagline = p.tagline || 'Property partner on NeztMate';
          const href = slug ? 'index.html?partner=' + encodeURIComponent(slug) : '#';
          const logo = p.logoUrl
            ? '<img src="' +
              p.logoUrl +
              '" alt="" style="width:40px;height:40px;border-radius:10px;object-fit:cover" />'
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
            '</h3>' +
            '<p>' +
            tagline +
            '</p>' +
            (slug ? '<p class="muted" style="margin-top:.5rem;font-size:.8rem">/' + slug + '</p>' : '') +
            '</a>'
          );
        })
        .join('');

      if (status) status.textContent = list.length + ' active partner' + (list.length === 1 ? '' : 's');
    } catch (e) {
      // Fallback sample cards so the section never looks broken
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
              '">' +
              '<div class="icon" style="background:' +
              color +
              '22;color:' +
              color +
              '">' +
              p.name.charAt(0) +
              '</div>' +
              '<h3 style="margin-top:.75rem">' +
              p.name +
              '</h3>' +
              '<p>' +
              (p.tagline || '') +
              '</p></a>'
            );
          })
          .join('');
        if (status) {
          status.textContent =
            'Showing sample partners (connect GET /partners/public or public list when API is ready).';
        }
      } else if (status) {
        status.textContent = 'Partners will appear here once published.';
      }
    }
  }
})();
