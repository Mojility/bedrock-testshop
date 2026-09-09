# Test fixture provenance

`website_scene.json` is a checked-in scene fixture consumed by website and
controller tests. It is test input, not the authoring source of the public site
and not a file rewritten by the publication workflow.

Change a fixture only when its test scenario changes deliberately. A compatibility
failure can indicate a source-contract regression; do not simply replace its
hash or copy a production scene to make a test pass. Preserve invented records.
