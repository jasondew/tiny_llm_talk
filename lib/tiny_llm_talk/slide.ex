defmodule TinyLlmTalk.Slide do
  @moduledoc """
  One slide.

  `id` is what the renderer pattern-matches on, so a slide's drawing lives in
  `TinyLlmTalkWeb.SlideComponents` as a function clause named by this atom and
  nowhere else. `steps` is how many times the right arrow fires before the deck
  moves on, which is what lets a code slide arrive a line at a time. `ticks`
  says the slide moves on its own, and `TinyLlmTalkWeb.Animation` runs its
  clock while it is on screen.
  """

  @enforce_keys [:id, :title]
  defstruct [:id, :title, :section, :index, notes: "", steps: 1, ticks: false]

  @type t :: %__MODULE__{
          id: atom(),
          title: String.t(),
          section: non_neg_integer() | nil,
          index: pos_integer() | nil,
          notes: String.t(),
          steps: pos_integer(),
          ticks: boolean()
        }

  @typedoc """
  A run of bullets, a run of points that must be made out loud, or a run of
  term and definition pairs.
  """
  @type block ::
          {:bullets, [String.t()]}
          | {:musts, [String.t()]}
          | {:definitions, [{String.t(), String.t()}]}

  @doc """
  The notes as blocks for the presenter: a line starting with `- ` is a
  bullet, one starting with `! ` is a point that must be made out loud, one
  starting with `= ` is a definition, `term: what it means`, and any other
  line continues the item before it. Consecutive items of one kind are
  grouped, so the presenter can draw a list, then a glossary, then a list
  again.
  """
  @spec blocks(t()) :: [block()]
  def blocks(%__MODULE__{notes: notes}) do
    notes
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce([], &add_line/2)
    |> Enum.reverse()
    |> Enum.map(fn {kind, items} -> {kind, Enum.reverse(items)} end)
  end

  @doc """
  The notes as one paragraph, for the stub and for checking a slide has any.
  """
  @spec prose(t()) :: String.t()
  def prose(slide) do
    slide
    |> blocks()
    |> Enum.flat_map(fn
      {:bullets, items} -> items
      {:musts, items} -> items
      {:definitions, pairs} -> Enum.map(pairs, fn {term, text} -> term <> ": " <> text end)
    end)
    |> Enum.join(" ")
  end

  ## PRIVATE FUNCTIONS

  defp add_line("- " <> text, [{:bullets, items} | rest]), do: [{:bullets, [text | items]} | rest]
  defp add_line("- " <> text, blocks), do: [{:bullets, [text]} | blocks]

  defp add_line("! " <> text, [{:musts, items} | rest]), do: [{:musts, [text | items]} | rest]
  defp add_line("! " <> text, blocks), do: [{:musts, [text]} | blocks]

  defp add_line("= " <> text, [{:definitions, pairs} | rest]),
    do: [{:definitions, [definition(text) | pairs]} | rest]

  defp add_line("= " <> text, blocks), do: [{:definitions, [definition(text)]} | blocks]

  # A line with no marker continues whatever came before it, or opens a
  # bullet when nothing did.
  defp add_line(text, [{:bullets, [last | items]} | rest]),
    do: [{:bullets, [last <> " " <> text | items]} | rest]

  defp add_line(text, [{:musts, [last | items]} | rest]),
    do: [{:musts, [last <> " " <> text | items]} | rest]

  defp add_line(text, [{:definitions, [{term, last} | pairs]} | rest]),
    do: [{:definitions, [{term, last <> " " <> text} | pairs]} | rest]

  defp add_line(text, []), do: [{:bullets, [text]}]

  defp definition(text) do
    case String.split(text, ": ", parts: 2) do
      [term, meaning] -> {term, meaning}
      [term] -> {term, ""}
    end
  end
end
