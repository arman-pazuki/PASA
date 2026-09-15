(function () {
  "use strict";

  function initializeWelcome() {
    const root = document.getElementById("pasa-welcome");
    if (!root || root.dataset.welcomeInitialized === "true") return;
    root.dataset.welcomeInitialized = "true";
    const query = name => root.querySelector(".pasa-welcome-" + name);
    const button = document.getElementById("pasa-welcome-pause");
    const status = query("motion-state");
    const base = query("base"), trace = query("trace"), glow = query("glow");
    const scan = query("scan"), halo = query("halo"), dot = query("dot");
    const ray = query("light"), beam = query("beam");
    const reflection = query("reflection"), signal = query("signal");
    const required = [button, status, base, trace, glow, scan, halo, dot, ray, beam, reflection, signal];
    if (required.some(element => !element)) return;
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)");
    const d = base.getAttribute("d");
    trace.setAttribute("d", d);
    glow.setAttribute("d", d);
    const length = base.getTotalLength();
    trace.style.strokeDasharray = `${length} ${length}`;
    glow.style.strokeDasharray = `${length} ${length}`;
    let playing = !reduced.matches;
    let phase = playing ? 0.32 : 0.86;
    let frame = null;
    let lastTime = null;
    let running = false;
    let destroyed = false;
    const loopSeconds = 7.8;
    const pane = root.closest(".tab-pane");

    function isVisible() {
      if (!root.isConnected || document.hidden || root.getClientRects().length === 0) return false;
      if (pane && !pane.classList.contains("active")) return false;
      const bounds = root.getBoundingClientRect();
      return bounds.width > 0 && bounds.height > 0 && bounds.bottom > 0 && bounds.top < window.innerHeight;
    }

    function render() {
      const raw = Math.max(0, Math.min(1, (phase - 0.055) / 0.755));
      const progress = raw * raw * (3 - 2 * raw);
      const fading = phase > 0.92 ? Math.max(0, (1 - phase) / 0.08) : phase < 0.04 ? phase / 0.04 : 1;
      const cursorVisible = phase >= 0.055 && phase < 0.92 ? 1 : fading;
      const offset = length * (1 - progress);
      trace.style.strokeDashoffset = String(offset);
      glow.style.strokeDashoffset = String(offset);
      trace.style.opacity = String(fading);
      glow.style.opacity = String(0.52 * fading);
      const point = base.getPointAtLength(length * progress);
      const top = 294 - (point.x - 1079) * 0.054;
      const bottom = 462 + (point.x - 1070) * 0.022;
      scan.setAttribute("d", `M${point.x + (point.y - top) * 0.043},${top}L${point.x - (bottom - point.y) * 0.043},${bottom}`);
      scan.style.opacity = String(0.48 * cursorVisible);
      for (const marker of [halo, dot]) {
        marker.setAttribute("cx", String(point.x));
        marker.setAttribute("cy", String(point.y));
        marker.style.opacity = String(cursorVisible);
      }
      const travel = (phase * 2) % 1;
      ray.setAttribute("transform", `translate(${282 + 449 * travel},${417.2 + 10.4 * travel}) rotate(1.31)`);
      ray.style.opacity = String(0.55 * Math.sin(Math.PI * travel) ** 2);
      beam.style.opacity = String(0.1 + 0.035 * Math.sin(phase * Math.PI * 2));
      reflection.style.opacity = String(0.08 + 0.06 * Math.sin(Math.PI * phase) ** 2);
      signal.style.strokeDashoffset = String(-phase * 66);
    }

    function tick(time) {
      frame = null;
      if (!root.isConnected) { destroy(); return; }
      if (!playing || !isVisible()) { sync(); return; }
      if (lastTime !== null) phase = (phase + Math.min((time - lastTime) / 1000, 0.1) / loopSeconds) % 1;
      lastTime = time;
      render();
      frame = requestAnimationFrame(tick);
    }

    function sync() {
      if (destroyed) return;
      const shouldRun = playing && isVisible();
      root.dataset.motion = shouldRun ? "playing" : "paused";
      root.dataset.motionPreference = playing ? "play" : "pause";
      button.textContent = playing ? "Pause animation" : "Play animation";
      const state = playing ? (shouldRun ? "Animation playing" : "Animation pauses off screen") : "Animation paused";
      if (status.textContent !== state) status.textContent = state;
      if (running === shouldRun && (frame !== null || !shouldRun)) return;
      running = shouldRun;
      if (frame !== null) cancelAnimationFrame(frame);
      frame = null;
      lastTime = null;
      if (shouldRun) frame = requestAnimationFrame(tick);
    }

    function onToggle() { playing = !playing; sync(); }
    function onReducedMotion() { if (reduced.matches) { playing = false; sync(); } }
    function onPaneEvent() { requestAnimationFrame(sync); }
    const visibilityObserver = new IntersectionObserver(sync, { threshold: 0 });
    visibilityObserver.observe(root);
    const paneObserver = new MutationObserver(sync);
    if (pane) paneObserver.observe(pane, { attributes: true, attributeFilter: ["class", "style", "hidden"] });
    const sizeObserver = new ResizeObserver(sync);
    sizeObserver.observe(root);

    function destroy() {
      destroyed = true;
      if (frame !== null) cancelAnimationFrame(frame);
      visibilityObserver.disconnect(); paneObserver.disconnect(); sizeObserver.disconnect();
      button.removeEventListener("click", onToggle);
      reduced.removeEventListener("change", onReducedMotion);
      document.removeEventListener("visibilitychange", sync);
      document.removeEventListener("shown.bs.tab", onPaneEvent);
      document.removeEventListener("hidden.bs.tab", onPaneEvent);
      window.removeEventListener("pagehide", destroy);
    }

    button.addEventListener("click", onToggle);
    reduced.addEventListener("change", onReducedMotion);
    document.addEventListener("visibilitychange", sync);
    document.addEventListener("shown.bs.tab", onPaneEvent);
    document.addEventListener("hidden.bs.tab", onPaneEvent);
    window.addEventListener("pagehide", destroy);
    render();
    sync();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initializeWelcome, { once: true });
  } else {
    initializeWelcome();
  }
})();
