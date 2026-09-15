# Quick start for PASA 1.0.0

Allow approximately 10–15 minutes after the R environment has been restored.

## 1. Verify and launch

Install exact R 4.6.0. From the PASA root, restore and verify the pinned environment before launching:

```sh
Rscript --vanilla reproducibility/INSTALL_DEPENDENCIES.R
Rscript --vanilla reproducibility/VERIFY_ENVIRONMENT.R
Rscript --vanilla START_PASA.R
```

The initial restoration needs internet access unless a complete compatible offline library is already supplied. Linux and macOS source builds also need the native dependencies in [R and package requirements](../reproducibility/R_PACKAGE_REQUIREMENTS.md); use native packages for the actual OS and architecture. Follow the current [release verification record](../RELEASE_VERIFICATION.md) for executed platform checks.

On Windows, after restoring the environment, you can instead double-click `START_PASA.cmd` or run this in PowerShell:

```powershell
.\START_PASA.cmd
```

The launcher checks R and locked package versions before starting. The launch console should show `Listening on http://127.0.0.1:<port>` and open the local app in a browser. Local-file analysis works offline once dependencies are installed.

## 2. Load the deterministic example

1. Open **Input data** and choose **Local** in Data source.
2. Select `examples/EXAMPLE_SYNTHETIC_SPECTRA.xlsx`.
3. If sheet selection is shown, choose **Synthetic Data**.
4. Click **Load data**.
5. Confirm: wavelength 350–750 nm, 1-nm spacing, 401 rows/points, and five spectra after the wavelength column.

The five spectra are `Blank`, `Single_Peak_450`, `Dual_Peak_450_675`, `Baseline_Shifted`, and `Deterministic_Ripple`.

## 3. Use a transparent primary configuration

- wavelength: 350–750 nm;
- baseline correction: off;
- resampling: off/native grid;
- smoothing: none;
- dilution factor: 1 for every spectrum;
- normalization: none; and
- include all five spectra for import/plot checks, excluding `Blank` from correlation or angle interpretations where a non-zero norm is required.

If the organism/sample-type controls require a choice, use one consistent choice for the walkthrough and state that the input is mathematical, not a biological specimen.

## 4. Inspect the app

Use the navigation order:

**Input data → Analysis settings → Summary → Spectra → Metrics → Band AUC → Data Quality → [Deconvolution] → Sample Color → Cell Growth → About → Help → FAQ → References → Feedback**

When **Advanced Mode** is enabled, **Deconvolution** appears immediately after Data Quality.

At minimum confirm:

- the Spectra plot renders all selected traces;
- the single and dual constructed features appear near their documented centers;
- Metrics and Band AUC identify coverage limitations instead of inventing values;
- Data Quality handles the zero blank and deterministic ripple transparently; and
- exports can be generated for the processed data and session state.

## 5. Run one sensitivity contrast

Compare **smoothing off** with a documented smoothing setting for `Deterministic_Ripple`, or compare **baseline off** with the justified baseline method for `Baseline_Shifted`. Record both settings and outputs; do not present the preferred-looking result alone.

## 6. Stop

Stop the app with `Ctrl+C` in the launch terminal or the RStudio stop control. Local in-memory session data are then released subject to ordinary R/operating-system cleanup.
