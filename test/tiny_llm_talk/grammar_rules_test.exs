defmodule TinyLlmTalk.GrammarRulesTest do
  use ExUnit.Case, async: true

  alias TinyLlmTalk.GrammarRules

  test "reads the four rules out of the grammar's own documentation, in order" do
    assert Enum.map(GrammarRules.rules(), &elem(&1, 0)) ==
             ~w(Sentence NounPhrase AdjectivePhrase VerbPhrase)
  end

  test "keeps every alternative, without the sampling percentages" do
    rules = Map.new(GrammarRules.rules())

    assert rules["Sentence"] == [~s(NounPhrase VerbPhrase ".")]
    assert length(rules["NounPhrase"]) == 3
    assert ~s(Determiner AdjectivePhrase Noun "who" VerbPhrase) in rules["NounPhrase"]
    assert "nothing" in rules["AdjectivePhrase"]

    for {_name, alternatives} <- rules, alternative <- alternatives do
      refute alternative =~ "%"
      refute alternative =~ "("
    end
  end
end
