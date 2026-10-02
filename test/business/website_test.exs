defmodule Business.WebsiteTest do
  use ExUnit.Case, async: true
  alias Business.Website.ComponentModel
  @fixture Path.expand("../fixtures/website_scene.json", __DIR__)
  defp scene, do: File.read!(@fixture) |> Jason.decode!()

  defp options,
    do: [
      model: {:ok, %{"version" => 1, "components" => []}},
      media: {:ok, %{"version" => 1, "photos" => %{}}}
    ]

  test "renders Bedrock's unexpanded scene without loading Bedrock" do
    refute Code.ensure_loaded?(Bedrock.Sites.Tree)

    assert {:ok, html} =
             Business.Website.render(
               scene(),
               Keyword.put(options(), :csrf_token, "per-request-token")
             )

    assert html =~ "Scene test"
    assert html =~ "per-request-token"
    assert html =~ "/assets/published/site.css"
    refute html =~ "__SITE_CSRF_TOKEN__"
  end

  test "customer native components use changing application content without changing the scene" do
    model = %{
      "version" => 1,
      "components" => [
        %{
          "name" => "live_notice",
          "native" => true,
          "level" => "organism",
          "props" => %{},
          "template" => %{
            "type" => "container",
            "children" => [%{"type" => "text", "props" => %{"content" => "Preview notice"}}]
          }
        }
      ]
    }

    scene = scene() |> Map.put("component_model_hash", ComponentModel.hash(model))

    scene =
      put_in(scene, ["document", "page", "nodes", "live_notice"], %{
        "id" => "live_notice",
        "type" => "live_notice",
        "parent_id" => nil,
        "index" => 1,
        "props" => %{}
      })

    opts = options() |> Keyword.put(:model, {:ok, model})
    assert {:error, _} = Business.Website.render(scene, opts)

    opts =
      Keyword.put(opts, :native_components, %{
        "live_notice" => &BusinessWeb.NativeNoticeFixture.render/1
      })

    assert {:ok, first} =
             Business.Website.render(
               scene,
               Keyword.put(opts, :content, %{"notice" => "Available today"})
             )

    assert {:ok, second} =
             Business.Website.render(
               scene,
               Keyword.put(opts, :content, %{"notice" => "<script>Booked</script>"})
             )

    assert first =~ "Available today"
    assert second =~ "&lt;script&gt;Booked&lt;/script&gt;"
    refute second =~ "Available today"
  end

  test "unknown versions, model changes and graph cycles are refused" do
    assert {:error, _} = Business.Website.render(Map.put(scene(), "version", 2), options())

    assert {:error, _} =
             Business.Website.render(Map.put(scene(), "component_model_hash", "wrong"), options())

    scene =
      put_in(scene(), ["document", "page", "nodes", "loop"], %{
        "id" => "loop",
        "type" => "stack",
        "parent_id" => "loop",
        "index" => 0,
        "props" => %{}
      })

    assert {:error, _} = Business.Website.render(scene, options())
  end
end
