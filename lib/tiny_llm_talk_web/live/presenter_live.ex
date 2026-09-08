defmodule TinyLlmTalkWeb.PresenterLive do
  @moduledoc """
  The laptop screen: the clock, the section and what it must land across the
  top; the slide the room is looking at, as wide as the screen allows; under
  it the notes on the left and what comes next on the right. The notes are
  only what has to be said out loud, and the points that must be made are
  drawn louder.

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
      <div class="presenter__head">
        <div class="presenter__where">
          <p class="presenter__label">
            {@section.number}. {@section.title} &middot; {@section.minutes} min &middot; slide {@slide.index} of {Deck.count()} &middot; step {@step} of {@slide.steps}
          </p>
          <p class="presenter__keys">
            training {@trainer.status} &middot; space/arrows move &middot; t pauses &middot; r resets &middot; click a preview to drive it
          </p>
        </div>
        <p class="presenter__clock">
          {format_clock(@elapsed)} <span class="presenter__budget">of {budget(@section)}</span>
        </p>
      </div>
      <p class="presenter__lands">{@section.lands}</p>
      <div class="presenter__current">
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
      </div>
      <div class="presenter__bottom">
        <div class="presenter__notes">
          <%= for block <- Slide.blocks(@slide) do %>
            <ul :if={elem(block, 0) == :bullets} class="presenter__bullets">
              <li :for={item <- elem(block, 1)}>{item}</li>
            </ul>
            <ul :if={elem(block, 0) == :musts} class="presenter__musts">
              <li :for={item <- elem(block, 1)}>{item}</li>
            </ul>
            <dl :if={elem(block, 0) == :definitions} class="presenter__defs">
              <%= for {term, text} <- elem(block, 1) do %>
                <dt>{term}</dt>
                <dd>{text}</dd>
              <% end %>
            </dl>
          <% end %>
        </div>
        <div :if={@next} class="presenter__next">
          <p class="presenter__label">
            next: {next_label(@slide, @step, @next)}
          </p>
          <div class="stage-preview stage-preview--next">
            <div class="stage stage--preview stage--preview-next">
              <SlideComponents.slide
                slide={elem(@next, 0)}
                step={elem(@next, 1)}
                controls={@controls}
                trainer={@trainer}
                frame={0}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  ## PRIVATE FUNCTIONS

  # What the next press of the right arrow shows: the next step of this
  # slide, or the first step of the next one, or nothing at the end.
  defp assign_upcoming(socket) do
    here = {socket.assigns.slide.index, socket.assigns.step}

    next =
      case Deck.move("ArrowRight", here, &SlideComponents.steps/1) do
        ^here -> nil
        {index, step} -> {Deck.at(index), step}
      end

    assign(socket, next: next, section: Deck.section(socket.assigns.slide))
  end

  defp next_label(slide, _step, {next_slide, next_step}) when next_slide.index == slide.index,
    do: "step #{next_step} of #{slide.steps}"

  defp next_label(_slide, _step, {next_slide, _next_step}), do: next_slide.title

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
