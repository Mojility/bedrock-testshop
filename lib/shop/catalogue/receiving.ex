defmodule Shop.Catalogue.Receiving do
  @moduledoc "Synthetic receiving scenario for the development catalogue; no repository or external effects."

  alias Shop.Catalogue.Temporal

  def initial do
    %{
      ordered: 24,
      received: 0,
      on_hand: 8,
      reserved: 8,
      unit_cost_cents: 6400,
      revision: 0,
      history: []
    }
  end

  def form(state, params \\ %{}) do
    {%{},
     %{
       quantity: :integer,
       reference: :string,
       revision: :integer,
       occurred_at: :naive_datetime,
       zone: :string
     }}
    |> Ecto.Changeset.cast(params, [:quantity, :reference, :revision, :occurred_at, :zone])
    |> Ecto.Changeset.validate_required([:quantity, :reference, :revision, :occurred_at, :zone])
    |> Ecto.Changeset.validate_inclusion(:zone, Temporal.zones())
    |> Temporal.validate_instant(:occurred_at)
    |> Ecto.Changeset.validate_number(:quantity,
      greater_than: 0,
      less_than_or_equal_to: state.ordered - state.received
    )
    |> Ecto.Changeset.validate_length(:reference, min: 2, max: 80)
    |> Ecto.Changeset.validate_change(:reference, fn :reference, ref ->
      if String.trim(ref) == "", do: [reference: "cannot be blank"], else: []
    end)
  end

  def receive(state, params, recorded_at \\ DateTime.utc_now()) do
    changeset = form(state, params)

    case Ecto.Changeset.apply_action(changeset, :insert) do
      {:ok, %{revision: revision}} when revision != state.revision ->
        {:error,
         Ecto.Changeset.add_error(
           changeset,
           :revision,
           "This receipt was already applied. Review the updated quantities."
         )
         |> Map.put(:action, :insert)}

      {:ok, values} ->
        {:ok, occurred_at} = Temporal.instant(values.occurred_at, values.zone)

        receipt = %{
          occurred_at: occurred_at,
          recorded_at: recorded_at,
          zone: values.zone,
          quantity: values.quantity,
          reference: String.trim(values.reference),
          sequence: state.revision + 1
        }

        {:ok,
         %{
           state
           | received: state.received + values.quantity,
             on_hand: state.on_hand + values.quantity,
             revision: state.revision + 1,
             history: [receipt | state.history]
         }}

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
