defmodule Business do
  @moduledoc """
  Business keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  The name of the business this system belongs to, loaded at startup.

  `BUSINESS_NAME` takes precedence over `SHOP_NAME`, then the JSON string `name`
  in `priv/business.json`, then `config :business, :business_name`. The last
  fallback preserves systems generated with a baked-in name and no data file.
  Names are data; consumers must escape them for their output format.
  """
  @spec name() :: String.t()
  def name, do: Application.fetch_env!(:business, :business_name)
end
