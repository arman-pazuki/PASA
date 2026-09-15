# PASA 1.0.0 application source

This directory contains the complete R/Shiny application, the deconvolution module, interface helpers and artwork, adapted CIE tables, and the exact dependency lock.

Use the repository's START_PASA.R or Windows START_PASA.cmd after restoring the packages. For Shiny hosting, deploy this entire directory with app.R as the entry point. Hosted mode disables access to server file paths and accepts uploaded files or permitted public URLs.

The environment requires R 4.6.0 and the versions in renv.lock. Source and launcher checksums are recorded in ../reproducibility/SOURCE_CHECKSUMS.tsv. Run ../reproducibility/VERIFY_ENVIRONMENT.R from the repository to verify them.

See ../README.md for installation, documentation, citation, and component licenses.
