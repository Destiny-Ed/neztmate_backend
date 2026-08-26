const AdminGuard = {
  requireAuth() {
    if (!window.NeztMateApi || !NeztMateApi.getToken()) {
      location.href = 'login.html';
      return false;
    }
    this.paintUser();
    this.bindLogout();
    this.paintNav();
    return true;
  },

  paintUser() {
    const user = NeztMateApi.getUser() || {};
    const el = document.getElementById('side-user');
    const partnerLabel = document.getElementById('partner-label');
    const roleBadge = document.getElementById('role-badge');
    if (el) el.textContent = user.email || user.fullName || 'Signed in';
    if (partnerLabel) {
      partnerLabel.textContent = NeztMateApi.isPlatformAdmin()
        ? '· Platform'
        : user.partnerId
          ? '· ' + user.partnerId
          : '';
    }
    if (roleBadge) {
      roleBadge.textContent = NeztMateApi.isPlatformAdmin() ? 'Platform admin' : 'Partner admin';
    }
  },

  paintNav() {
    const platformOnly = document.querySelectorAll('[data-platform-only]');
    const partnerOnly = document.querySelectorAll('[data-partner-only]');
    const isPlatform = NeztMateApi.isPlatformAdmin();
    platformOnly.forEach((el) => el.classList.toggle('hidden', !isPlatform));
    partnerOnly.forEach((el) => el.classList.toggle('hidden', isPlatform));
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
};
window.AdminGuard = AdminGuard;
