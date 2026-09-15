# PASA 1.0.0 release verification

Release commit [`7a1bf96b1149f75ba2dd617a196b6bb3859f1939`](https://github.com/arman-pazuki/PASA/commit/7a1bf96b1149f75ba2dd617a196b6bb3859f1939) passed [Release checks run 35032898132](https://github.com/arman-pazuki/PASA/actions/runs/35032898132) on 2026-09-15 UTC before publication as [v1.0.0](https://github.com/arman-pazuki/PASA/releases/tag/v1.0.0).

| Native environment | Result |
|---|---|
| [Ubuntu 24.04 x86_64, R 4.6.0](https://github.com/arman-pazuki/PASA/actions/runs/35032898132/job/104595265206) | Fresh restore of all 127 locked package versions, environment/source verification and Cairo runtime preflight passed; 34 R checks and 7 Chromium browser checks passed |
| [macOS 15 arm64 (Apple silicon), R 4.6.0](https://github.com/arman-pazuki/PASA/actions/runs/35032898132/job/104595265433) | Fresh restore of all 127 locked package versions, environment/source verification and Cairo runtime preflight passed; 34 R checks and 7 Chromium browser checks passed |

The workflow asserts the OS, native architecture and exact R version, and performs each dependency restore without a restored package cache. The R smoke checks cover startup/assets, CSV and Excel import/export, a real dedicated input worker, numerical metrics, Unicode Cairo PDF export and failed-device handling, ordinary and nested growth, session serialization/validation, deconvolution bootstrap, and agreement between real background-worker and main-process numerical outputs. Browser checks cover welcome/navigation, demo loading, Metrics, Spectra, Advanced Mode, support pages and immediate tour closing. These counts overlap in scope and are not independent defect counts.

Local Windows R 4.6.0 testing also passed the focused repair regressions, 34 merged R smoke checks and seven browser checks. The original review contained 185 numbered findings: 175 confirmed, nine partly correct, and one alleged BOM import failure refuted using the actual file reader. Repairs address the confirmed defects and supported portions of qualified findings. External scientific-validation studies were not recreated or relabelled as release tests.

An additional defect found during hosted startup rejected preloaded xtable `1.8-8` as different from R's equivalent normalized `1.8.8`. The hosted and desktop namespace guards now normalize versions before comparison; different versions remain rejected. Three new regressions are included in the 34-check suite. This later hosting-discovered fix is separate from the original 185 review findings.

Regenerated deployment metadata for this corrected commit contains 132 package records: all 127 locked versions plus five required R-recommended packages. Its 33 application-file checksums match the release. The [deployment manifest](reproducibility/SHINY_MANIFEST.json) SHA-256 is `50d016ee42a1c9d65685dc373f267730c53d655c15a575185a3a812ea3a8d2c9`; hosted results are recorded below.

After installing the exact environment, rerun the portable checks with:

```sh
Rscript --vanilla validation/release/SMOKE_RELEASE.R
```

The workflow additionally installs and runs the development-only Chromium test. The recorded run and commit above identify the tested source; subsequent code or environment changes require their own verification.

These checks establish the tested software behavior. They do not establish pigment identity, calibrated statistical coverage, biological validity, identical rendering or performance on every browser, or compatibility with every Linux distribution. No real feedback submission was made during these checks.

## Hosted verification

[Open PASA online](https://armanpazuki.shinyapps.io/pasa/). The running deployment uses application commit `7a1bf96b1149f75ba2dd617a196b6bb3859f1939` and bundle `12560087`. The following browser checks were recorded on 2026-09-16 (Europe/Prague):

| Hosted check | Result |
|---|---|
| Startup and built-in demo | Passed |
| Real CSV upload | Passed |
| Real XLSX upload and worksheet discovery | Passed: Synthetic Data worksheet selected; 401 rows and five samples |
| Spectra PDF export | Passed: live UI-generated URL fetched over HTTP; saved PDF rendered and visually checked, one page |
| Metrics PDF export | Passed: live UI-generated URL fetched over HTTP; saved PDF rendered and both pages visually checked |
| Information/support tabs | Passed: Analysis settings shortcut hidden |
| Cell Growth manual entry and paste | Passed |
| Session save and restore | Passed: downloaded snapshot restored 401 rows/five samples, all eight OD values, strain name and state across tabs |
| Ordinary deconvolution | Passed: Dual_Peak_450_675, K=1..2 selected K=2; overlay and residual plots loaded |
| K-selection bootstrap | Passed: all 80 draws selected K=2, zero errors; app navigation remained usable |
| Cancellation and worker reuse | Passed: a running K=1..4 bootstrap was canceled; prior accepted results remained; ordinary K=1..2 rerun then completed |

These are deployed-app checks, separate from the native CI browser tests. PDF export tests used the live UI-generated URLs and HTTP retrieval; no native browser save-dialog test is claimed. No feedback was submitted.

This was one synthetic-data session, not a concurrent-user or sustained-load test. No runtime error or out-of-memory event was observed during the reviewed interval, but post-bootstrap memory samples approached the configured 1 GB instance limit (approximately 936–943 MiB), leaving limited observed headroom. These results do not establish hosting capacity for concurrent users; resource and request limits still apply.
