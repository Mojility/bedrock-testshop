defmodule ShopWeb.Plugs.TrustedProxy do
  @moduledoc "Accept Caddy's last forwarded address only from explicitly trusted peers."
  import Plug.Conn
  def init(opts), do: opts

  def call(conn, _) do
    peers = Application.get_env(:shop, :trusted_proxy_ips, [])
    peer = conn.remote_ip |> :inet.ntoa() |> to_string()

    if peer in peers do
      with [forwarded] <- get_req_header(conn, "x-forwarded-for"),
           ip <- forwarded |> String.split(",") |> List.last() |> String.trim(),
           {:ok, address} <- :inet.parse_address(to_charlist(ip)) do
        %{conn | remote_ip: address}
      else
        _ -> conn
      end
    else
      conn
    end
  end
end
