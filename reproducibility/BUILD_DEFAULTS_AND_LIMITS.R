#!/usr/bin/env Rscript

# Build a machine-readable registry of PASA defaults, operational limits, and
# tested-range boundaries from the executable source. The registry is retained
# in both the complete public release and the article-linked replay archive.

options(warn = 1)

full_args <- commandArgs(trailingOnly = FALSE)
file_arg <- full_args[startsWith(full_args, "--file=")]
if (length(file_arg) != 1L) stop("Run this file with Rscript.")
script_path <- normalizePath(sub("--file=", "", file_arg[[1L]], fixed = TRUE),
                             winslash = "/", mustWork = TRUE)
repro_dir <- dirname(script_path)
package_root <- normalizePath(file.path(repro_dir, ".."), winslash = "/",
                              mustWork = TRUE)
app_dir <- file.path(package_root, "source_snapshot")
app_file <- file.path(app_dir, "PASA.R")
module_file <- file.path(app_dir, "deconvolution_module.R")
loader_file <- file.path(repro_dir, "LOAD_LOCKED_ENVIRONMENT.R")
output_file <- file.path(repro_dir, "PASA_DEFAULTS_AND_LIMITS.tsv")

for (required in c(app_file, module_file, loader_file)) {
  if (!file.exists(required)) stop("Missing required file: ", required)
}
source(loader_file, local = TRUE, encoding = "UTF-8")
load_pasa_locked_environment(package_root)
extra_lib <- Sys.getenv("PASA_R_LIB", unset = "")
if (nzchar(extra_lib) && dir.exists(extra_lib))
  .libPaths(unique(c(normalizePath(extra_lib, winslash = "/"), .libPaths())))

Sys.setenv(SPECTRA_DESKTOP_MODE = "1", PASA_APP_DIR = app_dir)
old_wd <- getwd()
on.exit(setwd(old_wd), add = TRUE)
setwd(app_dir)
app_env <- new.env(parent = globalenv())
app_expr <- parse(file = app_file, keep.source = FALSE)
app_last <- paste(deparse(app_expr[[length(app_expr)]]), collapse = "")
if (!grepl("^shinyApp\\s*\\(", trimws(app_last)))
  stop("PASA.R no longer ends with shinyApp(ui, server).")
eval(app_expr[-length(app_expr)], envir = app_env)
module_env <- new.env(parent = globalenv())
eval(parse(file = module_file, keep.source = FALSE), envir = module_env)

required_app <- c(
  "RELEASE_ID", "INPUT_LIMITS", "GROWTH_CONST", "GROWTH_MIN_LOG_RISE",
  "SIM_ROUGHNESS_MAX", "SIM_MIN_DYNRANGE", "SIM_MIN_SNR",
  ".SIM_BUDGET_TRACE_STOPS", ".SIM_TRACE_HARD_MAX", ".SIM_UI_PAIR_LIMIT",
  "AUC_MAX_GAP_NM",
  "COVERAGE_ABS_MAX_GAP_NM", "RESAMPLE_BIN_TOL", "DECON_CLASS_PRESETS",
  ".decon_depth_cap", ".decon_effective_k",
  ".pasa_feedback_config"
)
required_module <- c(
  "seed_peaks", "fit_pvoigt", "deconvolve_spectrum",
  "DECON_MIN_PTS_PER_COMP", "DECON_RESID_DF_MARGIN"
)
missing_app <- required_app[!vapply(required_app, exists, logical(1),
                                    envir = app_env, inherits = FALSE)]
missing_module <- required_module[!vapply(required_module, exists, logical(1),
                                          envir = module_env, inherits = FALSE)]
if (length(missing_app) || length(missing_module)) {
  stop("Missing defaults/limits symbols: ",
       paste(c(missing_app, missing_module), collapse = ", "))
}

app_text <- paste(readLines(app_file, warn = FALSE, encoding = "UTF-8"),
                  collapse = "\n")
module_text <- paste(readLines(module_file, warn = FALSE, encoding = "UTF-8"),
                     collapse = "\n")
expect_source <- function(id, pattern, text) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop("Source contract not found for ", id, ": ", pattern)
  }
  invisible(TRUE)
}

# Verify function-local and structural values that are not exported constants.
expect_source("pair-local union grid", "sort\\(unique\\(c\\(na, nb\\)\\)\\)", app_text)
expect_source("linear interpolation", "stats::approx\\(na, va, xout = g", app_text)
expect_source("minimum overlap", "SIM_MIN_OVERLAP_NM <- 40", app_text)
expect_source("minimum coverage", "SIM_MIN_COVER_FRAC <- 0\\.5", app_text)
expect_source("minimum native support", "n_min_native < 10", app_text)
expect_source("similarity second-derivative span", "SIM_D2_SPAN_NM <- 15", app_text)
expect_source("r/SAM tier thresholds",
              "r_analysis >= 0\\.995 && sam_deg <= 2", app_text)
expect_source("decon bootstrap count", "n_boot <- if \\(isTRUE\\(input\\$decon_bootstrap\\)\\) 80L else 0L", app_text)
expect_source("decon four-start multistart", "cand <- list\\(\\.fit_try\\(seeds_K\\)\\)", module_text)
expect_source("decon even multistart", "\\.fit_try\\(even_seeds", module_text)
expect_source("decon narrow multistart", "fwhm = pmax\\(seeds_K\\$fwhm \\* 0\\.6", module_text)
expect_source("decon broad multistart", "fwhm = seeds_K\\$fwhm \\* 1\\.6", module_text)
expect_source("moving-block length", "max\\(4L, as.integer\\(round\\(nb\\^\\(1/3\\)\\)\\)\\)", module_text)
expect_source("feedback explicit submit event", "observeEvent\\(input\\$fb_submit", app_text)
expect_source("growth bootstrap maximum", "GROWTH_BOOT_MAX <- 200L", app_text)
expect_source("shared eta model", "broadcast the shared eta to every band", module_text)
for (factory_default in c(
  "advanced_mode[^\\n]*= FALSE", "decon_depth[^\\n]*= \"tested\"",
  "decon_kmin[^\\n]*= 1", "decon_kmax[^\\n]*= 4",
  "decon_mu_tol[^\\n]*= 8", "decon_fwhm_min[^\\n]*= 8",
  "decon_fwhm_max[^\\n]*= 50", "decon_seed_win[^\\n]*= 15",
  "decon_criterion[^\\n]*= \"bic\"", "decon_bootstrap[^\\n]*= FALSE",
  "growth_boot[^\\n]*= FALSE"
)) expect_source("factory default", factory_default, app_text)

value_of_formal <- function(fun, name) {
  expr <- formals(fun)[[name]]
  if (is.null(expr)) return(NA)
  eval(expr, envir = baseenv())
}
scalar_text <- function(value) {
  if (length(value) == 0L || is.null(value)) return("")
  if (is.logical(value)) return(ifelse(isTRUE(value), "true", "false"))
  if (is.numeric(value)) return(paste(format(value, scientific = FALSE,
                                                   trim = TRUE), collapse = ","))
  paste(as.character(value), collapse = ",")
}

factory_defaults <- list(
  advanced_mode = FALSE, decon_depth = "tested", decon_kmin = 1,
  decon_kmax = 4, decon_mu_tol = 8, decon_fwhm_min = 8,
  decon_fwhm_max = 50, decon_seed_win = 15, decon_criterion = "bic",
  decon_bootstrap = FALSE, growth_boot = FALSE
)
snap <- function(key) factory_defaults[[key]]
limits <- app_env$INPUT_LIMITS
growth <- app_env$GROWTH_CONST
presets <- app_env$DECON_CLASS_PRESETS
seed_formals <- formals(module_env$seed_peaks)
fit_formals <- formals(module_env$fit_pvoigt)
decon_formals <- formals(module_env$deconvolve_spectrum)
default_feedback <- app_env$.pasa_feedback_config(
  getenv = function(key, unset = "") unset
)
opted_out_feedback <- app_env$.pasa_feedback_config(
  getenv = function(key, unset = "") if (identical(key, "PASA_FEEDBACK_ENABLED")) "0" else unset
)
incomplete_custom_feedback <- app_env$.pasa_feedback_config(
  getenv = function(key, unset = "") if (identical(key, "PASA_FEEDBACK_FORM_URL")) "https://example.invalid/form" else unset
)

stopifnot(
  identical(app_env$.decon_depth_cap("tested"), 4L),
  identical(app_env$.decon_depth_cap("advanced"), 20L),
  isTRUE(app_env$.decon_effective_k("tested", 1, 4)$ok),
  identical(app_env$.decon_effective_k("tested", 1, 4)$kmax, 4L),
  # Restored default (FEEDBACK_AND_TOUR_CLOSE.md): the bundled Google Form is on,
  # PASA_FEEDBACK_ENABLED=0 opts out, and an incomplete custom endpoint disables
  # direct submission instead of falling back to the bundled form.
  isTRUE(default_feedback$enabled), isTRUE(default_feedback$builtin),
  grepl("^https://docs\\.google\\.com/forms/", default_feedback$url),
  !isTRUE(opted_out_feedback$enabled), !nzchar(opted_out_feedback$url),
  !isTRUE(incomplete_custom_feedback$enabled), !nzchar(incomplete_custom_feedback$url)
)

rows <- list()
add <- function(section, setting, value, unit, role, source_locator,
                evidence_status, note) {
  rows[[length(rows) + 1L]] <<- data.frame(
    section = section,
    setting = setting,
    value = scalar_text(value),
    unit = unit,
    role = role,
    source_locator = source_locator,
    evidence_status = evidence_status,
    note = note,
    stringsAsFactors = FALSE
  )
}

# Input contract and resource guards.
add("Input", "raw_file_size_max", limits$raw_bytes / 1024^2, "MiB", "hard limit",
    "PASA.R: INPUT_LIMITS$raw_bytes", "source-evaluated", "Whole input is refused above the limit.")
add("Input", "expanded_table_size_max", limits$expanded_bytes / 1024^2, "MiB", "hard limit",
    "PASA.R: INPUT_LIMITS$expanded_bytes", "source-evaluated", "Approximate in-memory table size.")
add("Input", "sample_columns_max", limits$max_cols, "columns", "hard limit",
    "PASA.R: INPUT_LIMITS$max_cols", "source-evaluated", "Excludes the wavelength column.")
add("Input", "rows_max", limits$max_rows, "rows", "hard limit",
    "PASA.R: INPUT_LIMITS$max_rows", "source-evaluated", "Whole input is refused above the limit.")
add("Input", "cells_max", limits$max_cells, "cells", "hard limit",
    "PASA.R: INPUT_LIMITS$max_cells", "source-evaluated", "Rows multiplied by all columns.")

# Similarity numerical domain, guards, and descriptive tiers.
add("Similarity", "pair_grid", "sorted union of both native wavelength grids", "text", "contract",
    "PASA.R: compute_similarity()/.sim_union_interpolate()", "static-source-verified",
    "Each curve is linearly interpolated on this pair-local grid, then masked to physical overlap and joint measured coverage.")
add("Similarity", "interpolation", "linear; no retained endpoint extrapolation", "text", "contract",
    "PASA.R: .sim_union_interpolate() and coverage mask", "static-source-verified",
    "approx(rule=1) leaves points outside each trace's native span missing; physical-overlap and coverage masks define scored support.")
add("Similarity", "weighting", "trapezoidal wavelength weights", "text", "contract",
    "PASA.R: .sim_trap_weights()", "source-evaluated", "Finite-run endpoints receive half-interval weights.")
add("Similarity", "minimum_overlap", 40, "nm", "refusal threshold",
    "PASA.R: compute_similarity()/SIM_MIN_OVERLAP_NM", "static-source-verified", "Below this shared span metrics are withheld.")
add("Similarity", "minimum_native_support_per_trace", 10, "nodes", "refusal threshold",
    "PASA.R: compute_similarity()/n_min_native", "static-source-verified", "Minimum of the two in-range native-node counts.")
add("Similarity", "minimum_joint_coverage_fraction", 0.5, "fraction", "refusal threshold",
    "PASA.R: compute_similarity()/SIM_MIN_COVER_FRAC", "static-source-verified", "Below this jointly covered span metrics are withheld.")
add("Similarity", "coverage_gap_floor", app_env$AUC_MAX_GAP_NM, "nm", "operational limit",
    "PASA.R: AUC_MAX_GAP_NM", "source-evaluated", "Starting floor for adaptive measured-coverage guards.")
add("Similarity", "coverage_step_multiplier", app_env$RESAMPLE_BIN_TOL, "x modal native step", "operational limit",
    "PASA.R: RESAMPLE_BIN_TOL", "source-evaluated", "Used in adaptive coverage-gap construction.")
add("Similarity", "coverage_mask_absolute_gap_max", app_env$COVERAGE_ABS_MAX_GAP_NM, "nm", "hard limit",
    "PASA.R: COVERAGE_ABS_MAX_GAP_NM", "source-evaluated", "Caps sparse-grid interpolation support in the measured-coverage mask.")
add("Similarity", "tier_1", "r >= 0.995 and SAM <= 2", "r; degrees", "development threshold",
    "PASA.R: compute_similarity()", "static-source-verified", "Descriptive operational label; not a validated acceptance threshold.")
add("Similarity", "tier_2", "r >= 0.99 and SAM <= 4", "r; degrees", "development threshold",
    "PASA.R: compute_similarity()", "static-source-verified", "Applied only when tier 1 is not met.")
add("Similarity", "tier_3", "r >= 0.95 and SAM <= 10", "r; degrees", "development threshold",
    "PASA.R: compute_similarity()", "static-source-verified", "Otherwise the fourth/lower-similarity label is used.")
add("Similarity", "roughness_gate", app_env$SIM_ROUGHNESS_MAX, "ratio", "development threshold",
    "PASA.R: SIM_ROUGHNESS_MAX", "source-evaluated", "Advisory signal-evaluability gate.")
add("Similarity", "minimum_dynamic_range", app_env$SIM_MIN_DYNRANGE, "entered units", "development threshold",
    "PASA.R: SIM_MIN_DYNRANGE", "source-evaluated", "Flat/below-floor traces are withheld.")
add("Similarity", "minimum_feature_to_noise", app_env$SIM_MIN_SNR, "ratio", "development threshold",
    "PASA.R: SIM_MIN_SNR", "source-evaluated", "Consulted after the roughness gate.")
add("Similarity", "default_trace_budget", app_env$.sim_budget_cap(app_env$.sim_budget_default_index()), "traces", "default",
    "PASA.R: .SIM_BUDGET_TRACE_STOPS/.sim_budget_default_index()", "source-evaluated", "All-pairs work above this requires explicit authorization.")
add("Similarity", "hard_trace_ceiling", app_env$.SIM_TRACE_HARD_MAX, "traces", "hard limit",
    "PASA.R: .SIM_TRACE_HARD_MAX", "source-evaluated", "Applies even to the consented no-limit setting.")
add("Similarity", "ui_pair_projection_limit", app_env$.SIM_UI_PAIR_LIMIT, "pairs", "presentation limit",
    "PASA.R: .SIM_UI_PAIR_LIMIT", "source-evaluated", "Caps the lossy interactive table/network projection; canonical exports retain every computed pair.")
add("Similarity", "second_derivative_span", 15, "nm", "advisory parameter",
    "PASA.R: compute_similarity()/SIM_D2_SPAN_NM", "static-source-verified", "Wavelength span used by the advisory second-derivative similarity metric.")

# Deconvolution defaults, tested/advanced boundaries, and optimization design.
add("Deconvolution", "advanced_mode_default", snap("advanced_mode"), "logical", "default",
    "PASA.R: snapshot factory defaults", "source-evaluated", "Deconvolution tab is absent until Advanced Mode is enabled.")
add("Deconvolution", "search_depth_default", snap("decon_depth"), "text", "default",
    "PASA.R: snapshot factory defaults", "source-evaluated", "Tested range is the default depth.")
add("Deconvolution", "k_min_default", snap("decon_kmin"), "components", "default",
    "PASA.R: snapshot factory defaults", "source-evaluated", "Lower bound of the component-count sweep.")
add("Deconvolution", "k_max_default", snap("decon_kmax"), "components", "default",
    "PASA.R: snapshot factory defaults", "source-evaluated", "Matches the upper K exercised by the separately distributed recovery study.")
add("Deconvolution", "packaged_recovery_tested_K", "1-4", "components", "tested range",
    "docs/RECOVERY_EVIDENCE_SCOPE.md", "study-scope declaration", "The original study evidence is distributed separately; this package records its reported K=1-4 scope, not a new validation.")
add("Deconvolution", "advanced_opt_in_k_max", app_env$.decon_depth_cap("advanced"), "components", "advanced hard limit",
    "PASA.R: .decon_depth_cap()", "source-evaluated", "K > 4 is an uncharacterized sensitivity analysis.")
add("Deconvolution", "criterion_default", paste0(toupper(snap("decon_criterion")), "-like plug-in score"), "text", "default",
    "PASA.R: snapshot factory defaults", "source-evaluated", "Not a classical likelihood-based information criterion.")
add("Deconvolution", "mu_tolerance_default", snap("decon_mu_tol"), "nm", "default",
    "PASA.R: snapshot factory defaults", "source-evaluated", "Configurable center displacement from each seed.")
add("Deconvolution", "fwhm_min_default_complexes", presets$complexes$fwhm_min, "nm", "default",
    "PASA.R: DECON_CLASS_PRESETS$complexes", "source-evaluated", "Configurable development preset.")
add("Deconvolution", "fwhm_max_default_complexes", presets$complexes$fwhm_max, "nm", "default",
    "PASA.R: DECON_CLASS_PRESETS$complexes", "source-evaluated", "Configurable development preset.")
add("Deconvolution", "seed_window_default", snap("decon_seed_win"), "nm", "default",
    "PASA.R: snapshot factory defaults", "source-evaluated", "Converted to an odd node window for derivative seeding.")
add("Deconvolution", "seed_minimum_separation", value_of_formal(module_env$seed_peaks, "min_sep_nm"), "nm", "development threshold",
    "deconvolution_module.R: seed_peaks()", "source-evaluated", "Also supplies the split-guard floor when local SEs are unavailable.")
add("Deconvolution", "seed_prominence_fraction", value_of_formal(module_env$seed_peaks, "prominence_frac"), "fraction", "development threshold",
    "deconvolution_module.R: seed_peaks()", "source-evaluated", "Relative to the strongest second-derivative candidate.")
add("Deconvolution", "multistart_candidate_starts_per_K", 4, "starts", "algorithm design",
    "deconvolution_module.R: deconvolve_spectrum()", "static-source-verified", "Initial derivative seeds, evenly spaced centers, 0.6x FWHM, and 1.6x FWHM.")
add("Deconvolution", "bootstrap_default", snap("decon_bootstrap"), "logical", "default",
    "PASA.R: snapshot factory defaults", "source-evaluated", "Off unless explicitly requested.")
add("Deconvolution", "bootstrap_resamples_when_enabled", 80, "resamples", "default",
    "PASA.R: decon fit request", "static-source-verified", "K-stability heuristic, not a confidence statement.")
add("Deconvolution", "bootstrap_seed", value_of_formal(module_env$deconvolve_spectrum, "boot_seed"), "integer", "default",
    "deconvolution_module.R: deconvolve_spectrum()", "source-evaluated", "Each resample uses seed plus resample index.")
add("Deconvolution", "bootstrap_block_length", "max(4, round(n^(1/3)))", "nodes", "algorithm design",
    "deconvolution_module.R: deconvolve_spectrum()", "static-source-verified", "Moving-block residual bootstrap.")
add("Deconvolution", "minimum_points_per_component", module_env$DECON_MIN_PTS_PER_COMP, "points/component", "feasibility limit",
    "deconvolution_module.R: DECON_MIN_PTS_PER_COMP", "source-evaluated", "Combined with the residual degrees-of-freedom margin.")
add("Deconvolution", "residual_df_margin", module_env$DECON_RESID_DF_MARGIN, "points", "feasibility limit",
    "deconvolution_module.R: DECON_RESID_DF_MARGIN", "source-evaluated", "Enforces 3K+1 <= n-margin.")
add("Deconvolution", "shape_mixing_parameter", "one eta shared by all components", "text", "model constraint",
    "deconvolution_module.R: fit_pvoigt()", "static-source-verified", "The fitted model has 3K+1 curve parameters.")

# Cell Growth automatic window-selection contract.
add("Cell Growth", "minimum_R2", growth$min_r2, "R2", "development threshold",
    "PASA.R: GROWTH_CONST$min_r2", "source-evaluated", "Operational high-consistency and fallback screen.")
add("Cell Growth", "minimum_points_high_consistency", growth$min_window_pts_highconsistency, "points", "minimum",
    "PASA.R: GROWTH_CONST$min_window_pts_highconsistency", "source-evaluated", "Includes curvature screen.")
add("Cell Growth", "minimum_points_fallback", growth$min_window_pts_fallback, "points", "minimum",
    "PASA.R: GROWTH_CONST$min_window_pts_fallback", "source-evaluated", "Preliminary tier when high-consistency selection fails.")
add("Cell Growth", "maximum_interval_mu_CV", growth$max_interval_mu_cv, "fraction", "development threshold",
    "PASA.R: GROWTH_CONST$max_interval_mu_cv", "source-evaluated", "Applied when at least three intervals exist.")
add("Cell Growth", "slope_p_alpha", growth$slope_alpha, "p-value", "development threshold",
    "PASA.R: GROWTH_CONST$slope_alpha", "source-evaluated", "Post-selection operational filter, not an unqualified significance test.")
add("Cell Growth", "curvature_p_alpha", growth$curvature_alpha, "p-value", "development threshold",
    "PASA.R: GROWTH_CONST$curvature_alpha", "source-evaluated", "A finite p below this rejects the high-consistency tier.")
add("Cell Growth", "minimum_total_log_OD_rise", app_env$GROWTH_MIN_LOG_RISE, "log OD", "numerical floor",
    "PASA.R: GROWTH_MIN_LOG_RISE", "source-evaluated", "Not a biological growth/no-growth threshold.")
add("Cell Growth", "minimum_replicates_for_t_interval", growth$minimum_replicates_for_ci, "replicates", "minimum",
    "PASA.R: GROWTH_CONST$minimum_replicates_for_ci", "source-evaluated", "Conditional post-selection sensitivity interval.")
add("Cell Growth", "t_interval_level", growth$ci_level, "fraction", "default",
    "PASA.R: GROWTH_CONST$ci_level", "source-evaluated", "Not calibrated for window-selection uncertainty.")
add("Cell Growth", "minimum_biological_units", growth$min_biological_units, "biological units", "reporting threshold",
    "PASA.R: GROWTH_CONST$min_biological_units", "source-evaluated", "Operational reporting guidance.")
add("Cell Growth", "bootstrap_default", snap("growth_boot"), "logical", "default",
    "PASA.R: snapshot factory defaults", "source-evaluated", "Off unless explicitly requested.")
add("Cell Growth", "bootstrap_max_resamples", 200, "resamples", "hard limit",
    "PASA.R: GROWTH_BOOT_MAX", "static-source-verified", "Interactive cap.")
add("Cell Growth", "bootstrap_minimum_successes", growth$boot_min_success, "successful resamples", "minimum",
    "PASA.R: GROWTH_CONST$boot_min_success", "source-evaluated", "Below this no percentile interval is reported.")

# Privacy/network defaults relevant to the publication build.
add("Network and privacy", "feedback_default", default_feedback$enabled, "logical", "default",
    "PASA.R: .pasa_feedback_config()", "source-evaluated with empty environment", "The bundled PASA Google Form is the default destination; PASA_FEEDBACK_ENABLED=0 disables it, and an incomplete custom endpoint disables direct submission rather than falling back. Sending needs an explicit click and acknowledgment; only rating, comment, UTC timestamp, and app version are sent.")
add("Network and privacy", "feedback_endpoint_default", "bundled PASA Google Form (docs.google.com)", "URL", "default",
    "PASA.R: .pasa_feedback_config()", "source-evaluated with empty environment", "PASA_FEEDBACK_FORM_URL replaces it; a custom HTTPS endpoint needs complete explicit configuration.")
add("Network and privacy", "feedback_field_mapping_default", "bundled form entries for rating, comment, timestamp, and version", "text", "default",
    "PASA.R: .pasa_feedback_config()", "source-evaluated with empty environment", "A custom endpoint must supply unique identifiers for the four sent fields; the legacy location field is not sent.")
add("Network and privacy", "feedback_controller_default", default_feedback$controller_name, "text", "default",
    "PASA.R: .pasa_feedback_config()", "source-evaluated with empty environment", "Named for the bundled form; a custom endpoint requires an explicit controller name.")
add("Network and privacy", "feedback_privacy_url_default", default_feedback$privacy_url, "URL", "default",
    "PASA.R: .pasa_feedback_config()", "source-evaluated with empty environment", "Google's privacy information for the bundled form; a custom endpoint requires an explicit HTTPS privacy/deletion URL.")
add("Network and privacy", "feedback_trigger", "explicit Send feedback button", "text", "contract",
    "PASA.R: observeEvent(input$fb_submit)", "static-source-verified", "When enabled, sends rating, optional comment, UTC timestamp, and release version; the legacy location field is omitted.")
add("Network and privacy", "feedback_acknowledgment", "required before submission", "text", "contract",
    "PASA.R: .pasa_feedback_submission_allowed()", "source-evaluated", "The configured deployment operator controls retention and handles response access or deletion requests.")
add("Network and privacy", "background_telemetry", FALSE, "logical", "contract",
    "PASA.R: network/privacy implementation", "static-source-reviewed", "No analytics, database, IP-geolocation, or automatic telemetry call is implemented.")
add("Network and privacy", "remote_data_trigger", "explicit Load/Inspect action", "text", "contract",
    "PASA.R: URL loader and sheet inspection observers", "static-source-reviewed", "Remote data are fetched only after a user action.")

# Repair-release settings are read from the same definitions used by the app.
add("Input", "browser_default_limit", app_env$INPUT_LIMITS$raw_bytes / 2^20, "MiB", "default",
    "PASA.R: .pasa_upload_limit_bytes()", "source-evaluated", "Configured before the Shiny app starts; a lower explicit limit is retained.")
add("Input", "lower_deployment_limit", "PASA_UPLOAD_LIMIT_MIB or shiny.maxRequestSize", "text", "configuration",
    "PASA.R: .pasa_upload_limit_bytes()", "static-source-reviewed", "The UI shows the effective app limit. A reverse proxy can impose a smaller limit.")
add("Noise QC", "method_identifier", app_env$.NOISE_QC_METHOD, "text", "method",
    "PASA.R: .NOISE_QC_METHOD", "source-evaluated", "Operational residual and neighboring-point roughness screen.")
for (key in c("min_global_resid", "min_tail_resid", "min_region_resid", "min_adjacent_resid"))
  add("Noise QC", key, app_env$NOISE_QC_PARAMS[[key]], "residuals", "support floor",
      paste0("PASA.R: NOISE_QC_PARAMS$",key), "source-evaluated", "Insufficient support is not evaluated, never replaced by zero.")
for (key in c("adjacent_caution", "adjacent_fail"))
  add("Noise QC", key, app_env$NOISE_QC_PARAMS[[key]], "percent", "operational threshold",
      paste0("PASA.R: NOISE_QC_PARAMS$",key), "source-evaluated", "Curvature can contribute; this does not diagnose a detector fault.")
add("Noise QC", "tie_ranking", "average exact-tie ranks", "text", "contract",
    "PASA.R: compute_noise_qc()", "static-source-reviewed", "Sample order and names cannot split an exact tie.")
add("Deconvolution", "blank_failure", "refuse malformed selected blank", "text", "contract",
    "PASA.R: decon_blank_state()", "static-source-reviewed", "Current invalid input withholds cached fit outputs.")
add("Deconvolution", "red_edge_status", "disabled; applied; no_change; refused", "text", "contract",
    "deconvolution_module.R: .decon_prepare_red_clip()", "static-source-reviewed", "Requested/effective range and retained counts are reported together.")
add("Deconvolution", "bootstrap_all_attempts", "same-K draws / requested draws", "text", "denominator",
    "deconvolution_module.R: bootstrap accounting", "static-source-reviewed", "Defined only if the original spectrum has a selected K.")
add("Deconvolution", "bootstrap_conditional", "same-K draws / selected draws", "text", "denominator",
    "deconvolution_module.R: bootstrap accounting", "static-source-reviewed", "Undefined when no draw selects K; legacy conditional fields are retained.")
add("Deconvolution", "bootstrap_outcomes", "selected; no admissible K; execution error; invalid return", "text", "contract",
    "deconvolution_module.R: bootstrap accounting", "static-source-reviewed", "Every requested draw has an outcome record.")

add("Input", "worker_startup_stage_budget", app_env$.PASA_WORKER_READY_TIMEOUT_SECS, "seconds", "startup limit",
    "PASA.R: .PASA_WORKER_READY_TIMEOUT_SECS", "source-evaluated", "Connectivity and app initialization each have a bounded budget; whole-file load deadlines remain in force. A new request can retry a failed idle worker.")

table <- do.call(rbind, rows)
if (nrow(table) != 83L) {
  stop("Defaults/limits registry contract requires exactly 83 rows; observed ", nrow(table), ".")
}
freeze_requested <- identical(Sys.getenv("PASA_RELEASE_FROZEN", unset = "0"), "1")
table$release_version <- as.character(app_env$RELEASE_ID$version)
table$pasa_r_sha256 <- if (freeze_requested) {
  toupper(unname(tools::sha256sum(app_file)))
} else "PENDING_FINAL_FREEZE"
table$deconvolution_module_sha256 <- if (freeze_requested) {
  toupper(unname(tools::sha256sum(module_file)))
} else "PENDING_FINAL_FREEZE"
table$registry_status <- if (freeze_requested) "FINAL_SOURCE_VERIFIED" else "PROVISIONAL_UNTIL_SOURCE_FREEZE"

# Write through a binary connection so the record is LF-terminated on every platform
# (matches FREEZE_SOURCE_CHECKSUMS.R and the repository's .gitattributes).
registry_connection <- file(output_file, open = "wb")
utils::write.table(table, registry_connection, sep = "\t", quote = TRUE,
                   row.names = FALSE, na = "NA", fileEncoding = "UTF-8")
close(registry_connection)
cat(sprintf("PASA_DEFAULTS_AND_LIMITS_WRITTEN rows=%d status=%s\n",
            nrow(table), unique(table$registry_status)))
