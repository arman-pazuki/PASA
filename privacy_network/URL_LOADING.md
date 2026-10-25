# URL loading

## Trigger

Merely pasting a URL does not contact it. Network access begins when the user clicks **Inspect sheets** or **Load data**.

## Accepted resources

- Only `http://` and `https://` URLs are accepted.
- Google Sheets recognition is limited to `docs.google.com` spreadsheet paths and uses deauthenticated public access.
- Recognized OneDrive forms include `1drv.ms`, `onedrive.live.com`, and `sharepoint.com`, including subdomains.
- Other DNS-resolving public HTTP(S) hosts are accepted by the generic loader; PASA uses a public-address denylist rather than a Google/OneDrive-only allowlist.
- Embedded URL usernames/passwords are refused.

## Network protections

- DNS failure and private/non-global address ranges are refused.
- The resolved public address is pinned for the generic connection.
- Redirect destinations are revalidated.
- Generic downloads recognize HTTP 301, 302, 303, 307, and 308 and allow at most five redirects.
- Recognized OneDrive links use a separate bounded HEAD-resolution sequence before download.
- Normal `httr`/`curl` HTTPS certificate verification remains enabled.

These controls reduce server-side request-forgery risk but do not make an untrusted public file safe or confidential. Prefer HTTPS and known sources.

## Limits

For main spectra input, the application-level limits are:

| Limit | Value |
|---|---:|
| Raw file/download | 32 MiB |
| Expanded in-memory table | 64 MiB |
| Sample columns | 2,000 |
| Rows | 500,000 |
| Cells including wavelength | 4,000,000 |
| XLSX archive entries | 512 |
| XLSX uncompressed content | 512 MiB |
| XLSX compression ratio | 100 |
| Generic redirects | 5 |
| Intended load budget | 120 s desktop; 60 s hosted |

Important qualifications:

- PASA sets `shiny.maxRequestSize` before startup, with a 32-MiB default. A lower explicit option or `PASA_UPLOAD_LIMIT_MIB` is retained and shown in the input panel. A hosting proxy can impose a separate smaller limit.
- The measured-blank upload does not use the shared 32-MiB/row/column/cell preflight; it is constrained by the Shiny/deployment boundary and parser.
- The 60/120-second values are intended budgets, not an absolute wall-clock guarantee for every provider. OneDrive preliminary HEAD calls and staged Google API calls use partly separate timing behavior.

## Provenance and disclosure

The full URL is used to fetch data. Stored provenance removes user info, query, and fragment but retains path. A secret embedded in the path can therefore appear in snapshots/run summaries. Inspecting a generic workbook and subsequently loading it can cause two downloads. Remote providers can see ordinary connection metadata and the originating local or hosted server IP.
