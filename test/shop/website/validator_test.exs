defmodule Shop.Website.ValidatorTest do
  use ExUnit.Case, async: true

  import Shop.WebsiteFixtures

  alias Shop.Website.Theme
  alias Shop.Website.Tokens
  alias Shop.Website.Tree
  alias Shop.Website.Validator

  @facts %{
    "name" => "Acme Electric",
    "contact" => %{"phone" => "905-555-0100", "email" => "pat@acme.example"}
  }

  setup do
    {:ok, theme} = Theme.derive(theme_fixture())
    %{tokens: Tokens.derive(theme)}
  end

  defp node(id, type, parent_id, index, props \\ %{}) do
    %{"id" => id, "type" => type, "parent_id" => parent_id, "index" => index, "props" => props}
  end

  defp tree(nodes),
    do:
      nodes
      |> Enum.map(&%{"op" => "upsert", "node" => &1})
      |> then(&Tree.apply_ops(Tree.new(), &1))
      |> elem(1)

  # The smallest page that passes: a hero with the primary action, a contact
  # organism, and a footer.
  defp good_nodes do
    [
      node("hero", "hero", nil, 0, %{
        "heading" => "Acme Electric",
        "primary_label" => "Get in touch",
        "primary_href" => "#contact"
      }),
      node("contact", "contact", nil, 1, %{
        "phone" => "905-555-0100",
        "email" => "pat@acme.example"
      }),
      node("footer", "footer", nil, 2, %{"name" => "Acme Electric"})
    ]
  end

  defp validate(nodes, tokens, facts \\ @facts),
    do: Validator.validate(tree(nodes), tokens, facts)

  defp reasons(nodes, tokens, facts \\ @facts) do
    {:error, reasons} = validate(nodes, tokens, facts)
    reasons
  end

  test "a page of organisms passes", %{tokens: tokens} do
    assert validate(good_nodes(), tokens) == :ok
  end

  test "an invented section built from layouts, molecules, and atoms passes too", %{
    tokens: tokens
  } do
    invented = [
      node("after_hours", "band", nil, 1, %{"surface" => "surface_alt", "padding" => "s7"}),
      node("ah_c", "container", "after_hours", 0),
      node("ah_split", "split", "ah_c", 0, %{"ratio" => "2:3"}),
      node("ah_intro", "section_intro", "ah_split", 0, %{
        "heading" => "After hours",
        "lede" => "What happens when you call at 2am."
      }),
      node("ah_steps", "stack", "ah_split", 1, %{"gap" => "s4"}),
      node("ah_s1", "step", "ah_steps", 0, %{
        "number" => 1,
        "heading" => "You call",
        "text" => "A person answers."
      }),
      node("ah_s2", "step", "ah_steps", 1, %{
        "number" => 2,
        "heading" => "We come",
        "text" => "Within the hour."
      })
    ]

    assert validate(good_nodes() ++ invented, tokens) == :ok
  end

  describe "headings" do
    test "exactly one level 1", %{tokens: tokens} do
      [hero | rest] = good_nodes()

      assert reasons(rest, tokens)
             |> Enum.any?(&(&1 =~ "exactly one level 1 heading" and &1 =~ "has none"))

      two = [
        node("b", "band", nil, 5),
        node("c", "container", "b", 0),
        node("h", "heading", "c", 0, %{"level" => 1, "content" => "Again"})
      ]

      assert reasons([hero | rest] ++ two, tokens) |> Enum.any?(&(&1 =~ "has 2"))
    end

    test "levels never skip", %{tokens: tokens} do
      skip = [
        node("b", "band", nil, 1),
        node("c", "container", "b", 0),
        node("h", "heading", "c", 0, %{"level" => 3, "content" => "Deep"})
      ]

      # Upserted after the rest, index 1 puts the band right after the hero.
      assert reasons(good_nodes() ++ skip, tokens)
             |> Enum.any?(
               &(&1 =~
                   "heading h is level 3 but the heading before it is level 1; levels never skip")
             )

      fine = [
        node("b", "band", nil, 1),
        node("c", "container", "b", 0),
        node("h", "heading", "c", 0, %{"level" => 2, "content" => "Fine"})
      ]

      assert validate(good_nodes() ++ fine, tokens) == :ok
    end
  end

  describe "the primary action" do
    test "exactly one primary button", %{tokens: tokens} do
      [hero, contact, footer] = good_nodes()
      none = %{hero | "props" => Map.put(hero["props"], "primary_variant", "secondary")}

      assert reasons([none, contact, footer], tokens)
             |> Enum.any?(&(&1 =~ "exactly one primary button" and &1 =~ "has none"))

      two = %{contact | "props" => Map.put(contact["props"], "submit_variant", "primary")}
      assert reasons([hero, two, footer], tokens) |> Enum.any?(&(&1 =~ "has 2"))
      assert validate([none, two, footer], tokens) == :ok
    end
  end

  describe "types, props, and children" do
    test "an unknown prop, a missing required prop, a bad enum, a bad list", %{tokens: tokens} do
      [hero, contact, footer] = good_nodes()

      bad = %{
        hero
        | "props" => hero["props"] |> Map.put("colour", "red") |> Map.put("variant", "carousel")
      }

      reasons = reasons([bad, contact, footer], tokens)
      assert Enum.any?(reasons, &(&1 =~ "has no prop colour"))
      assert Enum.any?(reasons, &(&1 =~ "variant must be one of stacked, split, band, centred"))

      missing = %{hero | "props" => Map.delete(hero["props"], "heading")}
      assert reasons([missing, contact, footer], tokens) |> Enum.any?(&(&1 =~ "needs heading"))

      services = node("s", "services", nil, 1, %{"items" => [%{"text" => "no name"}]})

      assert reasons([hero, services, contact, footer], tokens)
             |> Enum.any?(&(&1 =~ "items item 1 needs name"))

      strings = node("s", "services", nil, 1, %{"items" => ["Panels"]})

      assert reasons([hero, strings, contact, footer], tokens)
             |> Enum.any?(&(&1 =~ "must be a list of objects"))
    end

    test "children must be of a level the parent accepts", %{tokens: tokens} do
      wrong = [
        node("b", "band", nil, 5),
        node("c", "container", "b", 0),
        node("hero2", "hero", "c", 0, %{
          "heading" => "x",
          "primary_label" => "y",
          "primary_href" => "#z"
        })
      ]

      assert reasons(good_nodes() ++ wrong, tokens)
             |> Enum.any?(&(&1 =~ "container c cannot hold hero hero2"))

      atom_top = [node("t", "text", nil, 5, %{"content" => "loose"})]

      assert reasons(good_nodes() ++ atom_top, tokens)
             |> Enum.any?(&(&1 =~ "cannot sit at the top of the page"))

      into_organism = [node("t", "text", "hero", 0, %{"content" => "inside"})]

      assert reasons(good_nodes() ++ into_organism, tokens)
             |> Enum.any?(&(&1 =~ "hero hero cannot hold text t: it takes no children"))
    end

    test "unknown type", %{tokens: tokens} do
      tree =
        Map.put(tree(good_nodes()), "x", %Shop.Website.Node{
          id: "x",
          type: "carousel",
          parent_id: nil,
          index: 9
        })

      assert {:error, [reason]} = Validator.validate(tree, tokens, @facts)
      assert reason =~ "unknown type"
    end
  end

  describe "tokens" do
    test "every colour, style, gap, width, surface, and padding must exist for the theme", %{
      tokens: tokens
    } do
      [hero, contact, footer] = good_nodes()

      bad = [
        node("b", "band", nil, 1, %{"surface" => "neon", "padding" => "s2"}),
        node("c", "container", "b", 0, %{"width" => "huge"}),
        node("s", "stack", "c", 0, %{"gap" => "s9"}),
        node("t", "text", "s", 0, %{"content" => "x", "style" => "shout", "color" => "red"})
      ]

      reasons = reasons([hero | bad] ++ [contact, footer], tokens)
      assert Enum.any?(reasons, &(&1 =~ "surface must be a surface token"))
      assert Enum.any?(reasons, &(&1 =~ "padding must be a band_padding token"))
      assert Enum.any?(reasons, &(&1 =~ "width must be a width token"))
      assert Enum.any?(reasons, &(&1 =~ "gap must be a gap token"))
      assert Enum.any?(reasons, &(&1 =~ "style must be a type token"))
      assert Enum.any?(reasons, &(&1 =~ "color must be a color token"))
    end
  end

  describe "layouts" do
    test "grid columns at most 4, no empty layouts, depth at most 6", %{tokens: tokens} do
      [hero, contact, footer] = good_nodes()

      wide = [
        node("b", "band", nil, 1),
        node("c", "container", "b", 0),
        node("g", "grid", "c", 0, %{"columns" => 5})
      ]

      reasons = reasons([hero | wide] ++ [contact, footer], tokens)
      assert Enum.any?(reasons, &(&1 =~ "columns must be one of 1, 2, 3, 4"))
      assert Enum.any?(reasons, &(&1 =~ "grid g is empty"))

      deep = [
        node("d1", "band", nil, 1),
        node("d2", "container", "d1", 0),
        node("d3", "stack", "d2", 0),
        node("d4", "stack", "d3", 0),
        node("d5", "stack", "d4", 0),
        node("d6", "stack", "d5", 0),
        node("d7", "stack", "d6", 0),
        node("d8", "text", "d7", 0, %{"content" => "far"})
      ]

      assert reasons([hero | deep] ++ [contact, footer], tokens)
             |> Enum.any?(&(&1 =~ "nested 7 deep; the most is 6"))
    end

    test "body text sits inside a container, card, or center", %{tokens: tokens} do
      [hero, contact, footer] = good_nodes()

      loose = [
        node("b", "band", nil, 1),
        node("s", "stack", "b", 0),
        node("t", "text", "s", 0, %{"content" => "x"})
      ]

      assert reasons([hero | loose] ++ [contact, footer], tokens)
             |> Enum.any?(&(&1 =~ "text t is body text outside a container"))

      held = [
        node("b", "band", nil, 1),
        node("c", "container", "b", 0),
        node("t", "text", "c", 0, %{"content" => "x"})
      ]

      assert validate([hero | held] ++ [contact, footer], tokens) == :ok

      caption = [
        node("b", "band", nil, 1),
        node("s", "stack", "b", 0),
        node("t", "text", "s", 0, %{"content" => "x", "style" => "caption"})
      ]

      assert validate([hero | caption] ++ [contact, footer], tokens) == :ok
    end
  end

  describe "labels and alt text" do
    test "every input has a label and every image alt text or decorative", %{tokens: tokens} do
      [hero, contact, footer] = good_nodes()

      unlabelled = [
        node("b", "band", nil, 1),
        node("c", "container", "b", 0),
        node("i", "input", "c", 0, %{"name" => "name"})
      ]

      assert reasons([hero | unlabelled] ++ [contact, footer], tokens)
             |> Enum.any?(&(&1 =~ "node i (input) needs label"))

      blind = [
        node("b", "band", nil, 1),
        node("c", "container", "b", 0),
        node("img", "image", "c", 0, %{"slot" => "van"})
      ]

      assert reasons([hero | blind] ++ [contact, footer], tokens)
             |> Enum.any?(&(&1 =~ "image img needs alt text"))

      described = [
        node("b", "band", nil, 1),
        node("c", "container", "b", 0),
        node("img", "image", "c", 0, %{"slot" => "van", "alt" => "Our van"})
      ]

      assert validate([hero | described] ++ [contact, footer], tokens) == :ok

      decorative = [
        node("b", "band", nil, 1),
        node("c", "container", "b", 0),
        node("img", "image", "c", 0, %{"slot" => "van", "decorative" => true})
      ]

      assert validate([hero | decorative] ++ [contact, footer], tokens) == :ok
    end

    test "an image that names one of the shop's photos may lean on the photo's own words", %{
      tokens: tokens
    } do
      [hero, contact, footer] = good_nodes()
      mine = Ecto.UUID.generate()

      leaning = [
        hero,
        node("b", "band", nil, 1),
        node("c", "container", "b", 0),
        node("img", "image", "c", 0, %{"slot" => "van", "photo" => mine}),
        contact,
        footer
      ]

      assert Validator.validate(tree(leaning), tokens, @facts, photo_ids: [mine]) == :ok
    end
  end

  describe "photos" do
    test "a band, and so a band hero, may only name one of the shop's photos behind it", %{
      tokens: tokens
    } do
      [_hero, contact, footer] = good_nodes()
      mine = Ecto.UUID.generate()
      theirs = Ecto.UUID.generate()

      with_backdrop = fn id ->
        [
          node("hero", "hero", nil, 0, %{
            "heading" => "Acme",
            "variant" => "band",
            "photo" => id,
            "primary_label" => "Go",
            "primary_href" => "#contact"
          }),
          contact,
          footer
        ]
      end

      assert Validator.validate(tree(with_backdrop.(mine)), tokens, @facts, photo_ids: [mine]) ==
               :ok

      assert {:error, reasons} =
               Validator.validate(tree(with_backdrop.(theirs)), tokens, @facts, photo_ids: [mine])

      assert Enum.any?(reasons, &(&1 =~ "band hero names photo"))
    end

    test "an image may only name one of the shop's photos", %{tokens: tokens} do
      [hero, contact, footer] = good_nodes()
      mine = Ecto.UUID.generate()
      theirs = Ecto.UUID.generate()

      with_photo = fn id ->
        [
          hero,
          node("b", "band", nil, 1),
          node("c", "container", "b", 0),
          node("img", "image", "c", 0, %{"slot" => "van", "alt" => "Our van", "photo" => id}),
          contact,
          footer
        ]
      end

      assert Validator.validate(tree(with_photo.(mine)), tokens, @facts, photo_ids: [mine]) == :ok

      assert Validator.validate(tree(with_photo.(mine)), tokens, @facts,
               photo_ids: MapSet.new([mine])
             ) ==
               :ok

      assert {:error, reasons} =
               Validator.validate(tree(with_photo.(theirs)), tokens, @facts, photo_ids: [mine])

      assert Enum.any?(reasons, &(&1 =~ "image img names photo"))
      assert Enum.any?(reasons, &(&1 =~ "not one of this shop's photos"))

      assert {:error, _reasons} = validate(with_photo.(mine), tokens)
    end

    test "a crew's people may name photos too", %{tokens: tokens} do
      [hero, contact, footer] = good_nodes()
      mine = Ecto.UUID.generate()

      crew =
        node("crew", "crew", nil, 1, %{
          "people" => [%{"name" => "Pat", "slot" => "pat", "photo" => mine}]
        })

      assert Validator.validate(tree([hero, crew, contact, footer]), tokens, @facts,
               photo_ids: [mine]
             ) ==
               :ok

      assert {:error, [reason]} = validate([hero, crew, contact, footer], tokens)
      assert reason =~ "names photo"
    end
  end

  describe "the lead form" do
    test "a contact organism or an equivalent form must exist", %{tokens: tokens} do
      [hero, _contact, footer] = good_nodes()

      assert reasons([hero, footer], tokens)
             |> Enum.any?(&(&1 =~ "needs a contact organism, or a form"))

      handmade = [
        node("reach", "band", nil, 1),
        node("reach_c", "container", "reach", 0),
        node("reach_f", "form", "reach_c", 0, %{"action" => "leads"}),
        node("f_name", "field", "reach_f", 0, %{"name" => "name", "label" => "Name"}),
        node("f_email", "field", "reach_f", 1, %{
          "name" => "email",
          "label" => "Email",
          "kind" => "email"
        }),
        node("f_send", "button", "reach_f", 2, %{"label" => "Send", "action" => "submit"})
      ]

      assert validate([hero | handmade] ++ [footer], tokens) == :ok

      no_name = Enum.reject(handmade, &(&1["id"] == "f_name"))

      assert reasons([hero | no_name] ++ [footer], tokens)
             |> Enum.any?(&(&1 =~ "needs a field named name"))

      no_way = Enum.reject(handmade, &(&1["id"] == "f_email"))

      assert reasons([hero | no_way] ++ [footer], tokens)
             |> Enum.any?(&(&1 =~ "needs a phone or email field"))
    end
  end

  describe "the facts" do
    test "tel: and mailto: on the page must match the contact facts", %{tokens: tokens} do
      [hero, contact, footer] = good_nodes()

      wrong_phone = %{
        hero
        | "props" => Map.put(hero["props"], "primary_href", "tel:416-555-0199")
      }

      assert reasons([wrong_phone, contact, footer], tokens)
             |> Enum.any?(
               &(&1 =~ "calls 416-555-0199, which is not the phone number in the facts")
             )

      formatted = %{
        hero
        | "props" => Map.put(hero["props"], "primary_href", "tel:+1 (905) 555-0100")
      }

      assert validate([formatted, contact, footer], tokens) == :ok

      wrong_email = %{
        contact
        | "props" => Map.put(contact["props"], "email", "Other@acme.example")
      }

      assert reasons([hero, wrong_email, footer], tokens)
             |> Enum.any?(&(&1 =~ "mails Other@acme.example, which is not the email"))

      cased = %{contact | "props" => Map.put(contact["props"], "email", "PAT@acme.example")}
      assert validate([hero, cased, footer], tokens) == :ok

      no_phone_fact = %{@facts | "contact" => %{"email" => "pat@acme.example"}}

      assert reasons(good_nodes(), tokens, no_phone_fact)
             |> Enum.any?(&(&1 =~ "not the phone number in the facts"))
    end

    test "links use #id, tel:, mailto:, or https://", %{tokens: tokens} do
      [hero, contact, footer] = good_nodes()
      odd = %{hero | "props" => Map.put(hero["props"], "primary_href", "javascript:alert(1)")}

      assert reasons([odd, contact, footer], tokens)
             |> Enum.any?(&(&1 =~ "use #id, tel:, mailto:, or https://"))
    end
  end
end
