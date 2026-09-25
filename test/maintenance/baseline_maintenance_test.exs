defmodule BaselineMaintenanceTest do
  use ExUnit.Case, async: true

  @fixtures Path.expand("../fixtures/maintenance", __DIR__)
  @script Path.expand("../../scripts/maintenance/apply_baseline.exs", __DIR__)

  @daisyui "// daisyUI 5.7.46 release bundle\n"
  @daisyui_sha256 :crypto.hash(:sha256, @daisyui) |> Base.encode16(case: :lower)

  defp baseline(overrides \\ %{}) do
    Map.merge(
      %{
        "version" => 1,
        "template_commit" => String.duplicate("a1", 20),
        "tool_versions" => %{
          "elixir" => "1.20.2-otp-29",
          "erlang" => "29.0.2",
          "postgres" => "18"
        },
        "debian" => "trixie-20260623-slim",
        "requirements" => %{
          "phoenix" => "~> 1.8",
          "phoenix_live_view" => "~> 1.2",
          "esbuild" => "~> 0.10",
          "gettext" => "~> 1.0"
        },
        "asset_tools" => %{"tailwind" => "4.3.3", "esbuild" => "0.28.2"},
        "vendored" => [
          %{
            "path" => "assets/vendor/daisyui.js",
            "url" => "https://github.com/saadeghi/daisyui/releases/download/v5.7.46/daisyui.js",
            "sha256" => @daisyui_sha256
          },
          %{
            "path" => "assets/vendor/not-in-this-shop.js",
            "url" => "https://github.com/example/tool/releases/download/v1.0.0/tool.js",
            "sha256" => String.duplicate("0", 64)
          }
        ]
      },
      overrides
    )
  end

  defp fetch_daisyui(url) do
    send(self(), {:fetched, url})
    {:ok, @daisyui}
  end

  defp tenant(tmp_dir) do
    File.mkdir_p!(Path.join(tmp_dir, "config"))
    File.mkdir_p!(Path.join(tmp_dir, "assets/vendor"))

    for {fixture, target} <- [
          {"mix.exs.fixture", "mix.exs"},
          {"config.exs.fixture", "config/config.exs"},
          {"Dockerfile.fixture", "Dockerfile"},
          {"tool-versions.fixture", ".tool-versions"}
        ] do
      File.cp!(Path.join(@fixtures, fixture), Path.join(tmp_dir, target))
    end

    File.write!(Path.join(tmp_dir, "assets/vendor/daisyui.js"), "// daisyUI 5.0.0\n")
    tmp_dir
  end

  defp read(root, path), do: File.read!(Path.join(root, path))

  describe "parse_baseline/1" do
    test "accepts a version 1 baseline" do
      assert {:ok, %{"version" => 1}} =
               baseline() |> JSON.encode!() |> BaselineMaintenance.parse_baseline()
    end

    test "rejects documents that are not a version 1 baseline" do
      invalid = [
        "not json",
        "[1]",
        JSON.encode!(baseline(%{"version" => 2})),
        JSON.encode!(Map.delete(baseline(), "tool_versions")),
        JSON.encode!(baseline(%{"template_commit" => "main"})),
        JSON.encode!(baseline(%{"requirements" => %{"phoenix" => "latest please"}})),
        JSON.encode!(baseline(%{"requirements" => %{"Bad Name" => "~> 1.0"}})),
        JSON.encode!(baseline(%{"asset_tools" => %{"tailwind" => "latest"}})),
        JSON.encode!(baseline(%{"debian" => "trixie; rm -rf /"})),
        String.duplicate(" ", 60_000)
      ]

      for json <- invalid do
        assert {:error, _reason} = BaselineMaintenance.parse_baseline(json), json
      end
    end

    test "rejects an Elixir build for a different OTP major than Erlang" do
      tools = %{"elixir" => "1.20.2-otp-28", "erlang" => "29.0.2", "postgres" => "18"}

      assert {:error, message} =
               baseline(%{"tool_versions" => tools})
               |> JSON.encode!()
               |> BaselineMaintenance.parse_baseline()

      assert message =~ "OTP major"
    end

    test "only allows GitHub release downloads into the repository" do
      entry = hd(baseline()["vendored"])

      unsafe = [
        %{entry | "url" => "https://example.com/daisyui.js"},
        %{entry | "url" => "http://github.com/saadeghi/daisyui/releases/download/v5/daisyui.js"},
        %{entry | "path" => "../outside.js"},
        %{entry | "path" => "/etc/passwd"},
        %{entry | "path" => ".github/workflows/build.yml"},
        %{entry | "sha256" => "not-a-digest"}
      ]

      for vendored <- unsafe do
        assert {:error, _reason} =
                 baseline(%{"vendored" => [vendored]})
                 |> JSON.encode!()
                 |> BaselineMaintenance.parse_baseline()
      end
    end
  end

  describe "apply_baseline/3" do
    @describetag :tmp_dir

    test "sets baseline requirements and keeps each dependency's options", %{tmp_dir: tmp_dir} do
      root = tenant(tmp_dir)

      assert {:ok, changes} =
               BaselineMaintenance.apply_baseline(root, baseline(), &fetch_daisyui/1)

      mix_exs = read(root, "mix.exs")
      assert mix_exs =~ ~s|{:phoenix, "~> 1.8"},|
      assert mix_exs =~ ~s|{:phoenix_live_view, "~> 1.2", override: true},|
      assert mix_exs =~ ~s|{:esbuild, "~> 0.10", runtime: Mix.env() == :dev},|
      assert mix_exs =~ "# Only in this shop; not part of the baseline."

      assert changes["requirements"]["phoenix"] == ["~> 1.8.0", "~> 1.8"]
      assert changes["requirements"]["phoenix_live_view"] == ["~> 1.1.0", "~> 1.2"]
    end

    test "loosens patch-level pins the baseline does not cover", %{tmp_dir: tmp_dir} do
      root = tenant(tmp_dir)

      assert {:ok, changes} =
               BaselineMaintenance.apply_baseline(root, baseline(), &fetch_daisyui/1)

      mix_exs = read(root, "mix.exs")
      assert mix_exs =~ ~s|{:nimble_csv, "~> 1.2", only: [:dev, :test], runtime: false},|
      assert mix_exs =~ ~s|{:decimal, "~> 2.1"},|
      assert changes["requirements"]["nimble_csv"] == ["~> 1.2.3", "~> 1.2"]
      refute Map.has_key?(changes["requirements"], "decimal")
    end

    test "never adds or removes dependencies", %{tmp_dir: tmp_dir} do
      root = tenant(tmp_dir)
      before = read(root, "mix.exs")

      assert {:ok, changes} =
               BaselineMaintenance.apply_baseline(root, baseline(), &fetch_daisyui/1)

      refute read(root, "mix.exs") =~ "gettext"
      refute Map.has_key?(changes["requirements"], "gettext")
      assert line_count(read(root, "mix.exs")) == line_count(before)
      assert read(root, "mix.exs") =~ ~s|github: "tailwindlabs/heroicons", tag: "v2.2.0"|
      assert read(root, "mix.exs") =~ ~s|{:local_tool, path: "../local_tool"}|
    end

    test "aligns .tool-versions and the Dockerfile with the baseline toolchain", %{
      tmp_dir: tmp_dir
    } do
      root = tenant(tmp_dir)

      assert {:ok, changes} =
               BaselineMaintenance.apply_baseline(root, baseline(), &fetch_daisyui/1)

      assert read(root, ".tool-versions") ==
               "# toolchain\nelixir 1.20.2-otp-29\nerlang 29.0.2\nnodejs 22.1.0\npostgres 18\n"

      dockerfile = read(root, "Dockerfile")
      assert dockerfile =~ "ARG ELIXIR_VERSION=1.20.2\n"
      assert dockerfile =~ "ARG OTP_VERSION=29.0.2\n"
      assert dockerfile =~ "ARG DEBIAN_VERSION=trixie-20260623-slim\n"
      assert dockerfile =~ "${ELIXIR_VERSION}-erlang-${OTP_VERSION}"

      assert changes["tool_versions"] == %{
               "elixir" => ["1.19.0-otp-28", "1.20.2-otp-29"],
               "erlang" => ["28.1", "29.0.2"],
               "postgres" => [nil, "18"]
             }

      assert changes["debian"] == ["bookworm-20250101-slim", "trixie-20260623-slim"]

      assert BaselineMaintenance.toolchain_mismatches(read(root, ".tool-versions"), dockerfile) ==
               []
    end

    test "updates asset tool versions in config.exs", %{tmp_dir: tmp_dir} do
      root = tenant(tmp_dir)

      assert {:ok, changes} =
               BaselineMaintenance.apply_baseline(root, baseline(), &fetch_daisyui/1)

      config = read(root, "config/config.exs")
      assert config =~ ~s|config :esbuild,\n  version: "0.28.2",|
      assert config =~ ~s|config :tailwind,\n  version: "4.3.3",|
      assert config =~ ~s|config :shop, :shop_name, "Fixture"|

      assert changes["asset_tools"] == %{
               "esbuild" => ["0.25.4", "0.28.2"],
               "tailwind" => ["4.1.7", "4.3.3"]
             }
    end

    test "replaces vendored files the shop already has, and only those", %{tmp_dir: tmp_dir} do
      root = tenant(tmp_dir)

      assert {:ok, changes} =
               BaselineMaintenance.apply_baseline(root, baseline(), &fetch_daisyui/1)

      assert read(root, "assets/vendor/daisyui.js") == @daisyui
      refute File.exists?(Path.join(root, "assets/vendor/not-in-this-shop.js"))
      assert changes["vendored"] == ["assets/vendor/daisyui.js"]

      assert_received {:fetched,
                       "https://github.com/saadeghi/daisyui/releases/download/v5.7.46/daisyui.js"}

      refute_received {:fetched, _other}
    end

    test "refuses a download that does not match its digest and writes nothing", %{
      tmp_dir: tmp_dir
    } do
      root = tenant(tmp_dir)
      before = for path <- ["mix.exs", "Dockerfile", ".tool-versions"], do: read(root, path)
      tampered = fn _url -> {:ok, "// not the release\n"} end

      assert {:error, reason} = BaselineMaintenance.apply_baseline(root, baseline(), tampered)

      assert reason =~ "does not match its sha256"
      assert read(root, "assets/vendor/daisyui.js") == "// daisyUI 5.0.0\n"

      assert before ==
               for(path <- ["mix.exs", "Dockerfile", ".tool-versions"], do: read(root, path))
    end

    test "reports no changes when the repository is already current", %{tmp_dir: tmp_dir} do
      root = tenant(tmp_dir)

      assert {:ok, _changes} =
               BaselineMaintenance.apply_baseline(root, baseline(), &fetch_daisyui/1)

      assert_received {:fetched, _url}

      assert {:ok, changes} =
               BaselineMaintenance.apply_baseline(root, baseline(), &fetch_daisyui/1)

      assert changes == %{
               "tool_versions" => %{},
               "requirements" => %{},
               "asset_tools" => %{},
               "vendored" => []
             }

      refute_received {:fetched, _url}
    end

    test "creates .tool-versions for a repository that has none", %{tmp_dir: tmp_dir} do
      root = tenant(tmp_dir)
      File.rm!(Path.join(root, ".tool-versions"))

      assert {:ok, _changes} =
               BaselineMaintenance.apply_baseline(root, baseline(), &fetch_daisyui/1)

      assert read(root, ".tool-versions") == "elixir 1.20.2-otp-29\nerlang 29.0.2\npostgres 18\n"
    end

    test "refuses a mix.exs whose deps/0 is not a list literal", %{tmp_dir: tmp_dir} do
      root = tenant(tmp_dir)

      File.write!(
        Path.join(root, "mix.exs"),
        "defmodule X do\n  defp deps, do: base() ++ extra()\nend\n"
      )

      assert {:error, reason} =
               BaselineMaintenance.apply_baseline(root, baseline(), &fetch_daisyui/1)

      assert reason =~ "deps/0"
    end
  end

  describe "loosen_patch_requirement/1" do
    test "drops the patch component of a pessimistic three-part requirement" do
      assert BaselineMaintenance.loosen_patch_requirement("~> 0.8.3") == "~> 0.8"
      assert BaselineMaintenance.loosen_patch_requirement("~> 1.2") == "~> 1.2"
      assert BaselineMaintenance.loosen_patch_requirement(">= 0.0.0") == ">= 0.0.0"
      assert BaselineMaintenance.loosen_patch_requirement("~> 1.0.0-rc.1") == "~> 1.0.0-rc.1"
    end
  end

  describe "lock and outdated reports" do
    test "pairs locked versions before and after an update" do
      before =
        BaselineMaintenance.lock_versions(
          File.read!(Path.join(@fixtures, "mix.lock.before.fixture"))
        )

      later =
        BaselineMaintenance.lock_versions(
          File.read!(Path.join(@fixtures, "mix.lock.after.fixture"))
        )

      assert BaselineMaintenance.diff_versions(before, later) == %{
               "phoenix" => ["1.8.1", "1.8.14"],
               "phoenix_live_view" => ["1.1.33", "1.2.12"],
               "lazy_html" => [nil, "0.1.13"],
               "retired" => ["0.1.0", nil]
             }

      assert before["heroicons"] == "0435d4c"
    end

    test "lists updates blocked by requirements the baseline does not cover" do
      outdated = File.read!(Path.join(@fixtures, "hex_outdated.fixture"))
      mix_exs = File.read!(Path.join(@fixtures, "mix.exs.fixture"))

      assert BaselineMaintenance.blocked_requirements(
               outdated,
               mix_exs,
               baseline()["requirements"]
             ) == [
               %{
                 "name" => "decimal",
                 "current" => "2.1.1",
                 "latest" => "3.0.0",
                 "requirement" => "~> 2.1"
               }
             ]
    end

    test "summarises changes as a commit message" do
      message =
        BaselineMaintenance.commit_message("0b7d4c1e-8f7a-4e2b-9a55-6c1d2e3f4a5b", %{
          "tool_versions" => %{"elixir" => ["1.19.0-otp-28", "1.20.2-otp-29"]},
          "debian" => ["bookworm-20250101-slim", "trixie-20260623-slim"],
          "requirements" => %{},
          "dependencies" => %{"phoenix" => ["1.8.1", "1.8.14"]},
          "vendored" => ["assets/vendor/daisyui.js"]
        })

      assert message =~ "Routine maintenance 0b7d4c1e-8f7a-4e2b-9a55-6c1d2e3f4a5b\n"
      assert message =~ "- elixir: 1.19.0-otp-28 -> 1.20.2-otp-29"
      assert message =~ "- debian: bookworm-20250101-slim -> trixie-20260623-slim"
      assert message =~ "- phoenix: 1.8.1 -> 1.8.14"
      assert message =~ "Vendored assets:\n- assets/vendor/daisyui.js"
      refute message =~ "Requirements:"
    end
  end

  describe "quality_gates/1" do
    test "expands nested aliases and keeps commands with arguments" do
      aliases = [
        test: ["ecto.create --quiet", "test"],
        quality: ["quality.security", "format --check-formatted", "test --cover", "quality"],
        "quality.security": ["hex.audit", "deps.audit"]
      ]

      assert BaselineMaintenance.quality_gates(aliases) ==
               ["hex.audit", "deps.audit", "format --check-formatted", "test --cover", "quality"]
    end

    test "matches this repository's quality alias" do
      gates = BaselineMaintenance.quality_gates(Mix.Project.config()[:aliases])

      assert "hex.audit" in gates
      assert "test --cover" in gates
      refute "quality.security" in gates
    end
  end

  describe "toolchain_mismatches/2" do
    test "reports Dockerfile defaults that drift from .tool-versions" do
      tools = "elixir 1.20.2-otp-29\nerlang 29.0.2\npostgres 18\n"
      dockerfile = File.read!(Path.join(@fixtures, "Dockerfile.fixture"))

      assert [elixir, otp] = BaselineMaintenance.toolchain_mismatches(tools, dockerfile)
      assert elixir =~ "ELIXIR_VERSION=1.19.0"
      assert otp =~ "OTP_VERSION=28.1"
    end

    test "reports a missing tool and an Elixir build for another OTP" do
      dockerfile = "ARG ELIXIR_VERSION=1.20.2\nARG OTP_VERSION=29.0.2\n"

      assert [missing, otp] =
               BaselineMaintenance.toolchain_mismatches(
                 "elixir 1.20.2-otp-28\nerlang 29.0.2\n",
                 dockerfile
               )

      assert missing =~ "no postgres line"
      assert otp =~ "not built for erlang 29.0.2"
    end
  end

  describe "command line" do
    @describetag :tmp_dir

    test "exits 2 for an invalid baseline", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "baseline.json")
      File.write!(path, JSON.encode!(baseline(%{"version" => 2})))

      assert {2, "invalid baseline: version must be 1"} =
               BaselineMaintenance.run(["apply", "--baseline", path, "--root", tmp_dir])
    end

    test "exits 1 when the baseline cannot be applied safely", %{tmp_dir: tmp_dir} do
      root = tenant(tmp_dir)
      path = Path.join(tmp_dir, "baseline.json")
      File.write!(path, JSON.encode!(baseline()))

      assert {1, reason} =
               BaselineMaintenance.run(["apply", "--baseline", path, "--root", root], fn _url ->
                 {:error, :nxdomain}
               end)

      assert reason =~ "could not download"
    end

    test "prints usage for an unknown command" do
      assert {2, usage} = BaselineMaintenance.run(["frobnicate"])
      assert usage =~ "usage:"
    end

    test "runs with plain elixir and prints the changes as JSON", %{tmp_dir: tmp_dir} do
      root = tenant(tmp_dir)
      File.rm!(Path.join(root, "assets/vendor/daisyui.js"))
      path = Path.join(tmp_dir, "baseline.json")
      File.write!(path, JSON.encode!(baseline()))

      assert {output, 0} =
               System.cmd("elixir", [@script, "apply", "--baseline", path, "--root", root])

      assert %{"requirements" => %{"phoenix" => ["~> 1.8.0", "~> 1.8"]}} = JSON.decode!(output)

      assert {_output, 0} = System.cmd("elixir", [@script, "check-toolchain", "--root", root])
    end
  end

  defp line_count(text), do: text |> String.split("\n") |> length()
end
