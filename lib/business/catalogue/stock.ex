defmodule Business.Catalogue.Stock do
  @moduledoc "Deterministic synthetic inventory for catalogue scale and interaction examples."

  @families [
    {"Breakers", "Circuit breaker",
     [
       "15A single pole",
       "20A single pole",
       "30A double pole",
       "40A double pole",
       "50A double pole",
       "15A AFCI",
       "20A AFCI",
       "20A GFCI"
     ], "each", "breaker"},
    {"Cable", "Building wire",
     [
       "14/2 NMD90",
       "12/2 NMD90",
       "10/2 NMD90",
       "14/3 NMD90",
       "12/3 NMD90",
       "10/3 NMD90",
       "8/3 NMD90",
       "6/3 NMD90"
     ], "m", "cable"},
    {"Devices", "Receptacle",
     [
       "15A duplex white",
       "20A duplex white",
       "15A GFCI white",
       "20A GFCI ivory",
       "15A tamper resistant",
       "20A weather resistant",
       "15A hospital grade",
       "20A hospital grade"
     ], "each", "receptacle"},
    {"Boxes", "Junction box",
     [
       "4-inch square",
       "4-inch octagon",
       "2-gang steel",
       "3-gang steel",
       "single gang PVC",
       "weatherproof single",
       "4-inch deep",
       "6-inch pull box"
     ], "each", nil},
    {"Conduit", "Conduit fitting",
     [
       "1/2-inch connector",
       "3/4-inch connector",
       "1-inch connector",
       "1/2-inch coupling",
       "3/4-inch coupling",
       "1-inch coupling",
       "1/2-inch elbow",
       "3/4-inch elbow"
     ], "each", nil},
    {"Lighting", "LED luminaire",
     [
       "4-foot strip 3500K",
       "4-foot strip 4000K",
       "2x2 panel 3500K",
       "2x4 panel 4000K",
       "6-inch downlight",
       "8-inch downlight",
       "wall pack 30W",
       "canopy 60W"
     ], "each", nil},
    {"Fasteners", "Mounting hardware",
     [
       "concrete anchor M6",
       "concrete anchor M8",
       "beam clamp",
       "strut nut M8",
       "strut nut M10",
       "cable clip 12mm",
       "cable clip 16mm",
       "rod coupling M10"
     ], "box", nil},
    {"Grounding", "Bonding fitting",
     [
       "rod clamp",
       "pipe clamp 1/2-inch",
       "pipe clamp 3/4-inch",
       "lug #6",
       "lug #4",
       "lug #2",
       "bonding bushing 1-inch",
       "bonding bushing 2-inch"
     ], "each", nil},
    {"Controls", "Control device",
     [
       "24V relay",
       "120V relay",
       "24V contactor",
       "120V contactor",
       "timer 24-hour",
       "occupancy sensor",
       "photocell",
       "disconnect 30A"
     ], "each", nil},
    {"Safety", "Safety supply",
     [
       "lockout hasp",
       "panel lock",
       "breaker lock",
       "warning tag",
       "arc flash label",
       "face shield",
       "insulated glove bag",
       "voltage tester pouch"
     ], "each", nil},
    {"Data", "Data accessory",
     [
       "Cat6 keystone white",
       "Cat6 keystone blue",
       "1-port plate",
       "2-port plate",
       "4-port plate",
       "patch lead 1m",
       "patch lead 2m",
       "patch lead 3m"
     ], "each", nil},
    {"Weatherproof", "Outdoor enclosure",
     [
       "6x6 steel",
       "8x8 steel",
       "10x10 steel",
       "12x12 steel",
       "6x6 polycarbonate",
       "8x8 polycarbonate",
       "10x10 polycarbonate",
       "12x12 polycarbonate"
     ], "each", nil}
  ]

  @generated (for i <- 0..1991 do
                {category, family, variants, unit, photo} = Enum.at(@families, rem(i, 12))
                variant = Enum.at(variants, rem(div(i, 12), 8))
                series = div(i, 96) + 1
                maker = Enum.at(["Northline", "Mapleworks", "Tradecrest"], rem(series - 1, 3))
                on_hand = if rem(i, 17) == 0, do: 0, else: rem(i * 37, 320) + 1
                reserved = if on_hand == 0, do: 0, else: rem(i * 11, on_hand + 1)

                %{
                  id: "SKU-#{String.pad_leading(Integer.to_string(i + 10001), 5, "0")}",
                  name: "#{family} · #{variant}",
                  category: category,
                  maker: maker,
                  series: "Series #{series}",
                  unit: unit,
                  bin:
                    "#{Enum.at(~w(D E F G H), rem(i, 5))}-#{String.pad_leading(Integer.to_string(rem(div(i, 5), 40) + 1), 2, "0")}",
                  on_hand: on_hand,
                  reserved: reserved,
                  photo: if(rem(i, 5) == 0, do: nil, else: photo),
                  reorder: if(unit == "m", do: 100, else: 8)
                }
              end)

  def categories, do: Enum.map(@families, &elem(&1, 0)) |> Enum.sort()

  def all(receipt) do
    anchors = [
      {"MAT-112", "15A AFCI breaker", "A-06", receipt.on_hand, receipt.reserved, "Breakers",
       "breaker", "each"},
      {"MAT-204", "200A panel assembly", "A-04", 5, 3, "Controls", nil, "each"},
      {"MAT-310", "12/2 cable · metres", "C-02", 180, 120, "Cable", "cable", "m"},
      {"MAT-086", "Grounding & bonding kit", "B-12", 14, 6, "Grounding", nil, "each"},
      {"MAT-224", "Weatherproof receptacle", "Van 02", 6, 2, "Devices", "receptacle", "each"},
      {"MAT-061", "4-inch junction box", "B-08", 36, 14, "Boxes", nil, "each"},
      {"MAT-428", "EV charger · 48A", "A-09", 2, 2, "Controls", nil, "each"},
      {"MAT-145", "Whole-home surge protector", "A-07", 4, 1, "Controls", nil, "each"}
    ]

    Enum.map(anchors, fn {id, name, bin, on_hand, reserved, category, photo, unit} ->
      %{
        id: id,
        name: name,
        bin: bin,
        on_hand: on_hand,
        reserved: reserved,
        category: category,
        photo: photo,
        unit: unit,
        maker: "Northline",
        series: "Standard",
        reorder: 8
      }
    end) ++ @generated
  end

  def get(receipt, id), do: Enum.find(all(receipt), &(&1.id == id))

  def page(receipt, opts) do
    words = opts.query |> String.downcase() |> String.split()

    matches =
      all(receipt)
      |> Enum.filter(fn row ->
        haystack =
          String.downcase(
            Enum.join([row.id, row.name, row.bin, row.category, row.maker, row.series], " ")
          )

        (opts.category == "All categories" || row.category == opts.category) &&
          Enum.all?(words, &String.contains?(haystack, &1))
      end)

    key =
      case opts.sort do
        "on_hand" -> & &1.on_hand
        "reserved" -> & &1.reserved
        "available" -> &(&1.on_hand - &1.reserved)
        _ -> &String.downcase(&1.name)
      end

    sorted =
      Enum.sort_by(
        matches,
        &{key.(&1), &1.id},
        if(opts.direction == "desc", do: :desc, else: :asc)
      )

    total = length(sorted)
    pages = max(1, ceil(total / opts.size))
    current = min(max(1, opts.page), pages)
    rows = Enum.slice(sorted, (current - 1) * opts.size, opts.size)

    %{
      rows: rows,
      total: total,
      pages: pages,
      page: current,
      first: if(total == 0, do: 0, else: (current - 1) * opts.size + 1),
      last: min(current * opts.size, total),
      selected_matches: Enum.any?(matches, &(&1.id == opts.selected))
    }
  end
end
