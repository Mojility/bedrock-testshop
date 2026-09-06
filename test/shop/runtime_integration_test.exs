defmodule Shop.RuntimeIntegrationTest do
  use ShopWeb.ConnCase, async: false

  test "rehearsal mail cannot be re-enabled by a credentials file" do
    names = ~w(MAIL_ADAPTER AWS_CREDENTIALS_FILE DATABASE_URL SECRET_KEY_BASE)
    old = Map.new(names, &{&1, System.get_env(&1)})

    on_exit(fn ->
      Enum.each(old, fn {key, value} ->
        if value, do: System.put_env(key, value), else: System.delete_env(key)
      end)
    end)

    System.put_env("MAIL_ADAPTER", "disabled")
    System.put_env("AWS_CREDENTIALS_FILE", "/tmp/inert-rehearsal-file")
    System.put_env("DATABASE_URL", "ecto://synthetic:synthetic@localhost/synthetic")
    System.put_env("SECRET_KEY_BASE", String.duplicate("synthetic", 8))

    for env <- [:test, :prod] do
      config = Config.Reader.read!(Path.expand("../../config/runtime.exs", __DIR__), env: env)
      assert config[:shop][Shop.Mailer][:adapter] == Shop.DisabledMailAdapter
    end

    assert {:ok, _} = Shop.DisabledMailAdapter.deliver(Swoosh.Email.new(), [])
  end

  test "standalone proxy visitors use separate submission buckets" do
    old = Application.get_env(:shop, :trusted_proxy_ips, [])
    on_exit(fn -> Application.put_env(:shop, :trusted_proxy_ips, old) end)
    Application.put_env(:shop, :trusted_proxy_ips, ["127.0.0.1", "::1"])

    address = fn value ->
      Plug.Test.conn(:post, "/leads")
      |> Plug.Conn.put_req_header("x-forwarded-for", value)
      |> ShopWeb.Plugs.TrustedProxy.call([])
      |> Map.fetch!(:remote_ip)
    end

    one = address.("192.0.2.201")
    two = address.("192.0.2.202")

    Enum.each(1..Shop.Leads.RateLimiter.limit(), fn _ ->
      assert Shop.Leads.RateLimiter.allow?(one)
    end)

    refute Shop.Leads.RateLimiter.allow?(one)
    assert Shop.Leads.RateLimiter.allow?(two)
  end

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
