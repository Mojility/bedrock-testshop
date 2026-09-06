defmodule ShopWeb.PageController do
  use ShopWeb, :controller

  def home(conn, params) do
    case Shop.Website.read_scene() do
      {:ok, scene} ->
        case Shop.Website.render(scene,
               csrf_token: Plug.CSRFProtection.get_csrf_token(),
               sent: params["sent"] == "1"
             ) do
          {:ok, page} -> html(conn, page)
          {:error, _} -> conn |> put_status(503) |> text("Website release is incompatible")
        end

      {:error, :enoent} ->
        render(conn, :home)

      {:error, _} ->
        conn |> put_status(503) |> text("Website release is unavailable")
    end
  end
end
