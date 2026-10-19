// Injected into the Dashboard pages: highlight box with dimmed surroundings, and a visible cursor.
(() => {
  if (window.top !== window) return;
  const CSS = `
  #__ov_root{position:fixed;inset:0;pointer-events:none;z-index:2147483647}
  #__ov_hl{position:absolute;display:none;border:4px solid #7588FB;border-radius:8px;box-shadow:0 0 0 9999px rgba(6,6,13,.45),0 0 0 10px rgba(117,136,251,.28);transition:all .45s ease}
  #__ov_cursor{position:absolute;left:960px;top:400px;width:30px;height:30px;display:none;transition:left .75s cubic-bezier(.4,.1,.2,1),top .75s cubic-bezier(.4,.1,.2,1)}
  #__ov_cursor svg{filter:drop-shadow(0 2px 3px rgba(0,0,0,.45))}
  #__ov_ripple{position:absolute;width:56px;height:56px;margin:-28px 0 0 -28px;border-radius:50%;border:4px solid #7588FB;opacity:0}
  #__ov_ripple.go{animation:__ovr .6s ease-out}
  @keyframes __ovr{0%{transform:scale(.3);opacity:1}100%{transform:scale(1.4);opacity:0}}`;
  function build() {
    if (document.getElementById('__ov_root') || !document.documentElement) return;
    const r = document.createElement('div'); r.id = '__ov_root';
    r.innerHTML = `<style>${CSS}</style><div id="__ov_hl"></div>
      <div id="__ov_cursor"><svg width="30" height="30" viewBox="0 0 24 24"><path d="M3 2 L3 20 L8 15.5 L11.5 23 L14.5 21.6 L11 14.4 L18 14.4 Z" fill="#fff" stroke="#06060D" stroke-width="1.6" stroke-linejoin="round"/></svg></div>
      <div id="__ov_ripple"></div>`;
    document.documentElement.appendChild(r);
  }
  const $ = id => document.getElementById(id);
  window.__ov = {
    set() { build(); },
    hl(b, pad) { build(); const h = $('__ov_hl'); if (!b) { h.style.display = 'none'; return; } pad = pad ?? 8;
      h.style.display = 'block'; h.style.left = (b.x - pad) + 'px'; h.style.top = (b.y - pad) + 'px'; h.style.width = (b.width + 2 * pad) + 'px'; h.style.height = (b.height + 2 * pad) + 'px'; },
    cursor(x, y, show = true) { build(); const c = $('__ov_cursor'); c.style.display = show ? 'block' : 'none'; c.style.left = x + 'px'; c.style.top = y + 'px'; },
    ripple() { const c = $('__ov_cursor'), r = $('__ov_ripple'); r.style.left = (parseFloat(c.style.left) + 4) + 'px'; r.style.top = (parseFloat(c.style.top) + 4) + 'px'; r.classList.remove('go'); void r.offsetWidth; r.classList.add('go'); },
    boxOf(text, minW) {
      const all = [...document.querySelectorAll('body *')].filter(e => e.offsetParent !== null && !e.closest('#__ov_root'));
      const eq = text.startsWith('/') ? (t => new RegExp(text.slice(1, -1)).test(t)) : (t => t === text);
      let el = all.find(e => [...e.childNodes].some(n => n.nodeType === 3 && eq(n.textContent.trim()))) || all.find(e => eq(e.textContent.trim()));
      if (!el) return null;
      let cur = el;
      while (cur && cur !== document.body) {
        const cs = getComputedStyle(cur), r = cur.getBoundingClientRect();
        const bordered = (parseFloat(cs.borderTopWidth) > 0 && cs.borderTopStyle !== 'none' && cs.borderTopColor !== 'rgba(0, 0, 0, 0)') || (cs.boxShadow && cs.boxShadow !== 'none');
        if (bordered && r.width >= (minW || 200) && r.height > 40) { cur.scrollIntoView({ block: 'center' }); const b = cur.getBoundingClientRect(); return { x: b.x, y: b.y, width: b.width, height: b.height }; }
        cur = cur.parentElement;
      }
      return null;
    }
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', build); else build();
})();
