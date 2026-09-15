# Dedicated background reader profile: input and feedback jobs do not queue
# behind a long numerical bootstrap. No request is made before an explicit action.
.pasa_io_state <- new.env(parent = emptyenv())
.pasa_io_state$ready <- FALSE
.pasa_io_state$restart_pending <- FALSE
.pasa_io_state$active <- 0L
.PASA_IO_MAX_JOBS <- 32L
.pasa_io_invalidate <- function() {
  # A task failure is not permission to reset another session's live worker.
  .pasa_io_state$restart_pending <- TRUE
  invisible()
}
.pasa_io_submit <- function(kind, args, budget) {
  if (!requireNamespace("mirai", quietly = TRUE) || !requireNamespace("later", quietly = TRUE))
    stop("Background reading requires the bundled mirai and later packages. Restore the locked dependencies, or upload a local file of at most 2 MiB.")
  if (.pasa_io_state$active >= .PASA_IO_MAX_JOBS)
    stop("The background reader is busy. Please retry after a pending operation finishes.")
  profile <- "pasa-io"
  if ((!isTRUE(.pasa_io_state$ready) || isTRUE(.pasa_io_state$restart_pending)) &&
      .pasa_io_state$active == 0L) {
    mirai::daemons(1L, .compute = profile)
    .pasa_io_state$ready <- TRUE
    .pasa_io_state$restart_pending <- FALSE
  }
  started <- tempfile("pasa-io-start-")
  source_root <- .pasa_source_root()
  task <- tryCatch(mirai::mirai({
    writeLines(sprintf("%.6f", as.numeric(Sys.time())), STARTED)
    task_deadline <- Sys.time() + BUDGET
    if (nzchar(LIB)) .libPaths(unique(c(LIB, .libPaths())))
    Sys.setenv(SPECTRA_HOSTED_MODE = HOSTED, SPECTRA_DESKTOP_MODE = DESKTOP, PASA_APP_DIR = ROOT)
    # A restarted daemon loads its own functions on its next job; no stale
    # process-wide readiness flag can leave it permanently uninitialized.
    key <- paste(ROOT, file.info(file.path(ROOT, "PASA.R"))$mtime)
    if (!exists(".pasa_io_loaded_key", envir = .GlobalEnv, inherits = FALSE) ||
        !identical(get(".pasa_io_loaded_key", envir = .GlobalEnv), key)) {
      old <- setwd(ROOT); on.exit(setwd(old), add = TRUE)
      expressions <- parse(file.path(ROOT, "PASA.R"), encoding = "UTF-8")
      suppressWarnings(suppressMessages(eval(expressions[-length(expressions)], envir = .GlobalEnv)))
      assign(".pasa_io_loaded_key", key, envir = .GlobalEnv)
    }
    answer <- switch(KIND,
      load = .load_spectra_worker(ARGS$use_file, ARGS$path, ARGS$ext,
                                  sheet = ARGS$sheet, deadline = task_deadline),
      sheets = if (isTRUE(ARGS$remote)) list_sheets_any(ARGS$path, deadline = task_deadline)
               else readxl::excel_sheets(ARGS$path),
      feedback = .pasa_feedback_send(ARGS$config, ARGS$rating, ARGS$comment, ARGS$version),
      stop("Unknown background reader operation"))
    if (Sys.time() > task_deadline) stop("The background operation exceeded its execution time limit.")
    answer
  }, KIND = kind, ARGS = args, BUDGET = budget, STARTED = started,
     ROOT = source_root, LIB = Sys.getenv("PASA_R_LIB", unset = ""),
     HOSTED = Sys.getenv("SPECTRA_HOSTED_MODE", unset = "1"),
     DESKTOP = Sys.getenv("SPECTRA_DESKTOP_MODE", unset = "0"), .compute = profile),
    error = function(e) { unlink(started); .pasa_io_invalidate(); stop(e) })
  .pasa_io_state$active <- .pasa_io_state$active + 1L
  released <- FALSE
  release <- function() {
    if (!released) {
      released <<- TRUE
      .pasa_io_state$active <- .pasa_io_state$active - 1L
    }
    invisible()
  }
  list(handle = task, started = started, queued = Sys.time(), budget = budget, release = release)
}

.pasa_io_runner <- function(session) {
  state <- new.env(parent = emptyenv())
  state$closed <- FALSE; state$next_id <- 0L; state$jobs <- list()
  session$onSessionEnded(function() {
    state$closed <- TRUE
    for (cancel in state$jobs) tryCatch(cancel(), error = function(e) NULL)
    state$jobs <- list()
  })
  function(kind, args, on_result, on_error, budget = 120, on_status = NULL) {
    if (state$closed) return(NULL)
    state$next_id <- state$next_id + 1L; id <- as.character(state$next_id)
    job <- tryCatch(.pasa_io_submit(kind, args, budget), error = function(e) e)
    if (inherits(job, "error")) {
      shiny::withReactiveDomain(session, shiny::isolate(on_error(conditionMessage(job))))
      return(NULL)
    }
    done <- FALSE; cleaned <- FALSE; start_time <- NULL
    cleanup <- function() {
      if (cleaned) return(invisible(TRUE))
      if (!.pasa_task_terminal(job$handle)) return(invisible(FALSE))
      unlink(job$started)
      job$release()
      cleaned <<- TRUE
      state$jobs[[id]] <- NULL
      invisible(TRUE)
    }
    cancel <- function() {
      if (done) return(invisible(cleaned))
      # Suppress scheduled polling before requesting termination. A failed stop
      # retains its handle and release token in the durable process reaper.
      done <<- TRUE
      if (identical(.pasa_task_stop_once(job$handle), "TERMINAL_CONFIRMED")) return(cleanup())
      .pasa_orphan_enroll(job$handle, cleanup, task_id = paste0("io_", kind))
      invisible(FALSE)
    }
    state$jobs[[id]] <- cancel
    fail <- function(message, invalidate = FALSE) {
      if (done) return(invisible())
      cancel()
      if (invalidate) .pasa_io_invalidate()
      if (!state$closed) shiny::withReactiveDomain(session, shiny::isolate(on_error(message)))
      invisible()
    }
    poll <- function() {
      if (done || state$closed) return(invisible())
      tryCatch({
        if (is.null(start_time) && file.exists(job$started)) {
          stamp <- suppressWarnings(as.numeric(readLines(job$started, warn = FALSE, n = 1L)))
          if (length(stamp) == 1L && is.finite(stamp)) {
            start_time <<- as.POSIXct(stamp, origin = "1970-01-01", tz = "UTC")
            if (is.function(on_status)) shiny::withReactiveDomain(session, shiny::isolate(on_status("running")))
          }
        }
        if (mirai::unresolved(job$handle)) {
          if (is.null(start_time) && as.numeric(difftime(Sys.time(), job$queued, units = "secs")) > 180)
            return(fail("The background reader is busy or could not start. Please retry; the file has not been read.", TRUE))
          if (!is.null(start_time) && Sys.time() > start_time + job$budget)
            return(fail(sprintf("The background operation exceeded its %.0f-second execution limit.", job$budget), TRUE))
          later::later(poll, 0.15)
          return(invisible())
        }
        result <- job$handle$data
        if (inherits(result, c("miraiError", "errorValue")))
          return(fail(paste("Background worker failed:", paste(as.character(result), collapse = " ")), TRUE))
        done <<- TRUE
        cleanup()
        deadline <- (start_time %||% Sys.time()) + job$budget
        shiny::withReactiveDomain(session, shiny::isolate(on_result(result, deadline)))
      }, error = function(e) {
        # Reporting errors must never escape later's event loop.
        if (!done) fail(conditionMessage(e), TRUE)
        else if (!state$closed) tryCatch(shiny::withReactiveDomain(session,
          shiny::isolate(on_error(conditionMessage(e)))), error = function(e) NULL)
      })
      invisible()
    }
    later::later(poll, 0)
    list(handle = job$handle, cancel = cancel, cleanup = cleanup)
  }
}
