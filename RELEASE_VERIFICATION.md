# PASA 1.0.0 verification

The application source in this release passed 44 R checks and nine manual browser checks on Windows with R 4.6.0. The checks use the locked package environment and synthetic data.

The R checks cover startup and assets, CSV and Excel import/export, the dedicated input worker, numerical metrics, Unicode Cairo PDF export and failed-device handling, ordinary and nested growth, session serialization and validation, deconvolution bootstrap, and agreement between background-worker and main-process numerical outputs. The browser checks cover welcome and navigation, demo loading, Summary requests, Metrics, Spectra, Advanced Mode, support pages and method descriptions, and closing a guided tour.

The [Release checks workflow](https://github.com/arman-pazuki/PASA/actions/workflows/release-checks.yml) runs the portable checks on Ubuntu and macOS. Each workflow run identifies its tested commit and records the result; consult the run for the source version you use.

After installing the exact environment, run the R checks from the repository root:

```sh
Rscript --vanilla validation/release/SMOKE_RELEASE.R
```

The workflow also installs and runs the development-only Chromium tests in `validation/release/browser`.

The deployment manifest contains all 127 locked package versions and five required R-recommended packages. Its 33 application-file checksums match the supplied source. See [hosting instructions](reproducibility/HOSTED_DEPLOYMENT.md) and the [manifest](reproducibility/SHINY_MANIFEST.json).

These checks establish the tested software behavior. They do not establish pigment identity, calibrated statistical coverage, biological validity, identical rendering or performance on every browser, or hosting capacity under concurrent load. No real feedback submission was made during these checks.
