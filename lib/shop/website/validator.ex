defmodule Shop.Website.Validator do
  @moduledoc """
  The rules a page tree must keep (`docs/atomic-composition.md`, "Rules
  the validator enforces"), each with a plain reason the model and the
  owner can read. A tree that fails is not rendered; the previous one
  stays.

  The rules are the invariants of the visual design theory skill that
  live in structure rather than in tokens: one h1 and headings in order,
  one primary action, every prop a value the registry allows and every
  token one the current theme has, children at the levels their parent
  accepts, grids of at most four columns, no empty layouts, a nesting
  depth of at most six in the agent's tree, body text inside a
  measure-limited container, every input labelled and every image
  described (by its alt text or by the photo it names), every `photo` one
  of the shop's own, a lead form on
  the page, and the contact channels on the page matching the facts
  (`tel:` and `mailto:` values, and `contact_channel` values, against
  `facts.contact`).

  Props are checked on the tree as the agent wrote it, since that is where
  the choices are; the structural rules run on the expanded tree, since
  that is what a visitor sees. Contrast is not checked here: it is a
  property of the tokens, so any tree that passes is readable.
  """
  alias Shop.Website.Node
  alias Shop.Website.Registry
  alias Shop.Website.Tokens
  alias Shop.Website.Tree

  @max_depth 6
  @max_columns 4
  @measure_limiting ~w(container card center)
  @href_schemes ~w(# tel: mailto: https:// http:// bedrock:apex)

  @doc """
  Checks `tree` against the rules, with the current theme's `tokens`
  (`Shop.Website.Tokens.derive/1`) and the site's `facts`. Returns `:ok`
  or `{:error, reasons}`. Options:

    * `:photo_ids` - the ids of the shop's ready photos (a `MapSet` or
      list); an image whose `photo` is not among them fails. None by
      default, so a page can only name photos the caller vouches for.

  """
  @spec validate(Tree.t(), Tokens.t(), map(), keyword()) :: :ok | {:error, [String.t()]}
  def validate(tree, tokens, facts, opts \\ [])
      when is_map(tree) and is_map(tokens) and is_map(facts) do
    extensions = Keyword.get(opts, :components, %{})
    agent_nodes = Map.values(tree)
    photo_ids = opts |> Keyword.get(:photo_ids, []) |> MapSet.new()

    structural =
      Enum.flat_map(agent_nodes, &node_problems(&1, tree, tokens, extensions)) ++
        depth_problems(tree)

    # A tree whose nodes are malformed cannot be expanded meaningfully, so
    # the page-wide rules wait for a well-formed one.
    case structural do
      [] -> page_problems(Tree.expand(tree, extensions), facts, photo_ids) |> result()
      problems -> {:error, problems}
    end
  end

  # ---- Per node: type, props, children, tokens --------------------------------

  defp node_problems(%Node{} = node, tree, tokens, extensions) do
    case Registry.get(node.type, extensions) do
      nil ->
        ["node #{node.id} has an unknown type #{inspect(node.type)}"]

      entry ->
        prop_problems(node, entry, tokens) ++ child_problems(node, entry, tree, extensions)
    end
  end

  defp prop_problems(node, entry, tokens) do
    schema_problems(node.props, entry.props, tokens, "node #{node.id} (#{node.type})")
  end

  defp schema_problems(props, schema, tokens, subject) do
    known = Map.new(schema, fn {name, spec} -> {to_string(name), spec} end)

    unknown =
      props
      |> Map.keys()
      |> Enum.reject(&Map.has_key?(known, &1))
      |> Enum.map(&"#{subject} has no prop #{&1}; its props are #{prop_names(known)}")

    missing =
      known
      |> Enum.filter(fn {name, spec} -> spec[:required] && blank?(props[name]) end)
      |> Enum.map(fn {name, _spec} -> "#{subject} needs #{name}" end)

    wrong =
      props
      |> Enum.filter(fn {name, value} -> Map.has_key?(known, name) and not is_nil(value) end)
      |> Enum.flat_map(fn {name, value} ->
        value_problems(value, known[name], tokens, "#{subject} #{name}")
      end)

    unknown ++ missing ++ wrong
  end

  defp value_problems(value, %{type: :string}, _tokens, subject) do
    if is_binary(value), do: [], else: ["#{subject} must be text"]
  end

  defp value_problems(value, %{type: :boolean}, _tokens, subject) do
    if is_boolean(value), do: [], else: ["#{subject} must be true or false"]
  end

  defp value_problems(value, %{type: :integer} = spec, _tokens, subject) do
    cond do
      not is_integer(value) ->
        ["#{subject} must be a whole number"]

      spec[:values] && value not in spec.values ->
        ["#{subject} must be one of #{list(spec.values)}"]

      true ->
        []
    end
  end

  defp value_problems(value, %{type: :enum, values: values}, _tokens, subject) do
    if value in values, do: [], else: ["#{subject} must be one of #{list(values)}"]
  end

  defp value_problems(value, %{type: :token, domain: domain}, tokens, subject) do
    allowed = token_values(domain, tokens)

    if value in allowed,
      do: [],
      else: ["#{subject} must be a #{domain} token of this theme: #{list(allowed)}"]
  end

  defp value_problems(value, %{type: :list, of: :string}, _tokens, subject) do
    if is_list(value) and Enum.all?(value, &is_binary/1),
      do: [],
      else: ["#{subject} must be a list of text"]
  end

  defp value_problems(value, %{type: :list, of: fields}, tokens, subject) when is_map(fields) do
    if is_list(value) and Enum.all?(value, &is_map/1) do
      value
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {item, n} ->
        schema_problems(Node.stringify(item), fields, tokens, "#{subject} item #{n}")
      end)
    else
      ["#{subject} must be a list of objects with #{prop_names(fields)}"]
    end
  end

  # Token domains come from the current theme's tokens where the theme has
  # a say (type styles, colours, spacing, widths); the rest are fixed sets.
  defp token_values(:type, tokens), do: Map.keys(tokens.type)

  defp token_values(:color, tokens),
    do: Enum.filter(Tokens.text_colors(), &(&1 in Map.keys(tokens.colors)))

  defp token_values(:gap, tokens), do: Enum.filter(Tokens.gaps(), &Map.has_key?(tokens.space, &1))
  defp token_values(:width, tokens), do: Map.keys(tokens.container)

  defp token_values(:band_padding, tokens),
    do: Enum.filter(Tokens.band_paddings(), &Map.has_key?(tokens.space, &1))

  defp token_values(:card_padding, tokens),
    do: Enum.filter(Tokens.card_paddings(), &Map.has_key?(tokens.space, &1))

  defp token_values(:icon, tokens), do: tokens.icons
  defp token_values(:surface, _tokens), do: Tokens.surfaces()
  defp token_values(:card_surface, _tokens), do: Tokens.card_surfaces()

  defp child_problems(node, entry, tree, extensions) do
    children = Tree.children_of(tree, node.id)

    wrong_level =
      children
      |> Enum.reject(fn child -> level_of(child, extensions) in entry.children end)
      |> Enum.map(fn child ->
        "#{node.type} #{node.id} cannot hold #{child.type} #{child.id}: " <> accepts(entry)
      end)

    empty =
      if entry.level == :layout and children == [],
        do: ["#{node.type} #{node.id} is empty; a layout needs children or should be removed"],
        else: []

    top =
      if is_nil(node.parent_id) and entry.level not in Registry.page_children(),
        do: [
          "#{node.type} #{node.id} cannot sit at the top of the page; only layouts and organisms can"
        ],
        else: []

    wrong_level ++ empty ++ top
  end

  defp accepts(%{children: []}), do: "it takes no children"

  defp accepts(%{children: levels}),
    do: "it takes " <> Enum.map_join(levels, ", ", &"#{&1}s")

  defp level_of(%Node{type: type}, extensions) do
    case Registry.get(type, extensions) do
      nil -> :unknown
      %{level: level} -> level
    end
  end

  defp depth_problems(tree) do
    tree
    |> Map.values()
    |> Enum.filter(&(depth(tree, &1) > @max_depth))
    |> Enum.map(&"node #{&1.id} is nested #{depth(tree, &1)} deep; the most is #{@max_depth}")
  end

  defp depth(_tree, %Node{parent_id: nil}), do: 1
  defp depth(tree, %Node{parent_id: parent_id}), do: 1 + depth(tree, Map.fetch!(tree, parent_id))

  # ---- Whole page, on the expanded tree ---------------------------------------

  defp page_problems(expanded, facts, photo_ids) do
    nodes = walk(expanded, [])

    heading_problems(nodes) ++
      primary_problems(nodes) ++
      grid_problems(nodes) ++
      measure_problems(nodes) ++
      image_problems(nodes) ++
      photo_problems(nodes, photo_ids) ++
      form_problems(nodes) ++
      fact_problems(nodes, facts)
  end

  # Every node in document order, with the types of its ancestors.
  defp walk(nodes, ancestors) do
    Enum.flat_map(nodes, fn node ->
      [{node, ancestors} | walk(node.children, [node.type | ancestors])]
    end)
  end

  defp heading_problems(nodes) do
    headings = for {%{type: "heading"} = node, _ancestors} <- nodes, do: node

    ones = Enum.filter(headings, &(&1.props["level"] == 1))

    count =
      case ones do
        [_one] ->
          []

        [] ->
          ["the page needs exactly one level 1 heading (the hero's) and has none"]

        many ->
          ["the page needs exactly one level 1 heading and has #{length(many)}: #{ids(many)}"]
      end

    {skips, _previous} =
      Enum.reduce(headings, {[], 0}, fn heading, {problems, previous} ->
        level = heading.props["level"]

        if is_integer(level) and level > previous + 1 do
          {[
             "#{where(heading)} is level #{level} but the heading before it is level #{previous}; levels never skip"
             | problems
           ], level}
        else
          {problems, level}
        end
      end)

    count ++ Enum.reverse(skips)
  end

  defp primary_problems(nodes) do
    primaries =
      for {%{type: "button", props: %{"variant" => "primary"}} = node, _ancestors} <- nodes,
          do: node

    case primaries do
      [_one] -> []
      [] -> ["the page needs exactly one primary button, the page's one action, and has none"]
      many -> ["the page needs exactly one primary button and has #{length(many)}: #{ids(many)}"]
    end
  end

  defp grid_problems(nodes) do
    for {%{type: "grid", props: %{"columns" => columns}} = node, _ancestors} <- nodes,
        is_integer(columns) and columns > @max_columns do
      "#{where(node)} has #{columns} columns; the most is #{@max_columns}"
    end
  end

  defp measure_problems(nodes) do
    for {%{type: "text", props: props} = node, ancestors} <- nodes,
        Map.get(props, "style", "body") in ~w(body lede),
        not Enum.any?(ancestors, &(&1 in @measure_limiting)) do
      "#{where(node)} is #{Map.get(props, "style", "body")} text outside a container; put it inside a container, card, or center"
    end
  end

  # An image that names one of the owner's photos may lean on the photo's
  # own description; a placeholder must say what will go there.
  defp image_problems(nodes) do
    for {%{type: "image", props: props} = node, _ancestors} <- nodes,
        blank?(props["alt"]) and blank?(props["photo"]) and props["decorative"] != true do
      "#{where(node)} needs alt text saying what it shows, or decorative: true"
    end
  end

  # Any node that names a photo (an image, or a band with one behind it)
  # must name one of this shop's ready photos.
  defp photo_problems(nodes, photo_ids) do
    for {%{props: %{"photo" => photo}} = node, _ancestors} <- nodes,
        not blank?(photo) and not MapSet.member?(photo_ids, photo) do
      "#{where(node)} names photo #{inspect(photo)}, which is not one of this shop's photos; use an id from the photo list or leave photo out"
    end
  end

  defp form_problems(nodes) do
    forms = for {%{type: "form"} = node, _ancestors} <- nodes, do: node

    case forms do
      [] ->
        [
          "the page needs a contact organism, or a form with action leads holding a name field and a phone or email field"
        ]

      forms ->
        Enum.flat_map(forms, &form_field_problems/1)
    end
  end

  defp form_field_problems(form) do
    names =
      for {%{type: type, props: props}, _ancestors} <- walk(form.children, []),
          type in ~w(input textarea select),
          do: props["name"]

    cond do
      "name" not in names ->
        ["#{where(form)} needs a field named name"]

      not Enum.any?(names, &(&1 in ~w(phone email))) ->
        ["#{where(form)} needs a phone or email field"]

      true ->
        []
    end
  end

  defp fact_problems(nodes, facts) do
    contact = Node.stringify(facts["contact"] || %{})
    phone = digits(contact["phone"])
    email = contact["email"] && String.downcase(contact["email"])

    nodes
    |> Enum.flat_map(fn {node, _ancestors} -> channel_values(node) end)
    |> Enum.flat_map(fn
      {node, "tel:" <> value} ->
        if digits(value) == phone and phone != "",
          do: [],
          else: ["#{where(node)} calls #{value}, which is not the phone number in the facts"]

      {node, "mailto:" <> value} ->
        if String.downcase(value) == email,
          do: [],
          else: ["#{where(node)} mails #{value}, which is not the email in the facts"]

      {node, href} ->
        if Enum.any?(@href_schemes, &String.starts_with?(href, &1)),
          do: [],
          else: ["#{where(node)} links to #{inspect(href)}; use #id, tel:, mailto:, or https://"]
    end)
  end

  defp channel_values(%{type: type, props: %{"href" => href}} = node)
       when type in ~w(button link) and is_binary(href),
       do: [{node, href}]

  defp channel_values(_node), do: []

  # ---- Helpers ----------------------------------------------------------------

  defp result([]), do: :ok
  defp result(problems), do: {:error, problems}

  defp ids(nodes), do: nodes |> Enum.map(&where/1) |> Enum.join(", ")

  # An expanded node is named for the model by the node the agent wrote.
  defp where(%{type: type, id: id}) do
    case Tree.origin(id) do
      ^id -> "#{type} #{id}"
      origin -> "the #{type} inside #{origin}"
    end
  end

  defp list(values), do: Enum.map_join(values, ", ", &to_string/1)

  defp prop_names(schema),
    do: schema |> Map.keys() |> Enum.map(&to_string/1) |> Enum.sort() |> Enum.join(", ")

  # A North American number with or without its country code is the same
  # number: +1 (905) 555-0100 and 905-555-0100 both come to 9055550100.
  defp digits(nil), do: ""

  defp digits(value) do
    case String.replace(to_string(value), ~r/\D/, "") do
      <<"1", rest::binary-size(10)>> -> rest
      digits -> digits
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?([]), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_value), do: false
end
