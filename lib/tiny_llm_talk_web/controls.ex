defmodule TinyLlmTalkWeb.Controls do
  @moduledoc """
  The things a slide lets the speaker do besides advance it.

  Both the room's window and the speaker's render the same slides, so both
  receive the same clicks, and both delegate here. A control is a name and a
  value in the socket's `controls` map, shared over `TinyLlmTalkWeb.Position`
  so that turning it in one window turns it in the other.

  Two of these do work rather than just store a value: drawing the next word
  asks the model, and featuring a sentence tells the room. The rest are
  bookkeeping a slide reads back out.
  """

  alias TinyLlmTalk.{Model, Room}
  alias TinyLlmTalkWeb.Position

  @events ~w(control next_word restart feature)

  # A sentence the room watches being written should not run off the slide.
  @longest_generation 12

  @doc "The events a slide may send, so both LiveViews can match on them."
  @spec events() :: [String.t()]
  def events, do: @events

  @spec handle(String.t(), map(), Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
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

  @doc "The words the room has watched the model write so far."
  @spec generated(map()) :: [String.t()]
  def generated(controls), do: Map.get(controls, "generated", [])

  @doc "Whether the sentence being written has ended, or run out of room."
  @spec finished?([String.t()]) :: boolean()
  def finished?(words), do: List.last(words) == "." or length(words) >= @longest_generation

  @doc "The temperature dial, which more than one slide reads."
  @spec temperature(map()) :: float()
  def temperature(controls), do: number(controls, "temperature", 1.0)

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
