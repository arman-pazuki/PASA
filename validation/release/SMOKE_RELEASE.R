# Portable release smoke checks. Run after INSTALL_DEPENDENCIES.R, from any cwd:
# Rscript validation/release/SMOKE_RELEASE.R [package-root]
# Uses only distributed files and synthetic local data. No network inputs or feedback.
options(warn = 1)
main <- function() {
  argv <- commandArgs(trailingOnly = TRUE)
  full <- commandArgs(trailingOnly = FALSE)
  script <- sub("^--file=", "", full[startsWith(full, "--file=")][1L])
  root <- if (length(argv)) argv[1L] else file.path(dirname(script), "../..")
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  output_dir <- Sys.getenv("PASA_SMOKE_OUTPUT", file.path(root, "validation/release/smoke-output"))
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)
  results <- list()
  check <- function(name, ok, detail = "") {
    pass <- isTRUE(ok)
    results[[length(results) + 1L]] <<- list(name = name, pass = pass, detail = detail)
    cat(if (pass) "PASS" else "FAIL", name, if (nzchar(detail)) paste0(": ", detail) else "", "\n")
    if (!pass) stop("Smoke check failed: ", name, call. = FALSE)
    invisible(pass)
  }
  report <- function(error = NULL) {
    if (requireNamespace("jsonlite", quietly = TRUE)) {
      jsonlite::write_json(list(
        ok = is.null(error) && length(results) > 0L && all(vapply(results, `[[`, logical(1), "pass")),
        error = error, platform = R.version$platform, r_version = as.character(getRversion()),
        system = as.list(Sys.info()), checks = results,
        session_info = capture.output(sessionInfo())),
        file.path(output_dir, "smoke-results.json"), auto_unbox = TRUE, pretty = TRUE, null = "null")
    }
    writeLines(capture.output(sessionInfo()), file.path(output_dir, "session-info.txt"))
  }
  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  on.exit({
    if (requireNamespace("mirai", quietly = TRUE)) {
      try(mirai::daemons(0L), silent = TRUE)
      try(mirai::daemons(0L, .compute = "pasa-io"), silent = TRUE)
    }
  }, add = TRUE)
  tryCatch({
    check("Exact release R version", identical(as.character(getRversion()), "4.6.0"), R.version.string)
    source(file.path(root, "reproducibility/LOAD_LOCKED_ENVIRONMENT.R"), local = TRUE)
    source_dir <- load_pasa_locked_environment(root)
    check("Locked dependencies loaded", requireNamespace("shiny", quietly = TRUE) &&
            requireNamespace("writexl", quietly = TRUE) && requireNamespace("mirai", quietly = TRUE))
    Sys.setenv(SPECTRA_HOSTED_MODE = "1", SPECTRA_DESKTOP_MODE = "0",
      PASA_PREFERENCES_DIR = file.path(output_dir, "preferences"), PASA_LAUNCH_BROWSER = "0",
      PASA_APP_DIR = source_dir)
    setwd(source_dir)
    expr <- parse(file.path(source_dir, "PASA.R"), encoding = "UTF-8", keep.source = FALSE)
    check("Startup expression is identified", is.call(expr[[length(expr)]]) &&
            identical(expr[[length(expr)]][[1L]], as.name("shinyApp")))
    # Match the launcher and worker environment in this dedicated smoke process.
    app <- globalenv()
    suppressPackageStartupMessages(eval(expr[-length(expr)], envir = app))
    check("Application sources and UI build", is.function(app$server) && !is.null(app$ui) &&
            is.function(app$deconvolve_spectrum))
    registry <- utils::read.delim(file.path(root, "reproducibility/PASA_DEFAULTS_AND_LIMITS.tsv"),
      check.names = FALSE, colClasses = "character")
    registry_expected <- c(
      release_version = as.character(app$RELEASE_ID$version),
      pasa_r_sha256 = toupper(unname(tools::sha256sum(file.path(source_dir, "PASA.R")))),
      deconvolution_module_sha256 = toupper(unname(tools::sha256sum(file.path(source_dir, "deconvolution_module.R")))),
      pasa_io_sha256 = toupper(unname(tools::sha256sum(file.path(source_dir, "pasa_io.R")))),
      registry_status = "FINAL_SOURCE_VERIFIED")
    registry_matches_source <- function(value) {
      if (!is.data.frame(value) || !nrow(value) || !all(names(registry_expected) %in% names(value))) return(FALSE)
      all(vapply(names(registry_expected), function(key)
        all(!is.na(value[[key]]) & value[[key]] == registry_expected[[key]]), logical(1)))
    }
    check("Defaults registry identifies every final source row", registry_matches_source(registry))
    stale_rejected <- vapply(names(registry_expected), function(key) {
      stale <- registry
      stale[[key]][nrow(stale)] <- "stale-regression-fixture"
      !registry_matches_source(stale)
    }, logical(1))
    missing_hash <- registry
    missing_hash$pasa_io_sha256 <- NULL
    check("Registry guard rejects stale hashes, version, status and missing provenance",
      all(stale_rejected) && !registry_matches_source(missing_hash))
    # The runtime also reads its CIE data at startup; enumerate actual distributed tables.
    assets <- app$PASA_RUNTIME_BUNDLE_FILES
    missing <- assets[!file.exists(file.path(source_dir, assets))]
    check("Registered runtime assets present", !length(missing), paste(missing, collapse = ", "))

    demo <- app$builtin_demo_data()
    check("Built-in example is deterministic and finite", nrow(demo) == 801L && ncol(demo) == 4L &&
            all(is.finite(as.matrix(demo))) && identical(demo, app$builtin_demo_data()))
    fixture <- as.data.frame(demo, check.names = FALSE)
    csv <- file.path(output_dir, "synthetic-spectra.csv")
    xlsx <- file.path(output_dir, "synthetic-spectra.xlsx")
    app$write_table_fmt(fixture, csv, "csv")
    app$write_table_fmt(fixture, xlsx, "xlsx")
    imported_csv <- app$read_spectra_file(csv)
    imported_xlsx <- app$read_spectra_file(xlsx, sheet = 1)
    same_table <- function(a, b) identical(names(a), names(b)) &&
      isTRUE(all.equal(unname(as.matrix(a)), unname(as.matrix(b)), tolerance = 1e-12, check.attributes = FALSE))
    check("CSV export and local import retain numerical data", same_table(fixture, imported_csv))
    check("XLSX export and local import retain numerical data", same_table(fixture, imported_xlsx) &&
            identical(readBin(xlsx, "raw", n = 2L), charToRaw("PK")))
    io_session <- shiny::MockShinySession$new()
    on.exit(io_session$close(), add = TRUE)
    io_runner <- app$.pasa_io_runner(io_session)
    io_result <- NULL; io_error <- NULL; io_domain_ok <- FALSE
    # use_file=TRUE models a user-uploaded local file in hosted mode.
    io_job <- io_runner("load", list(use_file = TRUE, path = csv, ext = "csv", sheet = 1),
      budget = 120,
      on_result = function(value, deadline) {
        io_result <<- value
        io_domain_ok <<- identical(shiny::getDefaultReactiveDomain(), io_session)
      },
      on_error = function(message) io_error <<- message)
    io_deadline <- Sys.time() + 135
    while (is.null(io_result) && is.null(io_error) && Sys.time() < io_deadline) later::run_now(.2)
    if (is.null(io_result) && is.null(io_error)) {
      io_job$cancel()
      stop("Dedicated input worker smoke test exceeded 135 seconds")
    }
    check("Dedicated input worker imports local CSV in session domain",
      is.null(io_error) && io_domain_ok && is.data.frame(io_result) && same_table(fixture, io_result),
      if (!is.null(io_error)) io_error else if (inherits(io_result, "pasa_load_error")) attr(io_result, "msg") else "")
    io_session$close()
    mirai::daemons(0L, .compute = "pasa-io")
    example_path <- file.path(root, "examples/EXAMPLE_SYNTHETIC_SPECTRA.xlsx")
    check("Distributed example workbook imports", file.exists(example_path) &&
            nrow(app$read_spectra_file(example_path, sheet = 1)) >= 2L)
    bands <- data.frame(band = c("Blue", "Red"), from = c(400, 640), to = c(500, 710))
    process <- function(d) app$process_wide_table(d, bands, analysis_range = c(350, 750),
      baseline_method = "single_nm", baseline_nm = 750, smoothing_method = "none",
      norm_method = "none", resample_step = 1, apply_baseline = TRUE)
    metrics <- process(fixture)
    metric_cols <- intersect(c("auc_raw", "auc_base", "peak_raw", "peak_base"), names(metrics))
    check("Spectral numerical outputs are finite", nrow(metrics) == 6L && length(metric_cols) >= 2L &&
            all(is.finite(as.matrix(metrics[, metric_cols, drop = FALSE]))) &&
            nrow(app$.pasa_processing_failures(metrics)) == 0L)
    compare_metrics <- function(d) {
      actual <- process(d)
      # Import provenance differs; compare the selected samples/bands and numerical outputs.
      identical(actual$sample, metrics$sample) && identical(actual$band, metrics$band) &&
        isTRUE(all.equal(as.matrix(actual[, metric_cols, drop = FALSE]),
                         as.matrix(metrics[, metric_cols, drop = FALSE]), tolerance = 1e-10))
    }
    check("Imported spectra reproduce numerical outputs", compare_metrics(imported_csv) && compare_metrics(imported_xlsx))
    check("Trapezoidal integration reference", abs(app$trapz_auc(c(0, 1, 2), c(0, 1, 2)) - 2) < 1e-12)
    flat <- as.data.frame(metrics[, c("sample", "band", metric_cols), drop = FALSE])
    app$write_table_fmt(flat, file.path(output_dir, "metrics.csv"), "csv")
    app$write_table_fmt(flat, file.path(output_dir, "metrics.xlsx"), "xlsx")
    pdf <- file.path(output_dir, "metrics-unicode.pdf")
    app$grid_table_pdf(flat, pdf, title = "PASA smoke: spectral metrics", subtitle = "Wavelength λ; apparent rate μ")
    check("Cairo PDF export produces a PDF", identical(readBin(pdf, "raw", n = 4L), charToRaw("%PDF")) &&
            file.info(pdf)$size > 1000)

    # Native Cairo may warn without opening a device even when capabilities()
    # reports TRUE. Inject that behavior without altering installed namespaces.
    local({
      guard_dir <- file.path(output_dir, "cairo-device-guard")
      dir.create(guard_dir, showWarnings = FALSE)
      prior_wd <- getwd(); setwd(guard_dir)
      on.exit(setwd(prior_wd), add = TRUE)
      original_ids <- unname(grDevices::dev.list())
      on.exit({
        for (id in setdiff(unname(grDevices::dev.list()), original_ids))
          try(grDevices::dev.off(which = id), silent = TRUE)
      }, add = TRUE)
      grDevices::pdf("existing-user-device.pdf")
      user_device <- unname(grDevices::dev.cur())
      user_ids <- unname(grDevices::dev.list())
      unchanged <- function() identical(unname(grDevices::dev.list()), user_ids) &&
        identical(unname(grDevices::dev.cur()), user_device) && !file.exists("Rplots.pdf")
      native_warning <- function(...) warning("simulated native Cairo library load failure")
      warned <- tryCatch(app$.pasa_open_pdf("warning.pdf", .device = native_warning), error = identity)
      check("Cairo warning without a device is refused without closing existing devices",
        inherits(warned, "error") && grepl("native Cairo library", conditionMessage(warned)) && unchanged())
      silent <- tryCatch(app$.pasa_open_pdf("silent.pdf", .device = function(...) invisible(NULL)), error = identity)
      check("Cairo silent no-device return is refused", inherits(silent, "error") &&
        grepl("did not open", conditionMessage(silent)) && unchanged())
      partial <- tryCatch(app$.pasa_open_pdf("partial.pdf", .device = function(filename, ...) {
        grDevices::pdf(filename)
        warning("simulated warning after partial device initialization")
      }), error = identity)
      check("Failed PDF initialization closes only its newly opened device",
        inherits(partial, "error") && unchanged())
      p <- ggplot2::ggplot(data.frame(x = 1:3, y = c(1, 3, 2)), ggplot2::aes(x, y)) +
        ggplot2::geom_line() + ggplot2::labs(x = "Wavelength λ", y = "Apparent rate μ")
      wrapped_warning <- tryCatch(ggplot2::ggsave("ggsave-warning.pdf", plot = p,
        device = app$.pasa_pdf_device, width = 5, height = 4, bg = "white", .device = native_warning), error = identity)
      check("ggsave uses the guarded PDF device and preserves the existing device on failure",
        inherits(wrapped_warning, "error") && unchanged())
      ggplot2::ggsave("guarded-plot.pdf", plot = p, device = app$.pasa_pdf_device,
        width = 5, height = 4, bg = "white")
      check("Guarded ggsave produces a Unicode Cairo PDF",
        identical(readBin("guarded-plot.pdf", "raw", n = 4L), charToRaw("%PDF")) &&
        file.info("guarded-plot.pdf")$size > 1000 && unchanged())
    })

    growth <- do.call(rbind, lapply(1:3, function(i) data.frame(
      Time = 0:6, Replicate = paste0("R", i), OD = (.04 + .01 * i) * exp(.3 * (0:6)))))
    gr <- app$analyze_growth(growth)
    check("Growth recovers synthetic apparent log-linear rate", isTRUE(gr$ok) &&
            all(abs(gr$best_each$mu - .3) < 1e-10) && gr$exp_t0 %in% growth$Time && gr$exp_t1 %in% growth$Time)
    nested <- expand.grid(Time = 0:5, biological_rep = paste0("B", 1:3), technical_rep = 1:2,
                          stringsAsFactors = FALSE)
    nested$OD <- .1 * exp(.3 * nested$Time)
    gn <- app$analyze_growth_nested(nested)
    check("Nested growth retains biological replicates", isTRUE(gn$ok) && gn$n_bio_contributing == 3L &&
            abs(gn$mu_mean - .3) < 1e-10)

    # Exercise actual session serialization and production validation/decoding.
    # MockShinySession does not run client-side widgets, so supply their defaults.
    shiny::testServer(app$server, {
      defaults <- .SNAPSHOT_SETTINGS_REGISTRY$default
      names(defaults) <- .SNAPSHOT_SETTINGS_REGISTRY$key
      defaults <- defaults[!vapply(defaults, is.null, logical(1))]
      do.call(session$setInputs, defaults)
      session$setInputs(load_demo = 0L, data_source = "demo", main_nav = "Data", advanced_mode = FALSE,
        growth_manual = FALSE, growth_nrep = 1L, growth_ntech = 1L, growth_ntp = 7L,
        growth_interval = 1, growth_unit = "Hours")
      session$flushReact()
      session$setInputs(load_demo = 1L)
      session$flushReact()
      check("Session loads built-in example", !is.null(shiny::isolate(dat_value())) &&
              same_table(fixture, shiny::isolate(dat_value())))
      session$setInputs(samples = names(fixture)[-1L], analysis_nm = c(350, 750),
        organism = "cyano", sample_type = "cells", apply_baseline = TRUE,
        baseline_method = "single_nm", baseline_nm = 750, norm_method = "none")
      session$flushReact()
      snapshot <- shiny::isolate(build_state_text(include_settings = TRUE, include_data = TRUE))
      writeLines(snapshot, file.path(output_dir, "roundtrip-state.txt"), useBytes = TRUE)
      parsed <- parse_state_text(snapshot)
      valid <- .validate_snapshot(parsed, names(parsed))
      check("Saved session validates through production decoder", isTRUE(valid$ok), paste(valid$errors, collapse = "; "))
      check("Saved session preserves spectra", same_table(fixture, valid$prepared$data))
      check("Saved session includes settings and growth state", !is.null(valid$prepared$settings) &&
              !is.null(valid$prepared$growth) && "DECON_BLANK_DATA" %in% names(parsed))
    })

    x <- seq(400, 750, by = 2)
    y <- .8 * exp(-.5 * ((x - 445) / 15)^2) + .3 * exp(-.5 * ((x - 680) / 13)^2) + .004 * sin(x * .4)
    direct <- app$deconvolve_spectrum(x, y, k_min = 1L, k_max = 2L, n_boot = 2L)
    check("Deconvolution and small full bootstrap complete", is.null(direct$error) &&
            nrow(direct$comparison) >= 1L && direct$boot_status == "ran" && direct$boot$n_requested == 2L)
    check("Actual background worker loads release source", isTRUE(app$.growth_bg_ready()))
    task <- mirai::mirai({
      fit <- deconvolve_spectrum(X, Y, k_min = 1L, k_max = 2L, n_boot = 2L)
      growth <- analyze_growth(GROWTH)
      list(fit = fit, growth_mu = growth$best_each$mu, worker_r = as.character(getRversion()))
    }, X = x, Y = y, GROWTH = growth)
    deadline <- Sys.time() + 60
    while (mirai::unresolved(task) && Sys.time() < deadline) Sys.sleep(.05)
    if (mirai::unresolved(task)) { mirai::stop_mirai(task); stop("Background smoke test exceeded 60 seconds") }
    worker <- task$data
    check("Actual worker returns deconvolution and growth outputs", is.list(worker) &&
            identical(worker$worker_r, "4.6.0") && is.null(worker$fit$error) &&
            worker$fit$boot_status == "ran" && all(abs(worker$growth_mu - .3) < 1e-10))
    check("Worker and main-process numerical fits agree", isTRUE(all.equal(
      worker$fit$comparison, direct$comparison, tolerance = 1e-10)))
    report()
    cat("RELEASE_SMOKE_COMPLETE", length(results), "checks; reports:", output_dir, "\n")
  }, error = function(e) {
    report(conditionMessage(e))
    stop(conditionMessage(e), call. = FALSE)
  })
}
main()
