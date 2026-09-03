defmodule TinyLlmTalk.Model do
  @moduledoc """
  The model's own numbers, computed once and kept.

  Slides quote the model rather than a transcription of it. The corpus, the
  bigram counts, and the trained weights all come from here, so a figure on a
  slide is the thing itself and cannot be stale in the way a pasted number can.

  Everything is memoized behind an Agent because it is all deterministic: one
  seed, one corpus, one count table. The application warms it at boot so the
  first slide that needs a figure does not pay for it in front of a room.
  """

  use Agent

  alias TinyLlm.{Bigram, Eval, Grammar, Sampler, Tensor, Transformer, Vocab}
  alias TinyLlmTalk.Checkpoint

  @seed 1234
  # Bump when the shape of a trace changes. The Agent outlives a code reload
  # in development, and a memoized trace of the old shape would otherwise be
  # handed to a slide expecting the new one.
  @trace_shape 2
  @corpus_size 2_000
  @probe_corpus_size 20_000
  @floor_corpus_size 50_000

  @doc "The probe the talk turns on, and its mirror."
  @spec probe() :: [Vocab.word()]
  def probe, do: ~w(<start> the llama who chases the dogs)

  @spec mirror_probe() :: [Vocab.word()]
  def mirror_probe, do: ~w(<start> the dogs who chase the llama)

  @doc """
  A second probe for the rematch at the end: plural subject, singular
  distractor, so the nearest noun lies the other way round.
  """
  @spec rematch_probe() :: [Vocab.word()]
  def rematch_probe, do: ~w(<start> the geese who see a fox)

  def start_link(_options), do: Agent.start_link(fn -> %{} end, name: __MODULE__)

  @doc "Two thousand sentences from the grammar, from a fixed seed."
  @spec corpus() :: [Grammar.sentence()]
  def corpus do
    memoize(:corpus, fn ->
      Grammar.seed(@seed)
      Grammar.corpus(@corpus_size)
    end)
  end

  @doc "How often each ordered pair of words was seen."
  @spec counts() :: Bigram.counts()
  def counts, do: memoize(:counts, fn -> Bigram.counts(corpus()) end)

  @doc "The count table, normalized into 32 rows of probabilities."
  @spec bigram() :: [[float()]]
  def bigram, do: memoize(:bigram, fn -> Bigram.matrix(counts()) end)

  @doc "The row the bigram would predict from, for one word."
  @spec bigram_row(Vocab.word()) :: [float()]
  def bigram_row(word), do: Enum.at(bigram(), Vocab.word_to_id(word))

  @doc "The most likely next word in the count table, among some options."
  @spec bigram_pick(Vocab.word(), [Vocab.word()]) :: Vocab.word()
  def bigram_pick(word, options) do
    row = bigram_row(word)

    Enum.max_by(options, fn option -> Enum.at(row, Vocab.word_to_id(option)) end)
  end

  @doc "Held-out probes where a noun of the wrong number sits next to the blank."
  @spec probes() :: [Eval.probe()]
  def probes do
    memoize(:probes, fn ->
      Grammar.seed(@seed + 1)
      @probe_corpus_size |> Grammar.corpus() |> Eval.probes()
    end)
  end

  @doc """
  The probes where a one-word model cannot do better than chance: a noun of the
  wrong number sits between the subject and the blank.

  The aggregate over all probes flatters every model, because a third of them
  end in a verb or an adjective that already agrees, and those are free. This
  subset is the contrast the talk is about.
  """
  @spec distractor_probes() :: [Eval.probe()]
  def distractor_probes do
    memoize(:distractor_probes, fn ->
      Enum.filter(probes(), fn probe ->
        case noun_number(List.last(probe.prefix)) do
          nil -> false
          number -> number != probe.number
        end
      end)
    end)
  end

  @doc """
  How often a model picks a verb of the right number, over the distractor
  probes by default, or over every probe.
  """
  @spec agreement(:bigram | :transformer, :distractor | :all) :: float() | nil
  def agreement(model, over \\ :distractor) do
    memoize({:agreement, model, over}, fn ->
      probes = if over == :all, do: probes(), else: distractor_probes()

      case predictor(model) do
        nil -> nil
        predict -> Eval.agreement(predict, probes)
      end
    end)
  end

  @doc """
  A trained checkpoint, or `nil` until `mix talk.train` has been run.

  Returns the whole run: params, the loss history, and how long it took.
  """
  @spec checkpoint(Checkpoint.name()) :: map() | nil
  def checkpoint(name), do: memoize({:checkpoint, name}, fn -> Checkpoint.read(name) end)

  @spec params(Checkpoint.name()) :: map() | nil
  def params(name) do
    case checkpoint(name) do
      %{params: params} -> params
      nil -> nil
    end
  end

  @spec trained?(Checkpoint.name()) :: boolean()
  def trained?(name), do: not is_nil(checkpoint(name))

  @doc "How many numbers the transformer is made of."
  @spec parameter_count() :: non_neg_integer() | nil
  def parameter_count do
    case params(:transformer) do
      nil -> nil
      params -> params |> Map.values() |> Enum.map(&(length(&1) * length(hd(&1)))) |> Enum.sum()
    end
  end

  @doc """
  The attention a prefix pays to itself: one row per position, one column per
  position looked at. The upper triangle is empty because of the causal mask.
  """
  @spec attention([Vocab.word()]) :: [[float()]] | nil
  def attention(words) do
    case trace(words) do
      nil -> nil
      trace -> trace.weights
    end
  end

  @doc """
  One forward pass through the head, with every intermediate a slide can show:
  the rows that went in, the queries and keys they became, the raw scores,
  the scores with the future masked, and the weights after the softmax.

  The model's own cache keeps the weights but not the scores, so those are
  recomputed here from the queries and keys, with the same `Tensor` the model
  used. `masked` holds `nil` where the mask applies, because the number the
  model uses there is minus a billion and nobody wants to read that.

  `block` is what happens to the last position after the head: the residual
  add, the MLP's hidden layer after the ReLU, the MLP's output added back,
  and the logits after the final norm and projection.
  """
  @spec trace([Vocab.word()]) :: map() | nil
  def trace(words) do
    memoize({:trace, @trace_shape, words}, fn ->
      case params(:transformer) do
        nil ->
          nil

        params ->
          cache = Transformer.forward(params, Vocab.encode(words))
          head = cache.block.attention
          width = length(hd(head.input))

          scores =
            head.queries
            |> Tensor.matmul(Tensor.transpose(head.keys))
            |> Tensor.scale(1.0 / :math.sqrt(width))

          masked =
            Enum.with_index(scores, fn row, query ->
              Enum.with_index(row, fn score, key -> if key > query, do: nil, else: score end)
            end)

          %{
            words: words,
            input: cache.input,
            queries: head.queries,
            keys: head.keys,
            values: head.values,
            scores: scores,
            masked: masked,
            weights: head.weights,
            context: head.context,
            block: %{
              residual: List.last(cache.block.residual),
              hidden: List.last(cache.block.hidden),
              output: List.last(cache.block.output),
              logits: List.last(cache.logits)
            }
          }
      end
    end)
  end

  @doc """
  What the weights would be with no causal mask: the softmax over the raw
  scores, future included. The wrong answer, shown once so the mask makes sense.
  """
  @spec unmasked_attention([Vocab.word()]) :: [[float()]] | nil
  def unmasked_attention(words) do
    case trace(words) do
      nil -> nil
      trace -> Tensor.softmax(trace.scores)
    end
  end

  @doc "What the trained transformer thinks comes next, at a temperature."
  @spec distribution([Vocab.word()], float()) :: [float()] | nil
  def distribution(words, temperature) do
    case params(:transformer) do
      nil -> nil
      params -> Sampler.distribution(params, words, temperature)
    end
  end

  @doc "One word, drawn from what the model thinks comes next. Random on purpose."
  @spec next([Vocab.word()], float()) :: Vocab.word() | nil
  def next(words, temperature) do
    case params(:transformer) do
      nil -> nil
      params -> Sampler.next_word(params, words, temperature)
    end
  end

  @doc """
  Which of some options the model likes best after a prefix. The model's
  answer to a question the room has just been asked.
  """
  @spec pick([Vocab.word()], [Vocab.word()]) :: Vocab.word() | nil
  def pick(words, options) do
    case distribution(words, 1.0) do
      nil -> nil
      distribution -> Enum.max_by(options, &Enum.at(distribution, Vocab.word_to_id(&1)))
    end
  end

  @doc "Sentences the trained model generates at a temperature, from a fixed seed."
  @spec sentences(float(), pos_integer()) :: [[Vocab.word()]] | nil
  def sentences(temperature, count) do
    memoize({:sentences, temperature, count}, fn ->
      case params(:transformer) do
        nil ->
          nil

        params ->
          Sampler.seed(@seed)

          Enum.map(1..count//1, fn _index ->
            Sampler.sentence(params, temperature: temperature)
          end)
      end
    end)
  end

  @doc """
  A paragraph for the writer to write: `count` sentences from a seed at a
  temperature, each short enough to draw a forward pass for. Longer ones are skipped, not cut,
  so every sentence shown is one the model actually finished.
  """
  @spec paragraph(integer(), pos_integer(), float()) :: [[Vocab.word()]] | nil
  def paragraph(seed, count, temperature) do
    memoize({:paragraph, seed, count, temperature}, fn ->
      case params(:transformer) do
        nil ->
          nil

        params ->
          Sampler.seed(seed)

          Stream.repeatedly(fn -> Sampler.sentence(params, temperature: temperature) end)
          |> Stream.filter(&(length(&1) <= 10 and List.last(&1) == "."))
          |> Enum.take(count)
      end
    end)
  end

  @doc """
  Three sentences for the room to judge: one written by the grammar, two
  written by the model and never seen in training. Shuffled from a seed, so
  the human one is in the same place every time the talk is given.

  Without a checkpoint the model has written nothing, so all three come from
  the grammar and the question is unanswerable, which the slide says.
  """
  @spec lineup() :: %{options: [String.t()], answer: String.t()}
  def lineup do
    memoize(:lineup, fn ->
      seen = MapSet.new(corpus())
      readable = Enum.filter(corpus(), &(length(&1) in 5..8))
      human = Enum.at(readable, 3)

      machine =
        case sentences(1.0, 40) do
          nil ->
            Enum.slice(readable, 4, 2)

          generated ->
            generated
            |> Enum.reject(&MapSet.member?(seen, &1))
            |> Enum.filter(&(length(&1) in 5..8 and Eval.grammatical?(&1)))
            |> Enum.take(2)
        end

      :rand.seed(:exsss, @seed)
      options = [human | machine] |> Enum.map(&Enum.join(&1, " ")) |> Enum.shuffle()

      %{options: options, answer: Enum.join(human, " ")}
    end)
  end

  @doc "The loss history of a training run, as `{step, loss}` pairs."
  @spec losses(Checkpoint.name()) :: [{non_neg_integer(), float()}] | nil
  def losses(name) do
    case checkpoint(name) do
      %{losses: losses} -> losses
      nil -> nil
    end
  end

  @doc """
  ln(32): the loss of knowing nothing at all, which is where every run starts.
  """
  @spec knowing_nothing() :: float()
  def knowing_nothing, do: :math.log(Vocab.size())

  @doc """
  H(next | previous): the best score anything can reach seeing only the
  previous word. A line on the loss chart, so the room can see the model go
  under it.

  Measured on a much larger corpus than the one the slides count, because the
  estimate is biased downward on a small sample: 2,000 sentences say 1.894 and
  50,000 say 1.904, and the smaller number would make the floor look lower than
  it is.
  """
  @spec bigram_floor() :: float()
  def bigram_floor do
    memoize(:bigram_floor, fn ->
      Grammar.seed(@seed)

      @floor_corpus_size
      |> Grammar.corpus()
      |> Bigram.counts()
      |> conditional_entropy()
    end)
  end

  @doc """
  Four sentences chosen to show the structures the grammar can build: a plain
  one, one with an adjective, one with a compound subject, and one with the
  relative clause the whole talk turns on.
  """
  @spec showcase_sentences() :: [Grammar.sentence()]
  def showcase_sentences do
    memoize(:showcase_sentences, fn ->
      corpus = corpus()

      [
        first_matching(corpus, &(&1 not in ["who", "and"])),
        first_matching(corpus, &(&1 in Vocab.adjectives())),
        first_matching(corpus, &(&1 == "and")),
        first_matching(corpus, &(&1 == "who"))
      ]
    end)
  end

  @doc "One word's learned embedding, as the row of floats it actually is."
  @spec embedding(Vocab.word()) :: [float()] | nil
  def embedding(word) do
    case params(:transformer) do
      nil -> nil
      %{embeddings: embeddings} -> Enum.at(embeddings, Vocab.word_to_id(word))
    end
  end

  @doc "The learned vector for one position, as the row of floats it actually is."
  @spec position(non_neg_integer()) :: [float()] | nil
  def position(index) do
    case params(:transformer) do
      nil -> nil
      %{positions: positions} -> Enum.at(positions, index)
    end
  end

  @doc "Which part of speech a word belongs to, for colouring a figure."
  @spec kind(Vocab.word()) :: atom()
  def kind(word) do
    cond do
      word in [Vocab.start_token(), Vocab.end_token()] -> :boundary
      word in Vocab.determiners() -> :determiner
      word in Vocab.nouns() -> :noun
      word in Vocab.adjectives() -> :adjective
      word in Vocab.connectives() -> :connective
      true -> :verb
    end
  end

  ## PRIVATE FUNCTIONS

  defp predictor(:bigram), do: Eval.bigram_predictor(bigram())

  defp predictor(:transformer) do
    case params(:transformer) do
      nil -> nil
      params -> Eval.model_predictor(params)
    end
  end

  defp conditional_entropy(counts) do
    totals =
      Enum.reduce(counts, %{}, fn {{from, _to}, n}, totals ->
        Map.update(totals, from, n, &(&1 + n))
      end)

    grand_total = totals |> Map.values() |> Enum.sum()

    Enum.reduce(counts, 0.0, fn {{from, _to}, n}, entropy ->
      entropy - n / grand_total * :math.log(n / Map.fetch!(totals, from))
    end)
  end

  # A sentence is "shortest one containing a word the predicate likes", so the
  # examples stay readable rather than being whatever came first.
  defp first_matching(corpus, predicate) do
    corpus
    |> Enum.filter(fn sentence -> Enum.any?(sentence, predicate) end)
    |> Enum.min_by(&length/1)
  end

  defp noun_number(word) do
    cond do
      word in Vocab.nouns(:singular) -> :singular
      word in Vocab.nouns(:plural) -> :plural
      true -> nil
    end
  end

  # The work happens in the caller, not in the Agent. Computing inside a
  # `get_and_update` would deadlock the moment one memoized value asked for
  # another, which every one of these does: the bigram needs the counts, and
  # the counts need the corpus.
  #
  # Two callers racing on a cold key both compute, and the first one to finish
  # wins. Every value here is deterministic, so that costs a little work and
  # changes nothing.
  defp memoize(key, compute) do
    case Agent.get(__MODULE__, &Map.fetch(&1, key)) do
      {:ok, value} ->
        value

      :error ->
        value = compute.()
        Agent.update(__MODULE__, &Map.put_new(&1, key, value))
        value
    end
  end
end
