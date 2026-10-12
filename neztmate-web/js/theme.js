/**
 * NeztMate default logo paths (root-relative so they work from any page).
 * neztmate_logo.jpg = white background (good in light headers)
 * logo_bg.png = dark background mark / favicon fallback
 */
function neztmateDefaultLogoUrl() {
  return '/assets/neztmate_logo.jpg';
}

function neztmateFaviconUrl() {
  return '/assets/logo_bg.png';
}

/** Partner logo if valid URL; otherwise NeztMate default */
function neztmateResolveLogoUrl(partner) {
  var raw =
    (partner && (partner.logoUrl || partner.logo_url || partner.logo)) || null;
  if (raw == null) return neztmateDefaultLogoUrl();
  var s = String(raw).trim();
  if (!s || s === 'null' || s === 'undefined') return neztmateDefaultLogoUrl();
  return s;
}

/** WhatsApp link from whatsappUrl, or built from supportPhone */
function neztmateResolveWhatsappUrl(partner) {
  if (!partner) return null;
  var raw = partner.whatsappUrl || partner.whatsapp_url || null;
  if (raw != null && String(raw).trim() !== '' && String(raw).trim() !== 'null') {
    var s = String(raw).trim();
    if (/^https?:\/\//i.test(s)) return s;
    if (/^wa\.me\//i.test(s) || /^api\.whatsapp\.com/i.test(s)) return 'https://' + s.replace(/^\/+/, '');
    var digitsFromUrl = s.replace(/\D/g, '');
    if (digitsFromUrl.length >= 8) return 'https://wa.me/' + digitsFromUrl;
    return s;
  }
  var phone = partner.supportPhone || partner.support_phone || null;
  if (phone != null && String(phone).trim() !== '') {
    var digits = String(phone).replace(/\D/g, '');
    if (digits.length >= 8) return 'https://wa.me/' + digits;
  }
  return null;
}

function neztmateBindLogoError(img) {
  if (!img || img._neztmateLogoBound) return;
  img._neztmateLogoBound = true;
  img.addEventListener('error', function onLogoErr() {
    img.removeEventListener('error', onLogoErr);
    var cur = img.getAttribute('src') || '';
    var fallback = neztmateDefaultLogoUrl();
    var alt = neztmateFaviconUrl();
    if (cur.indexOf('neztmate_logo') >= 0 || cur === fallback) {
      img.src = alt;
      return;
    }
    if (cur.indexOf('logo_bg') >= 0) {
      img.style.display = 'none';
      return;
    }
    img.src = fallback;
  });
}

/** Apply partner branding across the document */
window.NeztMateTheme = {
  defaultLogoUrl: neztmateDefaultLogoUrl,
  resolveLogoUrl: neztmateResolveLogoUrl,
  resolveWhatsappUrl: neztmateResolveWhatsappUrl,

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
    const whatsappUrl = neztmateResolveWhatsappUrl(partner);
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

    document.querySelectorAll('[data-brand-name]').forEach(function (el) {
      el.textContent = name;
    });

    document.querySelectorAll('[data-brand-name-html]').forEach(function (el) {
      var parts = String(name).trim().split(/\s+/);
      var html;
      if (parts.length > 1) {
        var last = parts.pop();
        html = parts.join(' ') + ' <span>' + last + '</span>';
      } else {
        html = name.replace(/Mate$/i, '<span>Mate</span>');
        if (html.indexOf('<span>') < 0) html = name;
      }
      var mark = el.querySelector('img.logo-mark, img[data-brand-logo]');
      var textEl = el.querySelector('.logo-text');
      if (mark) {
        if (!textEl) {
          textEl = document.createElement('span');
          textEl.className = 'logo-text';
          el.appendChild(textEl);
        }
        textEl.innerHTML = html;
        Array.prototype.slice.call(el.childNodes).forEach(function (n) {
          if (n !== mark && n !== textEl && n.nodeType === 3) {
            el.removeChild(n);
          }
        });
      } else {
        el.innerHTML = html;
      }
    });

    document.querySelectorAll('[data-brand-tagline]').forEach(function (el) {
      if (tagline) el.textContent = tagline;
    });

    // Support email from partner config
    document.querySelectorAll('[data-brand-support]').forEach(function (el) {
      if (el.tagName === 'A') {
        el.href = 'mailto:' + supportEmail;
        el.textContent = supportEmail;
      } else {
        el.textContent = supportEmail;
      }
    });

    // WhatsApp from partner config (whatsappUrl or supportPhone → wa.me)
    document.querySelectorAll('[data-brand-whatsapp]').forEach(function (el) {
      if (!whatsappUrl) {
        el.style.display = 'none';
        el.setAttribute('href', '#');
        return;
      }
      el.style.display = '';
      if (el.tagName === 'A') {
        el.href = whatsappUrl;
        el.target = '_blank';
        el.rel = 'noopener noreferrer';
        if (!el.getAttribute('data-keep-label')) {
          el.textContent = el.getAttribute('data-whatsapp-label') || 'Chat on WhatsApp';
        }
      }
    });
    document.querySelectorAll('[data-brand-whatsapp-wrap]').forEach(function (el) {
      el.style.display = whatsappUrl ? '' : 'none';
    });

    this._applyLogos(logoUrl, name);

    if (!opts.skipTitle) {
      if (document.title.indexOf('Listings') >= 0) {
        document.title = 'Listings · ' + name;
      } else {
        document.title = name + (tagline ? ' — ' + tagline : ' — Property app');
      }
    }

    var pill = document.getElementById('partner-pill');
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
    var src = logoUrl || neztmateDefaultLogoUrl();
    var alt = name || 'NeztMate';

    function styleMark(img) {
      img.classList.add('logo-mark');
      img.setAttribute('data-brand-logo', '');
      img.alt = alt;
      img.width = 32;
      img.height = 32;
      img.style.height = '32px';
      img.style.width = '32px';
      img.style.objectFit = 'contain';
      img.style.borderRadius = '8px';
      img.style.flexShrink = '0';
      img.style.display = 'block';
      img.hidden = false;
      neztmateBindLogoError(img);
      if (img.getAttribute('src') !== src) img.src = src;
    }

    document.querySelectorAll('[data-brand-logo]').forEach(function (el) {
      if (el.tagName === 'IMG') {
        styleMark(el);
      }
    });

    document.querySelectorAll('a.logo').forEach(function (el) {
      var img = el.querySelector('img.logo-mark, img[data-brand-logo]');
      if (!img) {
        img = document.createElement('img');
        img.className = 'logo-mark';
        img.setAttribute('data-brand-logo', '');
        el.insertBefore(img, el.firstChild);
      }
      styleMark(img);
      el.style.display = 'inline-flex';
      el.style.alignItems = 'center';
      el.style.gap = '0.5rem';
      el.style.textDecoration = 'none';
    });
  },

  _soft(hex) {
    try {
      var c = hex.replace('#', '');
      var full = c.length === 3 ? c.split('').map(function (x) { return x + x; }).join('') : c;
      var n = parseInt(full, 16);
      var r = (n >> 16) & 255;
      var g = (n >> 8) & 255;
      var b = n & 255;
      return 'rgba(' + r + ',' + g + ',' + b + ',0.14)';
    } catch (e) {
      return 'rgba(13, 148, 136, 0.14)';
    }
  },
};

/** Favicon: NeztMate mark */
(function ensureNeztMateFavicon() {
  try {
    var path = neztmateFaviconUrl();
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

/** Show default logo marks as soon as DOM is ready */
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
