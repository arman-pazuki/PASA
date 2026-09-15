# Maintainer command: run only after the final source/assets are ready for checks.
args <- commandArgs(FALSE)
script <- normalizePath(sub("^--file=", "", grep("^--file=", args, value = TRUE)[1]),
                        winslash = "/", mustWork = TRUE)
if (!identical(commandArgs(TRUE), "--freeze"))
  stop("No files changed. Pass --freeze only when the source and interface assets are final.")
root <- dirname(dirname(script))
app <- file.path(root, "source_snapshot")
source_files <- list.files(app, recursive = TRUE, all.files = TRUE, no.. = TRUE)
source_files <- source_files[!grepl("^renv/|^\\.Rhistory$|^\\.RData$|^\\.Rprofile$", source_files)]
launch_files <- c("START_PASA.cmd", "START_PASA.R",
  "reproducibility/RUN_PASA.R", "reproducibility/LOAD_LOCKED_ENVIRONMENT.R",
  "reproducibility/VERIFY_ENVIRONMENT.R", "reproducibility/FREEZE_SOURCE_CHECKSUMS.R",
  "reproducibility/INSTALL_DEPENDENCIES.R", "reproducibility/LAUNCH_PASA.ps1",
  "reproducibility/renv.lock")
runtime_records <- c("runtime/PACKAGE_FILES_SHA256.tsv", "runtime/PACKAGE_INVENTORY.tsv",
                     "runtime/LIBRARY_COPY_VERIFICATION.json")
if (!dir.exists(file.path(root, "runtime", "library"))) runtime_records <- character()
relative <- sort(unique(c(paste0("source_snapshot/", source_files), launch_files, runtime_records)))
absolute <- file.path(root, relative)
if (any(!file.exists(absolute))) stop("A source or launch file is missing: ",
                                      paste(relative[!file.exists(absolute)], collapse = ", "))
manifest <- data.frame(path = relative, bytes = file.info(absolute)$size,
                       sha256 = toupper(unname(tools::sha256sum(absolute))))
if (anyNA(manifest$sha256)) stop("A source file could not be hashed.")
target <- file.path(root, "reproducibility", "SOURCE_CHECKSUMS.tsv")
connection <- file(target, "wb")
lines <- c("path\tbytes\tsha256", paste(manifest$path, manifest$bytes, manifest$sha256, sep = "\t"))
writeBin(charToRaw(paste0(paste(lines, collapse = "\n"), "\n")), connection)
close(connection)
cat("SOURCE_CHECKSUMS_WRITTEN", nrow(manifest), "files\n")
cat("Now run VERIFY_ENVIRONMENT.R and the intended regression/UI suites.\n")
