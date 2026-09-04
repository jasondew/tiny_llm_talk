defmodule TinyLlmTalk.Room do
  @moduledoc """
  What the audience is doing right now, and how they have done so far.

  One activity is open at a time, and which one is decided by the slide on
  screen: arriving at a slide opens its activity, leaving closes it. That way
  there is no second thing to remember while presenting, and walking backwards
  through the deck re-opens what was there before.

  Most activities are a question with a right answer. The deck reveals the
  answer on a later step, every phone learns whether it agreed, and the room's
  record is kept so the scoreboard at the end can say how the humans did.

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
  alias TinyLlmTalk.Model

  @topic "room"

  # Answers that are looked up rather than written down are tagged, and
  # `activity/1` resolves them against the model so a slide and a phone agree
  # about what "right" means, and so the deck cannot claim an answer the
  # checkpoint does not give.
  @activities %{
    verb_vote: %{
      question: "flees, or flee?",
      hint: "the llama who chases the dogs ___",
      options: ~w(flees flee),
      answer: "flees"
    },
    bigram_next: %{
      question: "What comes after chases?",
      hint: "you are a count table. two thousand sentences. go.",
      options: ~w(the a dogs flees),
      answer: {:bigram, "chases"}
    },
    attention_bet: %{
      question: "Which word will the blank look at hardest?",
      hint: "before we look at what it actually did",
      options: ~w(llama dogs who chases),
      answer: :attention
    },
    sentence: %{
      question: "Build a sentence",
      hint: "tap words, then send it up",
      options: [],
      answer: nil
    },
    spot_the_human: %{
      question: "One of these was written by the grammar. Which?",
      hint: "the other two are the model's",
      options: :lineup,
      answer: :lineup
    },
    rematch: %{
      question: "flee, or flees?",
      hint: "the geese who see a fox ___",
      options: ~w(flee flees),
      answer: "flee"
    }
  }

  # The order the scoreboard lists results in, which is the order the talk asks.
  @scored ~w(verb_vote bigram_next attention_bet spot_the_human rematch)a

  defstruct activity: nil,
            votes: %{},
            submissions: %{},
            featured: nil,
            participants: %{},
            revealed: false,
            results: %{}

  @type t :: %__MODULE__{}
  @type result :: %{
          choice: String.t(),
          answer: String.t(),
          correct?: boolean(),
          votes: pos_integer()
        }

  ## CLIENT

  def start_link(_options), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Every activity the deck knows how to run, with its answer resolved."
  @spec activities() :: map()
  def activities, do: Map.new(@activities, fn {name, _activity} -> {name, activity(name)} end)

  @doc "One activity, with its options and answer resolved against the model."
  @spec activity(atom() | nil) :: map() | nil
  def activity(nil), do: nil

  def activity(name) do
    case Map.get(@activities, name) do
      nil -> nil
      activity -> resolve(activity)
    end
  end

  @spec subscribe() :: :ok
  def subscribe, do: PubSub.subscribe(TinyLlmTalk.PubSub, @topic)

  @doc "Opens an activity, or closes whatever is open when given `nil`."
  @spec open(atom() | nil) :: :ok
  def open(name), do: GenServer.cast(__MODULE__, {:open, name})

  @doc "Shows the answer to whatever is open. Every phone finds out how it did."
  @spec reveal() :: :ok
  def reveal, do: GenServer.cast(__MODULE__, :reveal)

  @doc "Forgets everything but who is connected. For rehearsals and tests."
  @spec reset() :: :ok
  def reset, do: GenServer.cast(__MODULE__, :reset)

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

    name
    |> activity()
    |> Map.fetch!(:options)
    |> Enum.map(fn option -> {option, Map.get(counts, option, 0)} end)
  end

  @doc "What the room, by majority, answered. Ties go to the option listed first."
  @spec majority(t(), atom()) :: String.t() | nil
  def majority(%__MODULE__{votes: votes}, _name) when map_size(votes) == 0, do: nil

  def majority(room, name) do
    room |> tally(name) |> Enum.max_by(&elem(&1, 1)) |> elem(0)
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

  @doc "The room's record, in the order the talk asked the questions."
  @spec results(t()) :: [{atom(), result()}]
  def results(%__MODULE__{results: results}) do
    Enum.flat_map(@scored, fn name ->
      case Map.get(results, name) do
        nil -> []
        result -> [{name, result}]
      end
    end)
  end

  @doc "How many questions the room got right, out of how many it answered."
  @spec score(t()) :: %{right: non_neg_integer(), asked: non_neg_integer()}
  def score(room) do
    results = results(room)

    %{
      right: Enum.count(results, fn {_name, result} -> result.correct? end),
      asked: length(results)
    }
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
  def handle_cast({:open, name}, %__MODULE__{activity: name} = room), do: {:noreply, room}

  # Opening an activity clears what the last one collected, after recording
  # how the room did on it. Walking back to a slide should ask the question
  # again, not show a stale answer; the record keeps the latest attempt.
  def handle_cast({:open, name}, room) do
    {:noreply,
     announce(%{
       record(room)
       | activity: name,
         votes: %{},
         submissions: %{},
         featured: nil,
         revealed: false
     })}
  end

  def handle_cast(:reveal, %__MODULE__{activity: nil} = room), do: {:noreply, room}
  def handle_cast(:reveal, room), do: {:noreply, announce(%{room | revealed: true})}

  def handle_cast(:reset, room) do
    {:noreply, announce(%__MODULE__{participants: room.participants})}
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
  defp options(name), do: name |> activity() |> Map.fetch!(:options)

  # A question counts once it has an answer and somebody voted. A room that
  # never voted has no record, and neither does a question with no answer.
  defp record(%__MODULE__{activity: nil} = room), do: room

  defp record(%__MODULE__{activity: name, votes: votes} = room) do
    case {activity(name).answer, majority(room, name)} do
      {nil, _choice} ->
        room

      {_answer, nil} ->
        room

      {answer, choice} ->
        result = %{
          choice: choice,
          answer: answer,
          correct?: choice == answer,
          votes: map_size(votes)
        }

        put_in(room.results[name], result)
    end
  end

  defp resolve(%{options: :lineup} = activity) do
    lineup = Model.lineup()

    %{activity | options: lineup.options, answer: lineup.answer}
  end

  defp resolve(%{answer: {:bigram, word}, options: options} = activity) do
    %{activity | answer: Model.bigram_pick(word, options)}
  end

  defp resolve(%{answer: :attention, options: options} = activity) do
    %{activity | answer: blank_looks_at(options)}
  end

  defp resolve(activity), do: activity

  # Where the position predicting the blank puts most of its attention, among
  # the words offered. Nil until there is a checkpoint, so nothing is revealed.
  defp blank_looks_at(options) do
    probe = Model.probe()

    case Model.attention(probe) do
      nil ->
        nil

      weights ->
        row = List.last(weights)

        Enum.max_by(options, fn option ->
          Enum.at(row, Enum.find_index(probe, &(&1 == option)))
        end)
    end
  end

  defp announce(room) do
    PubSub.broadcast(TinyLlmTalk.PubSub, @topic, {:room, room})

    room
  end
end
