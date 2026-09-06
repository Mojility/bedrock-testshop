defmodule ShopWeb.NativeNoticeFixture do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <aside id={@node.id}>{@state.content["notice"]}</aside>
    """
  end
end
