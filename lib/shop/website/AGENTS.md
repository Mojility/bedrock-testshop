# Website definitions and runtime source

This directory is customer-owned source. `document.ex`, `tree.ex` and
`template.ex` expand scene composition using the built-in `registry.ex` and
`organisms.ex` definitions plus `priv/website/components.json` extensions.
HTML behavior is implemented by `lib/shop_web/website_html.ex`; application-backed
public content comes from `content.ex`, with native registrations in `components.ex`.

`ComponentModel.hash/1` includes both the built-in registry and extension
entries. Bedrock's publisher and this renderer must agree on that contract.
Changing only this registry can make every published scene incompatible;
refreshing `components.json` alone does not synchronize built-in definitions.
Use the extension mechanism when appropriate, or coordinate a contract change
with the publisher. Keep compatibility checks intact. See `WEBSITE.md`.
