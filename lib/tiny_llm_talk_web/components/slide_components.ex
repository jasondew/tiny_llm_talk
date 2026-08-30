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
      <.step n={3} step={@step} class="slide__punchline">
        That bracket is the talk.
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
        clause: "slide(%{slide: %Slide{id: :#{assigns.slide.id}}} = assigns)"
      )

    ~H"""
    <section class="slide slide--stub">
      <p class="slide__eyebrow">{@section.number}. {@section.title}</p>
      <h2 class="slide__title">{@slide.title}</h2>
      <p class="slide__stub-notes">{Slide.prose(@slide)}</p>
      <p class="slide__stub-flag">
        not drawn yet &middot; add a <code>{@clause}</code> clause
      </p>
    </section>
    """
  end
end
