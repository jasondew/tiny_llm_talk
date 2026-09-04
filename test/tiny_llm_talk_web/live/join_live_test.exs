defmodule TinyLlmTalkWeb.JoinLiveTest do
  use TinyLlmTalkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TinyLlmTalk.Room

  setup do
    Room.reset()
    :ok
  end

  test "says nothing is happening yet when no activity is open", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/join")

    assert html =~ "You are in"
  end

  test "shows the open question and records a vote", %{conn: conn} do
    Room.open(:verb_vote)
    {:ok, view, _html} = live(conn, ~p"/join")

    assert render(view) =~ "flees, or flee?"

    view |> element("button[phx-value-choice='flees']") |> render_click()

    assert Room.tally(Room.state(), :verb_vote) == [{"flees", 1}, {"flee", 0}]
  end

  test "follows the deck to the next question without keeping the old answer", %{conn: conn} do
    Room.open(:verb_vote)
    {:ok, view, _html} = live(conn, ~p"/join")
    view |> element("button[phx-value-choice='flees']") |> render_click()

    Room.open(:attention_bet)

    assert render(view) =~ "look at hardest"
    refute render(view) =~ "join__option--chosen"
  end

  test "tells a phone it was right when the deck reveals the answer", %{conn: conn} do
    Room.open(:verb_vote)
    {:ok, view, _html} = live(conn, ~p"/join")
    view |> element("button[phx-value-choice='flees']") |> render_click()

    Room.reveal()

    assert render(view) =~ "You called it"
    assert render(view) =~ "join__option--answer"
  end

  test "tells a phone what the answer was when it was wrong, or silent", %{conn: conn} do
    Room.open(:verb_vote)
    {:ok, wrong, _html} = live(conn, ~p"/join")
    {:ok, silent, _html} = live(conn, ~p"/join")
    wrong |> element("button[phx-value-choice='flee']") |> render_click()

    Room.reveal()

    assert render(wrong) =~ "It was flees"
    assert render(wrong) =~ "join__verdict--wrong"
    assert render(silent) =~ "It was flees"
  end

  test "offers the lineup as sentences a thumb can tap", %{conn: conn} do
    Room.open(:spot_the_human)
    {:ok, _view, html} = live(conn, ~p"/join")

    for option <- Room.activity(:spot_the_human).options do
      assert html =~ option
    end
  end

  test "shows the room's record between questions", %{conn: conn} do
    Room.open(:verb_vote)
    Room.vote(self(), "flees")
    Room.open(nil)
    {:ok, _view, html} = live(conn, ~p"/join")

    assert html =~ "1 for 1"
  end

  test "builds a sentence a word at a time and sends it", %{conn: conn} do
    Room.open(:sentence)
    {:ok, view, _html} = live(conn, ~p"/join")

    view |> element("button[phx-value-word='the']") |> render_click()
    view |> element("button[phx-value-word='llama']") |> render_click()
    view |> element("button[phx-click='send']") |> render_click()

    assert [{~w(the llama), 1}] = Room.popular(Room.state(), 6)
  end

  test "will not send an empty sentence", %{conn: conn} do
    Room.open(:sentence)
    {:ok, view, _html} = live(conn, ~p"/join")

    render_click(view, "send", %{})

    assert Room.popular(Room.state(), 6) == []
  end

  test "offers only words the model has ever seen", %{conn: conn} do
    Room.open(:sentence)
    {:ok, _view, html} = live(conn, ~p"/join")

    offered =
      Regex.scan(~r/phx-value-word="([^"]+)"/, html)
      |> Enum.map(fn [_match, word] -> word end)

    assert offered != []
    assert Enum.all?(offered, &(&1 in TinyLlm.Vocab.words()))
  end
end
