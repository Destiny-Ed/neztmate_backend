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

  getTokenPayload() {
    try {
      const token = this.getToken();
      if (!token) return null;
      const part = token.split('.')[1];
      if (!part) return null;
      const json = atob(part.replace(/-/g, '+').replace(/_/g, '/'));
      return JSON.parse(json);
    } catch {
      return null;
    }
  },

  isPlatformAdmin() {
    const payload = this.getTokenPayload() || {};
    const tokenRole = String(payload.role || '').toLowerCase();
    if (tokenRole === 'platform_admin' || tokenRole === 'super_admin') return true;
    const u = this.getUser() || {};
    const role = String(u.role || '').toLowerCase();
    if (role === 'platform_admin' || role === 'super_admin') return true;
    return false;
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

  listActivePartners() {
    return this.request('/partners/public', { auth: false });
  },
  getPartnerConfig(slug) {
    return this.request('/partners/config?slug=' + encodeURIComponent(slug), { auth: false });
  },
  submitPartnerRequest(payload) {
    return this.request('/partners/requests', { method: 'POST', auth: false, body: payload });
  },
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
  getMyPartner() {
    return this.request('/partners/me');
  },
  updateMyPartner(payload) {
    return this.request('/partners/me', { method: 'PATCH', body: payload });
  },
  updateMyBranding(payload) {
    return this.request('/partners/me/branding', { method: 'PATCH', body: payload });
  },
  listPartners(params = {}) {
    const q = new URLSearchParams(params).toString();
    return this.request('/partners/' + (q ? '?' + q : ''));
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
      body: typeof status === 'object' ? status : { status },
    });
  },
  listPartnerRequests(params = {}) {
    const q = new URLSearchParams(params).toString();
    return this.request('/partners/requests' + (q ? '?' + q : ''));
  },
  updatePartnerRequest(id, payload) {
    return this.request('/partners/requests/' + encodeURIComponent(id), {
      method: 'PATCH',
      body: payload,
    });
  },
  getPublicPlans({ partnerId, slug } = {}) {
    const q = new URLSearchParams();
    if (partnerId) q.set('partnerId', partnerId);
    if (slug) q.set('slug', slug);
    const qs = q.toString();
    return this.request('/subscriptions/plans/public' + (qs ? '?' + qs : ''), { auth: false }).catch(
      () => {
        if (this.getToken()) return this.getSubscriptionPlans();
        throw new Error('Plans unavailable');
      }
    );
  },
  getSubscriptionPlans(params = {}) {
    const q = new URLSearchParams();
    Object.entries(params || {}).forEach(([k, v]) => {
      if (v !== undefined && v !== null && v !== '') q.set(k, v);
    });
    const qs = q.toString();
    return this.request('/subscriptions/plans' + (qs ? '?' + qs : ''));
  },
  getMySubscription(params = {}) {
    const q = new URLSearchParams();
    Object.entries(params || {}).forEach(([k, v]) => {
      if (v !== undefined && v !== null && v !== '') q.set(k, v);
    });
    const qs = q.toString();
    return this.request('/subscriptions/me' + (qs ? '?' + qs : ''));
  },
  getSubscriptionHistory() {
    return this.request('/subscriptions/history').catch(() =>
      this.request('/subscriptions/me/history')
    );
  },
  subscribeToPlan({ planId, billingCycle, partnerId }) {
    const body = { planId, billingCycle };
    if (partnerId) body.partnerId = partnerId;
    return this.request('/subscriptions/subscribe', { method: 'POST', body });
  },
  cancelSubscription() {
    return this.request('/subscriptions/cancel', { method: 'POST', body: {} });
  },
  createSubscriptionPlan(body) {
    return this.request('/subscriptions/plans', { method: 'POST', body });
  },
  updateSubscriptionPlan(id, body) {
    return this.request('/subscriptions/plans/' + encodeURIComponent(id), {
      method: 'PATCH',
      body,
    });
  },
  deleteSubscriptionPlan(id, params = {}) {
    const q = new URLSearchParams();
    Object.entries(params || {}).forEach(([k, v]) => {
      if (v !== undefined && v !== null && v !== '') q.set(k, v);
    });
    const qs = q.toString();
    return this.request(
      '/subscriptions/plans/' + encodeURIComponent(id) + (qs ? '?' + qs : ''),
      { method: 'DELETE' }
    );
  },
  getPaymentSummary(params = {}) {
    const q = new URLSearchParams(params).toString();
    return this.request('/payments/summary' + (q ? '?' + q : ''));
  },
  getMyPayments() {
    return this.request('/payments/my_payments').catch(() => this.request('/payments/me'));
  },
  getMyProperties() {
    return this.request('/properties').catch(() => this.request('/properties/all'));
  },
  getNotifications() {
    return this.request('/notifications').catch(() => this.request('/notifications/all'));
  },
  listAnnouncementsAdmin(params = {}) {
    const q = new URLSearchParams();
    Object.entries(params || {}).forEach(([k, v]) => {
      if (v !== undefined && v !== null && v !== '') q.set(k, v);
    });
    const qs = q.toString();
    return this.request('/announcements/admin' + (qs ? '?' + qs : ''));
  },
  getActiveAnnouncements() {
    return this.request('/announcements/active');
  },
  createAnnouncement(body) {
    return this.request('/announcements/create', { method: 'POST', body });
  },
  updateAnnouncement(id, body) {
    return this.request('/announcements/' + encodeURIComponent(id), {
      method: 'PATCH',
      body,
    });
  },
  deactivateAnnouncement(id) {
    return this.request('/announcements/' + encodeURIComponent(id), {
      method: 'DELETE',
    });
  },
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
  listUsers(params = {}) {
    const q = new URLSearchParams(params).toString();
    return this.request('/users' + (q ? '?' + q : ''));
  },
  listLeases(params = {}) {
    const q = new URLSearchParams(params).toString();
    return this.request('/leases' + (q ? '?' + q : '')).catch(() => this.request('/leases/me'));
  },
  listLeasesAdmin(params = {}) {
    const q = new URLSearchParams();
    Object.entries(params || {}).forEach(([k, v]) => {
      if (v !== undefined && v !== null && v !== '') q.set(k, v);
    });
    const qs = q.toString();
    return this.request('/leases/admin' + (qs ? '?' + qs : ''));
  },
  listAllUnits(params = {}) {
    const q = new URLSearchParams(params).toString();
    return this.request('/units/my' + (q ? '?' + q : '')).catch(() =>
      this.request('/units/available')
    );
  },
  listApplicationsAdmin(params = {}) {
    const q = new URLSearchParams(params).toString();
    return this.request('/applications/admin' + (q ? '?' + q : ''));
  },
  getHistory() {
    return this.request('/history');
  },
  getPartnerAnalytics() {
    return this.request('/partners/me/analytics');
  },
  getPlatformAnalytics() {
    return this.request('/platform/analytics');
  },
  getRevenueMetrics(params = {}) {
    const q = new URLSearchParams();
    Object.entries(params || {}).forEach(([k, v]) => {
      if (v !== undefined && v !== null && v !== '') q.set(k, v);
    });
    const qs = q.toString();
    return this.request('/metrics/revenue' + (qs ? '?' + qs : ''));
  },
  getApplicationFeeSettings(params = {}) {
    const q = new URLSearchParams();
    Object.entries(params || {}).forEach(([k, v]) => {
      if (v !== undefined && v !== null && v !== '') q.set(k, v);
    });
    const qs = q.toString();
    return this.request('/settings/application-fee' + (qs ? '?' + qs : ''));
  },
  updateApplicationFeeSettings(body) {
    return this.request('/settings/application-fee', { method: 'PUT', body });
  },

  // —— Email (Resend) ——
  sendEmail({ to, subject, html, text, tags }) {
    return this.request('/emails/send', {
      method: 'POST',
      body: { to, subject, html, text, tags },
    });
  },
  sendEmailCampaign({ subject, html, text, role, partnerId, limit }) {
    const body = { subject, html };
    if (text) body.text = text;
    if (role) body.role = role;
    if (partnerId) body.partnerId = partnerId;
    if (limit != null) body.limit = limit;
    return this.request('/emails/campaign', { method: 'POST', body });
  },
  resendWelcomeEmail(userId) {
    return this.request('/emails/welcome', { method: 'POST', body: { userId } });
  },
};

window.NeztMateApi = Api;
