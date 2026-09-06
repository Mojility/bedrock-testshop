defmodule ShopWeb.LeadController do
  use ShopWeb, :controller

  def create(conn, %{"lead" => attrs}) when is_map(attrs) do
    with {:ok, scene} <- Shop.Website.read_scene(),
         {:ok, _} <- Shop.Website.render(scene) do
      if Shop.Leads.RateLimiter.allow?(conn.remote_ip) do
        case Shop.Leads.submit(attrs) do
          {:ok, _} ->
            redirect(conn, to: "/?sent=1#lead-sent")

          {:error, changeset} ->
            render_failure(conn, scene, 422, lead_form: Phoenix.Component.to_form(changeset))
        end
      else
        render_failure(conn, scene, 429,
          refused: true,
          lead_form:
            Phoenix.Component.to_form(Shop.Leads.Lead.changeset(%Shop.Leads.Lead{}, attrs))
        )
      end
    else
      _ ->
        conn
        |> put_status(503)
        |> text(
          "The enquiry form is temporarily unavailable. Please contact the business directly."
        )
    end
  end

  def create(conn, _), do: conn |> put_status(400) |> text("Please complete the enquiry form.")

  defp render_failure(conn, scene, status, opts) do
    case Shop.Website.render(
           scene,
           Keyword.put(opts, :csrf_token, Plug.CSRFProtection.get_csrf_token())
         ) do
      {:ok, html} -> conn |> put_status(status) |> html(html)
      _ -> conn |> put_status(503) |> text("The enquiry form is temporarily unavailable.")
    end
  end
end
