# Dependency inventory

PASA references 127 exact CRAN package versions in ../reproducibility/renv.lock. R 4.6.0 and its recommended packages are external prerequisites.

DEPENDENCY_LICENSE_INVENTORY.tsv records the version-bound upstream license metadata. Packages are installed separately; their own notices and copyright/license files remain authoritative. PASA does not relicense dependencies.

The public source repository excludes installed package libraries. An optional administrator-provided PASA_R_LIB must use the same package versions and a compatible native platform. See ../reproducibility/R_PACKAGE_REQUIREMENTS.md.
