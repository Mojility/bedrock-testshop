# Credo's defaults, plus the standalone maintenance script, which runs with
# plain `elixir` and so lives outside lib/.
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "src/", "test/", "web/", "scripts/maintenance/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      }
    }
  ]
}
