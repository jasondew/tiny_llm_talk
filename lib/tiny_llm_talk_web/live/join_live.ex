defmodule TinyLlmTalkWeb.JoinLive do
  @moduledoc """
  What the audience sees on their phone.

  Deliberately one screen with no scrolling and no explanation: whatever is open
  on the big screen is what this shows, and when nothing is open it says so
  rather than inventing something to do. A person who arrives late, or who
  scanned the code twenty minutes ago and locked their phone, gets the current
  question the moment they look.

  This is the only route the audience touches, so it holds no state worth
  losing: closing the tab is a clean leave and re-opening it is a clean join.
  """

  use TinyLlmTalkWeb, :live_view

  alias TinyLlm.Vocab
  alias TinyLlmTalk.Room

  @max_words 9

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Room.subscribe()
      Room.join(self())
    end

    {:ok,
     socket
     |> assign(room: room(socket), choice: nil, words: [], sent: false)
     |> assign(page_title: "the llama who chases the dogs"), layout: false}
  end

  @impl true
  def handle_event("vote", %{"choice" => choice}, socket) do
    Room.vote(self(), choice)

    {:noreply, assign(socket, choice: choice)}
  end

  def handle_event("word", %{"word" => word}, socket) do
    {:noreply, update(socket, :words, &Enum.take(&1 ++ [word], @max_words))}
  end

  def handle_event("undo", _params, socket) do
    {:noreply, update(socket, :words, fn words -> Enum.drop(words, -1) end)}
  end

  def handle_event("send", _params, %{assigns: %{words: []}} = socket), do: {:noreply, socket}

  def handle_event("send", _params, socket) do
    Room.submit(self(), socket.assigns.words)

    {:noreply, assign(socket, sent: true)}
  end

  def handle_event("again", _params, socket) do
    {:noreply, assign(socket, words: [], sent: false)}
  end

  @impl true
  def handle_info({:room, room}, socket) do
    {:noreply, socket |> assign(room: room) |> reset_on_new_activity(room)}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, activity: Room.activity(assigns.room.activity))

    ~H"""
    <main class="join">
      <p class="join__brand">the llama who chases the dogs</p>

      <div :if={is_nil(@activity)} class="join__idle">
        <p class="join__idle-title">You are in.</p>
        <p class="join__idle-body">Leave this open. A question will appear here.</p>
      </div>

      <div :if={@activity && @room.activity != :sentence} class="join__ask">
        <p class="join__question">{@activity.question}</p>
        <p class="join__hint">{@activity.hint}</p>
        <button
          :for={option <- @activity.options}
          type="button"
          phx-click="vote"
          phx-value-choice={option}
          class={["join__option", @choice == option && "join__option--chosen"]}
        >{option}</button>
        <p :if={@choice} class="join__hint">Tap another to change your mind.</p>
      </div>

      <div :if={@room.activity == :sentence} class="join__build">
        <p class="join__question">{@activity.question}</p>

        <div :if={@sent} class="join__sent">
          <p class="join__sent-line">{Enum.join(@words, " ")}</p>
          <p class="join__hint">Sent. It might end up on the screen.</p>
          <button type="button" phx-click="again" class="join__option">write another</button>
        </div>

        <div :if={not @sent}>
          <p class="join__line">{sentence_so_far(@words)}</p>
          <div class="join__actions">
            <button type="button" phx-click="undo" class="join__small" disabled={@words == []}>
              back
            </button>
            <button
              type="button"
              phx-click="send"
              class="join__small join__small--go"
              disabled={@words == []}
            >
              send it up
            </button>
          </div>
          <div :for={group <- word_groups()} class="join__group">
            <p class="join__group-name">{group.name}</p>
            <div class="join__words">
              <button
                :for={word <- group.words}
                type="button"
                phx-click="word"
                phx-value-word={word}
                class="join__word"
              >{word}</button>
            </div>
          </div>
        </div>
      </div>
    </main>
    """
  end

  ## PRIVATE FUNCTIONS

  # A question that has just changed should not show the last one's answer.
  defp reset_on_new_activity(socket, room) do
    if socket.assigns.room.activity == room.activity do
      socket
    else
      assign(socket, choice: nil, words: [], sent: false)
    end
  end

  defp sentence_so_far([]), do: "tap a word"
  defp sentence_so_far(words), do: Enum.join(words, " ")

  defp word_groups do
    [
      %{name: "start with", words: Vocab.determiners()},
      %{name: "nouns", words: Vocab.nouns()},
      %{name: "who / and", words: Vocab.connectives()},
      %{name: "verbs", words: Vocab.transitive_verbs() ++ Vocab.intransitive_verbs()},
      %{name: "is / are", words: Vocab.copula()},
      %{name: "adjectives", words: Vocab.adjectives()}
    ]
  end

  # Before the socket connects there is nothing to join yet, so render the
  # empty room rather than reaching for a process the static render cannot use.
  defp room(socket) do
    if connected?(socket), do: Room.state(), else: %Room{}
  end
end
