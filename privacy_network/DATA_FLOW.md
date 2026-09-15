# Data flow

## Local desktop mode

| Stage | Location | Data |
|---|---|---|
| File selection | Browser on the user's computer | User-selected spectra/session/blank file. |
| Upload transport | Loopback connection (`127.0.0.1:<runtime port>`) | Selected file and UI values. |
| Parsing and analysis | Local R/Shiny process; optional local workers | Spectra, settings, intermediate and final results. |
| Display | Browser on the same computer | Rendered tables, plot/widget payloads, notifications. |
| Export | User-selected browser download location | Snapshot, tables, plots, reports, or ZIP. |

No external provider is involved in this flow unless the user triggers remote URL loading, an outbound link, package installation, or direct feedback submission. The Feedback tab uses the existing PASA Google Form by default: a POST occurs only after a reaction is selected, the notice acknowledged, and Send feedback clicked. It requests no name or email and performs no geolocation; Google still receives ordinary request metadata. `PASA_FEEDBACK_ENABLED=0` disables this service. A complete custom endpoint configuration can replace it. Save feedback downloads a local text file, and Compose email prepares a draft in the user's email app; PASA does not send that email.

## Hosted mode

| Stage | Location | Consequence |
|---|---|---|
| Browser upload | User device to remote server | Input crosses the network. |
| Analysis | Hosting server/processes | Operator/infrastructure controls memory, temporary files, logs, backups, and access. |
| Display/export | Remote server to browser | Results cross the network back to the user. |

The PASA app source ends with `shinyApp(ui, server)` and does not itself configure TLS, authentication, server logs, retention, backups, or data residency. The supplied trusted-desktop runner explicitly binds the local process to `127.0.0.1`. A hosted deployment requires a separate runner and remains responsible for its host binding and all other deployment controls.

## Typed server-local paths

Typed local filesystem paths are denied by default. Trusted desktop-path loading is enabled only by an explicit desktop-mode/local-path opt-in and is disabled when hosted mode is declared. Enabling it allows the R process to read files accessible to its operating-system account and must never be enabled on a public server.

Ordinary browser uploads remain available independently of typed-path access.
