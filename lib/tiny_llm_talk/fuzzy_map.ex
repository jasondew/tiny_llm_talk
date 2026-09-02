defmodule TinyLlmTalk.FuzzyMap do
  @moduledoc """
  Attention, built from the one data structure every engineer in the room
  already trusts.

  `Map.get/2` finds the one key equal to the query and returns its value. A
  fuzzy map scores every key against the query, turns the scores into a budget
  that sums to one, and returns the blend of every value weighted by that
  budget. Make the query, the keys and the values learned, and that is an
  attention head. Nothing in `TinyLlm.Attention` is missing from this file
  except the learning.

  The toy here is deliberately tiny and hand-authored. Each key is a word with
  a two-number vector, `[how much of an animal it is, how plural it is]`, and
  each value is one number, how plural the model should believe the word is.
  Querying with a word that is not in the map gives a sensible answer anyway,
  which is the whole reason to do the lookup this way.

  Presentation code: it lives in the talk, not in the model.
  """

  alias TinyLlm.Tensor

  @type entry :: %{key: String.t(), vector: [float()], value: float()}
  @type lookup :: %{
          query: String.t(),
          vector: [float()],
          scores: [%{key: String.t(), score: float(), weight: float(), value: float()}],
          blend: float()
        }

  # Keys are read at sampling time, which is why a softmax over dot products
  # rather than a max: two keys can be close, and the answer is a blend.
  @entries [
    %{key: "llama", vector: [1.0, -1.0], value: 0.0},
    %{key: "llamas", vector: [1.0, 1.0], value: 1.0},
    %{key: "dog", vector: [0.9, -1.0], value: 0.0},
    %{key: "dogs", vector: [0.9, 1.0], value: 1.0},
    %{key: "the", vector: [0.0, 0.0], value: 0.5}
  ]

  # Words the presenter can query with. The first two are in the map, so an
  # exact lookup would work; the rest are not, so it would not.
  @queries [
    %{word: "llama", vector: [1.0, -1.0]},
    %{word: "dogs", vector: [0.9, 1.0]},
    %{word: "goose", vector: [0.8, -1.0]},
    %{word: "geese", vector: [0.8, 1.0]},
    %{word: "mice", vector: [0.7, 0.9]}
  ]

  # How sharp the softmax is. Real attention gets this from the learned scale
  # of its queries and keys; the toy has to pick one so the blend commits.
  @sharpness 6.0

  @spec entries() :: [entry()]
  def entries, do: @entries

  @spec queries() :: [%{word: String.t(), vector: [float()]}]
  def queries, do: @queries

  @spec query_words() :: [String.t()]
  def query_words, do: Enum.map(@queries, & &1.word)

  @doc "What `Map.get/2` would say: the value under an exactly equal key, or nil."
  @spec exact(String.t()) :: float() | nil
  def exact(word) do
    case Enum.find(@entries, &(&1.key == word)) do
      nil -> nil
      entry -> entry.value
    end
  end

  @doc """
  The fuzzy lookup: score every key, softmax the scores, blend the values.

  Returns every intermediate so a slide can reveal them one at a time.
  """
  @spec lookup(String.t()) :: lookup()
  def lookup(word) do
    query = Enum.find(@queries, &(&1.word == word)) || hd(@queries)
    scores = Enum.map(@entries, fn entry -> Tensor.dot(query.vector, entry.vector) end)
    [weights] = Tensor.softmax([Enum.map(scores, &(&1 * @sharpness))])

    rows =
      [@entries, scores, weights]
      |> Enum.zip()
      |> Enum.map(fn {entry, score, weight} ->
        %{key: entry.key, score: score, weight: weight, value: entry.value}
      end)

    %{
      query: query.word,
      vector: query.vector,
      scores: rows,
      blend: rows |> Enum.map(&(&1.weight * &1.value)) |> Enum.sum()
    }
  end
end
