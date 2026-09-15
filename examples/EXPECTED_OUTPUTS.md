# Expected outputs

These expectations describe PASA 1.0.0 (`PASA-NUMERICS-1.0.0`) using the synthetic workbook in this folder. Exact numerical values depend on the selected settings. The notes below describe what users should see and what the app should refuse or mark undefined.

## After loading

- A load/detection message identifying the selected source and sheet.
- Wavelength range 350–750 nm.
- Native spacing 1 nm and 401 data rows.
- Five sample columns in source order.
- An input preview without confidential identifiers.

## Summary and spectra

- A configuration/coverage summary on screen and in exportable report/text forms.
- Two-dimensional spectrum overlays or facets for selected samples.
- A wavelength probe and band-peak information where the selected rules identify peaks.
- Optional interactive three-dimensional waterfall when `plotly` and browser WebGL are available.
- Processed-spectrum export plus image/PDF outputs where offered.

For the unprocessed primary synthetic run, the single curve has a constructed maximum of 0.8 at 450 nm, and the dual curve has constructed components centered at 450 and 675 nm.

## Metrics and Band AUC

- Processed and raw or dilution-scaled AUC and peak fields where coverage is adequate. Raw and baseline-corrected AUC use native wavelength coordinates; smoothed and normalized AUC use the processed grid and are resolution-dependent. Coarse binning targets full-range trapezoidal-area preservation only when coverage/range conditions permit and does not guarantee arbitrary-band invariance. Dilution-scaled magnitude is an undiluted-equivalent descriptive scale only under linear response and matched path length, blank/reference, units, sample matrix, and preprocessing; it is not concentration.
- OD, ratios, coverage, and provenance fields appropriate to the selected configuration.
- Band-AUC bar or radar views and their exports.
- `NA`, warning, or refusal when the selected wavelength interval does not adequately cover a requested band.

## Data Quality, including the similarity subview

- Residual-noise qualification (`PASA-NOISE-QC-3`) and per-sample QC fields. The noise percentage denominator is the maximum absolute native-coordinate, baseline-corrected, pre-smoothing analysis value. The second-difference estimator requires representative native spacing at most 1.5 nm and ≤1% within-segment relative step deviation; steps >1.5× the preliminary median are segmented as gaps. Coarser or materially non-uniform axes are marked unevaluable because sampling curvature can confound the screen. Missing components remain unavailable; a composite requires all four components, and partial-support samples retain applicable absolute classes without relative ranking.
- Baseline-residual local/window-mean, high-signal/saturation-risk, and high-correlation duplicate-candidate checks where applicable. QC lists all loaded columns; deselected samples are **not evaluated**, not passed. Residual bounds, statistic, point count, class, and effective anchor are exported. The residual is non-causal, and plot color represents its residual-specific class. A high-signal flag is not a saturation diagnosis; a duplicate candidate is not proof of identity.
- Pairwise PASA wavelength/trapezoid-weighted Pearson `r` on the native-coordinate, baseline-corrected, pre-normalization analysis curve, weighted Pearson second derivative, and weighted spectral-angle results for valid non-constant pairs. Endpoint half-weighting means these are not ordinary unweighted metrics even on a uniform finite grid. Full-precision decision values and thresholds are exported; displayed rounding does not define tiers. Network thickness can encode a selected metric while color encodes the combined Pearson-plus-SAM tier.
- Correlation or SAM involving `Blank` can be undefined because its variance/norm is zero; this must not be converted to a favorable zero-difference verdict.
- Complete pairwise results in export when the selected trace cap and absolute limits of 1,600 traces and 10 million estimated pair-grid nodes permit. Above 200 traces or one million estimated pair-grid nodes, consent for the current data is additionally required; it cannot override the selected or absolute limits. A refused ZIP calculation includes an explicit skipped-note file; browser table/network display limits remain separate.
- The derivative correlation is advisory and requires at least eight jointly supported, varying values from a 15-nm tri-cube-weighted local cubic derivative fit. An unavailable derivative result does not replace an undefined value with a favorable match.

## Sample Color

- Illustrative D65/CIE sRGB mapping; PASA uses the supplied absorbance values directly and has no path-length input, 1-cm rescaling, or physical-cuvette prediction. Rendering metadata identify the requested and effective targets, low-signal confidence/attenuation, available coverage, and any flat-extrapolated portions of the 380–780-nm conversion span.
- `T = 10^(-value)` is physical transmittance only for verified decadic absorbance on an applicable optical basis. Normalized, non-OD, or arbitrary inputs remain illustrative; negative values are clamped only for rendering. The output is not a colorimetric assay or proof of pigment identity.
- At most 30 cuvettes per display page, with sample names in the scene and hexadecimal codes in the folded Color details table. Dark/light scene backgrounds change the illustration, not its calculated color values.

## Cell Growth

Cell Growth is relevant only when **Cells/Lysate** or manual growth input is active. Sidebar-derived OD uses an exact native node when present; otherwise gap-guarded linear interpolation may be used on the uploaded as-measured basis. The observation export records exact/interpolated/unavailable status, bracketing wavelengths, and reason. With valid time-series inputs, outputs can include apparent OD-derived log-linear rate and OD doubling time, fit diagnostics, candidate/window-contract tables, phase tables, plots, and CSV/PDF/PNG exports. Window eligibility and rank include positivity, time order, interval-slope/CV, minimum-rise, `R²`, significance, curvature/tier, point-count, span, and lower-CV rules; exact constants and non-finite-p-value policies are exported. Biological specific-growth interpretation requires an independently justified OD–biomass relationship. Reported intervals are conditional post-selection sensitivity summaries: the Wilson interval is an algorithmic qualifying-window reference interval, and any reselection-bootstrap percentile interval is model-conditional. Neither is a calibrated biological confidence interval. The static synthetic spectra workbook is not a growth dataset.

Manual paste leaves the current growth grid unchanged until **Apply pasted data** is clicked. Invalid cells or dimensions produce an explanation without partially replacing the grid.

## Advanced deconvolution

When Advanced Mode is enabled, the tab is inserted dynamically. When its prerequisites are met, outputs include:

- the raw selected-score minimum, candidate admissibility, and guard-adjusted selected K (or explicit no-selection/fallback state) for post-fit plug-in residual-AR(1) penalized AIC-like, BIC-like, or AICc-like parsimony scores rather than classical likelihood-based information criteria;
- fit R², RMSE, and a heuristic residual-autocorrelation scalar;
- processed analysis-curve-at-native-coordinate/fit/component and residual plots;
- K-comparison and fitted-component tables;
- optimizer/fallback disclosure, warnings, and interpretation notes; local/model-conditional `nlsLM` standard errors where available, without calibrated coverage or model-selection uncertainty; and
- PDF/clipboard exports.

The fit uses one mixing parameter shared across components and four deterministic starts; shared shape can bias overlapping-band partitioning, and the starts do not remove local-optimum risk. An optimizer result is not a unique biological composition unless supported by independent standards and experimental design. K-stability is a moving-block residual-bootstrap output conditional on the specified processing, model, bounds, starts, residual model, search range, and resampling scheme—not confidence in species identity or true component count.

With the worker available, **Cancel deconvolution** stops the pending fit/bootstrap without applying a partial result. A previous completed fit may remain visible while replacement work runs. A missing worker makes bootstrap unavailable with an explanation; ordinary fitting has the documented fallback.

The synthetic workbook demonstrates software behavior; it is not an independent biological recovery study or a performance benchmark for experimental spectra. No unbundled study percentage is a pass target for this example. See [Method and interpretation limits](../docs/RECOVERY_EVIDENCE_SCOPE.md) for the boundary between included checks and separately distributed exploratory evidence.

## Session and complete export

- A reloadable plain-text `PASA_state.txt` snapshot.
- Pre- and post-normalization data where selected.
- Aggregate ZIP output when the `zip` backend is available.

Snapshots and ZIP files can contain the full input table and sample names. They are unencrypted and should be reviewed before sharing.
