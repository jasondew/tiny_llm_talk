defmodule TinyLlmTalk.SourceTest do
  use ExUnit.Case, async: true

  alias TinyLlmTalk.Source

  @attention "lib/tiny_llm/attention.ex"

  test "quotes a whole function from the model's source" do
    quotation = Source.function(@attention, :attend)

    assert String.starts_with?(quotation.code, "def attend(params, input) do")
    assert String.ends_with?(quotation.code, "end")
  end

  test "reports where the quote came from" do
    quotation = Source.function(@attention, :attend)

    assert quotation.path == @attention
    assert quotation.first_line > 0
  end

  test "dedents to the left margin" do
    quotation = Source.function(@attention, :attend)

    refute String.starts_with?(quotation.code, " ")
  end

  test "quotes a one-line definition without swallowing what follows" do
    quotation = Source.function(@attention, :mask_value)

    assert quotation.code == "def mask_value, do: -1.0e9"
  end

  test "quotes an explicit line range" do
    quotation = Source.lines(@attention, 1..1)

    assert quotation.code == "defmodule TinyLlm.Attention do"
    assert quotation.first_line == 1
  end

  test "captions a range with the lines it came from" do
    assert Source.lines(@attention, 198..213).location == "#{@attention}:198-213"
    assert Source.lines(@attention, 1..1).location == "#{@attention}:1"
  end

  test "raises rather than showing a slide about a function that has been renamed" do
    assert_raise ArgumentError, ~r/no definition of gone_away/, fn ->
      Source.function(@attention, :gone_away)
    end
  end
end
