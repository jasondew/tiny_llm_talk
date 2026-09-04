defmodule TinyLlmTalkWeb.DeckLive do
  @moduledoc """
  The deck, as the room sees it.

  Position lives in the URL rather than in assigns, so a LiveView that crashes
  or a websocket that drops mid-talk comes back on the slide it was on. The
  presenter window drives this view and is driven by it, over one PubSub topic,
  which means either window can hold the clicker.

  This is also the window that runs the room: arriving at a slide opens its
  activity, and reaching a slide's second step reveals the answer.
  """

  use TinyLlmTalkWeb, :live_view

  alias TinyLlmTalk.{Room, Trainer}
  alias TinyLlmTalkWeb.{Animation, Controls, Position}
  alias TinyLlmTalkWeb.SlideComponents

  @impl true
  def mount(_params, _session, socket) do
    Position.subscribe(socket)

    if connected?(socket) do
      Room.subscribe()
      Trainer.subscribe()
    end

    {:ok,
     assign(socket,
       controls: %{},
       room: Room.state(),
       trainer: Trainer.state(),
       activity: :none,
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
     |> sync_activity()
     |> sync_reveal()
     |> Animation.sync(previous)}
  end

  @impl true
  def handle_event("key", %{"key" => key}, socket) do
    {:noreply, Position.move(socket, key)}
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

  def handle_info({:room, room}, socket), do: {:noreply, assign(socket, room: room)}

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
          room={@room}
          trainer={@trainer}
          frame={@frame}
        />
        <.footer slide={@slide} />
      </div>
    </div>
    """
  end

  ## PRIVATE FUNCTIONS

  # Arriving at a slide opens its activity and leaving closes it, so there is no
  # second thing to remember while presenting. Comparing against what is already
  # open matters: `handle_params` also fires on every reveal step, and opening an
  # activity clears its votes.
  defp sync_activity(socket) do
    wanted = socket.assigns.slide.activity

    if socket.assigns.activity == wanted do
      socket
    else
      Room.open(wanted)

      assign(socket, activity: wanted)
    end
  end

  # A question's answer is on its second step, by convention across the deck.
  # The room does the revealing, so every phone hears about it.
  defp sync_reveal(%{assigns: %{slide: %{activity: nil}}} = socket), do: socket

  defp sync_reveal(%{assigns: %{slide: slide, step: step}} = socket) do
    if step >= 2 and not is_nil(Room.activity(slide.activity).answer), do: Room.reveal()

    socket
  end
end
