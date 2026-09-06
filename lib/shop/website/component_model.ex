defmodule Shop.Website.ComponentModel do
  @moduledoc "Versioned, data-only customer component definitions; never executable code."
  alias Shop.Website.Registry
  @levels ~w(atom molecule layout organism)a
  @types ~w(string integer boolean enum token list)a
  @domains ~w(type color space radius rule shadow icon surface card_surface container band_padding card_padding)a
  @ops ~w(prop item index concat case each if children)a

  def entries(nil), do: %{}

  def entries(%{"version" => 1, "components" => components})
      when is_list(components) and length(components) <= 100 do
    entries = Enum.map(components, &entry/1)
    names = Enum.map(entries, & &1.name)
    if length(Enum.uniq(names)) != length(names), do: raise(ArgumentError, "duplicate component")
    result = Map.new(entries, &{&1.name, &1})
    Enum.each(names, &check_dependencies(&1, result, []))
    result
  end

  def entries(_), do: raise(ArgumentError, "unsupported component model")

  defp check_dependencies(name, entries, ancestors) do
    if name in ancestors or length(ancestors) > 12,
      do: raise(ArgumentError, "recursive component model")

    if entry = entries[name] do
      Enum.each(references(entry.template), fn child ->
        unless Registry.get(child, entries),
          do: raise(ArgumentError, "unknown template component")

        check_dependencies(child, entries, [name | ancestors])
      end)
    end
  end

  defp references(map) when is_map(map),
    do: List.wrap(map[:type]) ++ Enum.flat_map(Map.values(map), &references/1)

  defp references(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> references()
  defp references(list) when is_list(list), do: Enum.flat_map(list, &references/1)
  defp references(_), do: []

  def hash(model) do
    :crypto.hash(:sha256, Jason.encode!(canonical({Registry.all(), entries(model)})))
    |> Base.encode16(case: :lower)
  end

  defp canonical(value) when is_map(value) do
    [
      "map",
      value
      |> Enum.map(fn {key, item} -> {to_string(key), canonical(item)} end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {key, item} -> [key, item] end)
    ]
  end

  defp canonical(value) when is_tuple(value),
    do: ["tuple", value |> Tuple.to_list() |> Enum.map(&canonical/1)]

  defp canonical(value) when is_list(value), do: Enum.map(value, &canonical/1)

  defp canonical(value) when is_atom(value) and value not in [nil, true, false],
    do: ["atom", to_string(value)]

  defp canonical(value), do: value

  defp entry(%{"name" => name, "level" => level, "template" => template} = entry) do
    unless is_binary(name) and Regex.match?(~r/^[a-z][a-z0-9_-]{0,63}$/, name) and
             is_nil(Registry.get(name)),
           do: raise(ArgumentError, "component name must be new")

    %{
      name: name,
      native: entry["native"] == true,
      level: enum(level, @levels),
      purpose: Map.get(entry, "purpose", "Customer component"),
      props: Map.new(Map.get(entry, "props", %{}), fn {key, value} -> {key, schema(value)} end),
      children: Enum.map(Map.get(entry, "children", []), &enum(&1, @levels)),
      template: template(template)
    }
  end

  defp entry(_), do: raise(ArgumentError, "component requires a declarative preview template")

  defp schema(%{"type" => type} = spec) do
    result = %{type: enum(type, @types)}

    result =
      Enum.reduce(~w(required default doc values), result, fn key, result ->
        if Map.has_key?(spec, key),
          do: Map.put(result, enum(key, [:required, :default, :doc, :values]), spec[key]),
          else: result
      end)

    result =
      if spec["domain"],
        do: Map.put(result, :domain, enum(spec["domain"], @domains)),
        else: result

    if spec["of"] do
      of =
        if spec["of"] == "string",
          do: :string,
          else: Map.new(spec["of"], fn {key, value} -> {key, schema(value)} end)

      Map.put(result, :of, of)
    else
      result
    end
  end

  defp template(%{"$expr" => [op | args]}),
    do: List.to_tuple([enum(op, @ops) | Enum.map(args, &template/1)])

  defp template(%{"type" => type} = node) when is_binary(type) do
    %{
      type: type,
      name: node["name"],
      props: Map.new(Map.get(node, "props", %{}), fn {k, v} -> {k, template(v)} end),
      children: Enum.map(Map.get(node, "children", []), &template/1)
    }
  end

  defp template(map) when is_map(map), do: Map.new(map, fn {k, v} -> {k, template(v)} end)
  defp template(list) when is_list(list), do: Enum.map(list, &template/1)
  defp template(value), do: value

  defp enum(value, allowed),
    do:
      Enum.find(allowed, &(Atom.to_string(&1) == value)) ||
        raise(ArgumentError, "unsupported model value")
end
