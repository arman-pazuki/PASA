# Presentation helpers. Existing analysis inputs and navigation values are retained.
pasa_shell_dependencies <- function() {
  shiny::tagList(
    shiny::tags$link(rel = "stylesheet", href = "pasa-ui/pasa-shell.css"),
    shiny::tags$script(src = "pasa-ui/pasa-shell.js"),
    shiny::tags$link(rel = "stylesheet", href = "pasa-ui/pasa-metrics-scroll.css"),
    shiny::tags$script(src = "pasa-ui/pasa-metrics-scroll.js")
  )
}

pasa_controls_layout <- function(content) {
  items <- unclass(content)
  groups <- list(); current <- list()
  for (item in items) {
    if (inherits(item, "shiny.tag") && identical(item$name, "hr")) {
      if (length(current)) groups[[length(groups) + 1L]] <- current
      current <- list()
    } else current[[length(current) + 1L]] <- item
  }
  if (length(current)) groups[[length(groups) + 1L]] <- current
  titles <- c("Range and sample type", "Samples", "Band windows", "Baseline", "Signal conditioning", "Scaling and normalization", "Export options")
  ids <- c("range", "samples", "bands", "baseline", "conditioning", "normalization", "exports")
  panels <- lapply(seq_along(groups), function(i) {
    title <- if (i <= length(titles)) titles[[i]] else "More settings"
    shiny::tags$details(id = paste0("pasa-settings-", if (i <= length(ids)) ids[[i]] else i),
      class = "pasa-setting-group", open = if (i <= 2L) "open" else NULL,
      shiny::tags$summary(title),
      shiny::div(class = "pasa-setting-content", groups[[i]]))
  })
  shiny::div(class = "pasa-settings-grid", panels)
}

pasa_workspace_header <- function() {
  shiny::div(id = "pasa-workspace-header",
    shiny::div(class = "pasa-page-heading",
      shiny::div(shiny::tags$p(class = "pasa-breadcrumb", "Workspace"),
                 shiny::tags$h1(id = "pasa-page-title", "Input data")),
      shiny::tags$button(id = "pasa-settings-shortcut", type = "button", class = "btn btn-outline-primary pasa-settings-toggle",
        onclick = "window.PasaShell && window.PasaShell.navigate('Analysis settings');",
        `aria-controls` = "pasa-analysis-settings", "Analysis settings")),
    shiny::uiOutput("pasa_analysis_summary"),
    shiny::div(class = "pasa-global-status", shiny::uiOutput("processing_input_status"),
               shiny::tableOutput("processing_failure_table")))
}

pasa_disclosure_actions <- function(target) {
  shiny::div(class = "pasa-disclosure-actions",
    shiny::tags$button(type = "button", class = "btn btn-sm btn-outline-secondary",
      `data-pasa-disclosures` = target, `data-pasa-expand` = "true", "Expand all"),
    shiny::tags$button(type = "button", class = "btn btn-sm btn-outline-secondary",
      `data-pasa-disclosures` = target, `data-pasa-expand` = "false", "Collapse all"))
}

# Human-facing labels only. The numerical method and snapshot values are unchanged.
pasa_normalization_label <- function(method = "none", band = NULL, target = NULL,
                                     reference = NULL, baseline = TRUE) {
  method <- if (length(method) == 1L && !is.na(method)) as.character(method) else "none"
  if (identical(method, "none")) return("None")
  number <- function(x) {
    x <- suppressWarnings(as.numeric(x))
    if (length(x) == 1L && is.finite(x)) format(x, digits = 6, trim = TRUE) else "not set"
  }
  band <- if (length(band) == 1L && !is.na(band) && nzchar(band)) band else "select a band"
  feature <- switch(method,
    max_to = "Spectral maximum",
    ref_nm_to = paste0("Value at ", number(reference), " nm"),
    unit_area_to = "Total area",
    band_peak_to = paste0("Band peak: ", band),
    band_auc_to = paste0("Band AUC: ", band), "Unknown method")
  label <- paste0(feature, ", target value: ", number(target))
  if (!isTRUE(baseline)) paste0("Not applied (baseline correction is off; ", label, ")") else label
}

pasa_shell_header_actions <- function() {
  list(
    bslib::nav_item(shiny::downloadButton("dl_state_file", "Save session", class = "btn-sm btn-outline-secondary pasa-requires-data")),
    bslib::nav_item(shiny::tags$details(class = "pasa-export-menu",
      shiny::tags$summary("Export"),
      shiny::div(class = "pasa-export-popover",
        shiny::downloadButton("dl_all_zip", "Download everything (ZIP)", class = "btn-primary pasa-requires-data"),
        shiny::tags$button(type = "button", class = "btn btn-outline-secondary",
          onclick = "window.PasaShell && window.PasaShell.navigate('Metrics'); this.closest('details').open=false;", "Tables and metrics"),
        shiny::tags$button(type = "button", class = "btn btn-outline-secondary",
          onclick = "window.PasaShell && window.PasaShell.navigate('Summary'); this.closest('details').open=false;", "Analysis summary")))),
    bslib::nav_item(shiny::actionButton("pasa_tour_restart", "Guided tour", class = "btn-sm btn-outline-primary"))
  )
}
