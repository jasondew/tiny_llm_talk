defmodule TinyLlmTalkWeb.JoinLiveTest do
  use TinyLlmTalkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TinyLlmTalk.Room

  setup do
    Room.open(nil)
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
