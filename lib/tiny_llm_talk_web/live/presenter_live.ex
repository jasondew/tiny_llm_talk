defmodule TinyLlmTalkWeb.PresenterLive do
  @moduledoc """
  The laptop screen: notes, the slide the room is looking at, what comes next,
  and a clock.

  The outline budgets minutes per section, so the clock shows elapsed time
  against the budget spent so far. The only two questions asked mid-talk are
  "where am I" and "am I behind."

  The preview is live. A control clicked in it is a control turned on the big
  screen, so every demo can be driven from the podium.
  """

  use TinyLlmTalkWeb, :live_view

  alias TinyLlmTalk.Deck
  alias TinyLlmTalk.{Slide, Trainer}
  alias TinyLlmTalkWeb.{Animation, Controls, Position}
  alias TinyLlmTalkWeb.SlideComponents

  @impl true
  def mount(_params, _session, socket) do
    Position.subscribe(socket)

    if connected?(socket) do
      :timer.send_interval(1_000, :tick)
      Trainer.subscribe()
    end

    {:ok,
     assign(socket,
       elapsed: 0,
       running?: true,
       controls: %{},
       trainer: Trainer.state(),
       frame: 0,
       ticking: false
     ), layout: false}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    previous = socket.assigns[:slide] && socket.assigns.slide.index

    {:noreply, socket |> Position.apply(params) |> assign_upcoming() |> Animation.sync(previous)}
  end

  @impl true
  def handle_event("key", %{"key" => "t"}, socket) do
    {:noreply, update(socket, :running?, &(not &1))}
  end

  def handle_event("key", %{"key" => "r"}, socket) do
    {:noreply, assign(socket, elapsed: 0)}
  end

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
    {:noreply, socket |> Position.follow(index, step) |> assign_upcoming()}
  end

  def handle_info({:controls, controls}, socket) do
    {:noreply, Position.follow_controls(socket, controls)}
  end

  def handle_info({:trainer, trainer}, socket), do: {:noreply, assign(socket, trainer: trainer)}

  def handle_info(:frame, socket), do: {:noreply, Animation.tick(socket)}

  def handle_info(:tick, %{assigns: %{running?: false}} = socket), do: {:noreply, socket}
  def handle_info(:tick, socket), do: {:noreply, update(socket, :elapsed, &(&1 + 1))}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="presenter" phx-window-keydown="key">
      <div class="presenter__now">
        <div class="stage-preview">
          <div class="stage stage--preview">
            <SlideComponents.slide
              slide={@slide}
              step={@step}
              controls={@controls}
              trainer={@trainer}
              frame={@frame}
            />
          </div>
        </div>
        <div class="presenter__next">
          <p class="presenter__label">next</p>
          <p class="presenter__next-title">{@upcoming && @upcoming.title}</p>
        </div>
      </div>
      <div class="presenter__aside">
        <p class="presenter__clock">
          {format_clock(@elapsed)} <span class="presenter__budget">of {budget(@section)}</span>
        </p>
        <p class="presenter__label">
          {@section.number}. {@section.title} &middot; {@section.minutes} min &middot; slide {@slide.index} of {Deck.count()} &middot; step {@step} of {@slide.steps}
        </p>
        <p class="presenter__lands">must land: {@section.lands}</p>
        <p class="presenter__notes">{Slide.prose(@slide)}</p>
        <p class="presenter__training">training {@trainer.status}</p>
        <p class="presenter__keys">
          space/arrows move &middot; t pauses the clock &middot; r resets it &middot; click the preview to run a demo
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

  # The minutes the outline says should have passed by the end of this section.
  defp budget(section) do
    Deck.sections()
    |> Enum.filter(&(&1.number <= section.number))
    |> Enum.map(& &1.minutes)
    |> Enum.sum()
    |> then(&"#{&1}:00")
  end

  defp format_clock(seconds) do
    minutes = div(seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(rem(seconds, 60)), 2, "0")}"
  end
end
