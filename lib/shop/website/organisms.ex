defmodule Shop.Website.Organisms do
  @moduledoc """
  The organisms (`docs/atomic-composition.md`): named sections the agent
  can use as one node, each an expansion into layouts, molecules, and atoms
  written in the tree language (`Shop.Website.Template`). They are data:
  adding an organism is adding an entry here, and its variants are props.

  The starting set from the spec (`hero`, `call_now_band`, `services`,
  `walkthrough`, `story`, `crew`, `quotes`, `area`, `stats`,
  `credentials`, `faq`, `hours`, `pricing_plainness`, `notice_band`,
  `contact`, `footer`) plus `why`, the "why people call us" points every
  site built before the tree had, so the migration recipe can reproduce
  it, and `gallery`, the owner's photos of their work in a grid. The agent is not limited to these: any section can be built from
  layouts, molecules, and atoms directly.

  Every organism sits in a `band` whose `surface` and `padding` are props,
  so two organisms in a row can alternate grounds without the agent
  reaching inside. Each organism's headings are level 2 (level 1 in the
  hero), and none but the hero carries the page's primary button unless
  told to.

  The palette is spread in the 60/30/10 spirit of `docs/site-design-system.md`:
  the neutrals carry the page, the secondary carries the bands that are
  not the page's own (the call-now band, the footer, the soft panels of a
  walkthrough or the contact form), and the accent is the marks: numerals,
  icons, quote marks, the badges of the credentials. The primary stays on
  the one action, the links, and the hero band.
  """

  @surfaces %{
    surface: %{type: :token, domain: :surface, default: "bg", doc: "the band's ground"},
    padding: %{type: :token, domain: :band_padding, default: "s8"}
  }

  @type entry :: %{
          name: String.t(),
          purpose: String.t(),
          props: map(),
          template: map()
        }

  @doc "Every organism, in the order the catalogue lists them."
  @spec all() :: [entry()]
  def all, do: organisms()

  # ---- Building blocks shared by the templates --------------------------------

  defp band(props, children, extra \\ %{}) do
    %{
      type: "band",
      props:
        Map.merge(
          %{surface: {:prop, :surface, "bg"}, padding: {:prop, :padding, "s8"}},
          Map.merge(props, extra)
        ),
      children: children
    }
  end

  defp container(children, width \\ "standard") do
    %{type: "container", props: %{width: width}, children: children}
  end

  defp intro(level \\ 2) do
    {:if, {:prop, :heading},
     %{
       name: "intro",
       type: "section_intro",
       props: %{
         heading: {:prop, :heading},
         level: level,
         eyebrow: {:prop, :eyebrow},
         lede: {:prop, :lede}
       }
     }}
  end

  defp organisms do
    [
      hero(),
      call_now_band(),
      services(),
      walkthrough(),
      story(),
      crew(),
      gallery(),
      quotes(),
      area(),
      stats(),
      credentials(),
      why(),
      faq(),
      hours(),
      pricing_plainness(),
      notice_band(),
      contact(),
      footer()
    ]
  end

  # ---- Hero -------------------------------------------------------------------

  defp hero do
    buttons = %{
      name: "actions",
      type: "button_group",
      props: %{},
      children: [
        %{
          name: "primary",
          type: "button",
          props: %{
            label: {:prop, :primary_label},
            href: {:prop, :primary_href},
            variant: {:prop, :primary_variant, "primary"}
          }
        },
        {:if, {:prop, :secondary_label},
         %{
           name: "secondary",
           type: "button",
           props: %{
             label: {:prop, :secondary_label},
             href: {:prop, :secondary_href},
             variant: "ghost"
           }
         }}
      ]
    }

    eyebrow =
      {:if, {:prop, :eyebrow},
       %{name: "eyebrow", type: "text", props: %{style: "eyebrow", content: {:prop, :eyebrow}}}}

    heading = %{name: "heading", type: "heading", props: %{level: 1, content: {:prop, :heading}}}

    tagline =
      {:if, {:prop, :tagline},
       %{name: "tagline", type: "text", props: %{style: "lede", content: {:prop, :tagline}}}}

    intro =
      {:if, {:prop, :intro},
       %{name: "intro", type: "text", props: %{style: "body", content: {:prop, :intro}}}}

    main = %{
      type: "stack",
      props: %{gap: "s5"},
      children: [eyebrow, heading, tagline, intro, buttons]
    }

    photo =
      {:if, {:prop, :photo},
       %{
         name: "photo",
         type: "image",
         props: %{slot: "hero", photo: {:prop, :photo}, aspect: "4:3"}
       }}

    split = %{
      type: "split",
      props: %{ratio: "3:2", gap: "s7", align: "end"},
      children: [
        %{type: "stack", props: %{gap: "s5"}, children: [eyebrow, heading, tagline, buttons]},
        %{type: "stack", props: %{gap: "s4"}, children: [photo, intro]}
      ]
    }

    # With a photo behind the band, the words sit on a panel in the hero's
    # own colours so they stay readable whatever the photo shows.
    band_variant =
      {:if, {:prop, :photo},
       %{
         name: "panel",
         type: "card",
         props: %{surface: "hero", padding: "s6", elevation: "flat"},
         children: [main]
       }, main}

    centred = %{
      type: "center",
      props: %{},
      children: [
        %{
          type: "stack",
          props: %{gap: "s5", align: "center"},
          children: [eyebrow, heading, tagline, intro, buttons]
        }
      ]
    }

    %{
      name: "hero",
      purpose: "the top of the page: the name as the one h1, a line, the primary action",
      props:
        Map.merge(
          %{
            variant: %{type: :enum, values: ~w(stacked split band centred), default: "stacked"},
            heading: %{type: :string, required: true, doc: "the shop's name, usually"},
            eyebrow: %{type: :string, doc: "trade and area, e.g. Electrical · Durham Region"},
            tagline: %{type: :string},
            intro: %{type: :string},
            primary_label: %{type: :string, required: true},
            primary_href: %{type: :string, required: true, doc: "#contact or tel:"},
            primary_variant: %{
              type: :enum,
              values: ~w(primary secondary),
              default: "primary",
              doc: "secondary when the primary button lives elsewhere"
            },
            secondary_label: %{type: :string},
            secondary_href: %{type: :string},
            photo: %{
              type: :string,
              doc:
                "one of the shop's photos, landscape: split shows it beside the words, band behind"
            }
          },
          %{
            surface: %{type: :token, domain: :surface, default: "hero"},
            padding: %{type: :token, domain: :band_padding, default: "s8"}
          }
        ),
      template:
        band(
          %{
            surface: {:prop, :surface, "hero"},
            photo: {:case, {:prop, :variant, "stacked"}, %{"band" => {:prop, :photo}}, nil}
          },
          [
            container([
              {:case, {:prop, :variant, "stacked"},
               %{"split" => split, "centred" => centred, "band" => band_variant}, main}
            ])
          ]
        )
    }
  end

  # ---- Call now band ----------------------------------------------------------

  defp call_now_band do
    %{
      name: "call_now_band",
      purpose: "a short band with the number, for shops people call in a hurry",
      props:
        Map.merge(@surfaces, %{
          surface: %{type: :token, domain: :surface, default: "secondary"},
          padding: %{type: :token, domain: :band_padding, default: "s7"},
          text: %{type: :string, required: true, doc: "e.g. 24 hours, 7 days. Burst pipe? Call."},
          phone: %{type: :string, required: true, doc: "must match the facts"},
          label: %{type: :string, default: "Call now"},
          button_variant: %{type: :enum, values: ~w(primary secondary), default: "secondary"}
        }),
      template:
        band(%{surface: {:prop, :surface, "secondary"}, padding: {:prop, :padding, "s7"}}, [
          container([
            %{
              type: "cluster",
              props: %{gap: "s5", justify: "between", align: "center"},
              children: [
                %{
                  name: "text",
                  type: "text",
                  props: %{style: "subheading", content: {:prop, :text}}
                },
                %{
                  name: "button",
                  type: "button",
                  props: %{
                    label: {:concat, [{:prop, :label, "Call now"}, " ", {:prop, :phone}]},
                    href: {:concat, ["tel:", {:prop, :phone}]},
                    variant: {:prop, :button_variant, "secondary"}
                  }
                }
              ]
            }
          ])
        ])
    }
  end

  # ---- Services ---------------------------------------------------------------

  defp services do
    item = %{
      name: "item",
      type: "service_item",
      props: %{name: {:item, :name}, text: {:item, :text}, icon: {:item, :icon}}
    }

    %{
      name: "services",
      purpose: "what they do, one item each",
      props:
        Map.merge(@surfaces, %{
          variant: %{type: :enum, values: ~w(grid two_column list numbered), default: "grid"},
          heading: %{type: :string, default: "What we do"},
          eyebrow: %{type: :string},
          lede: %{type: :string},
          items: %{
            type: :list,
            required: true,
            of: %{
              name: %{type: :string, required: true},
              text: %{type: :string},
              icon: %{type: :token, domain: :icon}
            }
          }
        }),
      template:
        band(%{}, [
          container([
            %{
              type: "stack",
              props: %{gap: "s6"},
              children: [
                intro(),
                {:case, {:prop, :variant, "grid"},
                 %{
                   "two_column" => %{
                     type: "grid",
                     props: %{columns: 2, gap: "s6"},
                     children: [{:each, {:prop, :items}, item}]
                   },
                   "list" => %{
                     type: "stack",
                     props: %{gap: "s4"},
                     children: [
                       {:each, {:prop, :items},
                        %{
                          name: "row",
                          type: "stack",
                          props: %{gap: "s4"},
                          children: [%{type: "divider", props: %{weight: "hairline"}}, item]
                        }}
                     ]
                   },
                   "numbered" => %{
                     type: "stack",
                     props: %{gap: "s6"},
                     children: [
                       {:each, {:prop, :items},
                        %{
                          name: "step",
                          type: "step",
                          props: %{
                            number: {:index},
                            heading: {:item, :name},
                            text: {:item, :text}
                          }
                        }}
                     ]
                   }
                 },
                 %{
                   type: "grid",
                   props: %{columns: 3, gap: "s5"},
                   children: [
                     {:each, {:prop, :items},
                      %{name: "card", type: "card", props: %{}, children: [item]}}
                   ]
                 }}
              ]
            }
          ])
        ])
    }
  end

  # ---- Walkthrough ------------------------------------------------------------

  defp walkthrough do
    %{
      name: "walkthrough",
      purpose: "what happens, step by step: when you call, when we arrive, after",
      props:
        Map.merge(@surfaces, %{
          heading: %{type: :string, required: true},
          eyebrow: %{type: :string},
          lede: %{type: :string},
          steps: %{
            type: :list,
            required: true,
            of: %{heading: %{type: :string, required: true}, text: %{type: :string}}
          }
        }),
      template:
        band(%{}, [
          container([
            %{
              type: "stack",
              props: %{gap: "s6"},
              children: [
                intro(),
                %{
                  type: "grid",
                  props: %{columns: 2, gap: "s5"},
                  children: [
                    {:each, {:prop, :steps},
                     %{
                       name: "card",
                       type: "card",
                       props: %{surface: "secondary_soft", elevation: "flat"},
                       children: [
                         %{
                           name: "step",
                           type: "step",
                           props: %{
                             number: {:index},
                             heading: {:item, :heading},
                             text: {:item, :text}
                           }
                         }
                       ]
                     }}
                  ]
                }
              ]
            }
          ])
        ])
    }
  end

  # ---- Story ------------------------------------------------------------------

  defp story do
    paragraphs = %{
      type: "stack",
      props: %{gap: "s4"},
      children: [
        {:each, {:prop, :paragraphs},
         %{name: "paragraph", type: "text", props: %{content: {:item}}}}
      ]
    }

    %{
      name: "story",
      purpose: "who they are, in a few paragraphs, with a photo if there is one",
      props:
        Map.merge(@surfaces, %{
          heading: %{type: :string, required: true},
          eyebrow: %{type: :string},
          paragraphs: %{type: :list, of: :string, required: true},
          slot: %{type: :string, doc: "photo slot name"},
          alt: %{type: :string, doc: "what the photo shows"}
        }),
      template:
        band(%{}, [
          container([
            %{
              type: "split",
              props: %{ratio: "2:3", gap: "s7"},
              children: [
                %{
                  type: "stack",
                  props: %{gap: "s5"},
                  children: [
                    intro(),
                    {:if, {:prop, :slot},
                     %{
                       name: "photo",
                       type: "image",
                       props: %{slot: {:prop, :slot}, alt: {:prop, :alt}, aspect: "4:3"}
                     }}
                  ]
                },
                paragraphs
              ]
            }
          ])
        ])
    }
  end

  # ---- Crew -------------------------------------------------------------------

  defp crew do
    %{
      name: "crew",
      purpose: "the people who show up",
      props:
        Map.merge(@surfaces, %{
          heading: %{type: :string, default: "Who shows up"},
          eyebrow: %{type: :string},
          lede: %{type: :string},
          people: %{
            type: :list,
            required: true,
            of: %{
              name: %{type: :string, required: true},
              role: %{type: :string},
              slot: %{type: :string},
              photo: %{type: :string, doc: "the id of one of the shop's photos"}
            }
          }
        }),
      template:
        band(%{}, [
          container([
            %{
              type: "stack",
              props: %{gap: "s6"},
              children: [
                intro(),
                %{
                  type: "grid",
                  props: %{columns: 3, gap: "s5"},
                  children: [
                    {:each, {:prop, :people},
                     %{
                       name: "person",
                       type: "person",
                       props: %{
                         name: {:item, :name},
                         role: {:item, :role},
                         slot: {:item, :slot},
                         photo: {:item, :photo}
                       }
                     }}
                  ]
                }
              ]
            }
          ])
        ])
    }
  end

  # ---- Gallery ----------------------------------------------------------------

  defp gallery do
    %{
      name: "gallery",
      purpose: "the owner's photos of their work in a grid, each with its own caption",
      props:
        Map.merge(@surfaces, %{
          heading: %{type: :string, default: "Our work"},
          eyebrow: %{type: :string},
          lede: %{type: :string},
          photos: %{type: :list, of: :string, required: true, doc: "ids from the photo list"},
          columns: %{type: :integer, values: [2, 3], default: 3},
          captions: %{type: :boolean, default: true, doc: "show each photo's caption"}
        }),
      template:
        band(%{}, [
          container([
            %{
              type: "stack",
              props: %{gap: "s6"},
              children: [
                intro(),
                %{
                  type: "grid",
                  props: %{columns: {:prop, :columns, 3}, gap: "s5"},
                  children: [
                    {:each, {:prop, :photos},
                     %{
                       name: "photo",
                       type: "image",
                       props: %{
                         slot: "work",
                         photo: {:item},
                         aspect: "4:3",
                         caption: {:prop, :captions, true}
                       }
                     }}
                  ]
                }
              ]
            }
          ])
        ])
    }
  end

  # ---- Quotes -----------------------------------------------------------------

  defp quotes do
    %{
      name: "quotes",
      purpose: "what customers say, in their words",
      props:
        Map.merge(@surfaces, %{
          heading: %{type: :string, default: "What people say"},
          eyebrow: %{type: :string},
          quotes: %{
            type: :list,
            required: true,
            of: %{text: %{type: :string, required: true}, attribution: %{type: :string}}
          }
        }),
      template:
        band(%{}, [
          container([
            %{
              type: "stack",
              props: %{gap: "s6"},
              children: [
                intro(),
                %{
                  type: "grid",
                  props: %{columns: 2, gap: "s5"},
                  children: [
                    {:each, {:prop, :quotes},
                     %{
                       name: "card",
                       type: "card",
                       props: %{surface: "accent_soft", elevation: "flat"},
                       children: [
                         %{
                           type: "quote",
                           props: %{text: {:item, :text}, attribution: {:item, :attribution}}
                         }
                       ]
                     }}
                  ]
                }
              ]
            }
          ])
        ])
    }
  end

  # ---- Area -------------------------------------------------------------------

  defp area do
    %{
      name: "area",
      purpose: "where they work, and the places by name",
      props:
        Map.merge(@surfaces, %{
          heading: %{type: :string, default: "Where we work"},
          eyebrow: %{type: :string},
          text: %{type: :string},
          places: %{type: :list, of: :string}
        }),
      template:
        band(%{}, [
          container([
            %{
              type: "stack",
              props: %{gap: "s5"},
              children: [
                intro(),
                {:if, {:prop, :text},
                 %{name: "text", type: "text", props: %{content: {:prop, :text}}}},
                {:if, {:prop, :places},
                 %{name: "places", type: "place_list", props: %{places: {:prop, :places}}}}
              ]
            }
          ])
        ])
    }
  end

  # ---- Stats ------------------------------------------------------------------

  defp stats do
    %{
      name: "stats",
      purpose: "a few figures that say how long, how many, how far",
      props:
        Map.merge(@surfaces, %{
          surface: %{type: :token, domain: :surface, default: "surface_alt"},
          padding: %{type: :token, domain: :band_padding, default: "s7"},
          heading: %{type: :string},
          stats: %{
            type: :list,
            required: true,
            of: %{
              value: %{type: :string, required: true},
              caption: %{type: :string, required: true}
            }
          }
        }),
      template:
        band(%{surface: {:prop, :surface, "surface_alt"}, padding: {:prop, :padding, "s7"}}, [
          container([
            %{
              type: "stack",
              props: %{gap: "s6"},
              children: [
                intro(),
                %{
                  type: "grid",
                  props: %{columns: 4, gap: "s6"},
                  children: [
                    {:each, {:prop, :stats},
                     %{
                       name: "stat",
                       type: "stat",
                       props: %{value: {:item, :value}, caption: {:item, :caption}}
                     }}
                  ]
                }
              ]
            }
          ])
        ])
    }
  end

  # ---- Credentials ------------------------------------------------------------

  defp credentials do
    %{
      name: "credentials",
      purpose: "licences, certifications, memberships, compact",
      props:
        Map.merge(@surfaces, %{
          heading: %{type: :string, default: "Licensed and certified"},
          eyebrow: %{type: :string},
          items: %{type: :list, of: :string, required: true}
        }),
      template:
        band(%{}, [
          container([
            %{
              type: "stack",
              props: %{gap: "s5"},
              children: [
                intro(),
                %{
                  type: "cluster",
                  props: %{gap: "s3"},
                  children: [
                    {:each, {:prop, :items},
                     %{name: "item", type: "badge", props: %{content: {:item}, tone: "accent"}}}
                  ]
                }
              ]
            }
          ])
        ])
    }
  end

  # ---- Why --------------------------------------------------------------------

  defp why do
    %{
      name: "why",
      purpose: "why people call them: a few short points in the owner's words",
      props:
        Map.merge(@surfaces, %{
          heading: %{type: :string, default: "Why people call us"},
          eyebrow: %{type: :string},
          points: %{type: :list, of: :string, required: true}
        }),
      template:
        band(%{}, [
          container([
            %{
              type: "stack",
              props: %{gap: "s5"},
              children: [
                intro(),
                %{
                  type: "stack",
                  props: %{gap: "s3"},
                  children: [
                    {:each, {:prop, :points},
                     %{name: "point", type: "notice", props: %{text: {:item}, icon: "check"}}}
                  ]
                }
              ]
            }
          ])
        ])
    }
  end

  # ---- FAQ --------------------------------------------------------------------

  defp faq do
    %{
      name: "faq",
      purpose: "the questions people ask before they call",
      props:
        Map.merge(@surfaces, %{
          heading: %{type: :string, default: "Questions people ask"},
          eyebrow: %{type: :string},
          items: %{
            type: :list,
            required: true,
            of: %{
              question: %{type: :string, required: true},
              answer: %{type: :string, required: true}
            }
          }
        }),
      template:
        band(%{}, [
          container(
            [
              %{
                type: "stack",
                props: %{gap: "s6"},
                children: [
                  intro(),
                  %{
                    type: "stack",
                    props: %{gap: "s5"},
                    children: [
                      {:each, {:prop, :items},
                       %{
                         name: "item",
                         type: "faq_item",
                         props: %{question: {:item, :question}, answer: {:item, :answer}}
                       }}
                    ]
                  }
                ]
              }
            ],
            "narrow"
          )
        ])
    }
  end

  # ---- Hours ------------------------------------------------------------------

  defp hours do
    %{
      name: "hours",
      purpose: "when they are open, and what happens outside those hours",
      props:
        Map.merge(@surfaces, %{
          heading: %{type: :string, default: "Hours"},
          eyebrow: %{type: :string},
          rows: %{
            type: :list,
            required: true,
            of: %{
              days: %{type: :string, required: true},
              times: %{type: :string, required: true}
            }
          },
          note: %{type: :string, doc: "e.g. Emergencies any time"}
        }),
      template:
        band(%{}, [
          container(
            [
              %{
                type: "stack",
                props: %{gap: "s5"},
                children: [
                  intro(),
                  %{
                    type: "stack",
                    props: %{gap: "s3"},
                    children: [
                      {:each, {:prop, :rows},
                       %{
                         name: "row",
                         type: "hours_row",
                         props: %{days: {:item, :days}, times: {:item, :times}}
                       }}
                    ]
                  },
                  {:if, {:prop, :note},
                   %{name: "note", type: "notice", props: %{text: {:prop, :note}, icon: "clock"}}}
                ]
              }
            ],
            "narrow"
          )
        ])
    }
  end

  # ---- Pricing plainness ------------------------------------------------------

  defp pricing_plainness do
    %{
      name: "pricing_plainness",
      purpose: "how they charge, said plainly: call-out, hourly, quotes, no surprises",
      props:
        Map.merge(@surfaces, %{
          heading: %{type: :string, default: "How we charge"},
          eyebrow: %{type: :string},
          text: %{type: :string, required: true},
          facts: %{
            type: :list,
            of: %{
              label: %{type: :string, required: true},
              value: %{type: :string, required: true}
            }
          }
        }),
      template:
        band(%{}, [
          container([
            %{
              type: "split",
              props: %{ratio: "1:1", gap: "s7"},
              children: [
                %{
                  type: "stack",
                  props: %{gap: "s4"},
                  children: [
                    intro(),
                    %{name: "text", type: "text", props: %{content: {:prop, :text}}}
                  ]
                },
                %{
                  type: "grid",
                  props: %{columns: 2, gap: "s5"},
                  children: [
                    {:each, {:prop, :facts},
                     %{
                       name: "fact",
                       type: "fact",
                       props: %{label: {:item, :label}, value: {:item, :value}}
                     }}
                  ]
                }
              ]
            }
          ])
        ])
    }
  end

  # ---- Notice band ------------------------------------------------------------

  defp notice_band do
    %{
      name: "notice_band",
      purpose: "one line everyone should see: seasonal, a closure, an emergency line",
      props:
        Map.merge(@surfaces, %{
          surface: %{type: :token, domain: :surface, default: "surface_alt"},
          padding: %{type: :token, domain: :band_padding, default: "s7"},
          text: %{type: :string, required: true},
          icon: %{type: :token, domain: :icon, default: "info"}
        }),
      template:
        band(%{surface: {:prop, :surface, "surface_alt"}, padding: {:prop, :padding, "s7"}}, [
          container([
            %{
              name: "notice",
              type: "notice",
              props: %{text: {:prop, :text}, icon: {:prop, :icon, "info"}}
            }
          ])
        ])
    }
  end

  # ---- Contact ----------------------------------------------------------------

  defp contact do
    channels = %{
      name: "channels",
      type: "stack",
      props: %{gap: "s5"},
      children: [
        {:if, {:prop, :phone},
         %{
           name: "phone",
           type: "contact_channel",
           props: %{
             kind: "phone",
             value: {:prop, :phone},
             caption: {:prop, :phone_caption},
             prominent: {:case, {:prop, :preferred, "phone"}, %{"phone" => true}, false}
           }
         }},
        {:if, {:prop, :email},
         %{
           name: "email",
           type: "contact_channel",
           props: %{
             kind: "email",
             value: {:prop, :email},
             caption: {:prop, :email_caption},
             prominent: {:case, {:prop, :preferred, "phone"}, %{"email" => true}, false}
           }
         }},
        {:if, {:prop, :hours},
         %{name: "hours", type: "fact", props: %{label: "Hours", value: {:prop, :hours}}}}
      ]
    }

    form = %{
      name: "form",
      type: "form",
      props: %{action: "leads"},
      children: [
        %{
          type: "stack",
          props: %{gap: "s5"},
          children: [
            %{
              name: "name",
              type: "field",
              props: %{name: "name", label: "Your name", kind: "text", required: true}
            },
            %{
              name: "phone",
              type: "field",
              props: %{
                name: "phone",
                label: "Phone",
                kind: "tel",
                help: "Phone or email, whichever you prefer."
              }
            },
            %{
              name: "email",
              type: "field",
              props: %{name: "email", label: "Email", kind: "email"}
            },
            %{
              name: "message",
              type: "field",
              props: %{
                name: "message",
                label: {:prop, :message_label, "What do you need?"},
                kind: "textarea"
              }
            },
            %{
              name: "submit",
              type: "button",
              props: %{
                label: {:prop, :submit_label, "Send"},
                action: "submit",
                variant: {:prop, :submit_variant, "secondary"}
              }
            }
          ]
        }
      ]
    }

    panel = %{
      name: "panel",
      type: "card",
      props: %{surface: "secondary_soft", padding: "s6"},
      children: [form]
    }

    %{
      name: "contact",
      purpose: "how to reach them, with the lead form; the one place the form lives",
      props:
        Map.merge(@surfaces, %{
          variant: %{
            type: :enum,
            values: ~w(form_first phone_first side_by_side),
            default: "side_by_side"
          },
          heading: %{type: :string, default: "Get in touch"},
          eyebrow: %{type: :string},
          lede: %{type: :string},
          phone: %{type: :string, doc: "only if it may be shown; must match the facts"},
          phone_caption: %{type: :string},
          email: %{type: :string, doc: "only if it may be shown; must match the facts"},
          email_caption: %{type: :string},
          preferred: %{type: :enum, values: ~w(phone email), default: "phone"},
          hours: %{type: :string},
          message_label: %{type: :string, default: "What do you need?"},
          submit_label: %{type: :string, default: "Send"},
          submit_variant: %{
            type: :enum,
            values: ~w(primary secondary),
            default: "secondary",
            doc: "primary only when no other button on the page is"
          }
        }),
      template:
        band(%{}, [
          container([
            %{
              type: "stack",
              props: %{gap: "s6"},
              children: [
                intro(),
                {:case, {:prop, :variant, "side_by_side"},
                 %{
                   "form_first" => %{
                     type: "stack",
                     props: %{gap: "s7"},
                     children: [panel, channels]
                   },
                   "phone_first" => %{
                     type: "stack",
                     props: %{gap: "s7"},
                     children: [channels, panel]
                   }
                 },
                 %{
                   type: "split",
                   props: %{ratio: "1:1", gap: "s7", align: "start"},
                   children: [channels, panel]
                 }}
              ]
            }
          ])
        ])
    }
  end

  # ---- Footer -----------------------------------------------------------------

  defp footer do
    %{
      name: "footer",
      purpose: "the foot of the page: the name, since when, and Site by Bedrock",
      props:
        Map.merge(@surfaces, %{
          surface: %{type: :token, domain: :surface, default: "secondary"},
          padding: %{type: :token, domain: :band_padding, default: "s7"},
          name: %{type: :string, required: true},
          founded_year: %{type: :integer},
          text: %{type: :string, doc: "an address or a line of small print"}
        }),
      template:
        band(
          %{surface: {:prop, :surface, "secondary"}, padding: {:prop, :padding, "s7"}},
          [
            container([
              %{
                type: "cluster",
                props: %{gap: "s5", justify: "between", align: "start"},
                children: [
                  %{
                    type: "stack",
                    props: %{gap: "s2"},
                    children: [
                      %{
                        name: "name",
                        type: "text",
                        props: %{
                          style: "caption",
                          content:
                            {:case, {:prop, :founded_year}, %{nil => {:prop, :name}},
                             {:concat, [{:prop, :name}, " · Since ", {:prop, :founded_year}]}}
                        }
                      },
                      {:if, {:prop, :text},
                       %{
                         name: "text",
                         type: "text",
                         props: %{style: "caption", content: {:prop, :text}}
                       }}
                    ]
                  },
                  %{
                    name: "bedrock",
                    type: "link",
                    props: %{label: "Site by Bedrock", href: "bedrock:apex"}
                  }
                ]
              }
            ])
          ],
          %{landmark: "footer"}
        )
    }
  end
end
