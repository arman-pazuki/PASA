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
failures <- character()

record_failure <- function(...) {
  failures <<- c(failures, paste0(...))
}

if (getRversion() != "4.6.0") {
  record_failure("R version: expected 4.6.0, detected ", as.character(getRversion()))
}

loader_file <- file.path(repro_dir, "LOAD_LOCKED_ENVIRONMENT.R")
if (!file.exists(loader_file)) {
  record_failure("Missing file: reproducibility/LOAD_LOCKED_ENVIRONMENT.R")
} else {
  tryCatch({
    source(loader_file, local = TRUE, encoding = "UTF-8")
    load_pasa_locked_environment(package_root)
  }, error = function(e) {
    record_failure("Locked environment activation failed: ", conditionMessage(e))
  })
}

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  record_failure("Package 'jsonlite' is unavailable; the lock cannot be read.")
} else if (file.exists(repro_lock)) {
  lock <- jsonlite::fromJSON(repro_lock, simplifyVector = FALSE)
  locked <- lock$Packages
  for (package_name in names(locked)) {
    expected <- as.character(locked[[package_name]]$Version)
    expected_normalized <- as.character(base::package_version(expected))
    actual <- tryCatch(as.character(utils::packageVersion(package_name, lib.loc = .libPaths())), error = function(e) NA_character_)
    if (is.na(actual) || !identical(actual, expected_normalized)) {
      record_failure("Package ", package_name, ": expected lock version ", expected,
                     " (normalized ", expected_normalized, "), detected ", actual)
    }
  }
} else {
  record_failure("Missing lock file: ", repro_lock)
}

sha256_file <- function(file_path) {
  if (requireNamespace("digest", quietly = TRUE)) {
    return(toupper(digest::digest(file = file_path, algo = "sha256", serialize = FALSE)))
  }
  if (requireNamespace("openssl", quietly = TRUE)) {
    connection <- file(file_path, open = "rb")
    on.exit(close(connection), add = TRUE)
    return(toupper(as.character(openssl::sha256(connection))))
  }
  record_failure("Neither digest nor openssl is available for SHA-256 verification.")
  NA_character_
}

check_inventory <- function(inventory_file, inventory_root) {
  if (!file.exists(inventory_file)) {
    record_failure("Missing checksum inventory: ", basename(inventory_file),
                   ". This source candidate has not been frozen for distribution.")
    return(invisible(FALSE))
  }
  inventory <- tryCatch(utils::read.delim(inventory_file, sep = "\t", quote = "",
    stringsAsFactors = FALSE, colClasses = "character", check.names = FALSE),
    error = function(e) NULL)
  if (is.null(inventory) || !all(c("path", "bytes", "sha256") %in% names(inventory)) ||
      !nrow(inventory) || anyDuplicated(inventory$path) ||
      any(!grepl("^[A-Fa-f0-9]{64}$", inventory$sha256)) ||
      any(grepl("(^|/)\\.\\.?(/|$)|^[A-Za-z]:|^/|\\\\", inventory$path))) {
    record_failure("Invalid checksum inventory: ", basename(inventory_file))
    return(invisible(FALSE))
  }
  paths <- file.path(inventory_root, inventory$path)
  present <- file.exists(paths) & !dir.exists(paths)
  if (any(!present)) record_failure("Missing inventoried files: ",
                                    paste(inventory$path[!present], collapse = ", "))
  if (any(present)) {
    hashes <- tryCatch(toupper(unname(tools::sha256sum(paths[present]))), error = function(e) {
      record_failure("Checksum inventory could not be read: ", conditionMessage(e))
      rep(NA_character_, sum(present))
    })
    mismatch <- is.na(hashes) | hashes != toupper(inventory$sha256[present]) |
      file.info(paths[present])$size != suppressWarnings(as.numeric(inventory$bytes[present]))
    mismatch[is.na(mismatch)] <- TRUE
    if (any(mismatch)) record_failure("Checksum/size mismatch: ",
      paste(inventory$path[present][mismatch], collapse = ", "))
  }
  invisible(TRUE)
}

check_inventory(file.path(repro_dir, "SOURCE_CHECKSUMS.tsv"), package_root)
runtime_root <- file.path(package_root, "runtime")
if (dir.exists(file.path(runtime_root, "library")))
  check_inventory(file.path(runtime_root, "PACKAGE_FILES_SHA256.tsv"), runtime_root)
if (file.exists(repro_lock) && file.exists(root_lock)) tryCatch({
  a <- sha256_file(repro_lock); b <- sha256_file(root_lock)
  if (is.na(a) || is.na(b) || !identical(a, b)) record_failure("The source and reproducibility lockfiles differ or could not be verified.")
}, error = function(e) record_failure("Lockfile hashing failed: ", conditionMessage(e)))

for (relative_path in c("PASA.R", "deconvolution_module.R")) {
  file_path <- file.path(project_dir, relative_path)
  if (file.exists(file_path)) {
    tryCatch(suppressWarnings(invisible(parse(file = file_path, encoding = "UTF-8"))), error = function(e) {
      record_failure("R parse failure for ", relative_path, ": ", conditionMessage(e))
    })
  }
}

runner_file <- file.path(repro_dir, "RUN_PASA.R")
if (file.exists(runner_file)) {
  tryCatch(suppressWarnings(invisible(parse(file = runner_file, encoding = "UTF-8"))), error = function(e) {
    record_failure("R parse failure for reproducibility/RUN_PASA.R: ", conditionMessage(e))
  })
} else {
  record_failure("Missing file: reproducibility/RUN_PASA.R")
}

cat("R_VERSION=", as.character(getRversion()), "\n", sep = "")
platform_label <- paste0(R.version$platform, "/", .Platform$r_arch)
cat("PLATFORM=", platform_label, "\n", sep = "")
cat("LOCKED_PACKAGE_RECORDS=", if (exists("locked")) length(locked) else 0L, "\n", sep = "")

if (length(failures)) {
  cat("ENVIRONMENT_VERIFICATION_FAIL\n")
  for (failure in failures) cat("- ", failure, "\n", sep = "")
  quit(save = "no", status = 1L)
}

cat("ENVIRONMENT_VERIFICATION_PASS\n")
