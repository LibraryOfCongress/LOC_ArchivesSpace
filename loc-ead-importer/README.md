LOC EAD3 Importer
==============================

Custom ArchivesSpace EAD3 Importer for Library Of Congress EADs

## Overview

This is an [ArchivesSpace plugin](https://github.com/archivesspace/archivesspace/tree/master/plugins)
which provides a custom importer for LOC EAD3 data.


## Unit Tests

To run the unit tests, checkout the [ArchivesSpace repo](http://github.com/archivesspace/archivesspace)
and create a symbolic link in the `plugins` directory to this repo. Follow the [steps to bootstrap the
development environment](https://archivesspace.github.io/tech-docs/development/dev.html) and then run:

```shell
./build/run backend:test -Dpattern="loc_ead_*"
```

## Coding Style

We follow the coding standards described in the [LOC coding standards repo](https://github.com/LibraryOfCongress/coding-standards/).
This includes 4 spaces for indents (rather than 2 as in the ArchivesSpace core code). Copy or link the `.editorconfig` file from
the repo and setup your editor to use it as described on the [EditorConfig website](https://editorconfig.org).
