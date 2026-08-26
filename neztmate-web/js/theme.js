/** Apply partner branding across the document */
window.NeztMateTheme = {
  apply(partner) {
    if (!partner) return;
    const root = document.documentElement;
    const primary = partner.primaryColor || partner.primary_color || '#0d9488';
    const secondary = partner.secondaryColor || partner.secondary_color || primary;
    const name = partner.name || partner.displayName || 'NeztMate';
    const tagline = partner.tagline || partner.description || '';
    const logoUrl = partner.logoUrl || partner.logo_url || null;
    const supportEmail = partner.supportEmail || partner.support_email || 'hello@neztmate.com';

    root.style.setProperty('--teal', primary);
    root.style.setProperty('--teal-dark', secondary);
    root.style.setProperty('--teal-soft', this._soft(primary));

    // Meta theme-color
    let meta = document.querySelector('meta[name="theme-color"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'theme-color';
      document.head.appendChild(meta);
    }
    meta.content = primary;

    document.querySelectorAll('[data-brand-name]').forEach((el) => {
      el.textContent = name;
    });
    document.querySelectorAll('[data-brand-name-html]').forEach((el) => {
      // Split last word as accent when possible
      const parts = String(name).trim().split(/\s+/);
      if (parts.length > 1) {
        const last = parts.pop();
        el.innerHTML = parts.join(' ') + ' <span>' + last + '</span>';
      } else {
        el.innerHTML = name.replace(/Mate$/i, '<span>Mate</span>');
        if (!el.innerHTML.includes('<span>')) el.textContent = name;
      }
    });
    document.querySelectorAll('[data-brand-tagline]').forEach((el) => {
      if (tagline) el.textContent = tagline;
    });
    document.querySelectorAll('[data-brand-support]').forEach((el) => {
      if (el.tagName === 'A') {
        el.href = 'mailto:' + supportEmail;
        el.textContent = supportEmail;
      } else el.textContent = supportEmail;
    });
    document.querySelectorAll('[data-brand-logo]').forEach((el) => {
      if (logoUrl) {
        if (el.tagName === 'IMG') {
          el.src = logoUrl;
          el.alt = name;
          el.hidden = false;
        } else {
          el.style.backgroundImage = 'url(' + logoUrl + ')';
        }
      }
    });

    document.title = name + ' — ' + (tagline || 'Property app');
    const pill = document.getElementById('partner-pill');
    if (pill && partner.slug && partner.slug !== 'neztmate') {
      pill.textContent = name;
      pill.classList.add('show');
    }
  },

  _soft(hex) {
    try {
      const c = hex.replace('#', '');
      const full = c.length === 3 ? c.split('').map((x) => x + x).join('') : c;
      const n = parseInt(full, 16);
      const r = (n >> 16) & 255;
      const g = (n >> 8) & 255;
      const b = n & 255;
      return 'rgba(' + r + ',' + g + ',' + b + ',0.14)';
    } catch {
      return '#ccfbf1';
    }
  },
};
