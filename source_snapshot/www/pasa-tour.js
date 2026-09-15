(function () {
  'use strict';
  if (window.PASAGuidedTour) return;
  const step = (nav, target, title, copy, extra = {}) => ({nav, target, title, copy, ...extra});
  const quickSteps = [
    step('Data', '#data_source', 'Bring in your spectra', 'Choose a local file, a URL or path, a saved session, or the built-in demo. Wavelength in nm belongs in the first column, with one sample in every remaining column. Select a source and load it when ready; you can also explore this tour without data.'),
    step('Analysis settings', '#analysis_nm, #organism, #samples', 'Choose the range and samples', 'Analysis settings now has its own tab. Set the wavelength range, organism preset and sample type, then select the samples. Presets supply editable band windows. The detailed tour explains each setting with examples.', {requiresData:true,fallback:'#pasa-analysis-settings'}),
    step('Analysis settings', '#apply_baseline, #smooth, #norm_method', 'Prepare the analysis', 'Review baseline correction, optional resampling and smoothing, dilution factors and normalization. For example, Band peak with Qy and target 1 compares curves on a common reference scale. Normalization removes signal-size information.', {requiresData:true,fallback:'#pasa-analysis-settings'}),
    step('Summary', '#run_summary_ui, #dl_state_file_summary', 'Review and save your work', 'Summary reports the current analysis and data preview. Save a session to reopen your data and settings; Export offers a ZIP of available results. Nothing is downloaded by the tour.', {fallback:'#dl_state_file'}),
    step('Spectra', '#plot_spectra, #plot_spectra_3d', 'Read the curves', 'Compare peak positions, curve shapes and signal size. Open Customize spectra plot, then choose Curve style, Titles and axes, Wavelength probe, or Band peaks and labels. The 3D overlay presents samples as interactive ridges and adds its own 3D rendering group.', {requiresData:true,fallback:'#customize_titles',output:true}),
    step('Metrics', '#metrics_layout, #metrics_ui', 'Read band measurements', 'Metrics brings peak positions, values, integrated areas and wavelength-window ratios together. Read the processing basis in the headings. Change the table layout or export the complete table as XLSX or PDF.'),
    step('Band AUC', '#auc_basis, #auc_chart_type', 'Compare integrated bands', 'Choose the processing basis, then a bar chart or radar chart. AUC is signal integrated within your band windows. Overlapping windows and sample backgrounds matter when comparing these descriptors.'),
    step('Data Quality', '#noise_qc_verdicts, #qc_view', 'Check quality and shape similarity', 'Noise qualification screens selected spectra. Per-sample QC inventories loaded columns. Select Sample similarity to compare shapes with weighted correlation and spectral angle; closer shape does not establish biological identity.', {fallback:'#qc_view'}),
    step('Data Quality', '#similarity_network_ui, #sim_budget_status', 'Explore the similarity network', 'Edge color represents the combined shape-similarity tier; thickness uses the selected relationship metric. At least two usable samples are needed. Network appearance starts open; expand the other groups for labels, calculation limits and the method. The detailed tour covers each control.', {fallback:'#qc_view',unavailable:'Choose Sample similarity (shape-based) under Compare to see this result.',output:true}),
    step('Data Quality', '#advanced_mode', 'Discover Advanced Mode', 'Advanced Mode adds the Deconvolution tab between Data Quality and Sample color. Turn it on if you want to explore fitted components. This is optional; the tour leaves your choice unchanged.'),
    step('Deconvolution', '#decon_sample, #decon_run', 'Fit overlapping components', 'Choose one sample and an appropriate sample class, review the search range and click Run when you want a fit. The overlay, residuals, component table and interpretation notes describe a curve model; they do not identify pigments.', {fallback:'#advanced_mode',unavailable:'Enable Advanced Mode in the header to open Deconvolution. Fitting also requires data and baseline correction.'}),
    step('Sample Color', '#is_pigmented', 'See an illustrative sample color', 'For a visibly colored sample, choose Yes to reveal a cuvette scene. Compare one sample or all selected samples and choose a Dark or Light scene background independently of the app theme. Expand Color details below the image for exact color codes and rendering information. The calculated color is illustrative and depends on the numerical curve, reference scaling and display.'),
    step('Cell Growth', '#growth_manual, #growth_gate_banner', 'Explore Cell Growth', 'Use Cells / Lysate spectra with samples mapped in time order, or enter OD measurements manually. Set the time unit, interval and biological replicates. Outputs include an apparent OD-derived rate, doubling time, curve and diagnostics. Switching to manual entry changes the source of OD values.'),
    step('About', '#pasa-about-content', 'Learn what PASA does', 'About explains PASA, intended sample types, input formatting and the difference between Band AUC and deconvolution. Expand all and Collapse all let you browse the complete page.'),
    step('Help', '#help_content', 'Keep the manual nearby', 'Help explains each processing step, outputs, exports and scientific assumptions. Open an individual section or use Expand all to read the complete manual.'),
    step('FAQ', '#pasa-faq-main, #pasa-faq-advanced', 'Find practical answers', 'FAQ contains Frequently Asked Questions and Advanced Mode & Deconvolution. It answers questions about formatting, normalization, growth, saving sessions and interpreting fitted bands. Expand or collapse all answers together.'),
    step('References', '#references_content', 'Trace methods and assumptions', 'References lists the sources behind the methods. The app also distinguishes cited methods from configurable operational defaults.'),
    step('Feedback', '#pasa-feedback-panel', 'Help improve PASA', 'Use Feedback to share a reaction, report a problem or suggest an improvement. Send feedback uses the existing Google Form without asking for your email. Review the notice before sending. You can also save a text draft or optionally compose an email. Contacts includes a Feedback shortcut.'),
    step('Feedback', '.theme-menu > button', 'Make PASA comfortable to use', 'Choose a theme for your screen and lighting. Guided tour in the header offers this quick introduction and a detailed walkthrough with chapter navigation. You can pause and resume either tour independently.')
  ];
  const inputSteps = [
    step('Data','#data_source','Choose an input route','Input data handles loading; Analysis settings handles processing. The tour never loads a file or replaces data. Follow along with your data, load the demo yourself, or read explanations and revisit unavailable controls later.'),
    step('Data','#file, #load','Load a local spectrum file','Choose Local, select a CSV, Excel or delimited text file, then press Load data. Include a header row such as nm, sample A, sample B. Each data row contains a wavelength followed by its measurements.',{fallback:'#data_source',unavailable:'Choose Local in Data source to show the file selector and Load data button.'}),
    step('Data','#path, #sheet','Use a URL, path or worksheet','For a URL or path, select that source and enter the address before loading. A local path refers to the machine running PASA. Excel and Google Sheets can offer a worksheet selector; confirm the intended sheet.',{fallback:'#data_source',unavailable:'Choose the URL/path route or an Excel source to reveal these controls.'}),
    step('Data','#state_load','Reopen a saved session','Select Import session and upload PASA_state.txt. The dialog lets you apply sections present in that file: settings, input data, Cell Growth data and a measured deconvolution blank. Applying a section replaces that part of the current session.',{fallback:'#data_source',unavailable:'Choose Import session to show its upload control.'}),
    step('Data','#load_demo','Try the built-in example','Choose Demo data and click Load demo data for a synthetic example. Loading it replaces the active spectra, so save a session first to retain your work. The tour leaves this button for you to operate.',{fallback:'#data_source',unavailable:'Choose Demo data to show its load button.'}),
    step('Data','#detected_info, #pasa_data_preview','Check the loaded file','Check the detected wavelength range and spacing, sample count and preview before analysis. Wavelengths are sorted; duplicate wavelengths are averaged per sample. Missing entries remain missing and can limit the outputs.',{requiresData:true,output:true,fallback:'#data_source'})
  ];
  const order = ['Data','Analysis settings','Summary','Spectra','Metrics','Band AUC','Data Quality','Deconvolution','Sample Color','Cell Growth','About','Help','FAQ','References','Feedback'];
  const workspace = window.PASATourWorkspaceSteps || [];
  const authored = [...(workspace.some(s => s.nav === 'Data') ? [] : inputSteps), ...(window.PASATourDetailedSteps || []), ...workspace];
  const section = s => s.nav || order.find(nav => nav.toLowerCase() === String(s.chapter).toLowerCase());
  const detailedSteps = order.flatMap(nav => {
    const rows = authored.filter(s => section(s) === nav);
    return rows.length ? rows : quickSteps.filter(s => s.nav === nav);
  }).concat(authored.filter(s => !order.includes(section(s))));
  const catalogs = {quick:quickSteps,detailed:detailedSteps};
  let initialized=false, connected=false, mode='browser', revision='2', state=null;
  let active=false, kind='quick', current=0, target=null, targets=[], field=0, clock=null, scrolled=false;
  let returnFocus=null, pending=null, manualDestination=null, missingNav=null, data={hasData:false,ready:false};
  const memory=new Map(), openedDetails=new Set(), openedPresentation=new Set(), openedMenus=new Set();
  let revealedThisStep = new WeakSet();
  const unavailableSteps={quick:new Set(),detailed:new Set()};
  const byId=id=>document.getElementById(id);
  const send=(name,value)=>{if(window.Shiny&&connected)window.Shiny.setInputValue(name,value,{priority:'event'});};
  const key=()=> 'pasa.guidedTour.'+revision;
  const blank=()=>({revision,kind:'quick',quick_status:'welcome',quick_step:0,detailed_status:'welcome',detailed_step:0});
  function normalize(value) {
    if(!value||typeof value!=='object'||Array.isArray(value))return null;
    const keys=['detailed_status','detailed_step','kind','quick_status','quick_step','revision'];
    if(Object.keys(value).sort().join(',')!==keys.join(',')||value.revision!==revision||!catalogs[value.kind])return null;
    for(const name of Object.keys(catalogs)){
      if(!['welcome','in_progress','completed','skipped'].includes(value[name+'_status'])||!Number.isInteger(value[name+'_step'])||value[name+'_step']<0||value[name+'_step']>=catalogs[name].length)return null;
    }
    return {...value};
  }
  function readBrowser(){
    try{const raw=localStorage.getItem(key());if(raw&&raw.length<=4096)return normalize(JSON.parse(raw));}
    catch(_){announce('Tour progress is kept only for this session because browser storage is unavailable.');}
    return memory.get(key())||null;
  }
  function save(status,index=current){
    state=state||blank();state={...state,kind,[kind+'_status']:status,[kind+'_step']:index};memory.set(key(),state);
    if(mode==='browser'){try{localStorage.setItem(key(),JSON.stringify(state));}catch(_){}}
    send('pasa_tour_state',state);
  }
  function announce(text){const live=byId('pasa-tour-live');if(live)live.textContent=text;}
  function navigate(nav){
    if(!nav)return true;
    const link=Array.from(document.querySelectorAll('#main_nav a[data-value]')).find(n=>n.getAttribute('data-value')===nav);
    if(link){link.click();return true;}
    return false;
  }
  function visible(node){
    if(!node||!node.isConnected)return false;
    const box=node.getBoundingClientRect(),style=getComputedStyle(node);
    return style.visibility!=='hidden'&&style.display!=='none'&&box.width>0&&box.height>0&&!node.closest('[inert]');
  }
  function restoreDisclosures(){
    openedMenus.forEach(toggle=>{if(toggle.isConnected&&toggle.getAttribute('aria-expanded')==='true')toggle.click();});openedMenus.clear();
    openedDetails.forEach(n=>{if(n.isConnected)n.open=false;});openedDetails.clear();
    openedPresentation.forEach(n=>{
      n.classList.remove('pasa-tour-reveal');
      const label=n.querySelector(':scope > .pasa-disc-header .pasa-disc-toggle');
      const control=n.querySelector(':scope > .pasa-disc-header .pasa-disc-cb');
      if(label&&control)label.setAttribute('aria-expanded',String(control.checked));
    });openedPresentation.clear();
  }
  function reveal(node){
    const menu=node.closest('.dropdown-menu');
    if(menu&&!menu.classList.contains('show')){
      const toggle=menu.parentElement.querySelector('[data-bs-toggle="dropdown"]');
      if(toggle){openedMenus.add(toggle);toggle.click();}
    }
    let parent=node;
    while(parent){
      if(parent.tagName==='DETAILS'&&!parent.open){openedDetails.add(parent);parent.open=true;}
      // CSS-only presentation reveal. Never check a Shiny input to enable an analysis branch.
      if(parent.classList.contains('pasa-disc-body')){
        const group=parent.parentElement,control=group.querySelector(':scope > .pasa-disc-header .pasa-disc-cb');
        if(control&&['customize_titles','auc_what_shows','lbl_point_opts'].includes(control.id)&&!control.checked){
          openedPresentation.add(group);group.classList.add('pasa-tour-reveal');
          const label=control.closest('.pasa-disc-toggle');if(label)label.setAttribute('aria-expanded','true');
        }
      }
      parent=parent.parentElement;
    }
  }
  function query(selector){return selector?selector.split(',').flatMap(s=>Array.from(document.querySelectorAll(s.trim()))):[];}
  function resolve(selector,match){
    const nodes=query(selector).filter(n=>!match||n.textContent.toLowerCase().includes(match.toLowerCase())),result=[];
    for(const node of nodes){
      if(!revealedThisStep.has(node)){reveal(node);revealedThisStep.add(node);}
      let wrapper=node.closest('.shiny-input-container')||node.closest('.pasa-disc-toggle')||node.closest('.pasa-pill')||node;
      if(!visible(wrapper)&&getComputedStyle(wrapper).display==='contents')wrapper=Array.from(wrapper.children).find(visible)||wrapper;
      if(visible(wrapper)&&!result.includes(wrapper))result.push(wrapper);
    }
    return result;
  }
  function rendered(node){
    if(!node)return false;const output=node.closest('.shiny-bound-output')||node;
    if(output.classList.contains('recalculating')||output.classList.contains('shiny-output-error'))return false;
    if(node.classList.contains('shiny-plot-output')){const img=node.querySelector('img');return !!(img&&img.complete&&img.naturalWidth);}
    return !!(node.textContent.trim()||node.querySelector('canvas,svg,table,.html-widget'));
  }
  function position(){
    if(!active)return;const card=byId('pasa-tour-card'),halo=byId('pasa-tour-highlight');if(!card||!halo)return;
    const pad=12,width=card.offsetWidth,height=card.offsetHeight,ww=innerWidth,wh=innerHeight;
    let left=Math.max(pad,ww-width-pad),top=Math.max(pad,wh-height-pad);
    if(target&&visible(target)){
      const b=target.getBoundingClientRect();halo.hidden=false;
      Object.assign(halo.style,{left:(b.left-4)+'px',top:(b.top-4)+'px',width:(b.width+8)+'px',height:(b.height+8)+'px'});
      if(ww>640){
        if(b.right+width+24<ww){left=b.right+16;top=b.top;}
        else if(b.left-width-16>pad){left=b.left-width-16;top=b.top;}
        else if(b.bottom+height+20<wh)top=b.bottom+12;
        else if(b.top-height-12>pad)top=b.top-height-12;
      }
    }else halo.hidden=true;
    card.style.top=Math.min(Math.max(pad,top),Math.max(pad,wh-height-pad))+'px';
    card.style.left=Math.min(Math.max(pad,left),Math.max(pad,ww-width-pad))+'px';
  }
  function refresh(){
    if(!active)return;const spec=catalogs[kind][current];
    if(missingNav&&navigate(missingNav))missingNav=null;
    targets=resolve(spec.target,spec.match);
    const available=targets.length>0&&(!spec.requiresData||data.hasData)&&(!(spec.output||spec.rendered)||targets.some(rendered));
    if(!available)targets=resolve(spec.fallback||(spec.nav==='Analysis settings'?'#pasa-analysis-settings':null));
    field=Math.min(field,Math.max(0,targets.length-1));target=targets[field]||null;
    if(available)unavailableSteps[kind].delete(current);else unavailableSteps[kind].add(current);
    if(target&&!scrolled){target.scrollIntoView({block:'center',inline:'nearest',behavior:'instant'});scrolled=true;}
    byId('pasa-tour-target').disabled=!target;byId('pasa-tour-field').hidden=targets.length<2;
    byId('pasa-tour-field').textContent='Next field ('+(field+1)+'/'+targets.length+')';
    byId('pasa-tour-wait').textContent=available?'':(spec.requiresData&&!data.hasData?'Load a file or the demo in Input data to see this control or result.':missingNav==='Deconvolution'?'Enable Advanced Mode in the header to open Deconvolution.':spec.unavailable||spec.wait||'This section or result is unavailable or closed. Open its relevant option or disclosure to explore it.')+' You can continue, or use Revisit after changing the relevant option.';
    byId('pasa-tour-revisit').textContent='Revisit ('+unavailableSteps[kind].size+')';byId('pasa-tour-revisit').disabled=!unavailableSteps[kind].size;position();
  }
  function populateChapters(){
    const select=byId('pasa-tour-chapter');select.replaceChildren();let previous=null;
    catalogs[kind].forEach((s,i)=>{const name=s.chapter||s.nav||'Workspace tools';if(name!==previous){const o=document.createElement('option');o.value=String(i);o.textContent=name==='Data'?'Input data':name;select.appendChild(o);}previous=name;});
  }
  function showStep(index){
    if(index>=catalogs[kind].length){finish('completed');return;}
    restoreDisclosures();revealedThisStep=new WeakSet();current=Math.max(0,index);field=0;target=null;scrolled=false;
    const spec=catalogs[kind][current];missingNav=navigate(spec.nav)?null:spec.nav;save('in_progress');
    byId('pasa-tour-chooser').hidden=true;byId('pasa-tour-card').hidden=false;
    byId('pasa-tour-title').textContent=spec.title;byId('pasa-tour-copy').textContent=spec.copy;
    byId('pasa-tour-progress').textContent=(kind==='quick'?'Quick':'Detailed')+' tour · '+(current+1)+' of '+catalogs[kind].length;
    announce((kind==='quick'?'Quick':'Detailed')+' tour, step '+(current+1)+' of '+catalogs[kind].length+': '+spec.title);
    byId('pasa-tour-back').disabled=current===0;byId('pasa-tour-next').disabled=false;byId('pasa-tour-next').textContent=current===catalogs[kind].length-1?'Finish':'Next';
    const option=Array.from(byId('pasa-tour-chapter').options).filter(o=>Number(o.value)<=current).pop();if(option)byId('pasa-tour-chapter').value=option.value;
    refresh();byId('pasa-tour-title').focus({preventScroll:true});clearInterval(clock);clock=setInterval(refresh,350);
  }
  function start(name='quick',resume=false,chapter=null){
    if(!catalogs[name])name='quick';
    if(!initialized){pending={name,resume,chapter};announce('PASA is connecting. Your tour will start shortly.');return;}
    if(!active)returnFocus=document.activeElement;kind=name;active=true;populateChapters();
    let index=resume&&state&&state[kind+'_status']==='in_progress'?state[kind+'_step']:0;
    if(chapter){const i=catalogs[kind].findIndex(s=>s.nav===chapter);if(i>=0)index=i;}showStep(index);
  }
  function finish(status='in_progress'){
    if(active)save(status);active=false;clearInterval(clock);clock=null;restoreDisclosures();target=null;
    byId('pasa-tour-card').hidden=true;byId('pasa-tour-highlight').hidden=true;
    announce(status==='completed'?'Tour complete. Open Guided tour for the other tour or to revisit a chapter.':'Tour paused. Guided tour can resume this tour.');
    const focus=visible(returnFocus)?returnFocus:byId('pasa_tour_restart');if(focus)focus.focus({preventScroll:true});
  }
  function choose(){
    if(active)finish('in_progress');returnFocus=document.activeElement;byId('pasa-tour-chooser').hidden=false;
    for(const name of Object.keys(catalogs)){
      const resume=byId('pasa-tour-resume-'+name);resume.hidden=!(state&&state[name+'_status']==='in_progress');
      resume.textContent='Resume '+name+' tour · step '+(state?state[name+'_step']+1:1);byId('pasa-tour-count-'+name).textContent=catalogs[name].length+' steps';
    }
    byId('pasa-tour-choose-title').focus();
  }
  function closeChoices(){
    pending=null;
    byId('pasa-tour-chooser').hidden=true;
    if(visible(returnFocus))returnFocus.focus();
  }
  function init(message){
    if(initialized)return;initialized=true;revision=String(message.revision);mode=message.storage==='desktop'?'desktop':'browser';state=mode==='desktop'?normalize(message.state):readBrowser();
    if(pending){const p=pending;pending=null;start(p.name,p.resume,p.chapter);return;}
    if(manualDestination){if(!state){state=blank();save('skipped',0);}navigate(manualDestination);return;}
    if(!state){state=blank();save('welcome',0);navigate('Welcome');}
    else if(Object.keys(catalogs).some(n=>state[n+'_status']==='in_progress')){navigate('Welcome');announce('A tour is paused. Guided tour offers Resume for each saved tour.');}
    else navigate(state.quick_status==='welcome'&&state.detailed_status==='welcome'?'Welcome':'Data');
  }
  function bindShiny(){
    if(!window.Shiny||!window.jQuery){setTimeout(bindShiny,50);return;}
    window.Shiny.addCustomMessageHandler('pasa-tour-init',init);window.Shiny.addCustomMessageHandler('pasa-tour-data',value=>{data=value;refresh();});
    // Shiny checks formal handler arity: even unused custom messages need one argument.
    window.Shiny.addCustomMessageHandler('pasa-tour-storage',_value=>announce('Tour progress is kept for this session; saving preferences was unavailable.'));
    const hello=()=>{
      if(window.Shiny.shinyapp&&window.Shiny.shinyapp.isConnected()&&typeof window.Shiny.setInputValue==='function'){
        connected=true;send('pasa_tour_client_ready',Date.now());
      }
    };
    window.jQuery(document).on('shiny:connected.pasaTour',()=>{
      connected=true;
      // The connected event fires before Shiny sends its init packet.
      setTimeout(hello,0);
    }).on('shiny:sessioninitialized.pasaTour',hello).on('shiny:disconnected.pasaTour',()=>{connected=false;});
    if(window.Shiny.initializedPromise&&typeof window.Shiny.initializedPromise.then==='function')window.Shiny.initializedPromise.then(hello);
    else setTimeout(hello,0);
  }
  function setup(){
    document.addEventListener('click',event=>{
      const control=event.target.closest('button, a');if(!control)return;
      if(control.matches('#main_nav a[data-value]')&&event.isTrusted){
        manualDestination=control.getAttribute('data-value');
        if(!initialized)pending=null;
        else if(!active&&state&&state.quick_status==='welcome'&&state.detailed_status==='welcome'&&manualDestination!=='Welcome')save('skipped',0);
      }
      if(['pasa_tour_restart','pasa_welcome_tour'].includes(control.id)){event.preventDefault();choose();}
      if(control.id==='pasa_welcome_open'){manualDestination='Data';pending=null;if(active)finish();if(initialized)save('skipped',0);navigate('Data');}
      if(control.id==='load_demo'&&data.hasData&&!window.confirm('Load the built-in demo and replace the currently loaded spectra? Save a session first to retain this analysis.')){event.preventDefault();event.stopImmediatePropagation();}
    },true);
    for(const name of Object.keys(catalogs)){
      byId('pasa-tour-start-'+name).addEventListener('click',()=>start(name));byId('pasa-tour-resume-'+name).addEventListener('click',()=>start(name,true));
    }
    byId('pasa-tour-chooser-close').addEventListener('click',closeChoices);
    byId('pasa-tour-chooser-x').addEventListener('click',closeChoices);
    byId('pasa-tour-close').addEventListener('click',()=>finish('in_progress'));
    byId('pasa-tour-back').addEventListener('click',()=>showStep(current-1));byId('pasa-tour-next').addEventListener('click',()=>showStep(current+1));
    byId('pasa-tour-skip-step').addEventListener('click',()=>showStep(current+1));byId('pasa-tour-exit').addEventListener('click',()=>finish());
    byId('pasa-tour-field').addEventListener('click',()=>{field=(field+1)%targets.length;scrolled=false;refresh();});
    byId('pasa-tour-chapter').addEventListener('change',e=>showStep(Number(e.target.value)));
    byId('pasa-tour-revisit').addEventListener('click',()=>{const list=Array.from(unavailableSteps[kind]).sort((a,b)=>a-b);if(list.length)showStep(list.find(i=>i>current)??list[0]);});
    byId('pasa-tour-target').addEventListener('click',()=>{
      if(!target)return;const f=target.matches('button,a,input:not([type=hidden]),select,textarea,summary')?target:Array.from(target.querySelectorAll('button,a,input:not([type=hidden]),select,textarea,summary,[tabindex]')).find(visible);
      if(f)f.focus();else{target.setAttribute('tabindex','-1');target.focus();}
    });
    document.addEventListener('keydown',e=>{
      if(e.key!=='Escape')return;
      const menu=document.querySelector('.dropdown-menu.show');
      const exportMenu=document.querySelector('.pasa-export-menu[open]');
      if(menu||exportMenu){
        e.preventDefault();e.stopImmediatePropagation();
        if(menu){const toggle=menu.parentElement.querySelector('[data-bs-toggle="dropdown"]');if(toggle)toggle.click();}
        if(exportMenu)exportMenu.open=false;
        return;
      }
      if(active){e.preventDefault();finish();}else if(!byId('pasa-tour-chooser').hidden)closeChoices();
    },true);
    window.addEventListener('resize',position);document.addEventListener('scroll',position,true);bindShiny();
  }
  window.PASAGuidedTour={choose,start,startSettings:()=>start('detailed',false,'Analysis settings'),restart:choose,catalog:()=>({quick:quickSteps.map(s=>({...s})),detailed:detailedSteps.map(s=>({...s}))})};
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',setup,{once:true});else setup();
}());
