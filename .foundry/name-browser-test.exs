defmodule Business.NameBrowserTest do
  use BusinessWeb.ConnCase, async: false

  test "120-character names preserve browser title, keyboard journey and reflow in both themes" do
    original = Application.fetch_env!(:business, :business_name)
    name = String.duplicate("N", 120)
    Application.put_env(:business, :business_name, name)
    on_exit(fn -> Application.put_env(:business, :business_name, original) end)
    server = start_supervised!({Bandit, plug: BusinessWeb.Endpoint, ip: {127, 0, 0, 1}, port: 0})
    {:ok, {_address, port}} = ThousandIsland.listener_info(server)
    {output, status} = System.cmd("node", [".foundry/name-browser.cjs", "http://127.0.0.1:#{port}"], env: [{"NAME_EXPECTED", name}], stderr_to_stdout: true)
    IO.puts(output)
    assert status == 0
    assert Enum.sort(Enum.map(Business.Repo.all(Business.Leads.Lead), & &1.name)) == ["Browser enquiry dark", "Browser enquiry light"]
  end
end
