defmodule Shop do
  @moduledoc """
  Shop keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  The name of the shop this system belongs to, from `config :shop, :shop_name`.
  """
  @spec name() :: String.t()
  def name, do: Application.fetch_env!(:shop, :shop_name)
end
