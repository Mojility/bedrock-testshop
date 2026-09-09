# Editable website component definitions

`components.json` is customer-owned authoring source, even when stored on one
line. It declares extension components, property schemas and declarative
implementations. Publication reads it; publication does not generate or replace
it.

Use new component names; built-in names cannot be shadowed. Native components
also need registration in `lib/shop/website/components.ex` and a customer-owned
renderer. See `WEBSITE.md` for the declaration format and preview requirements.
Commit component changes, refresh the component model in the Bedrock design
editor, and publish a compatible scene through the normal workflow.
