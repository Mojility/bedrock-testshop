defmodule Shop.DisabledMailAdapter do
  @moduledoc "Non-delivering mail sink for isolated rehearsal. Never logs message contents."
  use Swoosh.Adapter, required_config: []
  def deliver(_email, _config), do: {:ok, %{id: "disabled"}}
end
