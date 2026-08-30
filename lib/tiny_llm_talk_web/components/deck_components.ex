defmodule TinyLlmTalkWeb.DeckComponents do
  @moduledoc """
  The furniture every slide sits in: the footer, the reveal step, the code
  block, and the probe sentence the talk opens and closes on.

  These are the pieces a slide body is allowed to assume. Anything a single
  slide needs and no other slide needs belongs in that slide's clause in
  `TinyLlmTalkWeb.SlideComponents`, not here.
  """

  use Phoenix.Component

  alias TinyLlmTalk.{Code, Deck, Slide, Source}

  @doc "Repo link, section, and position. On every slide, by policy."
  attr :slide, Slide, required: true

  def footer(assigns) do
    assigns =
      assign(assigns,
        section: Deck.section(assigns.slide),
        repo: Application.fetch_env!(:tiny_llm_talk, :repo_label),
        count: Deck.count()
      )

    ~H"""
    <footer class="deck-footer">
      <span class="deck-footer__repo">{@repo}</span>
      <span class="deck-footer__section">{@section.number}. {@section.title}</span>
      <span class="deck-footer__position">{@slide.index} / {@count}</span>
    </footer>
    """
  end

  @doc "Content that appears on step `n` and stays."
  attr :n, :integer, required: true
  attr :step, :integer, required: true
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def step(assigns) do
    ~H"""
    <div class={["step", @class, @step >= @n && "step--shown"]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  A function quoted out of the `tiny_llm` checkout, highlighted, with the step's
  window lit and the rest dimmed.

  The caption names the file and line it came from, which is the claim the whole
  talk rests on: this is the code, not a simplified version of the code.
  """
  attr :path, :string, required: true
  attr :function, :atom, default: nil
  attr :range, :any, default: nil
  attr :focus, :list, default: []
  attr :step, :integer, default: 1
  attr :caption, :boolean, default: true

  def code(assigns) do
    quotation = quote_source(assigns)

    assigns =
      assign(assigns,
        quotation: quotation,
        rows: Code.focused(quotation.code, assigns.focus, assigns.step)
      )

    ~H"""
    <figure class="code">
      <pre class={Code.css_class()} style={"font-size: #{Code.font_size(length(@rows))}px"}><code>
        <span
          :for={row <- @rows}
          class={["code__line", not row.lit? && "code__line--dim"]}
        ><span class="code__number">{row.number}</span>{row.html}</span>
      </code></pre>
      <figcaption :if={@caption} class="code__caption">
        {@quotation.location}
      </figcaption>
    </figure>
    """
  end

  @doc """
  The probe sentence, drawn as a grid so the bracket underneath can span from
  the subject to the blank without anyone measuring anything.
  """
  attr :words, :list, required: true, doc: "words, or {word, mark} pairs"
  attr :bracket, :any, default: nil, doc: "a first..last range over word positions"
  attr :show_bracket, :boolean, default: false
  attr :show_marks, :boolean, default: false
  attr :class, :string, default: nil

  def probe(assigns) do
    assigns = assign(assigns, words: Enum.map(assigns.words, &normalize_word/1))

    ~H"""
    <div class={["probe", @class]} style={"--probe-columns: #{length(@words)}"}>
      <span
        :for={{word, mark} <- @words}
        class={["probe__word", mark && "probe__word--#{mark}", @show_marks && "probe__word--marked"]}
      >{word}</span>
      <span
        :if={@bracket}
        class={["probe__bracket", @show_bracket && "probe__bracket--shown"]}
        style={bracket_style(@bracket)}
      />
    </div>
    """
  end

  ## PRIVATE FUNCTIONS

  defp quote_source(%{function: name, path: path}) when is_atom(name) and not is_nil(name) do
    Source.function(path, name)
  end

  defp quote_source(%{range: %Range{} = range, path: path}) do
    Source.lines(path, range)
  end

  defp normalize_word({word, mark}), do: {word, mark}
  defp normalize_word(word), do: {word, nil}

  defp bracket_style(first..last//_step), do: "grid-column: #{first} / #{last + 1};"
end
