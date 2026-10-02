defmodule BuildWorkflowTest do
  @moduledoc """
  Exercises the authored job conditions against GitHub event and dependency
  results. This is a local workflow contract, not GitHub execution evidence.
  """
  use ExUnit.Case, async: true

  @workflow System.get_env("BUILD_WORKFLOW_PATH") ||
              Path.expand("../../.github/workflows/build.yml", __DIR__)
  @starter "Mojility/bedrock-system-template"
  @customer "Mojility/synthetic-electrical-service"
  @results ~w(success failure cancelled skipped)
  @events ~w(push workflow_dispatch pull_request schedule)
  @producer System.get_env("INTEGRATION_PRODUCER_PATH") ||
              Path.expand("../fixtures/integration-producer.yml", __DIR__)
  # Bedrock 78767528c45c0d9412c4cbc90d395c724ed1c5ee, unchanged workflow bytes.
  @producer_sha256 "da1dac5fe25a61dbd0096f988269c58ab36d71458f7afb02f16258e34d8b4a06"

  setup do
    workflow = YamlElixir.read_from_file!(@workflow)
    %{jobs: workflow["jobs"], workflow: workflow}
  end

  test "the caller grants every effective permission requested by the committed producer", %{
    workflow: workflow
  } do
    assert Base.encode16(:crypto.hash(:sha256, File.read!(@producer)), case: :lower) ==
             @producer_sha256

    producer = YamlElixir.read_from_file!(@producer)
    assert producer["jobs"]["bedrock-image"]["permissions"]["id-token"] == "write"
    assert permission_gaps(workflow, producer) == []

    # Preserved cycle 7 inherited contents: read, leaving id-token at none.
    preserved = update_in(workflow, ["jobs", "integration"], &Map.delete(&1, "permissions"))
    assert {"bedrock-image", "id-token", "write", "none"} in permission_gaps(preserved, producer)

    # A job-level declaration replaces workflow defaults, rather than merging.
    incomplete =
      put_in(workflow, ["jobs", "integration", "permissions"], %{"id-token" => "write"})

    assert {"resolve", "contents", "read", "none"} in permission_gaps(incomplete, producer)
    assert workflow["permissions"] == %{"contents" => "read"}
  end

  test "trusted starter publication events call the committed integration producer", %{jobs: jobs} do
    integration = jobs["integration"]
    assert is_map(integration), "the starter must call platform integration"
    assert integration["uses"] == "Mojility/bedrock/.github/workflows/integration.yml@main"
    assert integration["secrets"] == "inherit"
    refute Map.has_key?(integration, "continue-on-error")

    for repository <- [@starter, @customer], event <- @events do
      expected = repository == @starter and event in ~w(push workflow_dispatch)
      assert runs?(integration, context(repository, event)) == expected
    end
  end

  test "publication depends on quality, release acceptance and integration", %{jobs: jobs} do
    assert gated?(jobs)
  end

  test "integration failure blocks starter publication and skipped integration permits customer CI",
       %{jobs: jobs} do
    for repository <- [@starter, @customer],
        event <- @events,
        quality <- @results,
        release <- @results,
        integration <- @results,
        cancelled <- [false, true] do
      results = %{
        "needs.quality.result" => quality,
        "needs.release_acceptance.result" => release,
        "needs.integration.result" => integration,
        "cancelled" => cancelled
      }

      expected =
        not cancelled and event in ~w(push workflow_dispatch) and
          quality == "success" and release == "success" and
          integration == if(repository == @starter, do: "success", else: "skipped")

      assert runs?(jobs["build-and-push"], Map.merge(context(repository, event), results)) ==
               expected,
             inspect({repository, event, results})
    end
  end

  test "the previous missing integration dependency permits a broken starter to publish", %{
    jobs: jobs
  } do
    # These are the publication graph and condition in starter a5912b119a61.
    previous =
      jobs
      |> Map.delete("integration")
      |> put_in(["build-and-push", "needs"], ["quality", "release-acceptance"])
      |> put_in(
        ["build-and-push", "if"],
        "github.event_name == 'push' || github.event_name == 'workflow_dispatch'"
      )

    refute gated?(previous)
    failed_integration = context(@starter, "push")
    assert runs?(previous["build-and-push"], failed_integration)
    refute runs?(jobs["build-and-push"], failed_integration)
  end

  test "customer repositories require no platform source keys or platform jobs", %{jobs: jobs} do
    refute runs?(jobs["integration"], context(@customer, "push"))

    for {name, job} <- Map.delete(jobs, "integration") do
      refute Map.has_key?(job, "secrets"), name
      refute Map.has_key?(job, "uses"), name
      refute inspect(job) =~ "SOURCE_KEY", name
    end

    successful_customer =
      context(@customer, "push") |> Map.put("needs.integration.result", "skipped")

    assert runs?(jobs["build-and-push"], successful_customer)
  end

  defp permission_gaps(caller, producer) do
    granted = effective_permissions(caller, caller["jobs"]["integration"])
    levels = %{"none" => 0, "read" => 1, "write" => 2}

    for {name, job} <- producer["jobs"],
        {scope, required} <- effective_permissions(producer, job),
        available = Map.get(granted, scope, "none"),
        Map.fetch!(levels, required) > Map.fetch!(levels, available) do
      {name, scope, required, available}
    end
  end

  defp effective_permissions(workflow, job) do
    Map.get(job, "permissions", Map.fetch!(workflow, "permissions"))
  end

  defp gated?(jobs) do
    integration = jobs["integration"] || %{}
    publication = jobs["build-and-push"]

    integration["uses"] == "Mojility/bedrock/.github/workflows/integration.yml@main" and
      integration["secrets"] == "inherit" and
      Enum.all?(~w(quality release-acceptance integration), &(&1 in publication["needs"]))
  end

  defp context(repository, event) do
    %{
      "github.repository" => repository,
      "github.event_name" => event,
      "needs.quality.result" => "success",
      "needs.release_acceptance.result" => "success",
      "needs.integration.result" => "failure",
      "cancelled" => false
    }
  end

  defp runs?(nil, _context), do: false

  defp runs?(job, context) do
    job["if"]
    |> String.trim()
    |> String.trim_leading("${{")
    |> String.trim_trailing("}}")
    |> String.replace("release-acceptance", "release_acceptance")
    |> String.replace(~r/'([^']*)'/, "\"\\1\"")
    |> Code.string_to_quoted!()
    |> evaluate(context)
  end

  # Interpret only condition operators and context lookups; never execute AST.
  defp evaluate({operator, _, [left, right]}, context)
       when operator in [:&&, :||, :==, :!=] do
    left = evaluate(left, context)
    right = evaluate(right, context)

    case operator do
      :&& -> left and right
      :|| -> left or right
      :== -> left == right
      :!= -> left != right
    end
  end

  defp evaluate({:!, _, [value]}, context), do: not evaluate(value, context)
  defp evaluate({:cancelled, _, []}, context), do: Map.fetch!(context, "cancelled")

  defp evaluate({{:., _, _}, _, []} = path, context),
    do: Map.fetch!(context, variable_path(path))

  defp evaluate(value, _context) when is_binary(value) or is_boolean(value), do: value

  defp variable_path({{:., _, [parent, field]}, _, []}),
    do: variable_path(parent) <> "." <> Atom.to_string(field)

  defp variable_path({root, _, nil}) when root in [:github, :needs],
    do: Atom.to_string(root)
end
