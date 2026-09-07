defmodule TinyLlmTalkWeb.DeckLiveTest do
  use TinyLlmTalkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TinyLlmTalk.{Deck, Room}
  alias TinyLlmTalkWeb.SlideComponents

  setup do
    Room.reset()
    :ok
  end

  test "opens on the vote, with the question already open for the room", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "llama"
    assert html =~ "join at"
    assert html =~ Application.fetch_env!(:tiny_llm_talk, :repo_label)
    assert Room.state().activity == :verb_vote
  end

  test "moves the opening vote's bars as the room votes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    refute render(view) =~ "1 vote"

    Room.vote(self(), "flees")
    assert Room.state().votes == %{self() => "flees"}

    assert render(view) =~ "1 vote"
  end

  test "reveals the opening vote's answer on its second step", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    Room.vote(self(), "flees")
    refute render(view) =~ "tally__row--answer"

    render_keydown(view, "key", %{"key" => "ArrowRight"})

    assert Room.state().revealed
    assert render(view) =~ "tally__row--answer"
  end

  test "puts the position in the address bar so a crash can recover it", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/s/2")

    render_keydown(view, "key", %{"key" => "ArrowRight"})

    assert_patched(view, "/s/3/1")
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
      slide = Enum.find(Deck.slides(), &(&1.activity == :attention_bet))
      {:ok, _view, _html} = live(conn, ~p"/s/#{slide.index}")

      assert Room.state().activity == :attention_bet
    end

    test "closes it again on the way out", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.activity == :attention_bet))
      {:ok, view, _html} = live(conn, ~p"/s/#{slide.index}/#{slide.steps}")

      render_keydown(view, "key", %{"key" => "ArrowRight"})

      assert is_nil(Room.state().activity)
    end

    test "keeps the votes and reveals the answer on the second step", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.activity == :attention_bet))
      {:ok, view, _html} = live(conn, ~p"/s/#{slide.index}")
      Room.vote(self(), "who")
      refute Room.state().revealed

      render_keydown(view, "key", %{"key" => "ArrowRight"})

      assert Room.state().activity == :attention_bet
      assert Room.state().revealed
      assert {"who", 1} in Room.tally(Room.state(), :attention_bet)
    end

    test "records the room's answer once the deck moves on", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.activity == :attention_bet))
      {:ok, view, _html} = live(conn, ~p"/s/#{slide.index}/#{slide.steps}")
      Room.vote(self(), "who")

      render_keydown(view, "key", %{"key" => "ArrowRight"})

      assert [{:attention_bet, %{correct?: true}}] = Room.results(Room.state())
    end
  end

  describe "the controls" do
    test "a control turned in the presenter view shows up in the room's", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.id == :walkthrough))
      {:ok, deck, _html} = live(conn, ~p"/s/#{slide.index}")
      {:ok, presenter, _html} = live(conn, ~p"/presenter/#{slide.index}")

      render_click(presenter, "control", %{"name" => "position", "choice" => "2"})

      assert render(deck) =~ "walk__word--chosen"
      assert render(deck) =~ ~s(phx-value-choice="2")
    end

    test "a button click carries the browser's empty value without clobbering the choice",
         %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.id == :it_writes))
      {:ok, view, _html} = live(conn, ~p"/s/#{slide.index}")

      view |> element("button[phx-value-choice='slow']") |> render_click()

      assert render(view) =~ ~s(picker__option picker__option--chosen">slow)
    end

    test "moves the dot product's arrows, and puts them back", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.id == :dot_product))
      {:ok, view, _html} = live(conn, ~p"/s/#{slide.index}/3")

      render_click(view, "control", %{"name" => "vector_a", "value" => "2.0,-1.5"})

      html = render(view)
      assert html =~ "−1.50"
      # a = [2, -1.5], b = [1, 4]: 2 - 6
      assert html =~ "a · b = −4.00"

      render_click(view, "reset_vectors", %{})

      assert render(view) =~ "a · b = 7.00"
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

  describe "an animated slide" do
    test "advances a frame on its own clock and shows a different phase", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.id == :it_writes))
      {:ok, view, _html} = live(conn, ~p"/s/#{slide.index}")
      before = render(view)

      send(view.pid, :frame)

      assert render(view) != before
      assert live_stage(render(view)) =~ "2. rows"

      send(view.pid, :frame)
      send(view.pid, :frame)

      assert live_stage(render(view)) =~ "4. attention"
    end

    test "keeps ticking on its own clock, and stops when the slide changes", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.id == :it_writes))
      {:ok, view, _html} = live(conn, ~p"/s/#{slide.index}")

      # Normal pace is 700ms a frame, so 2.3 seconds is at least three frames.
      Process.sleep(2_300)
      assert live_stage(render(view)) =~ ~r/[3-7]\./

      render_keydown(view, "key", %{"key" => "ArrowRight"})
      Process.sleep(600)

      refute render(view) =~ "writer__stage--live"
      assert render(view) =~ Deck.at(slide.index + 1).title
    end

    test "steps a frame at a time by hand while paused", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.id == :it_writes))
      {:ok, view, _html} = live(conn, ~p"/s/#{slide.index}")

      view |> element("button[phx-value-choice='pause']") |> render_click()
      # Whatever frame the clock reached, from here on only clicks move it.
      Process.sleep(800)
      before = live_stage(render(view))
      Process.sleep(800)
      assert live_stage(render(view)) == before

      view |> element("button[phx-click='step_frame']") |> render_click()

      assert live_stage(render(view)) != before
    end

    test "lands on every word's pick in realtime, whatever phase it was on", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.id == :it_writes))
      {:ok, view, _html} = live(conn, ~p"/s/#{slide.index}")
      send(view.pid, :frame)
      send(view.pid, :frame)
      assert live_stage(render(view)) =~ "3."

      view |> element("button[phx-value-choice='realtime']") |> render_click()

      for _tick <- 1..3 do
        send(view.pid, :frame)
        assert live_stage(render(view)) =~ "6."
      end

      for _tick <- 1..60, do: send(view.pid, :frame)

      assert render(view) =~ "the paragraph is finished"
      assert render(view) =~ ~r/writer__chip--lit[^>]*>\s*<span class="writer__chip-word">\.</
    end

    test "starts over with a new paragraph on shuffle", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.id == :it_writes))
      {:ok, view, _html} = live(conn, ~p"/s/#{slide.index}")
      send(view.pid, :frame)
      send(view.pid, :frame)

      render_click(view, "shuffle", %{})

      assert render(view) =~ "1. words become integers"
    end

    # The trainer is shared, and another test may have run it, so this checks
    # the slide reads whatever state it is in rather than that it is idle.
    test "draws the training slide from the trainer's state", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.id == :live_training))
      {:ok, _view, html} = live(conn, ~p"/s/#{slide.index}")

      assert html =~ "Training, live"
      assert html =~ "seed"
      assert html =~ ~r/phx-click="(train|retrain)"/
      refute html =~ "press start"
    end
  end

  test "shows the speaker's notes and clock in the presenter view", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/presenter/1/1")

    assert html =~ "presenter__clock"
    assert html =~ "Cold open"
  end

  # The label of the writer's stage that is lit right now.
  defp live_stage(html) do
    case Regex.run(~r/writer__stage--live[^>]*>\s*<p class="writer__label">([^<]+)</, html) do
      [_match, label] -> label
      nil -> ""
    end
  end

  defp written_words(html) do
    ~r/class="written__word">([^<]+)</
    |> Regex.scan(html)
    |> Enum.map(fn [_match, word] -> String.trim(word) end)
  end
end
