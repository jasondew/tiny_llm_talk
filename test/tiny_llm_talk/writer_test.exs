defmodule TinyLlmTalk.WriterTest do
  use ExUnit.Case, async: true

  alias TinyLlmTalk.Writer

  @seed Writer.seed(0)

  test "writes four sentences a seed always writes the same way" do
    assert length(Writer.paragraph(@seed)) == 4
    assert Writer.paragraph(@seed) == Writer.paragraph(@seed)
    assert Writer.paragraph(@seed) != Writer.paragraph(Writer.seed(1))
  end

  test "keeps every sentence short enough to draw" do
    for sentence <- Writer.paragraph(@seed) do
      assert length(sentence) <= 10
      assert List.last(sentence) == "."
    end
  end

  test "walks six phases per word, in the order of the forward pass" do
    phases = Enum.map(0..5, &Writer.frame(@seed, &1).phase)

    assert phases == Writer.phases()
    assert Writer.frame(@seed, 6).phase == :word
  end

  test "reads the prefix the model would be given, with the start token" do
    [first | _rest] = Writer.paragraph(@seed)

    assert Writer.frame(@seed, 0).prefix == ["<start>"]
    assert Writer.frame(@seed, 0).chosen == hd(first)
    assert Writer.frame(@seed, 6).prefix == ["<start>", hd(first)]
  end

  test "only shows the chosen word once it has been picked" do
    [first | _rest] = Writer.paragraph(@seed)

    assert Writer.frame(@seed, 4).current == []
    assert Writer.frame(@seed, 5).current == [hd(first)]
  end

  test "moves on to the next sentence and keeps the ones written" do
    [first | _rest] = Writer.paragraph(@seed)
    frame = Writer.frame(@seed, length(first) * 6)

    assert frame.sentence == 1
    assert frame.written == [first]
    assert frame.prefix == ["<start>"]
  end

  test "loops when the paragraph ends" do
    assert Writer.frame(@seed, Writer.length(@seed)) == Writer.frame(@seed, 0)
  end
end
