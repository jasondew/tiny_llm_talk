defmodule TinyLlmTalkWeb.DeckLive do
  @moduledoc """
  The deck, as the room sees it.

  Position lives in the URL rather than in assigns, so a LiveView that crashes
  or a websocket that drops mid-talk comes back on the slide it was on. The
  presenter window drives this view and is driven by it, over one PubSub topic,
  which means either window can hold the clicker.
  """

  use TinyLlmTalkWeb, :live_view

  alias TinyLlmTalk.Trainer
  alias TinyLlmTalkWeb.{Animation, Controls, Position}
  alias TinyLlmTalkWeb.SlideComponents

  @impl true
  def mount(_params, _session, socket) do
    Position.subscribe(socket)

    if connected?(socket), do: Trainer.subscribe()

    {:ok,
     assign(socket,
       controls: %{},
       trainer: Trainer.state(),
       frame: 0,
       ticking: false
     ), layout: false}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    previous = socket.assigns[:slide] && socket.assigns.slide.index

    {:noreply,
     socket
     |> Position.apply(params)
     |> Animation.sync(previous)}
  end

  @impl true
  def handle_event("key", %{"key" => key} = params, socket) do
    {:noreply, Position.move(socket, key, params["shiftKey"] == true)}
  end

  def handle_event(event, params, socket) do
    if event in Controls.events() do
      {:noreply, Controls.handle(event, params, socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:position, index, step}, socket) do
    {:noreply, Position.follow(socket, index, step)}
  end

  def handle_info({:controls, controls}, socket) do
    {:noreply, Position.follow_controls(socket, controls)}
  end

  def handle_info({:trainer, trainer}, socket), do: {:noreply, assign(socket, trainer: trainer)}

  def handle_info(:frame, socket), do: {:noreply, Animation.tick(socket)}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="deck" phx-window-keydown="key">
      <div class="stage">
        <SlideComponents.slide
          slide={@slide}
          step={@step}
          controls={@controls}
          trainer={@trainer}
          frame={@frame}
        />
        <.footer slide={@slide} />
      </div>
    </div>
    """
  end
end
