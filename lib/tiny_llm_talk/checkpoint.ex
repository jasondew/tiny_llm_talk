defmodule TinyLlmTalk.Checkpoint do
  @moduledoc """
  Trained parameters on disk, so the talk does not spend 27 seconds of stage
  time watching a loss curve it has already seen.

  There is no serialization layer beyond `:erlang.term_to_binary/1`. The deck
  runs in the same BEAM as the model, so what comes back out is the same map of
  lists of floats that went in.

  Written by `mix talk.train` and committed, because every number on a slide has
  to reproduce from a seed, and "re-train it and hope" is not reproducing.
  """

  @directory "priv/checkpoints"

  @type name :: :transformer | :embedder

  @doc "Where a checkpoint lives, relative to the app."
  @spec path(name()) :: String.t()
  def path(name), do: Path.join(app_directory(), "#{name}.bin")

  @spec exists?(name()) :: boolean()
  def exists?(name), do: File.exists?(path(name))

  @doc "Reads a checkpoint, or `nil` if `mix talk.train` has not been run."
  @spec read(name()) :: map() | nil
  def read(name) do
    case File.read(path(name)) do
      {:ok, binary} -> :erlang.binary_to_term(binary)
      {:error, _reason} -> nil
    end
  end

  @spec write(name(), map()) :: :ok
  def write(name, contents) do
    File.mkdir_p!(app_directory())
    File.write!(path(name), :erlang.term_to_binary(contents))
  end

  ## PRIVATE FUNCTIONS

  # `Application.app_dir/2` points into _build, which is where the running
  # system reads from, but `mix talk.train` has to write into the source tree.
  defp app_directory do
    if function_exported?(Mix, :env, 0) and Mix.env() != :prod do
      @directory
    else
      Application.app_dir(:tiny_llm_talk, @directory)
    end
  end
end
