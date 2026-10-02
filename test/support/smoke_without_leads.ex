defmodule Business.SmokeWithoutLeads do
  @moduledoc false
  @behaviour Plug

  @impl true
  def init(options), do: options

  @impl true
  def call(conn, _options), do: Plug.Conn.send_resp(conn, 200, "A page without enquiries")
end
