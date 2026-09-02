defmodule TinyLlmTalkWeb.PresenterLive do
  @moduledoc """
  The laptop screen: notes, the slide the room is looking at, what comes next,
  and a clock.

  The outline budgets minutes per section, so the clock shows elapsed time
  against the budget spent so far. The only two questions asked mid-talk are
  "where am I" and "am I behind."
  """

  use TinyLlmTalkWeb, :live_view

  alias TinyLlmTalk.Deck
  alias TinyLlmTalk.{Room, Slide}
  alias TinyLlmTalkWeb.Position
  alias TinyLlmTalkWeb.SlideComponents

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(1_000, :tick)
    Position.subscribe(socket)
    if connected?(socket), do: Room.subscribe()

    {:ok, assign(socket, elapsed: 0, running?: true, controls: %{}, room: Room.state()),
     layout: false}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, socket |> Position.apply(params) |> assign_upcoming()}
  end

  @impl true
  def handle_event("key", %{"key" => "t"}, socket) do
    {:noreply, update(socket, :running?, &(not &1))}
  end

  def handle_event("key", %{"key" => "r"}, socket) do
    {:noreply, assign(socket, elapsed: 0)}
  end

  def handle_event("key", %{"key" => key}, socket) do
    {:noreply, Position.move(socket, key)}
  end

  @impl true
  def handle_info({:position, index, step}, socket) do
    {:noreply, socket |> Position.follow(index, step) |> assign_upcoming()}
  end

  def handle_info({:room, room}, socket), do: {:noreply, assign(socket, room: room)}

  def handle_info(:tick, %{assigns: %{running?: false}} = socket), do: {:noreply, socket}
  def handle_info(:tick, socket), do: {:noreply, update(socket, :elapsed, &(&1 + 1))}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="presenter" phx-window-keydown="key">
      <div class="presenter__now">
        <div class="stage-preview">
          <div class="stage stage--preview">
            <SlideComponents.slide slide={@slide} step={@step} controls={@controls} room={@room} />
          </div>
        </div>
        <div class="presenter__next">
          <p class="presenter__label">next</p>
          <p class="presenter__next-title">{@upcoming && @upcoming.title}</p>
        </div>
      </div>
      <div class="presenter__aside">
        <p class="presenter__clock">{format_clock(@elapsed)}</p>
        <p class="presenter__label">
          {@section.number}. {@section.title} &middot; {@section.minutes} min &middot; slide {@slide.index} of {Deck.count()} &middot; step {@step} of {@slide.steps}
        </p>
        <p class="presenter__lands">must land: {@section.lands}</p>
        <p class="presenter__notes">{Slide.prose(@slide)}</p>
        <p class="presenter__phones">
          {Room.participant_count(@room)} phones in the room
        </p>
        <p class="presenter__keys">
          space/arrows move &middot; t pauses the clock &middot; r resets it
        </p>
      </div>
    </div>
    """
  end

  ## PRIVATE FUNCTIONS

  defp assign_upcoming(socket) do
    index = socket.assigns.slide.index

    assign(socket,
      upcoming: if(index < Deck.count(), do: Deck.at(index + 1)),
      section: Deck.section(socket.assigns.slide)
    )
  end

  defp format_clock(seconds) do
    minutes = div(seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(rem(seconds, 60)), 2, "0")}"
  end
end
