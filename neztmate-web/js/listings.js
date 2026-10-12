(function () {
  const CFG = window.NeztMateConfig || {};
  const API = CFG.apiBase || 'https://neztmate-backend.onrender.com';
  const play = CFG.playStoreUrl || 'https://play.google.com/store/apps/details?id=com.neztmate.app';
  const appStore = CFG.appStoreUrl || 'https://apps.apple.com/app/neztmate';
  const grid = document.getElementById('listings-grid');
  const empty = document.getElementById('listings-empty');
  const statusEl = document.getElementById('listings-status');
  const modal = document.getElementById('app-download-modal');
  const searchInput = document.getElementById('listings-search');
  const cityInput = document.getElementById('listings-city');
  const stateInput = document.getElementById('listings-state');
  const minBedInput = document.getElementById('listings-beds');
  const maxRentInput = document.getElementById('listings-max-rent');

  function money(n) {
    if (typeof n !== 'number') return '—';
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

  function openModal(unit, property) {
    const title = document.getElementById('modal-unit-title');
    const sub = document.getElementById('modal-unit-sub');
    if (title) {
      title.textContent =
        (unit && (unit.title || unit.unitNumber || unit.name)) ||
        (property && property.name) ||
        'This home';
    }
    if (sub) {
      const loc = [property && property.city, property && property.state].filter(Boolean).join(', ');
      sub.textContent = loc
        ? 'Available on NeztMate in ' + loc + '. Download the app to view full details and apply.'
        : 'Download the NeztMate app to view full details, chat, and apply for this home.';
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
    const loc = esc([property.city, property.state, property.address].filter(Boolean).slice(0, 2).join(', ') || 'Nigeria');
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

    const params = new URLSearchParams();
    const city = (cityInput && cityInput.value.trim()) || '';
    const state = (stateInput && stateInput.value.trim()) || '';
    const beds = (minBedInput && minBedInput.value) || '';
    const maxRent = (maxRentInput && maxRentInput.value) || '';
    if (city) params.set('city', city);
    if (state) params.set('state', state);
    if (beds) params.set('minBedrooms', beds);
    if (maxRent) params.set('maxRent', maxRent);

    try {
      const res = await fetch(API + '/units/available' + (params.toString() ? '?' + params : ''), {
        headers: { Accept: 'application/json' },
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
      if (empty) empty.textContent = 'Unable to load listings right now. Please try again later.';
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

  var playA = document.getElementById('modal-play-link');
  var iosA = document.getElementById('modal-ios-link');
  if (playA) playA.href = play;
  if (iosA) iosA.href = appStore;

  load();
})();
