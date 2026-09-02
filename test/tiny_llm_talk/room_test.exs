defmodule TinyLlmTalk.RoomTest do
  use ExUnit.Case, async: false

  alias TinyLlmTalk.Room

  setup do
    Room.open(nil)
    Room.open(:verb_vote)
    :ok
  end

  describe "voting" do
    test "counts a vote against the option it names" do
      Room.vote(self(), "flees")

      assert Room.tally(Room.state(), :verb_vote) == [{"flees", 1}, {"flee", 0}]
    end

    test "lets a phone change its mind without voting twice" do
      Room.vote(self(), "flees")
      Room.vote(self(), "flee")

      assert Room.tally(Room.state(), :verb_vote) == [{"flees", 0}, {"flee", 1}]
    end

    test "keeps the options in the order the activity lists them" do
      tally = Room.tally(Room.state(), :verb_vote)

      assert Enum.map(tally, &elem(&1, 0)) == ~w(flees flee)
    end

    test "ignores a choice the activity does not offer" do
      Room.vote(self(), "banana")

      assert Room.tally(Room.state(), :verb_vote) == [{"flees", 0}, {"flee", 0}]
    end

    test "ignores votes when nothing is open" do
      Room.open(nil)
      Room.vote(self(), "flees")

      assert Room.state().votes == %{}
    end
  end

  describe "opening an activity" do
    test "clears what the last one collected, so walking back asks again" do
      Room.vote(self(), "flees")
      Room.open(:attention_bet)

      assert Room.state().votes == %{}
      assert Room.state().activity == :attention_bet
    end

    test "clears the featured sentence" do
      Room.feature(~w(the llama flees))
      Room.open(:sentence)

      assert is_nil(Room.state().featured)
    end
  end

  describe "sentences" do
    test "ranks the most-submitted first" do
      Room.open(:sentence)
      other = spawn(fn -> Process.sleep(:infinity) end)

      Room.submit(self(), ~w(the llama flees))
      Room.submit(other, ~w(the llama flees))
      Room.submit(spawn(fn -> Process.sleep(:infinity) end), ~w(the dogs flee))

      assert [{~w(the llama flees), 2}, {~w(the dogs flee), 1}] = Room.popular(Room.state(), 6)
    end

    test "keeps only a phone's latest sentence" do
      Room.open(:sentence)
      Room.submit(self(), ~w(the llama flees))
      Room.submit(self(), ~w(the dogs flee))

      assert Room.popular(Room.state(), 6) == [{~w(the dogs flee), 1}]
    end
  end

  describe "participants" do
    test "counts a phone while it is connected and forgets it when it goes" do
      phone = spawn(fn -> Process.sleep(:infinity) end)
      Room.join(phone)

      assert Room.participant_count(Room.state()) >= 1

      before = Room.participant_count(Room.state())
      Process.exit(phone, :kill)
      # The room learns about the exit through a monitor, so wait for it to land.
      Process.sleep(50)

      assert Room.participant_count(Room.state()) == before - 1
    end
  end

  describe "an empty room" do
    test "still tallies, so a talk with no participants still has slides" do
      assert Room.tally(%Room{}, :verb_vote) == [{"flees", 0}, {"flee", 0}]
      assert Room.popular(%Room{}, 6) == []
      assert Room.participant_count(%Room{}) == 0
    end
  end
end
