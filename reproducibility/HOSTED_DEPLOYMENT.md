# Deploy PASA 1.0.0 to Shiny

Deploy the complete source_snapshot directory with app.R as the entry point. Include every R helper, www asset, data file, and renv.lock. Do not upload an installed Windows library.

The service must provide R 4.6.0 and the exact locked package versions. The hosted entry point verifies them without installing packages at startup, selects a UTF-8 locale, and disables typed server-file paths. Visitors can upload files or request permitted public URLs.

For shinyapps.io, use Posit's rsconnect deployment client after restoring the local environment. Keep deployment credentials outside the source tree and Git. The deployment client should use the included lockfile with strict dependency resolution. Inspect its generated manifest and build log before sharing the live URL.

After deployment, check welcome/tour assets, real file upload, demo analysis, Metrics/Spectra outputs, saved sessions and downloads, and Advanced-mode fitting. Confirm that background jobs complete and that cancellation does not replace the last accepted result. Hosting resource and request limits still apply.

The repository's desktop Linux/macOS tests and the hosted deployment are separate checks. RELEASE_VERIFICATION.md identifies the exact platform runs and deployed source when those have completed.
