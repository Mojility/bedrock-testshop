defmodule BuildWorkflowTest do
  @moduledoc """
  Exercises workflow load safety and the complete publication graph locally.
  These contracts do not claim a hosted GitHub run or platform integration proof.
  """
  use ExUnit.Case, async: true

  @workflow Path.expand("../../.github/workflows/build.yml", __DIR__)
  @platform Path.expand("../../.github/workflows/starter-platform.yml", __DIR__)
  @producer Path.expand("../fixtures/integration-producer.yml", __DIR__)
  # Bedrock 78767528c45c0d9412c4cbc90d395c724ed1c5ee, unchanged workflow bytes.
  @producer_sha256 "da1dac5fe25a61dbd0096f988269c58ab36d71458f7afb02f16258e34d8b4a06"
  @starter "Mojility/bedrock-system-template"
  @customer "Mojility/synthetic-electrical-service"
  @results ~w(success failure cancelled skipped)
  @events ~w(push workflow_dispatch pull_request schedule)

  setup do
    %{
      workflow: YamlElixir.read_from_file!(@workflow),
      platform: if(File.exists?(@platform), do: YamlElixir.read_from_file!(@platform))
    }
  end

  test "customer workflows never resolve private Mojility resources at load time" do
    manifest = Path.expand("../../.bedrock/starter-only.json", __DIR__)

    excluded =
      if File.exists?(manifest), do: Jason.decode!(File.read!(manifest))["paths"], else: []

    for path <- Path.wildcard(".github/workflows/*.{yml,yaml}"), path not in excluded do
      for [_, repository] <- Regex.scan(~r/uses:\s*["']?(Mojility\/[^\s@"']+)/i, File.read!(path)) do
        assert repository == @starter or String.starts_with?(repository, @starter <> "/"),
               "#{path} resolves a platform resource before job guards: #{repository}"
      end
    end
  end

  @tag skip: not File.exists?(@platform)
  test "a customer copy loads safely even before starter-only files are removed", %{
    workflow: workflow,
    platform: platform
  } do
    manifest = Jason.decode!(File.read!(".bedrock/starter-only.json"))
    assert manifest == %{"version" => 1, "paths" => [".github/workflows/starter-platform.yml"]}

    # A guard cannot protect a private uses reference, including in excluded files.
    for path <- Path.wildcard(".github/workflows/*.{yml,yaml}") do
      refute File.read!(path) =~ ~r/uses:\s*["']?Mojility\/(?!bedrock-system-template(?:\/|@))/i
    end

    refute Map.has_key?(workflow["jobs"], "integration")
    refute inspect(workflow) =~ "SOURCE_KEY"
    refute inspect(workflow) =~ "Mojility/bedrock/"
    assert platform["on"] == %{"push" => %{"branches" => ["main"]}, "workflow_dispatch" => nil}

    for event <- @events do
      refute runs?(platform["jobs"]["resolve"], context(@customer, event))
      refute runs?(platform["jobs"]["integrated"], context(@customer, event))
      refute runs?(platform["jobs"]["publish-starter"], context(@customer, event))
    end
  end

  test "quality and release acceptance preserve the customer checks", %{workflow: workflow} do
    checks = YamlElixir.read_from_file!("test/fixtures/customer-build-checks.yml")["jobs"]
    assert Map.take(workflow["jobs"], Map.keys(checks)) == checks
    assert workflow["on"]["workflow_call"]["inputs"]["starter-publication"]["default"] == false
    assert workflow["jobs"]["build-and-push"]["needs"] == ["quality", "release-acceptance"]
  end

  test "customer publication needs only successful standalone gates", %{workflow: workflow} do
    for event <- @events, quality <- @results, release <- @results, cancelled <- [false, true] do
      ctx =
        Map.merge(context(@customer, event), %{
          "needs.quality.result" => quality,
          "needs.release_acceptance.result" => release,
          "cancelled" => cancelled
        })

      expected =
        not cancelled and event in ~w(push workflow_dispatch) and
          quality == "success" and release == "success"

      assert runs?(workflow["jobs"]["build-and-push"], ctx) == expected
    end
  end

  @tag skip: not File.exists?(@platform)
  test "ordinary integration jobs preserve shared producer validation", %{platform: platform} do
    assert Base.encode16(:crypto.hash(:sha256, File.read!(@producer)), case: :lower) ==
             @producer_sha256

    producer = YamlElixir.read_from_file!(@producer)["jobs"]
    actual = Map.delete(platform["jobs"], "publish-starter")
    assert Map.keys(actual) |> Enum.sort() == Map.keys(producer) |> Enum.sort()

    for {name, job} <- producer do
      expected = nonpublishing_job(name, job)

      received =
        if name in ["resolve", "integrated"],
          do: Map.delete(actual[name], "if"),
          else: actual[name]

      expected = if name == "integrated", do: Map.delete(expected, "if"), else: expected
      assert received == expected, "shared validation drift in #{name}"
      refute Map.has_key?(actual[name], "uses")
      refute Map.has_key?(actual[name], "continue-on-error")
    end

    assert actual["integrated"]["needs"] == ~w(resolve quality workshop bedrock-image)

    for repository <- [@starter, @customer], event <- @events do
      expected = repository == @starter and event in ~w(push workflow_dispatch)
      assert runs?(actual["resolve"], context(repository, event)) == expected
      assert runs?(actual["integrated"], context(repository, event)) == expected
    end
  end

  @tag skip: not File.exists?(@platform)
  test "starter publication only enters the local build after successful integration", %{
    platform: platform
  } do
    job = platform["jobs"]["publish-starter"]
    assert job["needs"] == "integrated"
    assert job["uses"] == "./.github/workflows/build.yml"
    assert job["with"] == %{"starter-publication" => true}
    assert job["permissions"] == %{"contents" => "read", "id-token" => "write"}
    refute Map.has_key?(job, "continue-on-error")

    for repository <- [@starter, @customer], event <- @events, result <- @results do
      ctx = Map.put(context(repository, event), "needs.integrated.result", result)

      expected =
        repository == @starter and event in ~w(push workflow_dispatch) and result == "success"

      assert runs?(job, ctx) == expected
    end
  end

  @tag skip: not File.exists?(@platform)
  test "the full graph blocks starter images on any failed gate and preserves standalone customer CI",
       %{
         workflow: workflow,
         platform: platform
       } do
    for repository <- [@starter, @customer],
        event <- @events,
        quality <- @results,
        release <- @results,
        integration <- @results,
        cancelled <- [false, true] do
      ctx =
        context(repository, event)
        |> Map.merge(%{
          "needs.quality.result" => quality,
          "needs.release_acceptance.result" => release,
          "needs.integrated.result" => integration,
          "cancelled" => cancelled
        })

      direct = runs?(workflow["jobs"]["build-and-push"], ctx)

      called =
        runs?(platform["jobs"]["publish-starter"], ctx) and
          runs?(
            workflow["jobs"]["build-and-push"],
            Map.put(ctx, "inputs.starter_publication", true)
          )

      expected =
        not cancelled and event in ~w(push workflow_dispatch) and
          quality == "success" and release == "success" and
          (repository != @starter or integration == "success")

      assert (direct or called) == expected,
             inspect({repository, event, quality, release, integration, cancelled})

      if repository == @starter, do: refute(direct)
    end
  end

  defp nonpublishing_job("bedrock-image", job) do
    job
    |> Map.delete("outputs")
    |> Map.update!("steps", fn steps ->
      Enum.reject(steps, &(&1["if"] == "inputs.publish-image"))
    end)
  end

  defp nonpublishing_job("quality", job) do
    Map.update!(job, "steps", &Enum.map(&1, fn step -> pin_integration_otp(step) end))
  end

  defp nonpublishing_job(_name, job), do: job

  defp pin_integration_otp(%{"uses" => "erlef/setup-beam@v1"} = step),
    do: put_in(step, ["with", "otp-version"], "29.0.2")

  defp pin_integration_otp(step), do: step

  defp context(repository, event) do
    %{
      "github.repository" => repository,
      "github.event_name" => event,
      "needs.quality.result" => "success",
      "needs.release_acceptance.result" => "success",
      "needs.integrated.result" => "success",
      "inputs.starter_publication" => false,
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
    |> String.replace("starter-publication", "starter_publication")
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
  defp evaluate({:always, _, []}, _context), do: true
  defp evaluate({:cancelled, _, []}, context), do: Map.fetch!(context, "cancelled")

  defp evaluate({{:., _, _}, _, []} = path, context),
    do: Map.fetch!(context, variable_path(path))

  defp evaluate(value, _context) when is_binary(value) or is_boolean(value), do: value

  defp variable_path({{:., _, [parent, field]}, _, []}),
    do: variable_path(parent) <> "." <> Atom.to_string(field)

  defp variable_path({root, _, nil}) when root in [:github, :needs, :inputs],
    do: Atom.to_string(root)
end
