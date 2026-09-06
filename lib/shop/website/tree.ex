defmodule Shop.Website.Tree do
  @moduledoc """
  A page tree as the agent edits it (`docs/atomic-composition.md`, "The
  tree, as the agent sees it"): a flat map of `Shop.Website.Node`s by id,
  each naming its parent, with flat operations to change it, a nested view
  for rendering and for the model's prompt, and `expand/1`, which turns
  molecules and organisms into the atoms and layouts they are made of.

  The tree is pure data and this module is pure. `Bedrock.Sites` keeps
  trees, and `Shop.Website.Validator` says whether one may be rendered.

  ## Operations

  A turn from the model is a list of operations, each a map with an `op`:

    * `upsert`: `node` (id, type, parent_id, index, props); a new id is
      added, an existing one replaced
    * `remove`: `id`, with its subtree
    * `move`: `id`, `parent_id`, `index`
    * `replace_children`: `id` of the parent and `children` (ordered ids);
      children of the parent not named are removed with their subtrees

  `apply_ops/2` applies them in order and returns the new tree or every
  reason the batch cannot be applied: an id used twice in one batch, a
  parent that does not exist, a move that would put a node inside itself,
  a malformed id. Children are re-indexed 0.. after every batch.
  """
  alias Shop.Website.Node
  alias Shop.Website.Registry
  alias Shop.Website.Template

  @type t :: %{Node.id() => Node.t()}
  @type op :: map()
  @type nested :: %{
          id: Node.id(),
          type: String.t(),
          props: map(),
          children: [nested()]
        }

  @ops ~w(upsert remove move replace_children)

  @doc "The operations a batch may hold."
  @spec ops() :: [String.t()]
  def ops, do: @ops

  @doc "An empty tree."
  @spec new() :: t()
  def new, do: %{}

  @doc "A tree from the map the document stores (`id => node map`)."
  @spec from_stored(map() | nil) :: t()
  def from_stored(nil), do: %{}

  def from_stored(nodes) when is_map(nodes) do
    Map.new(nodes, fn {id, node} -> {id, Node.from_map(Map.put(node, "id", id))} end)
  end

  @doc "The tree as the document stores it."
  @spec to_stored(t()) :: map()
  def to_stored(tree), do: Map.new(tree, fn {id, node} -> {id, Node.to_map(node)} end)

  @doc "A tree from nested nodes (`%{id, type, props, children}`), as a recipe builds one."
  @spec from_nested([map()]) :: t()
  def from_nested(nested) when is_list(nested) do
    nested
    |> Enum.with_index()
    |> Enum.flat_map(fn {node, index} -> flatten(node, nil, index) end)
    |> Map.new(&{&1.id, &1})
  end

  @doc "The tree as nested nodes, top-level nodes in order, children in order."
  @spec to_nested(t()) :: [nested()]
  def to_nested(tree), do: nest(tree, nil)

  @doc """
  Applies `ops` to `tree`. Returns `{:ok, tree}` or `{:error, reasons}` with
  a plain reason per problem; nothing is applied when anything fails.
  """
  @spec apply_ops(t(), [op()]) :: {:ok, t()} | {:error, [String.t()]}
  def apply_ops(tree, ops, extensions \\ %{}) when is_map(tree) and is_list(ops) do
    ops = Enum.map(ops, &Node.stringify/1)

    with [] <- batch_problems(ops),
         {:ok, tree} <- apply_each(tree, ops, extensions) do
      {:ok, reindex(tree)}
    else
      {:error, reasons} -> {:error, reasons}
      reasons when is_list(reasons) -> {:error, reasons}
    end
  end

  @doc """
  The tree with every molecule and organism expanded into the atoms and
  layouts it is made of, as nested nodes. Expanded nodes are named after
  their origin (`hero__0__heading`), so a reason about one can be traced
  back to the node the agent wrote (`origin/1`).
  """
  @spec expand(t() | [nested()]) :: [nested()]
  def expand(tree, extensions \\ %{}, depth \\ 0)

  def expand(_tree, _extensions, depth) when depth > 24,
    do: raise(ArgumentError, "component expansion too deep")

  def expand(tree, extensions, depth) when is_map(tree),
    do: expand(to_nested(tree), extensions, depth)

  def expand(nested, extensions, depth) when is_list(nested),
    do: Enum.flat_map(nested, &expand_node(&1, extensions, depth))

  @doc """
  The tree as compact text for the model's prompt: one node per line,
  indented by depth, as `type#id {props}`.
  """
  @spec to_text(t()) :: String.t()
  def to_text(tree) do
    case to_nested(tree) do
      [] -> "(empty)"
      nested -> nested |> Enum.map(&text_lines(&1, 0)) |> List.flatten() |> Enum.join("\n")
    end
  end

  @doc "The id of the node the agent wrote, for an id `expand/1` made (or the id itself)."
  @spec origin(Node.id()) :: Node.id()
  def origin(id) when is_binary(id), do: id |> String.split("__", parts: 2) |> hd()

  @doc "The ids of `id`'s subtree, itself first."
  @spec subtree_ids(t(), Node.id()) :: [Node.id()]
  def subtree_ids(tree, id) do
    [id | tree |> children_of(id) |> Enum.flat_map(&subtree_ids(tree, &1.id))]
  end

  @doc "The children of `parent_id` (nil for the top level), in order."
  @spec children_of(t(), Node.id() | nil) :: [Node.t()]
  def children_of(tree, parent_id) do
    tree
    |> Map.values()
    |> Enum.filter(&(&1.parent_id == parent_id))
    |> Enum.sort_by(&{&1.index, &1.id})
  end

  # ---- Operations -------------------------------------------------------------

  defp batch_problems(ops) do
    unknown =
      ops
      |> Enum.reject(&(&1["op"] in @ops))
      |> Enum.map(&"unknown operation #{inspect(&1["op"])}; use one of #{Enum.join(@ops, ", ")}")

    duplicates =
      ops
      |> Enum.filter(&(&1["op"] == "upsert"))
      |> Enum.map(&get_in(&1, ["node", "id"]))
      |> Enum.frequencies()
      |> Enum.filter(fn {_id, count} -> count > 1 end)
      |> Enum.map(fn {id, _count} ->
        "id #{inspect(id)} is upserted more than once in one batch"
      end)

    unknown ++ duplicates
  end

  defp apply_each(tree, ops, extensions) do
    Enum.reduce_while(ops, {:ok, tree}, fn op, {:ok, tree} ->
      case apply_op(tree, op, extensions) do
        {:ok, tree} -> {:cont, {:ok, tree}}
        {:error, reasons} -> {:halt, {:error, reasons}}
      end
    end)
  end

  defp apply_op(tree, %{"op" => "upsert", "node" => node_map}, extensions)
       when is_map(node_map) do
    node = Node.from_map(node_map)

    cond do
      not Node.valid_id?(node.id) ->
        {:error, [id_reason(node.id)]}

      not is_binary(node.type) or is_nil(Registry.get(node.type, extensions)) ->
        {:error, ["node #{node.id} has an unknown type #{inspect(node.type)}"]}

      not is_nil(node.parent_id) and not Map.has_key?(tree, node.parent_id) and
          node.parent_id != node.id ->
        {:error, ["node #{node.id} names a parent that does not exist: #{node.parent_id}"]}

      node.parent_id == node.id or node.parent_id in descendant_ids(tree, node.id) ->
        {:error, ["node #{node.id} cannot be its own ancestor"]}

      not is_map(node.props) ->
        {:error, ["node #{node.id} needs props as an object"]}

      not (is_integer(node.index) and node.index >= 0) ->
        {:error, ["node #{node.id}: index must be a whole number from 0"]}

      true ->
        {:ok, Map.put(tree, node.id, %{node | index: index_or_end(tree, node)})}
    end
  end

  defp apply_op(_tree, %{"op" => "upsert"}, _extensions), do: {:error, ["upsert needs a node"]}

  defp apply_op(tree, %{"op" => "remove", "id" => id}, _extensions) do
    if Map.has_key?(tree, id),
      do: {:ok, Map.drop(tree, subtree_ids(tree, id))},
      else: {:error, ["cannot remove #{inspect(id)}: there is no such node"]}
  end

  defp apply_op(_tree, %{"op" => "remove"}, _extensions), do: {:error, ["remove needs an id"]}

  defp apply_op(tree, %{"op" => "move", "id" => id} = op, _extensions) do
    parent_id = blank_to_nil(op["parent_id"])
    index = op["index"]

    cond do
      not Map.has_key?(tree, id) ->
        {:error, ["cannot move #{inspect(id)}: there is no such node"]}

      not is_nil(parent_id) and not Map.has_key?(tree, parent_id) ->
        {:error, ["cannot move #{id} under #{parent_id}: there is no such node"]}

      parent_id in subtree_ids(tree, id) ->
        {:error, ["cannot move #{id} inside itself"]}

      not (is_nil(index) or (is_integer(index) and index >= 0)) ->
        {:error, ["cannot move #{id}: index must be a whole number from 0"]}

      true ->
        node = %{tree[id] | parent_id: parent_id}
        {:ok, Map.put(tree, id, %{node | index: index_or_end(tree, node, index)})}
    end
  end

  defp apply_op(_tree, %{"op" => "move"}, _extensions), do: {:error, ["move needs an id"]}

  defp apply_op(
         tree,
         %{"op" => "replace_children", "id" => id, "children" => children},
         _extensions
       )
       when is_list(children) do
    parent_id = blank_to_nil(id)
    missing = Enum.reject(children, &Map.has_key?(tree, &1))

    cond do
      not is_nil(parent_id) and not Map.has_key?(tree, parent_id) ->
        {:error, ["cannot replace the children of #{inspect(id)}: there is no such node"]}

      missing != [] ->
        {:error, ["cannot place children that do not exist: #{Enum.join(missing, ", ")}"]}

      Enum.uniq(children) != children ->
        {:error, ["the children of #{inspect(id)} name the same id twice"]}

      not is_nil(parent_id) and parent_id in Enum.flat_map(children, &subtree_ids(tree, &1)) ->
        {:error, ["cannot move #{parent_id} inside itself"]}

      true ->
        dropped =
          tree
          |> children_of(parent_id)
          |> Enum.map(& &1.id)
          |> Enum.reject(&(&1 in children))
          |> Enum.flat_map(&subtree_ids(tree, &1))

        tree = Map.drop(tree, dropped)

        placed =
          children
          |> Enum.with_index()
          |> Enum.reduce(tree, fn {child_id, index}, tree ->
            Map.update!(tree, child_id, &%{&1 | parent_id: parent_id, index: index})
          end)

        {:ok, placed}
    end
  end

  defp apply_op(_tree, %{"op" => "replace_children"}, _extensions),
    do: {:error, ["replace_children needs an id and a list of children"]}

  defp id_reason(id) do
    "#{inspect(id)} is not a usable id: use lowercase letters, digits, - and _, up to 32 characters"
  end

  defp descendant_ids(tree, id), do: tree |> subtree_ids(id) |> tl()

  # The place `index` asks for among the node's siblings: before the sibling
  # now at that position, or last when there is none. Provisional (a half
  # step) until the batch is re-indexed.
  defp index_or_end(tree, node, index \\ nil) do
    index = index || node.index || 0
    siblings = tree |> children_of(node.parent_id) |> Enum.reject(&(&1.id == node.id))

    case Enum.at(siblings, index) do
      nil -> (siblings |> List.last() |> then(&((&1 && &1.index) || -1))) + 1
      sibling -> sibling.index - 0.5
    end
  end

  defp reindex(tree) do
    tree
    |> Map.values()
    |> Enum.group_by(& &1.parent_id)
    |> Enum.flat_map(fn {_parent_id, siblings} ->
      siblings
      |> Enum.sort_by(&{&1.index, &1.id})
      |> Enum.with_index()
      |> Enum.map(fn {node, index} -> %{node | index: index} end)
    end)
    |> Map.new(&{&1.id, &1})
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(other), do: other

  # ---- Nesting ----------------------------------------------------------------

  defp nest(tree, parent_id) do
    tree
    |> children_of(parent_id)
    |> Enum.map(fn node ->
      %{id: node.id, type: node.type, props: node.props, children: nest(tree, node.id)}
    end)
  end

  defp flatten(node, parent_id, index) do
    node = Node.stringify(node)
    id = node["id"]

    children =
      node
      |> Map.get("children", [])
      |> Enum.with_index()
      |> Enum.flat_map(fn {child, child_index} -> flatten(child, id, child_index) end)

    [
      %Node{
        id: id,
        type: node["type"],
        parent_id: parent_id,
        index: index,
        props: node["props"] || %{}
      }
      | children
    ]
  end

  # ---- Expansion --------------------------------------------------------------

  # A molecule or organism expands with the defaults its schema declares
  # filled in, so what the catalogue says is the default is what renders.
  defp expand_node(%{type: type} = node, extensions, depth) do
    case Registry.get(type, extensions) do
      %{template: template} = entry when is_map(template) ->
        props = Map.merge(Registry.defaults(entry), node.props)
        rendered = Template.render(template, props, node.children)
        expand([name_expansion(rendered, node.id, node.id)], extensions, depth + 1)

      _atom_or_layout ->
        [%{node | children: expand(node.children, extensions, depth + 1)}]
    end
  end

  # Names every node of a rendered template after its origin: the origin's
  # own id for the root, then `parent__name` or `parent__n` beneath it, so
  # a name is unique among its siblings and the first segment of any id is
  # always the node the agent wrote. Children the agent gave the node
  # (spliced by `{:children}`) keep their own ids.
  defp name_expansion(%{name: _name} = rendered, id, origin) do
    children =
      rendered.children
      |> Enum.with_index()
      |> Enum.map(fn
        {%{id: child_id} = child, _index} when is_binary(child_id) ->
          child

        {child, index} ->
          name_expansion(child, "#{id}__#{child.name || index}", origin)
      end)

    %{id: id, type: rendered.type, props: rendered.props, children: children}
  end

  defp name_expansion(%{id: _id} = agent_node, _id_unused, _origin), do: agent_node

  # ---- Text -------------------------------------------------------------------

  defp text_lines(node, depth) do
    indent = String.duplicate("  ", depth)
    props = node.props |> Enum.sort() |> Enum.map_join(", ", &text_prop/1)
    line = "#{indent}#{node.type}##{node.id}" <> if(props == "", do: "", else: " {#{props}}")
    [line | Enum.map(node.children, &text_lines(&1, depth + 1))]
  end

  defp text_prop({key, value}) when is_binary(value), do: "#{key}: #{inspect(truncate(value))}"
  defp text_prop({key, value}), do: "#{key}: #{Jason.encode!(value)}"

  defp truncate(value) when byte_size(value) > 80, do: String.slice(value, 0, 77) <> "..."
  defp truncate(value), do: value
end
