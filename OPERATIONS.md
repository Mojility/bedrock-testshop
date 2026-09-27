# Staff operations design

Authenticated staff workflows use a shared, customer-owned component hierarchy while the public website continues to use its existing scene renderer and theme.

- `ShopWeb.CoreComponents` provides controls and validation feedback.
- `ShopWeb.Operations` provides page headers, panels, statuses, empty states, form actions, and labelled facts.
- `ShopWeb.Layouts.app` and `ShopWeb.StaffNavigation` provide the responsive staff shell and role-aware navigation registry.
- Staff LiveViews own interaction state and call authorized business contexts; components do not contain business rules or authorization.

Staff pages pass `current_scope` and a matching `current_section` to `Layouts.app`, then compose their content from the shared operations components. Routes and context operations continue to enforce permissions independently of navigation visibility. Forms retain their existing validation and business behavior, use labelled fields, and provide clear progress and result feedback.

The sales pipeline and lead detail pages are the first adopted workspace. Public website files, published scenes, and customer-facing rendering are outside this design layer and remain unchanged.
