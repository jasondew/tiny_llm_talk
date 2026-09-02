defmodule TinyLlmTalkWeb.Router do
  use TinyLlmTalkWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TinyLlmTalkWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TinyLlmTalkWeb do
    pipe_through :browser

    live "/", DeckLive
    live "/s/:index", DeckLive
    live "/s/:index/:step", DeckLive

    live "/join", JoinLive

    live "/presenter", PresenterLive
    live "/presenter/:index", PresenterLive
    live "/presenter/:index/:step", PresenterLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", TinyLlmTalkWeb do
  #   pipe_through :api
  # end
end
