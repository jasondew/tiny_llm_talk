defmodule TinyLlmTalkWeb.SlideComponents do
  @moduledoc """
  Every slide's drawing, one function clause per slide id.

  Pattern matching is the whole dispatch mechanism: `TinyLlmTalk.Deck` names a
  slide, this module draws it, and a slide with no clause yet falls through to
  the stub at the bottom, which shows its title and its speaker notes.

  Figures are handed the model's own numbers from `TinyLlmTalk.Model` rather
  than a transcription of them, so a slide cannot quote a number the checkpoint
  does not produce. That is the whole reason the deck is a Phoenix app.
  """

  use Phoenix.Component

  import TinyLlmTalkWeb.DeckComponents
  import TinyLlmTalkWeb.FigureComponents

  alias TinyLlm.Vocab
  alias TinyLlmTalk.{Deck, Model, Room, Slide}

  @drawn [
    :the_sentence,
    :the_vote,
    :the_bracket,
    :what_you_leave_with,
    :from_nothing,
    :vocabulary,
    :grammar,
    :one_function,
    :how_we_score_it,
    :counting_pairs,
    :bigram_heatmap,
    :bigram_box,
    :bigram_wins,
    :bigram_fails,
    :the_floor,
    :what_does_learning_buy,
    :embeddings,
    :linear_and_softmax,
    :training,
    :demo_training_loss,
    :pca_scatter,
    :learning_was_not_the_problem,
    :what_we_want,
    :dot_product,
    :query_key_value,
    :scores,
    :pulling_in,
    :causal_mask,
    :positions,
    :attention_code,
    :attention_bet,
    :demo_attention_heatmap,
    :reading_the_heatmap,
    :audience_sentence,
    :the_number,
    :attention_sink,
    :architecture,
    :residuals,
    :mlp,
    :rmsnorm,
    :two_hop,
    :scale,
    :the_loop,
    :temperature,
    :demo_temperature,
    :the_tradeoff,
    :what_is_not_here,
    :the_sentence_again
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
  attr :controls, :map, default: %{}
  attr :room, Room, default: %Room{}

  # 0. Cold open ------------------------------------------------------------

  def slide(%{slide: %Slide{id: :the_sentence}} = assigns) do
    ~H"""
    <section class="slide slide--centred">
      <.probe words={~w(the llama who chases the dogs ____)} class="probe--huge" />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :the_vote}} = assigns) do
    ~H"""
    <section class="slide slide--tight">
      <.probe words={~w(the llama who chases the dogs ____)} class="probe--wide" />
      <div class="ask">
        <.qr />
        <.tally tally={Room.tally(@room, :verb_vote)} answer="flees" reveal={@step >= 2} />
      </div>
      <p :if={@step >= 2} class="slide__note">
        Everybody knew. Nobody can say how, in fewer than a paragraph.
      </p>
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
          <li>Trains in under a minute and a half on this laptop.</li>
        </.step>
        <.step n={5} step={@step}>
          <li>Every gradient by hand, and checked.</li>
        </.step>
      </ul>
    </section>
    """
  end

  # 1. The setup ------------------------------------------------------------

  def slide(%{slide: %Slide{id: :vocabulary}} = assigns) do
    assigns = assign(assigns, groups: vocabulary_groups())

    ~H"""
    <section class="slide">
      <h2 class="slide__title">Thirty-two words</h2>
      <p class="slide__lede">One word is one token is one integer. There is no tokenizer.</p>
      <div class="word-groups">
        <div :for={group <- @groups} class="word-group">
          <p class="word-group__name">{group.name}</p>
          <p class="word-group__words">
            <span :for={word <- group.words} class={["word", group.kind && "word--#{group.kind}"]}>
              {word}
            </span>
          </p>
        </div>
      </div>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :grammar}} = assigns) do
    assigns = assign(assigns, sentences: Model.showcase_sentences())

    ~H"""
    <section class="slide">
      <h2 class="slide__title">A grammar we own</h2>
      <ul class="examples">
        <li :for={sentence <- @sentences}>{Enum.join(sentence, " ")}</li>
      </ul>
      <ol class="rules">
        <li>A subject agrees with its verb.</li>
        <li>A relative clause's verb agrees with the head noun, not with whatever is nearest.</li>
      </ol>
      <p class="slide__note">
        We own the training data because then we know the right answer to every question
        we ask the model. Nobody knows that about a real corpus.
      </p>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :one_function}} = assigns) do
    assigns = assign(assigns, distribution: Model.distribution(Model.probe(), 1.0))

    ~H"""
    <section class="slide slide--centred">
      <h2 class="slide__title">A language model is one function</h2>
      <.function_box
        label="a language model"
        input="the words so far"
        distribution={@distribution}
      />
      <p class="slide__note">Every model in this talk is that function. Only the context changes.</p>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :how_we_score_it}} = assigns) do
    assigns =
      assign(assigns, knowing_nothing: Model.knowing_nothing(), floor: Model.bigram_floor())

    ~H"""
    <section class="slide">
      <h2 class="slide__title">How surprised is it?</h2>
      <.step n={1} step={@step} class="slide__lede">
        Held-out loss: how surprised the model is by sentences it has not seen. Lower is better.
      </.step>
      <div class="stat-row">
        <.step n={2} step={@step}>
          <.stat value={format_loss(@knowing_nothing)} label="knowing nothing" note="ln(32)" />
        </.step>
        <.step n={3} step={@step}>
          <.stat
            value={format_loss(@floor)}
            label="the best anything can do seeing one word"
            note="H(next | previous)"
            tone="cool"
          />
        </.step>
      </div>
      <.step n={3} step={@step} class="slide__note">
        Both lines are on every loss chart from here on.
      </.step>
    </section>
    """
  end

  # 2. Bigram ---------------------------------------------------------------

  def slide(%{slide: %Slide{id: :counting_pairs}} = assigns) do
    assigns = assign(assigns, row: Model.bigram_row("chases"))

    ~H"""
    <section class="slide">
      <h2 class="slide__title">Count every adjacent pair</h2>
      <p class="slide__lede">
        Two thousand sentences. For every word, what came after it, and how often.
      </p>
      <p class="row-caption">what follows <span class="word word--lit">chases</span></p>
      <.bars values={@row} words={Vocab.words()} top={5} highlight={~w(the a)} />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :bigram_heatmap}} = assigns) do
    assigns = assign(assigns, highlight: bigram_highlight(assigns.step))

    ~H"""
    <section class="slide slide--tight">
      <h2 class="slide__title slide__title--small">Thirty-two by thirty-two</h2>
      <.heatmap
        values={Model.bigram()}
        row_labels={Vocab.words()}
        column_labels={Vocab.words()}
        highlight={@highlight}
        scale={:sqrt}
        cell={15}
      />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :bigram_box}} = assigns) do
    ~H"""
    <section class="slide slide--centred">
      <h2 class="slide__title">The same function, with a table in it</h2>
      <.function_box
        label="count table"
        input="the last word"
        distribution={Model.bigram_row("dogs")}
      />
      <p class="slide__note">Look up the row for the last word. Pick from it.</p>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :bigram_wins}} = assigns) do
    assigns = assign(assigns, sentences: Model.bigram_sentences(8))

    ~H"""
    <section class="slide">
      <h2 class="slide__title">It gets a surprising amount right</h2>
      <ul class="examples examples--generated">
        <li :for={sentence <- @sentences}>{Enum.join(sentence, " ")}</li>
      </ul>
      <p class="slide__note">
        Determiners, the period, and agreement whenever the noun is right there.
      </p>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :bigram_fails}} = assigns) do
    assigns = assign(assigns, agreement: Model.agreement(:bigram))

    ~H"""
    <section class="slide">
      <h2 class="slide__title">Where it cannot</h2>
      <.probe words={probe_marks() ++ [{"____", :blank}]} show_marks class="probe--wide" />
      <.step n={2} step={@step}>
        <p class="row-caption">
          all it sees is <span class="word word--distractor">dogs</span>, and this is that row
        </p>
        <.bars values={Model.bigram_row("dogs")} words={Vocab.words()} top={4} highlight={~w(flee)} />
      </.step>
      <.step n={3} step={@step}>
        <.stat
          value={format_percent(@agreement)}
          label="right, on probes where the nearest noun disagrees"
          tone="bad"
        />
      </.step>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :the_floor}} = assigns) do
    assigns =
      assign(assigns, floor: Model.bigram_floor(), held_out: Model.bigram_held_out())

    ~H"""
    <section class="slide slide--centred">
      <h2 class="slide__statement">Nothing that sees one word beats {format_loss(@floor)}.</h2>
      <div class="stat-row">
        <.stat value={format_loss(@floor)} label="the floor" note="H(next | previous)" tone="cool" />
        <.stat value={format_loss(@held_out)} label="what the count table scores" note="held out" />
      </div>
      <p class="slide__note">
        The floor comes from the grammar, not from the model. The gap between the two is
        the price of counting rather than knowing.
      </p>
    </section>
    """
  end

  # 3. Neural bigram --------------------------------------------------------

  def slide(%{slide: %Slide{id: :what_does_learning_buy}} = assigns) do
    ~H"""
    <section class="slide slide--centred">
      <h2 class="slide__statement">If counting is optimal, what does learning buy?</h2>
      <p class="slide__lede">For this model: nothing.</p>
      <p class="slide__note">
        We build it anyway, because every part of it survives into the transformer.
      </p>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :embeddings}} = assigns) do
    assigns = assign(assigns, row: Model.embedding("llama"))

    ~H"""
    <section class="slide">
      <h2 class="slide__title">A word becomes a point</h2>
      <div class="lookup">
        <span class="lookup__word">llama</span>
        <span class="lookup__arrow">&rarr;</span>
        <span class="lookup__id">{Vocab.word_to_id("llama")}</span>
        <span class="lookup__arrow">&rarr;</span>
        <span class="lookup__row">
          <.spark :if={@row} values={Enum.map(@row, &abs/1)} />
          <.untrained :if={is_nil(@row)} what="This row of floats" />
        </span>
      </div>
      <p class="slide__note">
        Thirty-two floats, looked up from a table that starts random. Words that behave
        the same should end up near each other, and the model moves them there itself.
      </p>
    </section>
    """
  end

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

  def slide(%{slide: %Slide{id: :training}} = assigns) do
    ~H"""
    <section class="slide">
      <h2 class="slide__title">Training, all of it</h2>
      <ol class="beats beats--numbered">
        <.step n={1} step={@step}>
          <li>Loss is surprise at the right answer.</li>
        </.step>
        <.step n={2} step={@step}>
          <li>Every parameter has a slope: nudge it, and the loss goes up or down.</li>
        </.step>
        <.step n={3} step={@step}>
          <li>Move every parameter a small step downhill.</li>
        </.step>
        <.step n={4} step={@step}>
          <li>Repeat a few hundred times.</li>
        </.step>
      </ol>
      <.step n={4} step={@step} class="slide__note">
        Every slope in this repo is derived by hand and checked against a finite
        difference. No chain rule on screen.
      </.step>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :demo_training_loss}} = assigns) do
    assigns = assign(assigns, losses: Model.losses(:embedder))

    ~H"""
    <section class="slide">
      <h2 class="slide__title">It falls to the floor and stops</h2>
      <.loss_chart
        :if={@losses}
        losses={@losses}
        knowing_nothing={Model.knowing_nothing()}
        floor={Model.bigram_floor()}
        series_label="held-out loss, one word of context"
      />
      <.untrained :if={is_nil(@losses)} what="This loss curve" />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :pca_scatter}} = assigns) do
    assigns = assign(assigns, points: Model.embedding_scatter())

    ~H"""
    <section class="slide slide--tight">
      <h2 class="slide__title slide__title--small">What the embeddings learned</h2>
      <.scatter :if={@points} points={@points} />
      <.untrained :if={is_nil(@points)} what="This scatter" />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :learning_was_not_the_problem}} = assigns) do
    assigns =
      assign(assigns,
        bigram: Model.agreement(:bigram),
        embedder: Model.agreement(:embedder)
      )

    ~H"""
    <section class="slide slide--centred">
      <h2 class="slide__statement">Learning was never the problem.</h2>
      <div class="stat-row">
        <.stat value={format_percent(@bigram)} label="count table" tone="bad" />
        <.stat value={format_percent(@embedder)} label="learned, same context" tone="bad" />
      </div>
      <p class="slide__lede">
        Not close to each other by luck. They see the same one word, so they give the
        same answer, and on these probes that word is the one that lies.
      </p>
    </section>
    """
  end

  # 4. Attention ------------------------------------------------------------

  def slide(%{slide: %Slide{id: :what_we_want}} = assigns) do
    ~H"""
    <section class="slide slide--centred">
      <h2 class="slide__title">Reach back past the distractor</h2>
      <.probe
        words={probe_marks() ++ [{"____", :blank}]}
        bracket={3..8}
        show_marks
        show_bracket
        class="probe--wide"
      />
      <p class="slide__lede">
        A fixed window would not do it. The subject can be anywhere.
      </p>
      <p class="slide__note">
        So let the blank look at every earlier word and decide for itself which ones matter.
      </p>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :dot_product}} = assigns) do
    ~H"""
    <section class="slide">
      <h2 class="slide__title">A dot product is a similarity score</h2>
      <div class="arithmetic">
        <.step n={1} step={@step}>
          <p class="arithmetic__row"><span>a</span> 2.0 &nbsp; 1.0 &nbsp; &minus;3.0</p>
          <p class="arithmetic__row"><span>b</span> 1.0 &nbsp; 4.0 &nbsp; &nbsp;&nbsp;0.5</p>
        </.step>
        <.step n={2} step={@step}>
          <p class="arithmetic__row arithmetic__row--work">
            <span>multiply pairwise</span> 2.0 &nbsp; 4.0 &nbsp; &minus;1.5
          </p>
        </.step>
        <.step n={3} step={@step}>
          <p class="arithmetic__row arithmetic__row--total"><span>add</span> 4.5</p>
        </.step>
      </div>
      <.step n={3} step={@step} class="slide__note">
        Big when two vectors point the same way, near zero when they are unrelated.
        And we can learn what "similar" ought to mean.
      </.step>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :query_key_value}} = assigns) do
    ~H"""
    <section class="slide">
      <h2 class="slide__title">Query, key, value</h2>
      <dl class="definitions">
        <.step n={1} step={@step}>
          <dt>query</dt>
          <dd>what this position is looking for</dd>
        </.step>
        <.step n={2} step={@step}>
          <dt>key</dt>
          <dd>what this position is advertising</dd>
        </.step>
        <.step n={3} step={@step}>
          <dt>value</dt>
          <dd>what this position hands over if it gets chosen</dd>
        </.step>
      </dl>
      <.step n={4} step={@step} class="slide__note">
        Three weighted sums of the same embedding, through three learned tables: <code>Wq</code>, <code>Wk</code>, <code>Wv</code>. Nothing else.
      </.step>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :scores}} = assigns) do
    assigns = assign(assigns, weights: blank_row())

    ~H"""
    <section class="slide">
      <h2 class="slide__title">Score every earlier word</h2>
      <ol class="beats beats--numbered">
        <.step n={1} step={@step}>
          <li>Take the blank's query. Dot it against every earlier key.</li>
        </.step>
        <.step n={2} step={@step}>
          <li>Divide by the square root of the width, so the numbers stay tame.</li>
        </.step>
        <.step n={3} step={@step}>
          <li>Softmax across them. Now it is a probability of where to look.</li>
        </.step>
      </ol>
      <.step n={4} step={@step}>
        <.bars
          :if={@weights}
          values={@weights}
          words={Model.probe()}
          top={4}
          highlight={~w(who dogs llama)}
        />
        <.untrained :if={is_nil(@weights)} what="These attention weights" />
      </.step>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :pulling_in}} = assigns) do
    ~H"""
    <section class="slide slide--centred">
      <h2 class="slide__title">Pull in what you chose</h2>
      <p class="slide__statement slide__statement--wide">
        Multiply each earlier position's value by its weight, and add them up.
      </p>
      <p class="slide__lede">
        The blank now holds a blend of the words it decided to look at.
      </p>
      <p class="slide__note">
        One more weighted sum, <code>Wo</code>, and out through the same softmax as before.
      </p>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :causal_mask}} = assigns) do
    ~H"""
    <section class="slide">
      <h2 class="slide__title">Each position may only see what came before it</h2>
      <.heatmap
        values={causal_mask(length(Model.probe()))}
        row_labels={Model.probe()}
        column_labels={Model.probe()}
        cell={44}
      />
      <p class="slide__note">
        Every position predicts at once during training, so the future gets a score of
        minus a billion before the softmax, which rounds to no attention at all.
      </p>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :positions}} = assigns) do
    ~H"""
    <section class="slide slide--centred">
      <h2 class="slide__statement">Attention is a bag until you tell it otherwise.</h2>
      <p class="slide__lede">
        As described, it does not know that <span class="word word--subject">llama</span>
        came before <span class="word word--distractor">dogs</span>.
      </p>
      <p class="slide__note">
        So each position gets a learned vector of its own, added to the word's embedding.
        Sixteen positions, sixteen vectors. Now it can tell the noun near the start from
        the noun near the end.
      </p>
    </section>
    """
  end

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

  def slide(%{slide: %Slide{id: :attention_bet}} = assigns) do
    ~H"""
    <section class="slide slide--tight">
      <h2 class="slide__title slide__title--small">
        Which word will the blank look at hardest?
      </h2>
      <.probe words={probe_marks() ++ [{"____", :blank}]} show_marks class="probe--wide" />
      <div class="ask">
        <.qr size={200} />
        <.tally tally={Room.tally(@room, :attention_bet)} answer="who" reveal={@step >= 2} />
      </div>
      <p :if={@step >= 2} class="slide__note">
        It is <span class="word word--lit">who</span>. Nobody guesses that, including me,
        the first time.
      </p>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :demo_attention_heatmap}} = assigns) do
    assigns = assign(assigns, weights: Model.attention(Model.probe()))

    ~H"""
    <section class="slide">
      <h2 class="slide__title slide__title--small">Where each position looks</h2>
      <.heatmap
        :if={@weights}
        values={@weights}
        row_labels={Model.probe()}
        column_labels={Model.probe()}
        show_values
        cell={44}
      />
      <.untrained :if={is_nil(@weights)} what="This heatmap" />
      <p class="slide__note">
        Rows predict, columns are looked at. The upper triangle is empty, exactly as the
        mask says it must be.
      </p>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :reading_the_heatmap}} = assigns) do
    assigns = assign(assigns, weights: blank_row())

    ~H"""
    <section class="slide">
      <h2 class="slide__title">Read it honestly</h2>
      <.bars
        :if={@weights}
        values={@weights}
        words={Model.probe()}
        top={4}
        highlight={~w(who dogs llama)}
      />
      <.untrained :if={is_nil(@weights)} what="These weights" />
      <.step n={2} step={@step} class="slide__lede">
        It is not looking at <span class="word word--subject">llama</span>. And it does not
        need to: it reads the subject's number off <span class="word">chases</span>, which
        already agrees with the head noun.
      </.step>
      <.step n={3} step={@step} class="slide__note">
        The point is not that it draws the bracket we imagined. The point is that it is
        visibly structured rather than flat, and it gets the answer.
      </.step>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :audience_sentence}} = assigns) do
    assigns =
      assign(assigns,
        submissions: Room.popular(assigns.room, 6),
        featured: assigns.room.featured,
        weights: featured_attention(assigns.room)
      )

    ~H"""
    <section class="slide slide--tight">
      <h2 class="slide__title slide__title--small">Your sentence</h2>

      <div :if={is_nil(@featured)} class="ask">
        <.qr size={200} />
        <div class="submissions">
          <p :if={@submissions == []} class="slide__note">Nothing yet. Keep tapping.</p>
          <button
            :for={{words, _times} <- @submissions}
            type="button"
            phx-click="feature"
            phx-value-words={Enum.join(words, " ")}
            class="submissions__item"
          >{Enum.join(words, " ")}</button>
        </div>
      </div>

      <div :if={@featured}>
        <p class="row-caption">{Enum.join(@featured, " ")}</p>
        <.heatmap
          :if={@weights}
          values={@weights}
          row_labels={["<start>" | @featured]}
          column_labels={["<start>" | @featured]}
          show_values
          cell={heatmap_cell(@featured)}
        />
        <.untrained :if={is_nil(@weights)} what="This heatmap" />
      </div>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :the_number}} = assigns) do
    assigns =
      assign(assigns,
        bigram: Model.agreement(:bigram),
        embedder: Model.agreement(:embedder),
        transformer: Model.agreement(:transformer)
      )

    ~H"""
    <section class="slide slide--centred">
      <h2 class="slide__title">On the probes where the nearest noun lies</h2>
      <div class="stat-row">
        <.stat value={format_percent(@bigram)} label="count table" tone="bad" />
        <.stat value={format_percent(@embedder)} label="neural bigram" tone="bad" />
        <.stat value={format_percent(@transformer)} label="one attention head" tone="good" />
      </div>
      <p class="slide__lede">
        The one-word models are not unlucky here. They are wrong every single time,
        because the only word they see is the one pointing the wrong way.
      </p>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :attention_sink}} = assigns) do
    assigns = assign(assigns, weights: row_for("chases"))

    ~H"""
    <section class="slide">
      <h2 class="slide__title">It found the attention sink by itself</h2>
      <.bars
        :if={@weights}
        values={@weights}
        words={Model.probe()}
        top={3}
        highlight={["<start>"]}
      />
      <.untrained :if={is_nil(@weights)} what="This row" />
      <p class="slide__lede">
        The first verb has nothing useful behind it, so it dumps almost all of its
        attention on the start token.
      </p>
      <p class="slide__note">
        Production transformers do exactly this, and it has a name. Fifteen thousand
        parameters reproduced it unprompted.
      </p>
    </section>
    """
  end

  # 5. The rest of the block ------------------------------------------------

  def slide(%{slide: %Slide{id: :architecture}} = assigns) do
    ~H"""
    <section class="slide slide--tight">
      <h2 class="slide__title slide__title--small">The box, with its lid off</h2>
      <div class="stack">
        <.step n={1} step={@step}>
          <div class="stack__layer">embedding + position</div>
        </.step>
        <.step n={2} step={@step}>
          <div class="stack__layer stack__layer--norm">RMSNorm</div>
        </.step>
        <.step n={3} step={@step}>
          <div class="stack__layer stack__layer--attention">attention &mdash; gather</div>
        </.step>
        <.step n={4} step={@step}>
          <div class="stack__layer stack__layer--norm">RMSNorm</div>
        </.step>
        <.step n={5} step={@step}>
          <div class="stack__layer stack__layer--mlp">MLP &mdash; think</div>
        </.step>
        <.step n={6} step={@step}>
          <div class="stack__layer">32 probabilities</div>
        </.step>
      </div>
      <.step n={6} step={@step} class="slide__note">
        Two arrows go around the middle two: the residuals. Everything else you have seen.
      </.step>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :residuals}} = assigns) do
    ~H"""
    <section class="slide slide--centred">
      <h2 class="slide__statement">Keep what you had. Add what you learned.</h2>
      <p class="slide__lede">
        Do not replace the position's vector with what attention returned. Add it.
      </p>
      <p class="slide__note">
        Without this, information at the input has to survive every layer to reach the
        output. With it, passing through unchanged is the default.
      </p>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :mlp}} = assigns) do
    ~H"""
    <section class="slide">
      <h2 class="slide__title">A place to think about what you gathered</h2>
      <div class="widths">
        <span class="widths__step">32</span>
        <span class="widths__arrow">&rarr;</span>
        <span class="widths__step widths__step--wide">128</span>
        <span class="widths__arrow">&rarr;</span>
        <span class="widths__step">32</span>
      </div>
      <p class="slide__lede">
        Two weighted sums with a ReLU between, applied to each position on its own.
      </p>
      <p class="slide__note">
        Attention gathers; it cannot compute much about what it gathered. Half the
        parameters in the model are in here.
      </p>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :rmsnorm}} = assigns) do
    ~H"""
    <section class="slide slide--centred">
      <h2 class="slide__statement">
        Rescale each position's vector to a fixed size, so nothing blows up.
      </h2>
      <p class="slide__note">
        Before attention, before the MLP, with a learned gain. That is the whole slide.
      </p>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :two_hop}} = assigns) do
    assigns =
      assign(assigns,
        who: row_for("who"),
        mirror: mirror_row_for("who")
      )

    ~H"""
    <section class="slide">
      <h2 class="slide__title">The model drew the argument for depth</h2>
      <div class="two-up">
        <.step n={1} step={@step}>
          <p class="row-caption">the llama who chases the dogs</p>
          <.bars :if={@who} values={@who} words={Model.probe()} top={3} highlight={~w(llama)} />
        </.step>
        <.step n={2} step={@step}>
          <p class="row-caption">the dogs who chase the llama</p>
          <.bars
            :if={@mirror}
            values={@mirror}
            words={Model.mirror_probe()}
            top={3}
            highlight={~w(dogs)}
          />
        </.step>
      </div>
      <.untrained :if={is_nil(@who)} what="These rows" />
      <.step n={3} step={@step} class="slide__lede">
        The <span class="word">who</span> position has gathered the head noun into itself.
        And the blank attends to <span class="word">who</span>.
      </.step>
      <.step n={4} step={@step} class="slide__note">
        So half of a two-hop route exists, and one block cannot use the second hop, because
        both hops happen at once. A second block would read <span class="word">who</span>
        after it had already gathered the subject. That is what depth buys.
      </.step>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :scale}} = assigns) do
    ~H"""
    <section class="slide">
      <h2 class="slide__title">Same shape, bigger numbers</h2>
      <ul class="claims claims--compact">
        <.step n={1} step={@step}>
          <li>One head becomes many.</li>
        </.step>
        <.step n={2} step={@step}>
          <li>One block becomes dozens.</li>
        </.step>
        <.step n={3} step={@step}>
          <li>Thirty-two words become a hundred thousand, and a tokenizer.</li>
        </.step>
        <.step n={4} step={@step}>
          <li>Sixteen positions become a hundred thousand.</li>
        </.step>
        <.step n={5} step={@step} class="slide__punchline">
          <li>Nothing on this list is a new idea.</li>
        </.step>
      </ul>
    </section>
    """
  end

  # 6. Generating -----------------------------------------------------------

  def slide(%{slide: %Slide{id: :the_loop}} = assigns) do
    ~H"""
    <section class="slide">
      <h2 class="slide__title">Ask, pick, append, ask again</h2>
      <.code
        path="lib/tiny_llm/sampler.ex"
        function={:trace}
        step={@step}
        focus={[:all, 5..5, 11..13, 17..17]}
      />
      <.step n={4} step={@step} class="slide__note">
        No state carries between steps. The whole prefix is re-read every time, which is
        why a model cannot take back something it has already said.
      </.step>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :temperature}} = assigns) do
    ~H"""
    <section class="slide">
      <h2 class="slide__title">Divide the scores before the softmax</h2>
      <div class="three-up">
        <div :for={temperature <- [0.5, 1.0, 3.0]} class="three-up__panel">
          <p class="row-caption">T = {temperature}</p>
          <.spark
            :if={Model.distribution(Model.probe(), temperature)}
            values={Model.distribution(Model.probe(), temperature)}
          />
        </div>
      </div>
      <p class="slide__lede">
        Below one sharpens toward the top choice. Above one flattens toward uniform.
        Zero is argmax.
      </p>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :demo_temperature}} = assigns) do
    assigns = assign(assigns, temperature: temperature(assigns.controls))

    ~H"""
    <section class="slide">
      <h2 class="slide__title slide__title--small">Turn the dial</h2>
      <form id="temperature-dial" phx-change="control" class="dial">
        <input type="hidden" name="name" value="temperature" />
        <input
          type="range"
          name="value"
          min="0"
          max="3"
          step="0.05"
          value={@temperature}
          class="dial__range"
        />
        <output class="dial__value">T = {:erlang.float_to_binary(@temperature, decimals: 2)}</output>
      </form>
      <ul :if={Model.trained?(:transformer)} class="examples examples--generated">
        <li :for={sentence <- Model.sentences(@temperature, 6)}>{Enum.join(sentence, " ")}</li>
      </ul>
      <.untrained :if={not Model.trained?(:transformer)} what="These generations" />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :the_tradeoff}} = assigns) do
    assigns = assign(assigns, curve: Model.temperature_curve())

    ~H"""
    <section class="slide slide--tight">
      <h2 class="slide__title slide__title--small">Correct and boring, or varied and wrong</h2>
      <.tradeoff_chart :if={@curve} curve={@curve} />
      <.untrained :if={is_nil(@curve)} what="This chart" />
    </section>
    """
  end

  # 7. Close ----------------------------------------------------------------

  def slide(%{slide: %Slide{id: :what_is_not_here}} = assigns) do
    ~H"""
    <section class="slide">
      <div class="two-up two-up--lists">
        <.step n={1} step={@step}>
          <p class="slide__eyebrow">not here</p>
          <ul class="claims claims--compact">
            <li>autodiff</li>
            <li>a tokenizer</li>
            <li>a GPU</li>
            <li>multi-head attention</li>
            <li>depth</li>
            <li>dependencies</li>
          </ul>
        </.step>
        <.step n={2} step={@step}>
          <p class="slide__eyebrow">here</p>
          <ul class="claims claims--compact claims--lit">
            <li>embeddings</li>
            <li>learned positions</li>
            <li>scaled dot-product attention</li>
            <li>a causal mask</li>
            <li>residuals and RMSNorm</li>
            <li>an MLP</li>
            <li>cross-entropy</li>
            <li>backprop, by hand, checked</li>
            <li>temperature sampling</li>
          </ul>
        </.step>
      </div>
      <.step n={2} step={@step} class="slide__note">
        Every one of these is the same thing a frontier model does.
      </.step>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :the_sentence_again}} = assigns) do
    assigns = assign(assigns, flees: probability_of("flees"))

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
          {"flees", :answer}
        ]}
        bracket={2..7}
        show_marks
        show_bracket
        class="probe--huge"
      />
      <p :if={@flees} class="slide__punchline">
        <span class="word word--answer">flees</span>, at {format_percent(@flees)}: the highest
        of all thirty-two words.
      </p>
      <p class="slide__note">github.com/jasondew/tiny_llm</p>
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

  # Shared pieces -----------------------------------------------------------

  attr :value, :string, required: true
  attr :label, :string, required: true
  attr :note, :string, default: nil
  attr :tone, :string, default: nil

  defp stat(assigns) do
    ~H"""
    <div class={["stat", @tone && "stat--#{@tone}"]}>
      <p class="stat__value">{@value}</p>
      <p class="stat__label">{@label}</p>
      <p :if={@note} class="stat__note">{@note}</p>
    </div>
    """
  end

  ## PRIVATE FUNCTIONS

  # The probe, marked up: the subject that decides the answer, and the noun that
  # sits next to the blank pointing the wrong way.
  defp probe_marks do
    ["<start>", "the", {"llama", :subject}, "who", "chases", "the", {"dogs", :distractor}]
  end

  defp vocabulary_groups do
    [
      %{name: "determiners", words: Vocab.determiners(), kind: nil},
      %{name: "nouns", words: Vocab.nouns(), kind: nil},
      %{name: "verbs", words: Vocab.transitive_verbs() ++ Vocab.intransitive_verbs(), kind: nil},
      %{name: "to be", words: Vocab.copula(), kind: nil},
      %{name: "adjectives", words: Vocab.adjectives(), kind: nil},
      %{name: "connectives", words: Vocab.connectives(), kind: nil},
      %{name: "boundaries", words: [Vocab.start_token(), Vocab.end_token()], kind: "lit"}
    ]
  end

  # Which cells the bigram heatmap rings, one window per step. The rows are
  # read out loud in this order, so the picture keeps up with the sentence.
  defp bigram_highlight(1), do: []
  defp bigram_highlight(2), do: cells_in_row("chases")
  defp bigram_highlight(3), do: cells_in_row(".")
  defp bigram_highlight(_step), do: cells_in_row("llama") ++ cells_in_row("llamas")

  defp cells_in_row(word) do
    row = Vocab.word_to_id(word)

    Enum.map(0..(Vocab.size() - 1)//1, fn column -> {row, column} end)
  end

  defp causal_mask(size) do
    Enum.map(0..(size - 1)//1, fn row ->
      Enum.map(0..(size - 1)//1, fn column -> if column > row, do: 0.0, else: 0.8 end)
    end)
  end

  defp blank_row, do: row_for(List.last(Model.probe()))

  defp row_for(word) do
    case Model.attention(Model.probe()) do
      nil -> nil
      weights -> Enum.at(weights, Enum.find_index(Model.probe(), &(&1 == word)))
    end
  end

  defp mirror_row_for(word) do
    case Model.attention(Model.mirror_probe()) do
      nil -> nil
      weights -> Enum.at(weights, Enum.find_index(Model.mirror_probe(), &(&1 == word)))
    end
  end

  defp probability_of(word) do
    case Model.distribution(Model.probe(), 1.0) do
      nil -> nil
      distribution -> Enum.at(distribution, Vocab.word_to_id(word))
    end
  end

  # The audience can only send words from the vocabulary, so any submission
  # encodes; the context length is the only thing that can bite.
  defp featured_attention(%Room{featured: nil}), do: nil

  defp featured_attention(%Room{featured: words}) do
    Model.attention(Enum.take(["<start>" | words], 16))
  end

  defp heatmap_cell(words) do
    case length(words) + 1 do
      size when size <= 8 -> 44
      size when size <= 11 -> 34
      _longer -> 26
    end
  end

  defp temperature(controls) do
    case Map.get(controls, "temperature") do
      nil -> 1.0
      value -> value |> to_string() |> Float.parse() |> elem(0)
    end
  end

  defp format_loss(value), do: :erlang.float_to_binary(value, decimals: 3)

  defp format_percent(nil), do: "--"
  defp format_percent(value), do: "#{:erlang.float_to_binary(value * 100, decimals: 1)}%"
end
