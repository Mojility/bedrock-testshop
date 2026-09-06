defmodule Shop.Website.Template do
  @moduledoc """
  The tree language molecules and organisms are written in
  (`docs/atomic-composition.md`): a nested node, with placeholders where
  the node's props or its children come from the props the agent gave.
  An expansion is data, so a new organism is a new entry in
  `Shop.Website.Organisms`, not new code.

  A template node is `%{type: "stack", props: %{gap: "s2"}, children: [...]}`
  with an optional `name:` that names the node it expands to (the id is
  `parent__name`, `parent__name1`, `parent__name2` inside an `:each`;
  unnamed nodes are numbered). Anywhere a prop value goes,
  and anywhere a child goes, a placeholder may stand:

    * `{:prop, key}` and `{:prop, key, default}`: the agent's prop
    * `{:item}`, `{:item, key}`, `{:item, key, default}`: inside an
      `:each`, the current item or one of its fields
    * `{:index}`: inside an `:each`, the item's number from 1
    * `{:concat, parts}`: the parts joined, each a string or a placeholder
    * `{:case, ref, %{value => alternative}}` and
      `{:case, ref, alternatives, default}`: one alternative by the value
      of `ref` (a `:prop` or `:item` placeholder); a prop alternative is a
      value, a child alternative a node or list of nodes

  And among children only:

    * `{:each, ref, node}`: the node once per item in the list `ref` names
    * `{:if, ref, node_or_nodes}`: the node(s) only when `ref` has a value
      (not nil, false, empty); `{:if, ref, node_or_nodes, otherwise}`
      renders `otherwise` when it has none
    * `{:children}`: the children the agent gave the node, spliced in

  A prop that resolves to nil is left out of the node.
  """

  @type node_template :: %{
          required(:type) => String.t(),
          optional(:props) => map(),
          optional(:children) => list(),
          optional(:name) => String.t()
        }

  @type rendered :: %{
          type: String.t(),
          props: %{String.t() => term()},
          children: [rendered()],
          name: String.t() | nil
        }

  @doc """
  Renders `template` with the agent's `props` (string keys) and the
  `children` the agent gave the node, as nested nodes with every
  placeholder resolved.
  """
  @spec render(node_template(), map(), list()) :: rendered()
  def render(template, props, children \\ []) when is_map(template) do
    node(template, %{props: props, children: children, item: nil, index: nil})
  end

  defp node(%{type: type} = template, context) do
    %{
      type: type,
      name: Map.get(template, :name),
      props: props(Map.get(template, :props, %{}), context),
      children: children(Map.get(template, :children, []), context)
    }
  end

  defp props(props, context) do
    props
    |> Enum.map(fn {key, value} -> {to_string(key), value(value, context)} end)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp children(entries, context) do
    Enum.flat_map(entries, fn entry -> child(entry, context) end)
  end

  defp child({:each, ref, template}, context) do
    ref
    |> resolve(context)
    |> List.wrap()
    |> Enum.with_index(1)
    |> Enum.map(fn {item, index} ->
      rendered = node(template, %{context | item: item, index: index})
      %{rendered | name: rendered.name && "#{rendered.name}#{index}"}
    end)
  end

  defp child({:if, ref, alternative}, context), do: child({:if, ref, alternative, []}, context)

  defp child({:if, ref, alternative, otherwise}, context) do
    if present?(resolve(ref, context)),
      do: nodes(alternative, context),
      else: nodes(otherwise, context)
  end

  defp child({:case, ref, alternatives}, context),
    do: child({:case, ref, alternatives, []}, context)

  defp child({:case, ref, alternatives, default}, context) do
    alternatives
    |> Map.get(resolve(ref, context), default)
    |> nodes(context)
  end

  defp child({:children}, %{children: children}), do: children

  defp child(%{type: _type} = template, context), do: [node(template, context)]

  defp nodes(list, context) when is_list(list), do: children(list, context)
  defp nodes(one, context), do: child(one, context)

  defp value({:concat, parts}, context) do
    values = Enum.map(parts, &value(&1, context))
    if Enum.any?(values, &is_nil/1), do: nil, else: Enum.join(values)
  end

  defp value({:case, ref, alternatives}, context),
    do: value({:case, ref, alternatives, nil}, context)

  defp value({:case, ref, alternatives, default}, context) do
    alternatives |> Map.get(resolve(ref, context), default) |> value(context)
  end

  defp value({tag, _key} = ref, context) when tag in [:prop, :item], do: resolve(ref, context)

  defp value({tag, _key, _default} = ref, context) when tag in [:prop, :item],
    do: resolve(ref, context)

  defp value({:item}, context), do: resolve({:item}, context)
  defp value({:index}, context), do: resolve({:index}, context)
  defp value(literal, _context), do: literal

  defp resolve({:prop, key}, %{props: props}), do: Map.get(props, to_string(key))

  defp resolve({:prop, key, default}, context),
    do: default_if_nil(resolve({:prop, key}, context), default)

  defp resolve({:item}, %{item: item}), do: item
  defp resolve({:item, key}, %{item: item}) when is_map(item), do: Map.get(item, to_string(key))
  defp resolve({:item, _key}, _context), do: nil

  defp resolve({:item, key, default}, context),
    do: default_if_nil(resolve({:item, key}, context), default)

  defp resolve({:index}, %{index: index}), do: index

  defp default_if_nil(nil, default), do: default
  defp default_if_nil(value, _default), do: value

  defp present?(nil), do: false
  defp present?(false), do: false
  defp present?(""), do: false
  defp present?([]), do: false
  defp present?(_value), do: true
end
