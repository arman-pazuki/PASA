# Reproducibility

- [Install and verify](INSTALLATION.md) the R 4.6.0 environment.
- [Launch PASA](LAUNCH_INSTRUCTIONS.md).
- [Package and native-library requirements](R_PACKAGE_REQUIREMENTS.md).
- [Host the same source](HOSTED_DEPLOYMENT.md).

renv.lock and ../source_snapshot/renv.lock are identical. VERIFY_ENVIRONMENT.R checks package versions and SOURCE_CHECKSUMS.tsv. FREEZE_SOURCE_CHECKSUMS.R --freeze is a maintainer command to regenerate the inventory after deliberate source changes; it is not part of normal installation.

BUILD_DEFAULTS_AND_LIMITS.R generates PASA_DEFAULTS_AND_LIMITS.tsv from the current application source. The release workflow runs the functional checks in ../validation/release. See ../RELEASE_VERIFICATION.md for executed evidence and its limits.
