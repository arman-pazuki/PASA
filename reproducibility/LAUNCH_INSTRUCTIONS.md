# Launch PASA 1.0.0

Follow [installation](INSTALLATION.md) once, then run Rscript --vanilla START_PASA.R from the repository root, or open START_PASA.cmd on Windows.

The launcher keeps the app on the local computer (127.0.0.1). It opens the default browser. Set PASA_LAUNCH_BROWSER=0 to suppress that automatic opening and PASA_PORT to choose an available port. Stop the console with Ctrl+C.

The Input data page accepts uploaded local files. Desktop mode additionally permits a typed local path; hosted mode permits only uploads and allowed public URLs. No network data are fetched merely by pasting a URL.

See [R and package requirements](R_PACKAGE_REQUIREMENTS.md) for prerequisites and [hosted deployment](HOSTED_DEPLOYMENT.md) for server use.
