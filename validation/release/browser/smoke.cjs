'use strict';
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const assert = require('node:assert/strict');
const { spawn, spawnSync } = require('node:child_process');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '../../..');
const output = path.join(root, '.ci-results');
fs.mkdirSync(output, { recursive: true });
const port = Number(process.env.PASA_PORT || 3838);
assert(Number.isInteger(port) && port > 0 && port < 65536, 'Valid PASA_PORT required');
const baseURL = `http://127.0.0.1:${port}`;
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
const serverLog = fs.createWriteStream(path.join(output, 'app-server.log'));
let server, browser, page, serverError;
const browserErrors = [];
const checks = [];

async function ready() {
  return new Promise(resolve => {
    const req = http.get(baseURL, response => { response.resume(); resolve(response.statusCode === 200); });
    req.on('error', () => resolve(false));
    req.setTimeout(1000, () => req.destroy());
  });
}
async function tab(value) {
  await page.locator(`#main_nav a[data-value="${value}"]`).click();
  await page.waitForFunction(v => document.body.dataset.pasaView === v, value);
  console.log("TAB",value,await page.evaluate(()=>({view:document.body.dataset.pasaView,links:Array.from(document.querySelectorAll("#main_nav a.active")).map(x=>({value:x.dataset.value,href:x.getAttribute("href")})),panes:Array.from(document.querySelectorAll(".tab-pane.active")).map(x=>({id:x.id,value:x.dataset.value}))})));
}
async function noOutputError() {
  const errors = await page.locator('.tab-pane.active .shiny-output-error:not(.shiny-output-error-validation):visible').allTextContents();
  assert.deepEqual(errors.filter(x => x.trim()), [], 'No visible application output errors');
}
async function check(name, fn) {
  await fn(); checks.push(name); console.log('PASS: ' + name);
}

(async () => {
  try {
    assert(!(await ready()), 'Smoke test requires an unused port; it will not attach to a pre-existing app');
    server = spawn(process.env.RSCRIPT || 'Rscript', ['--vanilla', 'reproducibility/RUN_PASA.R'], {
      cwd: root, windowsHide: true, detached: process.platform !== 'win32',
      env: {...process.env, PASA_PORT:String(port), PASA_LAUNCH_BROWSER:'0', PASA_FEEDBACK_ENABLED:'0', SPECTRA_HOSTED_MODE:'1'},
      stdio:['ignore', 'pipe', 'pipe']
    });
    server.stdout.pipe(serverLog, {end:false}); server.stderr.pipe(serverLog, {end:false});
    server.on('error', error => { serverError = error; });
    const deadline = Date.now() + 120000;
    while (!(await ready())) {
      if (serverError) throw serverError;
      if (server.exitCode !== null) throw Error('Application exited with code ' + server.exitCode);
      if (Date.now() > deadline) throw Error('Application did not listen within 120 seconds');
      await wait(250);
    }
    browser = await chromium.launch({ headless:true, ...(process.env.PASA_SMOKE_CHROME ? {executablePath:process.env.PASA_SMOKE_CHROME} : {}) });
    const context = await browser.newContext({viewport:{width:1440,height:1000}, reducedMotion:'reduce'});
    // The demo is entirely local. An unexpected external page request cannot submit feedback.
    await context.route('**/*', route => {
      const url = new URL(route.request().url());
      return ['127.0.0.1','localhost'].includes(url.hostname) || ['data:','blob:'].includes(url.protocol)
        ? route.continue() : route.abort();
    });
    page = await context.newPage();
    page.setDefaultTimeout(Number(process.env.PASA_SMOKE_TIMEOUT || 60000));
    page.on('pageerror', error => browserErrors.push(error.message));
    await page.goto(baseURL, {waitUntil:'domcontentloaded'});
    await page.waitForFunction(() => window.Shiny?.shinyapp?.isConnected());

    await check('Welcome opens Input data and keeps support controls separate', async () => {
      await page.locator('#pasa_welcome_open').click();
      await page.waitForFunction(() => document.body.dataset.pasaView === 'Data');
      await page.locator('#data_source').waitFor({state:'visible'});
      assert(await page.locator('#pasa-settings-shortcut').isVisible());
    });
    await check('Built-in demo loads and exposes Analysis settings', async () => {
      await page.locator('#data_source input[value=demo]').check();
      await page.locator('#load_demo').click();
      await page.locator('#pasa_data_preview tbody tr').first().waitFor();
      await tab('Analysis settings');
      await page.locator('#analysis_nm').waitFor({state:'attached'});
      await noOutputError();
    });
    await check('Metrics produces a paginated table and visible top scroll control', async () => {
      await tab('Metrics');
      await page.locator('#metrics_ui .gt_table').first().waitFor();
      await page.waitForFunction(() => !document.querySelector('#metrics_ui')?.classList.contains('recalculating'));
      await page.locator('#metrics_ui input[type="range"]').first().waitFor();
      assert((await page.locator('#metrics_ui .gt_table tbody tr').count()) > 0);
      await noOutputError();
      await page.screenshot({path:path.join(output,'metrics.png'),fullPage:true});
    });
    await check('Spectra renders a nonempty plot', async () => {
      await tab('Spectra');
      await page.waitForFunction(() => {const img=document.querySelector('#plot_spectra img');return img && img.complete && img.naturalWidth > 0;});
      await page.waitForFunction(() => !document.querySelector('#plot_spectra')?.classList.contains('recalculating'));
      await noOutputError();
      await page.screenshot({path:path.join(output,'spectra.png'),fullPage:true});
    });
    await check('Advanced Mode reveals Deconvolution', async () => {
      await page.locator('label[for="advanced_mode"]').click();
      await page.locator('#main_nav a[data-value="Deconvolution"]').waitFor({state:'visible'});
      await tab('Deconvolution');
      await noOutputError();
    });
    await check('Support tabs hide the Analysis settings shortcut', async () => {
      for (const value of ['About','Help','FAQ','References','Feedback']) {
        await tab(value);
        assert(!(await page.locator('#pasa-settings-shortcut').isVisible()), value+' has no analysis shortcut');
        await noOutputError();
      }
    });
    await check('Guided tour chooser closes immediately', async () => {
      await page.locator('#pasa_tour_restart').click();
      await page.locator('#pasa-tour-chooser').waitFor({state:'visible'});
      await page.locator('#pasa-tour-chooser-x').click();
      await page.locator('#pasa-tour-chooser').waitFor({state:'hidden'});
    });
    assert.deepEqual(browserErrors, [], 'No uncaught browser exceptions');
    fs.writeFileSync(path.join(output,'browser-results.json'), JSON.stringify({status:'passed',checks,browserErrors},null,2)+'\n');
  } catch (error) {
    if (page) console.log("DOM DIAGNOSTIC",await page.evaluate(()=>({view:document.body.dataset.pasaView,links:Array.from(document.querySelectorAll("#main_nav a.active")).map(x=>({value:x.dataset.value,href:x.getAttribute("href")})),panes:Array.from(document.querySelectorAll(".tab-pane.active")).map(x=>x.id)})).catch(()=>({})));
    if (page) await page.screenshot({path:path.join(output,'browser-failure.png'),fullPage:true}).catch(()=>{});
    fs.writeFileSync(path.join(output,'browser-results.json'), JSON.stringify({status:'failed',checks,browserErrors,error:error.stack},null,2)+'\n');
    console.error(error); process.exitCode=1;
  } finally {
    if (browser) await browser.close().catch(()=>{});
    if (server && server.pid && server.exitCode === null) {
      if(process.platform === 'win32') spawnSync('taskkill',['/PID',String(server.pid),'/T','/F'],{windowsHide:true,stdio:'ignore'});
      else { try { process.kill(-server.pid,'SIGTERM'); } catch (_) { server.kill('SIGTERM'); } }
      const stop = Date.now()+5000;
      while (server.exitCode === null && Date.now() < stop) await wait(100);
      if (server.exitCode === null) {
        if(process.platform !== 'win32') { try { process.kill(-server.pid,'SIGKILL'); } catch (_) {} }
        else server.kill('SIGKILL');
      }
    }
    if(server) { server.stdout?.destroy(); server.stderr?.destroy(); server.unref(); }
    serverLog.end();
  }
})();
