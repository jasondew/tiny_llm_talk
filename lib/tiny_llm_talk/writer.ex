defmodule TinyLlmTalk.Writer do
  @moduledoc """
  The model writing a paragraph, one phase of one word at a time.

  A frame number is the whole state. Frame zero is the first phase of the
  first word of the first sentence; each word takes seven frames, one per
  phase of the forward pass, and the last frame is the paragraph finished,
  where it stays. Because the paragraph is drawn from a seed, the same frame
  shows the same thing in the room's window and the speaker's, and in
  rehearsal.

  The phases follow `TinyLlm.Transformer.forward/2` in order: the word
  becomes an integer, the rows attention will read, the queries and keys,
  the attention itself, the values blended by it, the distribution over what
  comes next, and the pick. The pick joins the sequence the moment it is
  made, which is the only way a full stop is ever seen: it ends the sentence,
  so it is never read as input.

  Everything here is arithmetic on a list of sentences. What the phases look
  like is the slide's business.
  """

  alias TinyLlmTalk.Model

  @phases [:word, :rows, :query_keys, :attention, :values, :next, :pick]
  @per_word length(@phases)
  @sentences_per_paragraph 4
  @seed 1234

  # At 1.0 the model slips on agreement in about one sentence in thirty, one
  # paragraph in nine. Cooling it a little halves that and keeps the variety.
  @temperature 0.8

  @type phase :: :word | :rows | :query_keys | :attention | :values | :next | :pick
  @type frame :: %{
          phase: phase(),
          prefix: [String.t()],
          sequence: [String.t()],
          chosen: String.t(),
          written: [[String.t()]],
          current: [String.t()],
          sentence: non_neg_integer(),
          total: pos_integer(),
          finished: boolean()
        }

  @spec phases() :: [phase()]
  def phases, do: @phases

  @doc "The seed a shuffle count turns into. Zero shuffles is the checkpoint's seed."
  @spec seed(non_neg_integer()) :: integer()
  def seed(shuffles), do: @seed + shuffles

  @doc "The temperature the writer samples at, which the slide says out loud."
  @spec temperature() :: float()
  def temperature, do: @temperature

  @doc "The paragraph a seed writes. Four sentences, short enough to draw."
  @spec paragraph(integer()) :: [[String.t()]] | nil
  def paragraph(seed), do: Model.paragraph(seed, @sentences_per_paragraph, @temperature)

  @doc "How many frames the paragraph takes to finish."
  @spec length(integer()) :: pos_integer()
  def length(seed) do
    case paragraph(seed) do
      nil -> 1
      sentences -> sentences |> Enum.map(&Kernel.length/1) |> Enum.sum() |> Kernel.*(@per_word)
    end
  end

  @doc """
  The next frame that is a pick: this word's if it has not been picked yet,
  otherwise the next word's. Realtime pace steps from pick to pick, so every
  word is seen chosen and the full stop lands whatever phase the clock was on
  when the pace changed.
  """
  @spec next_pick(non_neg_integer()) :: pos_integer()
  def next_pick(number), do: number + @per_word - rem(number + 1, @per_word)

  @doc "Whether the paragraph is finished by this frame."
  @spec finished?(integer(), non_neg_integer()) :: boolean()
  def finished?(seed, number), do: number >= __MODULE__.length(seed) - 1

  @doc """
  What is on screen at a frame: which phase, the prefix being read, the
  sequence as integers with the pick appended once it is made, the word
  about to be chosen, the sentences already written and the words of the
  current one so far. Frames past the end show the end. Nil until there is a
  checkpoint to write with.
  """
  @spec frame(integer(), non_neg_integer()) :: frame() | nil
  def frame(seed, number) do
    case paragraph(seed) do
      nil ->
        nil

      sentences ->
        last = __MODULE__.length(seed) - 1

        sentences
        |> locate(min(number, last))
        |> Map.put(:finished, number >= last)
    end
  end

  ## PRIVATE FUNCTIONS

  defp locate(sentences, number) do
    {sentence_index, word_index, phase_index} = position(sentences, number, 0)
    sentence = Enum.at(sentences, sentence_index)
    {before, [chosen | _rest]} = Enum.split(sentence, word_index)
    phase = Enum.at(@phases, phase_index)

    picked = if phase == :pick, do: before ++ [chosen], else: before

    %{
      phase: phase,
      prefix: ["<start>" | before],
      sequence: ["<start>" | picked],
      chosen: chosen,
      written: Enum.take(sentences, sentence_index),
      current: picked,
      sentence: sentence_index,
      total: Kernel.length(sentences)
    }
  end

  # Walks sentence by sentence, seven frames a word, until the frame lands.
  defp position([sentence | rest], number, index) do
    frames = Kernel.length(sentence) * @per_word

    if number < frames do
      {index, div(number, @per_word), rem(number, @per_word)}
    else
      position(rest, number - frames, index + 1)
    end
  end
end
