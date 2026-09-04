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
        rows: Code.focused(quotation.code, assigns.focus, assigns.step),
        longest: Code.longest_line(quotation.code),
        location: quotation.location
      )

    ~H"""
    <.listing rows={@rows} longest={@longest} caption={@caption && @location} />
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
  attr :caption, :any, default: nil

  defp listing(assigns) do
    ~H"""
    <figure class="code">
      <pre class={Code.css_class()} style={"font-size: #{Code.font_size(length(@rows), @longest)}px"}><code>
        <span
          :for={row <- @rows}
          class={["code__line", not row.lit? && "code__line--dim"]}
        ><span class="code__number">{row.number}</span>{row.html}</span>
      </code></pre>
      <figcaption :if={@caption} class="code__caption">{@caption}</figcaption>
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

  @doc """
  How to join, over a screen share.

  The URL leads, because everyone watching is already in a browser and a link is
  one paste in the chat. The code is small and secondary: it is only there for
  the people watching on a television or a second monitor, who reach for a phone
  instead. In a room those weightings would be the other way round.
  """
  attr :size, :integer, default: 150

  def qr(assigns) do
    assigns = assign(assigns, url: join_url(), svg: qr_svg(assigns.size))

    ~H"""
    <div class="join-card">
      <div class="join-card__words">
        <p class="join-card__label">join at</p>
        <p class="join-card__url">{display_url(@url)}</p>
        <p class="join-card__aside">also in the chat</p>
      </div>
      <div class="join-card__code">{@svg}</div>
    </div>
    """
  end

  @doc """
  A live vote, as bars in the order the activity lists its options, so nothing
  reorders under the audience while they are still voting.
  """
  attr :tally, :list, required: true
  attr :answer, :string, default: nil
  attr :reveal, :boolean, default: false
  attr :wide, :boolean, default: false, doc: "labels are sentences, not words"

  def tally(assigns) do
    assigns = assign(assigns, total: assigns.tally |> Enum.map(&elem(&1, 1)) |> Enum.sum())

    ~H"""
    <div class={["tally", @wide && "tally--wide"]}>
      <div
        :for={{option, count} <- @tally}
        class={["tally__row", (@reveal and option == @answer) && "tally__row--answer"]}
      >
        <span class="tally__label">{option}</span>
        <span class="tally__track">
          <span class="tally__fill" style={"width: #{share(count, @total)}%"} />
        </span>
        <span class="tally__count">{count}</span>
      </div>
      <p class="tally__total">{@total} {if @total == 1, do: "vote", else: "votes"}</p>
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

  defp join_url, do: Application.fetch_env!(:tiny_llm_talk, :join_url)

  # Nobody types a scheme. Show what a person would actually key in.
  defp display_url(url), do: String.replace(url, ~r{^https?://}, "")

  defp qr_svg(size) do
    join_url()
    |> EQRCode.encode()
    |> EQRCode.svg(width: size, color: "#000000", background_color: "#FFFFFF")
    |> Phoenix.HTML.raw()
  end

  defp share(_count, 0), do: 0
  defp share(count, total), do: Float.round(count / total * 100, 1)

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
