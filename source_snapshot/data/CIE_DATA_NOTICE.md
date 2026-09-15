# CIE adapted data notice

Status: third-party data governed by an existing license. This notice does not apply a license to PASA's author-created software.

## Scope and license

This notice applies only to:

- `CIE_1931_2deg_380_780_10nm.csv`
- `CIE_D65_380_780_10nm.csv`

Both files are adaptations of datasets published by the International Commission on Illumination (CIE), Vienna, Austria. CIE's metadata identifies each source dataset as licensed under the [Creative Commons Attribution-ShareAlike 4.0 International license](https://creativecommons.org/licenses/by-sa/4.0/) (CC BY-SA 4.0). The adapted files remain under CC BY-SA 4.0. PASA's authors do not claim authorship or ownership of the underlying CIE values.

The surrounding PASA source code, documentation, and other components are outside this notice. Their licenses, if approved, must be stated separately.

## Sources and attribution

### CIE 1931 color-matching functions

- Creator: International Commission on Illumination (CIE)
- Dataset title supplied by CIE: *Colour-matching functions of CIE 1931 standard colorimetric observer*
- Publication year: 2019
- DOI: [10.25039/CIE.DS.xvudnb9b](https://doi.org/10.25039/CIE.DS.xvudnb9b)
- CIE landing page: <https://cie.co.at/datatable/cie-1931-colour-matching-functions-2-degree-observer>
- Official CSV: <https://files.cie.co.at/CIE_xyz_1931_2deg.csv>
- Official metadata: <https://files.cie.co.at/Publications-datasets/CIE_xyz_1931_2deg.csv_metadata.json>
- CIE-published MD5: `17cca777db64b17170f06f67ce9d3ab7`
- CIE-published SHA-256: `fa663e3535a7e0763a745993a1f0a192eb0275ac46ad2d1befd7626841e713c1`
- Adapted-file SHA-256: `15cf5186bb80d911d555d2e07bca7f5adbc2e2b7016c5cdd67134fe0e63cfb63`

Suggested attribution: CIE 2019, *Colour-matching functions of CIE 1931 standard colorimetric observer*, International Commission on Illumination (CIE), Vienna, Austria, DOI 10.25039/CIE.DS.xvudnb9b, adapted as described below, CC BY-SA 4.0.

### CIE standard illuminant D65

- Creator: International Commission on Illumination (CIE)
- Dataset title supplied by CIE: *CIE standard illuminant D65*
- Publication year: 2019
- DOI: [10.25039/CIE.DS.hjfjmt59](https://doi.org/10.25039/CIE.DS.hjfjmt59)
- CIE landing page: <https://cie.co.at/datatable/cie-standard-illuminant-d65>
- Official CSV: <https://files.cie.co.at/CIE_std_illum_D65.csv>
- Official metadata: <https://files.cie.co.at/Publications-datasets/CIE_std_illum_D65.csv_metadata_v2.json>
- CIE-published MD5: `03d4eb9b837c60671627c946fb534deb`
- CIE-published SHA-256: `e76f210bffff3d552ef7113025da5f325d5dfec200dd4b878b1a2f3a507032cb`
- Adapted-file SHA-256: `20e1b192fd24d745063365db49ac4ffe7c771b849f40e358282f6a3071bd80f0`

Suggested attribution: CIE 2019, *CIE standard illuminant D65*, International Commission on Illumination (CIE), Vienna, Austria, DOI 10.25039/CIE.DS.hjfjmt59, adapted as described below, CC BY-SA 4.0.

## Changes made by PASA

Access and verification date: 2026-09-01.

- Selected the 41 exact source rows from 380 through 780 nm inclusive at 10-nm intervals. No interpolation was used to create either adapted file.
- Renamed the columns for explicit units and meaning.
- Preserved PASA's pre-remediation displayed precision: four decimal places for the three color-matching functions and two decimal places for D65 relative spectral power.
- Rounded each selected source value to the displayed precision. Every adapted value differs from its official source value by no more than one-half unit in the final displayed decimal place. The maximum absolute difference is `0.00004999999` for the color-matching functions and `0.005` for D65.
- Preserved PASA's two pre-remediation choices at exact D65 half-way values: `104.865` at 440 nm is stored as `104.86`, and `104.405` at 540 nm is stored as `104.41`. This explicit tie policy preserves the existing PASA table and numerical behavior; it does not imply additional source precision.
- Moved the values from literal R objects into discrete CSV files so their license scope and attribution are clear. No scientific meaning or source attribution was changed.

## Required downstream treatment

Anyone sharing modified versions of these two adapted files must comply with CC BY-SA 4.0, including attribution, a link to the license, indication of changes, and ShareAlike treatment of the adapted material. Do not remove this notice when redistributing either file.

No-endorsement statement: neither CIE nor W3C has reviewed, certified, sponsored, or endorsed PASA or these adaptations. Product and organization names are used only for attribution and technical reference.
