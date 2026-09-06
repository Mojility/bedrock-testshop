defmodule Shop.Website.RegistryTest do
  use ExUnit.Case, async: true

  alias Shop.Website.Organisms
  alias Shop.Website.Registry
  alias Shop.Website.Tokens

  @spec_atoms ~w(text heading button link icon image badge divider input textarea select numeral
                 quote_mark)
  @spec_molecules ~w(section_intro service_item step stat quote contact_channel hours_row
                     place_list person field button_group fact faq_item notice)
  @spec_layouts ~w(stack cluster grid split container band card center)
  @spec_organisms ~w(hero call_now_band services walkthrough story crew quotes area stats
                     credentials faq hours pricing_plainness notice_band contact footer)

  describe "the levels" do
    test "hold every type the spec names, plus the form layout, the why organism, and the gallery" do
      assert Registry.names(:atom) == @spec_atoms
      assert Registry.names(:molecule) == @spec_molecules
      assert Registry.names(:layout) == @spec_layouts ++ ["form"]

      assert Enum.sort(Registry.names(:organism)) ==
               Enum.sort(@spec_organisms ++ ["why", "gallery"])

      assert Registry.page_children() == [:layout, :organism]
    end

    test "every type has a level, a purpose, a prop schema, and the children it accepts" do
      for entry <- Registry.all() do
        assert entry.level in [:atom, :molecule, :layout, :organism], entry.name
        assert is_binary(entry.purpose) and entry.purpose != "", entry.name
        assert is_map(entry.props), entry.name
        assert is_list(entry.children), entry.name

        for {prop, schema} <- entry.props do
          assert schema.type in [:string, :integer, :boolean, :enum, :token, :list],
                 "#{entry.name}.#{prop}"

          if schema.type == :token, do: refute(Enum.empty?(Tokens.domain(schema.domain)))
          if schema.type == :enum, do: refute(Enum.empty?(schema.values))
        end
      end
    end

    test "atoms take no children, layouts take layouts, molecules and atoms, organisms none" do
      for name <- Registry.names(:atom), do: assert(Registry.get(name).children == [])

      for name <- Registry.names(:layout),
          do: assert(Registry.get(name).children == [:layout, :molecule, :atom])

      for name <- Registry.names(:organism), do: assert(Registry.get(name).children == [])
      assert Registry.get("button_group").children == [:atom]
    end

    test "molecules and organisms carry an expansion; atoms and layouts do not" do
      for name <- Registry.names(:molecule) ++ Registry.names(:organism) do
        assert is_map(Registry.get(name).template), name
      end

      for name <- Registry.names(:atom) ++ Registry.names(:layout) do
        assert Registry.get(name).template == nil, name
      end
    end

    test "organisms are data in their own module, one entry each with variants as props" do
      names = Enum.map(Organisms.all(), & &1.name)
      assert Enum.sort(names) == Enum.sort(Registry.names(:organism))
      assert Registry.get("hero").props.variant.values == ~w(stacked split band centred)
      assert Registry.get("services").props.variant.values == ~w(grid two_column list numbered)

      assert Registry.get("contact").props.variant.values ==
               ~w(form_first phone_first side_by_side)

      assert Registry.get("nothing") == nil
    end

    test "form fields may only post what the lead endpoint takes" do
      assert Registry.lead_fields() == ~w(name phone email message)
      assert Registry.get("input").props.name.values == Registry.lead_fields()
      assert Registry.get("field").props.name.values == Registry.lead_fields()
    end
  end

  describe "catalogue/0" do
    test "is deterministic and names every type, level, purpose, prop, and allowed value" do
      catalogue = Registry.catalogue()
      assert catalogue == Registry.catalogue()
      assert Registry.catalogue_hash() == Registry.catalogue_hash()
      assert String.length(Registry.catalogue_hash()) == 12

      for title <- ~w(ATOMS MOLECULES LAYOUTS ORGANISMS ICONS), do: assert(catalogue =~ title)

      for entry <- Registry.all() do
        assert catalogue =~ "\n#{entry.name}: #{entry.purpose}. props:", entry.name

        for {prop, _schema} <- entry.props do
          assert catalogue =~ to_string(prop), "#{entry.name}.#{prop}"
        end
      end

      assert catalogue =~ "variant=stacked|split|band|centred"
      assert catalogue =~ "columns*=1|2|3|4"
      assert catalogue =~ "gap=s2|s3|s4|s5|s6|s7 (default s5)"
      assert catalogue =~ "items*=[{name*, icon=an icon, text}]"
      assert catalogue =~ "button_group: " and catalogue =~ "children: atom"
      assert catalogue =~ "ICONS: phone, mail, clock"
      refute catalogue =~ "Barlow"
    end

    test "is compact enough for a prompt" do
      assert String.length(Registry.catalogue()) < 12_000
    end

    test "the hash follows the catalogue" do
      hash = Registry.catalogue_hash()
      assert hash =~ ~r/^[0-9a-f]{12}$/
    end
  end
end
