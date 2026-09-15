# PASA 1.0.0 release verification

Public release requires R 4.6.0 checks on **Ubuntu 24.04 x86_64** and **macOS 15 arm64 (Apple silicon)**. The [Release checks workflow](https://github.com/arman-pazuki/PASA/actions/workflows/release-checks.yml) asserts the operating system, native architecture, and R version before testing a fresh exact-lock installation, source checksums, functional smoke tests, and browser interaction.

Local Windows R 4.6.0 testing passed the focused review-fix regressions and the merged application smoke test. The portable smoke exercises startup/assets, CSV and Excel input/output, numerical metrics, Cairo PDF output, ordinary and nested growth, session serialization/validation, deconvolution bootstrap, and real background workers. Browser checks cover welcome/navigation, demo loading, Metrics, Spectra, Advanced Mode, support pages, and tour closing.

The original review contained 185 numbered findings: 175 were confirmed, nine partly correct, and one alleged BOM import failure was refuted using the actual file reader. Repairs address the confirmed defects and supported portions of qualified findings. Missing external scientific-validation studies have not been invented or relabelled as release tests.

Run the portable checks after installation:

```sh
Rscript --vanilla validation/release/SMOKE_RELEASE.R
```

The workflow also installs and runs the development-only Chromium smoke test. Its logs identify the tested Git commit, OS, architecture, R version, package restoration, and individual checks. Release notes link the successful platform run used for publication.

These checks establish the tested software behavior. They do not establish pigment identity, calibrated statistical coverage, biological validity, identical rendering/performance on every browser, or compatibility with every Linux distribution.

Shiny hosting is a separate environment and requires its own deployed-app verification. The public README will link the live app after a successful deployment.
