defmodule ToolchainConsistencyTest do
  @moduledoc """
  `.tool-versions` is the single statement of this system's toolchain: CI
  reads it, and routine maintenance rewrites it. The Dockerfile's build
  argument defaults must say the same thing, or the released image would be
  built with a toolchain the checks never ran.
  """
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)

  test "Dockerfile toolchain build arguments match .tool-versions" do
    tool_versions = File.read!(Path.join(@root, ".tool-versions"))
    dockerfile = File.read!(Path.join(@root, "Dockerfile"))

    assert BaselineMaintenance.toolchain_mismatches(tool_versions, dockerfile) == []
  end
end
