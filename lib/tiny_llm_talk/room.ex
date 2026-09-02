defmodule TinyLlmTalk.Room do
  @moduledoc """
  What the audience is doing right now.

  One activity is open at a time, and which one is decided by the slide on
  screen: arriving at a slide opens its activity, leaving closes it. That way
  there is no second thing to remember while presenting, and walking backwards
  through the deck re-opens what was there before.

  Everything is in memory and nothing outlives the talk. Votes are keyed by the
  phone that cast them so a person can change their mind and cannot vote twice,
  and each phone is monitored so the participant count falls when someone closes
  the tab.

  The room is allowed to be empty. Every figure that reads it renders correctly
  with no participants at all, because a talk where the wifi failed still has to
  be a talk.
  """

  use GenServer

  alias Phoenix.PubSub

  @topic "room"

  @activities %{
    verb_vote: %{
      question: "flees, or flee?",
      hint: "the llama who chases the dogs ___",
      options: ~w(flees flee)
    },
    attention_bet: %{
      question: "Which word will the blank look at hardest?",
      hint: "before we look at what it actually did",
      options: ~w(llama dogs who chases)
    },
    sentence: %{
      question: "Build a sentence",
      hint: "tap words, then send it up",
      options: []
    }
  }

  defstruct activity: nil, votes: %{}, submissions: %{}, featured: nil, participants: %{}

  @type t :: %__MODULE__{}

  ## CLIENT

  def start_link(_options), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Every activity the deck knows how to run."
  @spec activities() :: map()
  def activities, do: @activities

  @spec activity(atom()) :: map() | nil
  def activity(name), do: Map.get(@activities, name)

  @spec subscribe() :: :ok
  def subscribe, do: PubSub.subscribe(TinyLlmTalk.PubSub, @topic)

  @doc "Opens an activity, or closes whatever is open when given `nil`."
  @spec open(atom() | nil) :: :ok
  def open(name), do: GenServer.cast(__MODULE__, {:open, name})

  @doc "Registers a phone. The caller is monitored, so closing the tab is a leave."
  @spec join(pid()) :: t()
  def join(pid), do: GenServer.call(__MODULE__, {:join, pid})

  @spec vote(pid(), String.t()) :: :ok
  def vote(pid, choice), do: GenServer.cast(__MODULE__, {:vote, pid, choice})

  @spec submit(pid(), [String.t()]) :: :ok
  def submit(pid, words), do: GenServer.cast(__MODULE__, {:submit, pid, words})

  @doc "Picks one submitted sentence to put on the big screen."
  @spec feature([String.t()]) :: :ok
  def feature(words), do: GenServer.cast(__MODULE__, {:feature, words})

  @spec state() :: t()
  def state, do: GenServer.call(__MODULE__, :state)

  @doc """
  The vote so far, as `{option, count}` in the order the activity lists them, so
  a bar chart cannot reorder itself under the audience while they watch.
  """
  @spec tally(t(), atom()) :: [{String.t(), non_neg_integer()}]
  def tally(%__MODULE__{votes: votes}, name) do
    counts = Enum.frequencies(Map.values(votes))

    @activities
    |> Map.fetch!(name)
    |> Map.fetch!(:options)
    |> Enum.map(fn option -> {option, Map.get(counts, option, 0)} end)
  end

  @doc "Distinct submitted sentences, most-submitted first."
  @spec popular(t(), pos_integer()) :: [{[String.t()], pos_integer()}]
  def popular(%__MODULE__{submissions: submissions}, count) do
    submissions
    |> Map.values()
    |> Enum.frequencies()
    |> Enum.sort_by(fn {words, times} -> {-times, length(words)} end)
    |> Enum.take(count)
  end

  @spec participant_count(t()) :: non_neg_integer()
  def participant_count(%__MODULE__{participants: participants}), do: map_size(participants)

  ## SERVER

  @impl GenServer
  def init(:ok), do: {:ok, %__MODULE__{}}

  @impl GenServer
  def handle_call({:join, pid}, _from, room) do
    Process.monitor(pid)

    {:reply, room, put_in(room.participants[pid], true) |> announce()}
  end

  def handle_call(:state, _from, room), do: {:reply, room, room}

  @impl GenServer
  def handle_cast({:open, name}, room) do
    # Opening an activity clears what the last one collected. Walking back to a
    # slide should ask the question again, not show a stale answer.
    {:noreply, announce(%{room | activity: name, votes: %{}, submissions: %{}, featured: nil})}
  end

  def handle_cast({:vote, _pid, _choice}, %__MODULE__{activity: nil} = room),
    do: {:noreply, room}

  def handle_cast({:vote, pid, choice}, room) do
    if choice in options(room.activity) do
      {:noreply, announce(put_in(room.votes[pid], choice))}
    else
      {:noreply, room}
    end
  end

  def handle_cast({:submit, pid, words}, room) do
    {:noreply, announce(put_in(room.submissions[pid], words))}
  end

  def handle_cast({:feature, words}, room) do
    {:noreply, announce(%{room | featured: words})}
  end

  @impl GenServer
  def handle_info({:DOWN, _reference, :process, pid, _reason}, room) do
    {:noreply,
     room
     |> Map.update!(:participants, &Map.delete(&1, pid))
     |> Map.update!(:votes, &Map.delete(&1, pid))
     |> announce()}
  end

  ## PRIVATE FUNCTIONS

  defp options(nil), do: []
  defp options(name), do: @activities |> Map.fetch!(name) |> Map.fetch!(:options)

  defp announce(room) do
    PubSub.broadcast(TinyLlmTalk.PubSub, @topic, {:room, room})

    room
  end
end
