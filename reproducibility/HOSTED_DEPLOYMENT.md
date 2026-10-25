# Deploy PASA 1.0.0 to Shiny

The live app is [PASA on shinyapps.io](https://armanpazuki.shinyapps.io/pasa/).

Deploy the 33 files in `source_snapshot`, with `app.R` as the entry point, using the supplied [SHINY_MANIFEST.json](SHINY_MANIFEST.json). The manifest specifies **R 4.6.0**, preserves every locked package version, and includes the required R-recommended dependencies. Its file checksums identify the application files to deploy.

Keep credentials and deployment records outside the application and Git. Restore the release environment and configure your hosting account. The deployment client is **rsconnect 1.11.0**; deployment tools are separate from the application package lock. From the repository root:

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

Choose your configured account when prompted. To update an existing deployment, use its verified application ID and saved records. Supplying `manifestPath` makes rsconnect use the manifest's file list and metadata. Do not upload an installed Windows library. File paths in the manifest resolve against `source_snapshot`; the manifest itself can remain in `reproducibility`. See the [official deployApp API](https://rstudio.github.io/rsconnect/reference/deployApp.html).

## Runtime dependencies

The manifest contains **all 127 locked versions plus five required R-recommended packages**:

| Package | Exact version |
|---|---|
| boot | 1.3-32 |
| lattice | 0.22-9 |
| MASS | 7.3-65 |
| Matrix | 1.7-5 |
| nlme | 3.1-169 |

The full recursive **Depends, Imports and LinkingTo** graph and every declared version constraint must be satisfied. R and its base packages are supplied by the exact runtime. All 132 package records use CRAN. Suggested packages are not recursively expanded; the release lock records the supported feature set. The manifest pins package versions and R, but not the host operating-system image or resource limits.

If application files or dependencies change, regenerate the manifest, preserve the intended locked versions, complete the required dependency graph, and check all file hashes and version constraints. See rsconnect's [dependency resolution](https://rstudio.github.io/rsconnect/reference/appDependencies.html) and [manifest creation](https://rstudio.github.io/rsconnect/reference/writeManifest.html).

## Verify the hosted application

The hosted entry point checks exact R and package versions, selects a UTF-8 locale, and disables typed server-file paths. The namespace guards accept equivalent version forms such as `1.8-8` and `1.8.8` while rejecting different versions. The app does not install packages at startup.

After deployment, inspect build and runtime logs and test the actual URL: demo loading, CSV/XLSX upload and worksheet discovery, Metrics and Spectra, PDF downloads, saved sessions, manual growth, ordinary deconvolution, and bootstrap cancellation. Confirm that background jobs complete and canceled work does not replace the previous result. Test representative workloads and concurrency before making hosting-capacity assumptions. [Release verification](../RELEASE_VERIFICATION.md) describes the checks performed on the supplied source.
