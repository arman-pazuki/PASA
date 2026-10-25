(function () {
  'use strict';
  const titles = {'Data':'Input data','Sample Color':'Sample color','Cell Growth':'Cell growth','About':'About PASA','Welcome':'Welcome to PASA'};
  let nav, rail, toggle, settings, mobile = window.matchMedia('(max-width:650px)');
  function navigate(value) {
    const link = nav && Array.from(nav.querySelectorAll('a[data-value]')).find(a => a.dataset.value === value);
    if (link) link.click();
  }
  function syncTabAccessibility() {
    if (!nav) return;
    nav.querySelectorAll('a[data-value]').forEach(link => {
      const target = link.getAttribute('data-bs-target') || link.getAttribute('data-target') || link.getAttribute('href');
      link.setAttribute('role', 'tab');
      link.setAttribute('aria-selected', String(link.classList.contains('active')));
      if (target && target.startsWith('#') && target.length > 1) link.setAttribute('aria-controls', target.slice(1));
    });
  }
  function updateView() {
    syncTabAccessibility();
    const active = nav && nav.querySelector('a.active[data-value]');
    const value = active ? active.dataset.value : 'Welcome';
    document.body.dataset.pasaView = value;
    const title = document.getElementById('pasa-page-title');
    if (title) title.textContent = titles[value] || value;
    const header = document.getElementById('pasa-workspace-header');
    const analysis = !['Welcome','About','Help','FAQ','References','Feedback'].includes(value);
    if (header) {
      header.querySelectorAll('#pasa_analysis_summary').forEach(el => el.hidden = !analysis || value === 'Data');
      header.querySelectorAll('.pasa-global-status').forEach(el => el.hidden = !analysis);
      header.querySelectorAll('.pasa-settings-toggle').forEach(el => el.hidden = !analysis);
    }
    if (mobile.matches) { document.body.classList.add('pasa-nav-collapsed'); toggle.setAttribute('aria-expanded','false'); }
    window.dispatchEvent(new Event('resize'));
  }
  function syncControls() {
    const ready = !!document.getElementById('analysis_nm');
    document.body.classList.toggle('pasa-has-data',ready);
    document.querySelectorAll('.pasa-requires-data').forEach(el => {
      el.setAttribute('aria-disabled', String(!ready));
      if (!ready) el.setAttribute('title','Load data to enable this download');
      else el.removeAttribute('title');
    });
  }
  function toggleSettings() {
    navigate('Analysis settings');
  }
  // Labels mirror .SIM_BUDGET_TRACE_STOPS; the bound slider still stores 0–5.
  const budgetLabels = ['Maximum (1600)','100','200','400','800','1600'];
  const budgetPrettify = value => budgetLabels[Number(value)] ?? String(value);
  function syncBudgetLabels() {
    if (!window.jQuery) return;
    const slider = window.jQuery('#sim_pair_budget').data('ionRangeSlider');
    if (!slider || slider.options.prettify === budgetPrettify) return;
    slider.update({prettify_enabled:true, prettify:budgetPrettify});
  }
  function orderNavigation() {
    const order=['Welcome','Data','Analysis settings','Summary','Spectra','Metrics','Band AUC','Data Quality','Deconvolution','Sample Color','Cell Growth','About','Help','FAQ','References','Feedback'];
    const items = order.map(value => Array.from(nav.querySelectorAll('a[data-value]')).find(a => a.dataset.value === value)?.parentElement).filter(Boolean);
    const current = Array.from(nav.children).filter(item => items.includes(item));
    if (items.some((item, index) => current[index] !== item)) items.forEach(item => nav.append(item));
  }
  function documentSections(root) {
    if (!root || root.dataset.pasaSections === 'ready' || !root.querySelector('h3,h4')) return;
    const slug = text => text.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'');
    const group = (container, level, prefix) => {
      let body = null, index = 0;
      Array.from(container.childNodes).forEach(node => {
        if (node.nodeType === 1 && node.tagName === 'H' + level) {
          const details = document.createElement('details'); details.className = 'pasa-document-section';
          details.id = prefix + '-' + slug(node.textContent);
          details.open = index++ === 0;
          const summary = document.createElement('summary');
          container.insertBefore(details, node); summary.append(node); details.append(summary);
          body = document.createElement('div'); body.className = 'pasa-document-section-body'; details.append(body);
        } else if (body) body.append(node);
      });
    };
    group(root, 3, root.id);
    // Preserve all original content and bound controls; only wrap section nodes.
    Array.from(root.querySelectorAll('.pasa-document-section-body')).forEach(body => group(body, 4, body.parentElement.id));
    // Manuals whose first heading is h4 still get usable disclosures.
    if (!root.querySelector('.pasa-document-section')) group(root, 4, root.id);
    root.dataset.pasaSections = 'ready';
  }
  function init() {
    nav = document.getElementById('main_nav');
    if (!nav || document.querySelector('.pasa-navigation')) return;
    const bar = nav.closest('.navbar'), container = bar.querySelector('.container-fluid') || bar.firstElementChild;
    document.body.classList.add('pasa-carbon');
    toggle = document.createElement('button'); toggle.type='button'; toggle.className='pasa-nav-toggle'; toggle.textContent='☰';
    toggle.setAttribute('aria-label','Toggle navigation'); toggle.setAttribute('aria-controls','pasa-navigation'); toggle.setAttribute('aria-expanded',String(!mobile.matches));
    container.prepend(toggle);
    rail = document.createElement('aside'); rail.id='pasa-navigation'; rail.className='pasa-navigation'; rail.setAttribute('aria-label','PASA navigation');
    const label=document.createElement('div'); label.className='pasa-nav-label'; label.textContent='Workspace'; rail.append(label);
    const tools=document.createElement('ul'); tools.className='pasa-header-tools'; tools.setAttribute('aria-label','Session and help actions');
    Array.from(nav.children).forEach(item => { if (!item.querySelector('a[data-bs-toggle="tab"]')) tools.append(item); });
    rail.append(nav); document.body.append(rail); container.append(tools);
    nav.setAttribute('aria-orientation','vertical');
    const support=Array.from(nav.querySelectorAll('a[data-value]')).find(a=>a.dataset.value==='About');
    if(support) support.parentElement.classList.add('pasa-support-start');
    // Reorder the existing bound tab elements without duplicating inputs or outputs.
    orderNavigation();
    settings=document.getElementById('pasa-analysis-settings');
    documentSections(document.getElementById('pasa-about-content'));
    const help = document.getElementById('help_content');
    if (help) {
      new MutationObserver(() => {
        if (!help.querySelector('.pasa-document-section')) delete help.dataset.pasaSections;
        documentSections(help);
      }).observe(help, {childList:true});
      documentSections(help);
    }
    toggle.addEventListener('click',()=>{const closed=document.body.classList.toggle('pasa-nav-collapsed');toggle.setAttribute('aria-expanded',String(!closed));window.dispatchEvent(new Event('resize'));});
    if(mobile.matches) document.body.classList.add('pasa-nav-collapsed');
    const resizeRail = event => {
      document.body.classList.toggle('pasa-nav-collapsed',event.matches);
      toggle.setAttribute('aria-expanded',String(!event.matches));
      window.dispatchEvent(new Event('resize'));
    };
    if(mobile.addEventListener)mobile.addEventListener('change',resizeRail);
    else if(mobile.addListener)mobile.addListener(resizeRail);
    nav.addEventListener('keydown',event=>{
      if(!['ArrowDown','ArrowUp','Home','End'].includes(event.key))return;
      const links=Array.from(nav.querySelectorAll('a[data-value]'));const index=links.indexOf(document.activeElement);if(index<0)return;
      event.preventDefault();const next=event.key==='Home'?0:event.key==='End'?links.length-1:(index+(event.key==='ArrowDown'?1:-1)+links.length)%links.length;links[next].focus();links[next].click();
    });
    if(window.jQuery) {
      window.jQuery(nav).on('shown.bs.tab',updateView);
      // Shiny resets its formatter on server updates, then emits change.
      window.jQuery(document)
        .on('shiny:bound.pasaBudget change.pasaBudget', '#sim_pair_budget', syncBudgetLabels)
        .on('shiny:connected.pasaBudget', syncBudgetLabels);
      syncBudgetLabels();
    }
    nav.addEventListener('click',event=>{
      if(mobile.matches && event.target.closest('a[data-value]')) {
        document.body.classList.add('pasa-nav-collapsed');
        toggle.setAttribute('aria-expanded','false');
      }
    });
    new MutationObserver(()=>{orderNavigation();updateView();}).observe(nav,{childList:true,subtree:false});
    const controls=document.getElementById('controls_ui');
    if(controls)new MutationObserver(syncControls).observe(controls,{childList:true,subtree:true});
    new ResizeObserver(()=>document.documentElement.style.setProperty('--pasa-header-height',bar.getBoundingClientRect().height+'px')).observe(bar);
    document.addEventListener('click',event=>{
      const disclosureButton=event.target.closest('[data-pasa-disclosures]');
      if(disclosureButton) {
        const root=document.getElementById(disclosureButton.dataset.pasaDisclosures);
        if(root) root.querySelectorAll('details').forEach(el=>el.open=disclosureButton.dataset.pasaExpand==='true');
      }
      const disabled=event.target.closest('.pasa-requires-data[aria-disabled="true"]');if(disabled){event.preventDefault();event.stopPropagation();}
      document.querySelectorAll('.pasa-export-menu[open]').forEach(el=>{if(!el.contains(event.target))el.open=false;});
    },true);
    document.addEventListener('keydown',event=>{if(event.key==='Escape')document.querySelectorAll('.pasa-export-menu[open]').forEach(el=>el.open=false);});
    updateView();syncControls();
  }
  window.PasaShell={navigate,toggleSettings};
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init);else init();
})();

(function bindFeedbackBusy(){
  if(!window.Shiny||!Shiny.addCustomMessageHandler){setTimeout(bindFeedbackBusy,50);return;}
  Shiny.addCustomMessageHandler('pasa_feedback_busy',function(message){
    const button=document.getElementById('fb_submit');if(!button)return;
    const busy=!!(message&&message.busy);
    button.disabled=busy;button.setAttribute('aria-busy',String(busy));
  });
})();
