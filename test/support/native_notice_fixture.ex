defmodule ShopWeb.NativeNoticeFixture do
  @moduledoc "Native component fixture used to verify renderer extension boundaries."
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <aside id={@node.id}>{@state.content["notice"]}</aside>
    """
  end
end
