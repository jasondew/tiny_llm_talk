defmodule TinyLlmTalkWeb.Position do
  @moduledoc """
  Where the deck is, and what its controls are set to, shared between the
  room's window and the speaker's.

  Both views hold the same position and either can change it. A view that
  receives a broadcast it is already showing does nothing, which is what stops
  the two windows patching each other back and forth forever.

  Controls travel the same way. A slider dragged or a position clicked on the
  laptop shows up on the projector, so the speaker never has to reach for the
  big screen's mouse to run a demo.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [connected?: 1, push_patch: 2]

  alias TinyLlmTalk.Deck
  alias TinyLlmTalkWeb.SlideComponents

  @topic "deck:position"

  @spec subscribe(Phoenix.LiveView.Socket.t()) :: :ok
  def subscribe(socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(TinyLlmTalk.PubSub, @topic)
    :ok
  end

  @doc "Reads the position out of the URL params and tells the other window."
  @spec apply(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def apply(socket, params) do
    {index, step} = Deck.position(params["index"], params["step"], &SlideComponents.steps/1)

    broadcast({:position, index, step})

    assign(socket, slide: Deck.at(index), step: step)
  end

  @doc "Handles a keypress by patching to the URL it lands on."
  @spec move(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def move(socket, key) do
    current = {socket.assigns.slide.index, socket.assigns.step}

    case Deck.move(key, current, &SlideComponents.steps/1) do
      ^current -> socket
      {index, step} -> patch(socket, index, step)
    end
  end

  @doc "Handles the other window moving. Ignores a position we already hold."
  @spec follow(Phoenix.LiveView.Socket.t(), pos_integer(), pos_integer()) ::
          Phoenix.LiveView.Socket.t()
  def follow(socket, index, step) do
    if {socket.assigns.slide.index, socket.assigns.step} == {index, step} do
      socket
    else
      patch(socket, index, step)
    end
  end

  @doc "Sets one control and tells the other window."
  @spec control(Phoenix.LiveView.Socket.t(), String.t(), term()) :: Phoenix.LiveView.Socket.t()
  def control(socket, name, value) do
    controls = Map.put(socket.assigns.controls, name, value)

    broadcast({:controls, controls})

    assign(socket, controls: controls)
  end

  @doc "Handles the other window turning a control."
  @spec follow_controls(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def follow_controls(socket, controls), do: assign(socket, controls: controls)

  ## PRIVATE FUNCTIONS

  defp broadcast(message) do
    Phoenix.PubSub.broadcast_from(TinyLlmTalk.PubSub, self(), @topic, message)
  end

  defp patch(socket, index, step) do
    push_patch(socket, to: path(socket, index, step))
  end

  defp path(socket, index, step) do
    prefix = if presenter?(socket), do: "/presenter", else: "/s"
    "#{prefix}/#{index}/#{step}"
  end

  defp presenter?(socket), do: socket.view == TinyLlmTalkWeb.PresenterLive
end
