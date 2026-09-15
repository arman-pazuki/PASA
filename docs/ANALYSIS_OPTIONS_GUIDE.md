# Major analysis options

For input validation, Noise QC, background analysis and export behavior, see [Controls and result availability](REPAIR_BEHAVIOR.md).

This guide describes PASA 1.0.0 (`PASA-NUMERICS-1.0.0`). Saved data and settings
from earlier supported versions are recalculated with these methods.

## Data loading

| Option | Use | Important caveat |
|---|---|---|
| Local Excel/CSV/TSV/text | Load a wide table with wavelength in column 1 and spectra in later columns. | Review sheet selection, headers, units, missing/non-finite values, ordering, and wavelength duplicates. |
| URL | Load a public HTTP(S) workbook or table, including supported Google Sheets/OneDrive forms. | Clicking Inspect or Load initiates network access; use HTTPS and review URL privacy. |
| Import session | Restore selected settings, spectra, growth data, or measured blank. | Selected sections are validated together before application. Growth dimensions and replicate identities must be unambiguous; conflicting selected settings/data are refused. Snapshot is plain text and can contain the full original table and source identifiers. |
| Demo data | Deterministic built-in synthetic behavior check. | Generated in code; demonstrates software operation, not an anonymized measurement or experimental validity. |

Remote inputs and local files above 2 MiB require the background reader; local files at or below 2 MiB can load directly, including an authorized typed desktop path. Worksheet inspection and feedback submission also use the reader. A dedicated input/feedback worker keeps these jobs separate from growth and deconvolution jobs. Queue waiting is limited to 180 seconds with an explicit busy/startup message. The execution budget starts when the job begins and includes worker initialization. Failed or expired requests do not commit partial input. See [R and package requirements](../reproducibility/R_PACKAGE_REQUIREMENTS.md) for the worker dependencies.

## Shared analysis controls

| Control | Choices/function | Reporting requirement |
|---|---|---|
| Wavelength range | Restricts most downstream analysis to selected bounds. | Report exact bounds and coverage exclusions. Baseline lookup is a deliberate exception: it can use eligible native points from the full loaded source outside the selected analysis range. |
| Organism | Cyanobacteria, Red algae, Green algae, or Plants. | Determines adaptive band defaults; it is not inferred proof of identity. |
| Sample type | Protein sample, isolated phycobiliprotein where applicable, or Cells/Lysate. | Controls available bands/features including growth relevance. |
| Sample selection | Includes/excludes loaded columns from the selected-sample analysis path. | Report selection and preserve source order when it matters. QC still lists all loaded columns; analysis-dependent diagnostics for a deselected column are marked **not evaluated**, not passed. Duplicate-candidate screening is an all-loaded provenance check. |
| Band windows | Adaptive Qy, carotenoid, Soret/Bx, 600–650-nm, optional chlorophyll-b and phycoerythrin windows. | Report any manual changes; avoid tuning to obtain a desired peak. |

## Baseline, conditioning, and scaling

| Option | Behavior | Caveat |
|---|---|---|
| Baseline off | Leaves raw offset/slope present. | Raw similarity and AUC can be dominated by baseline. |
| Single reference wavelength | Subtracts the value at the nearest eligible native measured node in the full loaded source. | The requested wavelength and effective node can differ; report both and whether the effective node lies outside the selected analysis range. Requires eligible coverage and a scientifically quiet reference. |
| Robust reference-window median | Subtracts the median of eligible native measured values in the declared window, using the full loaded source. | Requires at least three eligible points. Report requested/effective bounds, point count, statistic, and any use of outside-analysis-range points. It does not necessarily remove slope or scattering. |
| Resampling off | Preserves the native grid. | Pairwise operations still require compatible/common support. |
| Finer fixed grid | Uses linear interpolation within eligible covered support. | Adds interpolated points, not new information; unsupported spans remain missing. |
| Coarser fixed grid | Uses bin averaging on connected native support. | Disconnected support is refused for binning: native curves, native AUC, and native similarity remain available, while processed outputs are unavailable. Arbitrary band AUC can change at bin boundaries, and narrow features can shift or merge. |
| No smoothing | Preserves recorded local variation. | Peak detection may be sensitive to noise/ripple. |
| Savitzky–Golay | Polynomial smoothing separately within supported runs when the backend and grid permit it. | Runs with more than 1% relative grid-step variation are not SG-smoothed. Short or refused runs retain their unsmoothed values with an exported status. Report effective application, window/order, and edge behavior. |
| Moving average | Smoothing within supported runs without crossing excluded gaps. | Can broaden or shift local features; unsupported nodes remain missing. |
| Dilution scaling | Global or per-sample factors. | Produces an undiluted-equivalent descriptive OD/AUC scale only under linear detector response and matched path length, blank/reference, units, sample matrix, and preprocessing; it is not an absolute concentration estimate. |
| Normalization | Maximum, value at wavelength, total area, band peak, or band AUC, with a strictly positive requested target. | Changes the scientific question; some choices require baseline correction. Report whether normalization was effectively applied, its divisor and target, or the refusal/reason. A native-coordinate deconvolution fit must use the effective normalization state rather than the requested method alone. |

## Spectra

- Overlay or facet view.
- Optional interactive 3-D waterfall.
- Palette, line, axes, grid, and band styling.
- Wavelength probe, peak markers, and peak table.
- PDF/image and processed-data export.

Visual styling should not change calculations, but screenshots must state the processing configuration behind the displayed curves.

## Metrics

Metrics can include processed AUC; raw or dilution-scaled, undiluted-equivalent AUC; peak wavelength/value; OD summaries; band ratios; coverage; and provenance. Raw and baseline-corrected AUC are evaluated on native wavelength coordinates. Smoothed and normalized AUC are processed-grid quantities and can depend on resolution. Five display layouts and XLSX/PDF/clipboard exports are available. Always report the basis—raw, corrected, smoothed, or normalized—and the coordinate grid rather than citing an unlabeled number.

AUC integrates finite piecewise-linear curve segments only where they intersect
the requested bounds and eligible native support. Missing curve values break
support. A supported signed or zero integral is retained; no supported interval
produces `NA`. A processed grid can cover a shorter finite span than the native
curve; the `processed_support_nm` and `band_processed_support_nm` exports record
that distinction. Native endpoint values are not silently substituted into a
smoothed or resampled curve.

## Band AUC

Choose raw, baseline-corrected, smoothed, or normalized basis. Bar and radar views, common/per-panel axes, overlays, and separate exports are available. Raw/baseline-corrected AUC use native coordinates; smoothed/normalized AUC use the processed grid and are resolution-dependent. Coarse binning targets full-range trapezoidal-area preservation under eligible coverage/range conditions but does not guarantee invariance of an arbitrary band whose boundary cuts a bin. Gaps wider than the adaptive threshold `min(max(3 nm, 1.25 × native step), 25 nm)` are excluded. AUC is meaningful only for adequately sampled, declared bounds.

## Data Quality, including the similarity subview

- Non-blocking residual-noise qualification (`PASA-NOISE-QC-3`) on eligible near-uniform native wavelength axes with representative spacing at most 1.5 nm. Coarser axes are not classified because curvature and sampling step can confound the residual screen. Noise percentage uses the maximum absolute native-coordinate, baseline-corrected, pre-smoothing analysis value as its denominator. Within each segment, relative step deviation must be ≤1%; steps >1.5× the preliminary median are segmented as gaps so stencils do not cross them. Denominator and axis diagnostics are exported.
- Baseline-residual local/window-mean, high-signal/saturation-risk, and high-correlation duplicate-candidate heuristic checks.
- Editable operational thresholds.
- Wavelength/trapezoid-weighted Pearson `r` on the native-coordinate, baseline-corrected, pre-normalization analysis curve; weighted Pearson second derivative; and weighted spectral angle.
- Bubble, force-directed, or circular network layouts.
- Edge filters and a computation-budget guard.

Display resampling and smoothing do not define the native similarity range.
Pairwise node and interval coverage use the same capped gap policy; pairs with
insufficient retained support or undefined primary metrics have no similarity
tier rather than a favorable placeholder result.

Second-derivative correlation is advisory. PASA estimates derivatives with a local cubic fit using tri-cube weights over a 15-nm window; at least eight jointly supported, varying derivative values are required. An unavailable derivative diagnostic does not supply a favorable placeholder or determine the Pearson-plus-spectral-angle tier.

Noise components with insufficient residual support remain unavailable. The composite requires all four components; partial-support samples keep their applicable absolute classes and do not enter adaptive ranking or the composite chart. Complete samples can receive a FAIL class through either absolute rules or the disclosed dataset-relative composite rule. The cutoffs remain operational defaults, not calibrated acceptance limits.

Similarity is a selectable subview within Data Quality, not a standalone navigation tab. QC and similarity thresholds are operational warnings or labels selected during development; they are not empirically calibrated or independently validated universal biological cutoffs. QC lists all loaded columns, but a deselected column's analysis-dependent fields remain **not evaluated** and are not counted as passes; the duplicate-candidate screen intentionally compares all loaded columns. The reported baseline residual is a mean over archived diagnostic bounds, not an exact-point value or a causal diagnosis. Residual-plot color represents the residual-specific tolerance class, which can differ from overall QC status. The high-signal/saturation-risk flag is a heuristic prompt, not a saturation diagnosis. A duplicate flag means only a high-correlation candidate requiring provenance review, not proof that two samples are identical. PASA's Pearson and SAM values use wavelength/trapezoid weights; because endpoints retain half the interior weight even on a uniform finite grid, they must not be described as ordinary unweighted metrics. Similarity tier decisions use exported full-precision values and thresholds; rounded values are presentation copies. Network edge thickness follows the selected thickness metric, whereas edge color represents the combined Pearson-plus-SAM tier, so they need not agree.

Similarity must fit the selected trace cap and the absolute ceilings of 1,600 traces and 10 million estimated pair-grid nodes. Automatic computation is further limited to 200 traces and one million estimated pair-grid nodes; above either automatic threshold, consent is required for the current data. Consent cannot bypass the selected cap or either absolute ceiling. The work estimate sums upper bounds on the wavelength nodes in each pair's joint grid; it is not a time estimate. Browser rendering is separately bounded. Full pair rows are exported only when computation passes these same guards; a skipped ZIP calculation includes an explicit note.

## Sample Color

The app shows an illustrative D65/CIE sRGB mapping. The step `T = 10^(-value)` represents physical transmittance only when `value` is verified decadic absorbance on an applicable optical basis. Normalized, non-OD, or arbitrary inputs remain illustrative, and negative values are clamped only for rendering. For low-signal input, PASA can attenuate the requested numerical target; displays and exports distinguish requested target, effective target, confidence factor, and low-signal state. Conversion is evaluated over 380–780 nm; missing end spans are flat-extrapolated from the nearest available endpoint and their lengths are reported. PASA uses the supplied absorbance values directly, has no path-length input, and does not infer or rescale them to a 1-cm cuvette. It does not predict a physical cuvette appearance or provide calibrated colorimetry or pigment identification.

Color targets must be finite and strictly positive. Absolute absorbance-unit low-signal thresholds are not applied to normalized relative values; their rendering confidence still includes the scale-independent signal-to-noise check. The grid shows at most 30 cuvettes per page, while supported full-table and image exports retain the selected samples.

## Cell Growth

- Sidebar-fed or manual OD input.
- Tracking wavelength, time unit, and interval.
- Biological and technical replicate structure.
- Automatic exponential-window selection.
- Apparent OD-derived rate (`μ`), OD doubling time, linear/log plots, phase detection, optional reselection bootstrap, diagnostics, and exports.

Cell Growth is inactive until Cells/Lysate is selected or manual input is enabled. Sidebar-derived OD uses the uploaded as-measured basis: an exact native node is used when present, otherwise gap-guarded linear interpolation may be used. The observation export records extraction method, bracketing wavelengths, and refusal reason for every sample/time point. Candidate windows require positive OD, strictly increasing time, positive interval log-slopes, a minimum log-rise, the configured interval-rate CV bound when enough intervals exist, a positive log-linear slope, minimum `R²`, and the configured slope-significance rule. High-consistency candidates also meet the minimum-point and curvature rules; a lower-tier fallback has its own minimum point count. Ranking proceeds by tier, point count, span, `R²`, and lower interval-rate CV. The exact constants and non-finite-p-value policies are exported as the machine-readable growth-window contract. Reported rate and OD doubling time are apparent OD-derived log-linear summaries; interpreting them as biological specific growth requires an independently justified OD–biomass relationship. Replicate hierarchy and time ordering must be declared correctly. Reported intervals are conditional post-selection sensitivity summaries: the Wilson interval is an algorithmic qualifying-window reference interval, and the optional reselection-bootstrap percentile interval is model-conditional. Neither is a calibrated biological confidence interval.

For nested technical replicates, PASA first averages technical OD readings
within each biological unit and timepoint. Each qualifying biological unit then
contributes one log-linear slope in the common selected interval; the reported
rate is the equal-weight mean of those slopes. A t-based conditional sensitivity
interval requires at least three contributing biological units. Configured,
observed, contributing, and excluded counts are disclosed. Installing or removing
`lme4` does not change this calculation. The interval omits window-selection and
within-trajectory uncertainty and is not a calibrated biological confidence
interval.

Manual-growth snapshots preserve every biological/technical/timepoint position,
including completely missing series. New exports write missing cells as `NA`;
supported older empty-field snapshots are read without dropping their rows.

Pasted manual growth data are a draft until **Apply pasted data** is clicked. Opening the paste area does not replace the edited grid. A rectangular table must fit the configured replicate/timepoint dimensions; tab- or semicolon-separated values can use decimal commas. Invalid cells or excess dimensions are refused before the grid changes.

## Advanced deconvolution

Advanced Mode dynamically inserts the Deconvolution tab; the tab is not always visible.

Run fitting explicitly after choosing its settings. With its background worker available, fitting and the optional bootstrap leave the interface usable; **Cancel deconvolution** stops pending work without applying a partial result. A previous completed fit can remain visible while a replacement runs, so use its recorded settings when interpreting it. Bootstrap requires the worker; ordinary fitting has the documented fallback if the worker is unavailable.

- One sample at a time.
- Pure-pigment, purified-complex, or cell/thylakoid presets.
- K range and Search-depth limit: Tested range (K ≤ 4, default), or Advanced opt-in (K ≤ 20).
- AIC-like, BIC-like, or AICc-like post-fit plug-in residual-AR(1) penalized parsimony scores among admissible candidates; these are not classical likelihood-based information criteria.
- Optional moving-block residual K-stability bootstrap, which is conditional on processing, model, bounds, starts, optimizer, residual model, search range, and resampling scheme rather than a confidence statement about species count.
- One Gaussian–Lorentzian mixing parameter shared across all components, four deterministic starts, and operational center, width, amplitude, and seeding bounds.
- Optional empirical inverse-power baseline term or subtraction of a user-supplied measured blank. These are distinct operations; neither is a validated physical scattering correction.
- Fit/residual plots, K comparison, component tables, interpretation notes, and exports.

Without `minpack.lm`, the documented L-BFGS-B fallback lacks fitted standard errors; the standard-error portion of the split guard is then unavailable, while fixed separation and amplitude-collapse guards remain. When `nlsLM` supplies standard errors, they are local and model-conditional; the residual-autocorrelation scalar is heuristic, and neither diagnostic supplies calibrated coverage or model-selection uncertainty. The app distinguishes the raw minimum of the selected score from the reportable selection: selected K is the lowest selected-criterion score among candidates that pass the admissibility guard, with an explicit no-selection/fallback state when none qualify. Agreement statements concern guard-adjusted selections; equality of raw minima alone is not evidence of criterion robustness. A fitted decomposition can be non-identifiable; shared shape can bias partitioning when true bands differ in shape, and four starts do not remove local-optimum risk. Components and K-stability describe conditional mathematical model behavior, not recovered pigments or molecular species.

Bootstrap K frequencies are counted across the full allowed K range, including
a valid bootstrap selection whose K failed in the original fit. Failed or
invalid selections are counted separately. If no replicate supplies a valid
selection, all-requested K frequencies are zero. Same-count stability over all
attempts is zero when the original fit has a valid selected K; conditional
frequencies/stability and the mode are unavailable. The bootstrap
preserves the caller's random-number state, including error paths.

Deconvolution also requires a complete uniform wavelength lattice. PASA refuses materially irregular or gapped axes; when departures can be attributed to stored coordinate rounding, it may reconstruct the coordinate lattice, perform an observed-coordinate sensitivity re-fit, and disclose the reconstruction. Fit inputs are processed analysis-curve values at native measured wavelength coordinates after selected dilution scaling, baseline, and any normalization that was effectively applied; a normalization request requires a positive target and valid divisor, and its applied/refused status is archived. When normalized, the fit values are relative rather than native measured absorbance. Resampling and display smoothing are not fit inputs. The optional inverse-power background is estimated from 730–800 nm; absorption or structured scattering in that tail can invalidate a physical interpretation even when numerical guards pass.

## Themes and accessibility

The navbar offers Auto, Light, Dark, Midnight Teal, High-Contrast, Sepia/Warm, and dyslexia-friendly typography. Theme choice is stored in browser `sessionStorage`; it does not alter spectra or calculations.
