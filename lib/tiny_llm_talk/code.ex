defmodule TinyLlmTalk.Code do
  @moduledoc """
  Elixir source, highlighted, split into lines.

  Splitting into lines is the whole point: a code slide reveals a line at a
  time, so the room reads one idea while you talk about it instead of scanning
  a wall. Makeup lexes the snippet as a whole, so a heredoc or a multi-line
  string still colours correctly; only the formatting is per line.
  """

  alias Makeup.Formatters.HTML.HTMLFormatter
  alias Makeup.Lexers.ElixirLexer

  @css_class "makeup"

  # The stage is 720px tall and a code slide has a title, a caption, and the
  # footer to pay for. What is left over is roughly this, and a snippet is sized
  # to fill it rather than to a fixed size, so a long function shrinks instead of
  # being silently clipped off the bottom of the slide.
  @available_height 380
  @line_height 1.45
  @largest 24.0
  @smallest 8.0

  # The stage is 1280 wide, a slide pads 96 a side, and the listing pads 24
  # plus a gutter for the line numbers. A monospace glyph is about 0.6em wide.
  @available_width 1000
  @glyph_width 0.6

  @doc "The CSS for the highlighter, inlined once in the layout."
  @spec stylesheet(atom()) :: String.t()
  def stylesheet(style \\ :one_dark_style), do: HTMLFormatter.stylesheet(style, @css_class)

  @spec css_class() :: String.t()
  def css_class, do: @css_class

  @doc """
  The font size that fits `line_count` lines in the space a code slide has.

  The floor is the smallest thing that survives a screen share and its
  compression. Hitting it means the snippet is too long for the medium, so it
  overflows visibly rather than shrinking into an unreadable grey block: quote a
  narrower range instead.
  """
  @spec font_size(pos_integer(), pos_integer()) :: float()
  def font_size(line_count, longest_line \\ 1) do
    by_height = @available_height / (line_count * @line_height)
    by_width = @available_width / (max(longest_line, 1) * @glyph_width)

    by_height
    |> min(by_width)
    |> min(@largest)
    |> max(@smallest)
    |> Float.round(1)
  end

  @doc "The longest line in a snippet, in characters, for `font_size/2`."
  @spec longest_line(String.t()) :: pos_integer()
  def longest_line(source) do
    source |> String.split("\n") |> Enum.map(&String.length/1) |> Enum.max(fn -> 1 end)
  end

  @doc "One safe HTML fragment per line of `source`."
  @spec lines(String.t()) :: [Phoenix.HTML.safe()]
  def lines(source) do
    source
    |> String.trim_trailing()
    |> ElixirLexer.lex()
    |> group_by_line()
    |> Enum.map(&Phoenix.HTML.raw(HTMLFormatter.format_inner_as_binary(&1, [])))
  end

  @doc """
  Highlighted lines tagged with whether this step lights them up.

  `focus` is one entry per step: a range, a list of ranges, or `:all`. Long
  functions are worth showing whole and then narrowing, rather than dribbling
  out a line at a time, so a step dims everything outside its window instead of
  hiding it.
  """
  @spec focused(String.t(), [Range.t() | [Range.t()] | :all], pos_integer()) :: [
          %{number: pos_integer(), html: Phoenix.HTML.safe(), lit?: boolean()}
        ]
  def focused(source, focus, step) do
    window = Enum.at(focus, step - 1, :all)

    source
    |> lines()
    |> Enum.with_index(1)
    |> Enum.map(fn {html, number} ->
      %{number: number, html: html, lit?: lit?(window, number)}
    end)
  end

  ## PRIVATE FUNCTIONS

  defp lit?(:all, _number), do: true
  defp lit?(nil, _number), do: true
  defp lit?(first..last//_step, number), do: number in first..last
  defp lit?(windows, number) when is_list(windows), do: Enum.any?(windows, &lit?(&1, number))

  defp group_by_line(tokens) do
    {done, current} = Enum.reduce(tokens, {[], []}, &split_token/2)
    Enum.reverse([Enum.reverse(current) | done])
  end

  defp split_token({type, meta, value}, {done, current}) do
    [first | rest] = value |> IO.iodata_to_binary() |> String.split("\n")

    Enum.reduce(rest, {done, prepend(current, {type, meta, first})}, fn part, {done, current} ->
      {[Enum.reverse(current) | done], prepend([], {type, meta, part})}
    end)
  end

  defp prepend(current, {_type, _meta, ""}), do: current
  defp prepend(current, token), do: [token | current]
end
