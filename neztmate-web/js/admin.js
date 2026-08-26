/**
 * NeztMate Admin shell — role-aware, no auto-logout on API errors.
 */
const AdminGuard = {
  requireAuth() {
    if (!window.NeztMateApi || !NeztMateApi.getToken()) {
      location.href = 'login.html';
      return false;
    }
    this.applyTheme();
    this.paintUser();
    this.bindLogout();
    this.bindTheme();
    this.paintNav();
    return true;
  },

  isPlatform() {
    return NeztMateApi.isPlatformAdmin();
  },

  applyTheme() {
    const t = localStorage.getItem('neztmate_theme') || 'light';
    document.documentElement.setAttribute('data-theme', t);
  },

  bindTheme() {
    const btn = document.getElementById('theme-toggle');
    if (!btn) return;
    const sync = () => {
      const t = document.documentElement.getAttribute('data-theme') || 'light';
      btn.textContent = t === 'dark' ? '☀️' : '🌙';
      btn.title = t === 'dark' ? 'Light mode' : 'Dark mode';
    };
    sync();
    btn.onclick = () => {
      const next = (document.documentElement.getAttribute('data-theme') || 'light') === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next);
      localStorage.setItem('neztmate_theme', next);
      sync();
    };
  },

  paintUser() {
    const user = NeztMateApi.getUser() || {};
    const el = document.getElementById('side-user');
    const partnerLabel = document.getElementById('partner-label');
    const roleBadge = document.getElementById('role-badge');
    if (el) el.textContent = user.fullName || user.email || 'Signed in';
    if (partnerLabel) {
      partnerLabel.textContent = this.isPlatform()
        ? '· Platform'
        : user.partnerId
          ? '· ' + user.partnerId
          : '';
    }
    if (roleBadge) {
      roleBadge.textContent = this.isPlatform() ? 'Platform admin' : 'Partner admin';
    }
  },

  paintNav() {
    const isPlatform = this.isPlatform();
    document.querySelectorAll('[data-platform-only]').forEach((el) => {
      el.classList.toggle('hidden', !isPlatform);
    });
    document.querySelectorAll('[data-partner-only]').forEach((el) => {
      el.classList.toggle('hidden', isPlatform);
    });
    // Highlight current page
    const path = location.pathname.split('/').pop() || 'index.html';
    document.querySelectorAll('.sidebar nav a[href]').forEach((a) => {
      const href = a.getAttribute('href');
      if (href && href !== '#' && path === href.split('?')[0]) a.classList.add('active');
    });
  },

  bindLogout() {
    const link = document.getElementById('logout-link');
    if (!link) return;
    link.addEventListener('click', (e) => {
      e.preventDefault();
      this.logout();
    });
  },

  logout() {
    NeztMateApi.clearSession();
    location.href = 'login.html';
  },

  money(n) {
    return typeof n === 'number'
      ? '₦' + n.toLocaleString('en-NG', { maximumFractionDigits: 0 })
      : '—';
  },

  /** Show error in #error without logging out */
  showError(msg) {
    const el = document.getElementById('error');
    if (!el) {
      console.error(msg);
      return;
    }
    el.style.display = 'block';
    el.className = 'alert alert-error';
    el.textContent = typeof msg === 'string' ? msg : msg?.message || 'Something went wrong';
  },

  showOk(msg) {
    const el = document.getElementById('info') || document.getElementById('success');
    if (!el) return;
    el.style.display = 'block';
    el.className = 'alert alert-ok';
    el.textContent = msg;
  },

  clearAlerts() {
    ['error', 'info', 'success'].forEach((id) => {
      const el = document.getElementById(id);
      if (el) el.style.display = 'none';
    });
  },

  badge(status) {
    const s = String(status || '').toLowerCase();
    let cls = 'badge-muted';
    if (['active', 'paid', 'approved', 'completed', 'ok'].some((x) => s.includes(x))) cls = 'badge-ok';
    else if (['pending', 'held', 'processing'].some((x) => s.includes(x))) cls = 'badge-warn';
    else if (['reject', 'fail', 'expired', 'terminat', 'inactive', 'cancel'].some((x) => s.includes(x)))
      cls = 'badge-danger';
    return '<span class="badge ' + cls + '">' + (status || '—') + '</span>';
  },

  /**
   * Safe API call — never redirects on 401/403/500 while session exists.
   * Only clears session if token is missing client-side.
   */
  async api(fn, fallback) {
    try {
      return await fn();
    } catch (e) {
      console.warn('Admin API error:', e);
      if (!NeztMateApi.getToken()) {
        location.href = 'login.html';
        return fallback;
      }
      this.showError(e.message || 'Request failed');
      return fallback;
    }
  },

  /** Shared modal helpers */
  openModal(id) {
    const el = document.getElementById(id);
    if (el) el.classList.remove('hidden');
  },
  closeModal(id) {
    const el = document.getElementById(id);
    if (el) el.classList.add('hidden');
  },

  esc(s) {
    return String(s ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  },
};

window.AdminGuard = AdminGuard;

/** Apply theme early (before paint) */
(function () {
  const t = localStorage.getItem('neztmate_theme') || 'light';
  document.documentElement.setAttribute('data-theme', t);
})();
