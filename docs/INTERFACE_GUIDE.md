# Using the PASA interface

In PASA 1.0.0, **Open PASA** enters **Input data**. Upload a spectrum table, import a saved session, or load the built-in example here. The input fields stay in place after loading; the adjacent preview shows the committed table. For remote input, pasting a URL is a draft; **Inspect sheets** or **Load data** starts the requested access.

The analysis navigation is **Input data → Analysis settings → Summary → Spectra → Metrics → Band AUC → Data Quality → Deconvolution (Advanced Mode only) → Sample Color → Cell Growth**. About, Help, FAQ, References, and Feedback follow.

## Analysis settings

The settings occupy their own tab. The **Analysis settings** button at the top right opens the same page from Input data and the analysis tabs. It is hidden on Welcome, About, Help, FAQ, References, and Feedback. There is only one instance of each control, so switching tabs does not reset settings or create competing copies.

The page groups controls into range and sample type, samples, band windows, baseline, signal conditioning, scaling and normalization, and export options. Expand a group to edit it, or use Expand all / Collapse all. Before a dataset is loaded, the page links back to Input data.

The strip above analysis pages shows sample count, wavelength range, baseline state, and a readable normalization description. For example, **Band peak: Qy, target value: 1** identifies both the selected band and the requested target. Processing problems and sample failures retain their existing notifications and tables.

## Spectra and sample colors

Metrics tables have synchronized horizontal scrollbars above and below each table. Translucent left/right arrows pan the view; the arrow at an exhausted edge is disabled. With the scrollbar focused, use Left/Right, Home, or End. Separate-band layouts give each table its own controls. Scrolling does not change copied or exported data.

**Customize spectra plot** groups controls into **Curve style**, **Titles and axes**, **Wavelength probe**, and **Band peaks and labels**. The 3D view has a separate **3D rendering** group. Open a section to inspect its fields; use **Show wavelength probe** or **Show band peaks** to enable the feature. Folding a section leaves its feature and values unchanged, and enabled result tables remain below the plot. Field widths align and adapt to the available screen width. Appearance controls do not change the definition of the numerical methods.

Sample Color uses a static textured lab bench, a lamp on the left, and transparent cuvettes. **Scene background** offers **Dark** (the default blue-gray laboratory) and **Light** (white-painted textured bench and walls), independently of the app theme. The choice applies to single/all-sample views and image exports and is retained in session settings. It does not change the calculated sample colors. There is no drawn light beam, filter, detector, or spectrum screen. Sample names remain in the image; hexadecimal codes are in the **Color details** table below it. That table starts folded and opens with its arrow. The illustration remains an illustrative D65/CIE sRGB mapping, not a calibrated physical cuvette prediction.

The cuvette grid shows at most 30 selected samples per page. Change the page to see the next group; this display limit does not remove samples from the full color details or supported exports.

## Data Quality

The **Compare** selector switches between Per-sample QC and Sample similarity; the report download and optional detailed tables are grouped beside it. Per-sample thresholds are under **QC thresholds**.

Sample similarity has four foldable sections: **Network appearance**, **Labels and visible connections**, **Calculation limit**, and **How similarity is calculated**. The first contains layout and relationship metric. The second contains sample/edge labels and edge-strength filtering. The calculation-limit slider displays trace counts rather than internal position numbers. Current budget and display-coverage messages remain visible. The method section retains the grid, weighting, tier and interpretation details. Opening or folding these sections changes no calculation setting.

The selected cap is enforced, with absolute limits of 1,600 traces and 10 million estimated pair-grid nodes. Above 200 traces or one million estimated pair-grid nodes, the current data also require consent; this cannot bypass a selected or absolute limit. The status message explains whether to reduce the data, raise the selected cap, or authorize a calculation that remains within the limits.

Noise QC (`PASA-NOISE-QC-3`) requires a near-uniform native grid with representative spacing at most 1.5 nm and sufficient residual support. Missing components remain not evaluated. A composite needs all four components, so its chart can be unavailable even when some individual estimates are present; partial-support samples keep applicable absolute classes. The exported reasons explain each omission.

## Cell Growth and deconvolution

In manual Cell Growth, paste a rectangular table and click **Apply pasted data** to replace the editable grid. Opening the paste area or changing its text leaves existing cells intact. Tab- and semicolon-delimited tables can use decimal commas; invalid cells or excess dimensions are refused before replacement.

Enable **Advanced Mode** to reveal Deconvolution. Run a fit after choosing its settings. With the background worker available, fitting and bootstrap leave the interface usable, and **Cancel deconvolution** stops the pending work without applying a partial result. A previous completed fit may remain visible during replacement; interpret it using its recorded settings. Bootstrap requires the worker, while ordinary fitting can use the documented fallback when it is unavailable.

## Guided tours

Choose **Guided tour** in the header or **Start guided tour** on Welcome. The quick tour introduces the workflow and the major analysis/support pages, including Advanced Mode. The detailed tour covers individual inputs, outputs, conditional options, explanations, and examples, with particular attention to Analysis settings.

The settings page's **Detailed guided tour** button starts directly at that chapter.

Use chapter navigation to reach a topic, move back, continue, pause, or resume. The upper-right **×** closes the tour immediately. **Go to control** brings the described control into view; it does not apply a setting or run the analysis. Some controls require a dataset, a particular mode, or a calculation. The tour explains what enables them and lets you skip/revisit unavailable steps. Loading a demo, changing an analysis value, running a fit, downloading a file, and sending feedback require the user's own actions.

Tour progress is separate from analysis snapshots. Hosted sessions store it in the browser; explicitly launched desktop sessions store it in the operating-system user's PASA preferences directory. Missing or unavailable storage does not prevent using the app.

## About, Help, FAQ, and feedback

About and Help have expandable sections and **Expand all / Collapse all**, like FAQ. The detailed tour points out both FAQ sections and selected questions to help users find relevant explanations.

**Feedback** follows References and is also available beneath LinkedIn in **Contacts**. Choose a reaction, optionally write a suggestion or problem report, acknowledge the displayed notice, and click **Send feedback** to use the configured form. The bundled destination is the PASA Google Form. No name, email address, or sign-in is requested; the provider can still receive normal request metadata, so avoid identifying details in comments if you want an anonymous message. Sending happens in the background and the app displays its outcome. Failed or unconfirmed sends preserve the draft. **Save feedback (.txt)** works offline and keeps a copy for later; **Compose email** opens an optional draft in the user's email app and uses that account's address if sent. Spectra are not attached automatically. See [Privacy and network behavior](../privacy_network/README.md).

Operators can disable direct sending with `PASA_FEEDBACK_ENABLED=0`. A custom form requires an HTTPS `PASA_FEEDBACK_FORM_URL`, distinct `PASA_FEEDBACK_RATING_FIELD`, `PASA_FEEDBACK_COMMENT_FIELD`, `PASA_FEEDBACK_TIMESTAMP_FIELD`, and `PASA_FEEDBACK_VERSION_FIELD` mappings, plus `PASA_FEEDBACK_CONTROLLER_NAME` and an HTTPS `PASA_FEEDBACK_PRIVACY_URL`. Incomplete custom configuration disables sending rather than falling back to the bundled form. The notice identifies the configured controller and privacy information before submission.

## Sessions, exports, and themes

Save session respects the snapshot-content choices in Analysis settings (also mirrored in Summary). Export provides Download everything (ZIP). Per-tab downloads remain with their plots and tables. Current numerical-method identifiers are recorded; imported earlier sessions are recalculated with `PASA-NUMERICS-1.0.0`. Snapshots and ZIPs can contain the complete input and sample identifiers; review them before sharing.

Auto, Light, Dark, Midnight Teal, High-Contrast, Sepia / Warm, and the dyslexia-friendly appearance option remain available through Theme. Only Welcome animates; the animation pauses when hidden and respects reduced motion.

## Table and export behavior

Metrics displays 20 samples per page, retaining every band for those samples. Previous and Next move between pages. Copy the entire table builds the complete dataset only on request; if browser clipboard permission is unavailable, a text dialog supports manual copy. XLSX/CSV and clipboard outputs retain all columns. The PDF is a compact core-metrics report and identifies the complete data export as the source of additional provenance and ratios.

The top table control has a visible thumb even on systems that hide native scrollbars. The bottom scrollbar and translucent arrows remain available.

Complete ZIP exports use the same sample-similarity computation limits as the interactive view. A skipped calculation or unavailable noise chart has an explicit note; it does not discard unrelated outputs. Failed session saves display an error and fail the download rather than providing an unrestorable state file under a normal filename.

Software, documentation, artwork, and adapted color-reference data have distinct license terms; see [Component licenses](../LICENSE.md) and [Third-party notices](../THIRD_PARTY_NOTICES.md).
