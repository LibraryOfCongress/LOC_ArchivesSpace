## LOC PDF

This plugin replaces the two pdf pipelines in core ArchivesSpace. It 
moves all PDF generation to a background job, and uses a pipeline 
adapted from the core pipeline in the public user interface.

### Workflow

Work is planned to add a nightly job that will queue all updated 
Resource records for re-generated PDFs.


### Debugging

You can add this to your config to capture the raw HTML when running
the generate pdf background job:

```
AppConfig[:debug_pdf_generation] = true
```
