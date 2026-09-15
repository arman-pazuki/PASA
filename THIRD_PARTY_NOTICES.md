# Third-party notices

This record identifies third-party components and public implementation references in the PASA 1.0.0 source release. Author-created material is separately licensed as stated in [LICENSE.md](LICENSE.md); this notice preserves third-party scope and terms.

## CIE adapted data

PASA loads two discrete adapted files under `source_snapshot/data/`:

- `CIE_1931_2deg_380_780_10nm.csv`, adapted-file SHA-256 `15CF5186BB80D911D555D2E07BCA7F5ADBC2E2B7016C5CDD67134FE0E63CFB63`; and
- `CIE_D65_380_780_10nm.csv`, adapted-file SHA-256 `20E1B192FD24D745063365DB49AC4FFE7C771B849F40E358282F6A3071BD80F0`.

The source datasets were published by the International Commission on Illumination (CIE) under CC BY-SA 4.0. The adapted files remain under CC BY-SA 4.0 and are outside the PASA MIT and author-created CC BY 4.0 scope. `source_snapshot/data/CIE_DATA_NOTICE.md` records the creators, titles, DOIs, official URLs, published source checksums, exact 10-nm selection and rounding changes, adapted-file checksums, downstream conditions, and no-endorsement statement. Its original explanatory prose is separately covered by the author CC BY 4.0 notice. Notice SHA-256: `53ABFAB908FC1028EC770A7EF9D878E85733FC7A809FC7DFA81AB9FC47DB6348`.

- CIE 1931 dataset DOI: <https://doi.org/10.25039/CIE.DS.xvudnb9b>
- CIE D65 dataset DOI: <https://doi.org/10.25039/CIE.DS.hjfjmt59>
- License: <https://creativecommons.org/licenses/by-sa/4.0/>

## R package dependencies

PASA references 127 exact CRAN package versions in `reproducibility/renv.lock`. Packages are downloaded separately and retain their own copyright, licenses, and notices. The PASA candidate does not contain CRAN package source code, package binaries, an installed R library, a container, or a portable dependency bundle.

The version-bound inventory is `dependencies/DEPENDENCY_LICENSE_INVENTORY.tsv`, SHA-256 `99FF607939F40240A6A61635912DC617AA48020AD4CED41F6D00C1CCF7B635EE`. `dependencies/README.md` explains the audited source-only boundary and the events that require a new redistribution review. A PASA license does not relicense the referenced packages; upstream package metadata and license files control.

## Public implementation reference and independently authored control

PASA's XYZ(D65)-to-sRGB implementation cites the public W3C CSS Color 4 implementation reference at <https://www.w3.org/TR/css-color-4/conversions.js>. PASA does not reproduce standards prose in this notice.

The advanced-mode user-interface switch uses independently authored native checkbox markup with `role="switch"`, CSS track/knob styling, and visible On/Off text. The earlier uncertain Bootstrap-like data-URI SVG artwork is not present in the remediated source, so no Bootstrap artwork or notice is included.

## Evidence outside this software candidate

The software candidate does not contain the BCO-DMO evidence dataset or any Clementson and Wojtasiewicz file. BCO-DMO provenance and CC BY 4.0 attribution are maintained in the separate evidence candidate. No Clementson and Wojtasiewicz source files or derivatives are distributed in either package.

## Browser test dependencies

The development-only browser smoke test references Playwright 1.62.1 (Apache-2.0) through a pinned npm lockfile. Its packages and Chromium browser are installed separately for testing and are not shipped as PASA code or required by the application runtime. Upstream dependency licenses remain authoritative.
