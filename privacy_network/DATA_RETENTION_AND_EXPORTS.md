# Data retention, exports, and feedback

## Session memory and temporary files

- Parsed spectra, active settings, results, and the last successfully loaded dataset remain in R session memory until replaced, reset/reloaded, disconnected, or process termination.
- Shiny manages uploaded temporary files.
- PASA removes its own temporary copies, URL downloads, ZIP staging, and intermediate export files on normal completion.
- Background tasks are stopped or handed to cleanup logic when a session ends, but process termination and memory reclamation can be asynchronous.
- Cleanup is not cryptographic erasure. Operating-system caches, swap, crash remnants, host logging, backup, and forensic recovery are outside PASA's control.

## Browser persistence

PASA stores the display theme in browser `sessionStorage` under `spectra_appearance`. Guided-tour revision 2 stores only the tour kind, quick/detailed status and step, and revision. Browser/hosted mode uses `localStorage` key `pasa.guidedTour.2`; an explicitly declared desktop launch uses `tour-preference.dcf` in the PASA user configuration directory or `PASA_PREFERENCES_DIR`. Preferences contain no spectra, filenames, analysis settings, results, or feedback. Other platform components can independently maintain cache, cookies, history, downloads, or access logs.

## Snapshots and ZIP exports

The standalone session snapshot can include the following according to its two export checkboxes; complete ZIP always embeds the full snapshot regardless of those standalone choices:

- settings and software identity;
- complete active input data;
- sample names and selections;
- manual growth values or growth mappings;
- parsed measured-blank name, hash, wavelengths, and values when a measured deconvolution blank is applicable;
- original upload filename; and
- sanitized remote-source URL, including its path.

Files are unencrypted and not automatically anonymized. Complete ZIP serializes PASA's accepted, parsed active table and analysis state; it does not necessarily preserve the original uploaded file's byte stream, workbook sheets, formulas, formatting, or file-level metadata. PASA likewise does not embed the original measured-blank upload container verbatim, but it can serialize the parsed measured-blank name, hash, wavelengths, and numeric values when applicable. Review these data before sharing any snapshot or ZIP.

## Other downloads and clipboard

Tables, plots, PDFs, images, and reports contain the currently selected names, values, and provenance appropriate to each output. Copy buttons place complete metrics or deconvolution text on the operating-system clipboard. PASA does not transmit clipboard contents, but other local software may read the clipboard.

## Feedback

The Feedback tab is always visible. Direct submission uses the existing PASA Google Form by default. Only an explicit **Send feedback** action after choosing a reaction and acknowledging the notice posts. PASA requests no name, email, or sign-in, and sends the reaction, optional comment, submission timestamp in UTC, and version. The legacy location field is omitted; no geolocation lookup occurs. Spectra, sample names, filenames, settings, and results are not attached. Google can receive the originating server IP and normal request metadata, and a comment can itself identify its author. Submitting without an email does not guarantee anonymity against the receiving service.

An operator can disable direct submission with `PASA_FEEDBACK_ENABLED=0`, or replace the bundled destination using a complete HTTPS endpoint, four unique nonempty field mappings for rating, comment, timestamp, and version, controller name, and HTTPS privacy-information URL. Incomplete custom configuration disables the direct route. The interface identifies the receiving controller/service before sending; their logs, access, retention, deletion, and geographic processing remain outside PASA.

Failed or unconfirmed sends preserve the draft. A user can save a local `.txt` containing the reaction, comment, and version, or optionally prepare an email draft to `pasa.app@outlook.com`. PASA does not send email; users review and send through their email service, whose identity and retention policies apply. Saved feedback text is an unencrypted download. The comment and acknowledgment are transient inputs excluded from analysis snapshots.

## Sharing checklist

Before sending any export:

1. open it and inspect sample names, filenames, URL paths, tables, and figure labels;
2. remove or replace confidential identifiers;
3. confirm the intended recipient and distribution channel;
4. encrypt the file using an approved external method when required; and
5. retain only the minimum necessary data.
