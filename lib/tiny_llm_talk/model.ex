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

  alias TinyLlm.{Bigram, Eval, Grammar, PCA, Sampler, Transformer, Vocab}
  alias TinyLlmTalk.Checkpoint

  @seed 1234
  @corpus_size 2_000
  @probe_corpus_size 20_000
  @floor_corpus_size 50_000
  @held_out_corpus_size 5_000

  @doc "The probe the talk turns on, and its mirror."
  @spec probe() :: [Vocab.word()]
  def probe, do: ~w(<start> the llama who chases the dogs)

  @spec mirror_probe() :: [Vocab.word()]
  def mirror_probe, do: ~w(<start> the dogs who chase the llama)

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
  @spec agreement(:bigram | :embedder | :transformer, :distractor | :all) :: float() | nil
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

  @doc """
  The attention a prefix pays to itself: one row per position, one column per
  position looked at. The upper triangle is empty because of the causal mask.
  """
  @spec attention([Vocab.word()]) :: [[float()]] | nil
  def attention(words) do
    memoize({:attention, words}, fn ->
      case params(:transformer) do
        nil -> nil
        params -> Transformer.weights(params, Vocab.encode(words))
      end
    end)
  end

  @doc "What the trained transformer thinks comes next, at a temperature."
  @spec distribution([Vocab.word()], float()) :: [float()] | nil
  def distribution(words, temperature) do
    case params(:transformer) do
      nil -> nil
      params -> Sampler.distribution(params, words, temperature)
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
  previous word. Nothing that sees one word beats this, which is the whole
  setup for section three.

  Measured on a much larger corpus than the one the slides count, because the
  estimate is biased downward on a small sample: 2,000 sentences say 1.894 and
  50,000 say 1.904, and the smaller number would make the floor look lower than
  it is. Same reason `Train.run/1` measures loss on held-out data.
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
  What a count table built from 2,000 sentences actually scores on sentences it
  has not seen.

  Above the floor, because finite counts are not the true distribution. Worth
  having on the same chart as the floor: the gap between them is the price of
  counting rather than knowing.
  """
  @spec bigram_held_out() :: float()
  def bigram_held_out do
    memoize(:bigram_held_out, fn ->
      matrix = bigram()
      Grammar.seed(@seed + 2)

      {total, predictions} =
        @held_out_corpus_size
        |> Grammar.corpus()
        |> Enum.reduce({0.0, 0}, fn sentence, accumulator ->
          ids = Vocab.encode([Vocab.start_token() | sentence])

          ids
          |> Enum.zip(tl(ids))
          |> Enum.reduce(accumulator, fn {from, to}, {total, predictions} ->
            probability = matrix |> Enum.at(from) |> Enum.at(to)

            {total - :math.log(max(probability, 1.0e-12)), predictions + 1}
          end)
        end)

      total / predictions
    end)
  end

  @doc """
  The learned embeddings, flattened onto their two strongest directions, with
  each word's part of speech so the scatter can colour by it.
  """
  @spec embedding_scatter() :: [%{word: Vocab.word(), x: float(), y: float(), kind: atom()}] | nil
  def embedding_scatter do
    memoize(:embedding_scatter, fn ->
      case params(:embedder) do
        nil ->
          nil

        %{embeddings: embeddings} ->
          PCA.seed(@seed)

          embeddings
          |> PCA.project()
          |> Enum.with_index()
          |> Enum.map(fn {{x, y}, id} ->
            word = Vocab.id_to_word(id)

            %{word: word, x: x, y: y, kind: kind(word)}
          end)
      end
    end)
  end

  @doc """
  What temperature costs and buys, measured rather than asserted: how many
  generated sentences are grammatical, and how many are distinct, as it rises.
  """
  @spec temperature_curve() ::
          [%{temperature: float(), grammatical: float(), distinct: float()}] | nil
  def temperature_curve do
    memoize(:temperature_curve, fn ->
      if trained?(:transformer) do
        Enum.map([0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0], fn temperature ->
          sentences = sentences(temperature, 100)

          %{
            temperature: temperature,
            grammatical: Eval.grammaticality(sentences),
            distinct: length(Enum.uniq(sentences)) / length(sentences)
          }
        end)
      end
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

  @doc "Sentences the count table generates, from a fixed seed."
  @spec bigram_sentences(pos_integer()) :: [Grammar.sentence()]
  def bigram_sentences(count) do
    memoize({:bigram_sentences, count}, fn ->
      Bigram.seed(@seed)
      matrix = bigram()

      Enum.map(1..count//1, fn _index -> Bigram.sentence(matrix) end)
    end)
  end

  @doc "One word's learned embedding, as the row of floats it actually is."
  @spec embedding(Vocab.word()) :: [float()] | nil
  def embedding(word) do
    case params(:embedder) do
      nil -> nil
      %{embeddings: embeddings} -> Enum.at(embeddings, Vocab.word_to_id(word))
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

  defp predictor(:embedder) do
    case params(:embedder) do
      nil -> nil
      params -> Eval.embedder_predictor(params)
    end
  end

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
