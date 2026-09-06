defmodule ShopWeb.HealthController do
  use ShopWeb, :controller

  alias Ecto.Adapters.SQL

  def ready(conn, _) do
    case SQL.query(Shop.Repo, "SELECT 1", []) do
      {:ok, _} -> json(conn, %{status: "ready", runtime_version: 1})
      _ -> conn |> put_status(503) |> json(%{status: "unavailable"})
    end
  rescue
    _ -> conn |> put_status(503) |> json(%{status: "unavailable"})
  end
end
