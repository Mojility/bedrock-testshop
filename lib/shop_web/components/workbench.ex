defmodule ShopWeb.Workbench do
  @moduledoc """
  Dense operational compositions. Slots supply application-owned data and actions;
  these components never query records or grant permissions.
  """
  use ShopWeb, :html

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :reference, :string, default: nil
  attr :description, :string, default: nil
  slot :actions

  def record_header(assigns) do
    ~H"""
    <header id={@id} class="wb-record-header">
      <div>
        <small :if={@reference}>{@reference}</small><h2>{@title}</h2><p :if={@description}>
          {@description}
        </p>
      </div>
      <div :if={@actions != []} class="wb-actions">{render_slot(@actions)}</div>
    </header>
    """
  end

  attr :id, :string, required: true
  slot :queue
  slot :inner_block, required: true
  slot :inspector, required: true

  def split(assigns) do
    ~H"""
    <div id={@id} class={["wb-split", @queue != [] && "wb-with-queue"]}>
      <aside :if={@queue != []} class="wb-queue" aria-label="Work queue">{render_slot(@queue)}</aside>
      <div class="wb-record">{render_slot(@inner_block)}</div>
      <aside
        id={@id <> "-inspector"}
        tabindex="-1"
        class="wb-inspector"
        aria-label="Supporting context"
      >
        {render_slot(@inspector)}
      </aside>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :tone, :string, default: "neutral", values: ~w(neutral success warning error)

  def status(assigns) do
    ~H"""
    <span class={"wb-status wb-#{@tone}"}>{@label}</span>
    """
  end

  attr :id, :string, required: true
  attr :tone, :string, default: "neutral", values: ~w(neutral success warning error)
  slot :inner_block, required: true

  def notice(assigns) do
    ~H"""
    <div
      id={@id}
      class={"wb-notice wb-#{@tone}"}
      role={if @tone == "error", do: "alert", else: "status"}
      aria-atomic="true"
      tabindex="-1"
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :caption, :string, required: true
  attr :compact, :boolean, default: false
  attr :striped, :boolean, default: false
  attr :sort_by, :string, default: nil
  attr :sort_direction, :string, default: "asc", values: ~w(asc desc)
  attr :sort_event, :string, default: nil
  attr :row_id, :any, default: nil
  attr :selected_id, :string, default: nil
  attr :row_click, :string, default: nil

  slot :col, required: true do
    attr :label, :string, required: true
    attr :numeric, :boolean
    attr :sort_key, :string
  end

  def data_table(assigns) do
    ~H"""
    <div class="wb-table-scroll" tabindex="0" role="region" aria-label={@caption}>
      <table id={@id} class={["wb-table", @compact && "wb-compact", @striped && "wb-striped"]}>
        <caption class="sr-only">{@caption}</caption>
        <thead>
          <tr>
            <th
              :for={col <- @col}
              scope="col"
              class={col[:numeric] && "wb-numeric"}
              aria-sort={
                if col[:sort_key] && @sort_by == col[:sort_key],
                  do: if(@sort_direction == "asc", do: "ascending", else: "descending")
              }
            >
              <button
                :if={col[:sort_key] && @sort_event}
                type="button"
                class="wb-sort"
                phx-click={@sort_event}
                phx-value-column={col.sort_key}
                aria-label={"Sort by #{col.label}, #{if @sort_by == col.sort_key && @sort_direction == "asc", do: "descending", else: "ascending"}"}
              >
                {col.label}<.icon
                  name={
                    if @sort_by == col.sort_key,
                      do: if(@sort_direction == "asc", do: "hero-arrow-up", else: "hero-arrow-down"),
                      else: "hero-arrows-up-down"
                  }
                  class="wb-sort-icon size-3"
                />
              </button>
              <span :if={!col[:sort_key] || !@sort_event}>{col.label}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            :for={row <- @rows}
            id={if @row_id, do: @id <> "-" <> @row_id.(row)}
            class={[
              @row_id && @selected_id == @row_id.(row) && "wb-selected",
              @row_click && "wb-clickable-row"
            ]}
            phx-click={@row_click}
            phx-value-id={@row_click && @row_id && @row_id.(row)}
          >
            <td :for={col <- @col} class={col[:numeric] && "wb-numeric"}>{render_slot(col, row)}</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :result_label, :string, required: true
  slot :search, required: true
  slot :actions

  def table_toolbar(assigns) do
    ~H"""
    <div id={@id} class="wb-table-toolbar">
      {render_slot(@search)}
      <span id={@id <> "-count"} class="wb-result-count" role="status" aria-atomic="true">{@result_label}</span>
      <div :if={@actions != []} class="wb-toolbar-actions">{render_slot(@actions)}</div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :page, :integer, required: true
  attr :pages, :integer, required: true
  attr :first, :integer, required: true
  attr :last, :integer, required: true
  attr :total, :integer, required: true
  attr :event, :string, required: true

  slot :options

  def pagination(assigns) do
    ~H"""
    <nav id={@id} class="wb-pagination" aria-label="Table pages" tabindex="-1">
      <span role="status" aria-atomic="true">{@first}–{@last} of {@total}<span class="sr-only"> · Page {@page} of {@pages}</span></span>
      {render_slot(@options)}
      <div class="wb-actions">
        <button
          type="button"
          class="wb-button secondary"
          phx-click={JS.push(@event) |> JS.focus(to: "##{@id}")}
          phx-value-page="1"
          disabled={@page == 1}
          aria-label="First page"
        >«</button>
        <button
          type="button"
          class="wb-button secondary"
          phx-click={JS.push(@event) |> JS.focus(to: "##{@id}")}
          phx-value-page={@page - 1}
          disabled={@page == 1}
          aria-label="Previous page"
        >‹</button>
        <span>Page {@page} of {@pages}</span>
        <button
          type="button"
          class="wb-button secondary"
          phx-click={JS.push(@event) |> JS.focus(to: "##{@id}")}
          phx-value-page={@page + 1}
          disabled={@page == @pages}
          aria-label="Next page"
        >›</button>
        <button
          type="button"
          class="wb-button secondary"
          phx-click={JS.push(@event) |> JS.focus(to: "##{@id}")}
          phx-value-page={@pages}
          disabled={@page == @pages}
          aria-label="Last page"
        >»</button>
      </div>
    </nav>
    """
  end

  attr :id, :string, required: true
  attr :form, :any, required: true

  def date_range(assigns) do
    ~H"""
    <fieldset class="wb-temporal-fields" aria-describedby={@id <> "-hint"}>
      <legend>Date range</legend>
      <p id={@id <> "-hint"}>Both dates included. Dates do not carry a time of day.</p>
      <div class="wb-date-fields">
        <.input
          field={@form[:from]}
          type="date"
          label="From date"
          class="wb-input"
          error_class="wb-input wb-invalid"
        />
        <.input
          field={@form[:to]}
          type="date"
          label="Through date"
          class="wb-input"
          error_class="wb-input wb-invalid"
        />
      </div>
    </fieldset>
    """
  end

  attr :id, :string, required: true
  attr :form, :any, required: true
  attr :zones, :list, required: true
  attr :label, :string, default: "Occurred at"

  def timestamp_field(assigns) do
    ~H"""
    <fieldset class="wb-temporal-fields" aria-describedby={@id <> "-hint"}>
      <legend>{@label}</legend>
      <p id={@id <> "-hint"}>Enter local date and time in the selected time zone.</p>
      <div class="wb-date-fields">
        <.input
          field={@form[:occurred_at]}
          type="datetime-local"
          step="60"
          label="Date and time"
          class="wb-input"
          error_class="wb-input wb-invalid"
        />
        <.input
          field={@form[:zone]}
          type="select"
          label="Time zone"
          options={@zones}
          class="wb-input"
          error_class="wb-input wb-invalid"
        />
      </div>
    </fieldset>
    """
  end

  attr :id, :string, required: true
  attr :form, :any, required: true
  attr :zones, :list, required: true

  def time_range(assigns) do
    ~H"""
    <fieldset class="wb-temporal-fields" aria-describedby={@id <> "-hint"}>
      <legend>Scheduled window</legend>
      <p id={@id <> "-hint"}>
        Start included, end excluded. For overnight work, set the end to the following date.
      </p>
      <div class="wb-date-fields">
        <.input
          field={@form[:starts_at]}
          type="datetime-local"
          step="60"
          label="Starts at"
          class="wb-input"
          error_class="wb-input wb-invalid"
        />
        <.input
          field={@form[:ends_at]}
          type="datetime-local"
          step="60"
          label="Ends at"
          class="wb-input"
          error_class="wb-input wb-invalid"
        />
      </div>
      <.input
        field={@form[:zone]}
        type="select"
        label="Scheduling time zone"
        options={@zones}
        class="wb-input"
        error_class="wb-input wb-invalid"
      />
    </fieldset>
    """
  end
end
