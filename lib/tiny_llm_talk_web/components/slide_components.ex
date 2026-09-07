defmodule TinyLlmTalkWeb.SlideComponents do
  @moduledoc """
  Every slide's drawing, one function clause per slide id.

  Pattern matching is the whole dispatch mechanism: `TinyLlmTalk.Deck` names a
  slide, this module draws it, and a slide with no clause yet falls through to
  the stub at the bottom, which shows its title and its speaker notes.

  Figures are handed the model's own numbers from `TinyLlmTalk.Model` rather
  than a transcription of them, so a slide cannot quote a number the checkpoint
  does not produce. That is the whole reason the deck is a Phoenix app.

  Slides read one thing besides the model: `@controls`, what the speaker has
  clicked or dragged. It is allowed to be empty, and every slide renders
  correctly when it is.
  """

  use Phoenix.Component

  import TinyLlmTalkWeb.DeckComponents
  import TinyLlmTalkWeb.FigureComponents

  alias TinyLlm.{Tensor, Vocab}
  alias TinyLlmTalk.{Deck, FuzzyMap, GrammarRules, Model, Slide, Trainer, Writer}
  alias TinyLlmTalkWeb.Controls

  # Every slide in the arc is drawn. The test suite renders each one and fails
  # if any falls through to the stub, so this list is a promise, not a record.
  @drawn Enum.map(Deck.slides(), & &1.id)

  # The public surface of the model's entire math library, in file order. The
  # two that matter are lit; the rest are dimmed to make the point that this
  # is all there is.

  # The five scores the softmax playground turns into a distribution.
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
  attr :trainer, :any, default: nil, doc: "the training run, or nil to ask the trainer"
  attr :frame, :integer, default: 0, doc: "the frame an animated slide is on"

  # 0. Cold open ------------------------------------------------------------

  def slide(%{slide: %Slide{id: :the_vote}} = assigns) do
    ~H"""
    <section class="slide slide--tight">
      <.probe words={~w(the llama who chases the dogs ____)} class="probe--wide" />
      <p class="choices">
        <span class={["choices__word", @step >= 2 && "choices__word--answer"]}>flees</span>
        <span class="choices__or">or</span>
        <span class={["choices__word", @step >= 2 && "choices__word--other"]}>flee</span>
      </p>
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
      <h2 class="slide__title slide__title--small">
        {if @step >= 2, do: "The transformer in this talk", else: "The transformer"}
      </h2>
      <div class="slide__fill">
        <.block_diagram
          repeats={if @step >= 2, do: "× 1", else: "× N"}
          outputs={if @step >= 2, do: "32 probabilities", else: "one probability per word"}
        />
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
      <h2 class="slide__title slide__title--small">Parameters</h2>
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
            <td class="parameters__name">
              {table.name}
              <span :if={formula_symbol(table.name)} class="parameters__symbol">
                (W<sub>{formula_symbol(table.name)}</sub>)
              </span>
            </td>
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
        corpus_size: Map.get(config, :training_corpus_size),
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
      <div class="two-up two-up--training">
        <ol class="beats beats--numbered beats--compact">
          <.step n={1} step={@step}>
            <li>
              Take a prefix from the corpus, where we know the next word.
              <span :if={@corpus_size} class="beats__aside">
                {format_count(@corpus_size)} sentences the grammar wrote
              </span>
            </li>
          </.step>
          <.step n={2} step={@step}>
            <li>Run the model: 32 probabilities.</li>
          </.step>
          <.step n={3} step={@step}>
            <li>Measure how surprised it was by the real word.</li>
          </.step>
          <.step n={4} step={@step}>
            <li>Nudge every number in the direction that makes the surprise smaller.</li>
          </.step>
          <.step n={5} step={@step}>
            <li>Repeat a few hundred times.</li>
          </.step>
        </ol>
        <.loss_chart
          losses={@losses}
          knowing_nothing={Model.knowing_nothing()}
          floor={Model.bigram_floor()}
          floor_label="the best any one-word model can do"
          series_label={"held-out loss, one block, seed #{config_seed(@trainer)}"}
          steps={@steps}
          width={640}
          height={380}
        />
      </div>
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
      <h2 class="slide__title">Vocabulary</h2>
      <p class="slide__lede">Only 32 words</p>
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
      <h2 class="slide__title">Grammar</h2>
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
      <p class="slide__eyebrow slide__eyebrow--break">Math break!</p>
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
    scores =
      Enum.map(@playground_scores, fn {word, default} ->
        {word, Controls.number(assigns.controls, "score_#{word}", default)}
      end)

    [distribution] = Tensor.softmax([Enum.map(scores, &elem(&1, 1))])

    assigns =
      assign(assigns,
        words: Enum.map(scores, &elem(&1, 0)),
        scores: scores,
        distribution: distribution
      )

    ~H"""
    <section class="slide">
      <p class="slide__eyebrow slide__eyebrow--break">Math break!</p>
      <h2 class="slide__title slide__title--small">A softmax turns scores into a distribution</h2>
      <p class="formula">
        softmax(x<sub>i</sub>)
        = <span class="formula__group">e<sup>x<sub>i</sub></sup></span>
        / Σ<sub>j</sub>
        e<sup>x<sub>j</sub></sup>
      </p>
      <div class="two-up">
        <div>
          <p class="row-caption">scores in &middot; drag one</p>
          <div class="score-rows">
            <form
              :for={{word, score} <- @scores}
              id={"score-#{word}"}
              phx-change="control"
              class="score-row"
            >
              <input type="hidden" name="name" value={"score_#{word}"} />
              <span class="score-row__word">{word}</span>
              <input
                type="range"
                name="value"
                min="-3"
                max="3"
                step="0.25"
                value={score}
                class="dial__range score-row__range"
              />
              <output class="score-row__value">{format_signed(score)}</output>
            </form>
          </div>
        </div>
        <div>
          <p class="row-caption">
            distribution out &middot; sums to {format_weight(Enum.sum(@distribution))}
          </p>
          <.bars values={@distribution} words={@words} top={5} highlight={@words} absolute />
        </div>
      </div>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :a_word_is_a_row}} = assigns) do
    assigns = assign(assigns, row: Model.embedding("dogs"), position: Model.position(6))

    ~H"""
    <section class="slide slide--tight">
      <.sentence_line />
      <.step n={2} step={@step}>
        <h2 class="slide__title slide__title--small">
          {if @step >= 3,
            do: "Each word becomes a row of floats, and its position is added on",
            else: "Each word becomes a row of floats"}
        </h2>
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
      <div :if={@row && @step == 2} class="floats floats--all">
        <span :for={value <- @row} class="floats__value">{format_signed(value)}</span>
      </div>
      <.step n={3} step={@step}>
        <div class="lookup">
          <span class="lookup__plus">+</span>
          <span class="lookup__word">position 6 of 16</span>
          <span class="lookup__arrow">&rarr;</span>
          <span class="lookup__row">
            <.spark :if={@position} values={Enum.map(@position, &abs/1)} />
            <.untrained :if={is_nil(@position)} what="This row of floats" />
          </span>
        </div>
      </.step>
      <.step n={4} step={@step}>
        <.code
          path="lib/tiny_llm/transformer.ex"
          range={114..116}
          step={@step}
          focus={[1..3, 1..3, 1..3, 1..3]}
        />
      </.step>
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
      <figure :if={@rows} class="figure-centred slide__fill">
        <.heatmap
          values={@rows}
          row_labels={Model.probe()}
          column_labels={Enum.map(0..31, fn _column -> "" end)}
          cell={26}
          class="heatmap--no-columns"
        />
        <figcaption class="figure-centred__caption">
          the input to attention: 7 positions &times; 32 floats, embedding + position
        </figcaption>
      </figure>
      <.untrained :if={is_nil(@rows)} what="This grid" />
    </section>
    """
  end

  # 4. Attention ------------------------------------------------------------

  def slide(%{slide: %Slide{id: :fuzzy_map}} = assigns) do
    query = Controls.choice(assigns.controls, "query", "geese")
    lookup = FuzzyMap.lookup(query)

    assigns =
      assign(assigns,
        query: lookup.query,
        lookup: lookup,
        options: FuzzyMap.query_words()
      )

    ~H"""
    <section class="slide slide--tight">
      <h2 class="slide__title slide__title--small">A small example, by hand: "Is it plural?"</h2>
      <div class="fuzzy-head">
        <div class="fuzzy-query">
          <span class="fuzzy-query__label">Q =</span>
          <.picker name="query" options={@options} chosen={@query} />
          <span class="fuzzy-query__vector">{format_vector(@lookup.vector)}</span>
        </div>
        <p class="fuzzy-formula">
          <.formula_term lit={@step >= 4}>
            <.formula_term lit={@step == 3}>
              softmax(<.formula_term lit={@step == 2}>Q K<sup>T</sup></.formula_term>
              / √d)
            </.formula_term>
            V
          </.formula_term>
        </p>
      </div>
      <table class="fuzzy">
        <thead>
          <tr>
            <th>key</th>
            <th>K</th>
            <th class={@step < 2 && "fuzzy--hidden"}>Q · K</th>
            <th class={@step < 3 && "fuzzy--hidden"}>softmax(Q · K / √d) (weight)</th>
            <th>V (0 := singular, 1 := plural)</th>
            <th class={@step < 4 && "fuzzy--hidden"}>weight &times; V</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={row <- @lookup.scores}>
            <td class="fuzzy__key">{row.key}</td>
            <td class="fuzzy__vector">{format_vector(entry_vector(row.key))}</td>
            <td class={["fuzzy__number", @step < 2 && "fuzzy--hidden"]}>
              {format_signed(row.score)}
            </td>
            <td class={["fuzzy__weight", @step < 3 && "fuzzy--hidden"]}>
              <span class="fuzzy__track">
                <span class="fuzzy__fill" style={"width: #{round(row.weight * 100)}%"} />
              </span>
              {format_weight(row.weight)}
            </td>
            <td class="fuzzy__number">{format_weight(row.value)}</td>
            <td class={["fuzzy__number", @step < 4 && "fuzzy--hidden"]}>
              {format_weight(row.weight * row.value)}
            </td>
          </tr>
        </tbody>
        <tfoot>
          <tr class={@step < 5 && "fuzzy--hidden"}>
            <td colspan="5" class="fuzzy__sum-label">Σ</td>
            <td class="fuzzy__number fuzzy__sum">{format_weight(@lookup.blend)}</td>
          </tr>
        </tfoot>
      </table>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :learn_the_lookup}} = assigns) do
    assigns = assign(assigns, positions: length(Model.probe()), width: Model.width())

    ~H"""
    <section class="slide slide--tight">
      <p class={["formula", "formula--heading", @step == 1 && "formula--hero"]}>
        Attention(W<sub>Q</sub>, W<sub>K</sub>, W<sub>V</sub>) = softmax(<span class="formula__group">Q K<sup>T</sup> / √d</span>) V
      </p>
      <dl class="definitions definitions--formula">
        <.step n={2} step={@step}>
          <dt>input</dt>
          <dd>
            <.shape rows={@positions} columns={@width} /> one row per position, from a few slides ago
          </dd>
        </.step>
        <.step n={3} step={@step}>
          <dt>W<sub>Q</sub>, W<sub>K</sub>, W<sub>V</sub></dt>
          <dd><.shape rows={@width} columns={@width} /> three learned matrices</dd>
        </.step>
        <.step n={4} step={@step}>
          <dt>Q = input × W<sub>Q</sub></dt>
          <dd><.shape rows={@positions} columns={@width} /> what this position is looking for</dd>
        </.step>
        <.step n={5} step={@step}>
          <dt>K = input × W<sub>K</sub></dt>
          <dd><.shape rows={@positions} columns={@width} /> what this position is advertising</dd>
        </.step>
        <.step n={6} step={@step}>
          <dt>V = input × W<sub>V</sub></dt>
          <dd>
            <.shape rows={@positions} columns={@width} />
            what this position hands over if it gets chosen
          </dd>
        </.step>
        <.step n={7} step={@step}>
          <dt>Q K<sup>T</sup></dt>
          <dd>
            <.shape rows={@positions} columns={@positions} />
            every query scored against every key, one dot product each
          </dd>
        </.step>
        <.step n={8} step={@step}>
          <dt>d</dt>
          <dd>
            <.shape rows={@width} /> the width of a key, which here is also the embedding size
          </dd>
        </.step>
        <.step n={9} step={@step}>
          <dt>softmax</dt>
          <dd>
            <.shape rows={@positions} columns={@positions} />
            each row of scores becomes a distribution
          </dd>
        </.step>
        <.step n={10} step={@step}>
          <dt>Attention</dt>
          <dd>
            <.shape rows={@positions} columns={@width} /> the blend, one new row per position
          </dd>
        </.step>
      </dl>
    </section>
    """
  end

  # What stands beside the code as its focus walks down: nothing until the
  # Q Kᵀ matmul, then the raw scores, the same scores with the future struck
  # out, the distribution the softmax makes of them, and the context rows
  # the blend produces. Each is the real number from the checkpoint.
  @projections_step 2
  @scores_step 3
  @mask_step 4
  @softmax_step 5
  @blend_step 6

  def slide(%{slide: %Slide{id: :attention_code}} = assigns) do
    trace = Model.trace(Model.probe())
    params = Model.params(:transformer)

    assigns =
      assign(assigns,
        trace: trace,
        stage: trace && attention_stage(trace, assigns.step),
        projections:
          params &&
            trace &&
            [
              {"Q", params.query_weight, trace.queries},
              {"K", params.key_weight, trace.keys},
              {"V", params.value_weight, trace.values}
            ],
        projections_step: @projections_step,
        scores_step: @scores_step,
        blend_step: @blend_step
      )

    ~H"""
    <section class="slide slide--tight">
      <p class="slide__eyebrow">one head of attention</p>
      <p class="formula">
        Attention(W<sub>Q</sub>, W<sub>K</sub>, W<sub>V</sub>) = softmax(<span class="formula__group">Q K<sup>T</sup> / √d</span>) V
      </p>
      <div class="two-up two-up--code">
        <.code
          path="lib/tiny_llm/attention.ex"
          range={198..213}
          step={@step}
          focus={[:all, 1..3, 5..8, 9..13, 14..14, 16..16, :all]}
        />
        <.step :if={@trace} n={@projections_step} step={@step} class="two-up__aside">
          <div :if={@step == @projections_step and @projections} class="aside-figure">
            <p class="aside-figure__caption">input, one row per position</p>
            <.strips rows={@trace.input} labels={Model.probe()} cell={8} />
            <p class="aside-figure__caption">
              × W<sub>Q</sub>, W<sub>K</sub>, W<sub>V</sub>, three learned matrices
            </p>
            <div class="matrix-row">
              <figure :for={{letter, weight, projection} <- @projections} class="matrix-thumb">
                <.thumb matrix={weight} />
                <figcaption>W<sub>{letter}</sub></figcaption>
                <span class="matrix-thumb__equals">=</span>
                <.thumb matrix={projection} />
                <figcaption>{letter}, {projection_name(letter)}</figcaption>
              </figure>
            </div>
          </div>
          <div :if={@step >= @scores_step} class="aside-figure">
            <p class="aside-figure__caption">{@stage.caption}</p>
            <.score_grid
              values={@stage.values}
              heat={@stage.heat}
              format={@stage.format}
              labels={Model.probe()}
              cell={36}
            />
          </div>
          <.step n={@blend_step} step={@step} class="aside-figure">
            <p class="aside-figure__caption">attention = weights × V</p>
            <.heatmap
              values={magnitudes(@trace.context)}
              row_labels={Model.probe()}
              column_labels={Enum.map(1..Model.width(), fn _column -> "" end)}
              cell={8}
              class="heatmap--compact"
            />
          </.step>
        </.step>
        <.untrained :if={is_nil(@trace)} what="This head" />
      </div>
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :attention_bet}} = assigns) do
    blank_row = blank_attention_row()

    assigns = assign(assigns, blank_row: blank_row, answer: blank_row && top_word(blank_row))

    ~H"""
    <section class="slide slide--tight">
      <.sentence_line />
      <h2 class="slide__title slide__title--small">
        Which word does the blank attend to the most?
      </h2>
      <.step :if={@blank_row} n={2} step={@step} class="bet-row">
        <p class="row-caption">
          the last row of the heatmap: <span class="word word--lit">dogs</span> predicts the blank
        </p>
        <.bars
          values={@blank_row}
          words={Model.probe()}
          top={4}
          highlight={List.wrap(@answer)}
          absolute
          class="bars--compact"
        />
      </.step>
      <.untrained :if={is_nil(@blank_row)} what="This bet" />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :walkthrough}} = assigns) do
    trace = Model.trace(Model.probe())
    last = length(Model.probe()) - 1
    # Starts on the last position, the one predicting the blank; `who` and
    # its masked future are a click away.
    position = assigns.controls |> Controls.number("position", last * 1.0) |> round() |> min(last)

    assigns = assign(assigns, trace: trace, position: position, words: Model.probe())

    ~H"""
    <section class="slide slide--tight">
      <.sentence_line />
      <h2 class="slide__title slide__title--small">LLMs are weird</h2>
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

        <div class="walk__row">
          <span class="walk__label">q &middot; k / &radic;d</span>
          <span
            :for={score <- Enum.at(@trace.scores, @position)}
            class="walk__cell walk__cell--number"
          >
            {format_signed(score)}
          </span>
        </div>

        <div class="walk__row">
          <span class="walk__label">mask the future</span>
          <span
            :for={score <- Enum.at(@trace.masked, @position)}
            class={["walk__cell walk__cell--number", is_nil(score) && "walk__cell--masked"]}
          >{if score, do: format_signed(score), else: "-1e9"}</span>
        </div>

        <div class="walk__row">
          <span class="walk__label">softmax</span>
          <span
            :for={weight <- Enum.at(@trace.weights, @position)}
            class="walk__cell walk__cell--weight"
          >
            <span class="walk__fill" style={"height: #{round(weight * 100)}%"} />
            <span class="walk__percent">{format_percent(weight)}</span>
          </span>
        </div>
      </div>
      <.untrained :if={is_nil(@trace)} what="This walkthrough" />
    </section>
    """
  end

  # 5. Look at what it did --------------------------------------------------

  def slide(%{slide: %Slide{id: :lid_off}} = assigns) do
    ~H"""
    <section class="slide slide--tight">
      <h2 class="slide__title slide__title--small">The transformer in this talk</h2>
      <div class="slide__fill">
        <.block_diagram repeats="× 1" label="the block" />
      </div>
    </section>
    """
  end

  @block_path "lib/tiny_llm/block.ex"

  # The walk down Block.forward: which lines each step lights, and which box
  # of the flow beside them. The first and last steps show the whole thing.
  @block_walk [:all, 2..2, 3..3, 4..4, 5..5, 6..8, 9..9, :all]
  @block_walk_stages [nil, :norm1, :attention, :add1, :norm2, :network, :add2, nil]

  def slide(%{slide: %Slide{id: :block_code}} = assigns) do
    assigns =
      assign(assigns,
        block_path: @block_path,
        walk: @block_walk,
        stage: Enum.at(@block_walk_stages, assigns.step - 1)
      )

    ~H"""
    <section class="slide slide--tight">
      <p class="slide__eyebrow">the block &middot; lib/tiny_llm/block.ex</p>
      <h2 class="slide__title slide__title--small">Block.forward</h2>
      <div class="two-up two-up--walk">
        <.code
          path={@block_path}
          function={:forward}
          elide={10..21}
          width={760}
          step={@step}
          focus={@walk}
        />
        <.block_flow stage={@stage} />
      </div>
    </section>
    """
  end

  # The block's forward pass, quoted once for the three slides that walk what
  # is left of it after attention, each lighting the lines it is about. The
  # numbers beside the code are the dogs position, the one predicting the
  # blank, straight from the checkpoint.

  def slide(%{slide: %Slide{id: :normalization}} = assigns) do
    assigns = assign(assigns, block: block_trace(), block_path: @block_path)

    ~H"""
    <section class="slide slide--tight">
      <p class="slide__eyebrow">normalization &middot; RMSNorm</p>
      <p class="formula">
        x̂ = <span class="formula__group">x / rms(x)</span> · g
      </p>
      <div>
        <.code path={@block_path} range={213..221} step={@step} focus={[[2..2, 5..5]]} />
      </div>
      <div :if={@block} class="strip-stack">
        <.strips
          rows={[@block.input, Enum.map(@block.input, &(&1 / @block.rms1)), @block.norm1]}
          labels={[
            "x, the dogs row · rms #{format_weight(@block.rms1)}",
            "x / rms(x) · rms 1.00",
            "· g, 32 learned floats"
          ]}
        />
      </div>
      <.untrained :if={is_nil(@block)} what="This row" />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :neural_network}} = assigns) do
    assigns = assign(assigns, block: block_trace(), block_path: @block_path)

    ~H"""
    <section class="slide slide--tight">
      <p class="slide__eyebrow">neural network &middot; MLP</p>
      <p class="formula">
        ReLU(<span class="formula__group">x W<sub>1</sub> + b<sub>1</sub></span>) W<sub>2</sub>
        + b<sub>2</sub>
      </p>
      <div>
        <.code path={@block_path} range={213..221} step={@step} focus={[[6..8]]} />
      </div>
      <div :if={@block} class="strip-stack">
        <.strips rows={[@block.norm2]} labels={["x · 32 wide"]} />
        <.strips
          rows={Enum.chunk_every(@block.hidden, 32)}
          labels={["ReLU(x W₁ + b₁) · 128 wide", "", "", "#{zeros(@block.hidden)} of them zero"]}
        />
        <.strips rows={[@block.mlp]} labels={["· W₂ + b₂ · 32 wide again"]} />
      </div>
      <.untrained :if={is_nil(@block)} what="This row" />
    </section>
    """
  end

  def slide(%{slide: %Slide{id: :residual}} = assigns) do
    assigns = assign(assigns, block: block_trace(), block_path: @block_path)

    ~H"""
    <section class="slide slide--tight">
      <p class="slide__eyebrow">residual</p>
      <p class="formula">
        x + <span class="formula__group">f(x)</span>
      </p>
      <div>
        <.code path={@block_path} range={213..221} step={@step} focus={[[4..4], [9..9]]} />
      </div>
      <div :if={@block} class="strip-stack">
        <.step n={1} step={@step} class="aside-figure">
          <.strips
            rows={[@block.input, @block.attention, @block.residual]}
            labels={["x", "attention(x)", "x + attention(x)"]}
          />
        </.step>
        <.step n={2} step={@step} class="aside-figure">
          <.strips
            rows={[@block.residual, @block.mlp, @block.output]}
            labels={["x", "mlp(x)", "x + mlp(x)"]}
          />
        </.step>
      </div>
      <.untrained :if={is_nil(@block)} what="This row" />
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

  def slide(%{slide: %Slide{id: :one_word_at_a_time}} = assigns) do
    words = Controls.generated(assigns.controls)

    temperature = Controls.temperature(assigns.controls)

    assigns =
      assign(assigns,
        words: words,
        finished: Controls.finished?(words),
        temperature: temperature,
        distribution: Model.distribution(["<start>" | words], temperature)
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
      <form id="temperature-dial" phx-change="control" class="dial dial--inline">
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
            <li>a tokenizer</li>
            <li>a GPU</li>
            <li>multi-head attention</li>
            <li>depth</li>
            <li>KV caching</li>
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

  def slide(%{slide: %Slide{id: :it_writes_again}} = assigns) do
    ~H"""
    <.writer controls={@controls} frame={@frame} eyebrow="github.com/jasondew/tiny_llm" sources />
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

  # The model writing a paragraph, with the forward pass for the word being
  # written drawn beside it. Opens the talk and closes it.
  attr :controls, :map, required: true
  attr :frame, :integer, required: true
  attr :eyebrow, :string, default: nil

  attr :sources, :boolean,
    default: false,
    doc: "the closing writer: sources where the controls were"

  defp writer(assigns) do
    seed = Writer.seed(Controls.shuffles(assigns.controls))
    frame = Writer.frame(seed, assigns.frame)
    assigns = assign(assigns, repo: Application.fetch_env!(:tiny_llm_talk, :repo_label))

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
      <div :if={@sources} class="writer__bar writer__sources">
        <p>
          <span class="writer__source-label">code</span>
          the model <code>{@repo}</code>
          &middot; this deck <code>github.com/jasondew/tiny_llm_talk</code>
        </p>
        <p>
          <span class="writer__source-label">papers</span>
          Vaswani et al. 2017, Attention Is All You Need <code>arxiv.org/abs/1706.03762</code>
          &middot; GPT-4 <code>arxiv.org/abs/2303.08774</code>
          &middot; Gemini <code>arxiv.org/abs/2312.11805</code>
          &middot; DeepSeek-V3 <code>arxiv.org/abs/2412.19437</code>
          &middot; Llama 4 <code>ai.meta.com/blog/llama-4-multimodal-intelligence</code>
        </p>
      </div>
      <div :if={not @sources} class="writer__bar">
        <p class="writer__count">temperature {Writer.temperature()}</p>
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
    <.probe words={@words} class="probe--line" />
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

  # The block's forward pass as a flow, top to bottom, in the order the code
  # runs it. With a stage named, that box is lit and the rest wait.
  @block_flow [
    {:input, "input", nil},
    {:norm1, "normalization", "norm"},
    {:attention, "attention", "attention"},
    {:add1, "x + attention(x)", "add"},
    {:norm2, "normalization", "norm"},
    {:network, "neural network", "mlp"},
    {:add2, "x + mlp(x)", "add"},
    {:output, "output", nil}
  ]

  attr :stage, :atom, default: nil

  defp block_flow(assigns) do
    assigns = assign(assigns, boxes: @block_flow)

    ~H"""
    <div class={["flow", @stage && "flow--stepping"]}>
      <%= for {{id, label, kind}, index} <- Enum.with_index(@boxes) do %>
        <span :if={index > 0} class="flow__arrow">&darr;</span>
        <div class={["flow__box", kind && "flow__box--#{kind}", id == @stage && "flow__box--lit"]}>
          {label}
        </div>
      <% end %>
    </div>
    """
  end

  # One transformer, as a stack: the block is boxed and marked with how many
  # times it repeats.
  attr :repeats, :string, default: nil
  attr :label, :string, default: nil, doc: "a name for the dashed box, at its left"
  attr :outputs, :string, default: nil, doc: "what the last layer says, if not this model's 32"

  defp block_diagram(assigns) do
    layers = @block_layers
    {_label, kind} = List.last(layers)

    assigns =
      assign(assigns,
        first: hd(layers),
        block: Enum.slice(layers, 1, 4),
        last: {assigns.outputs || elem(List.last(layers), 0), kind}
      )

    ~H"""
    <div class="stack stack--diagram">
      <.block_layer layer={@first} />
      <span class="stack__arrow">&darr;</span>
      <div class="stack__block">
        <span :if={@label} class="stack__block-label">{@label}</span>
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

  # The letter the attention formula gives each learned table, W with this
  # as its subscript. The other tables have no letter in the formula.
  defp formula_symbol(:query_weight), do: "Q"
  defp formula_symbol(:key_weight), do: "K"
  defp formula_symbol(:value_weight), do: "V"
  defp formula_symbol(:output_weight), do: "O"
  defp formula_symbol(_name), do: nil

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

  # What the grid beside the head's code shows at a step: the scores, the
  # scores with the future struck out, or the distribution. One grid, the
  # same cells throughout; only the numbers and the heat behind them change.
  defp attention_stage(trace, step) when step < @mask_step do
    %{
      caption: "scores = Q Kᵀ / √d",
      values: trace.scores,
      heat: positive_shares(trace.scores),
      format: :signed
    }
  end

  defp attention_stage(trace, step) when step < @softmax_step do
    %{
      caption: "scores, the future masked",
      values: trace.masked,
      heat: positive_shares(Enum.map(trace.masked, fn row -> Enum.map(row, &(&1 || 0.0)) end)),
      format: :signed
    }
  end

  # The masked cells stay struck out: their weight is exactly zero, and a
  # printed 0.00 would read as a small number rather than a rule.
  defp attention_stage(trace, _step) do
    %{
      caption: "weights = softmax(scores), row by row",
      values: keep_masked(trace.weights, trace.masked),
      heat: trace.weights,
      format: :weight
    }
  end

  # The word a row of attention weights lands on hardest.
  defp top_word(row) do
    Model.probe() |> Enum.zip(row) |> Enum.max_by(&elem(&1, 1)) |> elem(0)
  end

  defp projection_name("Q"), do: "the queries"
  defp projection_name("K"), do: "the keys"
  defp projection_name("V"), do: "the values"

  defp keep_masked(values, masked) do
    Enum.zip_with(values, masked, fn row, masked_row ->
      Enum.zip_with(row, masked_row, fn value, mask -> mask && value end)
    end)
  end

  # Heat for a matrix of scores: only a positive score pulls attention, so a
  # negative one is as dark as zero, and the brightest is the largest.
  defp positive_shares(rows) do
    peak = rows |> List.flatten() |> Enum.max() |> max(1.0e-9)
    Enum.map(rows, fn row -> Enum.map(row, &(max(&1, 0.0) / peak)) end)
  end

  # A matrix with its numbers printed on the heatmap's grid, and the heat
  # behind each. A nil is a masked cell, struck out.
  attr :values, :list, required: true
  attr :heat, :list, required: true
  attr :labels, :list, required: true
  attr :format, :atom, default: :signed, values: [:signed, :weight]
  attr :cell, :integer, default: 40

  defp score_grid(assigns) do
    ~H"""
    <div
      class="heatmap heatmap--numbers"
      style={"--heatmap-cell: #{@cell}px; --heatmap-columns: #{length(@labels)}"}
    >
      <div class="heatmap__corner" />
      <div :for={label <- @labels} class="heatmap__column-label"><span>{label}</span></div>
      <%= for {{row, heat_row}, label} <- Enum.zip(Enum.zip(@values, @heat), @labels) do %>
        <div class="heatmap__row-label">{label}</div>
        <div
          :for={{value, heat} <- Enum.zip(row, heat_row)}
          class={[
            "heatmap__cell",
            is_nil(value) && "heatmap__cell--masked",
            heat > 0.55 && "heatmap__cell--bright"
          ]}
          style={"--heat: #{Float.round(heat * 1.0, 3)}"}
        >
          {grid_number(value, @format)}
        </div>
      <% end %>
    </div>
    """
  end

  defp grid_number(nil, _format), do: "×"
  defp grid_number(value, :signed), do: format_signed(value)
  defp grid_number(value, :weight), do: format_weight(value)

  # Every value as a share of the largest magnitude, for a heatmap of a
  # matrix whose entries have signs.
  defp magnitudes(rows) do
    peak = rows |> List.flatten() |> Enum.map(&abs/1) |> Enum.max()
    Enum.map(rows, fn row -> Enum.map(row, &(abs(&1) / peak)) end)
  end

  # A few rows of floats as one heat strip each, on one shared scale, so the
  # eye can compare them: the same row before and after a stage, or a row and
  # what was added to it.
  attr :rows, :list, required: true
  attr :labels, :list, required: true
  attr :cell, :integer, default: 20

  defp strips(assigns) do
    ~H"""
    <.heatmap
      values={magnitudes(@rows)}
      row_labels={@labels}
      column_labels={Enum.map(1..length(hd(@rows)), fn _column -> "" end)}
      cell={@cell}
      class="heatmap--compact heatmap--strips"
    />
    """
  end

  # A matrix as a bare thumbnail: 32 columns at three pixels each, no labels,
  # so a weight matrix and the rows it produces line up column for column.
  attr :matrix, :list, required: true

  defp thumb(assigns) do
    ~H"""
    <.heatmap
      values={magnitudes(@matrix)}
      row_labels={Enum.map(@matrix, fn _row -> "" end)}
      column_labels={Enum.map(hd(@matrix), fn _column -> "" end)}
      cell={3}
      class="heatmap--compact heatmap--bare"
    />
    """
  end

  # The block's intermediates for the position predicting the blank.
  defp block_trace do
    case Model.trace(Model.probe()) do
      nil -> nil
      trace -> trace.block
    end
  end

  defp zeros(row), do: Enum.count(row, &(&1 == 0.0))

  # The shape of a matrix, or the size of a plain number, at the start of a
  # definition so the shapes line up down the slide.
  attr :rows, :integer, required: true
  attr :columns, :integer, default: nil

  defp shape(%{columns: nil} = assigns) do
    ~H"""
    <span class="definitions__shape">{@rows}</span>
    """
  end

  defp shape(assigns) do
    ~H"""
    <span class="definitions__shape">{@rows} × {@columns}</span>
    """
  end

  # One term of the formula over the toy table, lit while its column is the
  # one being filled in.
  attr :lit, :boolean, required: true
  slot :inner_block, required: true

  defp formula_term(assigns) do
    ~H"""
    <span class={["fuzzy-formula__term", @lit && "fuzzy-formula__term--lit"]}>{render_slot(
      @inner_block
    )}</span>
    """
  end

  defp entry_vector(key) do
    FuzzyMap.entries() |> Enum.find(&(&1.key == key)) |> Map.fetch!(:vector)
  end

  # The attention row of the position predicting the blank: where it looks,
  # as a distribution over the sentence so far. Nil before a checkpoint.
  defp blank_attention_row do
    case Model.attention(Model.probe()) do
      nil -> nil
      weights -> List.last(weights)
    end
  end

  defp probability_after(words, word) do
    case Model.distribution(words, 1.0) do
      nil -> nil
      distribution -> Enum.at(distribution, Vocab.word_to_id(word))
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
