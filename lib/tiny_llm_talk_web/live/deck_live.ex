defmodule TinyLlmTalkWeb.DeckLive do
  @moduledoc """
  The deck, as the room sees it.

  Position lives in the URL rather than in assigns, so a LiveView that crashes
  or a websocket that drops mid-talk comes back on the slide it was on. The
  presenter window drives this view and is driven by it, over one PubSub topic,
  which means either window can hold the clicker.
  """

  use TinyLlmTalkWeb, :live_view

  alias TinyLlmTalkWeb.Position
  alias TinyLlmTalkWeb.SlideComponents

  @impl true
  def mount(_params, _session, socket) do
    Position.subscribe(socket)
    {:ok, socket, layout: false}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, Position.apply(socket, params)}
  end

  @impl true
  def handle_event("key", %{"key" => key}, socket) do
    {:noreply, Position.move(socket, key)}
  end

  @impl true
  def handle_info({:position, index, step}, socket) do
    {:noreply, Position.follow(socket, index, step)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="deck" phx-window-keydown="key">
      <div class="stage">
        <SlideComponents.slide slide={@slide} step={@step} />
        <.footer slide={@slide} />
      </div>
    </div>
    """
  end
end
