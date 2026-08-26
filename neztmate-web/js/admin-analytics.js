(function () {
  if (!AdminGuard.requireAuth()) return;

  const isPlatform = NeztMateApi.isPlatformAdmin();
  const errEl = document.getElementById('error');
  const infoEl = document.getElementById('info');
  const kpiGrid = document.getElementById('kpi-grid');
  const chartBars = document.getElementById('chart-bars');
  const breakdown = document.getElementById('breakdown-list');
  const helpText = document.getElementById('help-text');

  document.getElementById('page-title').textContent = isPlatform
    ? 'Platform analysis'
    : 'Partner analysis';
  document.getElementById('page-sub').textContent = isPlatform
    ? 'Cross-partner health: partners, requests, subscriptions, and volume signals.'
    : 'Your workspace: properties, money movement, occupancy signals, and engagement.';
  document.getElementById('chart-title').textContent = isPlatform
    ? 'Partners overview'
    : 'Payments mix';
  helpText.innerHTML = isPlatform
    ? 'Platform view aggregates partner workspaces. Figures come from admin APIs when available; otherwise safe counts from list endpoints.'
    : 'Partner view is scoped by your JWT <code>partnerId</code>. Use this to spot empty inventory, unpaid volume, and support load.';

  document.getElementById('refresh-btn').onclick = () => load();

  function money(n) {
    return typeof n === 'number'
      ? '₦' + n.toLocaleString('en-NG', { maximumFractionDigits: 0 })
      : '—';
  }

  function kpi(label, value, sub) {
    return (
      '<div class="kpi"><label>' +
      label +
      '</label><strong>' +
      value +
      '</strong>' +
      (sub ? '<div class="muted" style="font-size:.75rem;margin-top:.25rem">' + sub + '</div>' : '') +
      '</div>'
    );
  }

  function renderBars(items) {
    if (!items.length) {
      chartBars.innerHTML = '<div class="empty-state" style="width:100%">No chart data</div>';
      return;
    }
    const max = Math.max(...items.map((i) => i.value), 1);
    chartBars.innerHTML = items
      .map((i) => {
        const h = Math.max(6, Math.round((i.value / max) * 120));
        return (
          '<div class="bar-wrap"><div class="bar" style="height:' +
          h +
          'px" title="' +
          i.label +
          ': ' +
          i.value +
          '"></div><div class="bar-label">' +
          i.label +
          '</div></div>'
        );
      })
      .join('');
  }

  function renderBreakdown(rows) {
    breakdown.innerHTML = rows
      .map(
        (r) =>
          '<li><span>' + r.label + '</span><strong>' + r.value + '</strong></li>'
      )
      .join('');
  }

  async function safe(fn, fallback) {
    try {
      return await fn();
    } catch {
      return fallback;
    }
  }

  async function loadPartnerAnalytics() {
    const summary = await safe(() => NeztMateApi.getPaymentSummary(), null);
    const s = summary?.summary || summary || {};

    const propsRes = await safe(() => NeztMateApi.getMyProperties(), { properties: [] });
    const properties = propsRes.properties || propsRes || [];
    const propCount = Array.isArray(properties) ? properties.length : 0;

    const payRes = await safe(() => NeztMateApi.getMyPayments(), { payments: [] });
    const payments = payRes.payments || [];
    const paid = payments.filter((p) => String(p.status || '').toLowerCase() === 'paid');
    const pending = payments.filter((p) =>
      String(p.status || '').toLowerCase().includes('pending')
    );

    const byType = {};
    for (const p of paid) {
      const t = p.type || 'other';
      byType[t] = (byType[t] || 0) + (Number(p.amount) || 0);
    }

    const notifRes = await safe(() => NeztMateApi.getNotifications(), { notifications: [] });
    const notifications = notifRes.notifications || [];

    const analytics = await safe(() => NeztMateApi.getPartnerAnalytics(), null);

    const totalUnits =
      analytics?.totalUnits ??
      properties.reduce((acc, p) => acc + (Number(p.totalUnits) || 0), 0);
    const activeLeases = analytics?.activeLeases ?? analytics?.totalActiveLeases ?? '—';
    const applications = analytics?.pendingApplications ?? analytics?.applications ?? '—';
    const maintenanceOpen = analytics?.openMaintenance ?? analytics?.maintenanceRequests ?? '—';

    kpiGrid.innerHTML = [
      kpi('Properties', propCount, 'In your workspace'),
      kpi('Units (listed total)', totalUnits === '—' ? '—' : totalUnits, 'From properties / analytics'),
      kpi('Received', money(s.totalReceived), 'Paid in'),
      kpi('Withdrawable', money(s.withdrawableAmount), 'Available balance signal'),
      kpi('Paid txs', paid.length, pending.length + ' pending'),
      kpi('Active leases', activeLeases, 'If analytics API present'),
      kpi('Applications', applications, 'Pending / total when available'),
      kpi('Notifications', notifications.length, 'Recent inbox size'),
    ].join('');

    const barItems = Object.keys(byType).length
      ? Object.entries(byType).map(([label, value]) => ({
          label: label.slice(0, 10),
          value: value,
        }))
      : [
          { label: 'Received', value: Number(s.totalReceived) || 0 },
          { label: 'Paid out', value: Number(s.totalPaid) || 0 },
          { label: 'Withdrawn', value: Number(s.totalWithdrawn) || 0 },
        ];
    renderBars(barItems);

    renderBreakdown([
      { label: 'Total received', value: money(s.totalReceived) },
      { label: 'Total paid (outflow)', value: money(s.totalPaid) },
      { label: 'Total withdrawn', value: money(s.totalWithdrawn) },
      { label: 'Pending payments', value: pending.length },
      { label: 'Maintenance open', value: maintenanceOpen },
      { label: 'Subscription', value: analytics?.subscriptionPlan || 'see /subscriptions/me' },
    ]);

    if (!analytics) {
      infoEl.style.display = 'block';
      infoEl.textContent =
        'Showing derived metrics from properties/payments/notifications. Deploy GET /partners/me/analytics for lease & application counts.';
    }
  }

  async function loadPlatformAnalytics() {
    const partnersRes = await safe(() => NeztMateApi.listPartners(), { partners: [] });
    const partners = partnersRes.partners || partnersRes || [];
    const active = partners.filter((p) => p.isActive !== false);
    const inactive = partners.filter((p) => p.isActive === false);

    const reqRes = await safe(() => NeztMateApi.listPartnerRequests(), { requests: [] });
    const requests = reqRes.requests || reqRes || [];
    const pendingReq = requests.filter((r) => String(r.status || '').toLowerCase() === 'pending');
    const approvedReq = requests.filter((r) => String(r.status || '').toLowerCase() === 'approved');

    const platform = await safe(() => NeztMateApi.getPlatformAnalytics(), null);

    kpiGrid.innerHTML = [
      kpi('Partners', partners.length, active.length + ' active'),
      kpi('Inactive partners', inactive.length, 'Suspended / off'),
      kpi('Partner requests', requests.length, pendingReq.length + ' pending'),
      kpi('Approved requests', approvedReq.length, 'Pipeline conversions'),
      kpi('Users', platform?.totalUsers ?? '—', 'Platform analytics API'),
      kpi('Properties', platform?.totalProperties ?? '—', 'All workspaces'),
      kpi('Active leases', platform?.activeLeases ?? '—', 'Cross-partner'),
      kpi('GMV (paid)', money(platform?.totalPaymentsVolume), 'Sum of paid volume'),
    ].join('');

    const barItems = [
      { label: 'Active', value: active.length },
      { label: 'Inactive', value: inactive.length },
      { label: 'Pending RQ', value: pendingReq.length },
      { label: 'Approved', value: approvedReq.length },
    ];
    renderBars(barItems);

    const topPartners = [...partners]
      .sort((a, b) => String(a.name || '').localeCompare(String(b.name || '')))
      .slice(0, 8)
      .map((p) => ({
        label: (p.name || p.slug || p.id) + (p.isActive === false ? ' (off)' : ''),
        value: p.slug || p.id || '—',
      }));

    renderBreakdown([
      ...topPartners.map((p) => ({ label: p.label, value: p.value })),
      {
        label: 'Open partner requests',
        value: pendingReq.length,
      },
      {
        label: 'Subscriptions (active)',
        value: platform?.activeSubscriptions ?? '—',
      },
    ]);

    if (!platform) {
      infoEl.style.display = 'block';
      infoEl.textContent =
        'Partner counts loaded from GET /partners/. Deploy GET /platform/analytics for users, leases, and GMV.';
    }
  }

  async function load() {
    errEl.style.display = 'none';
    infoEl.style.display = 'none';
    kpiGrid.innerHTML = '<div class="kpi"><label>Loading</label><strong>…</strong></div>';
    try {
      if (isPlatform) await loadPlatformAnalytics();
      else await loadPartnerAnalytics();
    } catch (e) {
      errEl.style.display = 'block';
      errEl.textContent = e.message || 'Failed to load analytics';
      if (e.status === 401 || e.status === 403) setTimeout(() => AdminGuard.logout(), 1200);
    }
  }

  load();
})();
