defmodule TinyLlmTalkWeb.Animation do
  @moduledoc """
  The frame counter behind any slide that moves on its own.

  A slide that animates says so in the deck (`ticks: true`), and while either
  window is on it, that window advances a frame on a timer. Both windows run
  their own clock: what a frame shows is a pure function of the frame number,
  so they agree without talking, and a dropped socket on one does not freeze
  the other.

  The frame resets whenever the slide changes, so walking back to an animated
  slide starts it from the top.
  """

  import Phoenix.Component, only: [assign: 2]

  alias TinyLlmTalkWeb.Controls

  @doc "Call after the position changes. Starts the clock if the slide needs one."
  @spec sync(Phoenix.LiveView.Socket.t(), pos_integer() | nil) :: Phoenix.LiveView.Socket.t()
  def sync(socket, previous_index) do
    socket =
      if socket.assigns.slide.index == previous_index,
        do: socket,
        else: assign(socket, frame: 0)

    if socket.assigns.slide.ticks and not socket.assigns.ticking do
      schedule(socket)
      assign(socket, ticking: true)
    else
      socket
    end
  end

  @doc "One tick. Advances the frame if the slide still wants one, else stops."
  @spec tick(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def tick(socket) do
    if socket.assigns.slide.ticks do
      schedule(socket)
      assign(socket, frame: socket.assigns.frame + 1)
    else
      assign(socket, ticking: false)
    end
  end

  ## PRIVATE FUNCTIONS

  defp schedule(socket) do
    Process.send_after(self(), :frame, Controls.pace(socket.assigns.controls))
  end
end
