# Reporting a security problem

Please report suspected vulnerabilities to **pasa.app@outlook.com**. Include the
PASA version, operating system, input route and steps needed to reproduce the
problem. Do not include passwords, access tokens, confidential spectra, or
sensitive server files. Avoid posting exploit details in a public issue before
the authors have reviewed the report. No response-time guarantee is made.

The desktop launcher binds to the local loopback address. A hosted deployment
must use hosted/default-deny mode and must not enable trusted desktop paths.
Input and URL protections are described in `privacy_network/URL_LOADING.md`.
Direct feedback uses the existing PASA Google Form only after a reaction,
acknowledgment, and explicit Send feedback click. No name or email is requested.
Set `PASA_FEEDBACK_ENABLED=0` to disable it; custom endpoints require complete
field mappings, controller identity, and an HTTPS privacy-information URL.
The Feedback tab also offers an optional email draft and a local text download.

Release status and exact verification scope are recorded in
`RELEASE_VERIFICATION.md`; this policy does not assert that a draft release is
already published or that every deployment has received a security audit.
