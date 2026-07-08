# LOC EAD Migrator

This plugin adds a job to import a full set of EADs to populate a repo.

The plugin is hardcoded for LOC's use case and would need to be modified 
for other installations.

The plugin looks for a directory of EAD files and imports them one at a time,
each in its own transaction. At the end of the import it provides a report
of successes and failures.
