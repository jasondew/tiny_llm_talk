defmodule TinyLlmTalk.Slide do
  @moduledoc """
  One slide.

  `id` is what the renderer pattern-matches on, so a slide's drawing lives in
  `TinyLlmTalkWeb.SlideComponents` as a function clause named by this atom and
  nowhere else. `steps` is how many times the right arrow fires before the deck
  moves on, which is what lets a code slide arrive a line at a time.
  """

  @enforce_keys [:id, :title]
  defstruct [:id, :title, :section, :index, notes: "", steps: 1]

  @type t :: %__MODULE__{
          id: atom(),
          title: String.t(),
          section: non_neg_integer() | nil,
          index: pos_integer() | nil,
          notes: String.t(),
          steps: pos_integer()
        }

  @doc """
  The notes as one paragraph.

  They are written as heredocs wrapped to the width of the source file, and a
  speaker glancing down mid-sentence should not be reading someone else's line
  breaks.
  """
  @spec prose(t()) :: String.t()
  def prose(%__MODULE__{notes: notes}) do
    notes |> String.replace(~r/\s+/, " ") |> String.trim()
  end
end
