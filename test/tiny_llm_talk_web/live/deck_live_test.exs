defmodule TinyLlmTalkWeb.DeckLiveTest do
  use TinyLlmTalkWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TinyLlmTalk.Deck
  alias TinyLlmTalkWeb.SlideComponents

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

  test "shows the speaker's notes and clock in the presenter view", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/presenter/1/1")

    assert html =~ "presenter__clock"
    assert html =~ "Cold open"
  end
end
