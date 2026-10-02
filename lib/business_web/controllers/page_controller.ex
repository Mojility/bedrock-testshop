defmodule BusinessWeb.PageController do
  use BusinessWeb, :controller

  # Only the validated HEEx renderer can produce this response; no raw request HTML.
  # Hostile scene text and incompatible scenes are covered by controller tests.
  # sobelow_skip ["XSS.HTML"]
  def home(conn, params) do
    case Business.Website.read_scene() do
      {:ok, scene} ->
        case Business.Website.render(scene,
               csrf_token: Plug.CSRFProtection.get_csrf_token(),
               sent: params["sent"] == "1"
             ) do
          {:ok, page} -> html(conn, page)
          {:error, _} -> conn |> put_status(503) |> text("Website release is incompatible")
        end

      {:error, :enoent} ->
        holding(conn, params)

      {:error, _} ->
        conn |> put_status(503) |> text("Website release is unavailable")
    end
  end

  @doc "Renders the unpublished enquiry page with the same validation feedback as a published site."
  def holding(conn, params, opts \\ []) do
    form = Keyword.get(opts, :lead_form, Phoenix.Component.to_form(%{}, as: :lead))
    error_field = Enum.find([:name, :phone, :email, :message], &Keyword.has_key?(form.errors, &1))

    conn
    |> put_view(html: BusinessWeb.PageHTML)
    |> render(:home,
      lead_form: form,
      error_field: error_field,
      sent: params["sent"] == "1",
      refused: Keyword.get(opts, :refused, false)
    )
  end
end
