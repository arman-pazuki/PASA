# Entry point used by START_PASA.cmd; paths follow this extracted folder.
pasa_args <- commandArgs(trailingOnly = FALSE)
pasa_script_arg <- grep("^--file=", pasa_args, value = TRUE)
if (length(pasa_script_arg) != 1L) stop("Run START_PASA.R with Rscript.")
pasa_start_file <- normalizePath(sub("^--file=", "", pasa_script_arg[[1L]]),
                                 winslash = "/", mustWork = TRUE)
pasa_runner <- file.path(dirname(pasa_start_file), "reproducibility", "RUN_PASA.R")
options(pasa.runner_file = pasa_runner)
source(pasa_runner, local = new.env(parent = globalenv()), encoding = "UTF-8")
