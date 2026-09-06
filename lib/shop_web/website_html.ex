defmodule ShopWeb.WebsiteHTML do
  @moduledoc """
  The renderer for a shop's website (`docs/atomic-composition.md`,
  "Rendering"): a walker over the page tree with one function component
  per atom and per layout. Molecules and organisms are expanded first
  (`Shop.Website.Tree.expand/1`) and render as what they are made of.
  Every element carries its level and type as `data-level` and
  `data-type`, and its token references as `data-*` attributes; the
  stylesheet (`site.css`) keys on those and on the `--t-*` tokens and
  never on a section by name, so a section the agent invents renders
  exactly as well as a named one.

  This is the page a customer of the shop sees. It shares nothing with the
  marketing site or the console: its own stylesheet, its own fonts, and
  the theme's tokens injected inline. The one piece of state it renders is
  the lead form's: the form, its errors, a thank-you after a lead, a note
  when it is closed to an address, and a disabled form in the preview.
  `photos` (the shop's ready photos by id, `Bedrock.Media.ready_photos_by_id/1`)
  is what an `image` atom's `photo` prop resolves against.
  """
  use Phoenix.Component
  import Phoenix.HTML
  import Plug.CSRFProtection, only: [get_csrf_token: 0]
  import ShopWeb.CoreComponents, only: [translate_error: 1]

  alias Shop.Website.Document
  alias Shop.Website.Media
  alias Shop.Website.Media, as: Photo
  alias Shop.Website.Tokens
  alias Shop.Website.Tree

  @icons %{
    "phone" =>
      "M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z",
    "mail" => "M4 6h16v12H4z M4 7l8 6 8-6",
    "clock" => "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z M12 8v5l3 2",
    "map_pin" =>
      "M12 21s-7-6.5-7-11a7 7 0 0 1 14 0c0 4.5-7 11-7 11z M12 12a2 2 0 1 0 0-4 2 2 0 0 0 0 4z",
    "check" => "M5 13l4 4L19 7",
    "wrench" => "M14.5 6.5a4 4 0 0 0 5 5l-9 9a2 2 0 0 1-3-3l9-9a4 4 0 0 1-2-2z",
    "shield" => "M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z",
    "star" => "M12 3l2.8 5.7 6.2.9-4.5 4.4 1 6.2L12 17.3 6.5 20.2l1-6.2L3 9.6l6.2-.9z",
    "bolt" => "M13 2L4 14h7l-1 8 9-12h-7z",
    "flame" => "M12 22c4 0 7-3 7-7 0-3-2-5-3-7-1 2-2 3-3 3 0-3-1-6-3-8-1 4-5 6-5 12 0 4 3 7 7 7z",
    "droplet" => "M12 3s6 6.5 6 11a6 6 0 0 1-12 0c0-4.5 6-11 6-11z",
    "thermometer" => "M10 14V5a2 2 0 1 1 4 0v9a4 4 0 1 1-4 0z",
    "truck" =>
      "M2 7h11v9H2z M13 10h5l3 3v3h-8z M6 19a2 2 0 1 0 0-4 2 2 0 0 0 0 4z M17 19a2 2 0 1 0 0-4 2 2 0 0 0 0 4z",
    "calendar" => "M4 6h16v14H4z M4 10h16 M8 3v5 M16 3v5",
    "alert" => "M12 3l10 18H2z M12 10v4 M12 17v1",
    "arrow_right" => "M4 12h16 M13 5l7 7-7 7",
    "info" => "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z M12 11v5 M12 8v1"
  }

  @heading_styles %{1 => "display_xl", 2 => "heading", 3 => "subheading"}

  @doc "The controller template: the whole page, shell and all."
  attr :document, :map, required: true
  attr :theme, :map, required: true
  attr :lead_form, Phoenix.HTML.Form, required: true
  attr :csrf_token, :any, default: true
  attr :sent, :boolean, default: false
  attr :refused, :boolean, default: false
  attr :photos, :map, default: %{}

  attr :native_components, :map, default: %{}
  attr :content, :map, default: %{}

  def show(assigns) do
    # Rendered by the controller with a plain map, so no change tracking.
    assigns = Map.put(assigns, :tokens, Tokens.derive(assigns.theme))

    ~H"""
    <.site_layout title={title(@document)} description={description(@document)} tokens={@tokens}>
      <.site_page
        document={@document}
        theme={@theme}
        lead_form={@lead_form}
        csrf_token={@csrf_token}
        sent={@sent}
        refused={@refused}
        photos={@photos}
        native_components={@native_components}
        content={@content}
      />
    </.site_layout>
    """
  end

  @doc """
  The root layout for the console's preview LiveView: the same shell, with
  the LiveView client so the page follows the draft. The tokens are
  rendered by the LiveView itself, since they change.
  """
  def preview_root(assigns) do
    ~H"""
    <.site_layout title={assigns[:page_title] || "Preview"} live>
      {@inner_content}
    </.site_layout>
    """
  end

  @doc """
  The HTML shell around a site: the title, the meta description, the
  tokens inline, and the site stylesheet. Nothing from the marketing
  layout. With `live`, also what LiveView needs.
  """
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :tokens, :map, default: nil
  attr :live, :boolean, default: false
  slot :inner_block, required: true

  def site_layout(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta :if={@live} name="csrf-token" content={get_csrf_token()} />
        <title>{@title}</title>
        <meta :if={@description} name="description" content={@description} />
        <.tokens_style :if={@tokens} tokens={@tokens} />
        <link rel="stylesheet" href="/assets/published/site.css" />
        <script :if={@live} defer type="text/javascript" src="/assets/app.js">
        </script>
      </head>
      <body>
        {render_slot(@inner_block)}
      </body>
    </html>
    """
  end

  @doc "The tokens as an inline `:root` block. Its values are engine-made, never typed by anyone."
  attr :tokens, :map, required: true

  def tokens_style(assigns) do
    ~H"""
    <style id="site-tokens">
      <%= raw(Tokens.to_css(@tokens)) %>
    </style>
    """
  end

  @doc """
  The site itself: `<main>` holding every top-level node but the footer
  bands, then those. With `preview`, the lead form is shown but inert.
  """
  attr :document, :map, required: true
  attr :theme, :map, required: true
  attr :lead_form, Phoenix.HTML.Form, required: true
  attr :csrf_token, :any, default: true
  attr :sent, :boolean, default: false
  attr :refused, :boolean, default: false
  attr :preview, :boolean, default: false
  attr :photos, :map, default: %{}, doc: "the shop's ready photos by id"

  attr :native_components, :map, default: %{}
  attr :content, :map, default: %{}

  def site_page(assigns) do
    extensions = Document.components(assigns.document)

    extensions =
      Map.new(extensions, fn {name, entry} ->
        {name,
         if(Map.has_key?(assigns.native_components, name),
           do: %{entry | template: nil},
           else: entry
         )}
      end)

    {footers, body} =
      assigns.document
      |> Document.tree()
      |> Tree.expand(extensions)
      |> Enum.split_with(&footer?/1)

    assigns =
      assigns
      |> assign(:body, body)
      |> assign(:footers, footers)
      |> assign(
        :state,
        Map.take(assigns, [
          :lead_form,
          :csrf_token,
          :sent,
          :refused,
          :preview,
          :photos,
          :native_components,
          :content
        ])
      )

    ~H"""
    <div id="site" class="site">
      <main id="site-main">
        <.render_node :for={node <- @body} node={node} state={@state} />
      </main>
      <.render_node :for={node <- @footers} node={node} state={@state} />
    </div>
    """
  end

  defp footer?(%{type: "band", props: %{"landmark" => "footer"}}), do: true
  defp footer?(_node), do: false

  # ---- The walker -------------------------------------------------------------

  attr :node, :map, required: true
  attr :state, :map, required: true

  defp render_node(%{node: %{type: type}} = assigns) do
    case Map.fetch(assigns.state.native_components, type) do
      {:ok, render} -> render.(assigns)
      :error -> builtin_node(assigns)
    end
  end

  defp builtin_node(%{node: %{type: "band"}} = assigns), do: band(assigns)
  defp builtin_node(%{node: %{type: "container"}} = assigns), do: container(assigns)
  defp builtin_node(%{node: %{type: "stack"}} = assigns), do: stack(assigns)
  defp builtin_node(%{node: %{type: "cluster"}} = assigns), do: cluster(assigns)
  defp builtin_node(%{node: %{type: "grid"}} = assigns), do: grid(assigns)
  defp builtin_node(%{node: %{type: "split"}} = assigns), do: split(assigns)
  defp builtin_node(%{node: %{type: "card"}} = assigns), do: card(assigns)
  defp builtin_node(%{node: %{type: "center"}} = assigns), do: center(assigns)
  defp builtin_node(%{node: %{type: "form"}} = assigns), do: lead_form(assigns)
  defp builtin_node(%{node: %{type: "text"}} = assigns), do: text(assigns)
  defp builtin_node(%{node: %{type: "heading"}} = assigns), do: heading(assigns)
  defp builtin_node(%{node: %{type: "button"}} = assigns), do: button_atom(assigns)
  defp builtin_node(%{node: %{type: "link"}} = assigns), do: link_atom(assigns)
  defp builtin_node(%{node: %{type: "icon"}} = assigns), do: icon_atom(assigns)
  defp builtin_node(%{node: %{type: "image"}} = assigns), do: image(assigns)
  defp builtin_node(%{node: %{type: "badge"}} = assigns), do: badge(assigns)
  defp builtin_node(%{node: %{type: "divider"}} = assigns), do: divider(assigns)
  defp builtin_node(%{node: %{type: "input"}} = assigns), do: input_atom(assigns)
  defp builtin_node(%{node: %{type: "textarea"}} = assigns), do: textarea_atom(assigns)
  defp builtin_node(%{node: %{type: "select"}} = assigns), do: select_atom(assigns)
  defp builtin_node(%{node: %{type: "numeral"}} = assigns), do: numeral(assigns)
  defp builtin_node(%{node: %{type: "quote_mark"}} = assigns), do: quote_mark(assigns)

  defp builtin_node(_assigns), do: raise(ArgumentError, "unregistered website component")

  attr :nodes, :list, required: true
  attr :state, :map, required: true

  defp children(assigns) do
    ~H"""
    <.render_node :for={child <- @nodes} node={child} state={@state} />
    """
  end

  # ---- Layouts ----------------------------------------------------------------

  # A band may carry one of the owner's photos behind it (the band hero):
  # the photo fills the band and the words sit on a panel in front.
  defp band(%{node: %{props: props}, state: state} = assigns) do
    assigns =
      assigns
      |> assign(:footer?, props["landmark"] == "footer")
      |> assign(:backdrop, Map.get(state.photos || %{}, props["photo"]))

    ~H"""
    <%= if @footer? do %>
      <footer
        id={@node.id}
        data-level="layout"
        data-type="band"
        data-surface={@node.props["surface"] || "bg"}
        data-padding={@node.props["padding"] || "s8"}
      >
        <.children nodes={@node.children} state={@state} />
      </footer>
    <% else %>
      <section
        id={@node.id}
        data-level="layout"
        data-type="band"
        data-surface={@node.props["surface"] || "bg"}
        data-padding={@node.props["padding"] || "s8"}
        data-photo={@backdrop && @backdrop.id}
      >
        <img
          :if={@backdrop}
          data-backdrop
          src={Media.url(@backdrop, :large)}
          srcset={srcset(@backdrop)}
          sizes="100vw"
          width={variant_width(@backdrop, :large)}
          height={variant_height(@backdrop, :large)}
          alt=""
          aria-hidden="true"
          decoding="async"
        />
        <.children nodes={@node.children} state={@state} />
      </section>
    <% end %>
    """
  end

  defp container(assigns) do
    ~H"""
    <div
      id={@node.id}
      data-level="layout"
      data-type="container"
      data-width={@node.props["width"] || "standard"}
    >
      <.children nodes={@node.children} state={@state} />
    </div>
    """
  end

  defp stack(assigns) do
    ~H"""
    <div
      id={@node.id}
      data-level="layout"
      data-type="stack"
      data-gap={@node.props["gap"] || "s5"}
      data-align={@node.props["align"]}
    >
      <.children nodes={@node.children} state={@state} />
    </div>
    """
  end

  defp cluster(assigns) do
    ~H"""
    <div
      id={@node.id}
      data-level="layout"
      data-type="cluster"
      data-gap={@node.props["gap"] || "s4"}
      data-justify={@node.props["justify"]}
      data-align={@node.props["align"]}
    >
      <.children nodes={@node.children} state={@state} />
    </div>
    """
  end

  defp grid(assigns) do
    ~H"""
    <div
      id={@node.id}
      data-level="layout"
      data-type="grid"
      data-columns={@node.props["columns"]}
      data-gap={@node.props["gap"] || "s5"}
    >
      <.children nodes={@node.children} state={@state} />
    </div>
    """
  end

  defp split(assigns) do
    ~H"""
    <div
      id={@node.id}
      data-level="layout"
      data-type="split"
      data-ratio={@node.props["ratio"] || "1:1"}
      data-gap={@node.props["gap"] || "s7"}
      data-align={@node.props["align"]}
    >
      <.children nodes={@node.children} state={@state} />
    </div>
    """
  end

  defp card(assigns) do
    ~H"""
    <div
      id={@node.id}
      data-level="layout"
      data-type="card"
      data-surface={@node.props["surface"] || "surface"}
      data-padding={@node.props["padding"] || "s5"}
      data-elevation={@node.props["elevation"] || "raised"}
    >
      <.children nodes={@node.children} state={@state} />
    </div>
    """
  end

  defp center(assigns) do
    ~H"""
    <div
      id={@node.id}
      data-level="layout"
      data-type="center"
      data-measure={to_string(Map.get(@node.props, "measure", true))}
    >
      <.children nodes={@node.children} state={@state} />
    </div>
    """
  end

  # The one stateful layout: the lead form. Its element id is fixed so the
  # controller can send a visitor back to it, and there is one per page.
  defp lead_form(assigns) do
    ~H"""
    <%= if @state.sent do %>
      <p id="lead-sent" data-level="atom" data-type="text" data-style="body" role="status">
        Thanks. We got your message and will be in touch.
      </p>
    <% else %>
      <.form
        for={@state.lead_form}
        id="lead-form"
        action="/leads"
        method="post"
        csrf_token={@state.csrf_token}
        data-level="layout"
        data-type="form"
        data-node={@node.id}
      >
        <fieldset disabled={@state.preview}>
          <p
            :if={@state.preview}
            id="lead-form-preview-note"
            data-level="atom"
            data-type="text"
            data-style="caption"
          >
            The form works on your published site.
          </p>
          <p
            :if={@state.refused}
            id="lead-form-refused"
            data-level="atom"
            data-type="text"
            data-style="body"
            data-status="alert"
            role="alert"
          >
            That is a lot of messages from one place in an hour. Try again later, or call.
          </p>
          <.children nodes={@node.children} state={@state} />
        </fieldset>
      </.form>
    <% end %>
    """
  end

  # ---- Atoms ------------------------------------------------------------------

  defp text(assigns) do
    ~H"""
    <p
      id={@node.id}
      data-level="atom"
      data-type="text"
      data-style={@node.props["style"] || "body"}
      data-color={@node.props["color"]}
    >
      {@node.props["content"]}
    </p>
    """
  end

  defp heading(%{node: %{props: props}} = assigns) do
    level = if props["level"] in [1, 2, 3], do: props["level"], else: 2

    assigns =
      assigns
      |> assign(:level, level)
      |> assign(:style, props["style"] || @heading_styles[level])

    ~H"""
    <%= case @level do %>
      <% 1 -> %>
        <h1
          id={@node.id}
          data-level="atom"
          data-type="heading"
          data-style={@style}
          data-color={@node.props["color"]}
        >
          {@node.props["content"]}
        </h1>
      <% 2 -> %>
        <h2
          id={@node.id}
          data-level="atom"
          data-type="heading"
          data-style={@style}
          data-color={@node.props["color"]}
        >
          {@node.props["content"]}
        </h2>
      <% 3 -> %>
        <h3
          id={@node.id}
          data-level="atom"
          data-type="heading"
          data-style={@style}
          data-color={@node.props["color"]}
        >
          {@node.props["content"]}
        </h3>
    <% end %>
    """
  end

  defp button_atom(%{node: %{props: props}} = assigns) do
    assigns = assign(assigns, :variant, props["variant"] || "secondary")

    ~H"""
    <%= if @node.props["action"] == "submit" do %>
      <button
        id={@node.id}
        type="submit"
        data-level="atom"
        data-type="button"
        data-variant={@variant}
        data-action="submit"
      >
        {@node.props["label"]}
      </button>
    <% else %>
      <a
        id={@node.id}
        href={href(@node.props["href"])}
        data-level="atom"
        data-type="button"
        data-variant={@variant}
      >
        {@node.props["label"]}
      </a>
    <% end %>
    """
  end

  defp link_atom(assigns) do
    ~H"""
    <a
      id={@node.id}
      href={href(@node.props["href"])}
      data-level="atom"
      data-type="link"
      data-prominent={to_string(@node.props["prominent"] == true)}
    >
      {@node.props["label"]}
    </a>
    """
  end

  defp icon_atom(%{node: %{props: props}} = assigns) do
    assigns = assign(assigns, :path, Map.get(@icons, props["name"], @icons["info"]))

    ~H"""
    <svg
      id={@node.id}
      data-level="atom"
      data-type="icon"
      data-size={@node.props["size"] || "m"}
      data-color={@node.props["color"] || "accent"}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      <path d={@path} />
    </svg>
    """
  end

  # With a photo the owner uploaded, a real `<img>` sized by the browser
  # from the medium and large variants, in a figure with the photo's own
  # caption when the node asks for one; without a photo, the placeholder.
  defp image(%{node: %{props: props}, state: state} = assigns) do
    photo = Map.get(state.photos || %{}, props["photo"])

    assigns =
      assigns
      |> assign(:decorative?, props["decorative"] == true)
      |> assign(:photo, photo)
      |> assign(:alt, photo_alt(props, photo))
      |> assign(:caption, photo_caption(props, photo))

    ~H"""
    <%= if @photo do %>
      <figure
        id={@node.id}
        data-level="atom"
        data-type="image"
        data-slot={@node.props["slot"]}
        data-photo={@photo.id}
        data-aspect={@node.props["aspect"] || "4:3"}
        data-treatment={@node.props["treatment"] || "plain"}
        data-captioned={to_string(@caption != nil)}
      >
        <img
          src={Media.url(@photo, :medium)}
          srcset={srcset(@photo)}
          sizes="(min-width: 900px) 50vw, 100vw"
          width={variant_width(@photo, :medium)}
          height={variant_height(@photo, :medium)}
          alt={if(@decorative?, do: "", else: @alt)}
          loading="lazy"
          decoding="async"
        />
        <figcaption :if={@caption} data-style="caption">{@caption}</figcaption>
      </figure>
    <% else %>
      <div
        id={@node.id}
        data-level="atom"
        data-type="image"
        data-slot={@node.props["slot"]}
        data-aspect={@node.props["aspect"] || "4:3"}
        data-treatment={@node.props["treatment"] || "plain"}
        role={if(@decorative?, do: "presentation", else: "img")}
        aria-label={if(!@decorative?, do: @node.props["alt"])}
        aria-hidden={if(@decorative?, do: "true")}
      >
      </div>
    <% end %>
    """
  end

  defp photo_alt(props, photo) do
    case props["alt"] do
      alt when is_binary(alt) and alt != "" -> alt
      _none -> (photo && photo.alt) || ""
    end
  end

  defp photo_caption(%{"caption" => true}, %{caption: caption})
       when is_binary(caption) and caption != "",
       do: caption

  defp photo_caption(_props, _photo), do: nil

  defp srcset(%{} = photo) do
    for name <- [:medium, :large],
        width = variant_width(photo, name),
        is_integer(width),
        uniq: true do
      "#{Media.url(photo, name)} #{width}w"
    end
    |> Enum.join(", ")
  end

  defp variant_width(photo, name), do: get_in(Photo.variant(photo, name) || %{}, ["width"])
  defp variant_height(photo, name), do: get_in(Photo.variant(photo, name) || %{}, ["height"])

  defp badge(assigns) do
    ~H"""
    <span
      id={@node.id}
      data-level="atom"
      data-type="badge"
      data-tone={@node.props["tone"] || "neutral"}
    >
      {@node.props["content"]}
    </span>
    """
  end

  defp divider(assigns) do
    ~H"""
    <hr
      id={@node.id}
      data-level="atom"
      data-type="divider"
      data-weight={@node.props["weight"] || "rule"}
    />
    """
  end

  defp input_atom(%{node: %{props: props}} = assigns) do
    assigns = field_assigns(assigns, props)

    ~H"""
    <div id={@node.id} data-level="atom" data-type="input">
      <label for={@field.id}>{@node.props["label"]}</label>
      <input
        id={@field.id}
        name={@field.name}
        type={input_type(@node.props["kind"])}
        value={Phoenix.HTML.Form.normalize_value(input_type(@node.props["kind"]), @field.value)}
        required={@node.props["required"] == true}
        autocomplete={autocomplete(@node.props["name"])}
        aria-invalid={if(@errors != [], do: "true")}
        aria-describedby={describedby(@errors, @error_id, @help, @help_id)}
      />
      <p :if={@help} id={@help_id} data-level="atom" data-type="text" data-style="caption">
        {@help}
      </p>
      <p
        :for={error <- @errors}
        id={@error_id}
        data-level="atom"
        data-type="text"
        data-style="caption"
        data-error
      >
        {error}
      </p>
    </div>
    """
  end

  defp textarea_atom(%{node: %{props: props}} = assigns) do
    assigns = field_assigns(assigns, props)

    ~H"""
    <div id={@node.id} data-level="atom" data-type="textarea">
      <label for={@field.id}>{@node.props["label"]}</label>
      <textarea
        id={@field.id}
        name={@field.name}
        required={@node.props["required"] == true}
        aria-invalid={if(@errors != [], do: "true")}
        aria-describedby={describedby(@errors, @error_id, @help, @help_id)}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @field.value) %></textarea>
      <p :if={@help} id={@help_id} data-level="atom" data-type="text" data-style="caption">
        {@help}
      </p>
      <p
        :for={error <- @errors}
        id={@error_id}
        data-level="atom"
        data-type="text"
        data-style="caption"
        data-error
      >
        {error}
      </p>
    </div>
    """
  end

  defp select_atom(%{node: %{props: props}} = assigns) do
    assigns = field_assigns(assigns, props)

    ~H"""
    <div id={@node.id} data-level="atom" data-type="select">
      <label for={@field.id}>{@node.props["label"]}</label>
      <select
        id={@field.id}
        name={@field.name}
        required={@node.props["required"] == true}
        aria-invalid={if(@errors != [], do: "true")}
        aria-describedby={describedby(@errors, @error_id, @help, @help_id)}
      >
        {Phoenix.HTML.Form.options_for_select(@node.props["options"] || [], @field.value)}
      </select>
      <p :if={@help} id={@help_id} data-level="atom" data-type="text" data-style="caption">
        {@help}
      </p>
      <p
        :for={error <- @errors}
        id={@error_id}
        data-level="atom"
        data-type="text"
        data-style="caption"
        data-error
      >
        {error}
      </p>
    </div>
    """
  end

  defp numeral(assigns) do
    ~H"""
    <p id={@node.id} data-level="atom" data-type="numeral" data-style="numeral">
      {@node.props["content"]}
    </p>
    """
  end

  defp quote_mark(assigns) do
    ~H"""
    <span id={@node.id} data-level="atom" data-type="quote_mark" aria-hidden="true">“</span>
    """
  end

  # ---- Helpers ----------------------------------------------------------------

  defp field_assigns(assigns, props) do
    field = assigns.state.lead_form[field_name(props["name"])]
    errors = Enum.map(field.errors, &translate_error/1)

    assigns
    |> assign(:field, field)
    |> assign(:errors, errors)
    |> assign(:error_id, field.id <> "-error")
    |> assign(:help, props["help"])
    |> assign(:help_id, field.id <> "-help")
  end

  defp field_name("phone"), do: :phone
  defp field_name("email"), do: :email
  defp field_name("message"), do: :message
  defp field_name(_name), do: :name

  defp input_type("tel"), do: "tel"
  defp input_type("email"), do: "email"
  defp input_type(_kind), do: "text"

  defp autocomplete("name"), do: "name"
  defp autocomplete("phone"), do: "tel"
  defp autocomplete("email"), do: "email"
  defp autocomplete(_name), do: nil

  defp href("bedrock:apex"), do: "/"
  defp href(href), do: href

  defp describedby(errors, error_id, help, help_id) do
    ids = [errors != [] and error_id, help && help_id] |> Enum.filter(&is_binary/1)
    if ids == [], do: nil, else: Enum.join(ids, " ")
  end

  @doc "The browser title: the page's, else the shop's name."
  @spec title(Document.t()) :: String.t()
  def title(document), do: Document.title(document)

  @doc "The meta description: the page's, else the trade, else the name."
  @spec description(Document.t()) :: String.t()
  def description(document), do: Document.description(document)
end
