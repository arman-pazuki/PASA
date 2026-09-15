# Install PASA 1.0.0

Use R 4.6.0. Download the repository as a ZIP and extract it, or clone it with Git. Keep the folder structure intact.

From the repository folder, run:

```sh
Rscript --vanilla reproducibility/INSTALL_DEPENDENCIES.R
Rscript --vanilla reproducibility/VERIFY_ENVIRONMENT.R
Rscript --vanilla START_PASA.R
```

The installer restores the exact 127 package versions in the lockfile, including renv itself. It needs internet access on the first run. On Linux and macOS, first install the native libraries described in [R and package requirements](R_PACKAGE_REQUIREMENTS.md). On macOS arm64, also complete the [gettext compiler setup](R_PACKAGE_REQUIREMENTS.md#macos-arm64-source-builds) before restoring the lock; installing gettext alone does not add its headers to R's compiler search path. For source-package installation on Windows, use the CRAN build tools compatible with R 4.6.0.

Verification prints ENVIRONMENT_VERIFICATION_PASS only when the R/package versions and recorded source checksums agree. The launcher never installs packages. It starts a local browser interface bound to 127.0.0.1; close its console with Ctrl+C to stop the app.

Windows users can double-click START_PASA.cmd after installing the packages. If Rscript is not on PATH, use its full path, for example:

```powershell
& 'C:\Program Files\R\R-4.6.0\bin\Rscript.exe' --vanilla '.\START_PASA.R'
```

A clone contains source, assets, examples, setup scripts, and a lockfile. It does not include R or platform-specific package binaries and needs no previous PASA version. Once dependencies are installed, local-file and demo analysis work offline.

An administrator may supply a complete locked library through PASA_R_LIB. It must match this R version, package versions, operating system, and architecture. Do not copy Windows packages onto Linux or macOS.

See [hosted deployment](HOSTED_DEPLOYMENT.md) for shinyapps.io and other Shiny services. The [release verification report](../RELEASE_VERIFICATION.md) states which platforms were actually tested.
