defmodule TinyLlmTalk.DeckTest do
  use ExUnit.Case, async: true

  alias TinyLlmTalk.{Deck, Room}

  describe "the arc" do
    test "covers the nine sections of the outline, in order" do
      assert Enum.map(Deck.sections(), & &1.number) == Enum.to_list(0..8)
    end

    test "budgets the 41 minutes the outline budgets, leaving four for questions" do
      assert Deck.sections() |> Enum.map(& &1.minutes) |> Enum.sum() == 41
    end

    test "opens with the vote, so the room has something to do while it arrives" do
      assert %{id: :the_vote, activity: :verb_vote} = Deck.at(1)
      assert %{id: :title, activity: nil} = Deck.at(2)
    end

    test "motivates the architecture before anything is built, and ends on the sources" do
      assert %{id: :the_architecture, section: 0} = Deck.at(3)
      assert %{id: :parameters, section: 0} = Deck.at(4)
      assert %{id: :sources, section: 8} = Deck.at(Deck.count())
    end

    test "shows the writer once the setup is done, as the path taken fast" do
      assert index(:it_writes) == index(:one_function) + 1
    end

    test "teaches the two bits of math right where the fuzzy map first uses them" do
      assert Enum.slice(ids(), index(:map_get) - 1, 4) ==
               [:map_get, :dot_product, :softmax_playground, :fuzzy_map]
    end

    test "trains live inside the training section, not under the introduction" do
      training = Deck.at(index(:live_training))

      assert Deck.section(training).title =~ "Training"
      assert Deck.at(index(:live_training) + 1).id == :training
    end

    test "says the seven lines and the no-deps claim without their own slides" do
      refute :all_of_it in ids()
      refute :from_nothing in ids()
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

  defp ids, do: Enum.map(Deck.slides(), & &1.id)

  defp index(id), do: Enum.find(Deck.slides(), &(&1.id == id)).index

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
