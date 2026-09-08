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

  /**
   * Ensure a shared detail drawer exists on the page.
   * Usage: AdminGuard.showDetail({ title, rows: [[label, value], ...], html? })
   */
  ensureDetailDrawer() {
    if (document.getElementById('admin-detail-drawer')) return;

    const css = document.createElement('style');
    css.textContent = `
      .admin-detail-backdrop {
        position: fixed; inset: 0; z-index: 200;
        background: rgba(15, 23, 42, .45);
        display: flex; justify-content: flex-end;
      }
      .admin-detail-backdrop.hidden { display: none !important; }
      .admin-detail-panel {
        width: min(440px, 100vw); height: 100%;
        background: var(--white, #fff); color: var(--ink, #0f172a);
        border-left: 1px solid var(--line, #e2e8f0);
        box-shadow: -12px 0 40px rgba(0,0,0,.12);
        display: flex; flex-direction: column;
        animation: adminDetailIn .2s ease;
      }
      @keyframes adminDetailIn { from { transform: translateX(24px); opacity: .6; } to { transform: none; opacity: 1; } }
      .admin-detail-head {
        display: flex; align-items: center; justify-content: space-between;
        gap: 1rem; padding: 1rem 1.15rem; border-bottom: 1px solid var(--line, #e2e8f0);
      }
      .admin-detail-head h3 { margin: 0; font-size: 1.05rem; }
      .admin-detail-body { padding: 1rem 1.15rem 2rem; overflow: auto; flex: 1; }
      .admin-detail-row {
        display: grid; grid-template-columns: 120px 1fr; gap: .5rem .75rem;
        padding: .55rem 0; border-bottom: 1px solid var(--line, #eef2f7);
        font-size: .9rem;
      }
      .admin-detail-row .lbl { color: var(--muted, #64748b); font-weight: 500; }
      .admin-detail-row .val { word-break: break-word; }
      .admin-detail-row .val code { font-size: .78rem; }
      tr.row-click { cursor: pointer; }
      tr.row-click:hover td { background: rgba(13, 148, 136, .06); }
      html[data-theme="dark"] .admin-detail-panel { background: var(--white); }
      html[data-theme="dark"] tr.row-click:hover td { background: rgba(45, 212, 191, .08); }
    `;
    document.head.appendChild(css);

    const root = document.createElement('div');
    root.id = 'admin-detail-drawer';
    root.className = 'admin-detail-backdrop hidden';
    root.innerHTML = `
      <div class="admin-detail-panel" role="dialog" aria-modal="true">
        <div class="admin-detail-head">
          <h3 id="admin-detail-title">Details</h3>
          <button type="button" class="btn btn-ghost btn-sm" id="admin-detail-close" aria-label="Close">×</button>
        </div>
        <div class="admin-detail-body" id="admin-detail-body"></div>
      </div>`;
    document.body.appendChild(root);

    root.addEventListener('click', (e) => {
      if (e.target === root) this.hideDetail();
    });
    document.getElementById('admin-detail-close').onclick = () => this.hideDetail();
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') this.hideDetail();
    });
  },

  /** @param {{ title: string, rows?: Array<[string, any]>, html?: string }} opts */
  showDetail({ title, rows = [], html = '' }) {
    this.ensureDetailDrawer();
    document.getElementById('admin-detail-title').textContent = title || 'Details';
    const body = document.getElementById('admin-detail-body');

    const rowHtml = rows
      .map(([label, value]) => {
        let v = value;
        if (v == null || v === '') v = '—';
        else if (typeof v === 'boolean') v = v ? 'Yes' : 'No';
        else if (typeof v === 'object') v = '<code>' + this.esc(JSON.stringify(v, null, 2)) + '</code>';
        else if (String(v).startsWith('http')) {
          v = '<a href="' + this.esc(String(v)) + '" target="_blank" rel="noopener">' + this.esc(String(v)) + '</a>';
        } else {
          v = this.esc(String(v));
        }
        return (
          '<div class="admin-detail-row"><div class="lbl">' +
          this.esc(label) +
          '</div><div class="val">' +
          v +
          '</div></div>'
        );
      })
      .join('');

    body.innerHTML = rowHtml + (html || '');
    document.getElementById('admin-detail-drawer').classList.remove('hidden');
  },

  hideDetail() {
    const el = document.getElementById('admin-detail-drawer');
    if (el) el.classList.add('hidden');
  },

  /** Format ISO date for display */
  fmtDate(v) {
    if (!v) return '—';
    try {
      return new Date(v).toLocaleString();
    } catch {
      return String(v);
    }
  },
};

window.AdminGuard = AdminGuard;

/** Apply theme early (before paint) */
(function () {
  const t = localStorage.getItem('neztmate_theme') || 'light';
  document.documentElement.setAttribute('data-theme', t);
})();