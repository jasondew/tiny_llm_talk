defmodule TinyLlmTalk.SlideTest do
  use ExUnit.Case, async: true

  alias TinyLlmTalk.{Deck, Slide}

  test "reflows notes onto one line for the speaker" do
    slide = %Slide{id: :example, title: "Example", notes: "one line\nand another\n"}

    assert Slide.prose(slide) == "one line and another"
  end

  test "reads bullets and definitions, grouping runs of each" do
    slide = %Slide{
      id: :example,
      title: "Example",
      notes: """
      - first cue
        wrapped onto a second line
      = rms: root mean square
      = g: a learned gain
      ! say this one out loud
      - last cue
      """
    }

    assert Slide.blocks(slide) == [
             {:bullets, ["first cue wrapped onto a second line"]},
             {:definitions, [{"rms", "root mean square"}, {"g", "a learned gain"}]},
             {:musts, ["say this one out loud"]},
             {:bullets, ["last cue"]}
           ]
  end

  test "every slide carries notes worth glancing at" do
    for slide <- Deck.slides() do
      assert String.length(Slide.prose(slide)) > 20, "#{slide.id} has no notes"
    end
  end
end
