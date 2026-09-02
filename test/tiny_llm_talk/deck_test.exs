defmodule TinyLlmTalk.DeckTest do
  use ExUnit.Case, async: true

  alias TinyLlmTalk.{Deck, Room}

  describe "the arc" do
    test "covers the ten sections of the outline, in order" do
      assert Enum.map(Deck.sections(), & &1.number) == Enum.to_list(0..9)
    end

    test "budgets the 41 minutes the outline budgets, leaving four for questions" do
      assert Deck.sections() |> Enum.map(& &1.minutes) |> Enum.sum() == 41
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

    test "only names activities the room knows how to run" do
      for slide <- Deck.slides(), slide.activity do
        assert Room.activity(slide.activity), "#{slide.id} asks for #{slide.activity}"
      end
    end

    test "gives every question a second step to reveal its answer on" do
      for slide <- Deck.slides(), slide.activity, Room.activity(slide.activity).answer do
        assert slide.steps >= 2, "#{slide.id} has nowhere to reveal the answer"
      end
    end

    test "asks every scored question exactly once" do
      asked = Deck.slides() |> Enum.map(& &1.activity) |> Enum.reject(&is_nil/1)

      assert length(asked) == length(Enum.uniq(asked))
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
end
