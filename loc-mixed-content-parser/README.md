# LOC Mixed Content Parser

EAD3 introduced new mixed content tags, so we needed to extend
the core mixed content parser for LOC data.

We also patch various classes to catch mixed content issues as
they turn up (for instance <part> tags in agent names).
