# Privacy and network statement

## Local desktop execution

PASA is a Shiny application. The supplied desktop launcher explicitly binds Shiny to `127.0.0.1`, even if a user- or site-level option sets a different default host. When PASA is launched that way, selected files travel from the browser to the local R/Shiny process through the loopback connection. Analysis runs in that local R process, with optional local worker processes for heavier operations. The audited PASA source defines no database, durable upload repository, analytics service, tracking pixel, automatic cloud backup, automatic telemetry, crash-report submission, IP-geolocation call, or background update check.

After the required packages are installed, local-file and built-in-demo analysis can operate without external internet access. External communication occurs only when the user explicitly:

- clicks **Inspect sheets** or **Load data** for a remote URL;
- selects a reaction, acknowledges the notice, and clicks **Send feedback**; or
- opens an email, social-media, or external reference link.

Package installation/restoration is a separate user-initiated network activity described in the reproducibility instructions.

## Uploaded data and session state

Main spectra uploads are staged in Shiny-managed temporary storage and parsed by the R server. Parsed spectra, settings, results, and the last successfully loaded dataset remain in session-scoped R memory until replaced, reset/reloaded, disconnected, or the R process ends.

PASA defines no application-managed persistent upload folder or database. PASA removes its own temporary copies, URL downloads, ZIP staging directories, and intermediate exports on normal completion. Shiny manages original upload temporary files. This is ordinary cleanup, not cryptographic erasure; R memory, operating-system caches, swap, crash remnants, security software, host logs, and backups are outside PASA's control.

## Browser/server boundary

PASA is not purely client-side JavaScript. Inputs and uploaded files are sent to the Shiny server, most calculations run in R, and rendered tables/plots/widgets plus downloads return to the browser. Some interaction, such as rotating an already-delivered WebGL plot, occurs in the browser.

For a normal local launch, browser and server are on the same computer. For a hosted deployment, uploaded files, UI values, rendered payloads, and downloads cross the network to/from the hosting server.

## Browser storage and cookies

PASA stores the display-theme choice in browser `sessionStorage` under `spectra_appearance`. Guided-tour revision 2 also stores a small progress record: tour kind, quick/detailed status and step, and revision. In browser/hosted mode this uses `localStorage` key `pasa.guidedTour.2`; an explicitly declared desktop launch uses `tour-preference.dcf` in the PASA user configuration directory (or `PASA_PREFERENCES_DIR`). If preference storage is unavailable, progress can remain session-only. These preferences contain no spectra, filenames, analysis settings, results, or feedback. No application-defined cookies were found. Browsers, Shiny, reverse proxies, or hosting providers can independently use cookies or maintain access logs.

## Remote URLs

Pasting a URL does not initiate a request. A request begins only after **Inspect sheets** or **Load data** is clicked. PASA accepts public `http://` and `https://` resources, with specialized handling for recognized Google Sheets and OneDrive/SharePoint links and a generic loader for other public hosts.

Use HTTPS wherever possible: plain HTTP is accepted and does not provide transport confidentiality.

PASA refuses embedded URL usernames/passwords and blocks hosts that fail DNS resolution or resolve to private, loopback, link-local, reserved, documentation, benchmarking, multicast, or other non-global address space. The resolved public address is pinned for the actual generic connection and redirects are revalidated.

For acquisition, the full entered URL is used. Durable PASA provenance removes user information, query parameters, and fragments, but preserves the scheme, host, optional port, and path. Share identifiers or secrets embedded in a path can therefore remain in snapshots or summaries. Review exports before publication.

## What remote providers receive

PASA downloads the selected remote resource; it does not upload a previously loaded spectrum to that provider. The provider can still observe the requested URL/query, originating server IP, DNS and HTTP/TLS metadata, user agent, redirects, and repeated access. Inspecting a generic remote workbook downloads it, and a later Load action can fetch it again.

For local desktop use, the originating IP is normally the user's network address. For hosted use, it is normally the hosting server's address.

## Feedback and outbound links

The Feedback tab is always visible. **Send feedback** uses the existing PASA Google Form by default and does not request a name, email address, or sign-in. A POST occurs only after the user selects a rating, acknowledges the notice, and clicks Send feedback. The payload contains the rating, optional free-text comment, submission timestamp in UTC, and PASA version. The legacy location field is omitted, and PASA performs no IP geolocation. It does not attach spectra, sample names, filenames, analysis settings, or results. The interface identifies the PASA developer as response controller and links Google's privacy information. Google can receive the originating server IP and ordinary request metadata; its processing and logs are outside PASA's control. A comment may itself identify its author, so submitting without an email address is not a guarantee of anonymity against the receiving service.

The default form is optional: `PASA_FEEDBACK_ENABLED=0` disables direct submission while leaving the Feedback tab and draft alternatives available. To replace the destination, an operator must supply an HTTPS `PASA_FEEDBACK_FORM_URL`; four unique nonempty `PASA_FEEDBACK_*_FIELD` mappings for rating, comment, timestamp, and version; a nonempty `PASA_FEEDBACK_CONTROLLER_NAME`; and an HTTPS `PASA_FEEDBACK_PRIVACY_URL`. An incomplete custom configuration disables direct submission rather than falling back to the bundled form. The custom service/controller is disclosed before sending. Its retention, access, deletion, and geographic-processing policies are the operator's responsibility.

If the request fails or the expected Google confirmation is absent, PASA keeps the current draft and reports that sending could not be confirmed. **Save feedback (.txt)** provides a local fallback for offline use. **Compose email** optionally prepares a draft to `pasa.app@outlook.com`; the user reviews and sends it through their email app, whose account identity, metadata, and retention rules apply. Drafts contain the selected reaction, entered comment, and PASA version. Preparing a draft or saving it does not send feedback. Feedback inputs remain transient session inputs and are excluded from analysis snapshots.

Email, X, LinkedIn, and reference links activate external activity only when clicked. Destination services can receive normal metadata, cookies/account identifiers, and anything the user chooses to send.

## Exports

Session snapshots are unencrypted plain text. The standalone TXT's Settings and Input data checkboxes control its content; Complete ZIP always embeds the full snapshot regardless of those standalone choices. The full snapshot can include settings/software identity, the complete active input table, sample names/selections, growth values/mappings, parsed measured-blank name/hash/wavelengths/values when applicable, and the upload filename or sanitized remote URL. A Complete ZIP serializes PASA's accepted, parsed active table and state; it does not necessarily preserve the original upload's byte stream, workbook sheets, formulas, cell formatting, or file-level metadata. Other downloads contain the tables, plots, summaries, names, and provenance appropriate to the selected output.

PASA performs no encryption or anonymization of exports. Treat snapshots, ZIPs, tables, images, PDFs, and clipboard contents as potentially sensitive and review them before sharing.

## Hosted deployment statement

The local statement above must not be reused unchanged for a public server. Use wording such as:

> When PASA is hosted remotely, uploaded files and user interactions are transmitted to and processed on the hosting server. Server operators and infrastructure providers may maintain access logs, temporary files, backups, or diagnostic records independently of PASA. The hosting operator is responsible for HTTPS, authentication where required, access control, geographic hosting location, retention/deletion policy, incident response, and disclosure of subprocessors. Sensitive or identifiable data should not be uploaded unless those safeguards and policies have been established.
