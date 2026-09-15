# Controls and result availability

PASA 1.0.0 (`PASA-NUMERICS-1.0.0`) checks required fields before processing samples. If a field is empty or invalid, correct the message shown in the app. When only some samples fail, the app keeps usable samples and reports each failure. Complete ZIP includes the failure table.

With baseline correction off, a residual QC chart that depends on the correction is not applicable. A complete download still includes the available outputs and records the omitted chart and reason. An unavailable noise composite chart likewise does not suppress the QC tables or unrelated exports.

Noise QC uses `PASA-NOISE-QC-3`. Representative native spacing must be at most 1.5 nm, with no more than 1% relative spacing deviation within a supported segment. Steps above 1.5 times the preliminary median separate segments. Coarser or materially non-uniform axes are not classified: the residual screen cannot separate sampling curvature from noise reliably. Interpolating the display does not change native-axis eligibility.

Noise QC needs 20 usable spacing-two residuals for a global or tail estimate, eight for a local interval, and 20 for the neighboring-point check. Unsupported components are marked not evaluated. The adjacent roughness measure is `100 × 1.4826 × median(abs((2*y[i] − y[i−1] − y[i+1])/sqrt(6))) / denominator`; its caution/fail cutoffs are 0.5%/1.5%. The denominator is the maximum absolute native-coordinate, baseline-corrected, pre-smoothing analysis value. Roughness can respond to smooth curvature as well as alternating noise and is not an instrument-fault diagnosis.

The noise composite requires all four components. Samples with partial support retain their applicable absolute classes and do not enter the composite chart or relative ranking. Complete samples can receive FAIL through absolute rules or the disclosed relative composite rule. Exact score ties receive the same adaptive rank. Thresholds are operational, not calibrated biological acceptance limits; editable caution/fail pairs must be finite and satisfy `0 ≤ caution < fail`.

Similarity computation respects the selected trace cap and absolute ceilings of 1,600 traces and 10 million estimated pair-grid nodes. Above 200 traces or one million estimated pair-grid nodes, consent is also needed for the current data. Consent cannot override the selected cap or the absolute ceilings. ZIP exports use these same guards and include an explicit note when pairwise computation is skipped.

A selected measured blank must contain usable numeric wavelength and signal columns with sufficient overlap. Replace or remove an invalid blank before fitting. Changing to invalid input withholds cached fit outputs.

Deconvolution and its bootstrap use a background worker when available. **Cancel deconvolution** stops pending work without applying a partial result; a previous completed fit may remain visible while its replacement runs. Bootstrap requires the worker and is refused when unavailable. Ordinary fitting can use the documented fallback. Fit components and bootstrap count stability are conditional mathematical descriptions, not pigment identification or calibrated biological confidence.

Red-edge clipping reports what actually happened. A limit above the data gives no change. A limit that leaves too few usable points is refused. The app does not silently restore the discarded range.

Bootstrap results retain every requested draw. For example, one matching selection and three draws with no admissible component count give 25% over all four attempts and 100% among the one successful selection. Neither number substitutes for the other. The conditional percentage is undefined if no draw selects a count; same-count stability is undefined if the original spectrum has no selected count.

Manual growth paste is applied only through **Apply pasted data**. Opening the paste area or editing its text does not overwrite the current grid. Invalid cells or excess dimensions are refused before any replacement. Tab- or semicolon-delimited tables support decimal commas.

The default browser limit is 32 MiB. Deployers can set `PASA_UPLOAD_LIMIT_MIB` or a lower `shiny.maxRequestSize` before startup. The input panel shows the effective app limit; a hosting proxy may have a smaller limit.

Remote sources and local files above 2 MiB require the background reader, as do worksheet inspection and feedback submission. Local files at or below 2 MiB can load directly, including an authorized desktop path. Input and feedback jobs use a dedicated worker separate from growth/deconvolution work. Queue waiting has a 180-second ceiling with an explicit busy/startup failure. Each operation's elapsed execution budget begins when the job starts and includes its initialization; it is not reset after initialization. Results and errors return to the requesting session, and session closure suppresses pending callbacks and requests cancellation. A failed stop retains ownership until the durable reaper confirms termination. Reader allocations are bounded; a full reader queue reports busy and asks the user to retry. Failed, expired, or cancelled loads do not commit partial input. Restore the locked dependencies if the worker is unavailable; a small local upload or the built-in example remains usable.
