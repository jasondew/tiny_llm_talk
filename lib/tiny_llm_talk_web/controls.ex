defmodule TinyLlmTalkWeb.Controls do
  @moduledoc """
  The things a slide lets the speaker do besides advance it.

  Both the room's window and the speaker's render the same slides, so both
  receive the same clicks, and both delegate here. A control is a name and a
  value in the socket's `controls` map, shared over `TinyLlmTalkWeb.Position`
  so that turning it in one window turns it in the other.

  A few of these do work rather than just store a value: drawing the next
  word asks the model, featuring a sentence tells the room, and starting
  training tells the trainer. The rest are bookkeeping a slide reads back out.
  """

  alias TinyLlmTalk.{Model, Room, Trainer}
  alias TinyLlmTalkWeb.{Animation, Position}

  @events ~w(control next_word restart feature train retrain shuffle step_frame reset_vectors)

  # A sentence the room watches being written should not run off the slide.
  @longest_generation 12

  # Milliseconds a frame of an animated slide lasts, by pace. Seven frames a
  # word, so normal is about five seconds a word: slow enough to read the
  # picture. Realtime shows the model's own speed, a whole word per tick at a
  # rate a browser can paint; a zero-delay loop of full re-renders was enough
  # to take a browser down. Pause has no clock; the speaker advances a frame
  # at a time with the step button.
  @paces %{"slow" => 1_100, "normal" => 700, "realtime" => 80, "pause" => nil}
  @default_pace "normal"

  @doc "The events a slide may send, so both LiveViews can match on them."
  @spec events() :: [String.t()]
  def events, do: @events

  @spec handle(String.t(), map(), Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  # A button sends its choice under "choice", never "value": LiveView merges a
  # clicked button's own `value` attribute into the event, and a button with
  # none sends an empty string, which would silently overwrite the real one.
  def handle("control", %{"name" => "pace", "choice" => choice}, socket) do
    socket |> Position.control("pace", choice) |> Animation.resume()
  end

  def handle("control", %{"name" => name, "choice" => choice}, socket) do
    Position.control(socket, name, choice)
  end

  # A form (a range input) sends its fields, and there "value" is the input.
  def handle("control", %{"name" => name, "value" => value}, socket) do
    Position.control(socket, name, value)
  end

  def handle("next_word", _params, socket) do
    words = generated(socket.assigns.controls)

    if finished?(words) do
      socket
    else
      case Model.next(["<start>" | words], temperature(socket.assigns.controls)) do
        nil -> socket
        word -> Position.control(socket, "generated", words ++ [word])
      end
    end
  end

  def handle("restart", _params, socket), do: Position.control(socket, "generated", [])

  def handle("feature", %{"words" => words}, socket) do
    Room.feature(String.split(words, " "))

    socket
  end

  def handle("train", _params, socket) do
    Trainer.start()

    socket
  end

  def handle("retrain", _params, socket) do
    Trainer.restart()

    socket
  end

  # The dot product slide's two arrows back where they started.
  def handle("reset_vectors", _params, socket) do
    socket |> Position.control("vector_a", nil) |> Position.control("vector_b", nil)
  end

  # One frame forward, for the step pace.
  def handle("step_frame", _params, socket), do: Animation.step(socket)

  # A new paragraph for the writer, from the top, with the clock running again.
  def handle("shuffle", _params, socket) do
    socket
    |> Position.control("shuffles", shuffles(socket.assigns.controls) + 1)
    |> Animation.restart()
  end

  @doc "The words the room has watched the model write so far."
  @spec generated(map()) :: [String.t()]
  def generated(controls), do: Map.get(controls, "generated", [])

  @doc "Whether the sentence being written has ended, or run out of room."
  @spec finished?([String.t()]) :: boolean()
  def finished?(words), do: List.last(words) == "." or length(words) >= @longest_generation

  @doc "The temperature dial, which more than one slide reads."
  @spec temperature(map()) :: float()
  def temperature(controls), do: number(controls, "temperature", 1.0)

  @doc "How many times the writer has been asked for a new paragraph."
  @spec shuffles(map()) :: non_neg_integer()
  def shuffles(controls), do: controls |> number("shuffles", 0.0) |> round()

  @doc """
  Milliseconds per frame, from the pace control, or nil when the speaker is
  stepping by hand. Junk means normal.
  """
  @spec pace(map()) :: non_neg_integer() | nil
  def pace(controls) do
    Map.get(@paces, choice(controls, "pace", @default_pace), Map.fetch!(@paces, @default_pace))
  end

  @spec paces() :: [String.t()]
  def paces, do: ~w(slow normal realtime pause)

  @doc "Whether the writer is at realtime pace, a word a tick rather than a phase."
  @spec realtime?(map()) :: boolean()
  def realtime?(controls), do: choice(controls, "pace", @default_pace) == "realtime"

  @doc """
  A two-entry vector control, sent by the dragged graph as "x,y". Anything
  that does not parse as two numbers means the default.
  """
  @spec vector(map(), String.t(), [float()]) :: [float()]
  def vector(controls, name, default) do
    with value when is_binary(value) <- Map.get(controls, name),
         [x, y] <- String.split(value, ","),
         {x, ""} <- Float.parse(x),
         {y, ""} <- Float.parse(y) do
      [x, y]
    else
      _junk -> default
    end
  end

  @doc "A numeric control, with a default for before anyone has touched it."
  @spec number(map(), String.t(), float()) :: float()
  def number(controls, name, default) do
    case Map.get(controls, name) do
      nil -> default
      value when is_number(value) -> value * 1.0
      value -> value |> to_string() |> Float.parse() |> elem(0)
    end
  end

  @doc "A choice control, with a default for before anyone has clicked."
  @spec choice(map(), String.t(), String.t()) :: String.t()
  def choice(controls, name, default), do: Map.get(controls, name, default)
end
