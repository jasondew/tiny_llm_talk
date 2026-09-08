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
          - Press start as soon as the projector is up; about 70 seconds; runs under the chatter
          - Same config and seed as the checkpoint, so it lands on the loss every figure came from; the slide says whether it matched
          - If asked: the model in this talk, training itself from random, right now
          = knowing nothing: ln 32 = 3.466, the loss of a uniform guess
          = dashed line: 1.904, the best any one-word model can do; the curve going well under it means it uses information the previous word does not carry
          - When it is time, move on to the sentence
          """
        },
        %Slide{
          id: :the_vote,
          title: "flees, or flee?",
          steps: 2,
          notes: """
          - Ask out loud, hands up for each; do not fill the silence
          - Step 2 lights flees; everybody knew
          - Say: the rule is easy to name; the hard part is knowing which noun is the subject when a plural one sits next to the blank. That is the talk
          """
        },
        %Slide{
          id: :title,
          title: "Transformers from Scratch, in Elixir",
          notes: """
          - Say the title once
          - The sentence before it is what the whole talk is about, and the room just answered it
          """
        },
        %Slide{
          id: :one_function,
          title: "A language model is one function",
          notes: """
          - Input: the words so far. Output: 32 probabilities. Never let go of this frame
          - Everything we build goes inside the box
          - Say once: the simplest thing that fits is a count table over adjacent pairs; it fails exactly where the nearest noun lies. That is the dashed line on the training chart
          """
        },
        %Slide{
          id: :the_architecture,
          title: "The transformer",
          steps: 2,
          notes: """
          - A word becomes a row, then the block, then probabilities
          - Inside the dashed box: attention gathers, a small network thinks; repeated N times
          - Step 2: N becomes 1, the model on this laptop, one block deep
          - Say, do not show: every frontier model uses these same pieces, in their own reports
          = GPT-4: "Transformer-based"
          = Gemini: "builds on Transformer decoders"
          = DeepSeek-V3: "still within the Transformer framework"
          = Llama 4: a mixture-of-experts transformer
          = Claude: Anthropic does not publish the architecture
          = Mamba, Qwen3-Next: swap most attention layers for a cheaper mixer and keep the rest; the block is still in them
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
          - One word is one token is one integer; there is no tokenizer
          - Point at start and the period: sequences begin with one and end with the other
          - Every word is lowercase
          """
        },
        %Slide{
          id: :grammar,
          title: "Grammar",
          notes: """
          - Rules on the left are quoted from the grammar module's docs; four sentences it wrote on the right
          = agreement: a subject agrees with its verb
          = relative clause: its verb agrees with the head noun, not the nearest noun
          - We wrote the grammar, so "did it learn agreement" is a measurement, not a vibe. Nobody knows that about a real corpus
          """
        },
        %Slide{
          id: :parameters,
          title: "Parameters",
          notes: """
          - Every table, by stage, with its shape and count
          = parameter: one float in one of these tables
          - Two tables on the way in, four square matrices in attention, the network holds more than half
          - Every one starts random and training moves every one; nothing is written by hand
          - Say, do not show: one block deep, one head wide, pure Elixir standard library, empty deps list
          - The repo link comes at the end
          """
        },
        %Slide{
          id: :it_writes,
          title: "It writes",
          ticks: true,
          notes: """
          - Starts paused; press normal when ready
          - The whole path once, fast, before we take it slowly
          - Left: the paragraph. Right: the forward pass for the word being written: integers, rows, query and keys, attention, the distribution, the pick
          - Say only: fifteen thousand floats, pure Elixir, no library, every picture is real
          - Slow it down if people lean in; reset if a sentence is dull
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
          - The sentence alone first; it stays on top through attention
          - Step 2: dogs, the word next to the blank; look its integer up in a 32 × 32 table and take the row. All 32 floats are real, from the checkpoint
          - Step 3: a second row for position 6 (the start token is 0), added, not appended: same width in, same width out
          = why positions: attention on its own is a bag of words
          = context length: 16 positions, the only hard limit in the model
          - Step 4: the three lines that do all of it
          """
        },
        %Slide{
          id: :forgets_the_words,
          title: "At this point the model has forgotten it saw words",
          notes: """
          - Seven positions in, seven rows of 32 floats out; this grid is what attention sees
          - Nothing after this slide mentions a word until the very end
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
          - Say "math break" out loud; two slides of arithmetic, then back to the model
          - Two lists, multiply pairwise, add
          = big: they point the same way
          = near zero: unrelated
          = negative: opposed
          - The only arithmetic in attention
          """
        },
        %Slide{
          id: :softmax_playground,
          title: "A softmax turns scores into a distribution",
          notes: """
          - Five scores in, five shares out, always summing to one
          = distribution: positive numbers that sum to one; define it once
          - The words are only labels, none from the sentence
          - Drag a score up: its share grows and every other shrinks; far below the rest goes to nearly nothing, never zero
          = softmax: e to the score, divided by the sum of all of them; e to anything is positive, which is why the shares are
          - End of the break; the next slide puts both pieces to work
          """
        },
        %Slide{
          id: :learn_the_lookup,
          title: "Attention: ask, offer, hand over",
          steps: 10,
          notes: """
          - Formula alone and large first; let them look. Then it shrinks to the top and one symbol arrives per step
          = input: the grid from the last slide, 7 × 32
          = W_Q, W_K, W_V: three learned matrices, 32 × 32
          = Q, K, V: what this position is looking for, what it advertises, what it hands over if chosen; each is input × matrix, 7 × 32
          = Q Kᵀ: every dot product at once, 7 × 7
          = √d: d is the width of a key, 32, so the softmax does not saturate; the paper's d_k, not d_model; the same 32 here with one head and no slicing. Frontier models slice the embedding across heads
          = softmax: each row becomes a distribution
          = Attention: blend the values; the input's shape, which is what lets the residual add it back
          - Next: the same thing on a toy map, by hand
          """
        },
        %Slide{
          id: :fuzzy_map,
          title: "A small example, by hand",
          steps: 5,
          notes: """
          - The same formula on five keys with two-number vectors, checkable by eye
          = key vector: how much of an animal, how plural
          = value: how plural that key is, 0 singular, 1 plural, so the blend answers how plural the query is
          - Pick a query, then one column a step: Q · K; divide by √2 and softmax; weight × V; the sum
          = geese: 1.00, plural, and the map never held it
          = sleepy: no animal, no number, every score zero, the softmax spreads evenly, 0.50, the honest "no idea"
          - goose and geese are not keys and it still answers sensibly. That is the whole trick
          - Next: the same thing in sixteen lines
          """
        },
        %Slide{
          id: :attention_code,
          title: "One head of attention, sixteen lines",
          steps: 8,
          notes: """
          - Real code from the repo, not simplified, with the real numbers beside it
          - Step 2: the three projections; the input's seven rows, three 32 × 32 matrices, and the Q, K, V each makes
          - Step 3: Q Kᵀ, the 7 × 7 scores, signed and raw
          - Step 4: divide by √d on its own line; the same cells shrink
          - Step 5: the mask; the future struck out, every cell above the diagonal
          - Step 6: softmax; each row sums to one; struck-out cells stay struck out, their weight is exactly zero
          - Step 7: the blend; attention output, 7 × 32, the input's shape
          - One head; frontier models run many side by side
          - Say: every position at once in one matmul, no loop over time; that is why this scales and a recurrent network did not
          - Let them read; say only what each block is for
          """
        },
        %Slide{
          id: :attention_bet,
          title: "Where will the blank look?",
          steps: 2,
          notes: """
          - Ask by voice before showing: llama, dogs, who, chases. Most rooms say llama
          - The weights stay on screen to stare at while they answer
          - The model says who; the reveal is the last row of the heatmap, the dogs position
          = why the dogs row: the blank has no row; it is predicted from the output of the last position given. Say it plainly, someone will ask
          - Being wrong together is what makes the walkthrough land
          """
        },
        %Slide{
          id: :walkthrough,
          title: "LLMs are weird",
          notes: """
          - Starts on dogs, the position predicting the blank, the whole row at once: its query dots every key, nothing to mask since it is last, softmax
          - Real numbers from the checkpoint. Most of the weight goes to who, not llama. That is the weird part
          - Say, do not show: who in turn attends to llama, so the blank reaches the subject in two hops, through the word that stands for it
          - Click who to show that hop, and the mask hiding its future
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
          - The picture from the cold open again, with the 1 and the dashed box named
          - Embedding and attention wear ticks, the two stages covered so far
          - Left: the two normalizations, the network, and the arrows between them
          - Next three slides: normalization, the activation, the network; then the block as code
          """
        },
        %Slide{
          id: :normalization,
          title: "Normalization",
          steps: 6,
          notes: """
          - Say the idea first, nothing on the slide for it: rows come out of a stage at whatever size the stage made them; the next stage wants them all at one size, or the big rows shout and the small ones vanish
          = RMSNorm: divide the row by its rms, then multiply by g
          = rms: root mean square; square every float so signs do not cancel, average the squares, take the root; one number per row, its typical size
          - Then the dogs row, real numbers, the first ten of 32
          - Step 2: its rms. Step 3: divided by it, same direction, size one. Step 4: g, 32 learned floats, one per column, so the model chooses the size per feature. Step 5: the product, what the next stage receives. Step 6: bars, all 32, one scale
          = vs LayerNorm: no mean subtracted, no bias; the RMSNorm paper found the recentring buys nothing
          - Say, do not show: it runs twice per block, before attention and before the network; lines 2 and 5 of the block
          """
        },
        %Slide{
          id: :relu,
          title: "The activation",
          steps: 2,
          notes: """
          - The one nonlinear thing in the block, and it is one line: max of zero and z
          = ReLU: negative becomes 0, positive passes through untouched; flat, then the identity, a corner at the origin
          = why: without the activation, W₁ then W₂ is a single matrix; the network could only draw straight lines
          - Step 2: the dogs row's 128 hidden floats before and after, on one scale; every bar below the line is gone, and the count says how many
          - Next: what a neural network is
          """
        },
        %Slide{
          id: :neural_network_idea,
          title: "A neural network",
          steps: 3,
          notes: """
          - Some of the room has never seen one; one idea at a time, nothing about training
          - Step 1, a node: four inputs, a weight on every wire, add them up, add a bias, through the activation. It is the dot product from the math break: x · w + b, then ReLU. With these numbers the sum lands just under zero and the node goes quiet
          = learned: the weights and the bias
          - Step 2, a layer: many nodes reading the same inputs, each with its own weights; W₁ has one column per node and a bias per node; six outputs from four inputs
          - Step 3, a network: layers feeding each other; this is the one in the block, 32 in, 128 hidden, 32 out
          - Say once: the whole transformer is also a neural network; this small one inside the block is the textbook kind
          - Do not go near backprop
          """
        },
        %Slide{
          id: :neural_network,
          title: "The neural network in the block",
          steps: 2,
          notes: """
          - The one from the last slide, in practice: the formula and the three lines, two matmuls with the activation between
          - Per position, no mixing between positions: attention gathered, this is where the model thinks about what it gathered
          - Step 2: the dogs row for real; 32 in, the hidden 128 as four rows of 32 with the ReLU's zeros dark, 32 out again
          = half the parameters: these two matrices, 4,096 floats each, plus their biases
          - Next: the block as code
          """
        },
        %Slide{
          id: :block_code,
          title: "Block.forward",
          steps: 8,
          notes: """
          - One function, nine lines of work; the training-only return value is folded away
          - The flow is the diagram with the two adds; the skips down its right edge are x: the input carried past normalization and attention to the first add, that sum carried past the second normalization and the network to the second
          - Step down one line and one box at a time: normalize, attend, add the input back, normalize, the network, add again
          = residual: the block never replaces the row, it adds to it. A layer that can only add starts as the identity, so a hundred stacked cannot lose the input, and every gradient has a straight path back through the additions. This is what made deep networks trainable
          - The last step shows it whole. Next: back to words
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
          - Step 1, the code: one more norm, then one more weighted sum takes the last row from 32 wide to 32 scores, one per word
          - Step 2: the logits, as a strip
          - Step 3: the softmax from the math break with its bars, and one new knob
          = temperature: divide the logits by T before the softmax. T = 1 is the raw softmax; below 1 the top word takes everything, since a small divisor stretches the gaps before the exponential; above 1 the bars flatten toward equal
          - The bars are the probe's: flees is the top of all 32, narrowly; are is second. Say so before someone else does
          - The dial carries to the generation slide
          """
        },
        %Slide{
          id: :every_part,
          title: "The transformer in this talk, every part",
          notes: """
          - The diagram once more, and every box wears a tick
          - That is the whole forward pass, seen. Next: the seven lines that do all of it
          """
        },
        %Slide{
          id: :all_of_it_again,
          title: "This was all of it",
          steps: 5,
          notes: """
          - Read the seven lines out loud: the three from the embedding slide, the block, the three from back to words
          - A word becomes a row, position is added. The block: attention gathers, the residual keeps, the network thinks. One more norm. 32 floats become 32 logits, and the softmax makes them probabilities
          - Nobody in the room needed a library to follow that. Next: using it
          """
        },
        %Slide{
          id: :one_word_at_a_time,
          title: "How to eat an elephant",
          notes: """
          - Answer the title: one bite at a time; here, one word at a time
          = the loop: ask the function, pick a word, append it, ask again, stop at the period. The whole prefix is re-read every time, so a model cannot take back what it has said
          - Press next: the bars, the pick, the append. Every press is a fresh draw. Start over if it wanders. Three or four words are enough
          = temperature: below one commits, above one wanders, zero is argmax. At zero, the same word every time. Past two, structure goes before content
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
          - The math first, for effect: the whole backward pass, every gradient the nudge needs, derived by hand in the repo's backprop notes, no autodiff. Do not read it. Say it all fit in one file
          - Step 1 replaces it with five sentences, which is all training is
          = corpus: 2,000 sentences the grammar wrote, so every prefix comes with the word that really followed
          = surprise: the loss, minus the log of the probability the model gave the real word
          - Take a prefix; run it; measure the surprise; nudge every number the way that makes it smaller; repeat a few hundred times
          - The loss falling live was slide 1; step back to it if there is time
          """
        }
      ]
    },
    %Section{
      number: 7,
      title: "Did it learn it",
      minutes: 2,
      lands: "what is not here, the sentence again, and it writes",
      slides: [
        %Slide{
          id: :what_is_not_here,
          title: "What is not here, and what is",
          steps: 2,
          notes: """
          = not here: a tokenizer, a GPU, multi-head attention, depth, KV caching
          = KV caching: here the whole prefix is re-read every word; a real model keeps the keys and values it already computed
          = here: embeddings, learned positions, scaled dot-product attention, a causal mask, residuals, RMSNorm, an MLP, temperature sampling
          - The loss and the hand-written gradients are in the repo but not in the talk, so they stay off the list
          - Every one of these is the same thing a frontier model does. The difference is thirteen orders of magnitude and a tokenizer
          """
        },
        %Slide{
          id: :the_sentence_again,
          title: "the llama who chases the dogs flees",
          notes: """
          - The bracket drawn, and the probability the model puts on flees: the highest of all 32 words
          """
        },
        %Slide{
          id: :it_writes_again,
          title: "It writes",
          ticks: true,
          notes: """
          - The writer again, under the repo link, with both repos and the papers along the bottom
          - Everything quoted about the frontier models came from the reports listed there
          - Leave it running through the questions. Stop talking
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
