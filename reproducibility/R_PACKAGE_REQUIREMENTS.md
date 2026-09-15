# PASA 1.0.0: R and package requirements

PASA's reproducible environment is **R 4.6.0 plus the 127 package versions in renv.lock**. The source and reproducibility copies of the lock must be byte-identical. The launcher and hosted wrapper check R/package versions; they never install or upgrade packages during startup. Use a fresh R process after restoring dependencies.

The public repository contains no R runtime or installed package library. Install R 4.6.0 separately and restore the lock on the target platform. Compatible CRAN binaries may be used when available; packages unavailable as exact-version binaries must be compiled from source.

On Linux or macOS, restore the lock on that platform. Do not copy Windows DLLs or another architecture's package library. Compiled-package platform metadata is checked. Cross-platform acceptance requires the release's actual Ubuntu 24.04 and macOS 15 arm64 CI results; a Windows run or source inspection alone does not establish it.

## Install and verify

1. Install exact R 4.6.0, including its standard/recommended packages.
2. Install the native build dependencies below if packages will be compiled from source.
3. Run `Rscript --vanilla reproducibility/INSTALL_DEPENDENCIES.R`.
4. Run `Rscript --vanilla reproducibility/VERIFY_ENVIRONMENT.R`.
5. Start with the platform launcher or `Rscript --vanilla START_PASA.R`.

The repository installer bootstraps the locked renv 1.2.3 and restores the lock into the local project library. Initial restoration requires internet access. A separately prepared desktop distribution may supply a complete compatible library, which the installer checks in place; the public repository does not supply one. Set PASA_R_LIB only to a complete, compatible, already-restored native package library.

The lock fixes R package versions. It does not pin the OS, compiler, external libraries, browser, graphics driver or BLAS implementation, and it does not by itself guarantee byte-identical numerical output across platforms.

## Direct packages

Startup attaches shiny 1.14.0, bslib 0.11.0, readxl 1.5.0, dplyr 1.2.1, tidyr 1.3.2, tibble 3.3.1, stringr 1.6.0, ggplot2 4.0.3, gt 1.3.0, ggrepel 0.9.8, data.table 1.18.4, httr 1.4.8 and googlesheets4 1.1.2. Runtime support includes jsonlite, digest, fastmap, curl, htmltools, later and scales. Restore the entire lock rather than installing this short list manually.

The supported frozen environment includes all locked packages. These feature dependencies explain what becomes unavailable if a worker or backend fails, or if a developer deliberately runs an incomplete environment outside the supported launcher:

| Dependency | Affected behavior |
| --- | --- |
| mirai + later, and a readable PASA source directory | Every URL/Google Sheets import and local file above 2 MiB requires the background reader, as do worksheet inspection and feedback submission. These operations are refused when the worker is unavailable. Local files at or below 2 MiB can load directly, through upload or an authorized desktop path; the built-in example remains usable. Growth bootstrap can use its cooperative fallback. |
| visNetwork + igraph | Interactive similarity network. Static fallback needs ggraph + igraph; otherwise the pair table remains. |
| plotly | Interactive 3D spectra overlay. |
| minpack.lm | Preferred deconvolution optimizer; bounded optimization fallback remains. Local parameter standard errors are conditional on the chosen model, not calibrated uncertainty. |
| signal | Savitzky–Golay smoothing and deconvolution seeding support; unavailable smoothing is disclosed rather than silently presented as applied. |
| patchwork | Combined growth-plot layout. |
| writexl | Excel export; CSV fallback remains. |
| zip | Complete ZIP download. |
| gridExtra | Legacy optional table-rendering support; current core metrics/deconvolution tables use base grid. |
| lme4 | Included in the lock; the current biological-unit growth estimator does not switch its estimator according to lme4 availability. |

## Native libraries and tools

These requirements come from the installed packages' DESCRIPTION SystemRequirements fields and the graphics/export paths. Binary package installers may bundle some libraries; source builds need compatible headers, libraries and toolchains.

| Native dependency | Consumers / purpose |
| --- | --- |
| C, C++ and Fortran compilers; GNU make; pkg-config; CMake >= 3.2 | Compiled packages, Rcpp/RcppEigen, minpack.lm, minqa, nloptr and their dependencies. Eigen headers are supplied by the locked RcppEigen package. |
| libcurl >= 7.73 with HTTPS support; CA certificates | curl, remote input and network backends. |
| OpenSSL >= 1.0.2 | openssl and websocket. |
| libxml2 | xml2; optionally igraph. |
| Fontconfig and FreeType | systemfonts and font discovery. Install usable fonts, including needed scientific/CJK glyphs. |
| Cairo plus PNG/JPEG-capable R graphics | Unicode PDF and PNG exports. The R build must report the relevant graphics capabilities; source-package installation alone cannot add a missing R graphics device. |
| Poppler C++ API | pdftools. On Debian/Ubuntu this is libpoppler-cpp-dev, not only the command-line Poppler utilities. |
| libjpeg | qpdf's bundled native code; also JPEG graphics support. |
| zlib | httpuv and writexl; usually supplied by the OS/toolchain. |
| GNU gettext headers and library on macOS | data.table source builds need libintl.h and the matching library search path. |
| V8 or a shared Node.js library | V8. Its installer can instead use upstream static V8 binaries on supported platforms; that bootstrap download needs network access. |
| libuv | fs; a bundled libuv build is available when a suitable system library is absent. |
| ICU4C >= 61 | stringi; it has a bundled ICU fallback. |
| GLPK >= 4.57 | Optional system backend for igraph. |
| libnng >= 1.12 and Mbed TLS >= 3.0 | nanonext can build bundled copies when suitable system versions are absent. Old distribution versions must not be assumed sufficient. |
| Chrome/Chromium | chromote/webshot2 browser capture operations and browser-level tests. Ordinary interactive use needs a modern browser; WebGL is required for 3D spectra. |
| Pandoc >= 1.14 | rmarkdown document conversion when used. The ordinary app UI and base-grid PDF exports do not require a TeX installation. |

A suitable Ubuntu 24.04 source-build set is: build-essential, gfortran, cmake, pkg-config, libcurl4-openssl-dev, libssl-dev, libxml2-dev, libfontconfig1-dev, libfreetype6-dev, libcairo2-dev, libpng-dev, libjpeg-dev, libpoppler-cpp-dev, zlib1g-dev, libuv1-dev, libicu-dev, libglpk-dev and libnode-dev, plus CA certificates and appropriate fonts. Browser capture additionally needs Chrome/Chromium. The CI restore and smoke tests are the acceptance check for the exact locked package set.

### macOS arm64 source builds

Use native arm64 R 4.6.0, Xcode Command Line Tools and the Fortran compiler compatible with that R distribution. Source builds may need Homebrew CMake, pkgconf, curl, OpenSSL, libxml2, fontconfig, freetype, cairo, jpeg-turbo, poppler, libuv, ICU, GLPK and gettext. Avoid mixing Intel libraries with arm64 R; V8/nanonext may use their supported bundled builds.

The locked data.table 1.18.4 source build includes `libintl.h`. Make gettext headers and libraries visible to R before running the installer. From the repository folder, in the same terminal used for installation:

```sh
brew install gettext
gettext_prefix="$(brew --prefix gettext)"
test -f "$gettext_prefix/include/libintl.h"
test -f "$gettext_prefix/lib/libintl.dylib"
pasa_makevars="$(mktemp "${TMPDIR:-/tmp}/pasa-Makevars.XXXXXX")"
printf 'CPPFLAGS += -I%s/include\nLDFLAGS += -L%s/lib\n' "$gettext_prefix" "$gettext_prefix" > "$pasa_makevars"
R_MAKEVARS_USER="$pasa_makevars" Rscript --vanilla reproducibility/INSTALL_DEPENDENCIES.R
```

This temporary Makevars preserves the compiler flags in R's own configuration and adds gettext search paths. It does not read a personal `~/.R/Makevars`; if that file contains required compiler settings, include those settings in the temporary file before installation. The release CI uses the same gettext flags with the compiler configured by its R setup step. See the [data.table installation guidance](https://github.com/Rdatatable/data.table/wiki/Installation), [Homebrew dependency-path guidance](https://docs.brew.sh/How-to-Build-Software-Outside-Homebrew-with-Homebrew-keg-only-Dependencies), and [R compilation customization manual](https://cran.r-project.org/doc/manuals/R-admin.html#Customizing-package-compilation).

### Windows source builds

On Windows, the exact-lock installer can use compatible CRAN binaries when available. Building packages from source requires the compiler toolchain specified for the exact CRAN R 4.6.0 distribution, plus any package-specific native dependencies; do not infer compatibility solely from an older Rtools installation. The public repository does not include a native package library.

Local uploads and the built-in example can be analyzed offline after restoration. Remote inputs and feedback submission require a network. Desktop mode may load user-supplied local paths; hosted mode always refuses arbitrary server paths.
