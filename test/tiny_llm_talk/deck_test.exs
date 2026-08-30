defmodule TinyLlmTalk.DeckTest do
  use ExUnit.Case, async: true

  alias TinyLlmTalk.Deck

  describe "the arc" do
    test "covers the eight sections of the outline, in order" do
      assert Enum.map(Deck.sections(), & &1.number) == Enum.to_list(0..7)
    end

    test "budgets the 46 minutes the outline budgets" do
      assert Deck.sections() |> Enum.map(& &1.minutes) |> Enum.sum() == 46
    end

    test "gives every slide a unique id" do
      ids = Enum.map(Deck.slides(), & &1.id)
      assert length(Enum.uniq(ids)) == length(ids)
    end

    test "numbers slides from one, without gaps" do
      assert Enum.map(Deck.slides(), & &1.index) == Enum.to_list(1..Deck.count())
    end

    test "puts every slide in the section that lists it" do
      for section <- Deck.sections(), slide <- section.slides do
        assert Deck.section(slide).number == section.number
      end
    end
  end

  describe "position/2" do
    test "defaults to the first slide" do
      assert Deck.position(nil, nil) == {1, 1}
    end

    test "clamps an index past the end of the deck" do
      assert {index, _step} = Deck.position("9999", "1")
      assert index == Deck.count()
    end

    test "clamps a step past the end of the slide" do
      assert Deck.position("1", "9999") == {1, Deck.at(1).steps}
    end

    test "survives junk in the address bar" do
      assert Deck.position("banana", "peel") == {1, 1}
    end
  end

  describe "move/2" do
    test "walks the steps of a slide before moving on" do
      stepped = Enum.find(Deck.slides(), &(&1.steps > 1))

      assert Deck.move("ArrowRight", {stepped.index, 1}) == {stepped.index, 2}
    end

    test "moves to the next slide from the last step" do
      slide = Deck.at(1)

      assert Deck.move(" ", {1, slide.steps}) == {2, 1}
    end

    test "arrives on the last step when going backwards into a slide" do
      previous = Deck.at(1)

      assert Deck.move("ArrowLeft", {2, 1}) == {1, previous.steps}
    end

    test "stays put at both ends" do
      last = Deck.count()

      assert Deck.move("ArrowLeft", {1, 1}) == {1, 1}
      assert Deck.move("ArrowRight", {last, Deck.at(last).steps}) == {last, Deck.at(last).steps}
    end

    test "ignores keys it does not know" do
      assert Deck.move("q", {4, 1}) == {4, 1}
    end

    test "jumps to either end" do
      assert Deck.move("Home", {12, 1}) == {1, 1}
      assert Deck.move("End", {12, 1}) == {Deck.count(), Deck.at(Deck.count()).steps}
    end
  end
end
