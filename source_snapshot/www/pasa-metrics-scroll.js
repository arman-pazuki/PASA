(function () {
  'use strict';
  const states = new Map();
  let observedRoot = null;
  let mutationObserver = null;
  let frame = 0;
  let serial = 0;
  const reducedMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function schedule() {
    if (!frame) frame = window.requestAnimationFrame(refresh);
  }

  function move(state, amount, absolute) {
    const left = absolute ? amount : state.viewport.scrollLeft + amount;
    state.viewport.scrollTo({ left: left, behavior: reducedMotion() ? 'auto' : 'smooth' });
  }

  function keyPan(event, state) {
    const step = Math.max(120, state.viewport.clientWidth * 0.7);
    if (event.key === 'ArrowLeft') move(state, -step);
    else if (event.key === 'ArrowRight') move(state, step);
    else if (event.key === 'Home') move(state, 0, true);
    else if (event.key === 'End') move(state, state.viewport.scrollWidth, true);
    else return;
    event.preventDefault();
  }

  function addTable(table, root) {
    let viewport = table.parentElement;
    // gt normally supplies an overflow container. Preserve it and its native
    // bottom scrollbar. Fall back to a local viewport for simplified layouts.
    while (viewport && viewport !== root) {
      const overflow = window.getComputedStyle(viewport).overflowX;
      if ((overflow === 'auto' || overflow === 'scroll') && viewport.querySelectorAll('table.gt_table').length === 1) break;
      viewport = viewport.parentElement;
    }
    if (!viewport || viewport === root) {
      viewport = document.createElement('div');
      table.parentNode.insertBefore(viewport, table);
      viewport.appendChild(table);
    }
    const host = document.createElement('div');
    host.className = 'pasa-metrics-scroll-host';
    viewport.parentNode.insertBefore(host, viewport);
    host.appendChild(viewport);
    viewport.classList.add('pasa-metrics-scroll-viewport');
    const id = 'pasa-metrics-viewport-' + (++serial);
    if (!viewport.id) viewport.id = id;
    if (!viewport.hasAttribute('tabindex')) viewport.tabIndex = 0;
    viewport.setAttribute('role', 'region');
    const title = table.querySelector('.gt_title');
    const name = title ? title.textContent.trim() : 'Metrics table';
    viewport.setAttribute('aria-label', name + '. Scroll horizontally to inspect more columns.');

    const top = document.createElement('div');
    top.className = 'pasa-metrics-scroll-tools';
    top.tabIndex = 0;
    top.setAttribute('role', 'region');
    top.setAttribute('aria-label', 'Horizontal scrollbar above ' + name);
    top.setAttribute('aria-controls', viewport.id);
    top.title = 'Scroll horizontally; Arrow keys move, Home and End jump to either edge.';
    // A visible native range thumb works even when OS scrollbars are overlays.
    const track = document.createElement('input');
    track.type = 'range'; track.min = '0'; track.max = '0'; track.step = '1'; track.value = '0';
    track.className = 'pasa-metrics-scroll-track';
    track.setAttribute('aria-label','Horizontal position in '+name);
    track.setAttribute('aria-controls',viewport.id);
    top.removeAttribute('tabindex');
    top.appendChild(track);
    host.insertBefore(top, viewport);

    function button(direction, glyph) {
      const node = document.createElement('button');
      node.type = 'button';
      node.className = 'pasa-metrics-pan pasa-metrics-pan-' + direction;
      node.setAttribute('aria-label', 'Scroll ' + name + ' ' + direction);
      node.setAttribute('aria-controls', viewport.id);
      node.title = 'Scroll table ' + direction;
      node.textContent = glyph;
      host.appendChild(node);
      return node;
    }
    const left = button('left', '\u2039');
    const right = button('right', '\u203a');
    const state = { table, host, viewport, top, track, left, right };
    track.addEventListener('input',()=>{viewport.scrollLeft=Number(track.value);schedule();});
    viewport.addEventListener('scroll',()=>{track.value=String(viewport.scrollLeft);schedule();},{passive:true});
    top.addEventListener('keydown', event => keyPan(event, state));
    viewport.addEventListener('keydown', event => {
      if (event.target === viewport) keyPan(event, state);
    });
    left.addEventListener('click', () => move(state, -Math.max(120, viewport.clientWidth * 0.7)));
    right.addEventListener('click', () => move(state, Math.max(120, viewport.clientWidth * 0.7)));
    if (window.ResizeObserver) {
      state.resize = new ResizeObserver(schedule);
      state.resize.observe(viewport);
      state.resize.observe(table);
    }
    states.set(table, state);
  }

  function refresh() {
    frame = 0;
    const root = document.getElementById('metrics_ui');
    if (root && root !== observedRoot) {
      if (mutationObserver) mutationObserver.disconnect();
      observedRoot = root;
      mutationObserver = new MutationObserver(schedule);
      mutationObserver.observe(root, { childList: true, subtree: true, characterData: true });
    }
    if (root) root.querySelectorAll('table.gt_table').forEach(table => {
      if (!states.has(table)) addTable(table, root);
    });
    states.forEach((state, table) => {
      if (!table.isConnected) {
        if (state.resize) state.resize.disconnect();
        states.delete(table);
        return;
      }
      const { viewport, top, track, host, left, right } = state;
      const visible = viewport.getClientRects().length > 0 && viewport.clientWidth > 0;
      const maximum = Math.max(0, viewport.scrollWidth - viewport.clientWidth);
      const overflow = visible && maximum > 2;
      top.hidden = !overflow;
      track.max = String(maximum); track.value = String(viewport.scrollLeft);
      track.setAttribute('aria-valuetext',Math.round(maximum?viewport.scrollLeft/maximum*100:0)+'% across table');
      left.disabled = viewport.scrollLeft <= 1;
      right.disabled = viewport.scrollLeft >= maximum - 1;
      left.setAttribute('aria-disabled', String(left.disabled));
      right.setAttribute('aria-disabled', String(right.disabled));
      const bounds = viewport.getBoundingClientRect();
      const hostBounds = host.getBoundingClientRect();
      const header = parseFloat(window.getComputedStyle(document.documentElement).getPropertyValue('--pasa-header-height')) || 64;
      const visibleTop = Math.max(bounds.top, header + 22);
      const visibleBottom = Math.min(bounds.bottom, window.innerHeight - 18);
      const arrowsVisible = overflow && visibleBottom - visibleTop > 52;
      left.hidden = right.hidden = !arrowsVisible;
      if (arrowsVisible) {
        const y = (visibleTop + visibleBottom) / 2 - hostBounds.top;
        left.style.top = right.style.top = y + 'px';
      }
    });
  }

  function start() {
    if (window.jQuery) window.jQuery(document).on('shiny:value.pasaMetrics shiny:connected.pasaMetrics shown.bs.tab.pasaMetrics', schedule);
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(schedule);
    schedule();
  }
  window.addEventListener('resize', schedule, { passive: true });
  document.addEventListener('scroll', schedule, { passive: true, capture: true });
  document.addEventListener('shown.bs.tab', schedule);
  document.addEventListener('shiny:value', schedule);
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();

(function(){
  'use strict';
  let installed=false;
  const status=value=>{if(window.Shiny&&Shiny.setInputValue)Shiny.setInputValue('copy_metrics_status',value,{priority:'event'});};
  function manualCopy(text){
    let dialog=document.getElementById('pasa-metrics-copy-dialog');
    if(dialog)dialog.remove();
    dialog=document.createElement('dialog');dialog.id='pasa-metrics-copy-dialog';
    const title=document.createElement('h3');title.textContent='Copy the complete metrics table';dialog.append(title);
    const hint=document.createElement('p');hint.textContent='Use Copy text, or select the text and press Ctrl+C (Command+C on Mac).';dialog.append(hint);
    const area=document.createElement('textarea');area.value=text;area.readOnly=true;area.setAttribute('aria-label','Complete metrics table as tab-separated text');dialog.append(area);
    const copy=document.createElement('button');copy.type='button';copy.textContent='Copy text';
    copy.addEventListener('click',()=>{area.focus();area.select();try{if(document.execCommand('copy')){status('ok');dialog.close?dialog.close():dialog.remove();}else status('fail');}catch(_){status('fail');}});
    const close=document.createElement('button');close.type='button';close.textContent='Close';close.addEventListener('click',()=>{dialog.close?dialog.close():dialog.remove();});dialog.append(copy,close);
    document.body.append(dialog);if(dialog.showModal)dialog.showModal();else dialog.setAttribute('open','');area.focus();area.select();status('fail');
  }
  function receive(msg){
    const text=msg&&typeof msg.value==='string'?msg.value:'';
    if(!text){status('empty');return;}
    if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(text).then(()=>status('ok')).catch(()=>manualCopy(text));
    else manualCopy(text);
  }
  function bind(){if(installed)return;if(!window.Shiny||!Shiny.addCustomMessageHandler){setTimeout(bind,50);return;}installed=true;Shiny.addCustomMessageHandler('pasa-copy-metrics',receive);}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',bind);else bind();
})();
