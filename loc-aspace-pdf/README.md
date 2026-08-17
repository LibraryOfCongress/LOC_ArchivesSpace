## LOC PDF

This plugin replaces the two pdf pipelines in core ArchivesSpace. It
moves all PDF generation to a background job, and uses a pipeline
adapted from the core pipeline in the public user interface.

### Scheduler

The scheduler is a separate program intended to run as nightly a cron
job. It depends on the API endpoint provided by the
[Archivesspace Export Service](https://github.com/hudmol/archivesspace_export_service)
plugin.

Only the `backend` directory from the plugin is required, so you can
do something like this:

```
git clone --filter=blob:none --no-checkout https://github.com/hudmol/archivesspace_export_service \
cd archivesspace_export_service
git sparse-checkout set 'backend'
git checkout
```

### Debugging PDF Generation

You can add this to your config to capture the raw HTML when running
the generate pdf background job:

```
AppConfig[:debug_pdf_generation] = true
```
