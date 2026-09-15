# Select a prepared library without installing packages or contacting a server.
# The desktop copy carries ordinary package directories in runtime/library.
.pasa_configure_sass_cache <- local({
  selected <- new.env(parent = emptyenv())
  writable_directory <- function(path) {
    tryCatch(suppressWarnings({
      if (!dir.exists(path) && !dir.create(path, recursive = TRUE, showWarnings = FALSE))
        return(FALSE)
      probe <- tempfile(".pasa-write-check-", tmpdir = path)
      on.exit(unlink(probe, recursive = FALSE), add = TRUE)
      connection <- file(probe, open = "wb")
      tryCatch(writeBin(as.raw(0), connection), finally = close(connection))
      TRUE
    }), error = function(e) FALSE)
  }
  function(package_root) {
    key <- normalizePath(package_root, winslash = "/", mustWork = FALSE)
    if (!exists(key, envir = selected, inherits = FALSE)) {
      candidate <- file.path(key, "runtime", "cache", "sass")
      if (!writable_directory(candidate)) {
        # Select one fallback for this app/process; do not revisit AppData on
        # every Sass compilation or warn repeatedly in read-only deployments.
        candidate <- tempfile("pasa-sass-", tmpdir = tempdir())
        if (!writable_directory(candidate)) candidate <- FALSE
      }
      if (is.character(candidate))
        candidate <- normalizePath(candidate, winslash = "/", mustWork = TRUE)
      assign(key, candidate, envir = selected)
    }
    chosen <- get(key, envir = selected, inherits = FALSE)
    options(sass.cache = chosen)
    invisible(chosen)
  }
})

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

.pasa_check_locked_library <- function(lockfile, prepared) {
  lock <- jsonlite::fromJSON(lockfile, simplifyVector = FALSE)
  if (!identical(as.character(getRversion()), as.character(lock$R$Version)))
    stop("This PASA environment requires R ", lock$R$Version,
       "; detected ", as.character(getRversion()), ".")
  errors <- character()
  for (package_name in names(lock$Packages)) {
    expected <- as.character(package_version(lock$Packages[[package_name]]$Version))
    actual <- tryCatch(as.character(utils::packageVersion(package_name, lib.loc = prepared)),
             error = function(e) "missing")
    if (!identical(actual, expected))
    errors <- c(errors, paste0(package_name, ": expected ", expected, ", found ", actual))
    description <- file.path(prepared, package_name, "DESCRIPTION")
    built <- if (file.exists(description)) tryCatch(read.dcf(description, fields = "Built")[[1L]], error = function(e) NA_character_) else NA_character_
    if (!is.na(built)) {
      fields <- trimws(strsplit(built, ";", fixed = TRUE)[[1L]])
      # Pure-R packages have an empty platform field; compiled packages must
      # belong to this architecture/OS. Patch-level build-R differences remain
      # visible in PACKAGE_INVENTORY.tsv rather than being silently relabelled.
      if (length(fields) >= 2L && nzchar(fields[2L]) && !identical(fields[2L], R.version$platform))
        errors <- c(errors, paste0(package_name, ": built for ", fields[2L], "; current platform is ", R.version$platform))
    }
    if (package_name %in% loadedNamespaces() &&
      !identical(as.character(getNamespaceVersion(package_name)), expected))
    errors <- c(errors, paste0(package_name, ": a different version is already loaded; restart R"))
  }
  if (length(errors)) stop("Prepared PASA library does not match renv.lock:\n",
               paste(errors, collapse = "\n"))
  invisible(TRUE)
}

load_pasa_locked_environment <- function(package_root) {
  .pasa_configure_utf8()
  package_root <- normalizePath(package_root, winslash = "/", mustWork = TRUE)
  .pasa_configure_sass_cache(package_root)
  project_dir <- normalizePath(file.path(package_root, "source_snapshot"),
                               winslash = "/", mustWork = TRUE)
  lockfile <- file.path(project_dir, "renv.lock")
  if (!file.exists(lockfile)) stop("Missing source_snapshot/renv.lock.")

  supplied <- Sys.getenv("PASA_R_LIB", unset = "")
  bundled <- file.path(package_root, "runtime", "library")
  prepared <- if (nzchar(supplied)) supplied else if (
    .Platform$OS.type == "windows" && dir.exists(bundled)) bundled else ""

  if (nzchar(prepared)) {
    if (!dir.exists(prepared)) stop("PASA_R_LIB is not an existing package library.")
    prepared <- normalizePath(prepared, winslash = "/", mustWork = TRUE)
    # R-recommended packages remain part of the required R installation.
    .libPaths(unique(c(prepared, .Library)))
    if (!file.exists(file.path(prepared, "jsonlite", "DESCRIPTION")))
      stop("The prepared PASA library is incomplete: jsonlite is missing.")
    if (!requireNamespace("jsonlite", quietly = TRUE))
      stop("The prepared jsonlite package could not be loaded.")
    .pasa_check_locked_library(lockfile, prepared)
    Sys.setenv(PASA_R_LIB = prepared,
               R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))
    return(invisible(project_dir))
  }

  bootstrap_lib <- file.path(package_root, "reproducibility", ".renv-bootstrap-library")
  if (dir.exists(bootstrap_lib)) .libPaths(unique(c(bootstrap_lib, .libPaths())))
  if (!requireNamespace("renv", quietly = TRUE))
    stop("No prepared PASA library was found. Run reproducibility/INSTALL_DEPENDENCIES.R.")
  renv::load(project = project_dir)
  prepared <- renv::paths$library(project = project_dir)
  # Keep unrelated global libraries out of subsequent package lookup.
  .libPaths(unique(c(prepared, .Library)))
  .pasa_check_locked_library(lockfile, prepared)
  Sys.setenv(PASA_R_LIB = prepared, R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))
  invisible(project_dir)
}
