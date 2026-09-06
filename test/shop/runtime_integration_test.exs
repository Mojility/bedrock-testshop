defmodule Shop.RuntimeIntegrationTest do
  use ShopWeb.ConnCase, async: false

  test "runtime configuration refuses a non-Canadian AWS region" do
    old = System.get_env("AWS_REGION")

    on_exit(fn ->
      if old, do: System.put_env("AWS_REGION", old), else: System.delete_env("AWS_REGION")
    end)

    System.put_env("AWS_REGION", "us-east-1")

    assert_raise RuntimeError, "Customer infrastructure must use ca-central-1", fn ->
      Config.Reader.read!(Path.expand("../../config/runtime.exs", __DIR__), env: :test)
    end
  end

  test "untrusted forwarding headers do not change the client address" do
    conn = Plug.Test.conn(:get, "/") |> Plug.Conn.put_req_header("x-forwarded-for", "1.2.3.4")
    assert ShopWeb.Plugs.TrustedProxy.call(conn, []).remote_ip == conn.remote_ip
    old = Application.get_env(:shop, :trusted_proxy_ips, [])
    on_exit(fn -> Application.put_env(:shop, :trusted_proxy_ips, old) end)
    Application.put_env(:shop, :trusted_proxy_ips, ["127.0.0.1"])
    conn = Plug.Conn.put_req_header(conn, "x-forwarded-for", "9.9.9.9, 1.2.3.4")
    assert ShopWeb.Plugs.TrustedProxy.call(conn, []).remote_ip == {1, 2, 3, 4}
  end

  test "readiness checks the database", %{conn: conn} do
    assert json_response(get(conn, "/health/ready"), 200)["runtime_version"] == 1
  end

  test "credential expiry is checked and renewed files are read on the next call" do
    path = Path.join(System.tmp_dir!(), "runtime-creds-#{System.unique_integer([:positive])}")
    old = Application.get_env(:shop, :aws_credentials_file)

    on_exit(fn ->
      File.rm(path)
      Application.put_env(:shop, :aws_credentials_file, old)
    end)

    Application.put_env(:shop, :aws_credentials_file, path)
    assert {:error, :credentials_unavailable} = Shop.RuntimeCredentials.read()

    data = %{
      "AccessKeyId" => "synthetic",
      "SecretAccessKey" => "synthetic",
      "SessionToken" => "synthetic",
      "Expiration" => DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), -60))
    }

    File.write!(path, Jason.encode!(data))
    assert {:error, :credentials_unavailable} = Shop.RuntimeCredentials.read()

    File.write!(
      path,
      Jason.encode!(%{
        data
        | "Expiration" => DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), 3600))
      })
    )

    assert {:ok, values} = Shop.RuntimeCredentials.read()
    assert values[:region] == "ca-central-1"
  end
end
