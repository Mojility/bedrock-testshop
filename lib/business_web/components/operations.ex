defmodule BusinessWeb.Operations do
  @moduledoc """
  Shared presentation patterns for staff workflows. See OPERATIONS.md.

  These components own layout and semantics, never authorization or business writes.
  """
  use BusinessWeb, :html

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, default: nil
  slot :actions
  slot :inner_block, required: true

  def page(assigns) do
    ~H"""
    <section id={@id} aria-labelledby={@id <> "-title"} class="flex flex-col gap-8">
      <header class="flex flex-wrap items-start justify-between gap-4 border-b border-base-300 pb-6">
        <div class="max-w-prose">
          <h1 id={@id <> "-title"} class="text-3xl font-semibold tracking-tight">{@title}</h1>
          <p :if={@description} class="mt-2 leading-relaxed text-base-content/80">{@description}</p>
        </div>
        <div :if={@actions != []} class="flex flex-wrap items-center gap-3">
          {render_slot(@actions)}
        </div>
      </header>
      {render_slot(@inner_block)}
    </section>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, default: nil
  slot :actions
  slot :inner_block, required: true

  def panel(assigns) do
    ~H"""
    <section
      id={@id}
      aria-labelledby={@id <> "-title"}
      class="flex flex-col gap-5 rounded-box border border-base-300 bg-base-100 p-5 sm:p-6"
    >
      <header class="flex flex-wrap items-start justify-between gap-3">
        <div class="max-w-prose">
          <h2 id={@id <> "-title"} class="text-xl font-semibold">{@title}</h2>
          <p :if={@description} class="mt-1 text-sm leading-relaxed text-base-content/80">
            {@description}
          </p>
        </div>
        <div :if={@actions != []} class="flex flex-wrap items-center gap-2">
          {render_slot(@actions)}
        </div>
      </header>
      {render_slot(@inner_block)}
    </section>
    """
  end

  attr :label, :string, required: true
  attr :tone, :string, default: "neutral", values: ~w(neutral success warning error)

  def status(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-2 rounded-full border px-3 py-1 text-sm font-medium",
      @tone == "neutral" && "border-base-300 bg-base-200 text-base-content",
      @tone == "success" && "border-success bg-base-100 text-base-content",
      @tone == "warning" && "border-warning bg-base-100 text-base-content",
      @tone == "error" && "border-error bg-base-100 text-base-content"
    ]}>
      {@label}
    </span>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true
  slot :actions

  def empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-start gap-3 rounded-box bg-base-200 p-6">
      <p class="font-semibold">{@title}</p>
      <p class="max-w-prose text-sm leading-relaxed">{@description}</p>
      <div :if={@actions != []} class="flex flex-wrap gap-3">{render_slot(@actions)}</div>
    </div>
    """
  end

  slot :inner_block, required: true
  slot :help

  def form_actions(assigns) do
    ~H"""
    <div class="mt-6 flex flex-col items-start gap-3 border-t border-base-300 pt-4">
      <div class="flex flex-wrap items-center gap-3">{render_slot(@inner_block)}</div>
      <p :if={@help != []} class="max-w-prose text-sm text-base-content/80">{render_slot(@help)}</p>
    </div>
    """
  end

  slot :item, required: true do
    attr :label, :string, required: true
  end

  def facts(assigns) do
    ~H"""
    <dl class="grid gap-x-6 gap-y-4 sm:grid-cols-2">
      <div :for={item <- @item} class="min-w-0">
        <dt class="text-sm text-base-content/80">{item.label}</dt>
        <dd class="mt-1 break-words">{render_slot(item)}</dd>
      </div>
    </dl>
    """
  end
end
