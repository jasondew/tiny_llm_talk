defmodule TinyLlmTalk.Deck do
  @moduledoc """
  The deck as data: the ten sections of `docs/talk-outline.md`, in order,
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
      lands: "it trains, it writes, this is all of it, and none of it is hidden",
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
          id: :the_architecture,
          title: "What a transformer is",
          steps: 4,
          notes: """
          Motivate it before building it. One block, repeated: attention,
          then a small MLP, then the same again. The frontier models say
          so in their own reports: GPT-4 is "Transformer-based", Gemini
          "builds on Transformer decoders", DeepSeek-V3 is "still within the
          Transformer framework", Llama 4 is a mixture-of-experts one.
          Anthropic does not publish Claude's. If someone raises Mamba or
          Qwen3-Next: those swap most attention layers for a cheaper mixer
          and keep the rest, so the block you are about to read is still in
          them. The one on this laptop is one block deep and one head wide.
          """
        },
        %Slide{
          id: :live_training,
          title: "Training, live",
          notes: """
          Press start as you walk up, then introduce yourself over it. Same
          config and seed as the checkpoint, so the loss it lands on is the
          loss every later slide was rehearsed on, and the slide says whether
          it matched. Point at it once, in the last ten seconds: it started
          at knowing nothing and went under the best any one-word model can
          do. Do not explain the chart yet.
          """
        },
        %Slide{
          id: :it_writes,
          title: "It writes",
          ticks: true,
          notes: """
          Let it run. Left, the paragraph. Right, the forward pass for the
          word being written: integers, rows, query and keys, attention, the
          distribution, the pick. Say only: fifteen thousand floats, pure
          Elixir, no library, and every one of those pictures is real. Slow
          it down if people lean in. Shuffle if a sentence is dull.
          """
        },
        %Slide{
          id: :all_of_it,
          title: "This is all of it",
          notes: """
          Say it, do not show it: seven lines, from a word to a distribution.
          Line five opens into eight more, and one of those into sixteen.
          That is the entire model, and forty minutes from now the room reads
          all of it.
          """
        },
        %Slide{
          id: :from_nothing,
          title: "What from nothing means",
          steps: 5,
          notes: """
          Pure Elixir standard library. No Nx, no Axon, deps are empty. About
          fifteen thousand parameters. Trains in about a minute, as you saw.
          Every gradient written out and checked. The repo link is in the
          footer now and stays there.
          """
        }
      ]
    },
    %Section{
      number: 1,
      title: "Words become numbers",
      minutes: 3,
      lands: "32 words, a grammar we own, and the room was a language model for a moment",
      slides: [
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
          id: :grammar,
          title: "A grammar we own",
          notes: """
          Four sentences with the structures visible, and the two rules that
          matter. We wrote the grammar, so "did it learn agreement" is a
          measurement, not a vibe. Nobody knows that about a real corpus.
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
          nearest noun lies. That is the baseline section 9 beats.
          """
        }
      ]
    },
    %Section{
      number: 2,
      title: "All the math there is",
      minutes: 2,
      lands: "a dot product is a similarity score, a softmax is a budget",
      slides: [
        %Slide{
          id: :dot_product,
          title: "A dot product is a similarity score",
          steps: 3,
          notes: """
          Two lists, multiply pairwise, add. Big when they point the same way,
          near zero when unrelated, negative when opposed. That is the only
          arithmetic in attention.
          """
        },
        %Slide{
          id: :softmax_playground,
          title: "A softmax turns scores into a budget",
          notes: """
          Drag the slider. Five scores in, five shares out, always summing to
          one. The words are just labels, none of them from the sentence. Sharp means commit to the top score; soft means spread the
          budget. Say "budget" and "commit"; never say exponential.
          """
        }
      ]
    },
    %Section{
      number: 3,
      title: "Embedding and position",
      minutes: 3,
      lands: "a word is a row of floats, and position is added, not appended",
      slides: [
        %Slide{
          id: :a_word_is_a_row,
          title: "A word becomes a row of floats",
          steps: 2,
          notes: """
          Look the word's integer up in a 32 by 32 table and take the row. The
          table starts random and the model moves the rows itself. This is the
          real llama row from the checkpoint, not a sketch.
          """
        },
        %Slide{
          id: :positions_added,
          title: "Position is another row, added on",
          steps: 2,
          notes: """
          Attention on its own is a bag of words. So each position has a
          learned vector of its own, added to the word's row, not appended to
          it. Sixteen rows, so the context length is 16: say the number, it is
          the only hard limit in the model. Same width, which is why nothing
          downstream has to know.
          """
        },
        %Slide{
          id: :forgets_the_words,
          title: "From here on the model has forgotten it saw words",
          notes: """
          Seven positions in, seven rows of thirty-two floats out. This grid is
          what attention actually sees. Nothing after this slide mentions a
          word until the very end, when we turn rows back into a distribution.
          """
        }
      ]
    },
    %Section{
      number: 4,
      title: "Attention, from Map",
      minutes: 10,
      lands: "a fuzzy lookup: score every key, budget the scores, blend the values",
      slides: [
        %Slide{
          id: :map_get,
          title: "Start with a lookup you already trust",
          steps: 2,
          notes: """
          A map from words to one fact about each: is it plural. Map.get
          finds the one key equal to the query and hands back its value; ask
          for geese and it is nil. Say the line: attention is Map.get with
          equal replaced by similar. The next slide does exactly that.
          """
        },
        %Slide{
          id: :fuzzy_map,
          title: "Now make it fuzzy",
          steps: 3,
          notes: """
          Pick a query word. Step one: score every key with a dot product.
          Step two: softmax the scores into a budget. Step three: blend the
          values by that budget. Query with goose, which is not in the map, and
          it still answers sensibly. That is the whole trick.
          """
        },
        %Slide{
          id: :learn_the_lookup,
          title: "Then let it learn what to ask, offer, and hand over",
          steps: 4,
          notes: """
          Query is what this position is looking for. Key is what it
          advertises. Value is what it hands over if chosen. Each is the
          position's row times a learned table. Three matrices, and the fuzzy
          map is now an attention head.
          """
        },
        %Slide{
          id: :attention_code,
          title: "The whole head, sixteen lines",
          steps: 7,
          notes: """
          Quoted from the repo, not simplified. Step through: the three
          projections, the dot products all at once, the scale, the mask, the
          softmax, the blend. Let them read; say only what each block is for.
          """
        },
        %Slide{
          id: :three_details,
          title: "Three details do all the work",
          steps: 3,
          notes: """
          Divide by the square root of the width so the softmax does not
          saturate as vectors grow. Mask the future before the softmax so the
          rows still sum to one; flip the toggle to show what leaks without it.
          And every position runs at once in one matrix multiply, no loop over
          time, which is why this scales and a recurrent network did not.
          """
        },
        %Slide{
          id: :attention_bet,
          title: "Where will the blank look?",
          activity: :attention_bet,
          steps: 2,
          notes: """
          Ask before showing. Most rooms say llama, because that is the answer
          to the grammar question. The model says who. Being wrong together is
          what makes the walkthrough land.
          """
        },
        %Slide{
          id: :walkthrough,
          title: "One position, all the way through",
          steps: 4,
          notes: """
          Starts on who, so the mask has something to hide. Step through: its
          query dots every key, the future gets struck out, the softmax turns
          scores into a budget. Real numbers from the checkpoint. Then click
          dogs, the position predicting the blank: most of its budget goes to
          who.
          """
        }
      ]
    },
    %Section{
      number: 5,
      title: "Look at what it did",
      minutes: 5,
      lands: "the sink, who gathers the subject, and half a route it cannot finish",
      slides: [
        %Slide{
          id: :heatmap,
          title: "Every position at once",
          notes: """
          Rows predict, columns are looked at. The upper triangle is empty,
          exactly as the mask says it must be. Let them find the bright cells
          before you name them.
          """
        },
        %Slide{
          id: :read_it_honestly,
          title: "Read it honestly",
          steps: 3,
          notes: """
          The blank attends most to who, then dogs, then llama. It is not
          looking at llama and it does not need to: chases already agrees with
          the head noun. The point is that the pattern is structured rather
          than flat, and it gets the answer.
          """
        },
        %Slide{
          id: :attention_sink,
          title: "It found the attention sink by itself",
          notes: """
          The first verb has nothing useful behind it, so it dumps its
          attention on start. Production transformers do exactly this and it
          has a name. Fifteen thousand parameters reproduced it unprompted.
          One slide, one laugh, move on.
          """
        },
        %Slide{
          id: :half_a_route,
          title: "The model drew the argument for depth",
          steps: 4,
          notes: """
          The who row gathers llama; on the mirror sentence it gathers dogs.
          The blank attends to who. So half of a two-hop route exists, and one
          block cannot use the second hop, because both hops happen at once. A
          second block would read who after it had gathered the subject. That
          is what depth buys, drawn by the model.
          """
        },
        %Slide{
          id: :audience_sentence,
          title: "Your sentence",
          activity: :sentence,
          notes: """
          Let a few land, then tap one to put it on the screen with its
          attention map. Any prefix works; the vocabulary is the only thing
          they can say. If nobody sends anything, type one yourself.
          """
        }
      ]
    },
    %Section{
      number: 6,
      title: "The rest of the block",
      minutes: 3,
      lands: "residual, RMSNorm, MLP: the plumbing that makes a layer stackable",
      slides: [
        %Slide{
          id: :lid_off,
          title: "The box, with its lid off",
          steps: 6,
          notes: """
          Embedding plus position, then attention, then the MLP, then out.
          Two arrows go around the middle: the residuals. Two small boxes: the
          norms. Everything on this slide except three words you have already
          seen.
          """
        },
        %Slide{
          id: :plumbing,
          title: "Three pieces of plumbing",
          steps: 3,
          notes: """
          Residual: add what attention returned to what was there, do not
          replace it. RMSNorm: rescale each row to a fixed size so nothing
          blows up. MLP: two weighted sums with a ReLU between, per position,
          32 to 128 to 32, where the model thinks about what it gathered. One
          sentence each and stop.
          """
        }
      ]
    },
    %Section{
      number: 7,
      title: "Back to words",
      minutes: 4,
      lands: "rows become a distribution, the loop, and the knob",
      slides: [
        %Slide{
          id: :back_to_words,
          title: "Thirty-two floats become thirty-two probabilities",
          notes: """
          One more weighted sum takes the last row from 32 wide to 32 scores,
          one per word, and the same softmax turns them into a budget. Bars for
          the probe: flees is the top of all thirty-two.
          """
        },
        %Slide{
          id: :the_loop,
          title: "Ask, pick, append, ask again",
          steps: 4,
          notes: """
          Start with start. Ask the function. Pick a word. Append it. Stop at
          the period. No state carries between steps; the whole prefix is
          re-read every time, which is why a model cannot take back what it
          has already said.
          """
        },
        %Slide{
          id: :one_word_at_a_time,
          title: "One word at a time",
          notes: """
          Press next and the room watches the bars, then the pick, then the
          append. Every press is a fresh draw, so it will surprise you too.
          Press restart if it wanders. Three or four words are enough.
          """
        },
        %Slide{
          id: :temperature_dial,
          title: "The knob",
          notes: """
          Divide the scores by a number before the softmax. Below one commits,
          above one wanders, zero is argmax. Turn it to zero: one sentence
          forever, and it is not in the corpus. Turn it past two: structure
          goes before content.
          """
        },
        %Slide{
          id: :spot_the_human,
          title: "One of these is human",
          activity: :spot_the_human,
          steps: 2,
          notes: """
          One sentence from the grammar, two from the model that never appeared
          in training. Vote. The point is not that the model wins; it is that
          the room cannot tell, and that the model's are new sentences, not
          recalled ones. CUT THIS SECOND if running long.
          """
        }
      ]
    },
    %Section{
      number: 8,
      title: "Training, in one slide",
      minutes: 3,
      lands: "guess, measure, nudge, repeat; and tests for the math",
      slides: [
        %Slide{
          id: :training,
          title: "Training, all of it",
          steps: 4,
          notes: """
          Guess the next word. Measure how surprised you were by the real one.
          Nudge every number in the direction that makes the surprise smaller.
          Repeat a few hundred times. No chain rule on screen.
          """
        },
        %Slide{
          id: :loss_falls,
          title: "Watch it fall",
          steps: 2,
          notes: """
          The line draws itself on the second step. It starts at knowing
          nothing, ln 32, and ends well under the dashed line, which is the
          best anything can do seeing only the previous word. Going under it is
          the proof: it is using information the previous word does not carry.
          """
        },
        %Slide{
          id: :tests_for_math,
          title: "Tests for math",
          steps: 3,
          notes: """
          Every gradient is derived by hand. So how do you know it is right?
          Nudge each parameter up and down, measure the loss both ways, and
          compare the slope to what the derivation says. A plausible-looking
          wrong gradient still trains, slowly. This test is what caught the
          missing transpose.
          """
        }
      ]
    },
    %Section{
      number: 9,
      title: "Did it learn it",
      minutes: 3,
      lands: "only the model beats chance when a distractor gets in the way",
      slides: [
        %Slide{
          id: :the_number,
          title: "On the sentences where the nearest noun lies",
          notes: """
          Held-out probes, filtered to the ones with a distractor. The count
          table is at chance, because the only word it sees is the one pointing
          the wrong way. The model is not perfect and is not at chance. Do not
          quote the aggregate; a third of the probes are free for every model.
          """
        },
        %Slide{
          id: :rematch,
          title: "Rematch",
          activity: :rematch,
          steps: 2,
          notes: """
          A fresh sentence the model has never seen, plural subject this time.
          The room votes, then the model answers. Either way it is a good
          moment: the room beating the model is a laugh, the model beating the
          room is a better one.
          """
        },
        %Slide{
          id: :scoreboard,
          title: "How the room did",
          notes: """
          Every question the room answered, and whether it agreed with the
          answer. Read it out. Then the model's line on the same two verb
          questions. Whoever won, the humans had a grammar lesson and the model
          had fifteen thousand floats.
          """
        },
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
          Not here: autodiff, a tokenizer, a GPU, multi-head, depth,
          dependencies. Here: embeddings, learned positions, scaled dot-product
          attention, a causal mask, residuals, RMSNorm, an MLP, cross-entropy,
          hand-written backprop with a finite-difference check, temperature
          sampling. Every one of these is the same thing a frontier model does.
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
          The writer again, under the repo link. Leave it running through the
          questions. Stop talking.
          """
        },
        %Slide{
          id: :sources,
          title: "Sources",
          notes: """
          Both repos and the paper. Everything quoted about the frontier
          models came from the reports listed here. Step back one if you
          would rather have the writer running during questions.
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
