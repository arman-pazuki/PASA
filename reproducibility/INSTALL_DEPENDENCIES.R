command_args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", command_args, value = TRUE)
if (length(script_arg) != 1L) {
  stop("Run this file with Rscript so the project path can be determined safely.")
}

script_file <- normalizePath(
  sub("^--file=", "", script_arg[[1L]]),
  winslash = "/",
  mustWork = TRUE
)
repro_dir <- dirname(script_file)
package_root <- normalizePath(file.path(repro_dir, ".."), winslash = "/", mustWork = TRUE)
project_dir <- normalizePath(file.path(package_root, "source_snapshot"), winslash = "/", mustWork = TRUE)
repro_lock <- file.path(repro_dir, "renv.lock")
root_lock <- file.path(project_dir, "renv.lock")

if (getRversion() != "4.6.0") {
  stop("Exact restoration requires R 4.6.0; detected ", as.character(getRversion()), ".")
}
if (!file.exists(repro_lock) || !file.exists(root_lock)) {
  stop("Both the reproducibility and source_snapshot renv.lock files must be present.")
}
if (!identical(readBin(repro_lock, "raw", n = file.info(repro_lock)$size),
               readBin(root_lock, "raw", n = file.info(root_lock)$size))) {
  stop("The source_snapshot and reproducibility renv.lock files are not byte-identical.")
}

# A complete local Windows library is already restored in this desktop copy.
# Check it and leave it in place; no network request or installation is needed.
if (.Platform$OS.type == "windows" && dir.exists(file.path(package_root, "runtime", "library"))) {
  source(file.path(repro_dir, "LOAD_LOCKED_ENVIRONMENT.R"), local = TRUE, encoding = "UTF-8")
  load_pasa_locked_environment(package_root)
  cat("DEPENDENCY_LIBRARY_ALREADY_PREPARED\n")
  cat("All locked package versions match. No packages were downloaded.\n")
  quit(save = "no", status = 0L)
}

options(repos = c(CRAN = "https://cloud.r-project.org"))
bootstrap_lib <- file.path(repro_dir, ".renv-bootstrap-library")
if (!dir.exists(bootstrap_lib) && !dir.create(bootstrap_lib, recursive = TRUE)) {
  stop("Could not create the package-local renv bootstrap library: ", bootstrap_lib)
}
.libPaths(unique(c(normalizePath(bootstrap_lib, winslash = "/"), .libPaths())))
# Bootstrap the exact renv record, never whatever release happens to be latest.
lock_lines <- readLines(repro_lock, warn = FALSE)
renv_start <- grep('"renv": {', lock_lines, fixed = TRUE)
if (length(renv_start) != 1L) stop("Cannot locate the renv record in the lockfile.")
version_line <- grep('"Version"', lock_lines[renv_start + seq_len(5L)], value = TRUE)[[1L]]
expected_renv <- strsplit(version_line, '"', fixed = TRUE)[[1L]][[4L]]
installed_renv <- tryCatch(as.character(utils::packageVersion("renv", lib.loc = bootstrap_lib)), error = function(e) "missing")
if (!identical(installed_renv, expected_renv)) {
  archive <- tempfile(fileext = ".tar.gz")
  urls <- sprintf(c("https://cloud.r-project.org/src/contrib/renv_%s.tar.gz",
                    "https://cloud.r-project.org/src/contrib/Archive/renv/renv_%s.tar.gz"), expected_renv)
  obtained <- FALSE
  for (url in urls) {
    status <- tryCatch(suppressWarnings(utils::download.file(url, archive, mode = "wb", quiet = TRUE)), error = function(e) 1L)
    if (identical(status, 0L)) { obtained <- TRUE; break }
  }
  if (!obtained) stop("The locked renv ", expected_renv, " is unavailable from CRAN. No different version was installed.")
  install.packages(archive, repos = NULL, type = "source", lib = bootstrap_lib)
  unlink(archive)
}
if (!identical(as.character(utils::packageVersion("renv", lib.loc = bootstrap_lib)), expected_renv))
  stop("The locked renv bootstrap did not install correctly.")
library(renv, lib.loc = bootstrap_lib)

setwd(project_dir)
renv::activate(project = project_dir)
renv::restore(project = project_dir, library = renv::paths$library(project = project_dir), lockfile = repro_lock, prompt = FALSE)

cat("DEPENDENCY_RESTORE_COMPLETE\n")
cat("Next: run reproducibility/VERIFY_ENVIRONMENT.R\n")
