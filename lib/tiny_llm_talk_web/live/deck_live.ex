defmodule TinyLlmTalkWeb.DeckLive do
  @moduledoc """
  The deck, as the room sees it.

  Position lives in the URL rather than in assigns, so a LiveView that crashes
  or a websocket that drops mid-talk comes back on the slide it was on. The
  presenter window drives this view and is driven by it, over one PubSub topic,
  which means either window can hold the clicker.
  """

  use TinyLlmTalkWeb, :live_view

  alias TinyLlmTalk.Room
  alias TinyLlmTalkWeb.Position
  alias TinyLlmTalkWeb.SlideComponents

  @impl true
  def mount(_params, _session, socket) do
    Position.subscribe(socket)
    if connected?(socket), do: Room.subscribe()

    {:ok, assign(socket, controls: %{}, room: Room.state(), activity: :none), layout: false}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, socket |> Position.apply(params) |> sync_activity()}
  end

  @impl true
  def handle_event("key", %{"key" => key}, socket) do
    {:noreply, Position.move(socket, key)}
  end

  # The one thing a slide can hold that a picture cannot: a control the room
  # watches you turn, with the model answering in the same BEAM.
  def handle_event("control", %{"name" => name, "value" => value}, socket) do
    {:noreply, update(socket, :controls, &Map.put(&1, name, value))}
  end

  # Putting one of the audience's sentences on the big screen.
  def handle_event("feature", %{"words" => words}, socket) do
    Room.feature(String.split(words, " "))

    {:noreply, socket}
  end

  @impl true
  def handle_info({:position, index, step}, socket) do
    {:noreply, Position.follow(socket, index, step)}
  end

  def handle_info({:room, room}, socket), do: {:noreply, assign(socket, room: room)}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="deck" phx-window-keydown="key">
      <div class="stage">
        <SlideComponents.slide slide={@slide} step={@step} controls={@controls} room={@room} />
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
end
