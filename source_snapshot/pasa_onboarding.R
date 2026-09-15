# PASA guided introduction. Only a small tour preference is persisted.
# This module never reads, transforms, replaces, or uploads analysis data.
.pasa_tour_revision <- "2"
# The catalog provides exact browser bounds. This server cap rejects implausible
# preference data without coupling content authoring to duplicated step counts.
.pasa_tour_step_cap <- 1000L

.pasa_tour_storage_mode <- function(env = Sys.getenv) {
  truth <- function(x) tolower(x) %in% c("1", "true", "yes", "on")
  # A declared host always wins. Absence of a hosted flag is not desktop consent.
  if (truth(env("SPECTRA_HOSTED_MODE", unset = ""))) return("browser")
  if (truth(env("SPECTRA_DESKTOP_MODE", unset = ""))) "desktop" else "browser"
}

.pasa_tour_validate_state <- function(x) {
  fields <- c("detailed_status", "detailed_step", "kind", "quick_status", "quick_step", "revision")
  if (!is.list(x) || !identical(sort(names(x)), fields)) return(NULL)
  if (!is.character(x$revision) || length(x$revision) != 1L ||
      is.na(x$revision) || !identical(x$revision, .pasa_tour_revision)) return(NULL)
  if (!is.character(x$kind) || length(x$kind) != 1L || is.na(x$kind) ||
      !x$kind %in% c("quick", "detailed")) return(NULL)
  for (kind in c("quick", "detailed")) {
    status <- x[[paste0(kind, "_status")]]
    step <- x[[paste0(kind, "_step")]]
    if (!is.character(status) || length(status) != 1L || is.na(status) ||
        !status %in% c("welcome", "in_progress", "completed", "skipped")) return(NULL)
    if (length(step) != 1L || is.list(step) || is.logical(step)) return(NULL)
    step <- suppressWarnings(as.numeric(step))
    if (!is.finite(step) || step != floor(step) || step < 0L || step >= .pasa_tour_step_cap) return(NULL)
    x[[paste0(kind, "_step")]] <- as.integer(step)
  }
  x[fields]
}

.pasa_tour_preferences_dir <- function() {
  override <- Sys.getenv("PASA_PREFERENCES_DIR", unset = "")
  if (nzchar(override)) override else tools::R_user_dir("PASA", "config")
}

.pasa_tour_read_state <- function(mode = .pasa_tour_storage_mode(),
                                  preferences_dir = .pasa_tour_preferences_dir()) {
  # Return before resolving a path or touching a file on hosted deployments.
  if (!identical(mode, "desktop")) return(NULL)
  tryCatch({
    path <- file.path(preferences_dir, "tour-preference.dcf")
    info <- file.info(path)
    if (is.na(info$size) || info$isdir || info$size > 4096L) return(NULL)
    raw <- read.dcf(path, all = TRUE)
    if (nrow(raw) != 1L) return(NULL)
    .pasa_tour_validate_state(as.list(raw[1L, , drop = FALSE]))
  }, error = function(e) NULL, warning = function(w) NULL)
}

.pasa_tour_write_state <- function(state, mode = .pasa_tour_storage_mode(),
                                   preferences_dir = .pasa_tour_preferences_dir()) {
  if (!identical(mode, "desktop")) return(FALSE)
  state <- .pasa_tour_validate_state(state)
  if (is.null(state)) return(FALSE)
  tryCatch({
    if (!dir.exists(preferences_dir) &&
        !dir.create(preferences_dir, recursive = TRUE, showWarnings = FALSE, mode = "0700")) return(FALSE)
    path <- file.path(preferences_dir, "tour-preference.dcf")
    temp <- tempfile("tour-", tmpdir = preferences_dir, fileext = ".tmp")
    on.exit(unlink(temp), add = TRUE)
    write.dcf(as.data.frame(state, stringsAsFactors = FALSE), file = temp)
    Sys.chmod(temp, mode = "0600")
    isTRUE(file.rename(temp, path))
  }, error = function(e) FALSE, warning = function(w) FALSE)
}

pasa_onboarding_ui <- function(app_dir = .pasa_source_root()) {
  shiny::tagList(shiny::tags$link(rel = "stylesheet", href = "pasa-ui/pasa-tour.css"),
    shiny::tags$div(
    id = "pasa-onboarding-root",
    shiny::tags$div(id = "pasa-tour-live", class = "pasa-tour-sr-only", role = "status", `aria-live` = "polite"),
    shiny::tags$section(id = "pasa-tour-chooser", role = "dialog", `aria-modal` = "false",
      `aria-labelledby` = "pasa-tour-choose-title", hidden = NA,
      shiny::tags$button(id = "pasa-tour-chooser-x", type = "button", class = "pasa-tour-close",
        `aria-label` = "Close tour choices", title = "Close tour choices",
        shiny::tags$span(`aria-hidden` = "true", "\u00d7")),
      shiny::tags$h2(id = "pasa-tour-choose-title", tabindex = "-1", "Choose your guided tour"),
      shiny::tags$p("Explore at your own pace. Both tours keep your analysis choices; controls that need another option are explained and can be revisited."),
      shiny::tags$div(class = "pasa-tour-choice",
        shiny::tags$h3("Quick tour"),
        shiny::tags$p("A short introduction to the workflow, every tab and Advanced Mode. ", shiny::tags$span(id = "pasa-tour-count-quick")),
        shiny::tags$button(id = "pasa-tour-start-quick", type = "button", class = "btn btn-primary", "Start quick tour"),
        shiny::tags$button(id = "pasa-tour-resume-quick", type = "button", class = "btn btn-outline-primary", hidden = NA, "Resume quick tour")),
      shiny::tags$div(class = "pasa-tour-choice",
        shiny::tags$h3("Detailed tour"),
        shiny::tags$p("A field-by-field guide with examples, detailed analysis settings, interpretation and exports. Jump between chapters whenever you want. ", shiny::tags$span(id = "pasa-tour-count-detailed")),
        shiny::tags$button(id = "pasa-tour-start-detailed", type = "button", class = "btn btn-primary", "Start detailed tour"),
        shiny::tags$button(id = "pasa-tour-resume-detailed", type = "button", class = "btn btn-outline-primary", hidden = NA, "Resume detailed tour")),
      shiny::tags$button(id = "pasa-tour-chooser-close", type = "button", class = "btn btn-link", "Close")),
    shiny::tags$div(id = "pasa-tour-highlight", `aria-hidden` = "true", hidden = NA),
    shiny::tags$section(id = "pasa-tour-card", role = "dialog", `aria-modal` = "false",
      `aria-labelledby` = "pasa-tour-title", `aria-describedby` = "pasa-tour-copy", hidden = NA,
      shiny::tags$button(id = "pasa-tour-close", type = "button", class = "pasa-tour-close",
        `aria-label` = "Close tour", title = "Close tour — progress is saved for Resume",
        shiny::tags$span(`aria-hidden` = "true", "\u00d7")),
      shiny::tags$p(id = "pasa-tour-progress", class = "pasa-tour-eyebrow"),
      shiny::tags$label(`for` = "pasa-tour-chapter", class = "pasa-tour-chapter-label", "Jump to chapter"),
      shiny::tags$select(id = "pasa-tour-chapter", class = "form-select form-select-sm", `aria-label` = "Tour chapter"),
      shiny::tags$h2(id = "pasa-tour-title", tabindex = "-1"),
      shiny::tags$p(id = "pasa-tour-copy"),
      shiny::tags$p(id = "pasa-tour-wait", role = "status", `aria-live` = "polite"),
      shiny::tags$div(class = "pasa-tour-actions",
        shiny::tags$button(id = "pasa-tour-target", type = "button", class = "btn btn-sm btn-outline-secondary", "Go to control"),
        shiny::tags$button(id = "pasa-tour-field", type = "button", class = "btn btn-sm btn-outline-secondary", hidden = NA, "Next field"),
        shiny::tags$button(id = "pasa-tour-back", type = "button", class = "btn btn-sm btn-outline-secondary", "Back"),
        shiny::tags$button(id = "pasa-tour-next", type = "button", class = "btn btn-sm btn-primary", "Next")),
      shiny::tags$div(class = "pasa-tour-actions pasa-tour-secondary",
        shiny::tags$button(id = "pasa-tour-skip-step", type = "button", class = "btn btn-sm btn-link", "Skip this step"),
        shiny::tags$button(id = "pasa-tour-revisit", type = "button", class = "btn btn-sm btn-link", "Revisit (0)"),
        shiny::tags$button(id = "pasa-tour-exit", type = "button", class = "btn btn-sm btn-link", "Pause tour"))
    )),
    shiny::tags$script(src = "pasa-ui/pasa-tour-details.js", defer = NA),
    shiny::tags$script(src = "pasa-ui/pasa-tour-workspace.js", defer = NA),
    shiny::tags$script(src = "pasa-ui/pasa-tour.js", defer = NA))
}

pasa_onboarding_server <- function(input, output, session,
                                   data_ready = shiny::reactive(FALSE),
                                   has_data = shiny::reactive(FALSE)) {
  mode <- .pasa_tour_storage_mode()
  state <- shiny::reactiveVal(.pasa_tour_read_state(mode))
  ready <- shiny::reactiveVal(FALSE)
  shiny::observeEvent(input$pasa_tour_client_ready, {
    ready(TRUE)
    session$sendCustomMessage("pasa-tour-init", list(
      revision = .pasa_tour_revision, storage = mode, state = state()))
  }, ignoreInit = FALSE)
  shiny::observe({
    shiny::req(ready())
    session$sendCustomMessage("pasa-tour-data", list(
      hasData = isTRUE(has_data()), ready = isTRUE(data_ready()),
      view = if (is.null(input$qc_view)) "" else input$qc_view))
  })
  shiny::observeEvent(input$pasa_tour_state, {
    value <- .pasa_tour_validate_state(input$pasa_tour_state)
    if (is.null(value)) return()
    state(value)
    if (identical(mode, "desktop")) {
      saved <- .pasa_tour_write_state(value, mode)
      if (!saved) session$sendCustomMessage("pasa-tour-storage", list(persistent = FALSE))
    }
  }, ignoreInit = FALSE)
  invisible(state)
}
