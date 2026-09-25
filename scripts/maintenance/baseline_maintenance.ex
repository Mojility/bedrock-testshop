defmodule BaselineMaintenance do
  @moduledoc """
  Applies a Bedrock maintenance baseline to this repository.

  The baseline says what "current" means: the Elixir, Erlang/OTP and
  PostgreSQL versions, the Debian base image, dependency requirements, asset
  tool versions, and vendored third-party files with their release digests.
  Maintenance changes only those declarations. It never adds or removes a
  dependency and never touches the shop's own code, scene, or records.

  This module uses the Elixir standard library only, because it runs before
  the project's dependencies are fetched. `apply_baseline.exs` is its command
  line entry point; `docs/maintenance.md` describes the workflow around it.
  """

  @tool_keys ["elixir", "erlang", "postgres"]
  @max_baseline_bytes 60_000

  @typedoc "A validated baseline, with the string keys of its JSON form."
  @type baseline :: %{required(String.t()) => term()}

  @typedoc "Old and new value of one changed declaration."
  @type change :: [String.t() | nil]

  @typedoc "A function that downloads a URL and returns its body."
  @type fetcher :: (String.t() -> {:ok, binary()} | {:error, term()})

  ## Baseline validation

  @doc """
  Parses and validates a baseline JSON document.

  Returns `{:error, reason}` for anything that is not a well-formed version 1
  baseline; the maintenance run then reports status `invalid`.
  """
  @spec parse_baseline(String.t()) :: {:ok, baseline()} | {:error, String.t()}
  def parse_baseline(json) when byte_size(json) >= @max_baseline_bytes,
    do: {:error, "baseline is larger than #{@max_baseline_bytes} bytes"}

  def parse_baseline(json) do
    case JSON.decode(json) do
      {:ok, %{} = baseline} -> validate_baseline(baseline)
      {:ok, _other} -> {:error, "baseline must be a JSON object"}
      {:error, _reason} -> {:error, "baseline is not valid JSON"}
    end
  end

  defp validate_baseline(baseline) do
    with :ok <- expect(baseline["version"] == 1, "version must be 1"),
         :ok <- expect_match(baseline["template_commit"], ~r/\A[0-9a-f]{40}\z/, "template_commit"),
         :ok <- validate_tool_versions(baseline["tool_versions"]),
         :ok <- expect_match(baseline["debian"], ~r/\A[a-z0-9][a-z0-9.-]{0,63}\z/, "debian"),
         :ok <- validate_requirements(baseline["requirements"]),
         :ok <- validate_asset_tools(baseline["asset_tools"]),
         :ok <- validate_vendored(baseline["vendored"]) do
      {:ok, baseline}
    end
  end

  defp validate_tool_versions(%{"elixir" => elixir, "erlang" => erlang, "postgres" => postgres}) do
    with :ok <-
           expect_match(elixir, ~r/\A\d+\.\d+\.\d+(-rc\.\d+)?-otp-\d+\z/, "tool_versions.elixir"),
         :ok <- expect_match(erlang, ~r/\A\d+(\.\d+){1,3}\z/, "tool_versions.erlang"),
         :ok <- expect_match(postgres, ~r/\A\d+\z/, "tool_versions.postgres") do
      expect(
        otp_major(elixir) == erlang_major(erlang),
        "tool_versions.elixir is built for a different OTP major than tool_versions.erlang"
      )
    end
  end

  defp validate_tool_versions(_other),
    do: {:error, "tool_versions must name elixir, erlang and postgres"}

  defp validate_requirements(%{} = requirements) do
    Enum.reduce_while(requirements, :ok, fn {name, requirement}, :ok ->
      case validate_requirement(name, requirement) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_requirements(_other), do: {:error, "requirements must be an object"}

  defp validate_requirement(name, requirement) do
    with :ok <- expect_match(name, ~r/\A[a-z][a-z0-9_]{0,63}\z/, "requirements key"),
         :ok <- expect(is_binary(requirement), "requirements.#{name} must be a string") do
      case Version.parse_requirement(requirement) do
        {:ok, _} -> :ok
        :error -> {:error, "requirements.#{name} is not a valid version requirement"}
      end
    end
  end

  defp validate_asset_tools(%{} = asset_tools) do
    Enum.reduce_while(asset_tools, :ok, fn {name, version}, :ok ->
      with :ok <- expect_match(name, ~r/\A[a-z][a-z0-9_]{0,63}\z/, "asset_tools key"),
           :ok <- expect_match(version, ~r/\A\d+\.\d+\.\d+\z/, "asset_tools.#{name}") do
        {:cont, :ok}
      else
        error -> {:halt, error}
      end
    end)
  end

  defp validate_asset_tools(_other), do: {:error, "asset_tools must be an object"}

  defp validate_vendored(entries) when is_list(entries) do
    Enum.reduce_while(entries, :ok, fn entry, :ok ->
      case validate_vendored_entry(entry) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_vendored(_other), do: {:error, "vendored must be a list"}

  defp validate_vendored_entry(%{"path" => path, "url" => url, "sha256" => sha256}) do
    with :ok <- expect(safe_relative_path?(path), "vendored path #{inspect(path)} is not allowed"),
         :ok <-
           expect_match(
             url,
             ~r{\Ahttps://github\.com/[\w.-]+/[\w.-]+/releases/download/[\w.+-]+/[\w.+-]+\z},
             "vendored url"
           ) do
      expect_match(sha256, ~r/\A[0-9a-f]{64}\z/, "vendored sha256")
    end
  end

  defp validate_vendored_entry(_other),
    do: {:error, "each vendored entry needs path, url and sha256"}

  defp safe_relative_path?(path) when is_binary(path) do
    segments = Path.split(path)

    path != "" and Path.type(path) == :relative and ".." not in segments and
      "." not in segments and hd(segments) not in [".git", ".github"]
  end

  defp safe_relative_path?(_other), do: false

  defp expect(true, _message), do: :ok
  defp expect(_false, message), do: {:error, message}

  defp expect_match(value, regex, field) when is_binary(value) do
    expect(Regex.match?(regex, value), "#{field} has an invalid value")
  end

  defp expect_match(_value, _regex, field), do: {:error, "#{field} must be a string"}

  defp otp_major(elixir), do: elixir |> String.split("-otp-") |> List.last()
  defp erlang_major(erlang), do: erlang |> String.split(".") |> hd()

  ## Applying a baseline

  @doc """
  Applies a validated baseline to the repository at `root`.

  Every change is computed and every vendored download verified before any
  file is written, so a refusal leaves the repository untouched. Returns the
  declarations that changed, in the `changes` shape of the maintenance result.
  """
  @spec apply_baseline(Path.t(), baseline(), fetcher()) :: {:ok, map()} | {:error, String.t()}
  def apply_baseline(root, baseline, fetch \\ &fetch_https/1) do
    with {:ok, mix_plan} <- plan_mix_exs(root, baseline["requirements"]),
         {:ok, config_plan} <- plan_config(root, baseline["asset_tools"]),
         {:ok, vendored_plan} <- plan_vendored(root, baseline["vendored"], fetch) do
      plans = [
        plan_tool_versions_file(root, baseline["tool_versions"]),
        plan_dockerfile(root, baseline["tool_versions"], baseline["debian"]),
        mix_plan,
        config_plan,
        vendored_plan
      ]

      for {writes, _changes} <- plans, {path, contents} <- writes, do: File.write!(path, contents)

      {:ok, plans |> Enum.map(&elem(&1, 1)) |> Enum.reduce(%{}, &Map.merge/2)}
    end
  end

  defp plan_tool_versions_file(root, tool_versions) do
    path = Path.join(root, ".tool-versions")
    current = read_optional(path)
    {updated, changes} = update_tool_versions(current, tool_versions)
    {writes_if_changed(path, current, updated), %{"tool_versions" => changes}}
  end

  defp plan_dockerfile(root, tool_versions, debian) do
    path = Path.join(root, "Dockerfile")

    case read_optional(path) do
      nil ->
        {[], %{}}

      current ->
        {updated, changes} = update_dockerfile(current, tool_versions, debian)
        {writes_if_changed(path, current, updated), changes}
    end
  end

  defp plan_mix_exs(root, requirements) do
    path = Path.join(root, "mix.exs")

    with {:ok, current} <- read_required(path),
         {:ok, updated, changes} <- update_requirements(current, requirements) do
      {:ok, {writes_if_changed(path, current, updated), %{"requirements" => changes}}}
    end
  end

  defp plan_config(root, asset_tools) do
    path = Path.join([root, "config", "config.exs"])

    with current when is_binary(current) <- read_optional(path),
         {:ok, updated, changes} <- update_asset_tools(current, asset_tools) do
      {:ok, {writes_if_changed(path, current, updated), %{"asset_tools" => changes}}}
    else
      nil -> {:ok, {[], %{"asset_tools" => %{}}}}
      error -> error
    end
  end

  defp plan_vendored(root, entries, fetch) do
    entries
    |> Enum.filter(&File.regular?(Path.join(root, &1["path"])))
    |> Enum.reject(&(sha256_file(Path.join(root, &1["path"])) == &1["sha256"]))
    |> Enum.reduce_while({:ok, {[], %{"vendored" => []}}}, fn entry, {:ok, {writes, changes}} ->
      case fetch_verified(entry, fetch) do
        {:ok, body} ->
          path = Path.join(root, entry["path"])
          changes = Map.update!(changes, "vendored", &(&1 ++ [entry["path"]]))
          {:cont, {:ok, {writes ++ [{path, body}], changes}}}

        error ->
          {:halt, error}
      end
    end)
  end

  defp fetch_verified(%{"url" => url, "sha256" => expected, "path" => path}, fetch) do
    case fetch.(url) do
      {:ok, body} ->
        if sha256(body) == expected,
          do: {:ok, body},
          else: {:error, "refused #{path}: the download from #{url} does not match its sha256"}

      {:error, reason} ->
        {:error, "could not download #{url} for #{path}: #{inspect(reason)}"}
    end
  end

  defp writes_if_changed(_path, same, same), do: []
  defp writes_if_changed(path, _current, updated), do: [{path, updated}]

  defp read_optional(path) do
    case File.read(path) do
      {:ok, contents} -> contents
      {:error, _reason} -> nil
    end
  end

  defp read_required(path) do
    case File.read(path) do
      {:ok, contents} -> {:ok, contents}
      {:error, reason} -> {:error, "cannot read #{path}: #{:file.format_error(reason)}"}
    end
  end

  defp sha256_file(path), do: path |> File.read!() |> sha256()
  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)

  @doc """
  Downloads an HTTPS URL, verifying the server certificate against the
  operating system's trust store.
  """
  @spec fetch_https(String.t()) :: {:ok, binary()} | {:error, term()}
  def fetch_https(url) do
    {:ok, _started} = Application.ensure_all_started([:inets, :ssl])

    ssl = [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      depth: 4,
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]

    request = {String.to_charlist(url), [{~c"user-agent", ~c"bedrock-maintenance"}]}

    case :httpc.request(:get, request, [ssl: ssl, timeout: 120_000], body_format: :binary) do
      {:ok, {{_version, 200, _reason}, _headers, body}} -> {:ok, body}
      {:ok, {{_version, status, _reason}, _headers, _body}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  ## .tool-versions and Dockerfile

  @doc """
  Sets the elixir, erlang and postgres lines of a `.tool-versions` file.

  Other lines and comments are kept; missing lines are appended. `nil`
  contents stand for a repository without the file.
  """
  @spec update_tool_versions(String.t() | nil, map()) :: {String.t(), %{String.t() => change()}}
  def update_tool_versions(contents, tool_versions) do
    lines =
      if contents in [nil, ""],
        do: [],
        else: String.split(String.trim_trailing(contents, "\n"), "\n")

    current = parse_tool_versions(contents || "")

    updated_lines =
      Enum.map(lines, fn line ->
        case String.split(line) do
          [tool | _rest] when tool in @tool_keys -> "#{tool} #{tool_versions[tool]}"
          _other -> line
        end
      end)

    appended =
      for tool <- @tool_keys,
          not Map.has_key?(current, tool),
          do: "#{tool} #{tool_versions[tool]}"

    changes =
      for tool <- @tool_keys, current[tool] != tool_versions[tool], into: %{} do
        {tool, [current[tool], tool_versions[tool]]}
      end

    {Enum.join(updated_lines ++ appended, "\n") <> "\n", changes}
  end

  @doc "Parses `.tool-versions` into a map of tool name to its first version."
  @spec parse_tool_versions(String.t()) :: %{String.t() => String.t()}
  def parse_tool_versions(contents) do
    for line <- String.split(contents, "\n"),
        [tool, version | _rest] <- [String.split(line)],
        not String.starts_with?(tool, "#"),
        into: %{},
        do: {tool, version}
  end

  @doc """
  Sets the Dockerfile's `ELIXIR_VERSION`, `OTP_VERSION` and `DEBIAN_VERSION`
  build argument defaults. An argument the Dockerfile does not declare is
  left alone.
  """
  @spec update_dockerfile(String.t(), map(), String.t()) :: {String.t(), map()}
  def update_dockerfile(contents, tool_versions, debian) do
    wanted = dockerfile_values(tool_versions, debian)
    current = dockerfile_args(contents)

    updated =
      for {arg, value} <- wanted, value != nil, reduce: contents do
        acc -> Regex.replace(~r/^(ARG #{arg}=)\S*$/m, acc, "\\g{1}#{value}")
      end

    changes =
      case {current["DEBIAN_VERSION"], debian} do
        {nil, _debian} -> %{}
        {same, same} -> %{}
        {old, new} -> %{"debian" => [old, new]}
      end

    {updated, changes}
  end

  @doc "Reads the build argument defaults declared with `ARG NAME=value`."
  @spec dockerfile_args(String.t()) :: %{String.t() => String.t()}
  def dockerfile_args(contents) do
    ~r/^ARG ([A-Z_]+)=(\S+)$/m
    |> Regex.scan(contents, capture: :all_but_first)
    |> Map.new(fn [name, value] -> {name, value} end)
  end

  defp dockerfile_values(tool_versions, debian) do
    %{
      "ELIXIR_VERSION" => elixir_release(tool_versions["elixir"]),
      "OTP_VERSION" => tool_versions["erlang"],
      "DEBIAN_VERSION" => debian
    }
  end

  defp elixir_release(nil), do: nil
  defp elixir_release(elixir), do: elixir |> String.split("-otp-") |> hd()

  @doc """
  Lists the ways the Dockerfile's toolchain defaults differ from
  `.tool-versions`. An empty list means they agree.
  """
  @spec toolchain_mismatches(String.t(), String.t()) :: [String.t()]
  def toolchain_mismatches(tool_versions_contents, dockerfile_contents) do
    tools = parse_tool_versions(tool_versions_contents)
    args = dockerfile_args(dockerfile_contents)

    missing =
      for tool <- @tool_keys,
          not Map.has_key?(tools, tool),
          do: ".tool-versions has no #{tool} line"

    drift =
      for {arg, expected} <- dockerfile_values(tools, args["DEBIAN_VERSION"]),
          expected != nil,
          args[arg] != expected,
          do: "Dockerfile ARG #{arg}=#{args[arg]} does not match .tool-versions (#{expected})"

    otp =
      with elixir when is_binary(elixir) <- tools["elixir"],
           erlang when is_binary(erlang) <- tools["erlang"],
           false <- otp_major(elixir) == erlang_major(erlang) do
        [".tool-versions elixir #{elixir} is not built for erlang #{erlang}"]
      else
        _agree_or_missing -> []
      end

    missing ++ drift ++ otp
  end

  ## mix.exs requirements

  @doc """
  Rewrites dependency requirements in a `mix.exs` source.

  Only the requirement string literals inside the tuples of `deps/0` change,
  byte for byte; options, comments and layout are preserved. A dependency the
  baseline names takes the baseline requirement. Any other patch-level
  requirement (`~> a.b.c`) is loosened to `~> a.b`. Dependencies are never
  added or removed.
  """
  @spec update_requirements(String.t(), %{String.t() => String.t()}) ::
          {:ok, String.t(), %{String.t() => change()}} | {:error, String.t()}
  def update_requirements(source, requirements) do
    with {:ok, deps} <- dependency_requirements(source) do
      edits =
        for {name, requirement, position} <- deps,
            wanted = wanted_requirement(name, requirement, requirements),
            wanted != requirement,
            do: {name, requirement, wanted, position}

      apply_edits(source, edits)
    end
  end

  defp wanted_requirement(name, requirement, requirements) do
    case Map.fetch(requirements, name) do
      {:ok, wanted} -> wanted
      :error -> loosen_patch_requirement(requirement)
    end
  end

  @doc """
  Loosens a patch-level requirement: `~> 1.1.0` becomes `~> 1.1`. Other
  requirements are returned unchanged.
  """
  @spec loosen_patch_requirement(String.t()) :: String.t()
  def loosen_patch_requirement(requirement) do
    case Regex.run(~r/\A~>\s*(\d+)\.(\d+)\.\d+\z/, requirement) do
      [_all, major, minor] -> "~> #{major}.#{minor}"
      nil -> requirement
    end
  end

  @doc """
  Lists `{name, requirement, {line, column}}` for each dependency in `deps/0`
  that declares its requirement as a plain string literal.
  """
  @spec dependency_requirements(String.t()) ::
          {:ok, [{String.t(), String.t(), {pos_integer(), pos_integer()}}]} | {:error, String.t()}
  def dependency_requirements(source) do
    with {:ok, ast} <- parse_source(source, "mix.exs"),
         {:ok, entries} <- deps_list(ast) do
      {:ok, Enum.flat_map(entries, &dependency_requirement/1)}
    end
  end

  defp deps_list(ast) do
    {_ast, bodies} =
      Macro.prewalk(ast, [], fn
        {kind, _meta, [{:deps, _, args}, body]} = node, acc
        when kind in [:def, :defp] and args in [nil, []] ->
          {node, [body | acc]}

        node, acc ->
          {node, acc}
      end)

    with [body] <- bodies,
         {:ok, expression} <- keyword_value(body, :do),
         entries when is_list(entries) <- unwrap(expression) do
      {:ok, entries}
    else
      _other -> {:error, "mix.exs deps/0 must be defined once and return a list literal"}
    end
  end

  defp dependency_requirement(entry) do
    case unwrap(entry) do
      {name, requirement} -> requirement_entry(name, requirement)
      {:{}, _meta, [name, requirement | _options]} -> requirement_entry(name, requirement)
      _other -> []
    end
  end

  defp requirement_entry({:__block__, _, [name]}, {:__block__, meta, [requirement]})
       when is_atom(name) and is_binary(requirement) do
    if meta[:delimiter] == "\"",
      do: [{Atom.to_string(name), requirement, {meta[:line], meta[:column]}}],
      else: []
  end

  defp requirement_entry(_name, _requirement), do: []

  ## config.exs asset tools

  @doc """
  Sets `version:` in `config :tool, version: "..."` for each asset tool the
  baseline names. Tools the configuration does not declare are left alone.
  """
  @spec update_asset_tools(String.t(), %{String.t() => String.t()}) ::
          {:ok, String.t(), %{String.t() => change()}} | {:error, String.t()}
  def update_asset_tools(source, asset_tools) do
    with {:ok, ast} <- parse_source(source, "config/config.exs") do
      {_ast, found} = Macro.prewalk(ast, [], &collect_tool_version/2)

      edits =
        for {tool, version, position} <- found,
            wanted = asset_tools[tool],
            wanted not in [nil, version],
            do: {tool, version, wanted, position}

      apply_edits(source, edits)
    end
  end

  defp collect_tool_version({:config, _meta, [app, options]} = node, acc) do
    with {:__block__, _, [tool]} when is_atom(tool) <- app,
         {:ok, {:__block__, meta, [version]}} when is_binary(version) <-
           keyword_value(options, :version),
         "\"" <- meta[:delimiter] do
      {node, [{Atom.to_string(tool), version, {meta[:line], meta[:column]}} | acc]}
    else
      _other -> {node, acc}
    end
  end

  defp collect_tool_version(node, acc), do: {node, acc}

  ## Source parsing and splicing

  defp parse_source(source, name) do
    encoder = fn literal, meta -> {:ok, {:__block__, meta, [literal]}} end

    case Code.string_to_quoted(source,
           columns: true,
           token_metadata: true,
           literal_encoder: encoder,
           emit_warnings: false
         ) do
      {:ok, ast} -> {:ok, ast}
      {:error, _reason} -> {:error, "cannot parse #{name}"}
    end
  end

  defp keyword_value(list, key) do
    list
    |> unwrap()
    |> List.wrap()
    |> Enum.find_value(:error, fn
      {{:__block__, _, [^key]}, value} -> {:ok, value}
      _other -> nil
    end)
  end

  # Lists and 2-tuples arrive wrapped by the literal encoder.
  defp unwrap({:__block__, _meta, [literal]}) when is_list(literal) or is_tuple(literal),
    do: literal

  defp unwrap(other), do: other

  # Applies `{name, old, new, position}` edits and reports them as changes.
  defp apply_edits(source, edits) do
    changes = Map.new(edits, fn {name, old, new, _position} -> {name, [old, new]} end)

    case splice(
           source,
           Enum.map(edits, fn {_name, old, new, position} -> {position, old, new} end)
         ) do
      {:ok, updated} -> {:ok, updated, changes}
      error -> error
    end
  end

  # Replaces string literals at known positions. Each edit names the literal
  # it expects, so a position that does not hold exactly `"old"` is refused
  # rather than guessed at.
  defp splice(source, []), do: {:ok, source}

  defp splice(source, edits) do
    lines = String.split(source, "\n")

    edits
    |> Enum.sort_by(fn {{line, column}, _old, _new} -> {line, -column} end)
    |> Enum.reduce_while({:ok, lines}, fn {{line, column}, old, new}, {:ok, acc} ->
      text = Enum.at(acc, line - 1)
      token = ~s("#{old}")
      offset = column - 1

      if String.slice(text, offset, String.length(token)) == token do
        replaced =
          String.slice(text, 0, offset) <>
            ~s("#{new}") <> String.slice(text, (offset + String.length(token))..-1//1)

        {:cont, {:ok, List.replace_at(acc, line - 1, replaced)}}
      else
        {:halt, {:error, "unexpected source at line #{line}, column #{column}; refusing to edit"}}
      end
    end)
    |> case do
      {:ok, updated} -> {:ok, Enum.join(updated, "\n")}
      error -> error
    end
  end

  ## Lock files and outdated reports

  @doc """
  Reads locked versions from a `mix.lock` source: the version of each Hex
  package and the short revision of each Git dependency.
  """
  @spec lock_versions(String.t()) :: %{String.t() => String.t()}
  def lock_versions(source) do
    case Code.string_to_quoted(source, emit_warnings: false) do
      {:ok, {:%{}, _meta, pairs}} ->
        Map.new(pairs, fn {name, entry} -> {to_string(name), locked_version(entry)} end)

      _empty_or_unreadable ->
        %{}
    end
  end

  defp locked_version({:{}, _meta, [:hex, _name, version | _rest]}), do: version

  defp locked_version({:{}, _meta, [:git, _url, revision | _rest]}),
    do: String.slice(revision, 0, 7)

  defp locked_version(_other), do: nil

  @doc "Pairs old and new versions of every locked dependency that changed."
  @spec diff_versions(map(), map()) :: %{String.t() => change()}
  def diff_versions(before, later) do
    for name <- Enum.uniq(Map.keys(before) ++ Map.keys(later)),
        before[name] != later[name],
        into: %{},
        do: {name, [before[name], later[name]]}
  end

  @doc """
  Reads `mix hex.outdated` output and lists the dependencies that cannot
  update because of a requirement the baseline does not cover.
  """
  @spec blocked_requirements(String.t(), String.t(), map()) :: [map()]
  def blocked_requirements(outdated_output, mix_exs_source, baseline_requirements) do
    declared =
      case dependency_requirements(mix_exs_source) do
        {:ok, deps} -> Map.new(deps, fn {name, requirement, _position} -> {name, requirement} end)
        {:error, _reason} -> %{}
      end

    for row <- outdated_rows(outdated_output),
        row["status"] == "Update not possible",
        not Map.has_key?(baseline_requirements, row["name"]) do
      %{
        "name" => row["name"],
        "current" => row["current"],
        "latest" => row["latest"],
        "requirement" => declared[row["name"]]
      }
    end
  end

  defp outdated_rows(output) do
    lines = output |> String.replace(~r/\e\[[0-9;]*m/, "") |> String.split("\n")

    case Enum.split_while(lines, &(not String.starts_with?(&1, "Dependency "))) do
      {_before, [header | rows]} ->
        columns = Map.new(~w(Current Latest Status), &{&1, column_offset(header, &1)})

        rows
        |> Enum.take_while(&(String.trim(&1) != ""))
        |> Enum.map(&outdated_row(&1, columns))

      {_all, []} ->
        []
    end
  end

  defp column_offset(header, title) do
    {offset, _length} = :binary.match(header, title)
    offset
  end

  defp outdated_row(line, columns) do
    field = fn from, to -> line |> binary_slice(from, max(to - from, 0)) |> String.trim() end

    %{
      "name" => line |> String.split() |> hd(),
      "current" => field.(columns["Current"], columns["Latest"]),
      "latest" => field.(columns["Latest"], columns["Status"]),
      "status" => field.(columns["Status"], byte_size(line))
    }
  end

  ## Quality gate

  @doc """
  Expands the project's `quality` alias into the mix commands it runs, so
  maintenance can run and name each gate separately. An entry without
  arguments that names another alias (such as `quality.security`) is
  expanded in place; an alias is never expanded inside itself.
  """
  @spec quality_gates(keyword()) :: [String.t()]
  def quality_gates(aliases), do: expand_alias(aliases, :quality, [])

  defp expand_alias(aliases, name, visited) do
    aliases
    |> Keyword.get(name, [])
    |> List.wrap()
    |> Enum.flat_map(&expand_gate(&1, aliases, [name | visited]))
  end

  defp expand_gate(task, aliases, visited) when is_binary(task) do
    nested = Enum.find(Keyword.keys(aliases), &(Atom.to_string(&1) == task))

    if nested && nested not in visited,
      do: expand_alias(aliases, nested, visited),
      else: [task]
  end

  defp expand_gate(task, _aliases, _visited) do
    raise ArgumentError, "quality alias entry #{inspect(task)} is not a mix command string"
  end

  ## Commit message

  @doc "Summarises changes as a commit message."
  @spec commit_message(String.t(), map()) :: String.t()
  def commit_message(maintenance_id, changes) do
    sections = [
      version_section(
        "Toolchain",
        Map.merge(changes["tool_versions"] || %{}, Map.take(changes, ["debian"]))
      ),
      version_section("Requirements", changes["requirements"]),
      version_section("Dependencies", changes["dependencies"]),
      version_section("Asset tools", changes["asset_tools"]),
      list_section("Vendored assets", changes["vendored"])
    ]

    Enum.join(
      ["Routine maintenance #{maintenance_id}" | Enum.reject(sections, &is_nil/1)],
      "\n\n"
    ) <>
      "\n"
  end

  defp version_section(_title, entries) when entries in [nil, %{}], do: nil

  defp version_section(title, entries) do
    lines =
      for {name, [old, new]} <- Enum.sort(entries),
          do: "#{name}: #{old || "none"} -> #{new || "removed"}"

    list_section(title, lines)
  end

  defp list_section(_title, items) when items in [nil, []], do: nil

  defp list_section(title, items),
    do: Enum.join(["#{title}:" | Enum.map(items, &"- #{&1}")], "\n")

  ## Command line

  @doc """
  Runs one command-line invocation and returns `{exit_status, output}`.

  Exit status 0 is success, 1 a refused or failed operation, and 2 an
  invalid baseline or usage error.
  """
  @spec run([String.t()], fetcher()) :: {non_neg_integer(), String.t()}
  def run(argv, fetch \\ &fetch_https/1)

  def run(["apply" | args], fetch) do
    {opts, _rest} = OptionParser.parse!(args, strict: [baseline: :string, root: :string])
    root = opts[:root] || "."

    with {:ok, json} <- read_argument_file(opts[:baseline]),
         {:ok, baseline} <- parse_baseline(json) do
      case apply_baseline(root, baseline, fetch) do
        {:ok, changes} -> {0, JSON.encode!(changes)}
        {:error, reason} -> {1, reason}
      end
    else
      {:error, reason} -> {2, "invalid baseline: #{reason}"}
    end
  end

  def run(["lock-diff", before_path, after_path], _fetch) do
    before = lock_versions(read_optional(before_path) || "")
    later = lock_versions(read_optional(after_path) || "")
    {0, JSON.encode!(diff_versions(before, later))}
  end

  def run(["blocked" | args], _fetch) do
    {opts, _rest} =
      OptionParser.parse!(args, strict: [baseline: :string, outdated: :string, root: :string])

    with {:ok, json} <- read_argument_file(opts[:baseline]),
         {:ok, baseline} <- parse_baseline(json),
         {:ok, mix_exs} <- read_required(Path.join(opts[:root] || ".", "mix.exs")) do
      outdated = read_optional(opts[:outdated] || "") || ""
      {0, JSON.encode!(blocked_requirements(outdated, mix_exs, baseline["requirements"]))}
    else
      {:error, reason} -> {2, reason}
    end
  end

  def run(["commit-message", maintenance_id, changes_path], _fetch) do
    with {:ok, json} <- read_argument_file(changes_path),
         {:ok, changes} <- JSON.decode(json) do
      {0, commit_message(maintenance_id, changes)}
    else
      _error -> {2, "cannot read changes from #{changes_path}"}
    end
  end

  def run(["check-toolchain" | args], _fetch) do
    {opts, _rest} = OptionParser.parse!(args, strict: [root: :string])
    root = opts[:root] || "."

    case toolchain_mismatches(
           read_optional(Path.join(root, ".tool-versions")) || "",
           read_optional(Path.join(root, "Dockerfile")) || ""
         ) do
      [] -> {0, "Dockerfile toolchain matches .tool-versions"}
      mismatches -> {1, Enum.join(mismatches, "\n")}
    end
  end

  def run(_argv, _fetch) do
    {2,
     """
     usage: elixir scripts/maintenance/apply_baseline.exs COMMAND
       apply --baseline FILE [--root DIR]
       lock-diff BEFORE_LOCK AFTER_LOCK
       blocked --baseline FILE --outdated FILE [--root DIR]
       commit-message MAINTENANCE_ID CHANGES_FILE
       check-toolchain [--root DIR]
     """}
  end

  defp read_argument_file(nil), do: {:error, "a file argument is required"}
  defp read_argument_file(path), do: read_required(path)

  @doc "Entry point for `apply_baseline.exs`: runs, prints, and halts."
  @spec main([String.t()]) :: no_return()
  def main(argv) do
    {status, output} = run(argv)
    device = if status == 0, do: :stdio, else: :stderr
    IO.puts(device, output)
    System.halt(status)
  end
end
