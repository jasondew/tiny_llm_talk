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
          - Press start once the projector is up; about 70 s; runs under the chatter
          - If asked: this talk's model, training itself from random
          = top line: ln 32 = 3.466, a uniform guess
          = dashed line: 1.904, the best one-word model can do; going under it means it uses more than the previous word
          - When ready, move on
          """
        },
        %Slide{
          id: :the_vote,
          title: "flees, or flee?",
          steps: 2,
          notes: """
          - Ask out loud; hands up for each; wait
          - Step 2 lights flees
          - Say: the rule is easy; knowing which noun is the subject is the hard part. That is the talk
          """
        },
        %Slide{
          id: :title,
          title: "Transformers from Scratch, in Elixir",
          notes: """
          - Say the title once
          - The room just answered what the talk is about
          """
        },
        %Slide{
          id: :one_function,
          title: "A language model is one function",
          notes: """
          - Words in, 32 probabilities out; keep this frame all talk
          - Everything we build goes inside the box
          = the dashed line: a count table over adjacent pairs; fails exactly where the nearest noun lies
          """
        },
        %Slide{
          id: :the_architecture,
          title: "The transformer",
          steps: 2,
          notes: """
          - Word to row, the block, probabilities
          - Inside the box: attention gathers, a small network thinks; times N
          - Step 2: N = 1, this laptop's model
          - Say, do not show: every frontier model uses these pieces
          = GPT-4, Gemini, DeepSeek-V3: "Transformer-based", "builds on Transformer decoders", "still within the Transformer framework"
          = Llama 4, Claude: a mixture-of-experts transformer; Anthropic does not publish
          = Mamba, Qwen3-Next: swap most attention for a cheaper mixer; the block stays
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
          - One word, one token, one integer; no tokenizer
          - Point at start and the period
          - All lowercase
          """
        },
        %Slide{
          id: :grammar,
          title: "Grammar",
          notes: """
          - Rules quoted from the grammar module; four sentences it wrote
          = relative clause: the verb agrees with the head noun, not the nearest
          - We wrote the grammar, so "did it learn agreement" is measurable
          """
        },
        %Slide{
          id: :parameters,
          title: "Parameters",
          notes: """
          - Every table, shape, count; every float learned, none by hand
          - Two tables in, four square matrices in attention, the network holds over half
          = W_O: the fourth attention matrix mixes the blend back into the row; not on the attention slides
          - One block, one head, pure Elixir, empty deps; repo link at the end
          """
        },
        %Slide{
          id: :it_writes,
          title: "It writes",
          ticks: true,
          notes: """
          - Paused; press normal
          - The whole path once, fast; slowly after
          - Left the paragraph; right the forward pass for the word being written
          - Say: fifteen thousand floats, no library, every picture real
          - Slow it if they lean in; reset if dull
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
          - Sentence first; it stays on top through attention
          - Step 2: dogs, integer 5, row 5 of a 32 × 32 table; real floats
          - Step 3: position 6 (start is 0), added, not appended
          = why positions: attention alone is a bag of words
          = context length: 16 positions, the only hard limit
          - Step 4: three lines
          """
        },
        %Slide{
          id: :forgets_the_words,
          title: "At this point, the model has forgotten it ever saw words",
          notes: """
          - Seven rows of 32 floats; this is what attention sees
          - No word is mentioned again until the end
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
          - Say "math break": two slides, then back
          - Multiply pairwise, add
          = big: same direction
          = near zero: unrelated
          = negative: opposed
          - The only arithmetic in attention
          """
        },
        %Slide{
          id: :softmax_playground,
          title: "A softmax turns scores into a distribution",
          notes: """
          - Five scores in, five shares out, sum to one
          = distribution: positive numbers summing to one
          - Labels only, none from the sentence
          - Drag one up: it grows, the rest shrink; never zero
          = softmax: e to the score over the sum; e to anything is positive
          - End of the break
          """
        },
        %Slide{
          id: :learn_the_lookup,
          title: "Attention: ask, offer, hand over",
          steps: 10,
          notes: """
          - Formula alone first; let them look; then one symbol a step
          - The definitions are on the slide; two need more
          = √d: d is the key width, 32; keeps the softmax from saturating; the paper's d_k; frontier models slice across heads
          = Attention: the blend has the input's shape, 7 × 32, so the residual can add it
          - Next: a toy map by hand
          """
        },
        %Slide{
          id: :fuzzy_map,
          title: "A small example, by hand: \"Is it plural?\"",
          steps: 5,
          notes: """
          - Same formula, five keys, two-number vectors
          = key, value: how animal and how plural; the value is how plural, 0 or 1
          - Pick a query; one column a step
          = geese: 1.00, plural; never a key
          = sleepy: all zeros; softmax spreads evenly; 0.50, "no idea"
          - Not in the map, still sensible. That is the trick
          - Next: sixteen lines
          """
        },
        %Slide{
          id: :attention_code,
          title: "One head of attention, sixteen lines",
          steps: 8,
          notes: """
          - Real code, real numbers
          - Step 2 projections; 3 Q Kᵀ; 4 divide by √d; 5 mask; 6 softmax, rows sum to one; 7 blend, 7 × 32
          - Masked cells stay exactly zero
          - One head; frontier models run many
          - Say: every position in one matmul, no loop; why this scales and RNNs did not
          - Let them read
          """
        },
        %Slide{
          id: :attention_bet,
          title: "Where will the blank look?",
          steps: 2,
          notes: """
          - Ask before showing: llama, dogs, who, chases? Most say llama
          - Answer: who; the last row of the heatmap
          = why the dogs row: the blank has no row; it is predicted from the last position given
          - Wrong together sets up the walkthrough
          """
        },
        %Slide{
          id: :walkthrough,
          title: "LLMs are weird",
          notes: """
          - Dogs row: its query dots every key; nothing to mask; softmax
          - The weight goes to who, not llama. Weird
          - Say: who attends to llama; the subject in two hops
          - Click who: its hop, and the mask
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
          - The diagram again; ticks on embedding and attention
          - Left: two normalizations, the network, the adds
          - Next: normalization, activation, network, the block as code
          """
        },
        %Slide{
          id: :normalization,
          title: "Normalization",
          steps: 6,
          notes: """
          - Say first: stages hand rows out at any size; the next wants one size, or big rows shout
          = RMSNorm: divide by rms, multiply by g
          = rms: square every float, average, root; the row's typical size
          - Dogs row, first 10 of 32
          - Step 2 rms; 3 divided, size one; 4 g, 32 learned, one per column; 5 the product; 6 bars, all 32
          = vs LayerNorm: no mean, no bias; recentring buys nothing
          - Runs twice per block; lines 2 and 5
          """
        },
        %Slide{
          id: :relu,
          title: "The activation",
          steps: 2,
          notes: """
          - The one nonlinear line: max(0, z)
          = ReLU: negative to 0, positive untouched
          = why: without it W₁ then W₂ is one matrix; straight lines only
          - Step 2: 128 hidden floats before and after; bars below the line gone
          - Next: what a feed forward network is
          """
        },
        %Slide{
          id: :neural_network_idea,
          title: "A feed forward network",
          steps: 3,
          notes: """
          - One idea a step; nothing about training or backprop
          - Step 1, a node: dot product, bias, activation; here the sum lands under zero, the node goes quiet
          = learned: the weights and the bias
          - Step 2, a layer: many nodes, same inputs, own weights; a column of W₁ each
          - Step 3, a network: layers feeding layers; 32 in, 128 hidden, 32 out
          - Say once: also called a neural network, or an MLP; the whole transformer is one too
          """
        },
        %Slide{
          id: :neural_network,
          title: "The feed forward network in the block",
          steps: 2,
          notes: """
          - The formula and three lines: two matmuls, the activation between
          - Per position, no mixing; attention gathered, this thinks
          - Step 2: the dogs row for real; hidden as four rows of 32, zeros dark
          = half the parameters: two matrices of 4,096
          - Next: the block as code
          """
        },
        %Slide{
          id: :block_code,
          title: "Block.forward",
          steps: 8,
          notes: """
          - One function, nine lines; the training return folded away
          - The skips on the right are x, carried past to each add
          - A step per line: normalize, attend, add, normalize, network, add
          = residual: adds, never replaces; starts as the identity; a straight path back for gradients; what made deep nets trainable
          - Last step whole. Next: back to words
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
          steps: 3,
          notes: """
          - Step 1: one more norm, one weighted sum; 32 wide to 32 scores
          - Step 2: the logits as a strip
          - Step 3: the softmax, with a knob
          = temperature: logits divided by T before the softmax; T = 1 raw; below 1 the top takes all; above 1 flattens
          - flees tops all 32, narrowly; are second. Say it first
          - The dial carries to generation
          """
        },
        %Slide{
          id: :every_part,
          title: "The transformer in this talk, every part",
          notes: """
          - Every box ticked; the whole forward pass, seen
          - Next: the seven lines
          """
        },
        %Slide{
          id: :all_of_it_again,
          title: "This was all of it",
          steps: 5,
          notes: """
          - Read the seven lines aloud
          - Row, position added; the block; one more norm; 32 logits, softmax
          - Nobody needed a library. Next: using it
          """
        },
        %Slide{
          id: :one_word_at_a_time,
          title: "How to eat an elephant",
          notes: """
          - One bite at a time
          = the loop: ask, pick, append, ask again, stop at the period; the prefix is re-read every time
          - Press next: bars, pick, append; a fresh draw each press; three or four words
          = temperature: below 1 commits, above 1 wanders, 0 is argmax; past 2 structure goes first
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
          steps: 6,
          notes: """
          - Math first, for effect: every gradient by hand, no autodiff; do not read it; one file
          - Step 1: five sentences, which is all training is
          = corpus: 2,000 grammar sentences; every prefix knows its next word
          = surprise: the loss; minus the log of the probability on the real word
          - Prefix, run, surprise, nudge, repeat
          - Slide 1 has the curve if there is time
          """
        }
      ]
    },
    %Section{
      number: 7,
      title: "Did it learn it",
      minutes: 2,
      lands: "what is not here, the sentence again with its two hops, and it writes",
      slides: [
        %Slide{
          id: :what_is_not_here,
          title: "What is not here, and what is",
          steps: 2,
          notes: """
          = not here: tokenizer, GPU, multi-head, depth, KV caching
          = KV caching: a real model keeps the keys and values it computed; here the prefix is re-read
          = here: embeddings, learned positions, scaled dot-product attention, causal mask, residuals, RMSNorm, feed forward, temperature
          - Same pieces as a frontier model; thirteen orders of magnitude and a tokenizer apart
          """
        },
        %Slide{
          id: :the_sentence_again,
          title: "the llama who chases the dogs flees",
          steps: 3,
          notes: """
          - Step 1: the sentence from the open, blank and all
          - Step 2: where the blank looked: who, then who to llama; the subject in two hops
          - Step 3: what it puts on the blank; flees above flee
          - The vote, answered
          """
        },
        %Slide{
          id: :it_writes_again,
          title: "It writes",
          ticks: true,
          notes: """
          - The writer under the repo link; sources along the bottom
          - The frontier quotes came from those reports
          - Leave it running; stop talking
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
