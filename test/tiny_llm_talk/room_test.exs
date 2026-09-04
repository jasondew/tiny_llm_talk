defmodule TinyLlmTalk.RoomTest do
  use ExUnit.Case, async: false

  alias TinyLlmTalk.Room

  setup do
    Room.reset()
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

    test "names the majority, and the first option on a tie" do
      assert is_nil(Room.majority(Room.state(), :verb_vote))

      Room.vote(self(), "flee")
      assert Room.majority(Room.state(), :verb_vote) == "flee"

      Room.vote(spawn(fn -> Process.sleep(:infinity) end), "flees")
      assert Room.majority(Room.state(), :verb_vote) == "flees"
    end
  end

  describe "activities" do
    test "resolve the answers that come from the model" do
      assert Room.activity(:bigram_next).answer in Room.activity(:bigram_next).options
      assert Room.activity(:attention_bet).answer in Room.activity(:attention_bet).options

      lineup = Room.activity(:spot_the_human)
      assert length(lineup.options) == 3
      assert lineup.answer in lineup.options
    end

    test "leave a question with no right answer alone" do
      assert is_nil(Room.activity(:sentence).answer)
      assert is_nil(Room.activity(nil))
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

    test "is a no-op for the activity already open, so a reveal step keeps the votes" do
      Room.vote(self(), "flees")
      Room.reveal()
      Room.open(:verb_vote)

      assert Room.state().votes != %{}
      assert Room.state().revealed
    end
  end

  describe "revealing" do
    test "marks the open activity as answered, and opening another clears it" do
      Room.reveal()
      assert Room.state().revealed

      Room.open(:rematch)
      refute Room.state().revealed
    end

    test "does nothing when nothing is open" do
      Room.open(nil)
      Room.reveal()

      refute Room.state().revealed
    end
  end

  describe "the record" do
    test "remembers how the room did once it moves on" do
      Room.vote(self(), "flees")
      Room.open(:rematch)
      Room.vote(self(), "flees")
      Room.open(nil)

      assert [{:verb_vote, first}, {:rematch, second}] = Room.results(Room.state())
      assert first.correct?
      assert first.choice == "flees"
      refute second.correct?
      assert second.answer == "flee"
      assert Room.score(Room.state()) == %{right: 1, asked: 2}
    end

    test "keeps the latest attempt when a question is asked twice" do
      Room.vote(self(), "flee")
      Room.open(nil)
      Room.open(:verb_vote)
      Room.vote(self(), "flees")
      Room.open(nil)

      assert [{:verb_vote, result}] = Room.results(Room.state())
      assert result.correct?
    end

    test "records nothing for a question nobody answered" do
      Room.open(nil)

      assert Room.results(Room.state()) == []
      assert Room.score(Room.state()) == %{right: 0, asked: 0}
    end

    test "records nothing for an activity with no right answer" do
      Room.open(:sentence)
      Room.submit(self(), ~w(the llama flees))
      Room.open(nil)

      assert Room.results(Room.state()) == []
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
      assert Room.results(%Room{}) == []
    end
  end
end
