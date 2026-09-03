defmodule TinyLlmTalkWeb.Animation do
  @moduledoc """
  The frame counter behind any slide that moves on its own.

  A slide that animates says so in the deck (`ticks: true`), and while either
  window is on it, that window advances a frame on a timer. Both windows run
  their own clock: what a frame shows is a pure function of the frame number,
  so they agree without talking, and a dropped socket on one does not freeze
  the other.

  The frame resets whenever the slide changes, so walking back to an animated
  slide starts it from the top. A slide that has finished stops its clock and
  holds the last frame; `restart/1` starts it over. With the pace set to step
  there is no clock at all, and `step/1` advances one frame per click.
  """

  import Phoenix.Component, only: [assign: 2]

  alias TinyLlmTalk.Writer
  alias TinyLlmTalkWeb.Controls

  @writers [:it_writes, :it_writes_again]

  @doc "Call after the position changes. Starts the clock if the slide needs one."
  @spec sync(Phoenix.LiveView.Socket.t(), pos_integer() | nil) :: Phoenix.LiveView.Socket.t()
  def sync(socket, previous_index) do
    socket =
      if socket.assigns.slide.index == previous_index,
        do: socket,
        else: assign(socket, frame: 0)

    resume(socket)
  end

  @doc "One tick. Advances the frame if the slide still wants one, else stops."
  @spec tick(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def tick(socket) do
    if manual?(socket) do
      assign(socket, ticking: false)
    else
      stride = Controls.stride(socket.assigns.controls)
      socket = assign(socket, frame: socket.assigns.frame + stride)

      if socket.assigns.slide.ticks and not finished?(socket) do
        schedule(socket)
        socket
      else
        assign(socket, ticking: false)
      end
    end
  end

  @doc "One frame forward by hand, whatever the clock is doing."
  @spec step(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def step(socket) do
    if finished?(socket), do: socket, else: assign(socket, frame: socket.assigns.frame + 1)
  end

  @doc "Starts the clock if the slide wants one, it is not already running, and the pace is not step."
  @spec resume(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def resume(socket) do
    wants_clock? =
      socket.assigns.slide.ticks and not socket.assigns.ticking and not manual?(socket) and
        not finished?(socket)

    if wants_clock? do
      schedule(socket)
      assign(socket, ticking: true)
    else
      socket
    end
  end

  @doc "Back to the first frame, with the clock running unless the pace is step."
  @spec restart(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def restart(socket), do: socket |> assign(frame: 0) |> resume()

  ## PRIVATE FUNCTIONS

  defp manual?(socket), do: is_nil(Controls.pace(socket.assigns.controls))

  # Only the writer knows when it is done. Any other animated slide runs
  # until the deck moves on.
  defp finished?(%{assigns: %{slide: %{id: id}, controls: controls, frame: frame}})
       when id in @writers do
    Writer.finished?(Writer.seed(Controls.shuffles(controls)), frame)
  end

  defp finished?(_socket), do: false

  defp schedule(socket) do
    Process.send_after(self(), :frame, Controls.pace(socket.assigns.controls))
  end
end
