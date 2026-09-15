# PASA component licenses

PASA uses the component licences below. The code, documentation, adapted CIE tables, and other third-party material have separate terms. These scopes retain the licences applied to the earlier PASA materials; the manuscript has a separate publication licence.

| Component in this candidate | Applicable terms |
|---|---|
| Author-created software code, including R, JavaScript, Python, PowerShell, CSS, application and test scripts, and release configuration | [MIT](LICENSES/MIT.txt), copyright (c) 2026 Arman Pazuki and Fatemeh Aflaki |
| Author-created documentation, including README files, security/privacy/compatibility/reproducibility instructions, `THIRD_PARTY_NOTICES.md`, the original explanatory prose in `source_snapshot/data/CIE_DATA_NOTICE.md`, and this component guide | [Author CC BY 4.0 notice](LICENSES/AUTHOR_CC_BY_4_0_NOTICE.md) and [CC BY 4.0 legal code](LICENSES/CC-BY-4.0.txt) |
| Original figures, synthetic examples, generated validation fixtures, and protectable author-created expression in analysis/evidence outputs, metadata, tables, inventories, and manifests | Author CC BY 4.0 notice; source facts and third-party rights are not claimed |
| Files nested in the four retained reliability ZIPs, where present | The same author CC BY 4.0 scope for generated output and fixture expression; the archives contain no dependency source or binary. The synthetic XLSX example is in this scope, including original arrangement and chart expression; numerical facts and formulas are not claimed |
| `source_snapshot/data/CIE_1931_2deg_380_780_10nm.csv` and `source_snapshot/data/CIE_D65_380_780_10nm.csv` | [CC BY-SA 4.0](LICENSES/CC-BY-SA-4.0.txt), with the adjacent [CIE attribution/change notice](source_snapshot/data/CIE_DATA_NOTICE.md). Only these adapted CSVs, not the author-created notice prose or surrounding software, fall in this CIE-data scope |
| BCO-DMO Dataset 3867 v1 source and source-derived content, if present in the evidence candidate | Existing source CC BY 4.0 terms and attribution in `THIRD_PARTY_NOTICES.md`. The raw CSV remains unchanged. The approved author CC BY 4.0 notice covers only protectable author additions; source attribution and transformation notices remain required |
| BCO-DMO-derived processed spectra, public-validation outputs, and preprocessing-sensitivity results, including figures/tables/reports based on those records | Existing BCO-DMO CC BY 4.0 plus author CC BY 4.0 for protectable additions. Independently authored analysis scripts remain MIT; their license does not relicense the data |
| `renv.lock`, package-version records, and dependency-license inventory | Reproducibility metadata only. Referenced packages retain their own licenses and are downloaded separately; PASA does not relicense upstream metadata or package contents |
| `LICENSES/MIT.txt`, `LICENSES/CC-BY-4.0.txt`, and `LICENSES/CC-BY-SA-4.0.txt` | License texts retained as license instruments/reference copies, not claimed as original PASA prose or relicensed by the author CC BY notice |
| Clementson/Wojtasiewicz official-link documentation and independently authored reconstruction tool, where present | Documentation: author CC BY 4.0. Code: MIT. No attachment, copied spectral table, workbook, derivative, or generated result is included or cleared for redistribution |

## Precedence and exclusions

1. A file-specific or adjacent third-party notice controls over a general PASA notice.
2. MIT applies only to author-created software/configuration expression identified above. The phrase "associated documentation files" in the standard MIT text does not override the explicit CC BY 4.0 scope for the separate documentation in this package.
3. The author CC BY 4.0 notice grants only rights in the identified author-created non-code material and protectable author-added expression. Facts, formulas, methods, and public-domain material are not made proprietary by this record.
4. Names, institutional names, trademarks, ORCIDs, contact information, privacy/publicity rights, and patent rights are not licensed merely because they occur in the package. No endorsement is implied. Rights outside the authors' control are not granted.
5. CRAN source, binaries, installed libraries, fonts, third-party JavaScript libraries, containers, and portable dependency bundles are outside the audited source-plus-lockfile boundary. Any future bundling requires a new audit.
6. The manuscript, submission records, private governance, baseline records, and held Clementson/Wojtasiewicz sources and derivatives are outside both candidate boundaries and this license application.
7. Keep applicable license, attribution, and change notices with copied or extracted components, including generated files extracted from the validation archives.

`RELEASE_INVENTORY.tsv` identifies the exact content files and component dispositions; `MANIFEST_SHA256.tsv` identifies their bytes plus the inventory.
