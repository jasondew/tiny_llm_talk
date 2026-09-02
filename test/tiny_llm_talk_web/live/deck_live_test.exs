defmodule TinyLlmTalkWeb.DeckLiveTest do
  use TinyLlmTalkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TinyLlmTalk.{Deck, Room}
  alias TinyLlmTalkWeb.SlideComponents

  setup do
    Room.reset()
    :ok
  end

  test "opens on the cold open", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "llama"
    assert html =~ Application.fetch_env!(:tiny_llm_talk, :repo_label)
  end

  test "puts the position in the address bar so a crash can recover it", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/s/1")

    render_keydown(view, "key", %{"key" => "ArrowRight"})

    assert_patched(view, "/s/2/1")
  end

  test "walks a slide's steps before moving on", %{conn: conn} do
    stepped = Enum.find(Deck.slides(), &(&1.steps > 1 and SlideComponents.drawn?(&1.id)))
    {:ok, view, _html} = live(conn, ~p"/s/#{stepped.index}")

    render_keydown(view, "key", %{"key" => "ArrowRight"})

    assert_patched(view, "/s/#{stepped.index}/2")
  end

  test "ignores a key that means nothing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/s/3")

    assert render_keydown(view, "key", %{"key" => "q"})
  end

  test "walks the whole deck, every step, without raising", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/s/1/1")
    steps = Deck.slides() |> Enum.map(&SlideComponents.steps(&1.index)) |> Enum.sum()

    for _press <- 2..steps do
      assert render_keydown(view, "key", %{"key" => "ArrowRight"}) =~ "deck-footer"
    end

    assert render(view) =~ "#{Deck.count()} / #{Deck.count()}"
  end

  describe "the audience activities" do
    test "opens a slide's activity on arrival", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.activity == :verb_vote))
      {:ok, _view, _html} = live(conn, ~p"/s/#{slide.index}")

      assert Room.state().activity == :verb_vote
    end

    test "closes it again on the way out", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.activity == :verb_vote))
      {:ok, view, _html} = live(conn, ~p"/s/#{slide.index}/#{slide.steps}")

      render_keydown(view, "key", %{"key" => "ArrowRight"})

      assert is_nil(Room.state().activity)
    end

    test "keeps the votes and reveals the answer on the second step", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.activity == :verb_vote))
      {:ok, view, _html} = live(conn, ~p"/s/#{slide.index}")
      Room.vote(self(), "flees")
      refute Room.state().revealed

      render_keydown(view, "key", %{"key" => "ArrowRight"})

      assert Room.state().activity == :verb_vote
      assert Room.state().revealed
      assert Room.tally(Room.state(), :verb_vote) == [{"flees", 1}, {"flee", 0}]
    end

    test "records the room's answer once the deck moves on", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.activity == :verb_vote))
      {:ok, view, _html} = live(conn, ~p"/s/#{slide.index}/#{slide.steps}")
      Room.vote(self(), "flees")

      render_keydown(view, "key", %{"key" => "ArrowRight"})

      assert [{:verb_vote, %{correct?: true}}] = Room.results(Room.state())
    end

    test "puts a submitted sentence on the screen when it is picked", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.activity == :sentence))
      {:ok, view, _html} = live(conn, ~p"/s/#{slide.index}")

      render_click(view, "feature", %{"words" => "the llama flees"})

      assert Room.state().featured == ~w(the llama flees)
      assert render(view) =~ "the llama flees"
    end
  end

  describe "the controls" do
    test "a control turned in the presenter view shows up in the room's", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.id == :walkthrough))
      {:ok, deck, _html} = live(conn, ~p"/s/#{slide.index}")
      {:ok, presenter, _html} = live(conn, ~p"/presenter/#{slide.index}")

      render_click(presenter, "control", %{"name" => "position", "value" => "2"})

      assert render(deck) =~ "walk__word--chosen"
      assert render(deck) =~ ~s(phx-value-value="2")
    end

    test "writes a sentence one word at a time and can start over", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.id == :one_word_at_a_time))
      {:ok, view, _html} = live(conn, ~p"/s/#{slide.index}")

      render_click(view, "next_word", %{})
      render_click(view, "next_word", %{})

      words = view |> render() |> written_words()
      assert length(words) in 1..2
      assert Enum.all?(words, &(&1 in TinyLlm.Vocab.words()))

      render_click(view, "restart", %{})

      assert view |> render() |> written_words() == []
    end
  end

  test "shows the speaker's notes and clock in the presenter view", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/presenter/1/1")

    assert html =~ "presenter__clock"
    assert html =~ "Cold open"
  end

  defp written_words(html) do
    ~r/class="written__word">([^<]+)</
    |> Regex.scan(html)
    |> Enum.map(fn [_match, word] -> String.trim(word) end)
  end
end
