defmodule Mix.Tasks.Talk.Train do
  @moduledoc """
  Trains the two models the deck shows and writes their checkpoints.

      mix talk.train

  The transformer takes about a minute. The deck trains it again live, on the
  opening slide, with this same config and seed, and checks that the loss it
  lands on is the one on disk. Every later slide reads the checkpoint.

  Both runs are seeded, so re-running this reproduces the same weights, and
  therefore the same attention numbers the slides quote.
  """

  @shortdoc "Trains the models the deck shows and writes priv/checkpoints"

  use Mix.Task

  alias TinyLlm.{Embedder, Train}
  alias TinyLlmTalk.{Checkpoint, Trainer}

  @embedder %Train.Config{
    model: Embedder,
    batch_size: 64,
    steps: 1_000,
    log_every: 25,
    learning_rate: 0.5,
    learning_rate_schedule: :constant
  }

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    train(:embedder, @embedder)
    train(:transformer, Trainer.default_config())
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
