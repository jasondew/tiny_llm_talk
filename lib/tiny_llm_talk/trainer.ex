defmodule TinyLlmTalk.Trainer do
  @moduledoc """
  Training the transformer on stage, in the same BEAM as the deck.

  The run is the checkpoint's run: same config, same seed, same order of
  draws from `:rand`, which makes it the same numbers. That is the point of
  doing it live. The loss the room watches land is the loss every later
  slide was rehearsed on, and the slide says whether it matched.

  `TinyLlm.Train.run/1` is a reduce that returns at the end, so the loop is
  unrolled here to report each logged loss as it happens. Nothing about the
  arithmetic differs; the order of the seeded draws is preserved exactly,
  because swapping any two would change every number.

  The work runs in a task so the server keeps answering. One scheduler is
  busy for about a minute and the LiveViews do not notice.
  """

  use GenServer

  alias Phoenix.PubSub
  alias TinyLlm.{Grammar, Train}
  alias TinyLlmTalk.Model

  @topic "trainer"

  # Matching means the run reproduced the checkpoint's final loss to floating
  # point noise. Anything looser would be a different run that happened to
  # land nearby.
  @tolerance 1.0e-9

  # Batch 8 with cosine decay from 0.5 over 500 steps, which is what the talk
  # quotes its transformer numbers from. `mix talk.train` trains with this.
  @default_config %Train.Config{
    model: TinyLlm.Transformer,
    batch_size: 8,
    steps: 500,
    log_every: 10,
    learning_rate: 0.5,
    learning_rate_schedule: :cosine
  }

  defstruct status: :idle,
            config: nil,
            losses: [],
            step: 0,
            started_at: nil,
            seconds: nil,
            matches: nil,
            task: nil

  @type t :: %__MODULE__{}

  ## CLIENT

  def start_link(_options), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @spec subscribe() :: :ok
  def subscribe, do: PubSub.subscribe(TinyLlmTalk.PubSub, @topic)

  @doc """
  Starts the run, with the checkpoint's config unless told otherwise. Does
  nothing if a run is already going, so arriving at the slide twice cannot
  restart it under the speaker.
  """
  @spec start(Train.Config.t() | nil) :: :ok
  def start(config \\ nil), do: GenServer.cast(__MODULE__, {:start, config, false})

  @doc "Starts over, even mid-run. For rehearsal."
  @spec restart(Train.Config.t() | nil) :: :ok
  def restart(config \\ nil), do: GenServer.cast(__MODULE__, {:start, config, true})

  @spec state() :: t()
  def state, do: GenServer.call(__MODULE__, :state)

  @doc "What `mix talk.train` trains the transformer with."
  @spec default_config() :: Train.Config.t()
  def default_config, do: @default_config

  @doc "The config the checkpoint was trained with, or the default until there is one."
  @spec checkpoint_config() :: Train.Config.t()
  def checkpoint_config do
    case Model.checkpoint(:transformer) do
      %{config: config} -> config
      _none -> @default_config
    end
  end

  @doc "The loss so far, as `{step, loss}` pairs in order."
  @spec losses(t()) :: [{non_neg_integer(), float()}]
  def losses(%__MODULE__{losses: losses}), do: Enum.reverse(losses)

  ## SERVER

  @impl GenServer
  def init(:ok), do: {:ok, %__MODULE__{}}

  @impl GenServer
  def handle_call(:state, _from, state), do: {:reply, state, state}

  @impl GenServer
  def handle_cast({:start, _config, false}, %__MODULE__{status: :running} = state) do
    {:noreply, state}
  end

  def handle_cast({:start, config, _force}, state) do
    if state.task, do: Task.Supervisor.terminate_child(TinyLlmTalk.TaskSupervisor, state.task.pid)

    config = config || checkpoint_config()
    trainer = self()

    task =
      Task.Supervisor.async_nolink(TinyLlmTalk.TaskSupervisor, fn ->
        train(config, fn step, loss -> send(trainer, {:progress, step, loss}) end)
      end)

    {:noreply,
     announce(%__MODULE__{
       status: :running,
       config: config,
       started_at: System.monotonic_time(:millisecond),
       task: task
     })}
  end

  @impl GenServer
  def handle_info({:progress, step, loss}, state) do
    {:noreply, announce(%{state | step: step, losses: [{step, loss} | state.losses]})}
  end

  def handle_info({ref, _params}, %__MODULE__{task: %Task{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])
    seconds = (System.monotonic_time(:millisecond) - state.started_at) / 1_000

    {:noreply,
     announce(%{
       state
       | status: :done,
         task: nil,
         seconds: Float.round(seconds, 1),
         matches: matches?(state)
     })}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, announce(%{state | status: :idle, task: nil})}
  end

  def handle_info(_message, state), do: {:noreply, state}

  ## PRIVATE FUNCTIONS

  # `Train.run/1`, unrolled so each logged loss can be reported. The three
  # seeded draws happen in the same order: training corpus, evaluation
  # corpus, parameters. Then the same batches, in the same order.
  defp train(config, report) do
    Train.seed(config.seed)
    examples = config.training_corpus_size |> Grammar.corpus() |> config.model.examples()
    evaluation = config.evaluation_corpus_size |> Grammar.corpus() |> config.model.examples()
    params = config.model.init(config)

    Enum.reduce(0..config.steps, params, fn step, params ->
      batch = Train.batch(examples, config.batch_size)
      updated = Train.step(config.model, params, batch, Train.learning_rate(config, step))

      if rem(step, config.log_every) == 0 do
        report.(step, config.model.loss(updated, evaluation))
      end

      updated
    end)
  end

  # Only a run with the checkpoint's own config can be expected to match it.
  # Any other config gets no verdict rather than a false "does not match".
  defp matches?(%__MODULE__{config: config, losses: [{_step, final} | _rest]}) do
    case Model.checkpoint(:transformer) do
      %{config: ^config, losses: losses} ->
        {_step, expected} = List.last(losses)
        abs(final - expected) < @tolerance

      _other ->
        nil
    end
  end

  defp matches?(_state), do: nil

  defp announce(state) do
    PubSub.broadcast(TinyLlmTalk.PubSub, @topic, {:trainer, state})

    state
  end
end
