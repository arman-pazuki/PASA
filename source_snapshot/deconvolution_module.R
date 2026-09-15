# =============================================================================
# SPECTRAL DECONVOLUTION MODULE  (pseudo-Voigt band fitting)
# Companion module for PASA.R.
#
# DESIGN PRINCIPLES (read before integrating):
#   * PURE CORE. All math here is plain functions of numeric vectors / data
#     frames. NO shiny, NO reactive(), NO input$/output$ references. The UI
#     wiring is the integrator's job; this file must remain testable with
#     source() + a vector of numbers.
#   * CONSUMES THE INTEGRATOR'S DECLARED FIT INPUT. The current PASA integration
#     preferentially supplies analysis-range-clipped native-grid analysis-curve
#     values after dilution scaling, baseline correction, and optional normalization;
#     display resampling and smoothing are not fit inputs. A documented fallback
#     supports older result rows lacking native-fit fields. The integrator MUST
#     pass an already-baselined (nm, val) vector and enforce its axis policy.
#   * REUSES app conventions: trapz_auc() for areas; reflect-padding philosophy
#     for derivatives; graceful degradation when optional packages are absent
#     (mirrors the optional-dependency pattern in PASA.R).
#   * REPRODUCIBLE BY CONSTRUCTION: peak seeds come from the 2nd-derivative
#     (deterministic), not from user clicks. Same input + same settings =>
#     identical fit. The optional bootstrap uses a local, fixed seed and restores
#     the caller's RNG state.
#
# SCIENTIFIC SCOPE / HONESTY:
#   This is phenomenological band modeling / resolution enhancement. A good
#   fit does NOT prove the number of molecular species. Always report residuals,
#   the plug-in parsimony score used for K selection, and conditional parameter uncertainty.
#   Treat band-window AUC as a simpler non-decomposition descriptor that is still
#   conditional on wavelength coverage, limits, preprocessing, and baseline choice;
#   treat this model as the more assumption-heavy complement.
#
# OPTIONAL DEPENDENCIES (all degrade gracefully):
#   * minpack.lm  -> bounded Levenberg-Marquardt (nlsLM). STRONGLY PREFERRED.
#                    Fallback: stats::optim(method="L-BFGS-B") on SSE.
#   * signal      -> Savitzky-Golay 2nd derivative for seeding.
#                    Fallback: finite-difference 2nd derivative on a light
#                    moving-average smooth.
# =============================================================================

if (!exists(".pasa_minpack_available", mode = "function", inherits = TRUE))
  .pasa_minpack_available <- function() requireNamespace("minpack.lm", quietly = TRUE)
if (!exists(".pasa_signal_available", mode = "function", inherits = TRUE))
  .pasa_signal_available <- function() requireNamespace("signal", quietly = TRUE)

# Detect optional packages without attaching them. PASA never installs packages
# at runtime; users restore/install dependencies outside the running app.
.decon_has_minpack <- .pasa_minpack_available()
.decon_has_signal  <- .pasa_signal_available()

# Re-detect optional packages after the host environment changes.
.decon_refresh_flags <- function() {
  .decon_has_minpack <<- .pasa_minpack_available()
  .decon_has_signal  <<- .pasa_signal_available()
  invisible(c(minpack.lm = .decon_has_minpack, signal = .decon_has_signal))
}

# -----------------------------------------------------------------------------
# trapz_auc fallback.
# The host app already defines trapz_auc(). To keep this file source()-able on
# its own (for unit testing), define it ONLY if it does not already exist.
# INTEGRATOR NOTE: when sourced by PASA.R the app's definition wins; remove
# this guard ONLY if you are certain of load order. Behavior is identical.
# -----------------------------------------------------------------------------
if (!exists("trapz_auc", mode = "function")) {
  trapz_auc <- function(x, y) {
    if (length(x) < 2) return(NA_real_)
    o <- order(x); x <- x[o]; y <- y[o]
    dx <- diff(x); ym <- (utils::head(y, -1) + utils::tail(y, -1)) / 2
    sum(dx * ym, na.rm = TRUE)
  }
}


pvoigt_one <- function(nm, amp, mu, fwhm, eta) {
  fwhm <- max(fwhm, 1e-6)
  # NOTE: eta is intentionally NOT clamped to [0,1] here. The nlsLM path
  # differentiates this model with respect to the shared eta_g; a min/max clamp
  # makes the model non-differentiable at the [0,1] boundary and triggers
  # minpack.lm's "singular gradient" abort, forcing the SE-less L-BFGS-B fallback
  # on affected numerical fixtures. Both fit paths already confine eta to [0,1] -- nlsLM via its
  # lower/upper bounds, the L-BFGS-B fallback by pinning eta at .DECON_ETA_START --
  # so the clamp is redundant and can impede convergence. Removing it allows the
  # bounded nlsLM path to report its model-conditional SE approximations when it converges.
  # Gaussian with given FWHM: sigma = fwhm / (2*sqrt(2*ln2))
  sigma <- fwhm / (2 * sqrt(2 * log(2)))
  gauss <- exp(-((nm - mu)^2) / (2 * sigma^2))
  # Lorentzian with given FWHM: gamma = fwhm/2
  gamma <- fwhm / 2
  lorentz <- 1 / (1 + ((nm - mu) / gamma)^2)
  amp * (eta * lorentz + (1 - eta) * gauss)
}

# Sum of K components. params is a flat numeric vector laid out as
# [amp1,mu1,fwhm1,eta1, amp2,mu2,fwhm2,eta2, ...] (length 4*K).
pvoigt_model <- function(nm, params) {
  K <- length(params) / 4L
  if (K < 1) return(rep(0, length(nm)))
  out <- numeric(length(nm))
  for (k in seq_len(K)) {
    o <- (k - 1L) * 4L
    out <- out + pvoigt_one(nm, params[o + 1], params[o + 2],
                            params[o + 3], params[o + 4])
  }
  out
}

# Flat-vector parameter names, used to build a named-scalar nlsLM model so the
# fit is portable across minpack.lm versions (vector-start support varies).
# Layout matches pvoigt_model(): amp_k, mu_k, fwhm_k, eta_k for k = 1..K.
.pvoigt_par_names <- function(K) {
  as.vector(rbind(
    paste0("amp",  seq_len(K)),
    paste0("mu",   seq_len(K)),
    paste0("fwhm", seq_len(K)),
    paste0("eta",  seq_len(K))
  ))
}

# Build the RHS expression string: sum of K pseudo-Voigt terms in named params.
.pvoigt_formula_rhs <- function(K) {
  terms <- vapply(seq_len(K), function(k) {
    sprintf("pvoigt_one(nm, amp%d, mu%d, fwhm%d, eta%d)", k, k, k, k)
  }, character(1))
  paste(terms, collapse = " + ")
}

# Eta (Gaussian<->Lorentzian mix) is fitted as ONE shared global parameter
# across all bands, instead of an independent free eta per band. A per-band
# free eta was strongly collinear with that band's FWHM in tested fixtures and
# could produce a singular Jacobian at the start point (nlsLM error: "singular
# gradient matrix at initial parameter estimates"), forcing the L-BFGS-B
# fallback and suppressing SEs. Collapsing to a single shared eta reduces this
# observed per-band collinearity and may permit nlsLM convergence and
# model-conditional SE estimation; it does not guarantee either. The data still
# choose the shared line-shape mix. Fully deterministic. Free parameters:
# amp/mu/fwhm per band (3K) + one shared eta = 3K + 1.
.DECON_ETA_START <- 0.3   # deterministic shared-eta start value

# Free-parameter names on the nlsLM path: amp_k, mu_k, fwhm_k (k=1..K) + eta_g.
.pvoigt_free_par_names <- function(K) {
  c(as.vector(rbind(
      paste0("amp",  seq_len(K)),
      paste0("mu",   seq_len(K)),
      paste0("fwhm", seq_len(K))
    )),
    "eta_g")
}

# RHS with a single shared eta parameter (eta_g) reused by every band.
.pvoigt_formula_rhs_shared_eta <- function(K) {
  terms <- vapply(seq_len(K), function(k) {
    sprintf("pvoigt_one(nm, amp%d, mu%d, fwhm%d, eta_g)", k, k, k)
  }, character(1))
  paste(terms, collapse = " + ")
}

# =============================================================================
# 2. DETERMINISTIC PEAK SEEDING via 2nd derivative
# =============================================================================
# Negative lobes of the 2nd derivative mark band maxima (a minimum in d2 sits
# under a peak in the spectrum). We smooth first to avoid seeding on noise.
# Returns a data.frame of candidate seeds sorted by prominence (descending).

.decon_second_derivative <- function(nm, val, sg_n = 15, sg_p = 3) {
  # Uniform spacing is assumed. The PASA integration validates the native axis,
  # reconstructs only rounding-compatible coordinates, and refuses materially
  # irregular or gapped axes before calling this function. Direct module users
  # receive the warning below if they bypass that integration contract.
  dnm <- diff(nm)
  if (length(unique(round(dnm, 6))) > 1L)
    warning("decon: wavelength grid is not uniform; seed positions may be approximate. ",
            "Validate/reconstruct a supported uniform lattice or refuse the fit.")
  h <- mean(dnm)
  n <- length(val)
  if (.decon_has_signal) {
    sg_n <- as.integer(round(sg_n)); if (sg_n %% 2L == 0L) sg_n <- sg_n + 1L
    max_odd <- if (n %% 2L == 0L) n - 1L else n
    sg_n <- max(3L, min(sg_n, max_odd))
    if (sg_n <= sg_p) sg_p <- max(1L, sg_n - 1L)
    d2 <- signal::sgolayfilt(val, p = sg_p, n = sg_n, m = 2, ts = h)
  } else {
    # finite-difference 2nd derivative on a light moving average
    k <- max(3, sg_n %/% 2)
    k <- min(k, (n - 1L) %/% 2L); if (k < 1L) k <- 1L
    ypad <- c(rev(val[2:(k + 1)]), val, rev(val[(n - k):(n - 1)]))
    sm <- stats::filter(ypad, rep(1 / (2 * k + 1), 2 * k + 1), sides = 2)
    sm <- as.numeric(sm)[(k + 1):(k + n)]
    d2 <- c(NA, diff(diff(sm)) / (h^2), NA)
  }
  d2
}

seed_peaks <- function(nm, val, max_peaks = 6, sg_n = 15, sg_p = 3,
                       min_sep_nm = 6, prominence_frac = 0.02) {
  stopifnot(length(nm) == length(val), length(nm) >= 5)
  d2 <- .decon_second_derivative(nm, val, sg_n = sg_n, sg_p = sg_p)
  n  <- length(val)
  # Local minima of d2 (interior points) = candidate band centers.
  is_min <- rep(FALSE, n)
  for (i in 2:(n - 1)) {
    if (is.finite(d2[i]) && is.finite(d2[i - 1]) && is.finite(d2[i + 1]) &&
        d2[i] < d2[i - 1] && d2[i] < d2[i + 1] && d2[i] < 0) is_min[i] <- TRUE
  }
  idx <- which(is_min)
  if (!length(idx)) {
    # Fallback: seed a single peak at the global maximum.
    j <- which.max(val)
    return(data.frame(mu = nm[j], amp = val[j], fwhm = (max(nm) - min(nm)) / 6,
                      prominence = val[j]))
  }
  # Prominence = depth of the d2 minimum (more negative => sharper band).
  prom <- -d2[idx]
  # Threshold weak candidates relative to the strongest.
  keep <- prom >= prominence_frac * max(prom, na.rm = TRUE)
  idx  <- idx[keep]; prom <- prom[keep]
  ord  <- order(prom, decreasing = TRUE)
  idx  <- idx[ord];  prom <- prom[ord]
  # Enforce minimum separation (greedy, strongest first).
  chosen <- integer(0)
  for (i in idx) {
    if (all(abs(nm[i] - nm[chosen]) >= min_sep_nm)) chosen <- c(chosen, i)
    if (length(chosen) >= max_peaks) break
  }
  data.frame(
    mu         = nm[chosen],
    amp        = pmax(val[chosen], 1e-6),
    fwhm       = rep(min(20, (max(nm) - min(nm)) / 10), length(chosen)),
    prominence = -d2[chosen]
  )
}

# =============================================================================
# 3. BOUNDED FIT
# =============================================================================
# Fits K pseudo-Voigt components to (nm, val) using seeds. Configurable numerical
# bounds keep the search finite and reproducible:
#   amp  in [0, 1.5*max(val)]      (no negative bands)
#   mu   within +/- mu_tol_nm of its seed (peaks can't wander across the band)
#   fwhm in [fwhm_min, fwhm_max] nm
#   eta  in [0, 1]
# Returns a list with params, fitted curve, residuals, gof, and per-parameter
# standard errors (when available).


# Gaussian AR(1) concentrated log-likelihood-style term evaluated at plug-in rho
# on a (near-)uniform grid. rho defaults to the lag-1 autocorrelation. Returns NA
# for a degenerate series (n < 3, or non-positive innovation variance).
.decon_ar1_loglik <- function(resid, rho = NULL) {
  r <- resid[is.finite(resid)]; n <- length(r)
  if (n < 3L) return(list(logLik = NA_real_, rho = NA_real_, n = n))
  if (is.null(rho)) {
    rc <- r - mean(r); den <- sum(rc * rc)
    rho <- if (is.finite(den) && den > 0) sum(rc[-n] * rc[-1L]) / den else 0
  }
  if (!is.finite(rho)) rho <- 0
  rho <- max(-0.999, min(0.999, rho))
  # Innovation SSE of the AR(1): (1-rho^2) r_1^2 + sum_{t>=2} (r_t - rho r_{t-1})^2.
  q  <- (1 - rho^2) * r[1]^2 + sum((r[-1L] - rho * r[-n])^2)
  s2 <- q / n
  if (!is.finite(s2) || s2 <= 0) return(list(logLik = NA_real_, rho = rho, n = n))
  ll <- -0.5 * (n * log(2 * pi) + n * log(s2) + n) + 0.5 * log(1 - rho^2)
  list(logLik = ll, rho = rho, n = n)
}

.decon_ic <- function(resid_score, npar) {
  rr  <- resid_score[is.finite(resid_score)]
  n   <- length(rr)
  sse <- sum(rr * rr)
  rc  <- rr - mean(rr); den <- sum(rc * rc)
  rho <- if (n >= 3L && is.finite(den) && den > 0)
           sum(rc[-length(rc)] * rc[-1L]) / den else 0
  if (!is.finite(rho)) rho <- 0
  ll <- .decon_ar1_loglik(rr, rho = rho)$logLik
  k  <- npar + 2L                                  # + sigma^2 + rho (AR(1) params)
  aic  <- if (is.finite(ll)) 2 * k - 2 * ll                     else NA_real_
  bic  <- if (is.finite(ll)) log(max(n, 1)) * k - 2 * ll        else NA_real_
  denom <- n - k - 1
  aicc <- if (is.finite(aic) && denom > 0) aic + 2 * k * (k + 1) / denom else Inf
  # n_eff is now INFORMATIONAL ONLY (shown in the table); it no longer enters the
  # criteria. It is a heuristic AR(1) reference quantity, not an estimate of a
  # literal number of independent residual observations.
  rho_pos <- max(0, min(rho, 0.999)); n_eff <- n * (1 - rho_pos) / (1 + rho_pos)
  list(n = n, n_eff = n_eff, sse = sse, rho_score = rho,
       logLik = ll, aic = aic, bic = bic, aicc = aicc)
}

# AR(1) effective sample size from a lag-1 autocorrelation and a raw count.
.decon_n_eff <- function(rho, n) {
  if (!is.finite(rho)) rho <- 0
  rho_pos <- max(0, min(rho, 0.999))
  n * (1 - rho_pos) / (1 + rho_pos)
}

.pvoigt_area_analytic <- function(amp, fwhm, eta) {
  amp <- as.numeric(amp); fwhm <- max(as.numeric(fwhm), 1e-9); eta <- as.numeric(eta)
  gauss_area <- amp * (1 - eta) * fwhm * sqrt(2 * pi) / (2 * sqrt(2 * log(2)))
  lor_area   <- amp * eta * (pi * fwhm / 2)
  gauss_area + lor_area
}

DECON_MIN_PTS_PER_COMP <- 8L
DECON_RESID_DF_MARGIN  <- 4L
.decon_max_feasible_k <- function(n) {
  n <- suppressWarnings(as.integer(n))
  if (is.na(n) || n < 5L) return(1L)
  cap_pts <- as.integer(floor(n / DECON_MIN_PTS_PER_COMP))               # rule (a)
  cap_df  <- as.integer(floor((n - DECON_RESID_DF_MARGIN - 1L) / 3L))    # rule (b): 3K+1 <= n - margin
  max(1L, min(cap_pts, cap_df))
}

# One clipping/point-support decision for the app's preview and fitting paths.
# The requested K floor is never weakened; the existing feasible-K ceiling may
# reduce the requested maximum. Axis/gap validation remains the integrator's job.
.decon_prepare_red_clip <- function(nm, val, limit = NULL, k_min = 1L, k_max = 4L) {
  nm <- suppressWarnings(as.numeric(nm)); val <- suppressWarnings(as.numeric(val))
  km <- suppressWarnings(as.numeric(k_min)); kx <- suppressWarnings(as.numeric(k_max))
  lim <- suppressWarnings(as.numeric(limit))
  disabled <- !length(lim) || (length(lim) == 1L && is.na(lim) &&
                               (is.null(limit) || is.numeric(limit) || is.logical(limit)))
  meta <- list(schema_version = 1L, requested_limit_nm = if (length(lim) == 1L) lim else NA_real_,
               status = "refused", reason = "", input_points = length(nm),
               finite_points = 0L, retained_points = 0L,
               input_range_nm = c(NA_real_, NA_real_), effective_range_nm = c(NA_real_, NA_real_),
               requested_k_min = if (length(km) == 1L) km else NA_real_,
               requested_k_max = if (length(kx) == 1L) kx else NA_real_,
               effective_k_max = NA_integer_)
  refuse <- function(reason) { meta$reason <- reason; list(ok = FALSE, nm = numeric(0), val = numeric(0), meta = meta) }
  if (length(nm) != length(val)) return(refuse("Deconvolution input wavelengths and values have different lengths."))
  if (!disabled && (length(lim) != 1L || !is.finite(lim)))
    return(refuse("Red-edge clip must be a finite wavelength, or left empty to disable clipping."))
  if (length(km) != 1L || length(kx) != 1L || !all(is.finite(c(km, kx))) ||
      km != floor(km) || kx != floor(kx) || km < 1L || kx < km)
    return(refuse("The component-count range must contain whole numbers with 1 <= k_min <= k_max."))
  usable <- is.finite(nm) & is.finite(val)
  meta$finite_points <- sum(usable)
  if (any(usable)) meta$input_range_nm <- range(nm[usable])
  keep <- usable & (if (disabled) TRUE else nm <= lim)
  n <- sum(keep); meta$retained_points <- n
  if (n) meta$effective_range_nm <- range(nm[keep])
  feasible <- if (n >= 8L) .decon_max_feasible_k(n) else 0L
  meta$effective_k_max <- min(as.integer(kx), feasible)
  if (n < 8L || km > feasible)
    return(refuse(sprintf(paste0("Deconvolution was not run: the requested red-edge range retains %d of %d finite points, ",
      "which cannot support k_min = %d (maximum feasible K = %d; at least %d points per component and 3K+1 <= n-%d). ",
      "Raise or clear the red-edge clip, widen the analysis range, or reduce Min components."),
      n, meta$finite_points, as.integer(km), feasible, DECON_MIN_PTS_PER_COMP, DECON_RESID_DF_MARGIN)))
  meta$status <- if (disabled) "disabled" else if (n == meta$finite_points) "no_change" else "applied"
  meta$reason <- switch(meta$status, disabled = "Red-edge clipping is disabled.",
    no_change = "All finite input points are within the requested red-edge limit.",
    applied = "Only finite input points at or below the requested limit are retained.")
  list(ok = TRUE, nm = nm[keep], val = val[keep], meta = meta)
}

.decon_bootstrap_outcome <- function(fit, draw, seed, k_min, k_max, original_k) {
  selected <- NA_integer_; status <- "invalid_return"; reason <- "Refit did not return one finite in-range integer K."
  if (inherits(fit, "try-error")) {
    status <- "execution_error"
    reason <- if (inherits(attr(fit, "condition"), "condition")) conditionMessage(attr(fit, "condition")) else as.character(fit)[1L]
  } else if (is.list(fit)) {
    k <- fit$best_K
    valid <- is.numeric(k) && length(k) == 1L && is.finite(k) && k == floor(k) && k >= k_min && k <= k_max
    no_adm <- identical(fit$selection_status, "no_admissible_candidate")
    if (valid && !no_adm) { status <- "selected"; selected <- as.integer(k); reason <- "" }
    else if (no_adm && is.numeric(k) && length(k) == 1L && is.na(k)) {
      status <- "no_admissible_candidate"
      reason <- if (is.character(fit$selection_reason) && length(fit$selection_reason) == 1L) fit$selection_reason else "No candidate passed the selection rule."
    }
  }
  same <- if (length(original_k) == 1L && is.finite(original_k))
            identical(status, "selected") && selected == original_k else NA
  data.frame(draw = as.integer(draw), seed = as.numeric(seed), outcome = status,
    selected_K = selected, same_K = same, reason = reason,
    parameter_usable = FALSE, area_usable = FALSE, parameter_reason = "not a selected same-K draw",
    stringsAsFactors = FALSE)
}

.decon_bootstrap_parameters <- function(fit, k) {
  bad <- function(reason) list(parameters = NULL, areas = NULL, reason = reason)
  cb <- tryCatch(fit$best$components, error = function(e) NULL)
  if (!is.data.frame(cb) || nrow(cb) != k || !all(c("amp", "mu_nm", "fwhm", "eta") %in% names(cb)))
    return(bad("The selected same-K refit did not return the expected component table."))
  vals <- tryCatch(lapply(cb[c("amp", "mu_nm", "fwhm", "eta")], as.numeric), error = function(e) NULL)
  if (is.null(vals) || !all(is.finite(unlist(vals))))
    return(bad("The selected same-K refit returned non-finite component parameters."))
  ord <- order(vals$mu_nm)
  pars <- as.numeric(rbind(vals$amp[ord], vals$mu_nm[ord], vals$fwhm[ord], vals$eta[ord]))
  areas <- suppressWarnings(as.numeric(cb$area_analytic))
  good_area <- length(areas) == k && all(is.finite(areas))
  list(parameters = pars, areas = if (good_area) areas[ord] else NULL,
       reason = if (good_area) "" else "The selected same-K refit returned unavailable or non-finite areas.")
}

.decon_bootstrap_summary <- function(outcomes, k_min, k_max, original_k,
                                    n_requested, block_len, seed, boot_pars, boot_areas) {
  stopifnot(is.data.frame(outcomes), nrow(outcomes) == n_requested,
            identical(as.integer(outcomes$draw), seq_len(n_requested)))
  selected <- outcomes$outcome == "selected"
  n_ok <- sum(selected)
  tb <- table(factor(outcomes$selected_K[selected], levels = seq.int(k_min, k_max)))
  oc <- table(factor(outcomes$outcome,
    levels = c("selected", "no_admissible_candidate", "execution_error", "invalid_return")))
  stopifnot(sum(tb) == n_ok, sum(oc) == n_requested)
  original_valid <- length(original_k) == 1L && is.finite(original_k)
  same_n <- if (original_valid) sum(outcomes$same_K %in% TRUE) else NA_integer_
  n_par <- length(boot_pars); n_area <- length(boot_areas)
  list(schema_version = 2L, outcome_schema = "PASA-DECON-BOOTSTRAP-2",
    n_requested = as.integer(n_requested), n_boot = n_ok,
    n_failed = as.integer(n_requested) - n_ok, # compatibility: all draws without a valid selection
    block_len = block_len, seed = seed,
    k_freq = if (n_ok) tb / n_ok else NULL,
    k_mode = if (n_ok) as.integer(names(tb)[which.max(tb)]) else NA_integer_,
    stability = if (original_valid && n_ok) same_n / n_ok else NA_real_,
    param_se_boot = if (n_par >= 3L) apply(do.call(rbind, boot_pars), 2, stats::sd, na.rm = TRUE) else NULL,
    area_se_boot = if (n_area >= 3L) apply(do.call(rbind, boot_areas), 2, stats::sd, na.rm = TRUE) else NULL,
    n_boot_params = n_par, # compatibility: usable parameter-vector count among same-K selections
    n_boot_areas = n_area, n_same_k = same_n,
    original_selected_K = if (original_valid) as.integer(original_k) else NA_integer_,
    stability_all_requested = if (original_valid && n_requested > 0L) same_n / n_requested else NA_real_,
    k_count = tb, k_freq_all_requested = tb / n_requested,
    outcome_counts = oc, n_no_admissible = unname(oc["no_admissible_candidate"]),
    n_execution_error = unname(oc["execution_error"]), n_invalid_return = unname(oc["invalid_return"]),
    outcomes = outcomes)
}

fit_pvoigt <- function(nm, val, seeds,
                       mu_tol_nm = 8, fwhm_min = 10, fwhm_max = 50,
                       maxiter = 200, nm_score = NULL, val_score = NULL) {
  if (!is.finite(fwhm_min) || !is.finite(fwhm_max) || fwhm_min >= fwhm_max)
    stop(sprintf("decon: fwhm bounds must be finite with fwhm_min < fwhm_max (got min=%s, max=%s).",
                 format(fwhm_min), format(fwhm_max)))
  if (!is.finite(mu_tol_nm) || mu_tol_nm < 0)
    stop(sprintf("decon: mu_tol_nm must be a finite, non-negative center tolerance (got %s).",
                 format(mu_tol_nm)))
  if (!is.finite(maxiter) || maxiter < 1)
    stop(sprintf("decon: maxiter must be a finite integer >= 1 (got %s).", format(maxiter)))
  K <- nrow(seeds)
  stopifnot(K >= 1)
  # SEGFAULT-PREVENTION (mirror of deconvolve_spectrum's ceiling): never hand an
  # over-parameterized / rank-deficient problem to the compiled solver -- it can crash the
  # R session at the C level, which no tryCatch can trap. Refuse before fitting.
  .n_fit <- sum(is.finite(nm) & is.finite(val))
  if (K > .decon_max_feasible_k(.n_fit))
    stop(sprintf("decon: cannot fit K = %d pseudo-Voigt components on %d points (max feasible K = %d here: needs >= %d points/component and 3K+1 <= n - %d).",
                 K, .n_fit, .decon_max_feasible_k(.n_fit), DECON_MIN_PTS_PER_COMP, DECON_RESID_DF_MARGIN))
  vmax <- suppressWarnings(max(val, na.rm = TRUE))
  if (!is.finite(vmax) || vmax <= 0)
    stop("decon: spectrum has no positive signal to fit (all values <= 0 after ",
         "baseline). Deconvolution assumes non-negative absorbance bands.")
  amp0 <- seeds$amp; mu0 <- seeds$mu
  fwhm0 <- pmin(pmax(seeds$fwhm, fwhm_min), fwhm_max)
  # eta is a single SHARED parameter across bands; the canonical per-band layout
  # below carries this shared value in every band's eta slot.
  eta_start <- rep(.DECON_ETA_START, K)

  # Canonical [amp,mu,fwhm,eta] x K layout, used by the model/comp table and the
  # L-BFGS-B fallback.
  par0  <- as.numeric(rbind(amp0, mu0, fwhm0, eta_start))
  lower <- as.numeric(rbind(rep(0, K),            mu0 - mu_tol_nm, rep(fwhm_min, K), rep(0, K)))
  upper <- as.numeric(rbind(rep(1.5 * max(val, na.rm = TRUE), K),
                            mu0 + mu_tol_nm, rep(fwhm_max, K), rep(1, K)))
  pnames <- .pvoigt_par_names(K)
  names(par0) <- names(lower) <- names(upper) <- pnames

  fit_ok <- FALSE; fit_obj <- NULL; pars <- par0; ses <- rep(NA_real_, length(par0))
  method <- NA_character_
  # fit_status distinguishes the three outcomes so PASA.R can show an honest
  # method/SE badge: "nlsLM" (converged; model-conditional SEs may be available
  # when the covariance calculation is estimable), "lbfgs_no_minpack"
  # (minpack.lm absent -> L-BFGS-B, no SEs), "lbfgs_nonconvergence" (minpack.lm
  # present but nlsLM failed to converge at this K -> L-BFGS-B, no SEs).
  fit_status <- NA_character_
  optimizer_converged <- FALSE; optimizer_accepted <- FALSE; optim_convergence_code <- NA_integer_
  optim_message_raw <- NA_character_
  # Genuinely free parameters: amp/mu/fwhm per band (3K) + one shared eta.
  n_free <- 3L * K + 1L

  if (.decon_has_minpack) {
    # Free parameters: amp/mu/fwhm per band plus ONE shared eta_g reused by every
    # band. In tested fixtures, collapsing the K per-band etas to one shared
    # value reduced eta<->FWHM collinearity and sometimes allowed nlsLM to
    # converge with model-conditional SEs. It does not guarantee a full-rank
    # Jacobian, convergence, or estimable SEs. Named-scalar form keeps this
    # portable across minpack.lm versions; pvoigt_one() is visible when sourced.
    amp_nm  <- paste0("amp",  seq_len(K))
    mu_nm_  <- paste0("mu",   seq_len(K))
    fwhm_nm <- paste0("fwhm", seq_len(K))
    start_f <- c(stats::setNames(amp0,  amp_nm),
                 stats::setNames(mu0,   mu_nm_),
                 stats::setNames(fwhm0, fwhm_nm),
                 eta_g = .DECON_ETA_START)
    lower_f <- c(stats::setNames(rep(0, K),        amp_nm),
                 stats::setNames(mu0 - mu_tol_nm,  mu_nm_),
                 stats::setNames(rep(fwhm_min, K), fwhm_nm),
                 eta_g = 0)
    upper_f <- c(stats::setNames(rep(1.5 * max(val, na.rm = TRUE), K), amp_nm),
                 stats::setNames(mu0 + mu_tol_nm,  mu_nm_),
                 stats::setNames(rep(fwhm_max, K), fwhm_nm),
                 eta_g = 1)
    fml <- stats::as.formula(paste("val ~", .pvoigt_formula_rhs_shared_eta(K)))
    df_fit <- data.frame(nm = nm, val = val)
    res <- try(minpack.lm::nlsLM(
        fml,
        data    = df_fit,
        start   = as.list(start_f),
        lower   = lower_f, upper = upper_f,
        control = minpack.lm::nls.lm.control(maxiter = maxiter)
      ), silent = TRUE)
    nls_conv <- FALSE
    if (!inherits(res, "try-error")) {
      is_conv <- tryCatch(isTRUE(res$convInfo$isConv), error = function(e) NA)
      co_try  <- tryCatch(stats::coef(res), error = function(e) NULL)
      coefs_ok <- !is.null(co_try) && all(is.finite(co_try)) &&
                  all(co_try >= lower_f - 1e-6) && all(co_try <= upper_f + 1e-6)
      # isTRUE(is_conv): converged. is.na(is_conv): older minpack.lm without
      # convInfo -> accept on finite in-bounds coefficients (best effort).
      nls_conv <- coefs_ok && (isTRUE(is_conv) || is.na(is_conv))
    }
    if (nls_conv) {
      fit_ok <- TRUE; fit_obj <- res; method <- "nlsLM"; fit_status <- "nlsLM"
      optimizer_converged <- TRUE; optimizer_accepted <- TRUE; optim_convergence_code <- 0L
      optim_message_raw <- tryCatch(as.character(res$convInfo$stopMessage), error = function(e) NA_character_)
      n_free <- length(start_f)
      co <- stats::coef(res)
      sm <- try(summary(res)$coefficients, silent = TRUE)
      se_named <- if (!inherits(sm, "try-error") && "Std. Error" %in% colnames(sm))
                    sm[, "Std. Error"] else stats::setNames(rep(NA_real_, length(co)), names(co))
      eta_hat <- as.numeric(co["eta_g"]); eta_se <- as.numeric(se_named["eta_g"])
      # Map free estimates back into the canonical 4K layout; the shared eta and
      # its SE are broadcast to every band's eta slot.
      for (k in seq_len(K)) {
        o <- (k - 1L) * 4L
        pars[o + 1] <- as.numeric(co[amp_nm[k]]);  ses[o + 1] <- as.numeric(se_named[amp_nm[k]])
        pars[o + 2] <- as.numeric(co[mu_nm_[k]]);  ses[o + 2] <- as.numeric(se_named[mu_nm_[k]])
        pars[o + 3] <- as.numeric(co[fwhm_nm[k]]); ses[o + 3] <- as.numeric(se_named[fwhm_nm[k]])
        pars[o + 4] <- eta_hat;                    ses[o + 4] <- eta_se
      }
    }
  }

  if (!fit_ok) {
    amp_i <- seq(1L, 4L * K, by = 4L); mu_i <- seq(2L, 4L * K, by = 4L)
    fw_i  <- seq(3L, 4L * K, by = 4L); eta_i <- seq(4L, 4L * K, by = 4L)
    free_from <- c(amp_i, mu_i, fw_i)              # 3K amp/mu/fwhm positions in the 4K layout
    pf0   <- c(par0[free_from],  eta_g = .DECON_ETA_START)
    pf_lo <- c(lower[free_from], eta_g = 0)
    pf_hi <- c(upper[free_from], eta_g = 1)
    expand_pars <- function(pf) {
      p <- par0
      p[free_from] <- pf[seq_len(3L * K)]
      p[eta_i]     <- pf[3L * K + 1L]              # broadcast the shared eta to every band
      p
    }
    sse <- function(pf) sum((val - pvoigt_model(nm, expand_pars(pf)))^2, na.rm = TRUE)
    sse_start <- sse(pf0)
    res <- try(stats::optim(pf0, sse, method = "L-BFGS-B",
                            lower = pf_lo, upper = pf_hi,
                            control = list(maxit = maxiter * 5,
                                           parscale = pmax(abs(pf0), 1e-6),
                                           fnscale  = max(sse_start, 1e-12))),
               silent = TRUE)
    optim_ok <- !inherits(res, "try-error") &&
                is.finite(res$value) && all(is.finite(res$par)) &&
                (isTRUE(res$convergence == 0L) ||
                 res$value <= sse_start + 1e-9 * max(1, abs(sse_start)))
    if (optim_ok) {
      fit_ok <- TRUE; pars <- expand_pars(res$par); method <- "L-BFGS-B"; n_free <- 3L * K + 1L
      # Two-case fallback: minpack.lm genuinely absent vs present-but-nonconvergent.
      fit_status <- if (.decon_has_minpack) "lbfgs_nonconvergence" else "lbfgs_no_minpack"
      optim_convergence_code <- suppressWarnings(as.integer(res$convergence))
      optim_message_raw      <- if (!inherits(res, "try-error") && !is.null(res$message)) as.character(res$message) else NA_character_
      optimizer_converged    <- isTRUE(optim_convergence_code == 0L)
      .at_optimum            <- isTRUE(!optimizer_converged) &&
                                isTRUE(res$value >= sse_start - 1e-9 * max(1, abs(sse_start)))   # diagnostic only; NOT admissibility
      optimizer_accepted     <- optimizer_converged
    } else {
      conv_code <- if (!inherits(res, "try-error")) as.character(res$convergence) else "error"
      stop("decon: fit did not converge with nlsLM or L-BFGS-B (optim code ",
           conv_code, "). Check that the input is baseline-corrected, has ",
           "positive signal, and enough points for K components.")
    }
  }

  optimizer_nonconverged <- isTRUE(fit_ok && !optimizer_accepted)
  fitted_curve <- pvoigt_model(nm, pars)
  resid <- val - fitted_curve
  # npar = genuinely free parameters: both the nlsLM and L-BFGS-B paths fit
  # amp/mu/fwhm per band plus ONE shared eta (3K+1). n_free was set accordingly above.
  n <- length(val); npar <- n_free
  sse_val <- sum(resid^2, na.rm = TRUE)
  ss_tot  <- sum((val - mean(val, na.rm = TRUE))^2, na.rm = TRUE)
  r2  <- if (ss_tot > 0) 1 - sse_val / ss_tot else NA_real_
  rmse <- sqrt(sse_val / n)
  # Measured lag-1 residual autocorrelation (rho) on the fit grid. It is a
  # descriptive residual-structure statistic: model mismatch, correlated
  # acquisition/preprocessing noise, sampling, or several causes may contribute.
  rho_lag1 <- {
    rr <- resid[is.finite(resid)]
    if (length(rr) >= 3L) {
      rc <- rr - mean(rr); den <- sum(rc * rc)
      if (is.finite(den) && den > 0) sum(rc[-length(rc)] * rc[-1L]) / den else NA_real_
    } else NA_real_
  }

  # --- Plug-in AR(1) parsimony scores on the native curve -----------------------
  # The IC that drive component-count selection are evaluated on nm_score/val_score
  # (the integrator passes processed analysis-curve values at native measured
  # wavelength coordinates, before display smoothing; defaults to the fit curve
  # when absent). The score uses the plug-in AR(1) likelihood-style
  # term in .decon_ic(); n_eff is informational only and does not enter the
  # AIC-like/BIC-like/AICc-like plug-in scores.
  nm_s  <- if (is.null(nm_score))  nm  else as.numeric(nm_score)
  val_s <- if (is.null(val_score)) val else as.numeric(val_score)
  resid_s <- if (length(nm_s) == length(nm) && isTRUE(all.equal(nm_s, nm)))
               (val_s - fitted_curve) else (val_s - pvoigt_model(nm_s, pars))
  ic  <- .decon_ic(resid_s, npar)
  ll  <- ic$logLik; aic <- ic$aic; bic <- ic$bic; aicc <- ic$aicc

  nstep <- { u <- sort(unique(nm_s[is.finite(nm_s)]))
             if (length(u) >= 2) stats::median(diff(u)) else NA_real_ }
  fwhm_eps <- max(1e-3 * (fwhm_max - fwhm_min), 1e-6)
  amp_eps  <- 1e-3 * max(vmax, 1e-9)
  Cg <- sqrt(2 * pi) / (2 * sqrt(2 * log(2)))
  area_se_vec <- rep(NA_real_, K)
  Vcov <- tryCatch(if (!is.null(fit_obj)) as.matrix(stats::vcov(fit_obj)) else NULL, error = function(e) NULL)
  if (!is.null(Vcov) && !is.null(rownames(Vcov))) {
    for (k in seq_len(K)) {
      o <- (k - 1L) * 4L; a <- pars[o+1]; fw <- pars[o+3]; et <- pars[o+4]
      gvec <- c((1 - et) * fw * Cg + et * pi * fw / 2,     # d area / d amp
                a * (1 - et) * Cg + a * et * pi / 2,        # d area / d fwhm
                a * fw * (pi / 2 - Cg))                     # d area / d eta
      nmv <- c(paste0("amp", k), paste0("fwhm", k), "eta_g")
      if (all(nmv %in% rownames(Vcov))) {
        vv <- as.numeric(t(gvec) %*% Vcov[nmv, nmv, drop = FALSE] %*% gvec)
        area_se_vec[k] <- if (is.finite(vv) && vv >= 0) sqrt(vv) else NA_real_
      }
    }
  }
  ar1_rho_src   <- if (is.finite(ic$rho_score)) ic$rho_score
                   else if (is.finite(rho_lag1)) rho_lag1 else 0
  ar1_rho_infl  <- if (is.finite(ar1_rho_src)) max(0, min(ar1_rho_src, 0.95)) else 0
  ar1_se_factor <- sqrt((1 + ar1_rho_infl) / (1 - ar1_rho_infl))
  if (is.finite(ar1_se_factor) && ar1_se_factor > 1) {
    ses         <- ses * ar1_se_factor
    area_se_vec <- area_se_vec * ar1_se_factor
  }

  comp <- lapply(seq_len(K), function(k) {
    o <- (k - 1L) * 4L
    cc <- pvoigt_one(nm, pars[o+1], pars[o+2], pars[o+3], pars[o+4])
    data.frame(
      component = k,
      amp   = pars[o+1], amp_se   = ses[o+1],
      mu_nm = pars[o+2], mu_se    = ses[o+2],
      fwhm  = pars[o+3], fwhm_se  = ses[o+3],
      eta   = pars[o+4], eta_se   = ses[o+4],
      area  = trapz_auc(nm, cc),
      area_analytic = .pvoigt_area_analytic(pars[o+1], pars[o+3], pars[o+4]),
      area_analytic_se = area_se_vec[k],
      fwhm_at_bound      = isTRUE(abs(pars[o+3] - fwhm_min) <= fwhm_eps ||
                                  abs(pars[o+3] - fwhm_max) <= fwhm_eps),
      amp_near_zero      = isTRUE(abs(pars[o+1]) < amp_eps),
      resolution_limited = isTRUE(is.finite(nstep) && pars[o+3] < 3 * nstep)
    )
  })
  comp <- do.call(rbind, comp)
  comp$area_frac          <- comp$area / sum(comp$area)
  comp$area_analytic_frac <- comp$area_analytic / sum(comp$area_analytic)

  area_obs   <- trapz_auc(nm, val)
  area_fit   <- trapz_auc(nm, fitted_curve)
  area_resid <- area_obs - area_fit
  r2_negative        <- isTRUE(is.finite(r2) && r2 < 0)
  any_boundary_pinned<- any(comp$fwhm_at_bound)
  any_res_limited    <- any(comp$resolution_limited)
  fit_quality_adequate <- isTRUE(is.finite(r2) && r2 >= 0.5) && !r2_negative && !any_boundary_pinned
  adequate <- isTRUE(fit_quality_adequate && !any_res_limited)

  fit_usable <- isTRUE(fit_ok)
  ok_strict  <- isTRUE(optimizer_converged)
  optim_message_display <- {
    .m <- optim_message_raw
    if (is.null(.m) || length(.m) != 1L || is.na(.m) || !nzchar(trimws(.m))) "No optimizer message returned" else as.character(.m)
  }

  list(
    ok = ok_strict, fit_usable = fit_usable, method = method, fit_status = fit_status,
    optim_message_raw = optim_message_raw, optim_message_display = optim_message_display,
    optimizer_converged = optimizer_converged, optimizer_accepted = optimizer_accepted,
    optimizer_nonconverged = optimizer_nonconverged, optim_convergence_code = optim_convergence_code,
    adequate = adequate,
    params = pars, se = ses,
    nm = nm, observed = val, fitted = fitted_curve, residual = resid,
    components = comp,
    gof = data.frame(n_points = n, n_params = npar, K = K,
                     r2 = r2, rmse = rmse, sse = sse_val,
                     aic = aic, bic = bic, aicc = aicc, logLik = ll,
                     n_eff = ic$n_eff, rho_lag1 = rho_lag1, rho_score = ic$rho_score,
                     se_ar1_factor = ar1_se_factor,
                     sse_score = ic$sse, n_score = ic$n,
                     area_obs = area_obs, area_fit = area_fit, area_resid = area_resid,
                     r2_negative = r2_negative, any_boundary_pinned = any_boundary_pinned,
                     any_resolution_limited = any_res_limited,
                     fit_quality_adequate = fit_quality_adequate, adequate = adequate,
                     optimizer_accepted = optimizer_accepted, optimizer_converged = optimizer_converged),
    fit_obj = fit_obj
  )
}

# =============================================================================
# 4. COMPONENT-COUNT SELECTION (parsimony)
# =============================================================================
# Fits K = k_min..k_max components (seeding the strongest K each time) and selects
# the lowest chosen AIC-like, BIC-like, or AICc-like plug-in score among admissible
# candidates (finite score, accepted optimizer, no operational-resolution flag).
# The raw all-candidate score minimum is retained separately for transparency.
# This answers which admissible K minimizes the documented heuristic under the
# stated search, not how many physical peaks exist. Returns the selected/display fit
# plus the comparison table.

.decon_split_guard <- function(components, min_sep_nm = 6) {
  cc <- components
  if (is.null(cc) || nrow(cc) < 2L) return(FALSE)
  o <- order(cc$mu_nm); mu <- cc$mu_nm[o]; se <- cc$mu_se[o]
  dmu <- diff(mu); j <- which.min(dmu)
  if (!length(j) || !is.finite(dmu[j])) return(FALSE)
  se_i <- se[j]; se_j <- se[j + 1L]
  unresolved_unc <- all(is.finite(c(se_i, se_j))) && dmu[j] < 2 * (se_i + se_j)
  unresolved_floor <- !all(is.finite(c(se_i, se_j))) && dmu[j] < min_sep_nm
  amplitude_collapsed <- isTRUE(any(cc$amp_near_zero))
  isTRUE(unresolved_unc || unresolved_floor || amplitude_collapsed)
}

deconvolve_spectrum <- function(nm, val,
                                 k_min = 1, k_max = 4,
                                 criterion = c("aic", "bic", "aicc"),
                                 seed_args = list(), fit_args = list(),
                                 nm_native = NULL, val_native = NULL,
                                 n_boot = 0L, boot_seed = 1L,
                                 multistart = TRUE, progress = NULL) {
  criterion <- match.arg(criterion)
  stopifnot(length(nm) == length(val))
  k_min <- suppressWarnings(as.integer(k_min)); k_max <- suppressWarnings(as.integer(k_max))
  if (!is.finite(k_min) || !is.finite(k_max) || k_min < 1L || k_max < 1L || k_min > k_max)
    stop(sprintf("decon: invalid component range (k_min = %s, k_max = %s). Require 1 <= k_min <= k_max.",
                 format(k_min), format(k_max)))
  nm <- suppressWarnings(as.numeric(nm)); val <- suppressWarnings(as.numeric(val))
  if (!all(is.finite(nm)) || !all(is.finite(val)) || is.unsorted(nm) || anyDuplicated(nm)) {
    keep <- is.finite(nm) & is.finite(val)
    ag <- stats::aggregate(val[keep], list(nm = nm[keep]),
                           FUN = function(z) mean(z, na.rm = TRUE))
    nm <- ag$nm; val <- ag$x
  }
  stopifnot(length(nm) >= 8, all(is.finite(nm)), all(is.finite(val)))
  score_nm <- nm; score_val <- NULL
  if (!is.null(nm_native) && !is.null(val_native) &&
      length(nm_native) == length(val_native) && length(val_native) >= 5L &&
      all(is.finite(nm_native)) && all(is.finite(val_native))) {
    score_nm  <- as.numeric(nm_native)
    score_val <- as.numeric(val_native)
    if (is.unsorted(score_nm) || anyDuplicated(score_nm)) {
      agn <- stats::aggregate(score_val, list(nm = score_nm),
                              FUN = function(z) mean(z, na.rm = TRUE))
      score_nm <- agn$nm; score_val <- agn$x
    }
  }

  # One generous seed pass on the (smoothed) fit curve; top-K by prominence/trial.
  all_seeds <- do.call(seed_peaks,
                       c(list(nm = nm, val = val, max_peaks = k_max), seed_args))
  all_seeds <- all_seeds[order(all_seeds$prominence, decreasing = TRUE), , drop = FALSE]
  k_req_min <- k_min; k_req_max <- k_max         # what the user asked for
  n_deriv   <- nrow(all_seeds)                   # numerical candidate features seeded by the 2nd derivative
  k_feasible <- .decon_max_feasible_k(length(nm))
  # Refuse an infeasible FLOOR rather than silently weakening it (never quietly change the
  # user's k_min, and never call the solver on a rank-deficient problem).
  if (k_req_min > k_feasible)
    stop(sprintf("decon: %d fitting points cannot support k_min = %d components (max feasible K = %d here: needs >= %d points/component and 3K+1 <= n - %d). Reduce Min components, widen the analysis / red-edge range, or use a finer grid.",
                 length(nm), k_req_min, k_feasible, DECON_MIN_PTS_PER_COMP, DECON_RESID_DF_MARGIN))
  # k_hi can still reach k_max via residual-deflation, but the feasibility ceiling is a
  # HARD upper bound (it wins even over the 2nd-derivative peak count).
  k_points_cap <- k_feasible
  k_hi <- min(k_max, max(n_deriv, k_points_cap))
  k_hi <- min(k_hi, k_feasible)                  # HARD feasibility cap
  if (k_hi < k_min) k_min <- k_hi                # only when k_min > k_max (user error); k_min <= k_feasible guaranteed
  # seed_limited now flags that the search had to SYNTHESIZE components beyond the
  # derivative-seeded candidate count to honor k_max (informational; such fits carry
  # the extra-component identifiability caveat surfaced via seed_note below).
  seed_limited     <- (n_deriv < k_req_max)
  seeds_synth_from <- if (n_deriv < k_hi) n_deriv + 1L else NA_integer_

  base_args <- c(list(nm = nm, val = val, nm_score = score_nm, val_score = score_val), fit_args)
  .fit_try <- function(seeds_try, mu_tol_over = NULL) {
    a <- base_args; a$seeds <- seeds_try
    if (!is.null(mu_tol_over)) a$mu_tol_nm <- mu_tol_over
    try(do.call(fit_pvoigt, a), silent = TRUE)
  }
  rng <- range(nm)
  # The residual-deflation prefix is deterministic for this curve. Extend it
  # once instead of re-fitting the same lower-count prefixes for every K.
  synth_seeds <- all_seeds
  .seeds_for_K <- function(K) {
    if (K <= n_deriv) return(all_seeds[seq_len(K), , drop = FALSE])
    msep <- as.numeric(if (!is.null(seed_args$min_sep_nm)) seed_args$min_sep_nm else 6)
    sd0 <- synth_seeds
    for (extra in seq_len(max(0L, K - nrow(sd0)))) {
      f <- .fit_try(sd0)
      resid_here <- if (!inherits(f, "try-error") && isTRUE(f$fit_usable)) (val - f$fitted)
                    else (val - stats::median(val, na.rm = TRUE))
      rp <- resid_here; rp[!is.finite(rp)] <- -Inf
      for (mu_ex in sd0$mu) rp[abs(nm - mu_ex) < msep] <- -Inf
      j <- which.max(rp)
      if (!length(j) || !is.finite(rp[j]) || rp[j] <= 0) {
        # no positive residual lobe left: seed the point furthest from any center
        dmin <- vapply(nm, function(x) min(abs(x - sd0$mu)), numeric(1))
        j <- which.max(dmin)
      }
      sd0 <- rbind(sd0, data.frame(mu = nm[j], amp = pmax(val[j], 1e-6),
                                   fwhm = stats::median(sd0$fwhm), prominence = 0))
    }
    synth_seeds <<- sd0
    sd0[seq_len(K), , drop = FALSE]
  }
  trials <- list(); rows <- list(); failures <- list()
  for (K in k_min:k_hi) {
    seeds_K <- .seeds_for_K(K)
    cand <- list(.fit_try(seeds_K))
    if (isTRUE(multistart)) {
      even_mu    <- seq(rng[1] + diff(rng)/(2*K), rng[2] - diff(rng)/(2*K), length.out = K)
      even_seeds <- data.frame(mu = even_mu,
                               amp = pmax(stats::approx(nm, val, even_mu, rule = 2)$y, 1e-6),
                               fwhm = rep(seeds_K$fwhm[1], K),
                               prominence = rep(1, K))
      wide_tol <- max(as.numeric(if (!is.null(fit_args$mu_tol_nm)) fit_args$mu_tol_nm else 8),
                      diff(rng)/(2*K))
      cand <- c(cand, list(
        .fit_try(even_seeds, mu_tol_over = wide_tol),
        .fit_try(transform(seeds_K, fwhm = pmax(seeds_K$fwhm * 0.6, 1))),
        .fit_try(transform(seeds_K, fwhm = seeds_K$fwhm * 1.6))))
    }
    ok_cand <- Filter(function(z) !inherits(z, "try-error") && isTRUE(z$fit_usable), cand)
    if (!length(ok_cand)) {
      msg <- tryCatch(trimws(conditionMessage(attr(cand[[1]], "condition"))),
                      error = function(e) "fit failed")
      failures[[length(failures) + 1L]] <-
        data.frame(K = K, reason = msg, stringsAsFactors = FALSE)
      next
    }
    sses <- vapply(ok_cand, function(z) as.numeric(z$gof$sse), numeric(1))
    trials[[as.character(K)]] <- ok_cand[[ which.min(sses) ]]
  }
  if (!length(trials)) stop("decon: no successful fit across K range.")
  failures_df <- if (length(failures)) do.call(rbind, failures) else NULL

  Ks_fit  <- sort(as.integer(names(trials)))
  rows <- lapply(Ks_fit, function(K) {
    tr <- trials[[as.character(K)]]
    g  <- tr$gof
    data.frame(K = K, r2 = g$r2, rmse = g$rmse,
               aic = g$aic, bic = g$bic, aicc = g$aicc,
               n_params = g$n_params, n_eff = g$n_eff, rho_lag1 = g$rho_lag1,
               optimizer_accepted = isTRUE(g$optimizer_accepted),
               optim_convergence_code = if (length(tr$optim_convergence_code)) suppressWarnings(as.integer(tr$optim_convergence_code)) else NA_integer_)
  })
  comparison <- do.call(rbind, rows)
  .min_sep <- as.numeric(if (!is.null(seed_args$min_sep_nm)) seed_args$min_sep_nm else 6)
  comparison$split <- vapply(comparison$K, function(K)
    .decon_split_guard(trials[[as.character(K)]]$components, .min_sep), logical(1))
  # which.min() returns integer(0) if every criterion value is non-finite (e.g. the
  # degenerate case where every K fits SSE ~ 0). Fall back to the smallest K so
  # selection can never index with integer(0).
  ic_vals  <- comparison[[criterion]]
  comparison$finite_criterion <- is.finite(ic_vals)
  comparison$admissible <- !comparison$split & comparison$optimizer_accepted & comparison$finite_criterion
  comparison$exclusion_reason <- vapply(seq_len(nrow(comparison)), function(i) {
    if (isTRUE(comparison$admissible[i])) return(NA_character_)
    why <- character(0)
    if (!isTRUE(comparison$finite_criterion[i]))   why <- c(why, sprintf("%s non-finite", toupper(criterion)))
    if (isFALSE(comparison$optimizer_accepted[i])) why <- c(why, "optimizer did not converge")
    if (isTRUE(comparison$split[i]))               why <- c(why, "triggered operational resolution guard")
    if (length(why)) paste(why, collapse = "; ") else "excluded"
  }, character(1))
  .fin_ic   <- which(is.finite(ic_vals))
  ic_argmin <- if (length(.fin_ic)) .fin_ic[which.min(ic_vals[.fin_ic])] else integer(0)
  best_K_ic <- if (length(ic_argmin)) comparison$K[ic_argmin] else NA_integer_
  raw_best_K <- best_K_ic
  cand_idx   <- which(comparison$admissible)
  if (length(cand_idx)) {
    wm <- cand_idx[which.min(ic_vals[cand_idx])]
    selected_K       <- comparison$K[wm]
    selection_status <- "selected"
    selection_reason <- sprintf("K=%d has the lowest %s score among admissible (optimizer-accepted, non-split, finite-score) candidates.",
                                selected_K, toupper(criterion))
  } else {
    selected_K       <- NA_integer_
    selection_status <- "no_admissible_candidate"
    .causes <- sprintf("K=%d: %s", comparison$K, comparison$exclusion_reason)
    .raw_ph <- if (is.finite(raw_best_K))
                 sprintf("the raw %s minimum is K=%d, reported for transparency but NOT selected", toupper(criterion), as.integer(raw_best_K))
               else sprintf("the raw %s minimum is unavailable", toupper(criterion))
    selection_reason <- sprintf("No admissible component count: %s. %s.", paste(.causes, collapse = "; "), .raw_ph)
  }
  best_K  <- selected_K
  .k_disp <- if (!is.na(selected_K)) selected_K
             else if (is.finite(raw_best_K) && !is.null(trials[[as.character(raw_best_K)]])) raw_best_K
             else min(comparison$K)
  best    <- trials[[as.character(.k_disp)]]
  .exc_ic <- { .ix <- match(best_K_ic, comparison$K)
               if (length(.ix) != 1L || is.na(.ix)) NA_character_ else comparison$exclusion_reason[.ix] }
  .exc_is_split <- identical(if (is.na(.exc_ic)) "" else .exc_ic,
                             "triggered operational resolution guard")
  k_guard_note <- if (is.finite(best_K_ic) && is.finite(best_K) && best_K_ic != best_K)
    sprintf(paste0("The %s is minimized at K=%d, but that model is not admissible: %s. The reported K=%d is the ",
                   "lowest-%s model among ADMISSIBLE candidates, not the raw all-candidate minimum.%s Compare the admissibility and ",
                   "exclusion-cause columns in the K table."),
            toupper(criterion), best_K_ic,
            if (is.na(.exc_ic)) "it was excluded by the admissibility guard" else .exc_ic,
            best_K, toupper(criterion),
            if (.exc_is_split)
              paste0(" (Two fitted centers triggered the operational resolution guard, or a component",
                     " collapsed to ~zero amplitude -- inspect the local, model-conditional center SEs.)")
            else "") else NA_character_

  boot <- NULL
  n_boot <- as.integer(n_boot)
  boot_status <- if (is.na(n_boot) || n_boot <= 0L) "not_requested" else "requested"
  boot_skip_reason <- NA_character_
  if (identical(boot_status, "requested") && !(k_hi > k_min)) {
    boot_status <- "skipped"
    boot_skip_reason <- sprintf(paste0("the effective component-count search covers a single K (k_min = k_max = %d), ",
                                       "so there is no K selection for a stability estimate to be about"),
                                as.integer(k_min))
  }
  if (identical(boot_status, "requested") && !is.null(score_val) &&
      (!identical(as.numeric(score_nm), as.numeric(nm)) ||
       !identical(as.numeric(score_val), as.numeric(val)))) {
    boot_status <- "skipped"
    boot_skip_reason <- paste0("native scoring data differ from the fit grid; a fit-grid residual bootstrap ",
      "would change the K-selection rule. Supply the same fit/scoring data or use a separately justified native-grid bootstrap.")
  }
  if (identical(boot_status, "requested")) {
    old_seed <- if (exists(".Random.seed", envir = globalenv(), inherits = FALSE))
                  get(".Random.seed", envir = globalenv()) else NULL
    # Restore the caller's RNG even if a bootstrap input or fitting error exits
    # this function before aggregation completes.
    on.exit({
      if (!is.null(old_seed)) assign(".Random.seed", old_seed, envir = globalenv())
      else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE))
        rm(".Random.seed", envir = globalenv())
    }, add = TRUE)
    fit_grid  <- best$fitted
    resid_b   <- best$residual
    nb        <- length(resid_b)
    Lblk      <- max(4L, as.integer(round(nb^(1/3))))
    nblk      <- as.integer(ceiling(nb / Lblk))
    starts    <- seq_len(max(1L, nb - Lblk + 1L))
    outcomes <- vector("list", n_boot)
    boot_pars <- list(); boot_areas <- list()
    for (b in seq_len(n_boot)) {
      set.seed(boot_seed + b)
      st   <- sample(starts, nblk, replace = TRUE)
      idxb <- as.integer(unlist(lapply(st, function(s) s:(s + Lblk - 1L))))[seq_len(nb)]
      y_b  <- fit_grid + resid_b[idxb]
      fb <- try(deconvolve_spectrum(nm, y_b, k_min = k_min, k_max = k_hi,
                                    criterion = criterion, seed_args = seed_args,
                                    fit_args = fit_args, n_boot = 0L, multistart = TRUE),
                silent = TRUE)
      .draw <- .decon_bootstrap_outcome(fb, b, boot_seed + b, k_min, k_hi, best_K)
      if (identical(.draw$outcome, "selected") && isTRUE(.draw$same_K)) {
        .pars <- tryCatch(.decon_bootstrap_parameters(fb, .draw$selected_K),
          error = function(e) list(parameters = NULL, areas = NULL, reason = conditionMessage(e)))
        .draw$parameter_usable <- !is.null(.pars$parameters)
        .draw$area_usable <- !is.null(.pars$areas)
        .draw$parameter_reason <- .pars$reason
        if (.draw$parameter_usable) boot_pars[[length(boot_pars) + 1L]] <- .pars$parameters
        if (.draw$area_usable) boot_areas[[length(boot_areas) + 1L]] <- .pars$areas
      }
      outcomes[[b]] <- .draw
      if (is.function(progress)) tryCatch(progress(b, n_boot), error = function(e) NULL)
    }
    boot <- .decon_bootstrap_summary(do.call(rbind, outcomes), k_min, k_hi,
      best_K, n_boot, Lblk, boot_seed, boot_pars, boot_areas)
    # Bootstrap components are matched by increasing center. Explicitly map
    # every SE back to the original component IDs rather than implying row order.
    ord <- order(best$components$mu_nm)
    ids <- best$components$component[ord]
    if (length(ids) != length(ord)) ids <- ord
    boot$component_order <- ord
    boot$component_ids <- ids
    boot$parameter_order <- as.vector(outer(c("amp", "mu_nm", "fwhm", "eta"), ids, paste, sep = "_"))
    boot$parameter_matching <- "increasing_mu_nm; component_ids_reference_original_component_table"
    if (!is.null(boot$param_se_boot)) names(boot$param_se_boot) <- boot$parameter_order
    if (!is.null(boot$area_se_boot)) names(boot$area_se_boot) <- as.character(ids)
 # the resample loop ran. `ran` covers both the all-succeeded and the every-resample-failed outcomes --
    # the per-resample counts inside `boot` (n_requested / n_boot / n_failed) tell those two apart, honestly.
    boot_status <- "ran"
  }

  seed_note <- if (is.finite(best_K) && best_K > n_deriv)
    sprintf(paste0("Selected K=%d exceeds the %d numerical candidate feature(s) seeded by the 2nd derivative; ",
                   "the extra component(s) were seeded by residual-deflation. Treat the ",
                   "additional modeled component(s) as tentative -- check the per-component identifiability ",
                   "flags (fwhm_at_bound / amp_near_zero / resolution_limited) and, ideally, ",
                   "the bootstrap K-stability (n_boot > 0)."),
            best_K, n_deriv) else NA_character_
  list(best = best, best_K = best_K, best_K_ic = best_K_ic, k_guard_note = k_guard_note,
       decon_result_schema = 3L,
       raw_best_K = raw_best_K, selected_K = selected_K, display_K = .k_disp,
       display_role = if (!is.na(selected_K)) "selected" else if (!is.null(best)) "diagnostic_not_selected" else "none",
       selection_status = selection_status, selection_reason = selection_reason,
       criterion = criterion,
       comparison = comparison, trials = trials, seeds = all_seeds,
       failures = failures_df,
       requested = c(k_min = k_req_min, k_max = k_req_max),
       effective = c(k_min = k_min, k_max = k_hi),
       n_deriv_seeds = n_deriv, seeds_synth_from = seeds_synth_from, seed_note = seed_note,
       seed_limited = seed_limited, boot = boot,
       boot_status = boot_status, boot_skip_reason = boot_skip_reason)
}

# =============================================================================
# 5. (OPTIONAL) MAP FITTED COMPONENTS TO THE APP'S NAMED BANDS
# =============================================================================
# Convenience: label each fitted component by which user band window its center
# falls in (Qy, carotenoid, etc.). `bands` is the app's bands object; the
# integrator should pass whatever structure carries (band, lo, hi). This is
# tolerant of column naming; adjust the accessor to match PASA.R's bands schema.

label_components_by_band <- function(components, bands) {
  if (is.null(bands)) { components$band <- NA_character_; return(components) }
  get_lohi <- function(b) {
    # Try common shapes: list(lo,hi) / c(lo,hi) / data.frame(min,max).
    if (is.numeric(b) && length(b) >= 2) return(c(min(b), max(b)))
    if (is.list(b) && all(c("lo","hi") %in% names(b))) return(c(b$lo, b$hi))
    if (is.list(b) && length(b) >= 2) return(c(min(unlist(b)), max(unlist(b))))
    c(NA, NA)
  }
  lab <- vapply(components$mu_nm, function(mu) {
    hit <- NA_character_
    for (nm_band in names(bands)) {
      lh <- get_lohi(bands[[nm_band]])
      if (all(is.finite(lh)) && mu >= lh[1] && mu <= lh[2]) { hit <- nm_band; break }
    }
    hit
  }, character(1))
  components$band <- lab
  components
}

# =============================================================================
# 6. EMPIRICAL INVERSE-POWER BASELINE CORRECTION
# =============================================================================
# INDEPENDENT PRE-PROCESSING HELPER. This is NOT part of the pseudo-Voigt core
# above: it is a standalone, pure numeric function that removes a sloped
# wavelength-dependent background BEFORE deconvolution. It is sourceable and
# unit-testable without the Shiny app and uses the module's optional minpack.lm
# path. It does NOT touch, and is not called by,
# seed_peaks() / fit_pvoigt() / deconvolve_spectrum().
#
# MODEL (fit on a user-selected tail window, then extrapolated backward and
# subtracted across the entire spectrum; the model does not establish that the
# window is absorption-free or identify the physical origin of the background):
#       S(lambda) = a * lambda^(-b) + c
#   a >= 0  amplitude of the empirical wavelength-dependent term.
#   b       empirical wavelength exponent. It is model- and window-dependent and
#           is not a particle-size measurement or a Rayleigh/Mie classifier.
#   c       wavelength-independent instrument offset (drift, cuvette mismatch,
#           dark current). This c REPLACES a single-nm / window offset baseline;
#           applying both subtracts the constant twice, so the integrator makes
#           them mutually exclusive app-side (offset baseline is bypassed for the
#           deconvolution input whenever this correction is on).
#
# ---------------------------------------------------------------------------
# b UPPER BOUND = 4.5. This numerical bound limits an otherwise weakly constrained
# extrapolation. Because a and b are strongly correlated in a*lambda^-b, a boundary
# optimum can distort the fitted amplitude and has unstable uncertainty. Values near
# the bound are therefore flagged as constraint- or noise-sensitive. The value 4.5
# is an operational fitting choice, not a physical ceiling; b_max remains configurable
# for study-specific sensitivity analysis.
# ---------------------------------------------------------------------------
# Returns a list: corrected, scattering, fit_ok, method ("powerlaw" |
# "median_fallback"), a, b, c, shift, n_tail, fit_start, fit_end,
# interpretation and warnings. Deterministic for a fixed fit object.

.scatter_interpret_b <- function(b) {
  if (!is.finite(b)) return("exponent undetermined")
  if (b >= 4.0) return("b >= 4: steep fitted wavelength dependence; check boundary sensitivity and tail-window adequacy")
  if (b >= 2.0) return("b ~ 2-4: steep fitted wavelength dependence; physical origin is not identified")
  if (b >= 0.5) return("b ~ 0.5-2: moderate fitted wavelength dependence; physical origin is not identified")
  "b -> 0: weak/near-flat fitted wavelength dependence; the empirical term may add little beyond an offset"
}

DECON_SCATTER_MIN_TAIL_PTS <- 10L

subtract_scattering <- function(nm, val, fit_start = 730, fit_end = 800,
                                b_max = 4.5, min_tail_pts = DECON_SCATTER_MIN_TAIL_PTS, covered = NULL,
                                check_extrap_ident = TRUE, ident_ci_frac = 0.75,
                                fixed_b = NULL, blank = NULL) {
  nm  <- as.numeric(nm); val <- as.numeric(val)
  if (length(nm) != length(val))
    stop(sprintf("subtract_scattering: nm and val must have equal length (got %d and %d).",
                 length(nm), length(val)))
  if (!is.null(blank)) {
    bl <- suppressWarnings(as.numeric(blank))
    if (length(bl) != length(val))
      stop(sprintf("subtract_scattering: blank must match val length (got %d and %d).",
                   length(bl), length(val)))
    fin <- is.finite(bl)
    if (!any(fin))
      stop("subtract_scattering: a supplied measured blank has no finite aligned values; correction was refused. Fix or remove the blank explicitly.")
    if (any(fin)) {
      bl_sub <- ifelse(fin, bl, 0)                 # subtract only where measured
      scat   <- ifelse(fin, bl, NA_real_)          # NA = unavailable (not corrected here)
      warns  <- if (!all(fin))
        sprintf("Measured blank covers %d of %d wavelengths; the remaining %d are left uncorrected (the blank did not span the full corrected range).",
                sum(fin), length(bl), sum(!fin)) else character(0)
      blue_fin <- if (any(fin)) bl[fin][which.min(nm[fin])] else NA_real_
      return(list(corrected = val - bl_sub, scattering = scat,
                  fit_ok = TRUE, method = "measured_blank",
                  a = NA_real_, b = NA_real_, c = NA_real_, shift = 0,
                  n_tail = NA_integer_, fit_start = NA_real_, fit_end = NA_real_,
                  b_ident_range = c(NA_real_, NA_real_), blue_ref = NA_real_,
                  scat_blue = blue_fin, scat_blue_range = c(NA_real_, NA_real_),
                  interpretation = if (all(fin))
                    "Measured blank/turbidity curve subtracted directly (no power-law extrapolation)."
                    else "Measured blank subtracted on its measured range only; wavelengths outside the blank's coverage were left uncorrected (no endpoint extrapolation).",
                  warnings = warns))
    }
  }
  b_is_fixed <- !is.null(fixed_b) && is.finite(suppressWarnings(as.numeric(fixed_b)[1]))
  if (b_is_fixed) fixed_b <- as.numeric(fixed_b)[1]
  if (length(fit_start) != 1L || length(fit_end) != 1L ||
      !is.finite(fit_start) || !is.finite(fit_end))
    stop("subtract_scattering: tail start and end must each be one finite wavelength.")
  cov <- if (is.null(covered) || length(covered) != length(nm)) rep(TRUE, length(nm)) else as.logical(covered)
  fin  <- is.finite(nm)
  meas <- fin & cov                      # genuinely-measured wavelength nodes
  data_min <- if (any(meas)) min(nm[meas]) else NA_real_
  data_max <- if (any(meas)) max(nm[meas]) else NA_real_
  warn <- character(0)

  # --- Guard the tail window against the actual data range. -------------------
  # If the loaded spectrum does not extend to fit_end (a common case: e.g. data
  # stops at 750 nm but the default window ends at 800), clamp to what exists and
  # say so loudly rather than fitting on the wrong / too-few points.
  eff_start <- max(fit_start, data_min, na.rm = TRUE)
  eff_end   <- min(fit_end,   data_max, na.rm = TRUE)
  if (is.finite(data_max) && fit_end > data_max + 1e-9)
    warn <- c(warn, if (eff_end > eff_start) sprintf(
      "Requested tail end %.0f nm exceeds the data (max %.0f nm); fitting on %.0f-%.0f nm only. A short lever arm makes the exponent b poorly determined.",
      fit_end, data_max, eff_start, eff_end) else sprintf(
      "The data end at %.0f nm, below the requested tail start %.0f nm; no tail interval is available.", data_max, fit_start))
  if (is.finite(data_min) && fit_start < data_min - 1e-9)
    warn <- c(warn, sprintf(
      "Requested tail start %.0f nm is below the data (min %.0f nm).", fit_start, data_min))

  idx    <- meas & is.finite(val) & nm >= eff_start & nm <= eff_end
  n_tail <- sum(idx)

  # Graceful degradation: flat-median subtraction (== a plain offset baseline).
  # The integrator MUST surface fit_ok = FALSE in the UI, because this silently
  # degrades to exactly the vertical-offset behavior the power law replaces.
  fallback <- function(extra = character(0)) {
    flat <- if (n_tail >= 1) stats::median(val[idx], na.rm = TRUE) else 0
    if (!is.finite(flat)) flat <- 0
    list(corrected = val - flat, scattering = rep(flat, length(val)),
         fit_ok = FALSE, method = "median_fallback",
         a = NA_real_, b = NA_real_, c = flat, shift = 0, n_tail = n_tail,
         fit_start = eff_start, fit_end = eff_end,
         interpretation = "Flat-median fallback: degrades to a plain offset subtraction (the behavior the power-law model is meant to replace) - the removed baseline has NO slope.",
         warnings = c(warn, extra))
  }

  if (!is.finite(eff_start) || !is.finite(eff_end) || eff_end <= eff_start)
    return(fallback("Tail window is empty or inverted after clamping to the data range."))
  if (n_tail < min_tail_pts)
    return(fallback(sprintf("Only %d point(s) in the tail window (need >= %d) - using a flat median offset.",
                            n_tail, min_tail_pts)))

  tail_nm  <- nm[idx]; tail_val <- val[idx]

  # --- The y-shift and additive constant are partially confounded. -----------
  # nlsLM tolerates a negative c, but a strictly positive tail keeps the
  # a*x^-b + c start well-conditioned. If the tail dips below zero for any
  # source- or preprocessing-dependent reason, lift it by |min| + eps for the fit, then undo the shift
  # on the predicted curve. CAVEAT: the shift is folded entirely into c, so the
  # RECOVERED c = (fitted_c - shift). A large shift (tail with substantial
  # negative OD) therefore biases the additive constant - we sanity-check its
  # size and warn.
  min_tail <- min(tail_val, na.rm = TRUE)
  shift    <- if (is.finite(min_tail) && min_tail < 0) abs(min_tail) + 1e-3 else 0
  tail_span <- diff(range(tail_val, na.rm = TRUE))
  if (shift > 0 && is.finite(tail_span) && tail_span > 0 && shift > 0.5 * tail_span)
    warn <- c(warn, "Tail contains large negative values; their source depends on the input and preprocessing, and the y-shift used for fitting may bias the constant term c. Inspect the tail window.")
  fit_y <- tail_val + shift

  # Scale nm -> nm/1000 so 'a' stays well-conditioned (a absorbs the constant
  # 1000^b factor; the exponent b is unchanged by the scaling). The SAME scaling
  # is used when the curve is extrapolated across the full spectrum below.
  fit_x <- tail_nm / 1000

  if (b_is_fixed) {
    # User-fixed-exponent mode. b is held at the supplied value;
    # only a and c are fit, by ordinary linear least squares on the tail (the model
    # is linear in a and c once b is fixed). This removes the noise-driven free-b
    # extrapolation blow-up entirely. a is constrained >= 0 as an inverse-power
    # amplitude; if the unconstrained slope is negative, the selected tail does not
    # support that decreasing baseline shape and we use a flat median offset.
    if (fixed_b == 0) {
      # At b=0, a and c are indistinguishable. Use the identifiable constant.
      a_hat <- 0; b_hat <- 0; c_hat <- mean(tail_val)
    } else {
      u <- fit_x^(-fixed_b)
      lf <- stats::lm.fit(cbind(1, u), fit_y)
      cc <- as.numeric(lf$coefficients)
      a_hat <- cc[2]; b_hat <- fixed_b; c_hat <- cc[1] - shift
    }
    if (!is.finite(a_hat) || !is.finite(c_hat))
      return(fallback("Fixed-exponent linear fit failed - using a flat median offset."))
    if (a_hat < 0)
      return(fallback(sprintf("Fixed exponent b=%.2f implies a NEGATIVE inverse-power amplitude on this tail; using a flat median offset.", fixed_b)))
    warn <- c(warn, if (fixed_b == 0)
      "Exponent b=0 specifies a constant background: amplitude a is set to zero and offset c is the tail mean."
      else sprintf("Inverse-power exponent held FIXED at b=%.2f (user-specified, not estimated); only amplitude a and offset c were fit. Extrapolation depends on whether this value is appropriate for the selected sample, window, and instrument.", fixed_b))
  } else {
    fit <- NULL
    if (.pasa_minpack_available()) {
      fit <- try(minpack.lm::nlsLM(
          fit_y ~ a * (fit_x)^(-b) + c,
          start   = list(a = mean(fit_y, na.rm = TRUE), b = 4, c = 0),
          lower   = c(a = 0,   b = 0,     c = -Inf),
          upper   = c(a = Inf, b = b_max, c =  Inf),
          control = minpack.lm::nls.lm.control(maxiter = 200)
        ), silent = TRUE)
    } else {
      return(fallback("minpack.lm not available; empirical inverse-power baseline fit degraded to a flat-median offset."))
    }
    if (is.null(fit) || inherits(fit, "try-error"))
      return(fallback("Power-law fit did not converge - using a flat median offset."))

    co    <- stats::coef(fit)
    a_hat <- as.numeric(co[["a"]]); b_hat <- as.numeric(co[["b"]])
    c_hat <- as.numeric(co[["c"]]) - shift    # undo the fit-only y-shift
  }
  # Extrapolate S(lambda) across the WHOLE spectrum and subtract. Computed
  # directly from coefficients (identical to predict() but avoids nls newdata
  # quirks and is trivially deterministic).
  scat <- a_hat * (nm / 1000)^(-b_hat) + c_hat

  # --- identifiability + stability guards (reject unidentifiable fits) -------
  # A "converged" fit is not automatically a MEANINGFUL one. On a short or
  # noise-dominated tail the three parameters a, b, c are not separable (a and c
  # are collinear over a narrow lambda span, and b is fixed by curvature the
  # noise swamps), so nlsLM can return a solution that either fits the tail no
  # better than a flat line or extrapolates absurdly toward the blue. In both
  # cases the honest result is the flat-median offset, not a confident power law.
  #   (1) Identifiability (scale-free): the sloped model must beat a flat
  #       constant on the tail by a clear margin, else its "slope" is just noise.
  tail_pred <- a_hat * (tail_nm / 1000)^(-b_hat) + c_hat
  rmse_pl   <- sqrt(mean((tail_val - tail_pred)^2))
  rmse_flat <- sqrt(mean((tail_val - mean(tail_val))^2))
  flat_eps  <- 1e-6 * max(abs(tail_val), 1e-9, na.rm = TRUE)
  ident_bad <- !is.finite(rmse_flat) || rmse_flat <= flat_eps || rmse_pl > 0.9 * rmse_flat
  #   (2) Stability: the baseline that gets SUBTRACTED must stay within a
  #       numerical scale of the data it is subtracted from (a blow-up guard).
  dscale <- max(abs(val), na.rm = TRUE)
  blowup <- any(!is.finite(scat)) ||
            (is.finite(dscale) && max(abs(scat), na.rm = TRUE) > 3 * dscale + 1e-9)
  if ((!b_is_fixed && ident_bad) || blowup)
    return(fallback(sprintf(
      "Inverse-power fit on the %.0f-%.0f nm tail is not identifiable (%s); using a flat median offset instead. Estimating an exponent requires a wider, cleaner, study-justified tail window; no fixed wavelength is guaranteed to be absorption-free.",
      eff_start, eff_end,
      if (ident_bad) "the sloped model fits the tail no better than a flat constant"
      else "the fitted curve blows up when extrapolated to the blue")))

  blue_ref      <- if (is.finite(data_min)) data_min else min(nm)
  scat_blue_hat <- a_hat * (blue_ref / 1000)^(-b_hat) + c_hat
  b_ident_range <- c(NA_real_, NA_real_); scat_blue_range <- c(NA_real_, NA_real_)
  if (!b_is_fixed && isTRUE(check_extrap_ident) && n_tail >= min_tail_pts && n_tail > 3L) {
    b_grid <- seq(0.2, b_max, length.out = 25L)
    prof <- vapply(b_grid, function(bf) {
      u  <- fit_x^(-bf)
      lf <- stats::lm.fit(cbind(1, u), fit_y)      # profile out (c+shift) and a at fixed b
      cc <- as.numeric(lf$coefficients)             # c(intercept = c+shift, slope = a)
      pred <- cc[1] + cc[2] * u
      sse  <- sum((fit_y - pred)^2)
      blue <- cc[2] * (blue_ref / 1000)^(-bf) + (cc[1] - shift)
      c(as.numeric(sse), as.numeric(blue))
    }, numeric(2))
    sse_b  <- prof[1, ]; blue_b <- prof[2, ]
    sse_min <- min(sse_b, na.rm = TRUE)
    # Operational F(0.9)-threshold profile-sensitivity set for b. This reuses a
    # familiar regression threshold as a guard; it is not a calibrated 90% confidence
    # set for this bounded, selected-window extrapolation.
    mult   <- 1 + stats::qf(0.90, 1, max(n_tail - 3L, 1L)) / max(n_tail - 3L, 1L)
    accept <- is.finite(sse_b) & (sse_b <= sse_min * mult + 1e-24)
    if (any(accept)) {
      b_ident_range   <- range(b_grid[accept])
      scat_blue_range <- range(blue_b[accept])
      halfw <- diff(scat_blue_range) / 2
      denom <- max(abs(scat_blue_hat), 0.05 * max(abs(val), na.rm = TRUE), 1e-9)
      if (is.finite(halfw) && halfw > ident_ci_frac * denom)
        return(fallback(sprintf(
          "Inverse-power exponent is not identified for stable extrapolation: exponents that fit the %.0f-%.0f nm tail similarly (b in [%.2f, %.2f]) imply an extrapolated baseline at %.0f nm spanning [%.3g, %.3g]. A short tail can constrain the fitted window without constraining the extrapolation; using a flat median offset instead.",
          eff_start, eff_end, b_ident_range[1], b_ident_range[2],
          blue_ref, scat_blue_range[1], scat_blue_range[2])))
    }
  }

  corrected <- val - scat

  # Boundary-proximity diagnostics on b: flag high or bound-pinned exponents as
  # constraint/noise sensitive without assigning a physical scattering regime.
  if (is.finite(b_hat) && b_hat >= 4.0)
    warn <- c(warn, sprintf("Fitted b = %.2f is high relative to the operational review threshold (4.0) and may be boundary- or noise-driven; the exponent is not a particle-size or scattering-regime measurement.", b_hat))
  if (is.finite(b_hat) && (b_max - b_hat) < 0.05)
    warn <- c(warn, "Fitted b is pinned against the upper bound and is boundary-limited or poorly identified under this fit; inspect tail-window and bound sensitivity.")

  list(corrected = corrected, scattering = scat,
       fit_ok = TRUE, method = if (b_is_fixed) "powerlaw_fixed_b" else "powerlaw",
       a = a_hat, b = b_hat, c = c_hat, shift = shift, n_tail = n_tail,
       fit_start = eff_start, fit_end = eff_end,
       b_ident_range = b_ident_range, blue_ref = blue_ref,
       scat_blue = scat_blue_hat, scat_blue_range = scat_blue_range,
       interpretation = .scatter_interpret_b(b_hat), warnings = warn)
}

# =============================================================================
# END MODULE
# =============================================================================
