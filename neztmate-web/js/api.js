const CFG = window.NeztMateConfig || {};
const API_BASE = CFG.apiBase || 'https://neztmate-backend.onrender.com';
const TOKEN_KEY = 'neztmate_access_token';
const REFRESH_KEY = 'neztmate_refresh_token';
const USER_KEY = 'neztmate_user';

const Api = {
  base: API_BASE,

  getToken() {
    return localStorage.getItem(TOKEN_KEY);
  },

  setSession({ accessToken, refreshToken, user }) {
    if (accessToken) localStorage.setItem(TOKEN_KEY, accessToken);
    if (refreshToken) localStorage.setItem(REFRESH_KEY, refreshToken);
    if (user) localStorage.setItem(USER_KEY, JSON.stringify(user));
  },

  clearSession() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(REFRESH_KEY);
    localStorage.removeItem(USER_KEY);
  },

  getUser() {
    try {
      return JSON.parse(localStorage.getItem(USER_KEY) || 'null');
    } catch {
      return null;
    }
  },

  isPlatformAdmin() {
    const u = this.getUser() || {};
    const role = (u.role || '').toLowerCase();
    return role === 'platform_admin' || role === 'super_admin' || u.isPlatformAdmin === true;
  },

  async request(path, { method = 'GET', body, auth = true, headers = {} } = {}) {
    const h = { Accept: 'application/json', ...headers };
    if (body !== undefined) h['Content-Type'] = 'application/json';
    if (auth) {
      const token = this.getToken();
      if (!token) {
        const err = new Error('Not authenticated');
        err.status = 401;
        throw err;
      }
      h.Authorization = 'Bearer ' + token;
    }

    const res = await fetch(this.base + path, {
      method,
      headers: h,
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });

    const text = await res.text();
    let data = null;
    try {
      data = text ? JSON.parse(text) : null;
    } catch {
      data = { message: text };
    }

    if (!res.ok) {
      const err = new Error((data && data.message) || res.statusText || 'Request failed');
      err.status = res.status;
      err.data = data;
      throw err;
    }
    return data;
  },

  // Public
  
  listActivePartners() {
    // Prefer public list; fall back to protected list if public not deployed
    return this.request('/partners/public', { auth: false }).catch(() =>
      this.request('/partners/?activeOnly=true', { auth: false }).catch(() =>
        this.request('/partners/', { auth: false })
      )
    );
  },

  getPartnerConfig(slug) {
    return this.request('/partners/config?slug=' + encodeURIComponent(slug), { auth: false });
  },

  submitPartnerRequest(payload) {
    return this.request('/partners/requests', { method: 'POST', auth: false, body: payload });
  },

  /**
   * Login
   * - platform_admin: partnerId optional / omit
   * - everyone else: partnerId required
   * - fcmToken required by API (web sends a web placeholder)
   */
  
  /**
   * Platform admin only — Google ID token from GIS.
   * Backend verifies token, checks allowlist / role platform_admin, returns JWT.
   */
  platformGoogleLogin({ idToken, fcmToken }) {
    return this.request('/auth/platform/google', {
      method: 'POST',
      auth: false,
      body: {
        idToken,
        fcmToken: fcmToken || 'web-admin-google-' + Date.now(),
        platform: 'web',
        loginAs: 'platform_admin',
      },
    });
  },

  login({ email, password, partnerId, fcmToken, isPlatformAdmin }) {
    const body = {
      email,
      password,
      fcmToken: fcmToken || 'web-admin-' + (typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : Date.now()),
      platform: 'web',
    };
    if (!isPlatformAdmin && partnerId) body.partnerId = partnerId;
    if (isPlatformAdmin) body.loginAs = 'platform_admin';
    return this.request('/auth/login', { method: 'POST', auth: false, body });
  },

  // Partner
  getMyPartner() {
    return this.request('/partners/me');
  },
  updateMyPartner(payload) {
    return this.request('/partners/me', { method: 'PATCH', body: payload });
  },
  updateMyBranding(payload) {
    return this.request('/partners/me/branding', { method: 'PATCH', body: payload });
  },

  // Platform
  listPartners() {
    return this.request('/partners/');
  },
  createPartner(payload) {
    return this.request('/partners/', { method: 'POST', body: payload });
  },
  getPartnerById(id) {
    return this.request('/partners/' + encodeURIComponent(id));
  },
  updatePartner(id, payload) {
    return this.request('/partners/' + encodeURIComponent(id), { method: 'PATCH', body: payload });
  },
  setPartnerStatus(id, status) {
    return this.request('/partners/' + encodeURIComponent(id) + '/status', {
      method: 'PATCH',
      body: { status },
    });
  },
  listPartnerRequests() {
    return this.request('/partners/requests');
  },
  updatePartnerRequest(id, payload) {
    return this.request('/partners/requests/' + encodeURIComponent(id), {
      method: 'PATCH',
      body: payload,
    });
  },

  // Product data
  getMySubscription() {
    return this.request('/subscriptions/me');
  },
  getPaymentSummary() {
    return this.request('/payments/summary');
  },
  getMyPayments() {
    return this.request('/payments/my_payments').catch(() => this.request('/payments/me'));
  },
  getMyProperties() {
    return this.request('/properties').catch(() => this.request('/properties/all'));
  },
  getNotifications() {
    return this.request('/notifications');
  },
  
  
  // ── Platform: partners + credentials ──
  createPartnerWithAdmin(body) {
    return this.request('/partners/with-admin', { method: 'POST', body });
  },
  approvePartnerRequest(id, body) {
    return this.request('/partners/requests/' + encodeURIComponent(id) + '/approve', {
      method: 'POST',
      body,
    });
  },
  updatePartnerRequestStatus(id, body) {
    return this.request('/partners/requests/' + encodeURIComponent(id), {
      method: 'PATCH',
      body,
    });
  },
  resetPartnerAdminPassword(partnerId, body) {
    return this.request('/partners/' + encodeURIComponent(partnerId) + '/admin/reset-password', {
      method: 'POST',
      body,
    });
  },
  changeMyPassword(body) {
    return this.request('/auth/change-password', { method: 'POST', body });
  },
  // ── Ops lists ──
  listUsers(params = {}) {
    const q = new URLSearchParams(params).toString();
    return this.request('/users' + (q ? '?' + q : ''));
  },
  listLeases(params = {}) {
    const q = new URLSearchParams(params).toString();
    return this.request('/leases' + (q ? '?' + q : '')).catch(() =>
      this.request('/leases/me')
    );
  },
  listAllUnits(params = {}) {
    const q = new URLSearchParams(params).toString();
    return this.request('/units/my' + (q ? '?' + q : '')).catch(() =>
      this.request('/units/available')
    );
  },
  listApplications(params = {}) {
    const q = new URLSearchParams(params).toString();
    return this.request('/applications/me' + (q ? '?' + q : ''));
  },
  getPaymentSummary(params = {}) {
    const q = new URLSearchParams(params).toString();
    return this.request('/payments/summary' + (q ? '?' + q : ''));
  },
  getMyPayments() {
    return this.request('/payments/my_payments').catch(() =>
      this.request('/payments/me')
    );
  },
  getMyProperties() {
    return this.request('/properties');
  },
  getNotifications() {
    return this.request('/notifications');
  },
  getHistory() {
    return this.request('/history/me');
  },
  listPartners(params = {}) {
    const q = new URLSearchParams(params).toString();
    return this.request('/partners/' + (q ? '?' + q : ''));
  },
  listPartnerRequests(params = {}) {
    const q = new URLSearchParams(params).toString();
    return this.request('/partners/requests' + (q ? '?' + q : ''));
  },
  createPartner(body) {
    return this.request('/partners/', { method: 'POST', body });
  },
  updatePartner(id, body) {
    return this.request('/partners/' + encodeURIComponent(id), { method: 'PATCH', body });
  },
  setPartnerStatus(id, body) {
    return this.request('/partners/' + encodeURIComponent(id) + '/status', {
      method: 'PATCH',
      body,
    });
  },
  updateMyPartner(body) {
    return this.request('/partners/me', { method: 'PATCH', body });
  },
  updateMyBranding(body) {
    return this.request('/partners/me/branding', { method: 'PATCH', body });
  },

  getPartnerAnalytics() {
    return this.request('/partners/me/analytics');
  },

  getPlatformAnalytics() {
    return this.request('/platform/analytics').catch(() =>
      this.request('/partners/analytics/platform')
    );
  },

  getHistory() {
    return this.request('/history');
  },
};

window.NeztMateApi = Api;
