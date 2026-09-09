# Customer web behavior

`website_html.ex` renders the scene tree supplied by `Shop.Website`. It is
editable source, not generated HTML. Scene expansion and component contracts
live in `lib/shop/website/`; business data and validation live in `lib/shop/`.
Changes to visitor behavior can also require the matching controller and staff
LiveView. Follow those references instead of searching published JSON for HTML
implementation. See `WEBSITE.md` for the authoring and publication boundary.
