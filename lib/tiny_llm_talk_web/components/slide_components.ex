defmodule TinyLlmTalkWeb.SlideComponents do
  @moduledoc """
  Every slide's drawing, one function clause per slide id.

  Pattern matching is the whole dispatch mechanism: `TinyLlmTalk.Deck` names a
  slide, this module draws it, and a slide with no clause yet falls through to
  the stub at the bottom, which shows its title and its speaker notes.

  Figures are handed the model's own numbers from `TinyLlmTalk.Model` rather
  than a transcription of them, so a slide cannot quote a number the checkpoint
  does not produce. That is the whole reason the deck is a Phoenix app.

  Slides read two things besides the model: `@controls`, what the speaker has
  clicked or dragged, and `@room`, what the audience has answered. Both are
  allowed to be empty, and every slide renders correctly when they are.
  """

  use Phoenix.Component

  import TinyLlmTalkWeb.DeckComponents
  import TinyLlmTalkWeb.FigureComponents

  alias TinyLlm.{Tensor, Vocab}
  alias TinyLlmTalk.{Deck, FuzzyMap, GrammarRules, Model, Room, Slide, Trainer, Writer}
  alias TinyLlmTalkWeb.Controls

  # Every slide in the arc is drawn. The test suite renders each one and fails
  # if any falls through to the stub, so this list is a promise, not a record.
  @drawn Enum.map(Deck.slides(), & &1.id)

  # The public surface of the model's entire math library, in file order. The
  # two that matter are lit; the rest are dimmed to make the point that this
  # is all there is.

  # The four scores the softmax playground turns into a budget.
  # Words from the vocabulary but not from the sentence, so the room does not
  # read the playground as attention over the probe. They are only labels.
  @playground_scores [
    {"fox", 2.0},
    {"goose", 1.0},
    {"mouse", 0.5},
    {"sleepy", 0.0},
    {"big", -1.0}
  ]

  # The two lists on the dot product slide. Two entries each, so the same
  # numbers can be drawn as arrows on a graph.
  @dot_a [3.0, 1.0]
  @dot_b [1.0, 4.0]

  # The writer's last stage: 128 hidden units drawn four to a cell so the row
  # lines up with the 32-wide ones, and how many words the softmax row names.
  @hidden_per_cell 4
  @logit_chips 8

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
  attr :trainer, :any, default: nil, doc: "the training run, or nil to ask the trainer"
  attr :frame, :integer, default: 0, doc: "the frame an animated slide is on"

  # 0. Cold open ------------------------------------------------------------

  def slide(%{slide: %Slide{id: :the_vote}} = assigns) do
    assigns = assign(assigns, activity: Room.activity(:verb_vote))

    ~H"""
    <section class="slide slide--tight">
      <.probe words={~w(the llama who chases the dogs ____)} class="probe--wide" />
      <div class="ask">
        <.qr size={200} />
        <.tally tally={Room.tally(@room, :verb_vote)} answer={@activity.answer} reveal={@step >= 2} />
      </div>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :title}} = assigns) do
    ~H"""
    <section class="slide slide--centred">
      <h1 class="slide__statement slide__statement--wide">
        Transformers from Scratch,<br />in Elixir
      </h1>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :the_architecture}} = assigns) do
    ~H"""
    <section class="slide slide--tight">
      <h2 class="slide__title slide__title--small">The transformer</h2>
      <div class="slide__fill">
        <.block_diagram repeats="× N" />
      </div>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :parameters}} = assigns) do
    assigns =
      assign(assigns,
        parameters: format_count(Model.parameter_count()),
        tables: Model.parameter_tables()
      )

    ~H"""
    <section class="slide slide--tight">
      <h2 class="slide__title slide__title--small">The model I built</h2>
      <table :if={@tables} class="parameters">
        <thead>
          <tr>
            <th>stage</th>
            <th>parameter</th>
            <th>shape</th>
            <th class="parameters__number">floats</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={{table, index} <- Enum.with_index(@tables)}>
            <td class="parameters__stage">{stage_label(@tables, index)}</td>
            <td class="parameters__name">{table.name}</td>
            <td class="parameters__shape">{format_shape(table.shape)}</td>
            <td class="parameters__number">
              <span class="parameters__count">{format_count(table.count)}</span>
            </td>
          </tr>
        </tbody>
        <tfoot>
          <tr>
            <td colspan="3">every one of them learned</td>
            <td class="parameters__number">{@parameters}</td>
          </tr>
        </tfoot>
      </table>
      <.untrained :if={is_nil(@tables)} what="This table" />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :live_training}} = assigns) do
    trainer = assigns.trainer || Trainer.state()
    config = trainer.config || Trainer.checkpoint_config()

    assigns =
      assign(assigns,
        trainer: trainer,
        losses: Trainer.losses(trainer),
        steps: config.steps,
        elapsed: elapsed(trainer),
        final: final_loss(trainer)
      )

    ~H"""
    <section class="slide slide--tight">
      <div class="training">
        <h2 class="slide__title slide__title--small">Training, live</h2>
        <div class="training__controls">
          <button :if={@trainer.status == :idle} type="button" phx-click="train" class="button">
            start
          </button>
          <button
            :if={@trainer.status != :idle}
            type="button"
            phx-click="retrain"
            class="button button--quiet"
          >
            start over
          </button>
          <p :if={@trainer.status != :idle} class="training__status">
            {status_line(@trainer, @elapsed, @final)}
          </p>
        </div>
      </div>
      <.loss_chart
        losses={@losses}
        knowing_nothing={Model.knowing_nothing()}
        floor={Model.bigram_floor()}
        floor_label="the best any one-word model can do"
        series_label={"held-out loss, one block, seed #{config_seed(@trainer)}"}
        steps={@steps}
        width={1088}
        height={400}
      />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :it_writes}} = assigns) do
    ~H"""
    <.writer controls={@controls} frame={@frame} />
    """
  end

  # 1. Words become numbers -------------------------------------------------

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
    assigns = assign(assigns, rules: GrammarRules.rules(), sentences: Model.showcase_sentences())

    ~H"""
    <section class="slide">
      <h2 class="slide__title">A grammar we own</h2>
      <div class="bnf">
        <%= for {name, alternatives} <- @rules, {alternative, index} <- Enum.with_index(alternatives) do %>
          <span class="bnf__name">{if index == 0, do: name}</span>
          <span class="bnf__symbol">{if index == 0, do: "→", else: "|"}</span>
          <span class="bnf__alternative">{alternative}</span>
        <% end %>
      </div>
      <div>
        <p class="slide__eyebrow">sentences it wrote</p>
        <ul class="examples examples--grid">
          <li :for={sentence <- @sentences}>{Enum.join(sentence, " ")}</li>
        </ul>
      </div>
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
    </section>
    """
  end

  # 2. All the math there is ------------------------------------------------

  def slide(%{slide: %Slide{id: :dot_product}} = assigns) do
    a = Controls.vector(assigns.controls, "vector_a", @dot_a)
    b = Controls.vector(assigns.controls, "vector_b", @dot_b)
    products = Enum.zip_with(a, b, &(&1 * &2))
    assigns = assign(assigns, a: a, b: b, products: products, total: Enum.sum(products))

    ~H"""
    <section class="slide">
      <h2 class="slide__title">A dot product is a similarity score</h2>
      <div class="two-up two-up--lists dot">
        <div class="dot__arithmetic">
          <.step n={1} step={@step} class="dot__vectors">
            <.vector label="a" values={@a} class="vector--a" />
            <.vector label="b" values={@b} class="vector--b" />
          </.step>
          <.step n={2} step={@step}>
            <.vector label="multiply pairwise" values={@products} class="vector--work" />
          </.step>
          <.step n={3} step={@step}>
            <.vector label="add" values={[@total]} class="vector--total" />
          </.step>
          <.step n={3} step={@step} class="dot__controls">
            <button type="button" phx-click="reset_vectors" class="button button--quiet">reset</button>
            <span class="dot__hint">drag the arrow tips</span>
          </.step>
        </div>
        <.vector_graph id="dot-graph" a={@a} b={@b} agreement={@step >= 3} interactive size={400} />
      </div>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :softmax_playground}} = assigns) do
    sharpness = Controls.number(assigns.controls, "sharpness", 1.0)
    scores = Enum.map(@playground_scores, &elem(&1, 1))
    [budget] = Tensor.softmax([Enum.map(scores, &(&1 * sharpness))])

    assigns =
      assign(assigns,
        sharpness: sharpness,
        words: Enum.map(@playground_scores, &elem(&1, 0)),
        scores: @playground_scores,
        budget: budget
      )

    ~H"""
    <section class="slide">
      <h2 class="slide__title slide__title--small">A softmax turns scores into a budget</h2>
      <div class="two-up">
        <div>
          <p class="row-caption">scores in</p>
          <div class="arithmetic">
            <p :for={{word, score} <- @scores} class="arithmetic__row">
              <span>{word}</span> {format_signed(score)}
            </p>
          </div>
        </div>
        <div>
          <p class="row-caption">budget out &middot; sums to {format_weight(Enum.sum(@budget))}</p>
          <.bars values={@budget} words={@words} top={5} highlight={@words} />
        </div>
      </div>
      <form id="sharpness-dial" phx-change="control" class="dial">
        <input type="hidden" name="name" value="sharpness" />
        <input
          type="range"
          name="value"
          min="0.1"
          max="4"
          step="0.1"
          value={@sharpness}
          class="dial__range"
        />
        <output class="dial__value">sharpness {:erlang.float_to_binary(@sharpness, decimals: 1)}</output>
      </form>
    </section>
    """
  end

  # 3. Embedding and position -----------------------------------------------

  def slide(%{slide: %Slide{id: :a_word_is_a_row}} = assigns) do
    assigns = assign(assigns, row: Model.embedding("dogs"))

    ~H"""
    <section class="slide slide--tight">
      <.sentence_line />
      <.step n={2} step={@step}>
        <h2 class="slide__title slide__title--small">A word becomes a row of floats</h2>
      </.step>
      <.step n={2} step={@step}>
        <div class="lookup">
          <span class="lookup__word">dogs</span>
          <span class="lookup__arrow">&rarr;</span>
          <span class="lookup__id">{Vocab.word_to_id("dogs")}</span>
          <span class="lookup__arrow">&rarr;</span>
          <span class="lookup__row">
            <.spark :if={@row} values={Enum.map(@row, &abs/1)} />
            <.untrained :if={is_nil(@row)} what="This row of floats" />
          </span>
        </div>
      </.step>
      <.step :if={@row} n={2} step={@step}>
        <div class="floats floats--all">
          <span :for={value <- @row} class="floats__value">{format_signed(value)}</span>
        </div>
      </.step>
      <.step n={3} step={@step}>
        <.code
          path="lib/tiny_llm/transformer.ex"
          range={114..116}
          step={@step}
          focus={[1..1, 1..1, 1..1]}
        />
      </.step>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :positions_added}} = assigns) do
    assigns = assign(assigns, row: Model.position(6))

    ~H"""
    <section class="slide slide--tight">
      <.sentence_line />
      <h2 class="slide__title slide__title--small">Position is another row, added on</h2>
      <div class="lookup">
        <span class="lookup__word">position 6 of 16</span>
        <span class="lookup__arrow">&rarr;</span>
        <span class="lookup__row">
          <.spark :if={@row} values={Enum.map(@row, &abs/1)} />
          <.untrained :if={is_nil(@row)} what="This row of floats" />
        </span>
      </div>
      <div :if={@row} class="floats floats--all">
        <span :for={value <- @row} class="floats__value">{format_signed(value)}</span>
      </div>
      <div>
        <.code path="lib/tiny_llm/transformer.ex" range={114..116} step={@step} focus={[2..2, 3..3]} />
      </div>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :forgets_the_words}} = assigns) do
    assigns = assign(assigns, rows: input_rows())

    ~H"""
    <section class="slide slide--tight">
      <.sentence_line />
      <h2 class="slide__title slide__title--small">
        At this point, the model has forgotten it ever saw words
      </h2>
      <figure :if={@rows} class="figure-centred">
        <.heatmap
          values={@rows}
          row_labels={Model.probe()}
          column_labels={Enum.map(0..31, &to_string/1)}
          cell={26}
        />
        <figcaption class="figure-centred__caption">
          the input to attention: 7 positions &times; 32 floats, embedding + position
        </figcaption>
      </figure>
      <.untrained :if={is_nil(@rows)} what="This grid" />
    </section>
    """
  end

  # 4. Attention, from Map --------------------------------------------------

  def slide(%{slide: %Slide{id: :fuzzy_map}} = assigns) do
    query = Controls.choice(assigns.controls, "query", "geese")
    lookup = FuzzyMap.lookup(query)

    assigns =
      assign(assigns,
        query: lookup.query,
        lookup: lookup,
        exact: FuzzyMap.exact(lookup.query),
        options: FuzzyMap.query_words()
      )

    ~H"""
    <section class="slide slide--tight">
      <h2 class="slide__title slide__title--small">Now make it fuzzy</h2>
      <div class="fuzzy-head">
        <.picker name="query" options={@options} chosen={@query} />
        <p class="row-caption">
          <code>Map.get</code>
          says {if @exact, do: format_weight(@exact), else: "nil"} &middot; query vector {format_vector(
            @lookup.vector
          )}
        </p>
      </div>
      <table class="fuzzy">
        <thead>
          <tr>
            <th>key</th>
            <th>key vector</th>
            <th>1. score (dot)</th>
            <th class={@step < 2 && "fuzzy--hidden"}>2. budget (softmax)</th>
            <th class={@step < 3 && "fuzzy--hidden"}>3. value &times; budget</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={row <- @lookup.scores}>
            <td class="fuzzy__key">{row.key}</td>
            <td class="fuzzy__vector">{format_vector(entry_vector(row.key))}</td>
            <td class="fuzzy__number">{format_signed(row.score)}</td>
            <td class={["fuzzy__budget", @step < 2 && "fuzzy--hidden"]}>
              <span class="fuzzy__track">
                <span class="fuzzy__fill" style={"width: #{round(row.weight * 100)}%"} />
              </span>
              {format_weight(row.weight)}
            </td>
            <td class={["fuzzy__number", @step < 3 && "fuzzy--hidden"]}>
              {format_weight(row.value)} &times; {format_weight(row.weight)}
            </td>
          </tr>
        </tbody>
      </table>
      <.step n={3} step={@step} class="fuzzy-answer">
        how plural is <span class="word word--lit">{@query}</span>?
        <span class="fuzzy-answer__value">{format_weight(@lookup.blend)}</span>
      </.step>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :learn_the_lookup}} = assigns) do
    ~H"""
    <section class="slide">
      <h2 class="slide__title slide__title--small">
        Then let it learn what to ask, what to offer, and what to hand over
      </h2>
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
      <.step n={4} step={@step}>
        <.code path="lib/tiny_llm/attention.ex" range={198..200} step={@step} caption={false} />
      </.step>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :attention_code}} = assigns) do
    ~H"""
    <section class="slide slide--tight">
      <p class="slide__eyebrow">one head of attention</p>
      <p class="formula">
        Attention(Q, K, V) = softmax(<span class="formula__group">Q K<sup>T</sup> / √d</span>) V
      </p>
      <.code
        path="lib/tiny_llm/attention.ex"
        range={198..213}
        step={@step}
        focus={[:all, 1..3, 5..8, 9..13, 14..14, 16..16, :all]}
      />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :three_details}} = assigns) do
    mask = Controls.choice(assigns.controls, "mask", "on")

    assigns =
      assign(assigns,
        mask: mask,
        weights:
          if(mask == "on",
            do: Model.attention(Model.probe()),
            else: Model.unmasked_attention(Model.probe())
          )
      )

    ~H"""
    <section class="slide slide--tight">
      <.sentence_line />
      <h2 class="slide__title slide__title--small">Three details do all the work</h2>
      <div class="two-up two-up--lists">
        <ol class="beats beats--numbered">
          <.step n={1} step={@step}>
            <li>Divide by the square root of the width, so the softmax does not saturate.</li>
          </.step>
          <.step n={2} step={@step}>
            <li>Mask the future before the softmax, so the rows still sum to one.</li>
          </.step>
          <.step n={3} step={@step}>
            <li>Every position at once, in one matrix multiply. No loop over time.</li>
          </.step>
        </ol>
        <div>
          <.step n={2} step={@step}>
            <.picker name="mask" options={~w(on off)} chosen={@mask} class="picker--small" />
          </.step>
          <.heatmap
            :if={@weights}
            values={@weights}
            row_labels={Model.probe()}
            column_labels={Model.probe()}
            cell={34}
          />
          <.untrained :if={is_nil(@weights)} what="This heatmap" />
        </div>
      </div>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :attention_bet}} = assigns) do
    assigns = assign(assigns, activity: Room.activity(:attention_bet))

    ~H"""
    <section class="slide slide--tight">
      <.sentence_line />
      <h2 class="slide__title slide__title--small">
        Which word will the blank look at hardest?
      </h2>
      <div class="ask">
        <.qr size={200} />
        <.tally
          tally={Room.tally(@room, :attention_bet)}
          answer={@activity.answer}
          reveal={@step >= 2}
        />
      </div>
      <p :if={@step >= 2 and @activity.answer} class="slide__note">
        It is <span class="word word--lit">{@activity.answer}</span>. Nobody guesses that,
        including me, the first time.
      </p>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :walkthrough}} = assigns) do
    trace = Model.trace(Model.probe())
    last = length(Model.probe()) - 1
    # Starts on `who`, which has a future to mask. The last position is where
    # the slide should end, by a click.
    position = assigns.controls |> Controls.number("position", 3.0) |> round() |> min(last)

    assigns = assign(assigns, trace: trace, position: position, words: Model.probe())

    ~H"""
    <section class="slide slide--tight">
      <.sentence_line />
      <h2 class="slide__title slide__title--small">One position, all the way through</h2>
      <div :if={@trace} class="walk" style={"--walk-columns: #{length(@words)}"}>
        <span class="walk__label">position</span>
        <button
          :for={{word, index} <- Enum.with_index(@words)}
          type="button"
          phx-click="control"
          phx-value-name="position"
          phx-value-choice={index}
          class={["walk__word", index == @position && "walk__word--chosen"]}
        >{word}</button>

        <span class="walk__label">query</span>
        <span
          :for={index <- 0..(length(@words) - 1)}
          class={["walk__cell", index == @position && "walk__cell--query"]}
        >{if index == @position, do: "q", else: ""}</span>

        <span class="walk__label">keys</span>
        <span :for={_index <- 0..(length(@words) - 1)} class="walk__cell walk__cell--key">k</span>

        <.step n={2} step={@step} class="walk__row">
          <span class="walk__label">q &middot; k / &radic;d</span>
          <span
            :for={score <- Enum.at(@trace.scores, @position)}
            class="walk__cell walk__cell--number"
          >
            {format_signed(score)}
          </span>
        </.step>

        <.step n={3} step={@step} class="walk__row">
          <span class="walk__label">mask the future</span>
          <span
            :for={score <- Enum.at(@trace.masked, @position)}
            class={["walk__cell walk__cell--number", is_nil(score) && "walk__cell--masked"]}
          >{if score, do: format_signed(score), else: "-1e9"}</span>
        </.step>

        <.step n={4} step={@step} class="walk__row">
          <span class="walk__label">softmax</span>
          <span
            :for={weight <- Enum.at(@trace.weights, @position)}
            class="walk__cell walk__cell--weight"
          >
            <span class="walk__fill" style={"height: #{round(weight * 100)}%"} />
            <span class="walk__percent">{format_percent(weight)}</span>
          </span>
        </.step>
      </div>
      <.untrained :if={is_nil(@trace)} what="This walkthrough" />
    </section>
    """
  end

  # 5. Look at what it did --------------------------------------------------

  def slide(%{slide: %Slide{id: :heatmap}} = assigns) do
    assigns = assign(assigns, weights: Model.attention(Model.probe()))

    ~H"""
    <section class="slide">
      <.sentence_line />
      <h2 class="slide__title slide__title--small">Every position at once</h2>
      <.heatmap
        :if={@weights}
        values={@weights}
        row_labels={Model.probe()}
        column_labels={Model.probe()}
        show_values
        cell={44}
      />
      <.untrained :if={is_nil(@weights)} what="This heatmap" />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :read_it_honestly}} = assigns) do
    assigns = assign(assigns, weights: blank_row())

    ~H"""
    <section class="slide">
      <.sentence_line />
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
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :attention_sink}} = assigns) do
    assigns = assign(assigns, weights: row_for("chases"))

    ~H"""
    <section class="slide">
      <.sentence_line />
      <h2 class="slide__title">It found the attention sink by itself</h2>
      <.bars
        :if={@weights}
        values={@weights}
        words={Model.probe()}
        top={3}
        highlight={["<start>"]}
      />
      <.untrained :if={is_nil(@weights)} what="This row" />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :half_a_route}} = assigns) do
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

  # 6. The rest of the block ------------------------------------------------

  def slide(%{slide: %Slide{id: :lid_off}} = assigns) do
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
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :plumbing}} = assigns) do
    ~H"""
    <section class="slide">
      <h2 class="slide__title">Three pieces of plumbing</h2>
      <dl class="definitions definitions--wide">
        <.step n={1} step={@step}>
          <dt>residual</dt>
          <dd>
            Add what attention returned to what was there. Do not replace it.
            <code>x + attention(x)</code>
          </dd>
        </.step>
        <.step n={2} step={@step}>
          <dt>RMSNorm</dt>
          <dd>
            Rescale each row to a fixed size, so nothing blows up. <code>x / rms(x) * gain</code>
          </dd>
        </.step>
        <.step n={3} step={@step}>
          <dt>MLP</dt>
          <dd>
            Two weighted sums with a ReLU between, per position. Where it thinks about
            what it gathered. <code>32 &rarr; 128 &rarr; 32</code>
          </dd>
        </.step>
      </dl>
    </section>
    """
  end

  # 7. Back to words --------------------------------------------------------

  def slide(%{slide: %Slide{id: :back_to_words}} = assigns) do
    assigns = assign(assigns, distribution: Model.distribution(Model.probe(), 1.0))

    ~H"""
    <section class="slide">
      <.sentence_line />
      <h2 class="slide__title slide__title--small">
        Thirty-two floats become thirty-two probabilities
      </h2>
      <.code path="lib/tiny_llm/transformer.ex" range={118..120} step={@step} focus={[3..3]} />
      <.bars
        :if={@distribution}
        values={@distribution}
        words={Vocab.words()}
        top={5}
        highlight={~w(flees)}
      />
      <.untrained :if={is_nil(@distribution)} what="This distribution" />
    </section>
    """
  end

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
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :one_word_at_a_time}} = assigns) do
    words = Controls.generated(assigns.controls)

    assigns =
      assign(assigns,
        words: words,
        finished: Controls.finished?(words),
        distribution:
          Model.distribution(["<start>" | words], Controls.temperature(assigns.controls))
      )

    ~H"""
    <section class="slide">
      <h2 class="slide__title slide__title--small">One word at a time</h2>
      <p class="written">
        <span class="written__word written__word--start">&lt;start&gt;</span>
        <span :for={word <- @words} class="written__word">{word}</span>
        <span :if={not @finished} class="written__cursor">____</span>
      </p>
      <div class="written__actions">
        <button type="button" phx-click="next_word" class="button" disabled={@finished}>
          next word
        </button>
        <button type="button" phx-click="restart" class="button button--quiet">start over</button>
      </div>
      <div :if={@distribution && not @finished}>
        <p class="row-caption">what it thinks comes next</p>
        <.bars
          values={@distribution}
          words={Vocab.words()}
          top={5}
          highlight={[Vocab.id_to_word(Tensor.argmax(@distribution))]}
        />
      </div>
      <p :if={@finished} class="slide__lede">Full stop. It is done, and so are we.</p>
      <.untrained :if={is_nil(@distribution)} what="This generator" />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :temperature_dial}} = assigns) do
    assigns = assign(assigns, temperature: Controls.temperature(assigns.controls))

    ~H"""
    <section class="slide">
      <.sentence_line />
      <h2 class="slide__title slide__title--small">Divide the scores before the softmax</h2>
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
      <div :if={Model.trained?(:transformer)} class="two-up">
        <div>
          <p class="row-caption">what comes next</p>
          <.bars
            values={Model.distribution(Model.probe(), @temperature)}
            words={Vocab.words()}
            top={5}
            highlight={~w(flees)}
          />
        </div>
        <ul class="examples examples--generated">
          <li :for={sentence <- Model.sentences(@temperature, 6)}>{Enum.join(sentence, " ")}</li>
        </ul>
      </div>
      <.untrained :if={not Model.trained?(:transformer)} what="These generations" />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :spot_the_human}} = assigns) do
    assigns = assign(assigns, activity: Room.activity(:spot_the_human))

    ~H"""
    <section class="slide slide--tight">
      <h2 class="slide__title slide__title--small">One of these was written by the grammar</h2>
      <div class="ask ask--stacked">
        <.qr size={110} />
        <.tally
          tally={Room.tally(@room, :spot_the_human)}
          answer={@activity.answer}
          reveal={@step >= 2}
          wide
        />
      </div>
    </section>
    """
  end

  # 8. Training, in one slide -----------------------------------------------

  def slide(%{slide: %Slide{id: :training}} = assigns) do
    ~H"""
    <section class="slide">
      <h2 class="slide__title">Training, all of it</h2>
      <ol class="beats beats--numbered">
        <.step n={1} step={@step}>
          <li>Guess the next word.</li>
        </.step>
        <.step n={2} step={@step}>
          <li>Measure how surprised you were by the real one.</li>
        </.step>
        <.step n={3} step={@step}>
          <li>Nudge every number in the direction that makes the surprise smaller.</li>
        </.step>
        <.step n={4} step={@step}>
          <li>Repeat a few hundred times.</li>
        </.step>
      </ol>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :loss_falls}} = assigns) do
    assigns = assign(assigns, losses: Model.losses(:transformer))

    ~H"""
    <section class="slide">
      <h2 class="slide__title">Watch it fall</h2>
      <.loss_chart
        :if={@losses}
        losses={@losses}
        knowing_nothing={Model.knowing_nothing()}
        floor={Model.bigram_floor()}
        floor_label="the best any one-word model can do"
        series_label="held-out loss, one block"
        line={@step >= 2}
        draw
        width={1088}
        height={400}
      />
      <.untrained :if={is_nil(@losses)} what="This loss curve" />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :tests_for_math}} = assigns) do
    ~H"""
    <section class="slide">
      <h2 class="slide__title">Tests for math</h2>
      <.code
        path="lib/tiny_llm/grad_check.ex"
        range={81..87}
        step={@step}
        focus={[:all, 2..4, 5..7]}
      />
    </section>
    """
  end

  # 9. Did it learn it ------------------------------------------------------

  def slide(%{slide: %Slide{id: :the_number}} = assigns) do
    assigns =
      assign(assigns,
        bigram: Model.agreement(:bigram),
        transformer: Model.agreement(:transformer),
        probes: length(Model.distractor_probes())
      )

    ~H"""
    <section class="slide slide--centred">
      <h2 class="slide__title">On the sentences where the nearest noun lies</h2>
      <div class="stat-row">
        <.stat value={format_percent(@bigram)} label="count table" tone="bad" />
        <.stat value={format_percent(@transformer)} label="one attention block" tone="good" />
      </div>
      <p class="slide__lede">
        The count table is at chance. The only word it sees is the one pointing the wrong way.
      </p>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :rematch}} = assigns) do
    activity = Room.activity(:rematch)

    assigns =
      assign(assigns,
        activity: activity,
        model_pick: Model.pick(Model.rematch_probe(), activity.options),
        model_confidence: probability_after(Model.rematch_probe(), activity.answer)
      )

    ~H"""
    <section class="slide slide--tight">
      <.probe
        words={[
          "the",
          {"geese", :subject},
          "who",
          "see",
          "a",
          {"fox", :distractor},
          {"____", :blank}
        ]}
        show_marks={@step >= 2}
        class="probe--wide"
      />
      <div class="ask">
        <.qr size={200} />
        <.tally tally={Room.tally(@room, :rematch)} answer={@activity.answer} reveal={@step >= 2} />
      </div>
      <.step n={2} step={@step} class="slide__lede">
        The model says
        <span class="word word--lit">{@model_pick || "..."}</span><span :if={@model_confidence}>, with {format_percent(@model_confidence)} on {@activity.answer}</span>.
        The room says <span class="word word--lit">{Room.majority(@room, :rematch) || "nothing yet"}</span>.
      </.step>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :scoreboard}} = assigns) do
    assigns =
      assign(assigns,
        results: Room.results(assigns.room),
        score: Room.score(assigns.room),
        model: model_record()
      )

    ~H"""
    <section class="slide">
      <h2 class="slide__title">How the room did</h2>
      <table :if={@results != []} class="scoreboard">
        <thead>
          <tr>
            <th>question</th>
            <th>the room said</th>
            <th>answer</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={{name, result} <- @results}>
            <td>{question_label(name)}</td>
            <td class="scoreboard__choice">{result.choice}</td>
            <td class="scoreboard__answer">{result.answer}</td>
            <td class={["scoreboard__mark", result.correct? && "scoreboard__mark--right"]}>
              {if result.correct?, do: "yes", else: "no"}
            </td>
          </tr>
        </tbody>
      </table>
      <p :if={@results == []} class="slide__lede">Nobody voted. The room is undefeated.</p>
      <div class="stat-row">
        <.stat
          value={"#{@score.right} of #{@score.asked}"}
          label="the room, on the questions it answered"
          tone="good"
        />
        <.stat
          :if={@model}
          value={"#{@model.right} of #{@model.asked}"}
          label="the model, on the two verb questions"
          tone="cool"
        />
      </div>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :all_of_it_again}} = assigns) do
    ~H"""
    <section class="slide">
      <h2 class="slide__title">This was all of it</h2>
      <.code
        path="lib/tiny_llm/transformer.ex"
        range={114..120}
        step={@step}
        focus={[:all, 1..3, 5..5, 6..6, 7..7]}
      />
      <div class="beats-row">
        <ol class="beats beats--numbered beats--small">
          <.step n={2} step={@step}>
            <li>A word becomes a row. Position is added.</li>
          </.step>
          <.step n={3} step={@step}>
            <li>The block: attention gathers, the residual keeps, the MLP thinks.</li>
          </.step>
          <.step n={4} step={@step}>
            <li>One more norm.</li>
          </.step>
          <.step n={5} step={@step}>
            <li>Thirty-two floats become thirty-two probabilities.</li>
          </.step>
        </ol>
      </div>
    </section>
    """
  end

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
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :the_sentence_again}} = assigns) do
    assigns = assign(assigns, flees: probability_after(Model.probe(), "flees"))

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

  def slide(%{slide: %Slide{id: :sources}} = assigns) do
    assigns = assign(assigns, repo: Application.fetch_env!(:tiny_llm_talk, :repo_label))

    ~H"""
    <section class="slide">
      <h2 class="slide__title">Sources</h2>
      <div class="two-up two-up--lists">
        <div>
          <p class="slide__eyebrow">code</p>
          <ul class="claims claims--compact">
            <li>the model: <code>{@repo}</code></li>
            <li>this deck: <code>github.com/jasondew/tiny_llm_talk</code></li>
          </ul>
        </div>
        <div>
          <p class="slide__eyebrow">papers</p>
          <ul class="claims claims--compact">
            <li>
              Vaswani et al., 2017. Attention Is All You Need. <code>arxiv.org/abs/1706.03762</code>
            </li>
            <li>OpenAI, 2023. GPT-4 Technical Report. <code>arxiv.org/abs/2303.08774</code></li>
            <li>
              Google, 2023. Gemini: A Family of Highly Capable Multimodal Models.
              <code>arxiv.org/abs/2312.11805</code>
            </li>
            <li>
              DeepSeek, 2024. DeepSeek-V3 Technical Report. <code>arxiv.org/abs/2412.19437</code>
            </li>
            <li>
              Meta, 2025. The Llama 4 herd.
              <code>ai.meta.com/blog/llama-4-multimodal-intelligence</code>
            </li>
          </ul>
        </div>
      </div>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :it_writes_again}} = assigns) do
    ~H"""
    <.writer controls={@controls} frame={@frame} eyebrow="github.com/jasondew/tiny_llm" />
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

  # The model writing a paragraph, with the forward pass for the word being
  # written drawn beside it. Opens the talk and closes it.
  attr :controls, :map, required: true
  attr :frame, :integer, required: true
  attr :eyebrow, :string, default: nil

  defp writer(assigns) do
    seed = Writer.seed(Controls.shuffles(assigns.controls))
    frame = Writer.frame(seed, assigns.frame)

    assigns =
      assign(assigns,
        frame: frame,
        pace: Controls.choice(assigns.controls, "pace", "normal"),
        parameters: format_count(Model.parameter_count()),
        last_chip: frame && length(frame.sequence) - 1
      )

    # A stage shows the word being written only once the wave has reached it.
    # Before that it holds what it showed for the previous word, or nothing at
    # the start of a sentence, so the room sees the new row flow through.
    assigns =
      assign(assigns,
        rows: frame && stage_data(frame, :rows),
        qk: frame && stage_data(frame, :query_keys),
        attention: frame && stage_data(frame, :attention),
        values: frame && stage_data(frame, :values),
        next: frame && stage_data(frame, :next)
      )

    ~H"""
    <section class="slide slide--tight writer">
      <p :if={@eyebrow} class="slide__eyebrow writer__eyebrow">{@eyebrow}</p>
      <.untrained :if={is_nil(@frame)} what="The writer" />
      <div :if={@frame} class="writer__pipe">
        <div class={["writer__stage", stage_class(@frame.phase, :word)]}>
          <p class="writer__label">
            1. words become integers{if @frame.finished, do: " · the paragraph is finished", else: ""}
          </p>
          <div class="writer__chips">
            <span
              :for={{word, index} <- Enum.with_index(@frame.sequence)}
              class={["writer__chip", index == @last_chip && "writer__chip--lit"]}
            >
              <span class="writer__chip-word">{word}</span>
              <span class="writer__chip-id">{Vocab.word_to_id(word)}</span>
            </span>
          </div>
        </div>
        <div class="writer__pair">
          <div class={["writer__stage", stage_class(@frame.phase, :rows)]}>
            <p class="writer__label">2. rows: embedding + position, 32 floats each</p>
            <.heatmap
              :if={@rows}
              values={normalized(@rows.trace.input)}
              row_labels={@rows.prefix}
              column_labels={List.duplicate("", 32)}
              cell={rows_cell(@rows.size)}
              class="heatmap--compact"
            />
            <p :if={is_nil(@rows)} class="writer__pending">&hellip;</p>
          </div>
          <div class={["writer__stage", stage_class(@frame.phase, :query_keys)]}>
            <p class="writer__label">3. q from the last row, k from every row</p>
            <.heatmap
              :if={@qk}
              values={[List.last(@qk.scaled.queries) | @qk.scaled.keys]}
              row_labels={["q · " <> List.last(@qk.prefix) | Enum.map(@qk.prefix, &("k · " <> &1))]}
              column_labels={List.duplicate("", 32)}
              highlight={[{0, -1}]}
              cell={rows_cell(@qk.size)}
              class="heatmap--compact heatmap--query"
            />
            <p :if={is_nil(@qk)} class="writer__pending">&hellip;</p>
          </div>
        </div>
        <div class={["writer__stage", stage_class(@frame.phase, :attention)]}>
          <p class="writer__label">
            4. attention: q &middot; k per row, softmaxed. the share it pulls from each
          </p>
          <div :if={@attention} class="writer__attention" style={"--walk-columns: #{@attention.size}"}>
            <div
              :for={cell <- @attention.row}
              class={["writer__attention-cell", cell.top? && "writer__attention-cell--top"]}
            >
              <span class="writer__attention-line">
                <span class="writer__attention-word">{cell.word}</span>
                <span class="writer__attention-score">{format_signed(cell.score)}</span>
                <span class="writer__attention-weight">{format_percent(cell.weight)}</span>
              </span>
              <span class="writer__attention-track">
                <span class="writer__attention-fill" style={"width: #{round(cell.weight * 100)}%"} />
              </span>
            </div>
          </div>
          <p :if={is_nil(@attention)} class="writer__pending">&hellip;</p>
        </div>
        <div class={["writer__stage", stage_class(@frame.phase, :values)]}>
          <p class="writer__label">5. every row offers a value (v). blend by those shares</p>
          <.heatmap
            :if={@values}
            values={@values.scaled.values ++ [@values.scaled.blend]}
            row_labels={Enum.map(@values.prefix, &("v · " <> &1)) ++ ["= blend"]}
            column_labels={List.duplicate("", 32)}
            highlight={[{@values.size, -1}]}
            cell={rows_cell(@values.size)}
            class="heatmap--compact heatmap--query"
          />
          <p :if={is_nil(@values)} class="writer__pending">&hellip;</p>
        </div>
        <div class={["writer__stage", stage_class(@frame.phase, :next)]}>
          <p class="writer__label">6. the rest of the block, then softmax and one draw</p>
          <.heatmap
            :if={@next}
            values={plumbing_rows(@next)}
            row_labels={plumbing_labels()}
            column_labels={List.duplicate("", 32)}
            cell={8}
            class="heatmap--compact heatmap--query"
          />
          <div :if={@next} class="writer__logits">
            <span
              :for={chip <- logit_chips(@next.distribution, drawn(@frame))}
              class={["writer__logit", chip.drawn? && "writer__logit--drawn"]}
            >
              <span class="writer__logit-word">{chip.word}</span>
              <span class="writer__logit-share">{format_percent(chip.probability)}</span>
            </span>
          </div>
          <p :if={is_nil(@next)} class="writer__pending">&hellip;</p>
        </div>
      </div>
      <div class="writer__bar">
        <p class="writer__count">
          {@parameters} parameters &middot; temperature {Writer.temperature()} &middot; pure Elixir &middot; no library
        </p>
        <div class="writer__controls">
          <.picker name="pace" options={Controls.paces()} chosen={@pace} class="picker--small" />
          <button
            :if={@pace == "pause"}
            type="button"
            phx-click="step_frame"
            class="button"
            disabled={@frame && @frame.finished}
          >
            step
          </button>
          <button type="button" phx-click="shuffle" class="button button--quiet">
            reset
          </button>
        </div>
      </div>
    </section>
    """
  end

  ## PRIVATE FUNCTIONS

  # A stage of the writer is lit while its phase is on, done once it has passed
  # for this word, and waiting before then. The pick has no box of its own: it
  # is the last stage's bars with the drawn word lit.
  defp stage_class(phase, stage) do
    current = phase_index(phase)
    own = phase_index(stage)

    cond do
      stage == :next and phase == :pick -> "writer__stage--live"
      current == own -> "writer__stage--live"
      current > own -> "writer__stage--done"
      true -> "writer__stage--waiting"
    end
  end

  # The writer's pictures shrink as the prefix grows, so a ten-word sentence
  # still fits above the footer.
  defp rows_cell(size) when size <= 5, do: 9
  defp rows_cell(size) when size <= 8, do: 8
  defp rows_cell(_size), do: 6

  # What a stage of the writer draws: the word being written once the wave has
  # reached the stage, the previous word until then, nothing at the start of a
  # sentence. Each stage only needs a little of the trace, so it gets that.
  defp stage_data(frame, stage) do
    reached? = phase_index(frame.phase) >= phase_index(stage)

    case if(reached?, do: frame.prefix, else: Enum.drop(frame.prefix, -1)) do
      [] -> nil
      prefix -> stage_data_for(prefix, Model.trace(prefix))
    end
  end

  defp stage_data_for(_prefix, nil), do: nil

  defp stage_data_for(prefix, trace) do
    %{
      prefix: prefix,
      size: length(prefix),
      trace: trace,
      scaled: query_and_keys(trace),
      row: attention_row(trace, prefix),
      distribution: Model.distribution(prefix, Writer.temperature())
    }
  end

  defp phase_index(phase), do: Enum.find_index(Writer.phases(), &(&1 == phase))

  # The last row's trip through the rest of the block, as rows of 32 so they
  # line up: the 128 hidden units are shown four to a cell, the largest of
  # each four, so a cell that stays light is a patch the ReLU switched off.
  # Each row is on its own 0 to 1 scale, a picture of its shape rather than a
  # comparison of sizes.
  defp plumbing_rows(%{trace: %{block: block}}) do
    hidden = block.hidden |> unit() |> Enum.chunk_every(@hidden_per_cell) |> Enum.map(&Enum.max/1)

    [unit(block.residual), hidden, unit(block.output), unit(block.logits)]
  end

  defp plumbing_labels do
    [
      "blend + row",
      "MLP hidden · ReLU (128, 4 per cell)",
      "MLP out + row",
      "norm · project = logits"
    ]
  end

  # The softmax as the top few words with their shares, and the drawn word
  # wherever it landed. Until the draw there is nothing to ring.
  defp logit_chips(distribution, drawn) do
    distribution
    |> Enum.zip(Vocab.words())
    |> Enum.sort_by(fn {probability, _word} -> -probability end)
    |> Enum.with_index()
    |> Enum.filter(fn {{_probability, word}, index} -> index < @logit_chips or word in drawn end)
    |> Enum.map(fn {{probability, word}, _index} ->
      %{word: word, probability: probability, drawn?: word in drawn}
    end)
  end

  # The word drawn, once it has been.
  defp drawn(%{phase: :pick, chosen: chosen}), do: [chosen]
  defp drawn(_frame), do: []

  # One row as magnitudes on its own 0 to 1 scale, for a picture of its shape.
  defp unit(row) do
    peak = row |> Enum.map(&abs/1) |> Enum.max()

    Enum.map(row, &(abs(&1) / max(peak, 1.0e-9)))
  end

  # The query, keys and values as magnitudes on one shared scale, so the room
  # can see they are the same kind of thing as the rows they came from. The
  # blend is the last row of the context: the values, weighted by attention.
  defp query_and_keys(trace) do
    everything = trace.queries ++ trace.keys ++ trace.values ++ trace.context
    peak = everything |> List.flatten() |> Enum.map(&abs/1) |> Enum.max()
    scale = fn rows -> Enum.map(rows, fn row -> Enum.map(row, &(abs(&1) / peak)) end) end

    %{
      queries: scale.(trace.queries),
      keys: scale.(trace.keys),
      values: scale.(trace.values),
      blend: [List.last(trace.context)] |> scale.() |> hd()
    }
  end

  # What the last position pulls in from each position: the raw score its
  # query gave that key, and the share the softmax turned it into.
  defp attention_row(trace, prefix) do
    scores = List.last(trace.scores)
    weights = List.last(trace.weights)
    top = Enum.max(weights)

    [prefix, scores, weights]
    |> Enum.zip()
    |> Enum.map(fn {word, score, weight} ->
      %{word: word, score: score, weight: weight, top?: weight == top}
    end)
  end

  defp normalized(rows) do
    peak = rows |> List.flatten() |> Enum.map(&abs/1) |> Enum.max()

    Enum.map(rows, fn row -> Enum.map(row, &(abs(&1) / peak)) end)
  end

  defp elapsed(%Trainer{status: :running, started_at: started}) do
    Float.round((System.monotonic_time(:millisecond) - started) / 1_000, 0)
  end

  defp elapsed(_trainer), do: nil

  defp final_loss(%Trainer{losses: [{_step, loss} | _rest]}), do: loss
  defp final_loss(_trainer), do: nil

  defp status_line(%Trainer{status: :running} = trainer, elapsed, final) do
    "step #{trainer.step} of #{trainer.config.steps} · #{round(elapsed)}s" <>
      if(final, do: " · loss #{format_loss(final)}", else: "")
  end

  defp status_line(%Trainer{status: :done} = trainer, _elapsed, final) do
    "loss #{format_loss(final)} in #{trainer.seconds}s · " <>
      case trainer.matches do
        true -> "matches the checkpoint"
        false -> "does not match the checkpoint"
        nil -> "nothing to compare it to"
      end
  end

  defp config_seed(%Trainer{config: %{seed: seed}}), do: seed
  defp config_seed(_trainer), do: Trainer.checkpoint_config().seed

  defp format_loss(nil), do: "--"
  defp format_loss(value), do: :erlang.float_to_binary(value, decimals: 4)

  # The sentence the talk turns on, small, at the top of every slide that is
  # about it, so the room never has to remember which sentence a picture is of.
  defp sentence_line(assigns) do
    assigns = assign(assigns, words: probe_marks() ++ [{"____", :blank}])

    ~H"""
    <.probe words={@words} show_marks class="probe--line" />
    """
  end

  # The six stages of the block, in the order the model runs them. The middle
  # four are the block itself; the ends are the tables on the way in and out.
  @block_layers [
    {"embedding + position", nil},
    {"normalization", "norm"},
    {"attention", "attention"},
    {"normalization", "norm"},
    {"neural network", "mlp"},
    {"32 probabilities", nil}
  ]

  # One transformer, as a stack: the block is boxed and marked with how many
  # times it repeats.
  attr :repeats, :string, default: nil

  defp block_diagram(assigns) do
    layers = @block_layers

    assigns =
      assign(assigns, first: hd(layers), block: Enum.slice(layers, 1, 4), last: List.last(layers))

    ~H"""
    <div class="stack stack--diagram">
      <.block_layer layer={@first} />
      <span class="stack__arrow">&darr;</span>
      <div class="stack__block">
        <span :if={@repeats} class="stack__repeats">{@repeats}</span>
        <%= for {layer, index} <- Enum.with_index(@block) do %>
          <span :if={index > 0} class="stack__arrow">&darr;</span>
          <.block_layer layer={layer} />
        <% end %>
      </div>
      <span class="stack__arrow">&darr;</span>
      <.block_layer layer={@last} />
    </div>
    """
  end

  attr :layer, :any, required: true

  defp block_layer(%{layer: {label, kind}} = assigns) do
    assigns = assign(assigns, label: label, kind: kind)

    ~H"""
    <div class={["stack__layer", @kind && "stack__layer--#{@kind}"]}>{@label}</div>
    """
  end

  # The stage is named once, on the first table it holds.
  defp stage_label(tables, 0), do: hd(tables).stage

  defp stage_label(tables, index) do
    current = Enum.at(tables, index).stage
    if Enum.at(tables, index - 1).stage == current, do: nil, else: current
  end

  defp format_shape({rows, columns}), do: "#{rows} × #{columns}"

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

  # The rows attention sees for the probe, as magnitudes on a 0 to 1 scale so
  # the heatmap can colour them. The sign is lost, which is fine for a picture
  # whose only job is "these are numbers now, not words".
  defp input_rows do
    case Model.trace(Model.probe()) do
      nil ->
        nil

      trace ->
        peak = trace.input |> List.flatten() |> Enum.map(&abs/1) |> Enum.max()

        Enum.map(trace.input, fn row -> Enum.map(row, &(abs(&1) / peak)) end)
    end
  end

  defp entry_vector(key) do
    FuzzyMap.entries() |> Enum.find(&(&1.key == key)) |> Map.fetch!(:vector)
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

  defp probability_after(words, word) do
    case Model.distribution(words, 1.0) do
      nil -> nil
      distribution -> Enum.at(distribution, Vocab.word_to_id(word))
    end
  end

  # How the model does on the two questions that have a grammatical answer,
  # for the scoreboard's second line. Nil without a checkpoint.
  defp model_record do
    questions = [
      {Model.probe(), Room.activity(:verb_vote)},
      {Model.rematch_probe(), Room.activity(:rematch)}
    ]

    picks =
      Enum.map(questions, fn {probe, activity} ->
        {Model.pick(probe, activity.options), activity.answer}
      end)

    if Enum.any?(picks, fn {pick, _answer} -> is_nil(pick) end) do
      nil
    else
      %{right: Enum.count(picks, fn {pick, answer} -> pick == answer end), asked: length(picks)}
    end
  end

  defp question_label(:verb_vote), do: "flees, or flee?"
  defp question_label(:bigram_next), do: "what follows chases"
  defp question_label(:attention_bet), do: "where the blank looks"
  defp question_label(:spot_the_human), do: "spot the human"
  defp question_label(:rematch), do: "the geese who see a fox"

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

  defp format_vector(vector), do: "[" <> Enum.map_join(vector, ", ", &format_signed/1) <> "]"

  defp format_signed(value) when value >= 0,
    do: "+" <> :erlang.float_to_binary(value * 1.0, decimals: 2)

  defp format_signed(value), do: :erlang.float_to_binary(value * 1.0, decimals: 2)

  defp format_weight(value), do: :erlang.float_to_binary(value * 1.0, decimals: 2)

  defp format_count(nil), do: "About fifteen thousand"

  defp format_count(count) do
    count
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.join(",")
  end

  defp format_percent(nil), do: "--"
  defp format_percent(value), do: "#{:erlang.float_to_binary(value * 100, decimals: 1)}%"
end
