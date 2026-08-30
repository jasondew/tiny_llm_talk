defmodule TinyLlmTalk.SlideTest do
  use ExUnit.Case, async: true

  alias TinyLlmTalk.{Deck, Slide}

  test "reflows notes onto one line for the speaker" do
    slide = %Slide{id: :example, title: "Example", notes: "one line\nand another\n"}

    assert Slide.prose(slide) == "one line and another"
  end

  test "every slide carries notes worth glancing at" do
    for slide <- Deck.slides() do
      assert String.length(Slide.prose(slide)) > 20, "#{slide.id} has no notes"
    end
  end
end
