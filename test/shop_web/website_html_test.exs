defmodule ShopWeb.WebsiteHTMLTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Phoenix.Component
  alias Shop.Leads.Lead
  alias Shop.Website.Theme
  alias Shop.Website.Tree
  alias ShopWeb.WebsiteHTML

  @hostile "<script>alert('unsafe')</script>"

  defp scene_node(type, props \\ %{}, children \\ []),
    do: %{id: "sample", type: type, props: props, children: children}

  defp page(nodes, opts \\ []) do
    document = %{"page" => %{"nodes" => nodes |> Tree.from_nested() |> Tree.to_stored()}}

    assigns =
      %{
        document: document,
        theme: %{},
        lead_form: Component.to_form(%{}, as: :lead),
        csrf_token: false,
        native_components: %{},
        content: %{}
      }
      |> Map.merge(Map.new(opts))

    render_component(&WebsiteHTML.site_page/1, assigns) |> LazyHTML.from_document()
  end

  defp attr(document, selector, attribute),
    do: document |> LazyHTML.query(selector) |> LazyHTML.attribute(attribute)

  for type <- ~w(container stack cluster grid split card center) do
    test "#{type} keeps child order and stable identifiers" do
      type = unquote(type)

      children = [
        %{scene_node("text", %{"content" => "First"}) | id: "first"},
        %{scene_node("text", %{"content" => "Second"}) | id: "second"}
      ]

      document = page([scene_node(type, %{}, children)])
      assert attr(document, "#sample", "data-type") == [type]

      assert document
             |> LazyHTML.query("#sample > p")
             |> Enum.map(&(LazyHTML.text(&1) |> String.trim())) == ["First", "Second"]
    end
  end

  test "footer bands are outside main; photo bands have decorative backgrounds" do
    photo = %{
      id: "photo",
      alt: "Business",
      caption: nil,
      variants: %{"large" => %{"width" => 1200, "height" => 800}}
    }

    document =
      page(
        [
          scene_node("band", %{"photo" => "photo"}),
          %{scene_node("band", %{"landmark" => "footer"}) | id: "footer"}
        ],
        photos: %{"photo" => photo}
      )

    assert attr(document, "main #sample > img", "alt") == [""]
    assert attr(document, "#site > footer", "id") == ["footer"]
    assert attr(document, "main #sample > img", "src") == ["/media/photo/large"]
  end

  for {type, tag, props} <- [
        {"text", "p", %{"content" => @hostile}},
        {"badge", "span", %{"content" => @hostile}},
        {"numeral", "p", %{"content" => @hostile}},
        {"quote_mark", "span", %{}},
        {"divider", "hr", %{}},
        {"icon", "svg", %{"name" => "unknown"}}
      ] do
    test "#{type} renders its semantic element and never executable text" do
      document = page([scene_node(unquote(type), unquote(Macro.escape(props)))])
      assert attr(document, unquote(tag) <> "#sample", "data-type") == [unquote(type)]
      assert document |> LazyHTML.query("script") |> Enum.empty?()
    end
  end

  for level <- [1, 2, 3, 9] do
    test "heading level #{level} has a supported semantic heading" do
      level = unquote(level)
      document = page([scene_node("heading", %{"level" => level, "content" => @hostile})])
      tag = "h#{if level in [1, 2, 3], do: level, else: 2}"
      assert document |> LazyHTML.query(tag) |> LazyHTML.text() |> String.trim() == @hostile
      assert document |> LazyHTML.query("script") |> Enum.empty?()
    end
  end

  test "buttons distinguish submit from navigation and links resolve the local apex" do
    document =
      page([
        scene_node("button", %{"action" => "submit", "label" => "Send"}),
        %{scene_node("button", %{"href" => "/contact", "label" => "Contact"}) | id: "contact"},
        %{
          scene_node("link", %{"href" => "bedrock:apex", "label" => "Home", "prominent" => true})
          | id: "home"
        }
      ])

    assert attr(document, "#sample", "type") == ["submit"]
    assert attr(document, "#contact", "href") == ["/contact"]
    assert attr(document, "#home", "href") == ["/"]
  end

  test "images have explicit and inherited alternatives, captions, sizes and placeholders" do
    photo = %{
      id: "photo",
      alt: "Inherited alternative",
      caption: @hostile,
      variants: %{
        "medium" => %{"width" => 600, "height" => 400},
        "large" => %{"width" => 1200, "height" => 800}
      }
    }

    document =
      page(
        [
          scene_node("image", %{"photo" => "photo", "caption" => true}),
          %{
            scene_node("image", %{
              "photo" => "photo",
              "alt" => "Custom alternative",
              "decorative" => true
            })
            | id: "decorative"
          },
          %{scene_node("image", %{"alt" => "Placeholder"}) | id: "placeholder"},
          %{scene_node("image", %{"decorative" => true}) | id: "empty"}
        ],
        photos: %{"photo" => photo}
      )

    assert attr(document, "#sample img", "alt") == ["Inherited alternative"]
    assert attr(document, "#sample img", "width") == ["600"]

    assert attr(document, "#sample img", "srcset") == [
             "/media/photo/medium 600w, /media/photo/large 1200w"
           ]

    assert document |> LazyHTML.query("figcaption") |> LazyHTML.text() |> String.trim() ==
             @hostile

    assert attr(document, "#decorative img", "alt") == [""]
    assert attr(document, "#placeholder", "aria-label") == ["Placeholder"]
    assert attr(document, "#empty", "aria-hidden") == ["true"]
    assert document |> LazyHTML.query("script") |> Enum.empty?()
  end

  test "lead fields connect labels, errors and help; previews disable submission" do
    form = %Lead{} |> Lead.changeset(%{}) |> Map.put(:action, :insert) |> Component.to_form()

    fields = [
      %{
        scene_node("input", %{
          "name" => "name",
          "label" => "Name",
          "help" => "Your name",
          "required" => true
        })
        | id: "name"
      },
      %{
        scene_node("input", %{"name" => "email", "kind" => "email", "label" => "Email"})
        | id: "email"
      },
      %{
        scene_node("input", %{"name" => "phone", "kind" => "tel", "label" => "Phone"})
        | id: "phone"
      },
      %{
        scene_node("textarea", %{
          "name" => "message",
          "label" => "Message",
          "help" => "Describe the work"
        })
        | id: "message"
      },
      %{
        scene_node("select", %{
          "name" => "unknown",
          "label" => "Choice",
          "help" => "Choose one",
          "options" => ["One", "Two"]
        })
        | id: "choice"
      }
    ]

    document =
      page([scene_node("form", %{}, fields)], lead_form: form, refused: true, preview: true)

    assert attr(document, "#lead-form fieldset", "disabled") == [""]
    assert attr(document, "#email input", "type") == ["email"]
    assert attr(document, "#phone input", "autocomplete") == ["tel"]
    assert attr(document, "#name input", "aria-invalid") == ["true"]
    assert attr(document, "#name input", "aria-describedby") == ["lead_name-error lead_name-help"]

    assert document |> LazyHTML.query("#lead-form-refused") |> LazyHTML.text() =~
             "Try again later"

    assert document |> LazyHTML.query("#choice option") |> Enum.count() == 2
    sent = page([scene_node("form")], sent: true)
    assert attr(sent, "#lead-sent", "role") == ["status"]
    assert sent |> LazyHTML.query("form") |> Enum.empty?()
  end

  test "preview shell loads the live client and escapes its page title" do
    document =
      render_component(&WebsiteHTML.preview_root/1, %{
        page_title: @hostile,
        inner_content: "Preview"
      })
      |> LazyHTML.from_document()

    assert document |> LazyHTML.query("title") |> LazyHTML.text() |> String.trim() == @hostile
    assert attr(document, "script", "src") == ["/assets/app.js"]
  end

  test "standalone shell contains the derived theme tokens" do
    {:ok, theme} =
      Theme.derive(
        Jason.decode!(File.read!(Path.expand("../fixtures/website_scene.json", __DIR__)))["theme"]
      )

    document = %{"page" => %{"title" => "Page", "description" => "Description", "nodes" => %{}}}

    html =
      render_component(&WebsiteHTML.show/1, %{
        document: document,
        theme: theme,
        lead_form: Component.to_form(%{}, as: :lead),
        native_components: %{},
        content: %{}
      })
      |> LazyHTML.from_document()

    assert html |> LazyHTML.query("title") |> LazyHTML.text() |> String.trim() == "Page"
    assert attr(html, "meta[name=description]", "content") == ["Description"]
    assert html |> LazyHTML.query("#site-tokens") |> LazyHTML.text() =~ ":root"
  end
end
