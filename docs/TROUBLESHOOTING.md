# Troubleshooting

For input validation, Noise QC, background analysis and exports, see [Controls and result availability](REPAIR_BEHAVIOR.md).

These notes apply to PASA 1.0.0 (`PASA-NUMERICS-1.0.0`). Preserve the run's numerical-methods identifier
when comparing it with an older analysis.

## App does not start

1. From the package root, run `Rscript --vanilla reproducibility/VERIFY_ENVIRONMENT.R`. If dependencies have not been restored, first run `Rscript --vanilla reproducibility/INSTALL_DEPENDENCIES.R`.
2. Preserve the extracted layout: `source_snapshot/PASA.R`, `source_snapshot/deconvolution_module.R`, their helper files, and resources must remain together.
3. Confirm exact R 4.6.0 is being used. Launch through `START_PASA.R` or the Windows `START_PASA.cmd` so the checked locked library is selected. A custom `PASA_R_LIB` must contain the complete locked native packages; do not copy Windows packages to Linux or macOS. See [R and package requirements](../reproducibility/R_PACKAGE_REQUIREMENTS.md).
4. Read the first console error; do not diagnose a browser symptom before resolving an R startup/package error.
5. If `Rscript.exe - Application Error` appears, close the crashed process, preserve the console/log, restart R, and rerun verification. Repeated native crashes can involve a package binary, graphics/browser subprocess, security software, or system instability and should not be classified as app-analysis failure without evidence.

## Browser does not open or firewall prompts repeat

- Copy the console's `http://127.0.0.1:<port>` address into a supported browser.
- PASA uses loopback; the port can change at each launch. Do not create a broad internet exception merely to fix a local-port prompt.
- Check which application the firewall prompt identifies. Use your intended modern browser; Chrome is not required for ordinary interactive use. Browser capture exports have separate Chrome/Chromium requirements.
- Browser popup/download, clipboard, or WebGL permissions can affect individual features without stopping the local R analysis.

## File will not load

- Use a wide table: wavelength in column 1, one sample per subsequent column, one header row.
- Confirm the extension, selected Excel sheet, numeric wavelengths, finite numeric sample values, and reasonable file size.
- Remove or resolve duplicate wavelengths, unsorted/descending assumptions, large gaps, and insufficient band coverage as reported by the app.
- For URL input, confirm the resource is public and use HTTPS. Pasting a URL alone does not fetch it; click **Inspect sheets** or **Load data**.
- A private Google/OneDrive link requiring authentication will not load through deauthenticated public access.
- URLs and local files above 2 MiB require the background reader, as do worksheet inspection and feedback submission. If it is unavailable, restore the locked worker dependencies. A local file at or below 2 MiB can load directly through upload or an authorized desktop path; the built-in example also remains available.
- Input/feedback jobs use a worker separate from growth and deconvolution. A queued job has a 180-second startup/wait ceiling; an explicit busy/startup failure asks you to retry. Its execution budget starts when work begins and includes initialization. A timeout does not commit a partial table.

## Output is missing, `NA`, or refused

- Check whether the selected wavelength interval covers the requested band. Baseline lookup is different: it can use the full loaded native source outside the analysis range; inspect the archived requested/effective node or window, eligible-point count, and outside-range-use field.
- Check for large wavelength gaps or too few finite points.
- If coarse binning is refused because support is disconnected, turn resampling off to inspect the native data. Native AUC and similarity remain available; processed arrays and processed AUC are unavailable for that refused request. Reducing the grid step does not repair missing measurements.
- AUC excludes unsupported intervals and does not join across nonfinite curve values. A zero or negative supported integral is retained; `NA` means no supported interval. Check the exported finite processed support when a coarse-grid AUC differs from native AUC.
- SG smoothing requires a sufficiently uniform grid within each supported run. A run with more than 1% relative step variation, or too few points, retains its unsmoothed values and an effective-status explanation. Read that status before reporting that SG was applied.
- A single-reference baseline requires a nearest eligible native measured node; a baseline window requires at least three eligible native points. Baseline-dependent outputs disappear when baseline correction is off or the effective reference requirement is not met.
- Normalization requires a strictly positive requested target and a valid divisor; inspect the applied/refused status rather than inferring success from the selected method.
- A constant/zero spectrum has undefined correlation or spectral angle; `NA` is correct.
- Read the warning before changing thresholds or processing options.

## Similarity analysis is slow or refused

- Pair count grows approximately with `n(n-1)/2`.
- The selected trace cap is enforced, with absolute limits of 1,600 traces and 10 million estimated pair-grid nodes. Consent does not bypass these limits. Reduce the selected samples or measured wavelength workload when an absolute limit is exceeded; changing the plot's display resolution does not reduce native similarity work.
- Above 200 traces or one million estimated pair-grid nodes, the app additionally asks for consent for the current data, provided they still fit the selected and absolute limits. Raise the selected cap first if it is the blocking limit.
- Browser tables and networks can be bounded while the completed pair export remains complete. A ZIP uses the same computation guards; if the calculation is refused, it records a skipped note and still provides unrelated outputs.
- If a rounded display value appears to sit on a tier threshold, use the exported full-precision decision value and threshold. Network edge thickness follows the selected thickness metric; edge color is the combined Pearson-plus-SAM tier, so disagreement is possible by design.
- Insufficient joint support or an undefined primary metric produces no tier. Changing display smoothing or resampling should not redefine the native similarity range.
- Second-derivative correlation needs at least eight jointly supported, varying derivative values from its 15-nm local cubic fit. It is advisory and may be unavailable on coarse or sparse axes even when the primary Pearson/spectral-angle comparison is usable.

## QC or noise result is not evaluated

- QC intentionally lists every loaded column. Analysis-dependent diagnostics for a deselected column are **not evaluated** and are not passes; duplicate-candidate screening remains an all-loaded provenance check.
- Baseline residual is a mean over the exported diagnostic bounds. It does not identify a blanking, scattering, or instrument cause, and its residual-specific class can differ from overall QC status.
- The residual-noise percentage denominator is the maximum absolute native-coordinate, baseline-corrected, pre-smoothing analysis value, not an uploaded/raw peak.
- `PASA-NOISE-QC-3` requires representative native spacing at most 1.5 nm and ≤1% within-segment relative step deviation. Steps >1.5× the preliminary median are segmented as gaps so stencils do not cross them. Coarser or materially non-uniform axes are marked unevaluable because the screen cannot reliably separate sampling curvature from residual noise. Display interpolation cannot make the native axis eligible.
- A component with too few usable residuals stays unavailable. All four components are required for the composite and its relative ranking; partial-support samples retain only applicable absolute classes. The composite chart may be absent even when some individual noise estimates are available, and the ZIP records this without losing the QC tables.
- Thresholds must be finite, nonnegative, and ordered with caution below fail. Zero is allowed; an empty, missing, or reversed threshold is not silently replaced with a default.

## Optional feature is unavailable

- no `plotly`: no interactive 3-D view;
- if either `visNetwork` or `igraph` is unavailable: no interactive similarity network; a static network needs both `ggraph` and `igraph`, otherwise use the pair table;
- no `minpack.lm`: L-BFGS-B deconvolution without fitted standard errors; when `nlsLM` is available, its standard errors remain local/model-conditional and do not provide calibrated coverage or model-selection uncertainty;
- no `signal`: documented smoothing/seeding fallbacks;
- no `writexl`: CSV rather than XLSX export; or
- no `zip`: complete ZIP download unavailable.

The supported launcher requires the full lock. These fallbacks describe feature behavior in a deliberately incomplete developer environment or when a backend becomes unavailable; restore the full lock to enable the reference feature set.

The nested-growth calculation in 1.0.0 uses equal-weight biological-unit slopes;
it does not switch models according to `lme4` availability.

## Deconvolution does not appear or looks stale

- Enable **Advanced Mode**.
- Confirm the colocated module is present and parsed.
- Satisfy baseline/coverage prerequisites.
- After changing a fit setting, run the fit again; do not interpret a previous result under new controls.
- High K, exploratory search, and bootstrap settings can be computationally expensive.
- With the background worker available, **Cancel deconvolution** stops the current fit/bootstrap without applying a partial result. A previous completed fit may remain visible while a replacement is pending; read its recorded settings. Bootstrap is refused with a message if the worker is unavailable; ordinary fitting can use the documented fallback.
- Distinguish the raw minimum of the AIC-like/BIC-like/AICc-like plug-in scores from the guard-adjusted selected K. The selected model is the lowest score among admissible candidates; no admissible candidate can produce an explicit no-selection/fallback state.
- For K bootstrap output, inspect successful and failed selection counts. When every draw fails to select a count, all-requested K frequencies are zero; same-count stability over all attempts is zero if the original fit has a valid selected K. Conditional frequencies/stability and the mode are unavailable. A K absent from the original admissible fits may still be selected in a valid bootstrap replicate and is included in its frequency table.

## Cell Growth is inactive or cannot fit

- Select Cells/Lysate or enable manual growth input.
- Confirm time units, interval, sample mapping, replicate hierarchy, and chronological order.
- Pasting into the manual-data area does not update the grid until **Apply pasted data** is clicked. Check the rectangular table against the configured replicate/timepoint dimensions. Tab- or semicolon-delimited input can use decimal commas; invalid values or excess rows/columns are refused without changing the existing grid.
- For sidebar-derived OD, inspect the observation export: each value is an exact native node, a gap-guarded linear interpolation with bracketing wavelengths, or unavailable with a reason.
- A dataset may genuinely lack a qualifying exponential window; do not force a favorable window.
- Inspect the exported machine-readable growth-window contract. Eligibility includes positive OD, increasing time, positive interval log-slopes, minimum log-rise, interval-rate CV, `R²`, slope significance, and tier-specific curvature/point requirements; ranking is not based on `R²` alone.
- For nested input, inspect the configured, observed, contributing, and excluded biological-unit counts. Technical readings are averaged within each unit/timepoint, then qualifying biological slopes receive equal weight. Fewer than three contributing biological units cannot supply the t-based conditional sensitivity interval; adding technical repeats does not replace biological replication.

## Session import/export concerns

- Use the PASA snapshot export/import procedure; do not edit large embedded tables manually unless necessary.
- A malformed selected section or disagreement between selected Settings and Growth dimensions rejects the import before current data/settings are changed. Choose the intended sections or correct the source snapshot; do not delete blank growth rows to make dimensions fit.
- New snapshots represent missing growth cells as `NA`. Supported legacy tab-only rows and trailing empty fields retain their exact replicate/timepoint positions. An ambiguous legacy matrix is refused rather than inferred from the current UI.
- A notice about a missing or older numerical-methods version does not reject the saved content. PASA recomputes it with current corrected methods, so earlier numerical results can differ.
- If a restore is not confirmed by the browser before its retry limit, the app warns and clears pending restoration work. Inspect the visible grid/selection before analysis or re-import. Closing the session or loading another dataset cancels delayed restoration writes.
- Restored custom band limits survive delayed sidebar redraws. Changing the pigment system or sample type afterward applies its usual preset; Reset Bands remains available. Inactive optional band controls do not cause a restore timeout.
- The baseline reference is bounded by the full loaded wavelength extent. Narrowing the analysis interval preserves a valid reference outside that interval; the exported baseline fields identify the actual native point or window used.
- Snapshots are unencrypted and can contain complete input data, sample names, settings, source filename, or sanitized URL path.
- Review and anonymize every snapshot/ZIP before public sharing.
