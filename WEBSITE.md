# Customer-owned website

The website is rendered by this application from a versioned scene. It runs
without Bedrock or Roost. The repository owns the renderer, component model,
and native component code. A publication changes
`priv/published_site/scene.json`,
the media manifest, and public assets; it does not replace application source.

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
