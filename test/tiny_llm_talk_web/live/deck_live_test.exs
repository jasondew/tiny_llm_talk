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

  test "draws a transformer as one block, and says the frontier models are one", %{conn: conn} do
    slide = Enum.find(Deck.slides(), &(&1.id == :the_architecture))
    {:ok, _view, html} = live(conn, ~p"/s/#{slide.index}/#{slide.steps}")

    assert html =~ "stack__layer--attention"
    assert html =~ "stack__layer--mlp"
    assert length(Regex.scan(~r/class="stack__arrow"/, html)) == 5
    assert html =~ "frontier"
    assert html =~ "Gemini"
    assert html =~ "The one on this laptop"
    refute html =~ "A small MLP"
  end

  test "counts the parameters stage by stage, and says they are learned", %{conn: conn} do
    slide = Enum.find(Deck.slides(), &(&1.id == :parameters))
    {:ok, _view, html} = live(conn, ~p"/s/#{slide.index}")

    assert html =~ "15,104"
    assert html =~ "learned"
    assert html =~ "8,352"
    assert length(Regex.scan(~r/class="stack__count"/, html)) == 6
  end

  test "ends on the sources, with both repos and the paper", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/s/#{Deck.count()}")

    assert html =~ "Attention Is All You Need"
    assert html =~ "github.com/jasondew/tiny_llm_talk"
    assert html =~ Application.fetch_env!(:tiny_llm_talk, :repo_label)
  end

  test "shows the grammar's rules beside sentences it wrote", %{conn: conn} do
    slide = Enum.find(Deck.slides(), &(&1.id == :grammar))
    {:ok, _view, html} = live(conn, ~p"/s/#{slide.index}")

    assert html =~ "NounPhrase"
    assert html =~ ~s(&quot;who&quot;)
    assert html =~ TinyLlmTalk.Model.showcase_sentences() |> List.last() |> Enum.join(" ")
    refute html =~ "A subject agrees with its verb"
  end

  test "shows every one of the row's 32 floats, and no sentence under them", %{conn: conn} do
    slide = Enum.find(Deck.slides(), &(&1.id == :a_word_is_a_row))
    {:ok, _view, html} = live(conn, ~p"/s/#{slide.index}")

    assert length(Regex.scan(~r/class="floats__value"/, html)) == 32
    assert html =~ "probe--line"
    refute html =~ "Looked up from a table"
  end

  test "keeps the sentence over the position slide, and the prose off it", %{conn: conn} do
    slide = Enum.find(Deck.slides(), &(&1.id == :positions_added))
    {:ok, _view, html} = live(conn, ~p"/s/#{slide.index}/2")

    assert html =~ "probe--line"
    refute html =~ "Added, not appended"
  end

  test "labels the grid attention sees, centred on its slide", %{conn: conn} do
    slide = Enum.find(Deck.slides(), &(&1.id == :forgets_the_words))
    {:ok, _view, html} = live(conn, ~p"/s/#{slide.index}")

    assert html =~ ~r/<figure class="figure-centred">\s*<div[^>]*class="heatmap/
    assert html =~ "the input to attention"
  end

  test "keeps the one-function slide to the box and its distribution", %{conn: conn} do
    slide = Enum.find(Deck.slides(), &(&1.id == :one_function))
    {:ok, _view, html} = live(conn, ~p"/s/#{slide.index}")

    refute html =~ "Everything we build today"
  end

  test "puts the title after the vote", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/s/2")

    assert html =~ "Transformers from Scratch,"
    assert html =~ "in Elixir"
    assert html =~ "llama"
    assert is_nil(Room.state().activity)
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
      slide = Enum.find(Deck.slides(), &(&1.activity == :rematch))
      {:ok, _view, _html} = live(conn, ~p"/s/#{slide.index}")

      assert Room.state().activity == :rematch
    end

    test "closes it again on the way out", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.activity == :rematch))
      {:ok, view, _html} = live(conn, ~p"/s/#{slide.index}/#{slide.steps}")

      render_keydown(view, "key", %{"key" => "ArrowRight"})

      assert is_nil(Room.state().activity)
    end

    test "keeps the votes and reveals the answer on the second step", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.activity == :rematch))
      {:ok, view, _html} = live(conn, ~p"/s/#{slide.index}")
      Room.vote(self(), "flee")
      refute Room.state().revealed

      render_keydown(view, "key", %{"key" => "ArrowRight"})

      assert Room.state().activity == :rematch
      assert Room.state().revealed
      assert Room.tally(Room.state(), :rematch) == [{"flee", 1}, {"flees", 0}]
    end

    test "records the room's answer once the deck moves on", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.activity == :rematch))
      {:ok, view, _html} = live(conn, ~p"/s/#{slide.index}/#{slide.steps}")
      Room.vote(self(), "flee")

      render_keydown(view, "key", %{"key" => "ArrowRight"})

      assert [{:rematch, %{correct?: true}}] = Room.results(Room.state())
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

    test "says what temperature the writer samples at", %{conn: conn} do
      slide = Enum.find(Deck.slides(), &(&1.id == :it_writes))
      {:ok, _view, html} = live(conn, ~p"/s/#{slide.index}")

      assert html =~ "temperature 0.8"
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
