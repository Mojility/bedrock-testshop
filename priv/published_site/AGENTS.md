# Published website artifacts

`scene.json` and `media.json` are produced by Bedrock's publication workflow,
not by a local asset build. `Bedrock.Publishing.Export.files/1` exports a frozen
design document and theme plus metadata for the referenced ready photographs.
The customer application consumes these files through `Shop.Website`.

For composition, facts, theme or published photograph changes, change the
corresponding authoring input and publish it. For rendering or business behavior,
follow the source map in `WEBSITE.md`. Do not hand-edit these files as a source
fix, and do not replace `component_model_hash` to bypass compatibility checks.
A new publication will replace these outputs. There is no local scene-generation
Mix task in this repository.
