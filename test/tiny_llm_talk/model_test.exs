defmodule TinyLlmTalk.ModelTest do
  use ExUnit.Case, async: true

  alias TinyLlm.Vocab
  alias TinyLlmTalk.Model

  @probe Model.probe()

  describe "parameter_breakdown/0" do
    test "names the six stages that hold weights, and they add up to the whole model" do
      breakdown = Model.parameter_breakdown()

      assert Enum.map(breakdown, &elem(&1, 0)) == [
               "embedding + position",
               "RMSNorm",
               "attention",
               "RMSNorm",
               "MLP",
               "32 probabilities"
             ]

      assert breakdown |> Enum.map(&elem(&1, 1)) |> Enum.sum() == Model.parameter_count()
      assert {"attention", 4 * 32 * 32} in breakdown
    end
  end

  describe "trace/1" do
    test "keeps one row per position at every stage" do
      trace = Model.trace(@probe)
      size = length(@probe)

      for stage <- [:input, :queries, :keys, :values, :scores, :masked, :weights, :context] do
        assert length(Map.fetch!(trace, stage)) == size, "#{stage} has the wrong number of rows"
      end
    end

    test "masks exactly the future" do
      trace = Model.trace(@probe)

      for {row, query} <- Enum.with_index(trace.masked), {cell, key} <- Enum.with_index(row) do
        assert is_nil(cell) == key > query
      end
    end

    test "weights are a budget over the past that sums to one" do
      trace = Model.trace(@probe)

      for {row, query} <- Enum.with_index(trace.weights) do
        assert_in_delta Enum.sum(row), 1.0, 1.0e-9
        assert row |> Enum.drop(query + 1) |> Enum.all?(&(&1 == 0.0))
      end
    end

    test "carries the block's plumbing for the last position" do
      block = Model.trace(@probe).block

      assert length(block.residual) == 32
      assert length(block.hidden) == 128
      assert Enum.all?(block.hidden, &(&1 >= 0.0))
      assert length(block.output) == 32
      assert length(block.logits) == 32
    end

    test "agrees with the attention the model reports" do
      assert Model.trace(@probe).weights == Model.attention(@probe)
    end
  end

  test "unmasked attention lets the future in" do
    [first | _rest] = Model.unmasked_attention(@probe)

    assert first |> Enum.drop(1) |> Enum.any?(&(&1 > 0.0))
  end

  test "picks the option the model likes best" do
    assert Model.pick(@probe, ~w(flees flee)) in ~w(flees flee)
    assert Model.bigram_pick("chases", ~w(the a dogs flees)) in ~w(the a)
  end

  test "draws a next word from the vocabulary" do
    assert Model.next(@probe, 1.0) in Vocab.words()
  end

  test "lines up one human sentence among the model's" do
    lineup = Model.lineup()
    seen = MapSet.new(Model.corpus())

    assert length(lineup.options) == 3
    assert lineup.answer in lineup.options
    assert MapSet.member?(seen, String.split(lineup.answer))

    for option <- lineup.options, option != lineup.answer do
      refute MapSet.member?(seen, String.split(option))
    end
  end

  test "counts the parameters the transformer is made of" do
    assert Model.parameter_count() > 10_000
  end

  test "reads a word's embedding and a position's vector as rows" do
    assert length(Model.embedding("llama")) == 32
    assert length(Model.position(0)) == 32
  end
end
