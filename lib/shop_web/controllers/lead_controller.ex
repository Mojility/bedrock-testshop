defmodule ShopWeb.LeadController do
  use ShopWeb, :controller

  alias Phoenix.Component
  alias Shop.Leads
  alias Shop.Leads.Lead
  alias Shop.Leads.RateLimiter
  alias Shop.Website

  def create(conn, %{"lead" => attrs}) when is_map(attrs) do
    with {:ok, scene} <- Website.read_scene(),
         {:ok, _} <- Website.render(scene) do
      accept_submission(conn, scene, attrs)
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

  defp accept_submission(conn, scene, attrs) do
    if RateLimiter.allow?(conn.remote_ip) do
      case Leads.submit(attrs) do
        {:ok, _} ->
          redirect(conn, to: "/?sent=1#lead-sent")

        {:error, changeset} ->
          render_failure(conn, scene, 422, lead_form: Component.to_form(changeset))
      end
    else
      render_failure(conn, scene, 429,
        refused: true,
        lead_form: Component.to_form(Lead.changeset(%Lead{}, attrs))
      )
    end
  end

  # Website.render validates the component model and escapes all dynamic text via HEEx.
  # Security regression tests exercise hostile text and invalid scene structures.
  # sobelow_skip ["XSS.HTML"]
  defp render_failure(conn, scene, status, opts) do
    case Website.render(
           scene,
           Keyword.put(opts, :csrf_token, Plug.CSRFProtection.get_csrf_token())
         ) do
      {:ok, html} -> conn |> put_status(status) |> html(html)
      _ -> conn |> put_status(503) |> text("The enquiry form is temporarily unavailable.")
    end
  end
end
