# Deploy PASA 1.0.0 to Shiny

The live app is [PASA on shinyapps.io](https://armanpazuki.shinyapps.io/pasa/). See [release verification](../RELEASE_VERIFICATION.md) for recorded hosted checks.

Deploy the 33 files in `source_snapshot`, with `app.R` as the entry point, using the supplied [SHINY_MANIFEST.json](SHINY_MANIFEST.json). The manifest was prepared for application commit `7a1bf96b1149f75ba2dd617a196b6bb3859f1939` and exact **R 4.6.0**. It preserves every locked package version and includes the required recommended-package dependencies. Its SHA-256 is `50d016ee42a1c9d65685dc373f267730c53d655c15a575185a3a812ea3a8d2c9`.

Keep credentials and deployment records outside the application and Git. Restore the release environment first and configure your own hosting account. The tested deployment client is **rsconnect 1.11.0**; deployment tools are not part of the application's package lock. From the repository root:

```r
stopifnot(getRversion() == "4.6.0",
          utils::packageVersion("rsconnect") == package_version("1.11.0"))
app_dir <- normalizePath("source_snapshot", mustWork = TRUE)
manifest_path <- normalizePath("reproducibility/SHINY_MANIFEST.json", mustWork = TRUE)
manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
stopifnot(manifest$platform == "4.6.0",
          manifest$environment$r$requires == "==4.6.0",
          length(manifest$files) == 33L, length(manifest$packages) == 132L)
expected <- vapply(manifest$files, function(x) x$checksum, character(1))
actual <- tools::md5sum(file.path(app_dir, names(expected)))
stopifnot(identical(unname(actual), unname(expected)))
record_dir <- file.path(tools::R_user_dir("PASA", "data"), "deployments")
dir.create(record_dir, recursive = TRUE, showWarnings = FALSE)
rsconnect::deployApp(
  appDir = app_dir, manifestPath = manifest_path,
  appName = "pasa", server = "shinyapps.io",
  recordDir = record_dir, launch.browser = FALSE
)
```

Choose your configured account when prompted. For an existing deployment, use its verified identity and saved records. Supplying `manifestPath` makes rsconnect use that manifest's file list and metadata instead of generating an incomplete replacement. Do not upload an installed Windows library. The manifest's file paths resolve against `source_snapshot`; the manifest itself can remain in `reproducibility`. See the [official deployApp API](https://rstudio.github.io/rsconnect/reference/deployApp.html).

## Why the manifest has 132 packages

In rsconnect 1.11.0, strict resolution of this release's `renv.lock` emitted only its 127 entries and omitted five required R-recommended packages. The initial hosting build therefore rejected missing MASS. The supplied manifest contains **all 127 unchanged locked versions plus these five packages**:

| Package | Exact version |
|---|---|
| boot | 1.3-32 |
| lattice | 0.22-9 |
| MASS | 7.3-65 |
| Matrix | 1.7-5 |
| nlme | 3.1-169 |

The full recursive **Depends, Imports and LinkingTo** graph and every declared version constraint were checked. Only R and its base packages are satisfied by the exact runtime without manifest records. All 132 records use CRAN. Suggested packages are not recursively expanded; the release lock already records its supported feature set. The manifest pins package versions and R, not the host operating-system image or resource limits.

If application files or dependencies change, regenerate the manifest, preserve the intended locked versions, complete the required dependency graph, and recheck all file hashes and version constraints. Do not reuse this manifest against modified source. See rsconnect's [dependency resolution](https://rstudio.github.io/rsconnect/reference/appDependencies.html) and [manifest creation](https://rstudio.github.io/rsconnect/reference/writeManifest.html).

## Verify the hosted application

The hosted entry point checks exact R/package versions, selects a UTF-8 locale, and disables typed server-file paths. A correction in this release normalizes loaded namespace versions so equivalent xtable strings `1.8-8` and `1.8.8` are accepted while genuinely different versions are refused. The app does not install packages at startup.

After deployment, inspect build/runtime logs and test the actual URL: demo, CSV/XLSX upload and worksheet discovery, Metrics/Spectra, real PDF downloads, saved sessions, manual growth, ordinary deconvolution and bootstrap cancellation. Confirm background jobs complete and canceled work does not replace the previous result. The current deployment passed startup, demo, file uploads and worksheet discovery, PDF export retrieval/rendering, information-tab checks, manual growth/paste, downloaded-session restoration, ordinary deconvolution, a complete 80-draw bootstrap, cancellation with prior-result preservation, and worker reuse after cancellation. PDF files were retrieved over HTTP from the live UI-generated download URLs; native browser save dialogs were not tested. [Release verification](../RELEASE_VERIFICATION.md) records the current scope.

Hosting observations cover one synthetic-data session, not concurrency or capacity validation. No runtime error or out-of-memory event was observed in the reviewed interval, but post-bootstrap memory samples reached approximately 936–943 MiB on the configured 1 GB instance, leaving limited observed headroom. Test representative workloads and concurrency before making capacity assumptions.
