/** Injects consistent sidebar into #sidebar */
const AdminShell = {
  mount(activePage) {
    const el = document.getElementById('sidebar');
    if (!el) return;
    const isP = NeztMateApi.isPlatformAdmin();
    el.innerHTML = `
      <a class="logo" href="index.html">Nezt<span>Mate</span></a>
      <div class="nav-section">Workspace</div>
      <nav>
        <a href="index.html">Dashboard</a>
        <a href="analytics.html">Analytics</a>
        <a href="properties.html" data-partner-only>Properties</a>
        <a href="units.html" data-partner-only>Units</a>
        <a href="leases.html">Leases</a>
        <a href="applications.html" data-partner-only>Applications</a>
        <a href="payments.html">Payments</a>
        <a href="users.html">Users</a>
        <a href="notifications.html">Notifications</a>
        <a href="branding.html" data-partner-only>Branding</a>
        <a href="settings.html">Settings</a>
      </nav>
      <div class="nav-section" data-platform-only>Platform</div>
      <nav data-platform-only>
        <a href="partners-list.html">Partners</a>
        <a href="partner-requests.html">Partner requests</a>
        <a href="partner-create.html">Create partner</a>
      </nav>
      <nav style="margin-top:1rem">
        <a href="#" id="logout-link">Sign out</a>
      </nav>
      <div class="side-foot">
        <span id="side-user">Signed in</span><br/>
        <span id="role-badge" class="badge badge-soft" style="margin-top:.35rem;display:inline-block">Admin</span>
      </div>
    `;
    // re-bind after inject
    if (window.AdminGuard) {
      AdminGuard.paintUser();
      AdminGuard.bindLogout();
      AdminGuard.paintNav();
      if (activePage) {
        el.querySelectorAll('nav a[href]').forEach((a) => {
          if (a.getAttribute('href') === activePage) a.classList.add('active');
        });
      }
    }
  },
};
window.AdminShell = AdminShell;
