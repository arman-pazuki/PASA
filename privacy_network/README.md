# Privacy and network behavior

Use these documents to describe what PASA does when run locally and how that changes when it is hosted remotely.

- `PRIVACY_AND_NETWORK_STATEMENT.md`: comprehensive publication-ready statement.
- `DATA_FLOW.md`: browser, local R process, temporary storage, and hosted boundary.
- `URL_LOADING.md`: exactly when network access begins, accepted hosts, metadata, limits, and provenance.
- `DATA_RETENTION_AND_EXPORTS.md`: memory, temporary files, browser storage, snapshots, ZIPs, clipboard, and feedback.

For confidential work, use local desktop execution with local upload, no remote URL loading or outbound links, and `PASA_FEEDBACK_ENABLED=0` to disable direct feedback. By default the visible Feedback tab offers the existing PASA Google Form after a reaction, acknowledgment, and explicit Send feedback click; no name or email is requested. It also supports a local text download and an optional email draft. A custom direct destination requires complete field mappings, an identified controller, and its privacy-information URL.
