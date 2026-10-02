defmodule BusinessWeb.LeadController do
  use BusinessWeb, :controller

  alias Business.Leads
  alias Business.Leads.Lead
  alias Business.Leads.RateLimiter
  alias Business.Website
  alias Phoenix.Component

  def create(conn, %{"lead" => attrs}) when is_map(attrs) do
    case Website.read_scene() do
      {:ok, scene} ->
        case Website.render(scene) do
          {:ok, _} -> accept_submission(conn, scene, attrs)
          _ -> unavailable(conn)
        end

      {:error, :enoent} ->
        accept_submission(conn, nil, attrs)

      _ ->
        unavailable(conn)
    end
  end

  def create(conn, _), do: conn |> put_status(400) |> text("Please complete the enquiry form.")

  defp unavailable(conn) do
    conn
    |> put_status(503)
    |> text("The enquiry form is temporarily unavailable. Please contact the business directly.")
  end

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

  defp render_failure(conn, nil, status, opts) do
    conn
    |> put_status(status)
    |> BusinessWeb.PageController.holding(%{}, opts)
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
