defmodule Shop.Website.Registry do
  @moduledoc """
  The design system's levels, as data (`docs/atomic-composition.md`): every
  type a page tree may hold, with its level (atom, molecule, layout,
  organism), a one-line purpose, a schema for its props, the levels of
  children it accepts, and, for molecules and organisms, the expansion
  that turns it into atoms and layouts at render time.

  Atoms and layouts are code: each has one function component in
  `ShopWeb.WebsiteHTML`. Molecules are expansions written here in the tree
  language (`Shop.Website.Template`), so they are data-like but typed.
  Organisms are expansions kept in `Shop.Website.Organisms`. The page is
  the implicit root: nodes with no parent, which may be layouts or
  organisms.

  `catalogue/0` renders the whole registry as compact text for the model's
  prompt, and `catalogue_hash/0` names that text so events can record
  which catalogue a batch of operations was composed against.

  A prop schema is a map of prop name to `%{type: ..., doc: ...}` where
  type is `:string`, `:integer` (with `values`), `:boolean`, `:enum` (with
  `values`), `:token` (with a `domain` of `Shop.Website.Tokens.domain/1`),
  or `:list` (with `of:` `:string` or a nested schema). `required: true`
  and `default:` say the rest.
  """
  alias Shop.Website.Organisms
  alias Shop.Website.Tokens

  @type level :: :atom | :molecule | :layout | :organism
  @type prop_schema :: %{
          required(:type) => :string | :integer | :boolean | :enum | :token | :list,
          optional(:values) => list(),
          optional(:domain) => atom(),
          optional(:of) => :string | %{atom() => prop_schema()},
          optional(:required) => boolean(),
          optional(:default) => term(),
          optional(:doc) => String.t()
        }
  @type entry :: %{
          name: String.t(),
          level: level(),
          purpose: String.t(),
          props: %{atom() => prop_schema()},
          children: [level()],
          template: map() | nil
        }

  @lead_fields ~w(name phone email message)
  @heading_levels [1, 2, 3]
  @icon_sizes ~w(s m l)
  @aspects ~w(16:9 4:3 1:1 3:4)
  @treatments ~w(plain soft)
  @button_variants ~w(primary secondary ghost)
  @tones ~w(neutral primary secondary accent)
  @rule_weights ~w(rule hairline heavy)
  @aligns ~w(start center end)
  @justifies ~w(start center end between)
  @ratios ~w(1:1 2:3 3:2)
  @landmarks ~w(section footer)
  @field_kinds ~w(text tel email textarea)
  @channel_kinds ~w(phone email)

  # ---- Atoms ----------------------------------------------------------------

  @atoms [
    %{
      name: "text",
      purpose: "a run of words in one type style",
      props: %{
        content: %{type: :string, required: true},
        style: %{type: :token, domain: :type, default: "body"},
        color: %{type: :token, domain: :color, default: "text"}
      }
    },
    %{
      name: "heading",
      purpose: "a heading; level 1 is the page's one h1, sections use 2, items 3",
      props: %{
        level: %{type: :integer, values: @heading_levels, required: true},
        content: %{type: :string, required: true},
        style: %{
          type: :token,
          domain: :type,
          doc: "defaults to display_xl for level 1, heading for 2, subheading for 3"
        },
        color: %{type: :token, domain: :color, default: "text"}
      }
    },
    %{
      name: "button",
      purpose: "an action, at least 44px tall; exactly one primary per page",
      props: %{
        label: %{type: :string, required: true},
        href: %{type: :string, doc: "#an_id, tel:, mailto:, or https://"},
        action: %{type: :enum, values: ~w(submit), doc: "instead of href, inside a form"},
        variant: %{type: :enum, values: @button_variants, default: "secondary"}
      }
    },
    %{
      name: "link",
      purpose: "a plain link in the text",
      props: %{
        label: %{type: :string, required: true},
        href: %{type: :string, required: true, doc: "#an_id, tel:, mailto:, or https://"},
        prominent: %{type: :boolean, default: false, doc: "large, for a phone number"}
      }
    },
    %{
      name: "icon",
      purpose: "a mark from the curated set, decorative unless labelled",
      props: %{
        name: %{type: :token, domain: :icon, required: true},
        size: %{type: :enum, values: @icon_sizes, default: "m"},
        color: %{type: :token, domain: :color, default: "accent"}
      }
    },
    %{
      name: "image",
      purpose:
        "a photo slot; one of the owner's photos, or a quiet placeholder until there is one",
      props: %{
        slot: %{type: :string, required: true, doc: "a short name for the photo, e.g. crew"},
        photo: %{type: :string, doc: "the id of one of the shop's photos, from the photo list"},
        alt: %{
          type: :string,
          doc: "what the photo shows; required unless decorative or a photo is named"
        },
        decorative: %{type: :boolean, default: false},
        aspect: %{type: :enum, values: @aspects, default: "4:3"},
        treatment: %{type: :enum, values: @treatments, default: "plain"},
        caption: %{
          type: :boolean,
          default: false,
          doc: "show the photo's own caption under it, when it has one"
        }
      }
    },
    %{
      name: "badge",
      purpose: "a short label in a chip",
      props: %{
        content: %{type: :string, required: true},
        tone: %{type: :enum, values: @tones, default: "neutral"}
      }
    },
    %{
      name: "divider",
      purpose: "a rule between things, in the theme's rule weight",
      props: %{weight: %{type: :enum, values: @rule_weights, default: "rule"}}
    },
    %{
      name: "input",
      purpose: "one line of the lead form, always labelled",
      props: %{
        name: %{type: :enum, values: @lead_fields, required: true},
        label: %{type: :string, required: true},
        kind: %{type: :enum, values: ~w(text tel email), default: "text"},
        required: %{type: :boolean, default: false},
        help: %{type: :string}
      }
    },
    %{
      name: "textarea",
      purpose: "a paragraph of the lead form, always labelled",
      props: %{
        name: %{type: :enum, values: @lead_fields, required: true},
        label: %{type: :string, required: true},
        required: %{type: :boolean, default: false},
        help: %{type: :string}
      }
    },
    %{
      name: "select",
      purpose: "a choice on the lead form, always labelled",
      props: %{
        name: %{type: :enum, values: @lead_fields, required: true},
        label: %{type: :string, required: true},
        options: %{type: :list, of: :string, required: true},
        required: %{type: :boolean, default: false},
        help: %{type: :string}
      }
    },
    %{
      name: "numeral",
      purpose: "a large figure: years, trucks, jobs, a step number",
      props: %{content: %{type: :string, required: true}}
    },
    %{
      name: "quote_mark",
      purpose: "a decorative opening quote, hidden from screen readers",
      props: %{}
    }
  ]

  # ---- Molecules --------------------------------------------------------------

  @molecules [
    %{
      name: "section_intro",
      purpose: "the top of any section: an eyebrow, the heading, a lede",
      props: %{
        heading: %{type: :string, required: true},
        level: %{type: :integer, values: [2, 3], default: 2},
        eyebrow: %{type: :string},
        lede: %{type: :string}
      },
      template: %{
        type: "stack",
        props: %{gap: "s3"},
        children: [
          {:if, {:prop, :eyebrow},
           %{
             name: "eyebrow",
             type: "text",
             props: %{style: "eyebrow", content: {:prop, :eyebrow}}
           }},
          %{
            name: "heading",
            type: "heading",
            props: %{level: {:prop, :level, 2}, content: {:prop, :heading}}
          },
          {:if, {:prop, :lede},
           %{name: "lede", type: "text", props: %{style: "lede", content: {:prop, :lede}}}}
        ]
      }
    },
    %{
      name: "service_item",
      purpose: "one thing they do: a name and a plain line",
      props: %{
        name: %{type: :string, required: true},
        text: %{type: :string},
        icon: %{type: :token, domain: :icon}
      },
      template: %{
        type: "stack",
        props: %{gap: "s2"},
        children: [
          {:if, {:prop, :icon}, %{type: "icon", props: %{name: {:prop, :icon}, size: "m"}}},
          %{name: "name", type: "heading", props: %{level: 3, content: {:prop, :name}}},
          {:if, {:prop, :text},
           %{name: "text", type: "text", props: %{content: {:prop, :text}, color: "muted"}}}
        ]
      }
    },
    %{
      name: "step",
      purpose: "one step of a walkthrough: a number, a heading, what happens",
      props: %{
        number: %{type: :integer, required: true},
        heading: %{type: :string, required: true},
        text: %{type: :string}
      },
      template: %{
        type: "stack",
        props: %{gap: "s2"},
        children: [
          %{
            name: "number",
            type: "numeral",
            props: %{content: {:concat, ["", {:prop, :number}]}}
          },
          %{name: "heading", type: "heading", props: %{level: 3, content: {:prop, :heading}}},
          {:if, {:prop, :text},
           %{name: "text", type: "text", props: %{content: {:prop, :text}, color: "muted"}}}
        ]
      }
    },
    %{
      name: "stat",
      purpose: "a figure with what it counts: years, trucks, jobs",
      props: %{
        value: %{type: :string, required: true},
        caption: %{type: :string, required: true}
      },
      template: %{
        type: "stack",
        props: %{gap: "s2"},
        children: [
          %{name: "value", type: "numeral", props: %{content: {:prop, :value}}},
          %{name: "caption", type: "text", props: %{style: "caption", content: {:prop, :caption}}}
        ]
      }
    },
    %{
      name: "quote",
      purpose: "a customer's words, with who said them",
      props: %{
        text: %{type: :string, required: true},
        attribution: %{type: :string}
      },
      template: %{
        type: "stack",
        props: %{gap: "s3"},
        children: [
          %{type: "quote_mark", props: %{}},
          %{name: "text", type: "text", props: %{style: "lede", content: {:prop, :text}}},
          {:if, {:prop, :attribution},
           %{
             name: "attribution",
             type: "text",
             props: %{style: "caption", content: {:prop, :attribution}}
           }}
        ]
      }
    },
    %{
      name: "contact_channel",
      purpose: "a phone number or email as a link, with a caption",
      props: %{
        kind: %{type: :enum, values: @channel_kinds, required: true},
        value: %{type: :string, required: true, doc: "must match the facts"},
        caption: %{type: :string},
        prominent: %{type: :boolean, default: false, doc: "large, for the preferred channel"}
      },
      template: %{
        type: "cluster",
        props: %{gap: "s3", align: "center"},
        children: [
          %{
            type: "icon",
            props: %{name: {:case, {:prop, :kind}, %{"phone" => "phone", "email" => "mail"}}}
          },
          %{
            type: "stack",
            props: %{gap: "s2"},
            children: [
              %{
                name: "link",
                type: "link",
                props: %{
                  label: {:prop, :value},
                  href:
                    {:case, {:prop, :kind},
                     %{
                       "phone" => {:concat, ["tel:", {:prop, :value}]},
                       "email" => {:concat, ["mailto:", {:prop, :value}]}
                     }},
                  prominent: {:prop, :prominent}
                }
              },
              {:if, {:prop, :caption},
               %{
                 name: "caption",
                 type: "text",
                 props: %{style: "caption", content: {:prop, :caption}}
               }}
            ]
          }
        ]
      }
    },
    %{
      name: "hours_row",
      purpose: "days and the hours they are open",
      props: %{
        days: %{type: :string, required: true},
        times: %{type: :string, required: true}
      },
      template: %{
        type: "cluster",
        props: %{gap: "s4", justify: "between"},
        children: [
          %{name: "days", type: "text", props: %{content: {:prop, :days}}},
          %{name: "times", type: "text", props: %{content: {:prop, :times}, color: "muted"}}
        ]
      }
    },
    %{
      name: "place_list",
      purpose: "named places served, as chips",
      props: %{places: %{type: :list, of: :string, required: true}},
      template: %{
        type: "cluster",
        props: %{gap: "s2"},
        children: [
          {:each, {:prop, :places}, %{name: "place", type: "badge", props: %{content: {:item}}}}
        ]
      }
    },
    %{
      name: "person",
      purpose: "one of the crew: a photo, a name, what they do",
      props: %{
        name: %{type: :string, required: true},
        role: %{type: :string},
        slot: %{type: :string, doc: "photo slot name"},
        photo: %{type: :string, doc: "the id of one of the shop's photos, from the photo list"}
      },
      template: %{
        type: "stack",
        props: %{gap: "s3"},
        children: [
          {:if, {:prop, :slot},
           %{
             type: "image",
             props: %{
               slot: {:prop, :slot},
               photo: {:prop, :photo},
               alt: {:prop, :name},
               aspect: "1:1",
               treatment: "soft"
             }
           }},
          %{name: "name", type: "heading", props: %{level: 3, content: {:prop, :name}}},
          {:if, {:prop, :role},
           %{name: "role", type: "text", props: %{style: "caption", content: {:prop, :role}}}}
        ]
      }
    },
    %{
      name: "field",
      purpose: "one control of the lead form: label, input, help, error",
      props: %{
        name: %{type: :enum, values: @lead_fields, required: true},
        label: %{type: :string, required: true},
        kind: %{type: :enum, values: @field_kinds, default: "text"},
        required: %{type: :boolean, default: false},
        help: %{type: :string}
      },
      template: %{
        type: "stack",
        props: %{gap: "s2"},
        children: [
          {:case, {:prop, :kind, "text"},
           %{
             "textarea" => %{
               name: "control",
               type: "textarea",
               props: %{
                 name: {:prop, :name},
                 label: {:prop, :label},
                 required: {:prop, :required},
                 help: {:prop, :help}
               }
             }
           },
           %{
             name: "control",
             type: "input",
             props: %{
               name: {:prop, :name},
               label: {:prop, :label},
               kind: {:prop, :kind, "text"},
               required: {:prop, :required},
               help: {:prop, :help}
             }
           }}
        ]
      }
    },
    %{
      name: "button_group",
      purpose: "buttons side by side: the primary and a secondary",
      props: %{},
      children: [:atom],
      template: %{
        type: "cluster",
        props: %{gap: "s4", align: "center"},
        children: [{:children}]
      }
    },
    %{
      name: "fact",
      purpose: "a labelled fact: licence, founded, insured",
      props: %{
        label: %{type: :string, required: true},
        value: %{type: :string, required: true}
      },
      template: %{
        type: "stack",
        props: %{gap: "s2"},
        children: [
          %{name: "label", type: "text", props: %{style: "eyebrow", content: {:prop, :label}}},
          %{name: "value", type: "text", props: %{content: {:prop, :value}}}
        ]
      }
    },
    %{
      name: "faq_item",
      purpose: "a question people ask and the answer",
      props: %{
        question: %{type: :string, required: true},
        answer: %{type: :string, required: true}
      },
      template: %{
        type: "stack",
        props: %{gap: "s2"},
        children: [
          %{name: "question", type: "heading", props: %{level: 3, content: {:prop, :question}}},
          %{name: "answer", type: "text", props: %{content: {:prop, :answer}, color: "muted"}}
        ]
      }
    },
    %{
      name: "notice",
      purpose: "a line with a mark beside it: 24/7, seasonal, a closure, a point",
      props: %{
        text: %{type: :string, required: true},
        icon: %{type: :token, domain: :icon, default: "info"}
      },
      template: %{
        type: "cluster",
        props: %{gap: "s3", align: "start"},
        children: [
          %{type: "icon", props: %{name: {:prop, :icon, "info"}, size: "s"}},
          %{name: "text", type: "text", props: %{content: {:prop, :text}}}
        ]
      }
    }
  ]

  # ---- Layouts ---------------------------------------------------------------

  @layouts [
    %{
      name: "stack",
      purpose: "children one above the other",
      props: %{
        gap: %{type: :token, domain: :gap, default: "s5"},
        align: %{type: :enum, values: @aligns}
      }
    },
    %{
      name: "cluster",
      purpose: "children in a row that wraps",
      props: %{
        gap: %{type: :token, domain: :gap, default: "s4"},
        justify: %{type: :enum, values: @justifies},
        align: %{type: :enum, values: @aligns}
      }
    },
    %{
      name: "grid",
      purpose: "equal columns; 1 below 640px, 2 below 900px",
      props: %{
        columns: %{type: :integer, values: [1, 2, 3, 4], required: true},
        gap: %{type: :token, domain: :gap, default: "s5"}
      }
    },
    %{
      name: "split",
      purpose: "two columns that stack on a phone",
      props: %{
        ratio: %{type: :enum, values: @ratios, default: "1:1"},
        gap: %{type: :token, domain: :gap, default: "s7"},
        align: %{type: :enum, values: @aligns}
      }
    },
    %{
      name: "container",
      purpose: "the centred content column; text belongs inside one",
      props: %{width: %{type: :token, domain: :width, default: "standard"}}
    },
    %{
      name: "band",
      purpose: "a full-width section with a surface; the top level of most sections",
      props: %{
        surface: %{type: :token, domain: :surface, default: "bg"},
        padding: %{type: :token, domain: :band_padding, default: "s8"},
        landmark: %{type: :enum, values: @landmarks, default: "section"},
        photo: %{
          type: :string,
          doc:
            "one of the shop's photos, behind the band; put the words in a card with surface hero"
        }
      }
    },
    %{
      name: "card",
      purpose: "a bounded region for things that belong together",
      props: %{
        surface: %{type: :token, domain: :card_surface, default: "surface"},
        padding: %{type: :token, domain: :card_padding, default: "s5"},
        elevation: %{type: :enum, values: ~w(raised flat), default: "raised"}
      }
    },
    %{
      name: "center",
      purpose: "a short centred moment, at reading width",
      props: %{measure: %{type: :boolean, default: true}}
    },
    %{
      name: "form",
      purpose: "the lead form; posts to the shop's lead endpoint",
      props: %{action: %{type: :enum, values: ~w(leads), required: true}}
    }
  ]

  @layout_children [:layout, :molecule, :atom]

  @typed_atoms Enum.map(@atoms, &Map.merge(&1, %{level: :atom, children: [], template: nil}))
  @typed_molecules Enum.map(
                     @molecules,
                     &Map.merge(%{level: :molecule, children: []}, &1)
                   )
  @typed_layouts Enum.map(
                   @layouts,
                   &Map.merge(&1, %{level: :layout, children: @layout_children, template: nil})
                 )

  @doc "Every registered type, atoms first, then molecules, layouts, organisms."
  @spec all() :: [entry()]
  def all, do: @typed_atoms ++ @typed_molecules ++ @typed_layouts ++ organisms()

  @doc "The registry as a map by type name."
  @spec by_name() :: %{String.t() => entry()}
  def by_name, do: Map.new(all(), &{&1.name, &1})

  @doc "The entry for `type`, or nil."
  @spec get(String.t()) :: entry() | nil
  def get(type, extensions \\ %{})

  def get(type, extensions) when is_binary(type),
    do: Map.get(extensions, type) || Map.get(by_name(), type)

  def get(_type, _extensions), do: nil

  @doc "The names of every type at `level`."
  @spec names(level()) :: [String.t()]
  def names(level), do: for(%{name: name, level: ^level} <- all(), do: name)

  @doc "The levels a node with no parent (a child of the page) may be."
  @spec page_children() :: [level()]
  def page_children, do: [:layout, :organism]

  @doc "The lead form's field names, the only ones an input may post."
  @spec lead_fields() :: [String.t()]
  def lead_fields, do: @lead_fields

  @doc """
  The registry as compact, deterministic text for the model: every type by
  level with its purpose, its props with allowed values (`*` marks a
  required prop), and what children it accepts.
  """
  @spec catalogue() :: String.t()
  def catalogue(extensions \\ %{}) do
    [
      {"ATOMS", :atom, "content and token references only; go inside molecules or layouts"},
      {"MOLECULES", :molecule, "fixed compositions of atoms; go inside layouts"},
      {"LAYOUTS", :layout, "composition; hold layouts, molecules, atoms; may sit at the top"},
      {"ORGANISMS", :organism, "whole sections as one node; props only, no children; at the top"}
    ]
    |> Enum.map_join("\n\n", fn {title, level, note} ->
      lines =
        (all() ++ Map.values(extensions))
        |> Enum.filter(&(&1.level == level))
        |> Enum.map_join("\n", &catalogue_line/1)

      "#{title} (#{note})\n#{lines}"
    end)
    |> Kernel.<>("\n\nICONS: " <> Enum.join(Tokens.icons(), ", "))
  end

  @doc "A short, stable name for the current catalogue."
  @spec catalogue_hash() :: String.t()
  def catalogue_hash do
    :sha256 |> :crypto.hash(catalogue()) |> Base.encode16(case: :lower) |> binary_part(0, 12)
  end

  @doc "The props of `entry` that have a default, with those defaults, string-keyed."
  @spec defaults(entry()) :: %{String.t() => term()}
  def defaults(%{props: props}) do
    for {name, %{default: default}} <- props, into: %{}, do: {to_string(name), default}
  end

  @doc "One prop's allowed values as the catalogue writes them, or nil for free text."
  @spec values(prop_schema()) :: [term()] | nil
  def values(%{type: :enum, values: values}), do: values
  def values(%{type: :integer, values: values}), do: values
  def values(%{type: :token, domain: domain}), do: Tokens.domain(domain)
  def values(%{type: :boolean}), do: [true, false]
  def values(_schema), do: nil

  defp organisms do
    Enum.map(Organisms.all(), &Map.merge(&1, %{level: :organism, children: []}))
  end

  defp catalogue_line(entry) do
    props =
      case entry.props do
        empty when map_size(empty) == 0 -> "none"
        props -> props |> Enum.sort_by(&prop_order/1) |> Enum.map_join(", ", &catalogue_prop/1)
      end

    children =
      case entry.children do
        [] -> ""
        levels -> " children: " <> Enum.map_join(levels, "|", &Atom.to_string/1)
      end

    "#{entry.name}: #{entry.purpose}. props: #{props}.#{children}"
  end

  # Required props first, then alphabetical, so the line reads as a signature.
  defp prop_order({name, schema}), do: {not Map.get(schema, :required, false), name}

  defp catalogue_prop({name, %{type: :list, of: :string} = schema}) do
    "#{name}#{star(schema)}=[text]"
  end

  defp catalogue_prop({name, %{type: :list, of: fields} = schema}) when is_map(fields) do
    inner = fields |> Enum.sort_by(&prop_order/1) |> Enum.map_join(", ", &catalogue_prop/1)
    "#{name}#{star(schema)}=[{#{inner}}]"
  end

  defp catalogue_prop({name, schema}) do
    values =
      case {schema, values(schema)} do
        {%{domain: :icon}, _icons} -> "=an icon"
        {%{type: :integer}, nil} -> "=number"
        {_schema, nil} -> ""
        {_schema, values} -> "=" <> Enum.map_join(values, "|", &to_string/1)
      end

    default =
      case Map.get(schema, :default) do
        nil -> ""
        default -> " (default #{default})"
      end

    doc =
      case Map.get(schema, :doc) do
        nil -> ""
        doc -> " [#{doc}]"
      end

    "#{name}#{star(schema)}#{values}#{default}#{doc}"
  end

  defp star(%{required: true}), do: "*"
  defp star(_schema), do: ""
end
