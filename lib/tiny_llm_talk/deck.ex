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
      minutes: 5,
      lands:
        "the room has voted, a language model is one function, and a transformer is one block repeated",
      slides: [
        %Slide{
          id: :the_vote,
          title: "flees, or flee?",
          activity: :verb_vote,
          steps: 2,
          notes: """
          On screen while the room arrives. Paste the join link in the chat
          and let the bars move; do not fill the silence. The second step
          lights the answer and every phone learns whether it agreed, and the
          room's record starts here. Everybody knew. Say, do not show: the
          rule is easy to name, the hard part is knowing which noun is the
          subject when a plural one sits right next to the blank. That is
          the talk.
          """
        },
        %Slide{
          id: :title,
          title: "Transformers from Scratch, in Elixir",
          notes: """
          Say the title once. The sentence under it is the one the whole
          talk is about, and the room has just voted on it.
          """
        },
        %Slide{
          id: :one_function,
          title: "A language model is one function",
          notes: """
          Input: the words so far. Output: 32 probabilities. State the frame
          here and never let go of it. Everything we build today goes inside
          the box. Say once: the simplest thing that fits in the box is a
          count table over adjacent pairs, and it fails exactly where the
          nearest noun lies. That is the baseline section 8 beats.
          """
        },
        %Slide{
          id: :the_architecture,
          title: "The transformer",
          steps: 2,
          notes: """
          Motivate it before building it. The stack: a word becomes a row,
          then the block, then probabilities. Inside the dashed box, attention
          gathers and a small MLP thinks, and the box repeats N times. Second
          step: N becomes 1, and the title says so; this is the one on this
          laptop, one block deep. Say, do not show: every frontier model uses
          these same pieces, and the labs say so in their own reports: GPT-4
          is
          "Transformer-based", Gemini
          "builds on Transformer decoders", DeepSeek-V3 is "still within the
          Transformer framework", Llama 4 is a mixture-of-experts one.
          Anthropic does not publish Claude's. If someone raises Mamba or
          Qwen3-Next: those swap most attention layers for a cheaper mixer
          and keep the rest, so the block you are about to read is still in
          them. The next slide is the one on this laptop.
          """
        },
        %Slide{
          id: :parameters,
          title: "The model I built",
          notes: """
          Every parameter table in the model, by stage, with its shape and
          how many floats it holds. Say what a parameter is: one float in one
          of these tables. Two tables on the way in, four square matrices in
          attention, and the MLP holds more than half. Every one starts
          random and training moves every one of them; nothing in here is
          written by hand. Say, do not show: one block deep, a single head
          wide, pure Elixir standard library with an empty deps list. The
          repo link is in the footer and stays there.
          """
        }
      ]
    },
    %Section{
      number: 1,
      title: "Words become numbers",
      minutes: 3,
      lands: "a grammar we own, 32 words, and the whole path once, fast",
      slides: [
        %Slide{
          id: :grammar,
          title: "A grammar we own",
          notes: """
          The rules on the left are quoted from the grammar module's own
          docs; four sentences it wrote on the right, one per structure.
          Say the two rules that matter: a subject agrees with its verb, and
          a relative clause's verb agrees with the head noun, not whatever is
          nearest. We wrote the grammar, so "did it learn agreement" is a
          measurement, not a vibe. Nobody knows that about a real corpus.
          """
        },
        %Slide{
          id: :vocabulary,
          title: "Thirty-two words",
          notes: """
          One word is one token is one integer; there is no tokenizer. Point at
          start and at the period: sequences begin with one and end with the
          other. Every word is lowercase, including the title.
          """
        },
        %Slide{
          id: :it_writes,
          title: "It writes",
          ticks: true,
          notes: """
          Starts paused; press normal when you are ready. The whole path once,
          fast, before we take it slowly. Left, the
          paragraph. Right, the forward pass for the word being written:
          integers, rows, query and keys, attention, the distribution, the
          pick. Those are the stages the next thirty minutes walk one at a
          time. Say only: fifteen thousand floats, pure Elixir, no library,
          and every one of those pictures is real. Slow it down if people
          lean in. Shuffle if a sentence is dull.
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
          The sentence alone first; it stays on top from here to the end of
          attention. Second step: take dogs, the word next to the blank. Look
          its integer up in a 32 by 32 table and take the row. The table
          starts random and the model moves the rows itself. All thirty-two
          floats are on the slide: this is the real dogs row from the
          checkpoint, not a sketch. Third step: the floats give way to a
          second row, the one for position six, counting the start token as
          zero. Attention on its own is a bag of words, so each position has
          a learned row of its own, added to the word's row, not appended to
          it: same width in, same width out, so nothing downstream has to
          know position exists. Sixteen positions, so the context length is
          16: say the number, it is the only hard limit in the model. Last
          step, the three lines that do all of it.
          """
        },
        %Slide{
          id: :forgets_the_words,
          title: "At this point the model has forgotten it saw words",
          notes: """
          Seven positions in, seven rows of thirty-two floats out. This grid is
          what attention actually sees. Nothing after this slide mentions a
          word until the very end, when we turn rows back into a distribution.
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
          Say "math break" out loud; two slides of arithmetic, then back to
          the model. Two lists, multiply pairwise, add. Big when they point the same way,
          near zero when unrelated, negative when opposed. That is the only
          arithmetic in attention.
          """
        },
        %Slide{
          id: :softmax_playground,
          title: "A softmax turns scores into a distribution",
          notes: """
          Five scores in, five shares out, always summing to one: that is a
          distribution, define it once. The words are just labels, none of
          them from the sentence. Drag a score up and its share grows while
          every other share shrinks; drag one far below the rest and its
          share goes to nearly nothing but never to zero. Say the formula
          once, plainly: e to the score, divided by the sum of all of them;
          e to anything is positive, which is why the shares are. End of the
          break; the next slide puts both pieces to work.
          """
        },
        %Slide{
          id: :learn_the_lookup,
          title: "Attention: ask, offer, hand over",
          steps: 10,
          notes: """
          The formula alone and large first; let them look at it. Then it
          shrinks to the top and stands as the title, and one symbol arrives
          per step, each with its shape. The input is the grid from the last slide, seven rows of
          thirty-two. Three learned matrices, thirty-two square. Query is
          what this position is looking for, key is what it advertises, value
          is what it hands over if chosen; each is the input times a matrix,
          so seven by thirty-two again. Q times K transposed is every dot
          product at once, seven by seven; divide by root d, the width of a
          key, so the softmax does not saturate. In the paper that is d_k,
          not d_model; with one head and no slicing they are the same 32
          here, and frontier models slice the embedding across heads; softmax each row into a distribution; blend the
          values, and the result is the input's shape, which is what lets
          the residual add it back. The next slide runs it on a toy map by
          hand.
          """
        },
        %Slide{
          id: :fuzzy_map,
          title: "A small example, by hand",
          steps: 5,
          notes: """
          The formula from the last slide, on five keys with two-number
          vectors, small enough to check by eye. The toy: each key's vector
          is [how much of an animal, how plural], and each value is how plural
          that key is, so the blend answers how plural the query is. Pick a
          query; the keys and their values, 0 for singular and 1 for plural
          as the header says, are there from the start. Then one column a
          step: Q dot every K; divide by root d, d is two here, and softmax
          into a distribution; each value times its weight, and the whole
          formula lights up; and last the sum, which is the answer: 1.00,
          geese is plural, and the map never held it. Then pick sleepy: no
          animal, no number, every score zero, so the softmax spreads evenly
          and the answer is 0.50, which is the honest "no idea". Query with goose or geese, which are not keys, and it
          still answers sensibly. That is the whole trick, and the next slide
          is the same thing in sixteen lines.
          """
        },
        %Slide{
          id: :attention_code,
          title: "One head of attention, sixteen lines",
          steps: 7,
          notes: """
          The formula again, now over the real code, quoted from the repo,
          not simplified, and beside it the real numbers for the sentence
          at each stage. Step through: the three projections, with the
          input's seven rows and the three learned matrices beside them,
          thirty-two square each; then the Q K transposed matmul, and the seven by seven scores appear, signed,
          already divided by root d so the softmax does not saturate as
          vectors grow; the mask, and the future is struck out, every cell
          above the diagonal; the softmax, and the scores become a
          distribution per row, summing to one; the blend, and the context
          appears under it, seven rows of thirty-two again, the input's
          shape. One head; frontier models run many side by side. Say out
          loud: every position at once in one matrix multiply, no loop over
          time, which is why this scales and a recurrent network did not.
          Let them read; say only what each block is for.
          """
        },
        %Slide{
          id: :attention_bet,
          title: "Where will the blank look?",
          activity: :attention_bet,
          steps: 2,
          notes: """
          Ask before showing. Most rooms say llama, because that is the answer
          to the grammar question. The model says who; the reveal shows the
          last row of the heatmap from the last slide, the dogs position,
          because the blank has no row: it is predicted from the output of
          the last position given. Say that plainly, it is the question
          someone will ask. Being wrong together is what makes the
          walkthrough land.
          """
        },
        %Slide{
          id: :walkthrough,
          title: "LLMs are weird",
          notes: """
          Starts on dogs, the position predicting the blank, with the whole
          row there at once: its query dots every key, nothing to mask
          since it is last, the softmax turns scores into a distribution.
          Real numbers from the checkpoint. Most of its weight goes to who,
          not llama, which is the weird part. Say, do not show: who in turn
          attends to llama, so the blank reaches the subject in two hops,
          through the word that stands for it. Click who to show that hop,
          and the mask hiding its future.
          """
        }
      ]
    },
    %Section{
      number: 4,
      title: "The rest of the block",
      minutes: 4,
      lands: "normalize, think, add: what makes a layer stackable",
      slides: [
        %Slide{
          id: :lid_off,
          title: "The transformer in this talk",
          notes: """
          The picture from slide 3 again, with the 1, and the dashed box
          named: the block. Attention is done; what is left of the block is
          the two normalizations and the neural network, and the arrows
          between them. The next slide is the block as code.
          """
        },
        %Slide{
          id: :block_code,
          title: "Block.forward",
          notes: """
          The whole block is one function, twenty-two lines, and the
          diagram was drawn from it: norm, attention, add, norm, network,
          add. Let them read it once whole; the next three slides take the
          lines that are new one at a time.
          """
        },
        %Slide{
          id: :normalization,
          title: "Normalization",
          notes: """
          The first of the two normalizations, on the dogs row. Divide the
          row by its root mean square, so every row comes in at the same
          size whatever attention did to it; then multiply by g, thirty-two
          learned floats, so the model can choose the size it wants per
          column. Three strips: the row as it arrived, the row at rms one,
          the row after g. Nothing blows up and nothing vanishes, which is
          what lets the layers stack. The code is the block's forward pass;
          the two lit lines are the two norms.
          """
        },
        %Slide{
          id: :neural_network,
          title: "The neural network",
          notes: """
          Two weighted sums with a ReLU between, per position, no mixing
          between positions: attention gathered, this is where the model
          thinks about what it gathered. 32 wide in, 128 hidden, 32 out.
          The hidden strip is four rows of thirty-two; the dark cells are
          the zeros the ReLU made, and there are a lot of them. Half the
          parameters of the model are these two matrices.
          """
        },
        %Slide{
          id: :residual,
          title: "The residual",
          steps: 2,
          notes: """
          The block never replaces the row; it adds to it. First step: the
          dogs row, what attention returned for it, and their sum; the sum
          still looks like the row, with attention's contribution on top.
          Second step: the same for the network. Why: a layer that can only
          add starts out as the identity, so stacking a hundred of them
          cannot lose the input, and every gradient has a straight path
          back through the additions. This is the trick that made deep
          networks trainable, and the transformer inherits it. Next: back
          to words.
          """
        }
      ]
    },
    %Section{
      number: 5,
      title: "Back to words",
      minutes: 3,
      lands: "rows become a distribution, the loop, and the knob",
      slides: [
        %Slide{
          id: :back_to_words,
          title: "Thirty-two floats become thirty-two probabilities",
          notes: """
          One more weighted sum takes the last row from 32 wide to 32 scores,
          one per word, and the same softmax turns them into a distribution. Bars for
          the probe: flees is the top of all thirty-two.
          """
        },
        %Slide{
          id: :one_word_at_a_time,
          title: "One word at a time",
          notes: """
          Say the loop once: ask the function, pick a word, append it, ask
          again, stop at the period; the whole prefix is re-read every time,
          so a model cannot take back what it has said. Then press next and
          the room watches the bars, then the pick, then the append. Every
          press is a fresh draw, so it will surprise you too.
          Press restart if it wanders. Three or four words are enough. Then
          the slider: temperature divides the scores before the softmax.
          Below one commits, above one wanders, zero is argmax. Turn it to
          zero and press next: the same word every time. Turn it past two:
          structure goes before content.
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
          title: "Training, live",
          steps: 5,
          notes: """
          Press start, then talk over it; it takes about seventy seconds.
          Same config and seed as the checkpoint, so the loss it lands on is
          the loss every figure in this deck was drawn from, and the slide
          says whether it matched. While it draws, step the five beats
          beside it. The corpus is sentences the grammar wrote, two thousand
          of them, so every prefix comes with the word that really followed.
          Take a prefix; run the model for its 32 probabilities; measure how
          surprised it was by the real word; nudge every number in the
          direction that makes the surprise smaller; repeat a few hundred
          times. No chain rule on
          screen; the nudges are derived by hand in the repo, with no
          autodiff to hide behind. Name the two lines: it starts at knowing
          nothing, ln 32, and the dashed line is the best anything can do
          seeing only the previous word. The point lands when the curve
          goes well under the dashed line: it is using information the
          previous word does not carry.
          """
        }
      ]
    },
    %Section{
      number: 7,
      title: "Did it learn it",
      minutes: 2,
      lands: "the whole thing again, the sentence again, and it writes",
      slides: [
        %Slide{
          id: :all_of_it_again,
          title: "This was all of it",
          steps: 5,
          notes: """
          The same seven lines from the opener, read out loud now. A word
          becomes a row, position is added. The block: attention gathers,
          the residual keeps, the MLP thinks. One more norm. Thirty-two floats
          become thirty-two probabilities. Nobody in the room needed a
          library to follow that.
          """
        },
        %Slide{
          id: :what_is_not_here,
          title: "What is not here, and what is",
          steps: 2,
          notes: """
          Not here: a tokenizer, a GPU, multi-head, depth, KV caching (the
          whole prefix is re-read every word; a real model keeps the keys
          and values it already computed). Here: embeddings, learned positions, scaled dot-product
          attention, a causal mask, residuals, RMSNorm, an MLP, temperature
          sampling. The loss and the hand-written gradients are in the repo
          but not in the talk, so they stay off the list. Every one of these
          is the same thing a frontier model does.
          The difference is thirteen orders of magnitude and a tokenizer.
          """
        },
        %Slide{
          id: :the_sentence_again,
          title: "the llama who chases the dogs flees",
          notes: """
          The bracket drawn, and the probability the model puts on flees.
          """
        },
        %Slide{
          id: :it_writes_again,
          title: "It writes",
          ticks: true,
          notes: """
          The writer again, under the repo link, with both repos and the
          papers along the bottom where its controls were. Everything quoted
          about the frontier models came from the reports listed there.
          Leave it running through the questions. Stop talking.
          """
        }
      ]
    }
  ]

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
