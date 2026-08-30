defmodule TinyLlmTalkWeb.SlideComponents do
  @moduledoc """
  Every slide's drawing, one function clause per slide id.

  Pattern matching is the whole dispatch mechanism: `TinyLlmTalk.Deck` names a
  slide, this module draws it, and a slide with no clause yet falls through to
  the stub at the bottom, which shows its title and its speaker notes. That
  means the deck is presentable from the first minute and gets less grey as it
  gets written.
  """

  use Phoenix.Component

  import TinyLlmTalkWeb.DeckComponents

  alias TinyLlmTalk.{Deck, Slide}

  # The slides that have a clause below. A slide that is still a stub ignores
  # `@step`, so navigation must treat it as a single beat or it gets shown
  # several times over, identically. The list is checked against the clauses in
  # the tests, so it cannot quietly drift.
  @drawn [
    :the_sentence,
    :the_bracket,
    :what_you_leave_with,
    :from_nothing,
    :linear_and_softmax,
    :attention_code
  ]

  @doc "Whether this slide has been drawn yet, or is still a stub."
  @spec drawn?(atom()) :: boolean()
  def drawn?(id), do: id in @drawn

  @doc """
  The steps a slide actually has: what the arc plans for once it is drawn, and
  one until then.
  """
  @spec steps(pos_integer()) :: pos_integer()
  def steps(index) do
    slide = Deck.at(index)

    if drawn?(slide.id), do: slide.steps, else: 1
  end

  attr :slide, Slide, required: true
  attr :step, :integer, required: true

  # 0. Cold open ------------------------------------------------------------

  def slide(%{slide: %Slide{id: :the_sentence}} = assigns) do
    ~H"""
    <section class="slide slide--centred">
      <.probe words={~w(the llama who chases the dogs ____)} class="probe--huge" />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :the_bracket}} = assigns) do
    ~H"""
    <section class="slide slide--centred">
      <.probe
        words={[
          "the",
          {"llama", :subject},
          "who",
          "chases",
          "the",
          {"dogs", :distractor},
          {"____", :blank}
        ]}
        bracket={2..7}
        show_marks={@step >= 2}
        show_bracket={@step >= 3}
        class="probe--huge"
      />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :what_you_leave_with}} = assigns) do
    ~H"""
    <section class="slide slide--centred">
      <p class="slide__eyebrow">what you leave with</p>
      <h2 class="slide__statement">
        You will be able to explain how a transformer works.
      </h2>
      <.step n={2} step={@step} class="slide__lede">
        Attention is the part you will be able to describe out loud.
      </.step>
      <.step n={3} step={@step}>
        <ol class="beats">
          <li>each position looks back at the ones before it</li>
          <li>scores them</li>
          <li>and pulls in what it needs</li>
        </ol>
      </.step>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :from_nothing}} = assigns) do
    ~H"""
    <section class="slide">
      <h2 class="slide__title">From nothing</h2>
      <ul class="claims">
        <.step n={1} step={@step}>
          <li>The Elixir standard library. Nothing else.</li>
        </.step>
        <.step n={2} step={@step}>
          <li><code>mix.exs</code> deps are empty.</li>
        </.step>
        <.step n={3} step={@step}>
          <li>15,104 parameters.</li>
        </.step>
        <.step n={4} step={@step}>
          <li>Trains in under 30 seconds on this laptop.</li>
        </.step>
        <.step n={5} step={@step}>
          <li>Every gradient by hand, and checked.</li>
        </.step>
      </ul>
    </section>
    """
  end

  # 3. Neural bigram -------------------------------------------------------

  def slide(%{slide: %Slide{id: :linear_and_softmax}} = assigns) do
    ~H"""
    <section class="slide">
      <h2 class="slide__title">{@slide.title}</h2>
      <.code
        path="lib/tiny_llm/embedder.ex"
        function={:forward}
        step={@step}
        focus={[:all, 2..2, 3..3, :all]}
      />
    </section>
    """
  end

  # 4. Attention ------------------------------------------------------------

  def slide(%{slide: %Slide{id: :attention_code}} = assigns) do
    ~H"""
    <section class="slide">
      <h2 class="slide__title">{@slide.title}</h2>
      <.code
        path="lib/tiny_llm/attention.ex"
        range={198..213}
        step={@step}
        focus={[:all, 1..3, 5..8, 9..13, 14..14, 16..16, :all]}
      />
    </section>
    """
  end

  # The stub every unwritten slide falls through to -------------------------

  def slide(assigns) do
    assigns =
      assign(assigns,
        section: Deck.section(assigns.slide),
        clause: "not drawn yet · :#{assigns.slide.id}"
      )

    ~H"""
    <section class="slide slide--stub">
      <p class="slide__eyebrow">{@section.number}. {@section.title}</p>
      <h2 class="slide__title">{@slide.title}</h2>
      <p class="slide__stub-notes">{Slide.prose(@slide)}</p>
      <p class="slide__stub-flag">{@clause}</p>
    </section>
    """
  end
end
