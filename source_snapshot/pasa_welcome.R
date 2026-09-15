# Local welcome artwork and animation. Navigation is wired by the main app.
pasa_welcome_dependencies <- function(asset_dir = NULL) {
  if (is.null(asset_dir)) {
    app_root <- if (exists(".pasa_source_root", mode = "function")) {
      .pasa_source_root()
    } else {
      Sys.getenv("PASA_APP_DIR", unset = getwd())
    }
    asset_dir <- file.path(app_root, "www")
  }
  asset_dir <- normalizePath(asset_dir, winslash = "/", mustWork = TRUE)
  shiny::addResourcePath("pasa-ui", asset_dir)
  htmltools::singleton(htmltools::tagList(
    shiny::tags$link(rel = "stylesheet", href = "pasa-ui/pasa-welcome.css"),
    shiny::tags$script(src = "pasa-ui/pasa-welcome.js", defer = "defer")
  ))
}

pasa_welcome_ui <- function(asset_dir = NULL) {
  if (is.null(asset_dir)) {
    app_root <- if (exists(".pasa_source_root", mode = "function")) {
      .pasa_source_root()
    } else {
      Sys.getenv("PASA_APP_DIR", unset = getwd())
    }
    asset_dir <- file.path(app_root, "www")
  }
  htmltools::tagList(
    pasa_welcome_dependencies(asset_dir),
    shiny::tags$section(
      id = "pasa-welcome", class = "pasa-welcome",
      `aria-labelledby` = "pasa-welcome-heading", `data-motion` = "paused",
      shiny::tags$header(
        class = "pasa-welcome-heading",
        shiny::tags$h1(id = "pasa-welcome-heading", "Welcome to PASA"),
        shiny::tags$p("Explore the shape and magnitude of your spectra.")
      ),
      shiny::tags$figure(
        class = "pasa-welcome-figure",
        htmltools::includeHTML(file.path(asset_dir, "pasa-welcome-scene.svg")),
        shiny::tags$figcaption(
          shiny::tags$span("Illustrative spectrum"),
          shiny::tags$span(class = "pasa-welcome-motion-state", `aria-live` = "polite", "Animation paused")
        )
      ),
      shiny::tags$div(
        class = "pasa-welcome-actions",
        shiny::actionButton("pasa_welcome_open", "Open PASA", class = "btn-primary"),
        shiny::actionButton("pasa_welcome_tour", "Start guided tour", class = "btn-outline-secondary"),
        shiny::tags$button(
          type = "button", id = "pasa-welcome-pause",
          class = "btn btn-outline-secondary pasa-welcome-pause",
          `aria-controls` = "pasa-welcome-scene",
          "Play animation"
        )
      )
    )
  )
}
