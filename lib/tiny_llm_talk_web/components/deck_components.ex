defmodule TinyLlmTalkWeb.DeckComponents do
  @moduledoc """
  The furniture every slide sits in: the footer, the reveal step, the code
  block, the probe sentence the talk opens and closes on, and the pieces an
  audience question is made of.

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
        talk: Deck.title(),
        count: Deck.count()
      )

    ~H"""
    <footer class="deck-footer">
      <span class="deck-footer__talk">{@talk}</span>
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
  attr :elide, :any, default: nil, doc: "lines of the listing to fold into one row of dots"
  attr :width, :integer, default: nil, doc: "the pixels the listing has when it shares the slide"

  slot :annotation, doc: "a note drawn at the end of one line of the listing" do
    attr :line, :integer, required: true, doc: "the line, counted from 1 within the listing"
  end

  def code(assigns) do
    quotation = quote_source(assigns)

    assigns =
      assign(assigns,
        rows:
          quotation.code
          |> Code.focused(assigns.focus, assigns.step)
          |> Code.elide(assigns.elide),
        longest: Code.longest_line(quotation.code),
        location: quotation.location
      )

    ~H"""
    <.listing
      rows={@rows}
      longest={@longest}
      width={@width}
      caption={@caption && @location}
      annotations={@annotation}
    />
    """
  end

  @doc """
  Elixir written for the slide rather than quoted from the model: the `Map.get`
  the room already knows, and the fuzzy version of it. Highlighted and stepped
  the same way, but with no caption, because it is not a claim about the repo.
  """
  attr :source, :string, required: true
  attr :focus, :list, default: []
  attr :step, :integer, default: 1

  def snippet(assigns) do
    assigns =
      assign(assigns,
        rows: Code.focused(assigns.source, assigns.focus, assigns.step),
        longest: Code.longest_line(assigns.source)
      )

    ~H"""
    <.listing rows={@rows} longest={@longest} caption={nil} />
    """
  end

  attr :rows, :list, required: true
  attr :longest, :integer, required: true
  attr :width, :integer, default: nil
  attr :caption, :any, default: nil
  attr :annotations, :list, default: []

  defp listing(assigns) do
    ~H"""
    <figure class="code">
      <pre
        class={Code.css_class()}
        style={"font-size: #{Code.font_size(length(@rows), @longest, @width)}px"}
      ><code>
        <span
          :for={row <- @rows}
          class={["code__line", not row.lit? && "code__line--dim"]}
        ><span class="code__number">{row.number}</span>{row.html}<span
            :for={annotation <- annotations_for(@annotations, row.number)}
            class="code__annotation"
          >{render_slot(annotation)}</span></span>
      </code></pre>
      <figcaption :if={@caption} class="code__caption">{@caption}</figcaption>
    </figure>
    """
  end

  defp annotations_for(annotations, line) do
    Enum.filter(annotations, &(&1.line == line))
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

  @doc """
  A row of choices the speaker clicks through, on either window. The chosen one
  is lit; the rest wait.
  """
  attr :name, :string, required: true
  attr :options, :list, required: true
  attr :chosen, :string, required: true
  attr :class, :string, default: nil

  def picker(assigns) do
    ~H"""
    <div class={["picker", @class]}>
      <button
        :for={option <- @options}
        type="button"
        phx-click="control"
        phx-value-name={@name}
        phx-value-choice={option}
        class={["picker__option", option == @chosen && "picker__option--chosen"]}
      >{option}</button>
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
