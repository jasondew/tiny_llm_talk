defmodule TinyLlmTalk.WriterTest do
  use ExUnit.Case, async: true

  alias TinyLlmTalk.Writer

  @seed Writer.seed(0)
  @per_word length(Writer.phases())

  test "writes four sentences a seed always writes the same way" do
    assert length(Writer.paragraph(@seed)) == 4
    assert Writer.paragraph(@seed) == Writer.paragraph(@seed)
    assert Writer.paragraph(@seed) != Writer.paragraph(Writer.seed(1))
  end

  test "samples a little cooler than 1.0, and says so" do
    assert Writer.temperature() == 0.8
    assert Writer.paragraph(@seed) == TinyLlmTalk.Model.paragraph(@seed, 4, 0.8)
    assert Writer.paragraph(@seed) != TinyLlmTalk.Model.paragraph(@seed, 4, 1.0)
  end

  test "keeps every sentence short enough to draw" do
    for sentence <- Writer.paragraph(@seed) do
      assert length(sentence) <= 10
      assert List.last(sentence) == "."
    end
  end

  test "walks seven phases per word, in the order of the forward pass" do
    phases = Enum.map(0..(@per_word - 1), &Writer.frame(@seed, &1).phase)

    assert phases == Writer.phases()
    assert :values in phases
    assert Writer.frame(@seed, @per_word).phase == :word
  end

  test "reads the prefix the model would be given, with the start token" do
    [first | _rest] = Writer.paragraph(@seed)

    assert Writer.frame(@seed, 0).prefix == ["<start>"]
    assert Writer.frame(@seed, 0).chosen == hd(first)
    assert Writer.frame(@seed, @per_word).prefix == ["<start>", hd(first)]
  end

  test "only shows the chosen word once it has been picked" do
    [first | _rest] = Writer.paragraph(@seed)

    assert Writer.frame(@seed, @per_word - 2).current == []
    assert Writer.frame(@seed, @per_word - 1).current == [hd(first)]
  end

  test "adds the pick to the sequence on screen, so the full stop is seen" do
    [first | _rest] = Writer.paragraph(@seed)
    last_pick = length(first) * @per_word - 1

    assert Writer.frame(@seed, last_pick - 1).sequence == ["<start>" | Enum.drop(first, -1)]
    assert Writer.frame(@seed, last_pick).sequence == ["<start>" | first]
    assert Writer.frame(@seed, last_pick + 1).sequence == ["<start>"]
  end

  test "keeps the last full stop on screen once the paragraph is finished" do
    last = Writer.length(@seed) - 1

    assert List.last(Writer.frame(@seed, last).sequence) == "."
  end

  test "moves on to the next sentence and keeps the ones written" do
    [first | _rest] = Writer.paragraph(@seed)
    frame = Writer.frame(@seed, length(first) * @per_word)

    assert frame.sentence == 1
    assert frame.written == [first]
    assert frame.prefix == ["<start>"]
  end

  test "stops on the finished paragraph instead of looping" do
    last = Writer.length(@seed) - 1

    refute Writer.finished?(@seed, last - 1)
    assert Writer.finished?(@seed, last)
    assert Writer.frame(@seed, last).finished
    assert Writer.frame(@seed, last + 50) == Writer.frame(@seed, last)
    assert Writer.frame(@seed, last).written == Enum.drop(Writer.paragraph(@seed), -1)
    assert Writer.frame(@seed, last).current == List.last(Writer.paragraph(@seed))
  end
end
