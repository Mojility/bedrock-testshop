defmodule ShopWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use ShopWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_section, :string, default: nil

  attr :catalogue, :boolean, default: false

  slot :inner_block, required: true

  def app(%{catalogue: true} = assigns) do
    ~H"""
    {render_slot(@inner_block)}
    <.flash_group flash={@flash} />
    """
  end

  def app(assigns) do
    assigns =
      assign(
        assigns,
        :staff_destinations,
        ShopWeb.StaffNavigation.for_scope(assigns.current_scope)
      )

    ~H"""
    <header class="flex flex-wrap items-center justify-between gap-3 border-b border-base-300 bg-base-100 px-4 py-3 sm:px-6 lg:px-8">
      <div class="flex-1">
        <.link navigate={~p"/"} class="text-lg font-semibold">{Shop.name()}</.link>
      </div>
      <nav class="max-w-full" aria-label="Staff navigation">
        <ul class="flex flex-wrap items-center gap-2">
          <%= if @current_scope do %>
            <li :for={destination <- @staff_destinations}>
              <.link
                navigate={destination.path}
                aria-current={if @current_section == destination.id, do: "page"}
                class={[
                  "inline-flex min-h-11 items-center rounded-field px-3 font-medium focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary",
                  @current_section == destination.id && "bg-base-200 text-base-content",
                  @current_section != destination.id && "hover:bg-base-200"
                ]}
              >
                {destination.label}
              </.link>
            </li>
            <li class="hidden sm:block opacity-70">{@current_scope.user.email}</li>
            <li>
              <.link
                href={~p"/users/settings"}
                class="inline-flex min-h-11 items-center px-3 underline"
              >
                Settings
              </.link>
            </li>
            <li>
              <.link
                href={~p"/users/log-out"}
                method="delete"
                class="inline-flex min-h-11 items-center px-3 underline"
              >
                Log out
              </.link>
            </li>
          <% else %>
            <li><.link href={~p"/users/log-in"}>Log in</.link></li>
          <% end %>
          <li><.theme_toggle /></li>
        </ul>
      </nav>
    </header>

    <main class="px-4 py-12 sm:px-6 lg:px-8">
      <div class={[
        "mx-auto flex flex-col gap-4",
        if(@current_scope, do: "max-w-6xl", else: "max-w-2xl")
      ]}>
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex min-h-11 min-w-11 items-center justify-center p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        aria-label="Use system theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex min-h-11 min-w-11 items-center justify-center p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        aria-label="Use light theme"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex min-h-11 min-w-11 items-center justify-center p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        aria-label="Use dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
