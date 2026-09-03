defmodule TinyLlmTalk.TrainerTest do
  use ExUnit.Case, async: false

  alias TinyLlm.{Train, Transformer}
  alias TinyLlmTalk.Trainer

  # Small enough to finish in well under a second, and nothing like the
  # checkpoint's config, so no verdict about matching it is possible.
  @tiny %Train.Config{
    model: Transformer,
    d_model: 8,
    batch_size: 4,
    steps: 3,
    log_every: 1,
    training_corpus_size: 40,
    evaluation_corpus_size: 10,
    seed: 7
  }

  setup do
    Trainer.subscribe()
    :ok
  end

  test "reports each logged loss as it happens and then finishes" do
    Trainer.restart(@tiny)

    assert_receive {:trainer, %Trainer{status: :running}}, 1_000
    assert_receive {:trainer, %Trainer{status: :done} = done}, 10_000

    assert Enum.map(Trainer.losses(done), &elem(&1, 0)) == [0, 1, 2, 3]
    assert is_float(done.seconds)
  end

  test "reproduces what Train.run/1 would have produced, step for step" do
    Trainer.restart(@tiny)
    assert_receive {:trainer, %Trainer{status: :done} = done}, 10_000

    assert Trainer.losses(done) == Train.run(@tiny).losses
  end

  test "has no verdict about the checkpoint for a run with a different config" do
    Trainer.restart(@tiny)
    assert_receive {:trainer, %Trainer{status: :done} = done}, 10_000

    assert is_nil(done.matches)
  end

  test "will not start over while a run is going, unless told to" do
    Trainer.restart(@tiny)
    assert_receive {:trainer, %Trainer{status: :running, started_at: started}}, 1_000

    Trainer.start(@tiny)
    assert Trainer.state().started_at == started

    assert_receive {:trainer, %Trainer{status: :done}}, 10_000
  end

  test "knows the config the checkpoint was trained with" do
    config = Trainer.checkpoint_config()

    assert config.model == Transformer
    assert config.steps > 0
  end
end
