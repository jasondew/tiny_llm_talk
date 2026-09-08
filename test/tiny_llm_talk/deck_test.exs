defmodule TinyLlmTalk.DeckTest do
  use ExUnit.Case, async: true

  alias TinyLlmTalk.Deck

  describe "the arc" do
    test "covers the eight sections of the outline, in order" do
      assert Enum.map(Deck.sections(), & &1.number) == Enum.to_list(0..7)
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

  describe "the clock's budget" do
    test "adds every section's minutes into the whole talk" do
      minutes = Deck.sections() |> Enum.map(& &1.minutes) |> Enum.sum()

      assert Deck.total_seconds() == minutes * 60
    end

    test "expects nothing at the very first slide" do
      assert Deck.expected_seconds(Deck.at(1)) == 0
    end

    test "expects a section's earlier minutes in full at its first slide" do
      [first, second | _rest] = Deck.sections()
      opening = hd(second.slides)

      assert Deck.expected_seconds(opening) == first.minutes * 60
    end

    test "gives a slide a window that ends where the next one begins" do
      section = Enum.find(Deck.sections(), &(length(&1.slides) >= 2))
      [first, second | _rest] = section.slides

      assert Deck.expected_window(first) ==
               {Deck.expected_seconds(first), Deck.expected_seconds(second)}
    end

    test "spreads a section's minutes evenly over its slides" do
      section = Enum.find(Deck.sections(), &(length(&1.slides) >= 2))
      [first, second | _rest] = section.slides

      assert Deck.expected_seconds(second) - Deck.expected_seconds(first) ==
               div(section.minutes * 60, length(section.slides))
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

    test "takes the step count from whoever is doing the drawing" do
      stepped = Enum.find(Deck.slides(), &(&1.steps > 1))
      undrawn = fn _index -> 1 end

      assert Deck.move("ArrowRight", {stepped.index, 1}, undrawn) == {stepped.index + 1, 1}
    end

    test "ignores keys it does not know" do
      assert Deck.move("q", {4, 1}) == {4, 1}
    end

    test "jumps to either end" do
      assert Deck.move("Home", {12, 1}) == {1, 1}
      assert Deck.move("End", {12, 1}) == {Deck.count(), Deck.at(Deck.count()).steps}
    end
  end

  describe "skip/2" do
    test "moves a whole slide at a time, landing on the first step" do
      assert Deck.skip("ArrowRight", {4, 2}) == {5, 1}
      assert Deck.skip("ArrowLeft", {4, 2}) == {3, 1}
    end

    test "stays put at both ends" do
      assert Deck.skip("ArrowLeft", {1, 1}) == {1, 1}
      assert Deck.skip("ArrowRight", {Deck.count(), 1}) == {Deck.count(), 1}
    end

    test "still jumps to either end and ignores unknown keys" do
      assert Deck.skip("End", {4, 1}) == Deck.move("End", {4, 1})
      assert Deck.skip("q", {4, 2}) == {4, 2}
    end
  end
end
