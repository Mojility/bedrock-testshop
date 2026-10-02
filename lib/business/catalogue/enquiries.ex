defmodule Business.Catalogue.Enquiries do
  @moduledoc "Bounded synthetic Journey state; shares lead validation and never writes or sends mail."
  alias Business.Leads.Lead
  import Phoenix.Component, only: [to_form: 2]

  def initial do
    leads =
      for {name, message, status, index} <- [
            {"Alex Morgan", "Our workshop lights flicker when the compressor starts.", "new", 1},
            {"Sam Chen", "Please quote for an EV charger at our office.", "contacted", 2},
            {"Robin Patel", "Annual panel inspection for our warehouse.", "closed", 3}
          ] do
        %Lead{
          id: "sample-#{index}",
          name: name,
          email: "enquiry#{index}@example.test",
          message: message,
          status: status,
          inserted_at: ~U[2026-09-26 13:00:00Z],
          notes: if(status == "contacted", do: "Called; awaiting site photos.", else: nil)
        }
      end

    %{
      leads: leads,
      selected: hd(leads),
      form: blank_form(),
      follow_up: follow_up_form(hd(leads)),
      result: nil,
      saved: nil
    }
  end

  def submit(state, params) do
    case %Lead{} |> Lead.changeset(params) |> Ecto.Changeset.apply_action(:insert) do
      {:ok, lead} ->
        lead = %{
          lead
          | id: "demo-#{System.unique_integer([:positive])}",
            inserted_at: DateTime.utc_now()
        }

        %{
          state
          | leads: Enum.take([lead | state.leads], 50),
            selected: lead,
            form: blank_form(),
            follow_up: follow_up_form(lead),
            saved: nil,
            result: "Thanks, #{lead.name}. Your sample enquiry is now in the staff queue below."
        }

      {:error, changeset} ->
        %{state | form: to_form(changeset, as: :enquiry), result: nil}
    end
  end

  def select(state, id) do
    case Enum.find(state.leads, &(&1.id == id)) do
      nil -> state
      lead -> %{state | selected: lead, follow_up: follow_up_form(lead), saved: nil}
    end
  end

  def follow_up(state, params) do
    case state.selected
         |> Lead.follow_up_changeset(params)
         |> Ecto.Changeset.apply_action(:update) do
      {:ok, lead} ->
        lead = %{lead | seen_at: lead.seen_at || DateTime.utc_now()}

        %{
          state
          | selected: lead,
            leads: Enum.map(state.leads, &if(&1.id == lead.id, do: lead, else: &1)),
            follow_up: follow_up_form(lead),
            saved: "Follow-up saved for #{lead.name}. No message was sent."
        }

      {:error, changeset} ->
        %{state | follow_up: to_form(changeset, as: :follow_up), saved: nil}
    end
  end

  defp blank_form, do: to_form(Ecto.Changeset.change(%Lead{}), as: :enquiry)
  defp follow_up_form(lead), do: to_form(Lead.follow_up_changeset(lead, %{}), as: :follow_up)
end
