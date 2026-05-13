# LOC ISO Language Code Updates

This plugin updates the ArchivesSpace **language_iso639_2** enumeration to reflect the Library of Congress’s (LOC) current usage of ISO 639-2 codes. It renames older “2b” codes to their newer equivalents and adds any missing codes used in LOC finding aids.

## Overview

This is an [ArchivesSpace plugin](https://github.com/archivesspace/archivesspace/tree/master/plugins) that:

1. **Renames** out-of-date ISO 639-2 codes (e.g., `chi` → `zho`).  
2. **Merges** if a ISO code like is already present.  
3. **Inserts** new codes used by LOC (e.g., `kfk => Kinnauri`, `khb => Lü`) if they are missing.

It **does not** override any CSV export. Instead, it ensures the **enumeration_value** table in ArchivesSpace contains the correct codes for “Language (language_iso639_2).”

## Installation

1. **Clone** or download this plugin repository, named `loc-iso-lang-updates`, into your ArchivesSpace `plugins/` directory (or create a symlink).
2. **Enable** the plugin in `config/config.rb` (or your preferred config file):
   ```ruby
   AppConfig[:plugins] = [
     # other plugins here...
     'loc-iso-lang-updates'
   ]

