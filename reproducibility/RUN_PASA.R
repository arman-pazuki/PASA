.pasa_run_desktop <- function(app_object, launch_browser, port = NULL,
                              run_app = shiny::runApp) {
  call_args <- list(
    appDir = app_object,
    launch.browser = launch_browser,
    host = "127.0.0.1"
  )
  if (!is.null(port)) call_args$port <- port
  do.call(run_app, call_args)
}

.pasa_configure_launch_mode <- function() {
  hosted_setting <- tolower(trimws(Sys.getenv("SPECTRA_HOSTED_MODE", unset = "")))
  hosted_mode <- hosted_setting %in% c("1", "true", "yes", "on")
  Sys.setenv(SPECTRA_DESKTOP_MODE = if (hosted_mode) "0" else "1")
  invisible(hosted_mode)
}

command_args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", command_args, value = TRUE)
if (length(script_arg) != 1L) {
  stop("Run this launcher with Rscript.")
}

script_file <- normalizePath(
  getOption("pasa.runner_file", sub("^--file=", "", script_arg[[1L]])),
  winslash = "/",
  mustWork = TRUE
)
repro_dir <- dirname(script_file)
package_root <- normalizePath(file.path(repro_dir, ".."), winslash = "/", mustWork = TRUE)
app_root <- normalizePath(file.path(package_root, "source_snapshot"), winslash = "/", mustWork = TRUE)
app_file <- file.path(app_root, "PASA.R")
module_file <- file.path(app_root, "deconvolution_module.R")
loader_file <- file.path(repro_dir, "LOAD_LOCKED_ENVIRONMENT.R")

if (!file.exists(app_file)) stop("Missing main application: ", app_file)
if (!file.exists(module_file)) {
  warning("deconvolution_module.R is missing; Advanced-Mode deconvolution will be unavailable.")
}
if (!file.exists(loader_file)) {
  stop("Missing environment loader: ", loader_file)
}
source(loader_file, local = TRUE, encoding = "UTF-8")
load_pasa_locked_environment(package_root)
if (!requireNamespace("shiny", quietly = TRUE)) {
  stop("Package 'shiny' is unavailable. Restore the locked environment before launch.")
}

Sys.setenv(PASA_APP_DIR = app_root)
# Explicit hosted mode always wins over a desktop-launch request.
.pasa_configure_launch_mode()
setwd(app_root)
app_environment <- new.env(parent = globalenv())
source_result <- source(app_file, local = app_environment, chdir = TRUE, encoding = "UTF-8")
app_object <- source_result$value

if (!inherits(app_object, "shiny.appobj")) {
  stop("PASA.R did not return a Shiny application object.")
}

launch_setting <- tolower(trimws(Sys.getenv("PASA_LAUNCH_BROWSER", unset = "1")))
launch_browser <- !launch_setting %in% c("0", "false", "no", "off")
port_setting <- trimws(Sys.getenv("PASA_PORT", unset = ""))

if (nzchar(port_setting)) {
  port <- suppressWarnings(as.integer(port_setting))
  if (is.na(port) || port < 1L || port > 65535L) {
    stop("PASA_PORT must be an integer from 1 through 65535.")
  }
  .pasa_run_desktop(app_object, launch_browser = launch_browser, port = port)
} else {
  .pasa_run_desktop(app_object, launch_browser = launch_browser)
}
