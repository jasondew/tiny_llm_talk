defmodule Mix.Tasks.Talk.Train do
  @moduledoc """
  Trains the two models the deck shows and writes their checkpoints.

      mix talk.train

  The transformer takes about half a minute. That is a fine beat once, in
  section 3, where the point is watching a loss fall; it is dead air the second
  time, so section 4 onwards reads the numbers off disk instead.

  Both runs are seeded, so re-running this reproduces the same weights, and
  therefore the same attention numbers the slides quote.
  """

  @shortdoc "Trains the models the deck shows and writes priv/checkpoints"

  use Mix.Task

  alias TinyLlm.{Embedder, Train, Transformer}
  alias TinyLlmTalk.Checkpoint

  @embedder %Train.Config{
    model: Embedder,
    batch_size: 64,
    steps: 1_000,
    log_every: 25,
    learning_rate: 0.5,
    learning_rate_schedule: :constant
  }

  # Batch 8 with cosine decay from 0.5 over 500 steps, which is what the talk
  # quotes its transformer numbers from.
  @transformer %Train.Config{
    model: Transformer,
    batch_size: 8,
    steps: 500,
    log_every: 10,
    learning_rate: 0.5,
    learning_rate_schedule: :cosine
  }

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    train(:embedder, @embedder)
    train(:transformer, @transformer)
  end

  ## PRIVATE FUNCTIONS

  defp train(name, config) do
    Mix.shell().info("training #{name} (#{config.steps} steps, batch #{config.batch_size}) ...")

    {microseconds, result} = :timer.tc(fn -> Train.run(config) end)
    {_step, final_loss} = List.last(result.losses)

    Checkpoint.write(name, %{
      params: result.params,
      losses: result.losses,
      config: config,
      seconds: Float.round(microseconds / 1_000_000, 1)
    })

    Mix.shell().info(
      "  #{name}: loss #{Float.round(final_loss, 4)} " <>
        "in #{Float.round(microseconds / 1_000_000, 1)}s -> #{Checkpoint.path(name)}"
    )
  end
end
