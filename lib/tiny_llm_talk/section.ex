defmodule TinyLlmTalk.Section do
  @moduledoc """
  One section of the arc, with the minutes budgeted for it in
  `docs/talk-outline.md` and the one thing it has to land. The presenter view
  shows both, because the only two questions a speaker asks mid-talk are "where
  am I" and "am I behind."
  """

  @enforce_keys [:number, :title, :minutes, :lands, :slides]
  defstruct [:number, :title, :minutes, :lands, :slides]

  @type t :: %__MODULE__{
          number: non_neg_integer(),
          title: String.t(),
          minutes: pos_integer(),
          lands: String.t(),
          slides: [TinyLlmTalk.Slide.t()]
        }
end
