defmodule Shop.Website.TreeTest do
  use ExUnit.Case, async: true

  alias Shop.Website.Node
  alias Shop.Website.Template
  alias Shop.Website.Tree

  defp upsert(id, type, parent_id, index, props \\ %{}) do
    %{
      "op" => "upsert",
      "node" => %{
        "id" => id,
        "type" => type,
        "parent_id" => parent_id,
        "index" => index,
        "props" => props
      }
    }
  end

  defp apply!(tree, ops) do
    {:ok, tree} = Tree.apply_ops(tree, ops)
    tree
  end

  defp order(tree, parent_id), do: tree |> Tree.children_of(parent_id) |> Enum.map(& &1.id)

  # A band with a container holding two text atoms, as ops.
  defp section_ops do
    [
      upsert("about", "band", nil, 0, %{"surface" => "surface"}),
      upsert("about_c", "container", "about", 0),
      upsert("about_s", "stack", "about_c", 0, %{"gap" => "s4"}),
      upsert("t1", "text", "about_s", 0, %{"content" => "One"}),
      upsert("t2", "text", "about_s", 1, %{"content" => "Two"})
    ]
  end

  describe "Node" do
    test "accepts short lowercase ids and refuses the rest" do
      for id <- ~w(hero a1 call-now why_us x), do: assert(Node.valid_id?(id), id)

      for id <- [
            "",
            "Hero",
            "a b",
            "site",
            "site-main",
            "a__b",
            String.duplicate("a", 33),
            nil,
            3
          ] do
        refute Node.valid_id?(id), inspect(id)
      end
    end

    test "round-trips through a stored map with string keys" do
      node =
        Node.from_map(%{id: "x", type: "text", parent_id: "", index: 2, props: %{content: "hi"}})

      assert %Node{id: "x", type: "text", parent_id: nil, index: 2, props: %{"content" => "hi"}} =
               node

      assert Node.to_map(node) == %{
               "type" => "text",
               "parent_id" => nil,
               "index" => 2,
               "props" => %{"content" => "hi"}
             }
    end
  end

  describe "apply_ops/2 upsert" do
    test "adds nodes under their parents in order and re-indexes siblings from 0" do
      tree = apply!(Tree.new(), section_ops())

      assert map_size(tree) == 5
      assert order(tree, nil) == ["about"]
      assert order(tree, "about_s") == ["t1", "t2"]
      assert tree["t2"].index == 1
      assert tree["t2"].props == %{"content" => "Two"}
    end

    test "replaces a known node's props, parent, and place" do
      tree = apply!(Tree.new(), section_ops())
      tree = apply!(tree, [upsert("t1", "text", "about_s", 5, %{"content" => "One again"})])

      assert tree["t1"].props["content"] == "One again"
      assert order(tree, "about_s") == ["t2", "t1"]
      assert map_size(tree) == 5
    end

    test "an index past the end goes last, index 0 first" do
      tree = apply!(Tree.new(), section_ops())
      tree = apply!(tree, [upsert("t0", "text", "about_s", 0, %{"content" => "Zero"})])
      assert order(tree, "about_s") == ["t0", "t1", "t2"]
      assert Enum.map(Tree.children_of(tree, "about_s"), & &1.index) == [0, 1, 2]
    end

    test "rejects a malformed id, an unknown type, a missing parent, or a bad index" do
      assert {:error, [reason]} = Tree.apply_ops(Tree.new(), [upsert("Bad Id", "band", nil, 0)])
      assert reason =~ "not a usable id"

      assert {:error, [reason]} = Tree.apply_ops(Tree.new(), [upsert("x", "carousel", nil, 0)])
      assert reason =~ "unknown type"

      assert {:error, [reason]} = Tree.apply_ops(Tree.new(), [upsert("x", "stack", "ghost", 0)])
      assert reason =~ "parent that does not exist"

      assert {:error, [reason]} = Tree.apply_ops(Tree.new(), [upsert("x", "band", nil, -1)])
      assert reason =~ "index must be"
    end

    test "rejects the same id twice in one batch, and applies nothing of it" do
      ops = section_ops() ++ [upsert("t1", "text", "about_s", 3, %{"content" => "Dup"})]
      assert {:error, [reason]} = Tree.apply_ops(Tree.new(), ops)
      assert reason =~ "upserted more than once"
    end

    test "rejects a node made its own ancestor" do
      tree = apply!(Tree.new(), section_ops())
      assert {:error, [reason]} = Tree.apply_ops(tree, [upsert("about", "band", "about_s", 0)])
      assert reason =~ "own ancestor"
    end

    test "rejects an unknown operation" do
      assert {:error, [reason]} = Tree.apply_ops(Tree.new(), [%{"op" => "rename", "id" => "x"}])
      assert reason =~ "unknown operation"
    end
  end

  describe "apply_ops/2 remove" do
    test "removes the node and its whole subtree" do
      tree = apply!(Tree.new(), section_ops())
      tree = apply!(tree, [%{"op" => "remove", "id" => "about_c"}])
      assert Map.keys(tree) == ["about"]
    end

    test "cannot remove what is not there" do
      assert {:error, [reason]} = Tree.apply_ops(Tree.new(), [%{"op" => "remove", "id" => "x"}])
      assert reason =~ "no such node"
    end
  end

  describe "apply_ops/2 move" do
    test "moves a node to a new parent and place, re-indexing both sides" do
      tree = apply!(Tree.new(), section_ops() ++ [upsert("other", "stack", "about_c", 1)])
      tree = apply!(tree, [%{"op" => "move", "id" => "t1", "parent_id" => "other", "index" => 0}])

      assert order(tree, "about_s") == ["t2"]
      assert order(tree, "other") == ["t1"]
      assert tree["t2"].index == 0
    end

    test "moves a node to the top of the page with a null parent" do
      tree = apply!(Tree.new(), section_ops())

      tree =
        apply!(tree, [%{"op" => "move", "id" => "about_s", "parent_id" => nil, "index" => 0}])

      assert order(tree, nil) == ["about_s", "about"]
    end

    test "cannot move a node inside itself or under a missing parent" do
      tree = apply!(Tree.new(), section_ops())

      assert {:error, [reason]} =
               Tree.apply_ops(tree, [%{"op" => "move", "id" => "about", "parent_id" => "about_s"}])

      assert reason =~ "inside itself"

      assert {:error, [reason]} =
               Tree.apply_ops(tree, [%{"op" => "move", "id" => "t1", "parent_id" => "nowhere"}])

      assert reason =~ "no such node"
    end
  end

  describe "apply_ops/2 replace_children" do
    test "orders the named children and removes the rest with their subtrees" do
      tree =
        apply!(
          Tree.new(),
          section_ops() ++ [upsert("t3", "text", "about_s", 2, %{"content" => "3"})]
        )

      tree =
        apply!(tree, [
          %{"op" => "replace_children", "id" => "about_s", "children" => ["t3", "t1"]}
        ])

      assert order(tree, "about_s") == ["t3", "t1"]
      refute Map.has_key?(tree, "t2")
    end

    test "can adopt a node from elsewhere" do
      tree = apply!(Tree.new(), section_ops() ++ [upsert("other", "stack", "about_c", 1)])

      tree =
        apply!(tree, [%{"op" => "replace_children", "id" => "other", "children" => ["t2"]}])

      assert order(tree, "other") == ["t2"]
      assert order(tree, "about_s") == ["t1"]
    end

    test "refuses unknown children, a repeated child, and a parent moved into its own subtree" do
      tree = apply!(Tree.new(), section_ops())

      assert {:error, [reason]} =
               Tree.apply_ops(tree, [
                 %{"op" => "replace_children", "id" => "about_s", "children" => ["nope"]}
               ])

      assert reason =~ "do not exist"

      assert {:error, [reason]} =
               Tree.apply_ops(tree, [
                 %{"op" => "replace_children", "id" => "about_s", "children" => ["t1", "t1"]}
               ])

      assert reason =~ "twice"

      assert {:error, [reason]} =
               Tree.apply_ops(tree, [
                 %{"op" => "replace_children", "id" => "about_s", "children" => ["about"]}
               ])

      assert reason =~ "inside itself"
    end
  end

  describe "nesting and storage" do
    test "to_nested/1 and from_nested/1 are inverses, in order" do
      tree = apply!(Tree.new(), section_ops())
      nested = Tree.to_nested(tree)

      assert [
               %{
                 id: "about",
                 type: "band",
                 children: [%{id: "about_c", children: [%{id: "about_s", children: [t1, t2]}]}]
               }
             ] =
               nested

      assert t1.id == "t1" and t2.id == "t2"
      assert Tree.from_nested(nested) == tree
    end

    test "to_stored/1 and from_stored/1 round-trip through string-keyed maps" do
      tree = apply!(Tree.new(), section_ops())
      stored = Tree.to_stored(tree)

      assert stored["t1"] == %{
               "type" => "text",
               "parent_id" => "about_s",
               "index" => 0,
               "props" => %{"content" => "One"}
             }

      assert Tree.from_stored(stored) == tree
      assert Tree.from_stored(nil) == %{}
    end

    test "to_text/1 is one indented line per node with its props" do
      text = Tree.new() |> apply!(section_ops()) |> Tree.to_text()

      assert text == """
             band#about {surface: "surface"}
               container#about_c
                 stack#about_s {gap: "s4"}
                   text#t1 {content: "One"}
                   text#t2 {content: "Two"}\
             """

      assert Tree.to_text(Tree.new()) == "(empty)"
    end

    test "origin/1 names the agent's node behind an expanded one" do
      assert Tree.origin("hero__0__heading") == "hero"
      assert Tree.origin("hero") == "hero"
    end
  end

  describe "expand/1" do
    test "turns a molecule into its atoms and layouts, named after the molecule" do
      tree =
        apply!(Tree.new(), [
          upsert("s", "stack", nil, 0),
          upsert("intro", "section_intro", "s", 0, %{
            "heading" => "What we do",
            "eyebrow" => "Services",
            "lede" => "Plainly."
          })
        ])

      assert [%{id: "s", type: "stack", children: [intro]}] = Tree.expand(tree)
      assert intro.type == "stack"
      assert intro.id == "intro"

      assert Enum.map(intro.children, &{&1.id, &1.type}) == [
               {"intro__eyebrow", "text"},
               {"intro__heading", "heading"},
               {"intro__lede", "text"}
             ]

      assert Enum.at(intro.children, 1).props == %{"level" => 2, "content" => "What we do"}
    end

    test "leaves out the optional parts of a molecule that have no prop" do
      tree =
        apply!(Tree.new(), [
          upsert("s", "stack", nil, 0),
          upsert("i", "section_intro", "s", 0, %{"heading" => "H"})
        ])

      [%{children: [intro]}] = Tree.expand(tree)
      assert Enum.map(intro.children, & &1.type) == ["heading"]
    end

    test "turns an organism into layouts, molecules, and atoms, all the way down" do
      tree =
        apply!(Tree.new(), [
          upsert("hero", "hero", nil, 0, %{
            "heading" => "Acme",
            "primary_label" => "Call",
            "primary_href" => "tel:1",
            "variant" => "split"
          })
        ])

      assert [%{id: "hero", type: "band", props: %{"surface" => "hero"}, children: [container]}] =
               Tree.expand(tree)

      assert %{type: "container", children: [%{type: "split"}]} = container

      types =
        tree
        |> Tree.expand()
        |> Tree.from_nested()
        |> Map.values()
        |> Enum.map(& &1.type)
        |> Enum.uniq()
        |> Enum.sort()

      assert types == ~w(band button cluster container heading split stack)
      ids = tree |> Tree.expand() |> Tree.from_nested() |> Map.keys()
      assert length(ids) == length(Enum.uniq(ids))
      assert Enum.all?(ids, &(Tree.origin(&1) == "hero"))
    end

    test "splices the agent's own children into a molecule that takes them" do
      tree =
        apply!(Tree.new(), [
          upsert("s", "stack", nil, 0),
          upsert("g", "button_group", "s", 0),
          upsert("b", "button", "g", 0, %{"label" => "Go", "href" => "#x", "variant" => "primary"})
        ])

      [%{children: [group]}] = Tree.expand(tree)
      assert group.type == "cluster"
      assert [%{id: "b", type: "button"}] = group.children
    end
  end

  describe "Template.render/3" do
    test "resolves props, items, index, concat, case, if, and each" do
      template = %{
        type: "stack",
        props: %{gap: {:prop, :gap, "s2"}, missing: {:prop, :nothing}},
        children: [
          {:if, {:prop, :title},
           %{name: "title", type: "text", props: %{content: {:prop, :title}}}},
          {:each, {:prop, :rows},
           %{
             name: "row",
             type: "text",
             props: %{content: {:concat, ["", {:index}, ". ", {:item, :name}]}}
           }},
          {:case, {:prop, :kind}, %{"a" => %{type: "divider", props: %{}}},
           %{type: "quote_mark", props: %{}}}
        ]
      }

      rendered =
        Template.render(template, %{"rows" => [%{"name" => "x"}, %{"name" => "y"}], "kind" => "b"})

      assert rendered.props == %{"gap" => "s2"}

      assert Enum.map(rendered.children, &{&1.name, &1.type, &1.props["content"]}) == [
               {"row1", "text", "1. x"},
               {"row2", "text", "2. y"},
               {nil, "quote_mark", nil}
             ]

      with_title = Template.render(template, %{"title" => "T", "kind" => "a"})
      assert Enum.map(with_title.children, & &1.type) == ["text", "divider"]
    end
  end
end
