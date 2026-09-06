defmodule Shop.Website.Node do
  @moduledoc """
  One node of a page tree (`docs/atomic-composition.md`, "The tree, as the
  agent sees it"): an id the agent chose, a registered type, the id of its
  parent (nil at the top of the page), its place among its siblings, and
  its props. Nothing else: what a node looks like is the type's business
  (`Shop.Website.Registry`), and what it is made of, when it is a molecule
  or an organism, is its expansion.

  Ids are short strings: lowercase letters, digits, `-` and `_`, up to 32
  characters, and never containing `__`, which expansion uses to name the
  nodes it makes from a molecule or organism (`hero__heading`).
  """

  @enforce_keys [:id, :type]
  defstruct id: nil, type: nil, parent_id: nil, index: 0, props: %{}

  @type id :: String.t()
  @type t :: %__MODULE__{
          id: id(),
          type: String.t(),
          parent_id: id() | nil,
          index: non_neg_integer(),
          props: %{String.t() => term()}
        }

  @id_format ~r/^[a-z0-9][a-z0-9_-]{0,31}$/
  @reserved ~w(site site-main site-theme)

  @doc "Whether `id` is a well-formed node id the agent may use."
  @spec valid_id?(term()) :: boolean()
  def valid_id?(id) when is_binary(id) do
    Regex.match?(@id_format, id) and not String.contains?(id, "__") and id not in @reserved
  end

  def valid_id?(_id), do: false

  @doc """
  A node from a map with string or atom keys, as the model sends one or as
  the document stores one. Props are stringified a level deep; an absent
  `index` is 0.
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    map = stringify(map)

    %__MODULE__{
      id: map["id"],
      type: map["type"],
      parent_id: blank_to_nil(map["parent_id"]),
      index: map["index"] || 0,
      props: stringify(map["props"] || %{})
    }
  end

  @doc "The node as the document stores it: a string-keyed map without the id."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = node) do
    %{
      "type" => node.type,
      "parent_id" => node.parent_id,
      "index" => node.index,
      "props" => node.props
    }
  end

  @doc "`value` with string keys throughout, lists included."
  @spec stringify(term()) :: term()
  def stringify(map) when is_map(map) and not is_struct(map) do
    Map.new(map, fn {key, value} -> {to_string(key), stringify(value)} end)
  end

  def stringify(list) when is_list(list), do: Enum.map(list, &stringify/1)
  def stringify(other), do: other

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(other), do: other
end
