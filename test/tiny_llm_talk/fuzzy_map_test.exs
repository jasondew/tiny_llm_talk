defmodule TinyLlmTalk.FuzzyMapTest do
  use ExUnit.Case, async: true

  alias TinyLlmTalk.FuzzyMap

  test "an exact lookup works for a key in the map and not otherwise" do
    assert FuzzyMap.exact("llama") == 0.0
    assert FuzzyMap.exact("llamas") == 1.0
    assert is_nil(FuzzyMap.exact("goose"))
  end

  test "the weights are a budget that sums to one" do
    lookup = FuzzyMap.lookup("geese")

    assert_in_delta lookup.scores |> Enum.map(& &1.weight) |> Enum.sum(), 1.0, 1.0e-9
  end

  test "a word that is not in the map still gets a sensible answer" do
    assert FuzzyMap.lookup("geese").blend > 0.8
    assert FuzzyMap.lookup("goose").blend < 0.2
  end

  test "an exact key gets most of the budget" do
    lookup = FuzzyMap.lookup("llama")
    top = Enum.max_by(lookup.scores, & &1.weight)

    assert top.key == "llama"
  end

  test "falls back to the first query for a word it does not offer" do
    assert FuzzyMap.lookup("banana").query == hd(FuzzyMap.query_words())
  end
end
