/** Default NeztMate logo when partner.logoUrl is empty/null */
function neztmateDefaultLogoUrl() {
  try {
    var path = location.pathname || '';
    if (path.indexOf('/admin') >= 0 || path.indexOf('/u/') >= 0) {
      return '../assets/logo_bg.png';
    }
    if (location.origin && location.protocol !== 'file:') {
      return location.origin + '/assets/logo_bg.png';
    }
  } catch (e) {}
  return 'assets/logo_bg.png';
}

/** Resolve partner logo or fall back to NeztMate asset */
function neztmateResolveLogoUrl(partner) {
  var raw =
    (partner && (partner.logoUrl || partner.logo_url || partner.logo)) || null;
  if (raw != null && String(raw).trim() !== '') {
    return String(raw).trim();
  }
  return neztmateDefaultLogoUrl();
}

/** Apply partner branding across the document */
window.NeztMateTheme = {
  defaultLogoUrl: neztmateDefaultLogoUrl,

  resolveLogoUrl: neztmateResolveLogoUrl,

  apply(partner, options) {
    if (!partner) return;
    const opts = options || {};
    const root = document.documentElement;
    const primary = partner.primaryColor || partner.primary_color || '#0d9488';
    const secondary = partner.secondaryColor || partner.secondary_color || primary;
    const name = partner.name || partner.displayName || 'NeztMate';
    const tagline = partner.tagline || partner.description || '';
    const logoUrl = neztmateResolveLogoUrl(partner);
    const supportEmail =
      partner.supportEmail || partner.support_email || 'support@neztmate.com';
    const isPartnerHosted =
      opts.isPartnerHosted === true ||
      (partner.slug && String(partner.slug).toLowerCase() !== 'neztmate');

    root.style.setProperty('--teal', primary);
    root.style.setProperty('--teal-dark', secondary);
    root.style.setProperty('--teal-soft', this._soft(primary));

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
      // Keep existing logo mark if present; only update text nodes / spans
      const mark = el.querySelector('img.logo-mark, img[data-brand-logo]');
      const parts = String(name).trim().split(/\s+/);
      let html;
      if (parts.length > 1) {
        const last = parts.pop();
        html = parts.join(' ') + ' <span>' + last + '</span>';
      } else {
        html = name.replace(/Mate$/i, '<span>Mate</span>');
        if (!html.includes('<span>')) html = name;
      }
      if (mark) {
        // Re-apply text after the logo image
        const rest = document.createElement('span');
        rest.className = 'logo-text';
        rest.innerHTML = html;
        el.innerHTML = '';
        el.appendChild(mark);
        el.appendChild(rest);
      } else {
        el.innerHTML = html;
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

    // Always set logo: partner logoUrl when present, else NeztMate default
    this._applyLogos(logoUrl, name);

    // Prefer partner name + tagline in title, keep app identity
    const baseTitle = name + (tagline ? ' — ' + tagline : ' — Property app');
    if (document.title.indexOf('Listings') >= 0) {
      document.title = 'Listings · ' + name;
    } else if (!opts.skipTitle) {
      document.title = baseTitle;
    }

    const pill = document.getElementById('partner-pill');
    if (pill) {
      if (isPartnerHosted) {
        pill.textContent = name;
        pill.classList.add('show');
      } else {
        pill.classList.remove('show');
      }
    }
  },

  _applyLogos(logoUrl, name) {
    const src = logoUrl || neztmateDefaultLogoUrl();

    document.querySelectorAll('[data-brand-logo]').forEach((el) => {
      if (el.tagName === 'IMG') {
        el.src = src;
        el.alt = name || 'NeztMate';
        el.hidden = false;
        el.style.display = '';
      } else if (el.tagName === 'A' || el.tagName === 'DIV' || el.tagName === 'SPAN') {
        let img = el.querySelector('img');
        if (!img) {
          img = document.createElement('img');
          el.insertBefore(img, el.firstChild);
        }
        img.src = src;
        img.alt = name || 'NeztMate';
        img.classList.add('logo-mark');
        img.setAttribute('data-brand-logo', '');
      }
    });

    // Inject / update logo mark on every .logo link (header + footer)
    document.querySelectorAll('a.logo, .logo[data-brand-name-html]').forEach((el) => {
      let img = el.querySelector('img.logo-mark, img[data-brand-logo]');
      if (!img) {
        img = document.createElement('img');
        img.className = 'logo-mark';
        img.setAttribute('data-brand-logo', '');
        img.setAttribute(
          'style',
          'height:32px;width:32px;object-fit:contain;border-radius:8px;flex-shrink:0;display:block'
        );
        el.insertBefore(img, el.firstChild);
        if (getComputedStyle(el).display === 'inline') {
          el.style.display = 'inline-flex';
        }
        el.style.alignItems = 'center';
        el.style.gap = '0.5rem';
      }
      img.src = src;
      img.alt = name || 'NeztMate';
      img.hidden = false;
      img.style.display = 'block';
    });
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
      return 'rgba(13, 148, 136, 0.14)';
    }
  },
};

/** Favicon always uses NeztMate logo (not partner-specific) */
(function ensureNeztMateFavicon() {
  try {
    var path = neztmateDefaultLogoUrl();
    function setLink(rel, sizes) {
      var el = document.querySelector('link[rel="' + rel + '"]');
      if (!el) {
        el = document.createElement('link');
        el.rel = rel;
        document.head.appendChild(el);
      }
      el.type = 'image/png';
      el.href = path;
      if (sizes) el.sizes = sizes;
    }
    setLink('icon', '32x32');
    setLink('icon', '192x192');
    setLink('apple-touch-icon');
  } catch (e) {}
})();

/** On load, if no partner applied yet, still show default logo marks */
(function ensureDefaultLogosOnLoad() {
  function run() {
    try {
      if (window.NeztMateTheme && NeztMateTheme._applyLogos) {
        NeztMateTheme._applyLogos(neztmateDefaultLogoUrl(), 'NeztMate');
      }
    } catch (e) {}
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', run);
  } else {
    run();
  }
})();
