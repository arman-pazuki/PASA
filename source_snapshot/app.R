# Standard Shiny deployment entry point. Deploy this complete source_snapshot
# directory after restoring its dependencies on the hosting platform.
# This wrapper never enables local server-path input.
.pasa_configure_utf8 <- function() {
  if (isTRUE(l10n_info()[["UTF-8"]])) return(invisible(TRUE))
  candidates <- if (.Platform$OS.type == "windows") c(".UTF-8", "English_United States.utf8")
                else c("C.UTF-8", "en_US.UTF-8", "UTF-8")
  for (candidate in candidates) {
    suppressWarnings(try(Sys.setlocale("LC_CTYPE", candidate), silent = TRUE))
    if (isTRUE(l10n_info()[["UTF-8"]])) return(invisible(TRUE))
  }
  stop("PASA requires a UTF-8 character locale. Enable a UTF-8 locale on this operating system and restart R.")
}
.pasa_configure_utf8()
Sys.setenv(SPECTRA_HOSTED_MODE = "1", SPECTRA_DESKTOP_MODE = "0")
pasa_hosted_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(pasa_hosted_root, "PASA.R")))
  stop("Launch the complete source_snapshot directory as the Shiny application.")
if (!identical(as.character(getRversion()), "4.6.0"))
  stop("This PASA release requires R 4.6.0; detected ", as.character(getRversion()), ".")
pasa_hosted_library <- Sys.getenv("PASA_R_LIB", unset = "")
if (nzchar(pasa_hosted_library)) {
  if (!dir.exists(pasa_hosted_library)) stop("PASA_R_LIB is not an existing native package library.")
  .libPaths(unique(c(normalizePath(pasa_hosted_library, winslash = "/", mustWork = TRUE), .Library)))
}
if (!requireNamespace("jsonlite", quietly = TRUE))
  stop("Restore this release's renv.lock on the hosting platform before starting PASA; jsonlite is unavailable.")
pasa_hosted_lock <- file.path(pasa_hosted_root, "renv.lock")
if (!file.exists(pasa_hosted_lock)) stop("The hosted source directory is missing renv.lock.")
pasa_hosted_lock <- jsonlite::fromJSON(pasa_hosted_lock, simplifyVector = FALSE)
if (!identical(as.character(pasa_hosted_lock$R$Version), as.character(getRversion())))
  stop("The hosting R version does not match renv.lock.")
pasa_hosted_errors <- character()
for (package_name in names(pasa_hosted_lock$Packages)) {
  expected <- as.character(package_version(pasa_hosted_lock$Packages[[package_name]]$Version))
  actual <- tryCatch(as.character(utils::packageVersion(package_name, lib.loc = .libPaths())), error = function(e) "missing")
  if (!identical(actual, expected))
    pasa_hosted_errors <- c(pasa_hosted_errors, paste0(package_name, ": expected ", expected, ", found ", actual))
  if (package_name %in% loadedNamespaces() && !identical(as.character(package_version(getNamespaceVersion(package_name))), expected))
    pasa_hosted_errors <- c(pasa_hosted_errors, paste0(package_name, ": a different version is already loaded; restart the host process"))
  package_dir <- tryCatch(find.package(package_name, lib.loc = .libPaths(), quiet = TRUE), error = function(e) character())
  if (length(package_dir)) {
    built <- tryCatch(read.dcf(file.path(package_dir, "DESCRIPTION"), fields = "Built")[[1L]], error = function(e) NA_character_)
    if (!is.na(built)) {
      fields <- trimws(strsplit(built, ";", fixed = TRUE)[[1L]])
      if (length(fields) >= 2L && nzchar(fields[2L]) && !identical(fields[2L], R.version$platform))
        pasa_hosted_errors <- c(pasa_hosted_errors, paste0(package_name, ": built for ", fields[2L], "; host is ", R.version$platform))
    }
  }
}
if (length(pasa_hosted_errors))
  stop("The hosting library does not match the release lock:\n", paste(pasa_hosted_errors, collapse = "\n"))
Sys.setenv(PASA_APP_DIR = pasa_hosted_root)
pasa_hosted_env <- new.env(parent = globalenv())
pasa_hosted_result <- source(file.path(pasa_hosted_root, "PASA.R"),
                             local = pasa_hosted_env, chdir = TRUE, encoding = "UTF-8")
if (!inherits(pasa_hosted_result$value, "shiny.appobj"))
  stop("PASA.R did not return a Shiny application object.")
pasa_hosted_result$value
