# Third-party notices

This record identifies third-party components and public implementation references in the PASA 1.0.0 source release. Author-created material is separately licensed as stated in [LICENSE.md](LICENSE.md); this notice preserves third-party scope and terms.

## CIE adapted data

PASA loads two discrete adapted files under `source_snapshot/data/`:

- `CIE_1931_2deg_380_780_10nm.csv`, adapted-file SHA-256 `15CF5186BB80D911D555D2E07BCA7F5ADBC2E2B7016C5CDD67134FE0E63CFB63`; and
- `CIE_D65_380_780_10nm.csv`, adapted-file SHA-256 `20E1B192FD24D745063365DB49AC4FFE7C771B849F40E358282F6A3071BD80F0`.

The source datasets were published by the International Commission on Illumination (CIE) under CC BY-SA 4.0. The adapted files remain under CC BY-SA 4.0 and are outside the PASA MIT and author-created CC BY 4.0 scope. `source_snapshot/data/CIE_DATA_NOTICE.md` records the creators, titles, DOIs, official URLs, published source checksums, exact 10-nm selection and rounding changes, adapted-file checksums, downstream conditions, and no-endorsement statement. Its original explanatory prose is separately covered by the author CC BY 4.0 notice. Notice SHA-256: `48E8D98C487C246414AD74337529A6BE1131D4D6E913B40C078E7342DDE37E00`.

- CIE 1931 dataset DOI: <https://doi.org/10.25039/CIE.DS.xvudnb9b>
- CIE D65 dataset DOI: <https://doi.org/10.25039/CIE.DS.hjfjmt59>
- License: <https://creativecommons.org/licenses/by-sa/4.0/>

## R package dependencies

PASA references 127 exact CRAN package versions in `reproducibility/renv.lock`. Packages are downloaded separately and retain their own copyright, licenses, and notices. The PASA source release does not contain CRAN package source code, package binaries, an installed R library, a container, or a portable dependency bundle.

The version-bound inventory is `dependencies/DEPENDENCY_LICENSE_INVENTORY.tsv`, SHA-256 `5625F1C31CB4A21F416767D37684A412566A14FFB317597784D6090CA5EB790F`. `dependencies/README.md` describes the source-only distribution and external package requirements. Redistributing dependencies requires a separate review of their terms. A PASA license does not relicense the referenced packages; upstream package metadata and license files control.

## Public implementation reference

PASA's XYZ(D65)-to-sRGB implementation cites the public W3C CSS Color 4 implementation reference at <https://www.w3.org/TR/css-color-4/conversions.js>.

## Browser test dependencies

The development-only browser smoke test references Playwright 1.62.1 (Apache-2.0) through a pinned npm lockfile. Its packages and Chromium browser are installed separately for testing and are not shipped as PASA code or required by the application runtime. Upstream dependency licenses remain authoritative.
