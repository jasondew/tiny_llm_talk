defmodule TinyLlmTalk.Deck do
  @moduledoc """
  The deck as data: the eight sections of `docs/talk-outline.md`, in order,
  with every slide the outline names.

  Nothing here draws anything. A slide is a title, a note, and a count of
  reveal steps; `TinyLlmTalkWeb.SlideComponents` matches on the id to draw it.
  Keeping the arc as a list means the running order is one readable file that
  can be diffed against the outline, rather than something recovered by
  reading templates.

  The arc is one sentence going through one forward pass, in the order
  `TinyLlm.Transformer.forward/2` runs it. Every section moves one of three
  things: the sentence, the picture of where attention looks, or the score.
  """

  alias TinyLlmTalk.{Section, Slide}

  @sections [
    %Section{
      number: 0,
      title: "Cold open",
      minutes: 4,
      lands:
        "it trained while they sat down, the room has answered, a language model is one function, and a transformer is one block repeated",
      slides: [
        %Slide{
          id: :training_math,
          title: "Training, live",
          notes: """
          - Start it once the projector is up
          - About 70 seconds
          - If asked: this talk's model, training itself from random
          = dashed line: the best any one-word model can do
          - Going under it means it uses more than the previous word
          """
        },
        %Slide{
          id: :the_vote,
          title: "flees, or flee?",
          steps: 2,
          notes: """
          - Ask, hands up for each, wait
          ! The rule is easy
          ! Knowing which noun is the subject is the hard part
          ! That is the talk
          """
        },
        %Slide{
          id: :title,
          title: "Transformers from Scratch, in Elixir",
          notes: """
          ! Say the title once
          - The room just answered what it is about
          """
        },
        %Slide{
          id: :one_function,
          title: "A language model is one function",
          notes: """
          ! Words in, probabilities out
          ! Keep this frame all talk
          - Everything we build goes inside the box
          - A count of adjacent pairs is the simplest fit
          - It fails exactly where the nearest noun lies
          """
        },
        %Slide{
          id: :the_architecture,
          title: "The transformer",
          steps: 2,
          notes: """
          - Attention gathers, a small network thinks
          - Repeated N times
          ! Every frontier model uses these pieces
          = GPT-4: "Transformer-based"
          = Gemini: "builds on Transformer decoders"
          = DeepSeek-V3: "still within the Transformer framework"
          = Llama 4: mixture of experts
          = Claude: not published
          = Mamba, Qwen3-Next: a cheaper mixer for most attention, block kept
          """
        }
      ]
    },
    %Section{
      number: 1,
      title: "Words become numbers",
      minutes: 4,
      lands: "32 words, a grammar we own, every parameter, and the whole path once, fast",
      slides: [
        %Slide{
          id: :vocabulary,
          title: "Vocabulary",
          notes: """
          ! One word, one token, one integer
          ! No tokenizer
          """
        },
        %Slide{
          id: :grammar,
          title: "Grammar",
          notes: """
          - The relative clause rule: the verb agrees with the head noun, not the nearest
          ! We wrote the grammar
          ! So "did it learn agreement" is measurable
          """
        },
        %Slide{
          id: :parameters,
          title: "Parameters",
          notes: """
          ! Every float learned, none by hand
          - The network holds over half
          = W_O: the fourth attention matrix, mixes the blend back into the row
          - One block, one head, pure Elixir, empty deps
          - Repo link at the end
          """
        },
        %Slide{
          id: :it_writes,
          title: "It writes",
          ticks: true,
          notes: """
          - Press normal
          - The whole path once, fast
          ! Fifteen thousand floats, no library
          ! Every picture is real
          - Slow it if they lean in
          - Reset if dull
          """
        }
      ]
    },
    %Section{
      number: 2,
      title: "Embedding and position",
      minutes: 3,
      lands: "a word is a row of floats, and position is added, not appended",
      slides: [
        %Slide{
          id: :a_word_is_a_row,
          title: "Each word becomes a row of floats",
          steps: 4,
          notes: """
          - Real floats from the checkpoint
          ! Position is added, not appended
          ! Attention alone is a bag of words
          - 16 positions, the only hard limit
          """
        },
        %Slide{
          id: :forgets_the_words,
          title: "At this point, the model has forgotten it ever saw words",
          notes: """
          ! This grid is all attention ever sees
          ! No word until the end
          """
        }
      ]
    },
    %Section{
      number: 3,
      title: "Attention",
      minutes: 11,
      lands: "a fuzzy lookup: score every key, softmax the scores, blend the values",
      slides: [
        %Slide{
          id: :dot_product,
          title: "A dot product is a similarity score",
          steps: 3,
          notes: """
          ! Say "math break"
          - Two slides, then back
          - Big: same direction
          - Near zero: unrelated
          - Negative: opposed
          ! The only arithmetic in attention
          """
        },
        %Slide{
          id: :softmax_playground,
          title: "A softmax turns scores into a distribution",
          notes: """
          = distribution: positive numbers summing to one
          - Define it once
          - Labels only, none from the sentence
          ! Drag one up: it grows, the rest shrink
          ! Never zero, e to anything is positive
          - End of the break
          """
        },
        %Slide{
          id: :learn_the_lookup,
          title: "Attention: ask, offer, hand over",
          steps: 10,
          notes: """
          - Let them look at the formula first
          = √d: keeps the softmax from saturating
          - The paper's d_k
          - Frontier models slice the width across heads
          ! The blend keeps the input's shape
          ! So the residual can add it
          - Next: a toy map by hand
          """
        },
        %Slide{
          id: :fuzzy_map,
          title: "A small example, by hand: \"Is it plural?\"",
          steps: 5,
          notes: """
          - Keys: how animal, how plural
          - Value: how plural
          = geese: plural, and never a key
          = sleepy: all zeros, the softmax spreads evenly, 0.50 is "no idea"
          ! Not in the map, still sensible
          ! That is the trick
          """
        },
        %Slide{
          id: :attention_code,
          title: "One head of attention, sixteen lines",
          steps: 8,
          notes: """
          - Masked cells stay exactly zero
          - One head, frontier models run many
          ! Every position in one matmul, no loop
          ! Why this scales and RNNs did not
          - Let them read
          """
        },
        %Slide{
          id: :attention_bet,
          title: "Where will the blank look?",
          steps: 2,
          notes: """
          ! Ask before showing: llama, dogs, who, or chases?
          - Most say llama
          = why the dogs row: the blank has no row, so the last position predicts it
          - Wrong together sets up the walkthrough
          """
        },
        %Slide{
          id: :walkthrough,
          title: "LLMs are weird",
          notes: """
          - Nothing to mask, dogs is last
          ! The weight goes to who, not llama
          ! Weird
          ! Who attends to llama: the subject in two hops
          - Click who to show it
          """
        }
      ]
    },
    %Section{
      number: 4,
      title: "The rest of the block",
      minutes: 6,
      lands: "normalize, think, add: what makes a layer stackable",
      slides: [
        %Slide{
          id: :lid_off,
          title: "The transformer in this talk",
          notes: """
          - Two stages done, three to go
          - Then the block as code
          """
        },
        %Slide{
          id: :normalization,
          title: "Normalization",
          steps: 6,
          notes: """
          ! Say first: stages hand rows out at any size
          ! The next stage wants one size, or big rows shout
          - g lets the model pick a size per feature
          = vs LayerNorm: no mean, no bias
          - Recentring buys nothing
          - Runs twice per block
          """
        },
        %Slide{
          id: :relu,
          title: "The activation",
          steps: 2,
          notes: """
          - The one nonlinear line
          ! Without it the two matrices collapse to one
          ! Straight lines only
          - Next: what a feed forward network is
          """
        },
        %Slide{
          id: :neural_network_idea,
          title: "A feed forward network",
          steps: 3,
          notes: """
          - One idea a step
          - No training, no backprop
          - The node is the dot product from the math break, plus a bias
          ! Also called a neural network, or an MLP
          ! The whole transformer is one too
          """
        },
        %Slide{
          id: :neural_network,
          title: "The feed forward network in the block",
          steps: 2,
          notes: """
          ! Per position, no mixing
          ! Attention gathered, this thinks
          - These two matrices are half the parameters
          """
        },
        %Slide{
          id: :block_code,
          title: "Block.forward",
          steps: 8,
          notes: """
          - The skips are x, carried past to each add
          ! The residual adds, never replaces
          ! It starts as the identity
          ! Gradients get a straight path back
          ! What made deep nets trainable
          """
        }
      ]
    },
    %Section{
      number: 5,
      title: "Back to words",
      minutes: 3,
      lands:
        "rows become a distribution, every box ticked, the seven lines, the loop, and the knob",
      slides: [
        %Slide{
          id: :back_to_words,
          title: "Thirty-two floats become thirty-two probabilities",
          steps: 4,
          notes: """
          = temperature: T = 1 is the raw softmax
          - Below 1 the top takes all
          - Above 1 flattens
          ! flees tops all 32, narrowly
          ! are is second, say it first
          - The dial carries to generation
          """
        },
        %Slide{
          id: :every_part,
          title: "The transformer in this talk, every part",
          notes: """
          ! The whole forward pass, seen
          """
        },
        %Slide{
          id: :all_of_it_again,
          title: "This was all of it",
          steps: 5,
          notes: """
          ! Read the seven lines aloud
          ! Nobody needed a library
          """
        },
        %Slide{
          id: :one_word_at_a_time,
          title: "How to eat an elephant",
          notes: """
          - One bite at a time
          ! The prefix is re-read every time
          ! A model cannot take back what it said
          - Three or four words
          - Start over if it wanders
          - Below 1 commits, above 1 wanders
          - 0 is argmax
          - Past 2 structure goes first
          """
        }
      ]
    },
    %Section{
      number: 6,
      title: "Training",
      minutes: 3,
      lands: "it trains live; guess, measure, nudge, repeat",
      slides: [
        %Slide{
          id: :live_training,
          title: "Training",
          steps: 7,
          notes: """
          - Ask: how does it learn? Then the math
          ! Do not read the math
          ! Every gradient by hand, no autodiff, one file
          = corpus: 2,000 grammar sentences
          - Every prefix knows its next word
          = surprise: minus the log of the probability on the real word
          - Slide 1 has the curve if there is time
          """
        }
      ]
    },
    %Section{
      number: 7,
      title: "Did it learn it",
      minutes: 2,
      lands: "what is not here, and it writes",
      slides: [
        %Slide{
          id: :what_is_not_here,
          title: "What is not here, and what is",
          steps: 2,
          notes: """
          = KV caching: a real model keeps the keys and values it computed
          - Here the prefix is re-read
          ! Same pieces as a frontier model
          ! Thirteen orders of magnitude and a tokenizer apart
          """
        },
        %Slide{
          id: :it_writes_again,
          title: "It writes",
          ticks: true,
          notes: """
          - The frontier quotes came from those reports
          ! Leave it running
          ! Stop talking
          """
        }
      ]
    }
  ]

  @title "Transformers from Scratch, in Elixir"

  @slides @sections
          |> Enum.flat_map(fn section ->
            Enum.map(section.slides, &%{&1 | section: section.number})
          end)
          |> Enum.with_index(1)
          |> Enum.map(fn {slide, index} -> %{slide | index: index} end)

  @numbered_sections Enum.map(@sections, fn section ->
                       %{section | slides: Enum.filter(@slides, &(&1.section == section.number))}
                     end)

  @count length(@slides)

  @forward_keys ~w(ArrowRight ArrowDown PageDown Enter n j l) ++ [" "]
  @backward_keys ~w(ArrowLeft ArrowUp PageUp Backspace p k h)

  @doc "The talk's title, as the footer of every slide shows it."
  @spec title() :: String.t()
  def title, do: @title

  @spec sections() :: [Section.t()]
  def sections, do: @numbered_sections

  @spec slides() :: [Slide.t()]
  def slides, do: @slides

  @spec count() :: pos_integer()
  def count, do: @count

  @spec at(pos_integer()) :: Slide.t()
  def at(index) when index in 1..@count//1, do: Enum.at(@slides, index - 1)

  @spec section(Slide.t()) :: Section.t()
  def section(%Slide{section: number}) do
    Enum.find(@numbered_sections, &(&1.number == number))
  end

  @doc "The whole talk's budget, in seconds: every section's minutes added up."
  @spec total_seconds() :: non_neg_integer()
  def total_seconds, do: Enum.sum(Enum.map(@sections, &(&1.minutes * 60)))

  @doc """
  The seconds the outline says should have passed when this slide comes up:
  every earlier section in full, plus this section's minutes spread evenly
  over its slides.
  """
  @spec expected_seconds(Slide.t()) :: non_neg_integer()
  def expected_seconds(%Slide{} = slide) do
    section = section(slide)

    earlier =
      @sections |> Enum.filter(&(&1.number < section.number)) |> Enum.map(&(&1.minutes * 60))

    place = Enum.find_index(section.slides, &(&1.index == slide.index))

    Enum.sum(earlier) + div(section.minutes * 60 * place, length(section.slides))
  end

  @doc """
  The window the outline gives this slide, in seconds from the start of the
  talk: from when it should come up to when the next one should. The
  presenter is on pace while the clock is inside it.
  """
  @spec expected_window(Slide.t()) :: {non_neg_integer(), non_neg_integer()}
  def expected_window(%Slide{} = slide) do
    section = section(slide)
    start = expected_seconds(slide)

    {start, start + div(section.minutes * 60, length(section.slides))}
  end

  @doc """
  The steps a slide plans for.

  `steps:` in the arc above is a plan, not a fact: it says how many beats a
  slide will have once it is drawn. Navigation takes the count from the
  renderer instead, because a slide that ignores `@step` would otherwise be
  shown several times over, identically. Callers pass their own function; this
  is the one that trusts the plan.
  """
  @spec steps(pos_integer()) :: pos_integer()
  def steps(index), do: at(index).steps

  @doc """
  Turns whatever came in on the URL into a position that exists. A slide index
  in the address bar is the whole crash-recovery story: a LiveView that dies
  mid-talk reconnects to the slide it was on, not to slide one.
  """
  @spec position(term(), term(), (pos_integer() -> pos_integer())) ::
          {pos_integer(), pos_integer()}
  def position(index_param, step_param, steps_of \\ &steps/1) do
    index = index_param |> to_integer() |> clamp(1, @count)
    step = step_param |> to_integer() |> clamp(1, steps_of.(index))
    {index, step}
  end

  @doc "Where a keypress moves the deck. Unknown keys stay put."
  @spec move(String.t(), {pos_integer(), pos_integer()}, (pos_integer() -> pos_integer())) ::
          {pos_integer(), pos_integer()}
  def move(key, position, steps_of \\ &steps/1)

  def move(key, {index, step}, steps_of) when key in @forward_keys,
    do: advance(index, step, steps_of)

  def move(key, {index, step}, steps_of) when key in @backward_keys,
    do: retreat(index, step, steps_of)

  def move("Home", _position, _steps_of), do: {1, 1}
  def move("End", _position, steps_of), do: {@count, steps_of.(@count)}
  def move(_key, position, _steps_of), do: position

  @doc """
  Where a keypress moves the deck with the steps skipped: whole slides, landing
  on the first step of each. Shift and an arrow, for getting somewhere fast.
  """
  @spec skip(String.t(), {pos_integer(), pos_integer()}, (pos_integer() -> pos_integer())) ::
          {pos_integer(), pos_integer()}
  def skip(key, position, steps_of \\ &steps/1)

  def skip(key, {index, _step}, _steps_of) when key in @forward_keys,
    do: {min(index + 1, @count), 1}

  def skip(key, {index, _step}, _steps_of) when key in @backward_keys,
    do: {max(index - 1, 1), 1}

  def skip(key, position, steps_of), do: move(key, position, steps_of)

  ## PRIVATE FUNCTIONS

  defp advance(index, step, steps_of) do
    cond do
      step < steps_of.(index) -> {index, step + 1}
      index < @count -> {index + 1, 1}
      true -> {index, step}
    end
  end

  defp retreat(index, step, steps_of) do
    cond do
      step > 1 -> {index, step - 1}
      index > 1 -> {index - 1, steps_of.(index - 1)}
      true -> {index, step}
    end
  end

  defp to_integer(value) when is_integer(value), do: value

  defp to_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, _rest} -> integer
      :error -> 1
    end
  end

  defp to_integer(_value), do: 1

  defp clamp(value, minimum, maximum), do: value |> max(minimum) |> min(maximum)
end
