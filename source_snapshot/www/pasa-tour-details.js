(function () {
  'use strict';
  // Content only: this catalog never changes inputs, starts jobs, or sends data.
  // The tour engine handles navigation, disclosures, positioning, and skipping.
  const settings = [];
  const deconvolution = [];
  const growth = [];
  const add = (list, chapter, nav, target, title, copy, options = {}) => list.push({
    id: chapter.toLowerCase().replace(/[^a-z0-9]+/g, '-') + '-' + title.toLowerCase().replace(/[^a-z0-9]+/g, '-'),
    chapter, nav, target, title, copy,
    requiresData: chapter !== 'Cell growth',
    ...options
  });
  const setting = (target, title, copy, options) => add(settings, 'Analysis settings', 'Analysis settings', target, title, copy, options);
  const fit = (target, title, copy, options) => add(deconvolution, 'Deconvolution', 'Deconvolution', target, title, copy, options);
  const grow = (target, title, copy, options) => add(growth, 'Cell growth', 'Cell Growth', target, title, copy, options);

  setting('#pasa-analysis-settings', 'Your analysis control center',
    'These seven groups hold the settings shared by the plots, metrics and exports. They stay in place when you change tabs. Expand all reveals the complete workspace; Collapse all makes it easier to focus on one group. The header shortcut returns here from any working tab.');
  setting('#analysis_nm', 'Choose the wavelength range',
    'This range limits the processed curves, band measurements, normalization and exports. For example, 400–750 nm focuses on the visible pigment region if your file covers it. Baseline lookup is a documented exception: its reference can use eligible measured points outside this analysis range.');
  setting('#organism', 'Choose an organism preset',
    'The organism selector supplies starting band windows and labels. For example, Cyanobacteria emphasizes the Qy and possible phycobiliprotein region; Green algae adds a separate chlorophyll b window. Changing a preset overwrites the band sliders, so use it deliberately. The preset does not identify pigments in an unknown sample.');
  setting('#sample_type', 'Declare what was measured',
    'Protein sample covers purified complexes or thylakoid membranes. Cells / Lysate indicates a whole-cell preparation and can enable growth analysis. For cyanobacteria or red algae, Isolated phycobiliprotein is a separate choice. This declaration changes the meaning of the 600–650 nm band; PASA cannot infer preparation from the curve.',
    { fallback: '#organism', unavailable: 'Sample type is hidden for Plants. Choose Cyanobacteria, Red algae or Green algae to inspect the available preparation choices.' });
  setting('#samples', 'Select the samples to analyze',
    'Each checkbox represents one input column. Check two samples to compare their curves, or one to inspect it closely. Selected samples feed analysis-dependent results; per-sample Data Quality still inventories every uploaded column and labels deselected analysis diagnostics as not evaluated.',
    { fallback: '#samples_ui', unavailable: 'Load a table to create the sample checklist.' });
  setting('#select_all, #clear_all', 'Select all or clear the checklist',
    'Select all checks every sample; Clear unchecks them. For example, clear a long checklist and then select only your control and treatment columns. With no samples selected, analysis outputs ask you to choose at least one. These buttons change selection, not the uploaded file.');
  setting('#pasa-settings-bands', 'Understand the band windows',
    'Each window defines the wavelengths used for its reported peak and area. The windows can overlap, so adding their areas need not give a unique total. Use your sample context to choose the ranges. The next examples show the main bands and the extra fields that appear for different presets.');
  setting('#qy', 'Set the Qy window',
    'Qy covers the red chlorophyll-associated region, with 660–690 nm as a configurable starting range. For green algae or plants the label becomes Chl a Qy. For example, inspect the red peak in Spectra before narrowing this window. A window label alone does not establish pigment identity.',
    { fallback: '#qy_slider_ui', unavailable: 'The Qy slider appears after the analysis controls are ready.' });
  setting('#pbs', 'Interpret the preparation-dependent band',
    'The 600–650 nm window has a different label for different preparations: a chlorophyll Qx/vibronic region for proteins or thylakoids, Phycobiliprotein for an isolated preparation, and PBS for eligible cells/lysate. For example, compare the labels for Cyanobacteria → Protein sample and Cells / Lysate before interpreting an area.',
    { fallback: '#band3_slider_ui', unavailable: 'Choose a loaded organism/sample preparation to see this band label.' });
  setting('#chlb_qy', 'Find the chlorophyll b window',
    'Green algae and Plants expose Chl b Qy, initially around 640–657 nm. This gives a separate region to inspect alongside Chl a Qy. For example, select a green-algae preset to see both windows. Their signals and overlaps still require preparation-specific interpretation.',
    { fallback: '#organism', unavailable: 'Choose Green algae or Plants to reveal the Chl b Qy slider. Changing this preset resets the starting band windows.' });
  setting('#pe', 'Find the phycoerythrin window',
    'Red algae with Cells / Lysate exposes an additional phycoerythrin window. This is a useful example of the interface adapting to both organism and preparation. The field defines a reported spectral region; it does not confirm that phycoerythrin caused the signal.',
    { fallback: '#organism, #sample_type', unavailable: 'Choose Red algae and Cells / Lysate to reveal the phycoerythrin slider, or continue without changing your data settings.' });
  setting('#car', 'Adjust the carotenoid window',
    'The starting carotenoid window is 430–520 nm. For example, retain that broad region for an initial overview, then inspect whether a narrower study-specific interval is justified. Its 430–460 nm part overlaps the Soret/Bx window, so the two areas are not independent pieces of a total.');
  setting('#bx', 'Adjust the Soret or Bx window',
    'Soret / Bx starts at 420–460 nm and covers the strong blue chlorophyll-associated region. For example, compare its peak location with Qy in Spectra. PASA assumes no universal Soret-to-Qy ratio: preparation, solvent, blanking and instrument response can change the relationship.');
  setting('#reset_bands', 'Reset the band starting values',
    'Reset Bands to Defaults restores the windows for the currently declared organism and sample type. Use it after exploring custom windows if you want to return to that preset. It changes the band settings and therefore recalculates band-dependent results.');
  setting('#band_overlap_notice', 'Review overlapping windows',
    'This notice appears when band windows overlap and helps you inspect which reported regions share wavelengths. For example, a carotenoid/Soret overlap can be expected from the initial windows. Treat overlapping areas as related measurements rather than adding them as separate pigment quantities.',
    { fallback: '#pasa-settings-bands', unavailable: 'An overlap notice is shown only when the current band windows warrant one; the band sliders remain the place to inspect the limits.' });

  setting('#apply_baseline', 'Choose whether to subtract a baseline',
    'Baseline correction subtracts one assumed additive reference value. For example, a measured low-absorption far-red reference can reduce a uniform offset when justified for your sample. Switching it off leaves the uploaded basis before PASA subtraction, disables normalization, and prevents the baseline-dependent deconvolution workflow.');
  setting('#baseline_method', 'Compare the two baseline methods',
    'Single nm requests one reference wavelength; Window median baseline requests a wavelength interval. For example, compare a 750 nm reference with a justified 745–750 nm median window. The window method requires at least three eligible measured points. Neither method establishes that the reference is absorption-free.',
    { fallback: '#apply_baseline', unavailable: 'Enable Apply baseline correction to reveal the method choices.' });
  setting('#baseline_nm', 'Request a single reference wavelength',
    'A value such as 750 nm is a request: PASA uses the nearest eligible native measured node in the full source, which can lie outside the analysis range. Inspect the requested and effective reference reported in Metrics. Noise or residual absorption at that point affects every corrected wavelength.',
    { fallback: '#baseline_method, #apply_baseline', unavailable: 'Enable baseline correction and choose Single nm to reveal this numeric field.' });
  setting('#baseline_win', 'Use a median reference window',
    'Choose a study-justified, approximately flat low-absorption window, for example 745–750 nm when your measurements support it. PASA subtracts the median of at least three eligible native points. It refuses a window with too few points instead of moving it to another region.',
    { fallback: '#baseline_method, #apply_baseline', unavailable: 'Enable baseline correction and choose Window median baseline to reveal both window endpoints.' });
  setting('#baseline_input_error', 'Read baseline input problems',
    'If a baseline request is invalid, this message explains the setting that needs attention. For example, a window with insufficient usable measurements cannot supply a median. Review the input warning and effective-baseline fields before interpreting an apparently corrected curve.',
    { fallback: '#pasa-settings-baseline', unavailable: 'There is no baseline error to show when the request is valid; this group is where any input warning will appear.' });
  setting('#resample_on', 'Choose whether to resample',
    'Resampling places traces on a common evenly spaced wavelength axis. For example, it can make plots or exported tables easier to compare when sampling intervals differ. A finer grid estimates intermediate values; it does not add measured information. A coarser grid uses integral-based bin averaging.');
  setting('#grid_step', 'Set the grid spacing',
    'Grid step is the spacing in nanometers when resampling is enabled. For example, 1 nm creates a common 1 nm grid; 2 nm is coarser. Coarsening can smooth detail and alter an individual band area near its boundaries, even where the method preserves full-range area under its stated conditions.');
  setting('#smooth', 'Compare the smoothing choices',
    'None preserves the unsmoothed processed signal. Savitzky–Golay fits local polynomials, while Moving avg averages neighboring points. For example, inspect the unsmoothed trace first and then compare one gentle smoothing choice. Smoothing can shift, broaden or distort features; native-path QC and deconvolution follow their separately documented methods.');
  setting('#sg_n', 'Choose an SG window',
    'This is the Savitzky–Golay window length in points. For example, an 11-point window uses a wider neighborhood than 5 points. The physical width also depends on grid spacing. PASA enforces an odd window that exceeds the polynomial degree; compare the effect on a narrow peak.',
    { fallback: '#smooth', unavailable: 'Select Savitzky–Golay under Smoothing to reveal its window control.' });
  setting('#sg_p', 'Choose the SG polynomial degree',
    'Polynomial degree controls the local curve used inside the SG window. For example, degree 3 with an 11-point window is an initial setting to inspect, not a universally optimal choice. The window must exceed the degree. Check sensitivity before trusting peak shape after smoothing.',
    { fallback: '#smooth', unavailable: 'Select Savitzky–Golay to reveal the polynomial-degree control.' });
  setting('#ma_k', 'Choose a moving-average window',
    'The moving-average window sets how many neighboring points are averaged. For example, 7 points gives more smoothing than 3 points but can blur narrow structure. Compare its result with None and an SG example so you can recognize which visible features depend on smoothing.',
    { fallback: '#smooth', unavailable: 'Select Moving avg under Smoothing to reveal its own window control.' });

  setting('#dilution', 'Apply one dilution factor',
    'The global factor multiplies values for samples without an individual override. For example, a recorded twofold dilution suggests a nominal factor of 2 when measurement conditions support the linear-response interpretation. It does not recover absolute concentration or repair scattering. Normalization can hide this amplitude change in the plotted curves.');
  setting('#per_sample_dilution_ui input[id^="dil_"]', 'Set an individual sample factor',
    'Open Individual dilution correction factor to see one numeric row per selected sample. For example, use 2 for one diluted sample while another inherits the global factor. A finite positive entry overrides the global factor for that sample; a blank or invalid row falls back to the global value.',
    { fallback: '#per_sample_dilution_ui, #dilution', unavailable: 'Select at least one sample and open Individual dilution correction factor. Each selected sample receives its own row.' });
  setting('#norm_method', 'Choose a normalization basis',
    'Normalization rescales each curve by a chosen reference and sacrifices its original amplitude information. Choose None to retain that scale. The other options use the spectral maximum, value at one wavelength, total area, a band peak or a band area. Baseline correction must be enabled for normalization to apply.');
  setting('#norm_target', 'Choose the target value',
    'The target is the positive value assigned to the selected normalization reference. For example, target 1 makes a chosen peak equal to 1 after normalization. Zero, negative and nonfinite targets are refused. A target is a plotting/analysis scale; it is not a concentration calibration.');
  setting('#norm_method', 'Example: spectral maximum to one',
    'Choose Max → target and set Target value to 1 to compare relative shape while each usable spectral maximum is scaled to one. This uses the maximum within the active analysis range, so changing that range can change the reference. Look at Spectra and the readable normalization summary afterward.');
  setting('#norm_ref_nm', 'Example: one wavelength as the reference',
    'Choose Value@λ → target to reveal Reference λ. For example, request 680 nm and target 1 if that wavelength is a justified, usable reference for all compared samples. Review the result and any refusal: a reference must have a supported, finite nonzero value; typing a wavelength does not create a measurement.',
    { fallback: '#norm_method', unavailable: 'Choose Value@λ → target to reveal the Reference λ numeric field.' });
  setting('#norm_method', 'Example: total area to one',
    'Choose Total area → target with target 1 to put curves on a common integrated-area scale across the selected range. Unlike maximum normalization, no individual peak must equal one. Because the range defines the area being normalized, keep it consistent when comparing samples.');
  setting('#norm_band', 'Example: Qy band peak to one',
    'Choose Band peak → target, then choose Qy (or Chl a Qy for its preset) and target 1. Each usable selected-band peak is scaled to one. Spectra should report a label such as “Band peak: Qy, target value: 1”. Inspect whether all compared samples have a meaningful peak in that window.',
    { fallback: '#norm_method', unavailable: 'Choose Band peak → target to reveal Normalization band, then select the Qy band for this example.' });
  setting('#norm_band', 'Example: band area to one',
    'Choose Band AUC → target and select a band to normalize by its integrated area rather than its highest point. For example, Qy with target 1 makes that region’s normalized AUC the reference. A broader or differently shaped peak can therefore scale differently than under band-peak normalization.',
    { fallback: '#norm_method', unavailable: 'Choose Band AUC → target to reveal the band selector for an area-normalization example.' });
  setting('#dl_data_fmt', 'Choose the data export format',
    'Select CSV, Excel (.xlsx), or Tab-text (.txt) for the applicable processed-data, metrics and QC downloads. For example, Excel is convenient for a workbook workflow, while a tab-text table can be read by many analysis programs. This changes the exported container, not the analysis values.');
  setting('#dl_processed_pre, #dl_processed_post', 'Export pre- and post-normalization values',
    'Pre-norm values export a wide table before the final normalization scale; Post-norm values expose the corresponding normalized basis when a method is selected. For example, retain both to distinguish an amplitude comparison from a shape comparison. The tour describes these actions without downloading your data.',
    { fallback: '#pasa-settings-exports', unavailable: 'Post-norm values appears only when a normalization method is selected; Pre-norm values remains available for the unnormalized processed basis.' });
  setting('#snapshot_include_settings, #snapshot_include_data', 'Choose what a standalone snapshot contains',
    'Settings records your analysis/display choices; Input data records the active table and applicable growth/blank state. For example, keep both checked to reopen the working analysis later. These choices are mirrored on Summary. Download everything (ZIP) always includes a full snapshot even if a standalone checkbox is off.');

  // SETTINGS_END

  fit('#advanced_mode', 'Enable the advanced workspace',
    'Advanced Mode adds Deconvolution after Data Quality. It fits a sum of phenomenological spectral components to one selected sample. Switch the toggle on if you want to inspect its controls. The tour does not enable it or run a fit automatically; you can read this chapter and skip unavailable examples.',
    { nav: null, requiresData: false });
  fit('#decon_input_provenance', 'Check the fit input and prerequisites',
    'Deconvolution needs loaded data, a selected sample and baseline correction. Its provenance explains which curve is actually fitted: the native analysis basis follows the documented preprocessing path, rather than simply refitting a smoothed display image. Read this before assigning meaning to a component.',
    { output: true, fallback: '#advanced_mode, #apply_baseline', unavailable: 'Enable Advanced Mode, load data and enable baseline correction in Analysis settings to make this workflow available.' });
  fit('#decon_sample', 'Choose one spectrum to fit',
    'The sample selector chooses a single active spectrum. For example, start with a well-measured control before comparing a treatment. Changing the sample does not automatically run a new fit; review the controls and use Run deconvolution when ready.',
    { fallback: '#advanced_mode', unavailable: 'Enable Advanced Mode and baseline correction, then select at least one sample in Analysis settings.' });
  fit('#decon_sample_class', 'Choose a development starting preset',
    'Pure pigments, Purified complexes, and Cells / thylakoids load different development starting settings. For example, selecting Purified complexes resets bounds and seeding settings for that preset. These labels organize starting values; they are not validation of the model for your specimen. Review the settings that changed.');
  fit('#decon_kmin', 'Set the smallest component count',
    'k_min is the smallest number of pseudo-Voigt components to try. For example, k_min = 1 lets the search test a single broad component before considering more complex models. The selected component count is a numerical model choice, not a measured count of molecules or pigments.');
  fit('#decon_depth', 'Distinguish tested and extended search depths',
    'Tested range keeps the upper component count at four, the range exercised by the separately distributed recovery study. Advanced opt-in permits up to twenty. For example, remain in Tested range for an initial fit; choosing a larger range is an uncharacterized sensitivity analysis with greater runtime and identifiability concerns.');
  fit('#decon_kmax', 'Set the largest component count',
    'k_max caps the sweep that begins at k_min. For example, 1 through 4 tests a small set of model sizes. A larger maximum can find extra mathematical structure but also increases runtime and ambiguity. Very short spectra can lower the effective feasible count; review the depth advisory.');
  fit('#decon_criterion', 'Choose the candidate-ranking score',
    'AIC-like, BIC-like and AICc-like plug-in scores balance fit and model size under PASA’s documented calculation. For example, compare whether the chosen K changes with the score while inspecting residuals. These are not standard likelihood-based information criteria and do not estimate molecular-species counts.');
  fit('#decon_criterion_note, #decon_depth_advisory', 'Read the score and search-depth notes',
    'These notes describe the current score and any search outside the packaged tested range. For example, raising k_max above four activates an explicit depth advisory. Read the note alongside the candidate table so that a numerical best score is not mistaken for validated molecular identification.',
    { output: true, fallback: '#decon_criterion, #decon_kmax', unavailable: 'The applicable notes depend on the current criterion and K limit.' });
  fit('#decon_bootstrap', 'Explore K-selection stability',
    'This optional residual-block bootstrap repeats selection and reports how often each K is chosen, including no-admissible and error outcomes. For example, enable it only when you want a sensitivity check beyond one fit. It is slower and follows an explicit confirmation. Deconvolution bootstrap uses a background worker so the interface stays responsive; Cancel deconvolution stops the requested work. If a worker is unavailable, bootstrap is refused with an explanation. The tour does not request or confirm a job.');
  fit('#decon_mu_tol', 'Constrain component-center movement',
    'Open Advanced fit settings to find μ tolerance. It limits how far a center can move from its derivative-seeded position; 8 nm is a development default. For example, inspect whether a fitted center repeatedly reaches this bound. The tolerance is a search setting, not an instrument-resolution specification.');
  fit('#decon_fwhm_min, #decon_fwhm_max', 'Set the allowed component widths',
    'FWHM min and max bound the widths of candidate components. For example, the starting 8–50 nm range constrains narrow and broad solutions. A component at either limit deserves review. Change one bound at a time to assess sensitivity; these are configurable search limits, not physical pigment bandwidth rules.');
  fit('#decon_seed_win', 'Choose a seeding window',
    'The seeding window controls SG smoothing used to locate second-derivative starting features, expressed in nm and converted to an odd point count. For example, a wider window can produce fewer broad seeds; a narrow window can follow noise. Extra components may be seeded by residual deflation and marked tentative.');
  fit('#decon_red_clip', 'Choose the red-edge fitting limit',
    'Red-edge clip sets the upper wavelength used for seeding and fitting. For example, 750 nm excludes wavelengths farther into a tail that you judge unsuitable. This is a user-declared boundary, not evidence that the excluded region is absorption-free. Inspect the retained fit range and residuals.');
  fit('#decon_scatter_on', 'Inspect the empirical baseline option',
    'This deconvolution-local option models an inverse-power background with a constant term. When active, its constant replaces the ordinary offset subtraction for the fit input so the constant is not removed twice. For example, inspect a justified tail-region model as a sensitivity analysis; it does not prove a scattering mechanism.');
  fit('#decon_scatter_start, #decon_scatter_end', 'Choose the tail-fit interval',
    'Tail fit start and end select the region used by the empirical background model. For example, choose a measured far-red interval that your study supports as a useful background region. A short or contaminated tail can poorly constrain the exponent. Read the fit-window note before accepting the correction.',
    { fallback: '#decon_scatter_on', unavailable: 'Enable the empirical inverse-power baseline option to reveal its start and end fields.' });
  fit('#decon_scatter_overlay', 'Overlay the removed background',
    'Overlay removed curve lets you inspect the empirical background alongside the fitted view. For example, compare how much of a broad tail is assigned to background before interpreting the remaining components. Showing an overlay changes the display; it does not independently validate that background choice.',
    { fallback: '#decon_scatter_on', unavailable: 'Enable the empirical baseline option to reveal the overlay checkbox.' });
  fit('#decon_scatter_fixb_on, #decon_scatter_fixb', 'Compare free and fixed exponents',
    'Hold exponent b fixed reveals a numeric exponent. For example, you can compare a study-justified fixed value with a freely estimated exponent to assess sensitivity. The tour supplies no universal exponent: the model and interval must be justified for the specimen. Turn the option off to let the model estimate it.',
    { fallback: '#decon_scatter_on, #decon_scatter_fixb_on', unavailable: 'Enable the empirical baseline option, then Hold exponent b fixed to reveal the numeric b field.' });
  fit('#decon_scatter_blank', 'Supply a measured blank when appropriate',
    'Measured blank / turbidity curve lets you supply a separate measured reference for this workflow. For example, use a matching instrument/medium reference from the same measurement basis and inspect the source and basis notes. Uploading a reference is a scientific choice; the tour does not select or upload a file.',
    { fallback: '#decon_scatter_on', unavailable: 'Enable the empirical baseline option to reveal the measured-reference upload.' });
  fit('#decon_blank_source_status, #decon_blank_basis_note, #decon_scatter_window_note', 'Verify the blank source and basis',
    'These fields report the available reference, how its values enter the correction, and whether the requested interval is usable. For example, after restoring a session, verify that the expected measured blank and basis were restored. A missing or unsuitable reference should be resolved before interpreting the fit.',
    { output: true, fallback: '#decon_scatter_blank, #decon_scatter_on', unavailable: 'Enable the empirical baseline option; applicable source/basis notes appear for the current reference and interval.' });
  fit('#decon_blank_clear', 'Remove a measured blank',
    'Remove measured blank clears that reference from this analysis. For example, use it when switching to a different measurement preparation, then inspect the updated source status. It can change the fit input and make existing results stale; it does not delete the original reference file on your computer.',
    { fallback: '#decon_scatter_on', unavailable: 'The measured-reference controls appear under the empirical baseline option.' });

  fit('#decon_run', 'Run only when you are ready',
    'Run deconvolution launches the candidate fit for the selected sample and current settings. For example, first check the input basis and modest K range, then run an initial model. The fit is on demand. The tour can introduce the outputs without automatically starting this computation.');
  fit('#decon_boot_confirm', 'Review the bootstrap confirmation',
    'When a bootstrap-enabled run requests confirmation, this dialog explains the runtime decision and offers the appropriate continuation. Review the estimate before choosing Continue. The tour never presses that button. You can skip this step if you are only learning where the optional computation is controlled.',
    { fallback: '#decon_bootstrap, #decon_run', unavailable: 'This confirmation appears only after you request an applicable bootstrap-enabled run.' });
  fit('#decon_status, #decon_timer, #decon_stale_banner, #decon_run_status, #decon_cancel', 'Track progress and stale results',
    'Status and the elapsed timer describe the current run. A stale-result notice appears when settings change after a fit. For example, moving a width bound can leave the previous result visible with a warning until you run again. Always check whether the displayed result matches the live settings.',
    { output: true, fallback: '#decon_run', unavailable: 'Run status, timer and stale warnings appear when there is a relevant run or changed setting.' });
  fit('#decon_method_badge, #decon_scatter_readout', 'Check the fitted method and background',
    'The method badge and empirical-background readout identify the basis used for the result. For example, compare these with the baseline controls after a fit to confirm which correction was applied. The background parameters are model outputs under your assumptions, not proof of a physical scattering law.',
    { output: true, fallback: '#decon_run, #decon_scatter_on', unavailable: 'These readouts need an applicable fit or empirical-background result.' });
  fit('#decon_overlay_plot', 'Inspect the fitted overlay',
    'The overlay compares the input trace, combined fitted curve and modeled components. For example, look for broad regions that the combined fit misses, and inspect whether components overlap heavily. A visually good fit can have more than one plausible decomposition; component colors and count do not establish pigment identities.',
    { output: true, fallback: '#decon_run', unavailable: 'Run a fit to see the actual overlay, or continue to learn about the remaining result fields.' });
  fit('#decon_residual_plot', 'Inspect the residual pattern',
    'Residuals show what remains after subtracting the fitted model from its input. For example, a structured shoulder in the residual can suggest model mismatch, while a background trend can point toward preprocessing sensitivity. A small overall residual alone does not prove that individual components have molecular meaning.',
    { output: true, fallback: '#decon_run', unavailable: 'The residual plot becomes available after a fit.' });
  fit('#decon_comparison_table', 'Compare candidate model sizes',
    'The comparison table records candidate K values, scores and fitting diagnostics. For example, inspect whether several admissible candidates have similar scores instead of reporting only the selected row. The displayed best admissible choice can differ from an unconstrained raw minimum when an optimizer or resolution check rejects a candidate.',
    { output: true, fallback: '#decon_run', unavailable: 'A completed candidate sweep supplies this comparison table.' });
  fit('#decon_components_title, #decon_display_role_banner, #decon_components_table', 'Read component parameters with their role',
    'The component table reports quantities such as center, width, amplitude and area, together with the displayed model’s role. For example, check bound flags and any available local standard-error information before interpreting a small component. Those uncertainties are model-conditional; an apparent component is not automatically a distinct molecular species.',
    { output: true, fallback: '#decon_run', unavailable: 'Run a fit to populate the component table and its role banner.' });
  fit('#decon_interpretation_notes', 'Read the interpretation notes',
    'These notes bring together warnings about tiny or near-noise components, constraints and other fit limitations. For example, inspect whether a very small component is flagged before deciding that it represents a pigment. Compare simpler models and independent evidence; the notes guide review rather than automatically deleting components.',
    { output: true, fallback: '#decon_run', unavailable: 'Interpretation notes are generated from an available fit.' });
  fit('#decon_enlarge_overlay, #decon_enlarge_resid', 'Enlarge either diagnostic plot',
    'Each plot has its own Enlarge action. For example, enlarge residuals when checking a weak structured feature, then return to the full tab to compare the candidate and component tables. Enlarging changes viewing space, not the fitted result.');
  fit('#decon_dl_pdf, #decon_copy_tab, #decon_copy_notify', 'Export the full fit context',
    'Download as PDF preserves a report of the fit; Copy Entire Tab prepares its text and tables for another application and reports whether copying succeeded. For example, retain the fit context with the component table when sharing a result. The tour does not copy or export automatically.',
    { fallback: '#decon_run', unavailable: 'Fit exports need an available result; the copy-status message appears only after a copy attempt.' });

  // DECONVOLUTION_END

  grow('#growth_manual, #growth_gate_banner', 'Choose a growth-data route',
    'Cell growth can use eligible loaded spectra or manually entered OD readings. Loaded-spectra mode requires Cells / Lysate for a supported organism. Manual entry works independently of spectral data. For example, choose manual entry to explore a time series already recorded in a spreadsheet; the gate banner explains the active route.');
  grow('#growth_strain', 'Name the strain or series',
    'This optional name labels the growth curve and summary. For example, enter a strain identifier that is appropriate to include in exported results. Keep one species or strain per analysis; the field does not group multiple organisms into separate biological models.',
    { fallback: '#growth_manual', unavailable: 'Activate a growth route to use the measurement setup.' });
  grow('#growth_wl, #growth_wl_num', 'Choose a tracking wavelength',
    'The slider and numeric box are linked ways to select the tracking wavelength. For example, 730 nm reads a far-red OD value from each mapped spectrum. In manual mode it is optional metadata because the typed OD values are used directly. The wavelength and OD–biomass relationship need study-specific justification.');
  grow('#growth_wl_warn, #growth_wl_label_inline', 'Check wavelength availability and basis',
    'The label and any warning describe how the tracking wavelength is being used. For example, loaded-spectra OD can use an exact native node or a permitted interpolation; an unsupported gap gives an unavailable reading. The observations export records the method and bracket. The spectral-tail subtraction is deliberately bypassed for growth.',
    { output: true, fallback: '#growth_wl', unavailable: 'A warning is displayed only if the current tracking wavelength or data needs attention.' });
  grow('#growth_unit', 'Choose days or hours',
    'Time unit controls the x-axis and rate units. For example, choose Hours for readings every half hour, or Days for daily measurements. All mapped or typed columns must use the same time basis. Switching the label is not a substitute for checking the actual measurement schedule.');
  grow('#growth_interval', 'Set equal spacing between observations',
    'Interval size is the positive spacing between consecutive columns in the chosen unit. For example, Hours with 0.5 means observations every thirty minutes. The first column is the first measurement and the last column is the last; this workflow assumes equally spaced times.');
  grow('#growth_nrep', 'Count independent biological replicates',
    'Biological replicates are separate cultures or colonies, with one row or nested block per unit. For example, three independently grown cultures means three biological replicates. Repeated readings of the same culture belong under technical replicates instead. A configured but empty unit remains part of the recorded design.');
  grow('#growth_rep_mapping', 'Map spectra in time order',
    'In loaded-spectra mode, each replicate selector lists active samples. For example, map time-zero, first-interval and second-interval spectra in that order for Rep 1. Repeat for other biological units. The order you choose defines the time series; sample names alone do not establish measurement time.',
    { fallback: '#growth_manual', unavailable: 'Use eligible loaded spectra with manual entry off to reveal the Replicate → sample mapping selectors.' });
  grow('#growth_map_preview', 'Verify the mapped OD observations',
    'This preview lets you check the mapping before interpreting the growth fit. For example, verify that a rising time series was not accidentally reversed. Read any exact/interpolated/unavailable flags and compare them with your original acquisition record. Incorrect mapping can create a misleading growth curve.',
    { output: true, fallback: '#growth_rep_mapping, #growth_manual', unavailable: 'Select ordered samples in loaded-spectra mode to populate the mapping preview.' });
  grow('#growth_manual', 'Use manual OD values',
    'Manual entry replaces the values taken from loaded spectra for this tab. For example, enter instrument-zeroed or medium-blanked OD readings from a plate reader. PASA uses the entered values as supplied and does not add another blank correction. Activating this route is an explicit user choice.');
  grow('#growth_ntech', 'Distinguish technical repeats',
    'Technical replicates are repeated measurements of the same biological unit. For example, three cultures measured twice each means three biological and two technical replicates, not six independent cultures. With two or more technical repeats, the grid expands into nested rows and PASA averages technical readings within each biological unit and time.',
    { fallback: '#growth_manual', unavailable: 'Enable manual OD entry to reveal the technical-replicate count.' });
  grow('#growth_ntp', 'Set the number of timepoints',
    'Timepoints sets the number of measurement columns in the manual grid. For example, eight timepoints at an interval of one hour creates eight consecutive observations. Check both the displayed headers and your original measurement schedule. Changing the grid dimensions can expose or hide cells, so review the complete intended design.',
    { fallback: '#growth_manual', unavailable: 'Enable manual OD entry to reveal the timepoint count.' });
  grow('#growth_load_dummy', 'Explore the built-in growth example',
    'Load built-in demo data populates a three-replicate, eight-timepoint example growth curve. It is useful for learning the outputs without preparing a file. It replaces the manual example values, so use it deliberately; the tour does not press it or overwrite your current growth measurements.',
    { fallback: '#growth_manual', unavailable: 'Enable manual entry to access the built-in growth example.' });
  grow('#growth_od_1_1', 'Enter an ordinary OD cell',
    'Each ordinary grid row is one biological replicate and each column is a timepoint. For example, enter the first culture’s initial blanked OD in the first cell, then follow the time headers across the row. Leave unavailable readings blank rather than inventing a measurement.',
    { fallback: '#growth_manual_grid, #growth_manual', unavailable: 'Enable manual entry with one technical replicate to see an ordinary first-cell example.' });
  grow('#growth_od_1_1_1', 'Inspect a nested-design OD cell',
    'With two or more technical replicates, a row label identifies both the biological unit and its technical repeat. For example, Bio 1 · Tech 1 and Bio 1 · Tech 2 belong to the same culture. This representation prevents repeated measurements from being counted as independent biological units.',
    { fallback: '#growth_ntech, #growth_manual', unavailable: 'Enable manual entry and set technical replicates to at least two to reveal nested rows.' });
  grow('#growth_paste_mode, #growth_paste_data, #growth_apply_paste', 'Paste a delimited growth table',
    'Paste mode accepts rows in the displayed replicate order and columns in time order, separated by tabs, spaces, commas or semicolons. In a nested design, match the expanded biological × technical rows. For example, copy a rectangular OD table from a spreadsheet, then click Apply pasted data and inspect the resulting grid and headers carefully. Opening the paste area does not overwrite edited cells. Tab- or semicolon-delimited data can use decimal commas; invalid or excess cells are refused before changes are applied.',
    { fallback: '#growth_manual', unavailable: 'Enable manual entry, then Paste delimited data to reveal the text area.' });
  grow('#growth_clear_grid', 'Clear manual inputs deliberately',
    'Clear inputs empties the OD cells in the manual grid. For example, use it before entering a new experimental series after saving the old one. This is a change to the current working data, so the tour describes the button without clicking it.',
    { fallback: '#growth_manual', unavailable: 'The clear-grid button is available in manual-entry mode.' });

  grow('#growth_summary_sentence, #growth_result_msg', 'Read the growth result status',
    'The summary and result message tell you whether the observations support a qualifying fitted window. For example, a flat or declining series may remain a measured curve without an exponential-rate result. Read the message before treating a missing number as a software failure or a biological no-growth conclusion.',
    { output: true, fallback: '#growth_manual, #growth_load_dummy', unavailable: 'Provide a mapped or manual time series to populate the growth result summary.' });
  grow('#growth_plot', 'Read measured and fitted growth curves',
    'The plot shows the supplied OD observations and an applicable fitted interval. Linear and log views help inspect different aspects of the series. For example, check whether the selected apparent exponential region is plausible and whether cultures agree. OD-based growth is a proxy with measurement and biological assumptions.',
    { output: true, fallback: '#growth_manual, #growth_load_dummy', unavailable: 'Enter observations or load the growth example to generate a curve.' });
  grow('#growth_phase_alpha', 'Adjust phase shading',
    'Phase color intensity changes the transparency of the colored background phases. For example, reduce it when shading makes replicate points hard to read. This is a presentation setting; it does not change phase boundaries, the selected fitting interval or the calculated growth rate.');
  grow('#growth_metrics_cards', 'Read rates and qualifying outcomes together',
    'The cards summarize available quantities such as apparent OD-derived rate, doubling time and culture-level outcomes. For example, distinguish the rate among qualifying cultures from how many supplied cultures qualified. Neither a conditional interval nor a qualifying-window fraction automatically establishes an underlying biological population rate or binary growth endpoint.',
    { output: true, fallback: '#growth_manual, #growth_load_dummy', unavailable: 'The available metric cards depend on the data and whether a qualifying window is found.' });
  grow('#growth_interpretation', 'Read the growth interpretation and limits',
    'This narrative explains the observed fit, qualifying units and uncertainty for the active design. For example, nested technical repeats and independent biological cultures contribute differently. Read the stated conditioning and omitted uncertainties before describing an interval as a confidence interval; the app documents sensitivity estimates and their boundaries.',
    { output: true, fallback: '#growth_manual, #growth_load_dummy', unavailable: 'Supply a usable growth series to obtain the interpretation text.' });
  grow('#growth_advanced', 'Reveal supplementary growth outputs',
    'Show advanced / supplementary outputs reveals per-replicate diagnostics, candidate windows, phase boundaries and detailed downloads. For example, open it when you want to understand why a particular fitting interval was selected. This checkbox is separate from the global Advanced Mode that reveals spectral deconvolution.');
  grow('#growth_bestfit_tbl', 'Inspect per-replicate fits',
    'The best-fit table lets you inspect the contributing replicate-level fits. For example, compare rates and fit diagnostics across cultures instead of relying only on an aggregate card. Table availability depends on the result and design; missing or excluded units need interpretation from the accompanying status.',
    { output: true, fallback: '#growth_advanced', unavailable: 'Enable supplementary outputs and provide an applicable fitted result to reveal the replicate-fit table.' });
  grow('#growth_candidates_tbl', 'Inspect alternative growth windows',
    'The candidate-window table shows intervals considered during selection. For example, check whether several windows give similar apparent rates or whether the result depends strongly on one short interval. This table provides context for selection sensitivity and for documenting the final analysis.',
    { output: true, fallback: '#growth_advanced', unavailable: 'Enable supplementary outputs; the candidate table appears when the current result provides window candidates.' });
  grow('#growth_phase_tbl', 'Inspect estimated phase boundaries',
    'The phase table records the available boundaries corresponding to plot shading. For example, compare the identified exponential interval with your experimental observations before assigning biological phase labels. Boundaries are operational summaries of the supplied series, not independent measurements of a biological transition.',
    { output: true, fallback: '#growth_advanced', unavailable: 'Enable supplementary outputs and provide a result with phase information to reveal this table.' });
  grow('#growth_boot', 'Explore reselection-bootstrap sensitivity',
    'The optional reselection bootstrap resamples residual series and repeats the full window selection. For example, use it to examine how sensitive an apparent rate is under this resampling model. It is slower and yields a model-conditional percentile sensitivity interval, not a calibrated confidence interval. A runtime confirmation precedes execution.');
  grow('#growth_boot_nested_note', 'Check whether the bootstrap applies',
    'The classic reselection bootstrap does not apply to the nested biological × technical engine. For example, when technical replicates are at least two, the note explains that the checkbox has no effect and the nested design reports its own conditional sensitivity interval. Check the active design before comparing uncertainty summaries.',
    { output: true, fallback: '#growth_boot, #growth_ntech', unavailable: 'The nested-design note appears when the bootstrap checkbox is on while a nested manual design is active.' });
  grow('#growth_boot_run', 'Request an optional bootstrap run',
    'Run bootstrap requests the calculation only after you enable the option. For example, first inspect the ordinary fit, then request this sensitivity analysis if it answers your question. The button can also offer re-run or retry after a previous attempt. The tour does not start a job.',
    { fallback: '#growth_boot', unavailable: 'Enable reselection bootstrap in a supported non-nested design to reveal the run control.' });
  grow('#growth_boot_confirm, #growth_boot_preflight_cancel', 'Review the runtime confirmation',
    'The preflight dialog offers Run and Cancel after explaining the requested bootstrap. For example, cancel if the estimate is unsuitable for your computer or current session. This is a real computation decision; advancing the tour never confirms it for you.',
    { fallback: '#growth_boot_run, #growth_boot', unavailable: 'The confirmation dialog appears only after an explicit bootstrap request.' });
  grow('#growth_boot_cancel_run, #growth_boot_controls', 'Track or cancel a running bootstrap',
    'While the job starts or runs, this area shows progress and a Cancel action. For example, cancel an unintended expensive run instead of closing the whole analysis. The control later reports completion, cancellation or a retry state. These are runtime states, so a passive tour may show only the idle controls.',
    { fallback: '#growth_boot', unavailable: 'A live Cancel button and progress appear only during an active bootstrap attempt.' });
  grow('#growth_top_dl_pdf, #growth_top_dl_img, #growth_dl_plot_png, #growth_dl_plot_pdf', 'Save the growth figure',
    'The Results header offers PDF and image downloads; supplementary outputs also provide plot downloads. For example, use PDF for a vector-friendly report or an image for a slide. Check the current phase shading and figure labels before saving. The tour itself downloads nothing.',
    { fallback: '#growth_advanced, #growth_manual', unavailable: 'Some duplicate plot downloads are under supplementary outputs and require an applicable result.' });
  grow('#growth_dl_summary, #growth_dl_observations', 'Export the summary and observations',
    'The summary export records the analysis result, while observations preserves the underlying mapped or manual readings and their provenance. For example, keep both when reporting a rate so a reviewer can inspect the actual series and any exact/interpolated/unavailable OD values.',
    { fallback: '#growth_advanced', unavailable: 'Enable supplementary outputs to find the detailed data downloads.' });
  grow('#growth_dl_contract, #growth_dl_candidates, #growth_dl_phases', 'Export the window-selection evidence',
    'The contract describes the window-selection rules; candidate and phase downloads preserve applicable detailed outputs. For example, archive these with the observations to document why the chosen interval was reported. Candidate or phase files appear only when the result has that information.',
    { fallback: '#growth_advanced', unavailable: 'Enable supplementary outputs; candidate and phase downloads depend on the available result.' });

  // GROWTH_END

  window.PASATourDetailSections = { settings, deconvolution, growth };
  window.PASATourDetailedSteps = [...settings, ...deconvolution, ...growth];
})();
