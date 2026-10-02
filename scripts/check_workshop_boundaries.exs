# Execute inside the supplied committed Workshop snapshot.
ExUnit.start()

defmodule StarterWorkshopBoundaryTest do
  use ExUnit.Case, async: false
  alias WorkshopExecutive.{Identity, Journal, Runner, Source}

  setup do
    root = Path.join(System.tmp_dir!(), "starter-boundary-#{Identity.new()}")
    File.mkdir_p!(Path.join(root, "lib"))
    File.mkdir_p!(Path.join(root, "test"))
    File.write!(Path.join(root, "test/retained_test.exs"), "# retained regression\n")
    on_exit(fn -> File.rm_rf!(root) end)

    journal =
      start_supervised!(
        {Journal,
         journal_path: Path.join(root, "_build/journal.sqlite"),
         workshop_id: "synthetic-boundary",
         generation: 1,
         artifact_key: :crypto.strong_rand_bytes(32),
         name: nil}
      )

    binding = %{
      "source_root" => root,
      "database_id" => "synthetic-no-database",
      "region" => "ca-central-1",
      "generation" => 1,
      "toolchain" => System.version()
    }

    contract = %{"hash" => "synthetic-contract", "targets" => binding}
    run = %{"contract" => contract, "baseline" => %{"database" => binding["database_id"]}}
    baseline = Source.snapshot(root, run, binding)
    run = Map.put(run, "baseline_manifest", baseline["manifest"])

    job = %{
      "id" => "boundary",
      "run_id" => "synthetic-boundary",
      "contract_hash" => contract["hash"],
      "run" => run,
      "candidate" => baseline
    }

    %{root: root, job: job, options: [binding: binding, generation: 1, journal: journal]}
  end

  test "real source gate rejects platform calls and accepts explanatory prose", context do
    page = Path.join(context.root, "lib/blueprints.html.heex")
    File.write!(page, "{Bedrock.Sites.name()}")

    assert {:ok, %{"status" => "failed", "files" => ["lib/blueprints.html.heex"]}, _} =
             Runner.check("source_separation", context.job, context.options)

    File.write!(page, "Versioned snapshot; no Bedrock runtime calls.")

    assert {:ok, %{"status" => "passed", "files" => []}, _} =
             Runner.check("source_separation", context.job, context.options)
  end

  test "real integrity gate rejects a removed retained test", context do
    test = Path.join(context.root, "test/retained_test.exs")
    File.rm!(test)
    candidate = Source.snapshot(context.root, context.job["run"], context.options[:binding])
    job = Map.put(context.job, "candidate", candidate)

    assert {:ok, %{"status" => "failed", "removed_tests" => ["test/retained_test.exs"]}, _} =
             Runner.check("test_integrity", job, context.options)

    File.write!(test, "# retained regression\n")

    assert {:ok, %{"status" => "passed", "removed_tests" => []}, _} =
             Runner.check("test_integrity", context.job, context.options)
  end
end
