# Customer-owned website

The website is rendered by this application from a versioned scene. It runs
without Bedrock or Roost. The repository owns the renderer, component model,
and native component code. A publication changes
`priv/published_site/scene.json`,
the media manifest, and public assets; it does not replace application source.

## Source map

The authoring document and the published scene are different revisions of data.
Bedrock edits the tenant's design document, freezes it for publication, and
exports the runtime scene. This repository owns the published revision and its
consumer; it does not contain that editor's live authoring database.

| Change or file | Editable authority | How it reaches the website |
| --- | --- | --- |
| Composition, design facts and theme | Bedrock design document | Publish a validated design |
| `priv/published_site/scene.json` | Published output of that document and theme | `Shop.Website.read_scene/0` reads it |
| `priv/published_site/media.json` | Ready photograph metadata in the publisher | Publication exports the referenced variants |
| `priv/static/assets/published/` | Publisher CSS and font sources | Publication copies CSS/fonts and rewrites font URLs |
| `priv/website/components.json` | Customer extension declarations | Commit, refresh the editor's component model, then publish |
| `lib/shop/website/` | Customer definitions, expansion and public-content code | Application build and release |
| `lib/shop_web/website_html.ex` | Customer HTML renderer | Application build and release |
| `test/fixtures/website_scene.json` | Deliberate test scenario | Tests consume it; publication does not update it |

The producer is `Bedrock.Publishing.Export.files/1`. Publishing updates only its
exported files and publication metadata. It does not replace the customer
renderer, native component implementations or business records. There is no
local Mix task that reconstructs an editor draft from the published scene.

Trace the requested behavior to its editable source before working on a compact
file. A scene may show which components are selected, but its HTML is produced
by scene expansion and the renderer. Changing the published scene does not
change those implementations and will be overwritten by a later publication.

## Extending the model

Add declarations to `priv/website/components.json`. Version 1 contains a
`components` array. Each entry has a unique new `name`, a `level` (atom,
molecule, layout, or organism), a `props` schema, accepted `children` levels,
and a declarative `template`. Built-in names cannot be shadowed through JSON.

For example, a reusable announcement:

```json
{
  "version": 1,
  "components": [{
    "name": "shop_notice",
    "level": "organism",
    "purpose": "A public announcement",
    "props": {"message": {"type": "string", "required": true}},
    "template": {
      "type": "container",
      "children": [{
        "type": "text",
        "props": {"content": {"$expr": ["prop", "message"]}}
      }]
    }
  }]
}
```

`$expr` encodes the existing template operations: `prop`, `item`, `index`,
`concat`, `case`, `each`, `if`, and `children`. No expression evaluates Elixir,
loads a module, or executes a query. Recursive definitions are rejected.

For application-backed behavior, add `"native": true` to the declaration and
register an explicit function in `Shop.Website.Components.native/0`, for example
`%{"shop_notice" => &ShopWeb.ShopNotice.render/1}`. Its Phoenix assigns include
`node` (ID, props, children) and `state.content`. Use normal escaped HEEx
output.
The declared template supports structural checks. A native registration is
required for rendering and preview; no static substitute is silently served.

## Application content

`Shop.Website.Content.load/0` runs for each page request. Return a map of public
content for native components, using this application's own contexts and
queries. A change to a service, project, or announcement can then update the
website without modifying the scene. Do not return private records or secrets.
Publishing does not mutate this content or replace the function.

The repository is the authority for published scene revisions. If a future
feature stores editable designs in the database, add explicit revision and
conflict handling before allowing both sources to modify the same design.

## Compatibility and preview

The scene pins the component-model hash. Refresh component definitions in the
Bedrock editor before publishing a scene using new types. Incompatible models,
missing native registrations, and unsupported scene versions fail explicitly.

The hash includes both built-in registry definitions and customer extension
entries. Importing `components.json` refreshes extensions only. A change to the
customer's built-in registry therefore needs a coordinated publisher contract
change; it cannot be fixed by refreshing extensions or replacing the scene hash.
A rendering implementation change does not necessarily require a contract change.
Keep the contract stable unless the requested capability actually changes it.

`POST /api/website/preview` renders through the same code as the public page.
It requires a bearer credential from `WEBSITE_PREVIEW_SECRET` (at least 32
bytes).
This credential is separate from customer login and belongs in runtime secret
configuration. Bedrock uses `WEBSITE_PREVIEW_SECRETS`, a JSON map from tenant ID
to its corresponding credential, and the mapped customer application's HTTPS
address. Neither credential belongs in this repository or the scene.

Authenticated previews produce signed, 15-minute links for draft photographs,
including photographs absent from the published manifest. Unsigned unpublished
variants remain inaccessible. The preview has no browser session and does not
persist changes. Bedrock embeds
its result in a sandboxed frame. The public homepage generates a fresh CSRF
token per request. The runtime exposes no scene-writing HTTP endpoint.

Lead capture and the authenticated business workspace are part of this
application; see `BUSINESS.md`. Before deployment, qualify owner provisioning,
mail delivery, trusted proxy address resolution, private-media serving, and
the trusted build/rehearsal checks.
