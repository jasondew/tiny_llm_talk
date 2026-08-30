defmodule TinyLlmTalk.Deck do
  @moduledoc """
  The deck as data: the eight sections of `docs/talk-outline.md`, in order,
  with every slide the outline names.

  Nothing here draws anything. A slide is a title, a note, and a count of
  reveal steps; `TinyLlmTalkWeb.SlideComponents` matches on the id to draw it.
  Keeping the arc as a list means the running order is one readable file that
  can be diffed against the outline, rather than something recovered by
  reading templates.
  """

  alias TinyLlmTalk.{Section, Slide}

  @sections [
    %Section{
      number: 0,
      title: "Cold open",
      minutes: 3,
      lands: "the sentence, and the question it asks",
      slides: [
        %Slide{
          id: :the_sentence,
          title: "the llama who chases the dogs ____",
          notes: """
          Ask the room: flees or flee? Everyone knows. Nobody can say how they
          know in fewer than a paragraph. Wait for an answer before advancing.
          """
        },
        %Slide{
          id: :the_bracket,
          title: "The word that decides it is five back",
          steps: 3,
          notes: """
          A plural noun sits right next to the blank pointing the wrong way.
          Say the line out loud rather than putting it on the slide: that
          bracket is the talk, and we are going to build, from nothing, a
          program that draws it.
          """
        },
        %Slide{
          id: :what_you_leave_with,
          title: "You will leave able to explain how a transformer works",
          steps: 3,
          notes: """
          The promise, before the constraints. Attention is the part they will
          be able to describe out loud: each position looks back at the ones
          before it, scores them, and pulls in what it needs. Everything else in
          the talk is in service of those three verbs.
          """
        },
        %Slide{
          id: :from_nothing,
          title: "What from nothing means",
          steps: 5,
          notes: """
          Pure Elixir standard library. No Nx, no Axon, no hex packages, mix.exs
          deps are empty. 15,104 parameters. Trains in under 30 seconds on a
          laptop. Every gradient written out by hand and checked. The repo link
          goes in the footer now and stays there.
          """
        }
      ]
    },
    %Section{
      number: 1,
      title: "The setup",
      minutes: 4,
      lands: "32 words, a grammar we own, the one function frame",
      slides: [
        %Slide{
          id: :vocabulary,
          title: "Thirty-two words",
          notes: """
          One word is one token is one integer; there is no tokenizer. Point at
          start and at the period: sequences begin with one and end with the
          other.
          """
        },
        %Slide{
          id: :grammar,
          title: "A grammar we own",
          notes: """
          Three or four example sentences with the structure visible, and the
          two rules that matter: subjects agree with verbs, and a relative
          clause's verb agrees with the head noun. We own the training data
          because then we know the right answer to every question we ask the
          model, which no one does with a real corpus.
          """
        },
        %Slide{
          id: :one_function,
          title: "A language model is one function",
          notes: """
          Input: the words so far. Output: 32 probabilities. State the frame
          here and never let go of it. This slide comes back three more times
          with a different box each time.
          """
        },
        %Slide{
          id: :how_we_score_it,
          title: "How surprised is it?",
          steps: 3,
          notes: """
          Held-out loss is how surprised the model is by sentences it has not
          seen; lower is better. Two lines appear on every loss chart from here:
          ln(32) = 3.466 is knowing nothing, 1.9021 is the best possible score
          for anything that sees only the previous word. Do not explain entropy.
          Say surprise and move on.
          """
        }
      ]
    },
    %Section{
      number: 2,
      title: "Bigram",
      minutes: 6,
      lands: "counting works, until the answer is more than one word back",
      slides: [
        %Slide{
          id: :counting_pairs,
          title: "Count every adjacent pair",
          notes: """
          Primer beat: a matrix is a table. Rows are things, columns are things,
          cells are numbers about the pair. Show the counts for one row, chases,
          as a plain list first.
          """
        },
        %Slide{
          id: :bigram_heatmap,
          title: "Thirty-two by thirty-two",
          steps: 4,
          notes: """
          Read three cells out loud: chases is followed by the or a, nothing
          else. The period is followed by nothing. llama is followed by a
          singular verb, llamas by a plural one.
          """
        },
        %Slide{
          id: :bigram_box,
          title: "The box, with a count table in it",
          notes: """
          To predict, look up the row for the last word and pick from it.
          """
        },
        %Slide{
          id: :bigram_wins,
          title: "Where it wins",
          notes: """
          It gets determiners, it gets the period, it gets agreement when the
          noun is right there. Ten generated sentences, most of them fine.
          """
        },
        %Slide{
          id: :bigram_fails,
          title: "Where it cannot",
          steps: 3,
          notes: """
          The probe. The bigram's context is dogs and nothing else. Its row for
          dogs says flee. On the distractor case it scores 55.3%, the base rate
          of the plural forms, so it is guessing. Show the row.
          """
        },
        %Slide{
          id: :the_floor,
          title: "1.904",
          notes: """
          Computed from the grammar itself: the best score anything can reach
          seeing only the previous word. A count table with enough data sits on
          it. Nothing that sees one word can beat this. That sentence is the
          setup for the next section's punchline.
          """
        }
      ]
    },
    %Section{
      number: 3,
      title: "Neural bigram",
      minutes: 7,
      lands: "learning does not help if the context is the problem",
      slides: [
        %Slide{
          id: :what_does_learning_buy,
          title: "If counting is optimal, what does learning buy?",
          notes: """
          Answer up front: for this model, nothing. We build it anyway because
          it introduces every part that survives into the transformer.
          """
        },
        %Slide{
          id: :embeddings,
          title: "A word becomes a point",
          notes: """
          Replace the word's integer with a row of 32 floats, looked up from a
          table. The table starts random. A vector is a point; words that behave
          the same should end up near each other, and the model will move them
          there on its own.
          """
        },
        %Slide{
          id: :linear_and_softmax,
          title: "Weighted sums, then softmax",
          steps: 4,
          notes: """
          Every output is a weighted sum of the inputs, and the weights are what
          gets learned. Say that once, here, and then stop saying it. Softmax
          turns 32 scores into 32 probabilities that sum to one.
          """
        },
        %Slide{
          id: :training,
          title: "Training, all of it",
          steps: 4,
          notes: """
          Loss is surprise at the right answer. Every parameter has a slope:
          nudge it and the loss goes up or down. Move every parameter a small
          step downhill. Repeat a few hundred times. The slope is computed by
          hand here, the derivation is in docs/backprop.md, and a
          finite-difference test checks every one of them. No chain rule on
          screen.
          """
        },
        %Slide{
          id: :demo_training_loss,
          title: "Demo: watch the loss fall",
          notes: """
          DEMO 1. Train the Embedder live, about ten seconds. It starts at 3.466
          and falls to about 1.944, just above the 1.9021 line. It does not
          cross the line. It cannot. Static fallback slide is one keypress away.
          """
        },
        %Slide{
          id: :pca_scatter,
          title: "What the embeddings learned",
          notes: """
          Nouns cluster tightly; the first axis is a noun detector. Adjectives
          and determiners cluster. Verbs do not cluster at all, and that is
          honest: verb number lives in the output table, not the input one,
          because nothing after a verb depends on its number. CUT THIS SLIDE
          FIRST if the talk is running long.
          """
        },
        %Slide{
          id: :learning_was_not_the_problem,
          title: "Zero, again",
          notes: """
          Identical to the count table, to the decimal, because it sees the same
          one word and gives the same answer. Learning was never the problem.
          Context is the problem.
          """
        }
      ]
    },
    %Section{
      number: 4,
      title: "Attention",
      minutes: 12,
      lands: "each position looks back and pulls in what it needs",
      slides: [
        %Slide{
          id: :what_we_want,
          title: "Reach back past the distractor",
          notes: """
          The blank needs to reach back to llama, past dogs, past the, past
          chases. A fixed window would not do it; the subject can be anywhere.
          We want the blank to look at every earlier word and decide for itself
          which ones matter.
          """
        },
        %Slide{
          id: :dot_product,
          title: "A dot product is a similarity score",
          steps: 3,
          notes: """
          Two vectors, multiply pairwise, add. Big when they point the same way,
          near zero when unrelated. And we can learn what similar should mean.
          """
        },
        %Slide{
          id: :query_key_value,
          title: "Query, key, value",
          steps: 4,
          notes: """
          In words before symbols. A query is what this position is looking for.
          A key is what this position is advertising. A value is what this
          position hands over if chosen. Three weighted sums, three learned
          weight tables: Wq, Wk, Wv.
          """
        },
        %Slide{
          id: :scores,
          title: "Score every earlier word",
          steps: 4,
          notes: """
          Take the blank's query, dot it against every earlier key. One number
          per earlier word. Divide by the square root of the width so the
          numbers stay tame. Softmax across them: now it is a probability of
          where to look.
          """
        },
        %Slide{
          id: :pulling_in,
          title: "Pull in what you chose",
          notes: """
          Multiply each earlier position's value by its weight and add them up.
          The blank now holds a blend of the words it chose to look at. One more
          weighted sum, Wo, and out to the same softmax as before.
          """
        },
        %Slide{
          id: :causal_mask,
          title: "The causal mask",
          notes: """
          Every position predicts the next word at once, so each must only see
          what came before it. Future positions get a score of minus a billion
          before the softmax, which rounds to zero attention. Show the triangle.
          """
        },
        %Slide{
          id: :positions,
          title: "Attention is a bag until you tell it otherwise",
          notes: """
          As described it does not know that llama came before dogs. So each
          position also has a learned vector added to its word embedding. 16
          positions, 16 vectors. Now the model can tell the noun near the start
          from the noun near the end.
          """
        },
        %Slide{
          id: :attention_code,
          title: "The six lines that matter",
          steps: 7,
          notes: """
          This is where the nothing is hidden claim is cashed. Step through it a
          line at a time. Do not read it out; let them read it while you say
          what each block is for.
          """
        },
        %Slide{
          id: :demo_attention_heatmap,
          title: "Demo: where the blank looks",
          notes: """
          DEMO 2. Rendered from the shipped checkpoint, not trained live. Rows
          are positions predicting, columns are positions looked at. The lower
          triangle is filled, the upper is empty.
          """
        },
        %Slide{
          id: :reading_the_heatmap,
          title: "Read it honestly",
          steps: 3,
          notes: """
          The blank attends 0.55 to who, 0.17 to dogs, 0.13 to llama. It is not
          looking at llama, and it does not need to: it read the subject's
          number off chases, which already agrees with the head noun. The point
          is not that it draws the bracket we imagined. The point is that it is
          visibly structured, not flat, and it gets the answer.
          """
        },
        %Slide{
          id: :the_number,
          title: "Zero, zero, and sixty-nine",
          notes: """
          Against 55.3% for both bigrams. The one-word models could not do
          better than chance when a noun intervened; this one can. Do not quote
          the 91.4% aggregate; a third of the probes are free for every model.
          """
        },
        %Slide{
          id: :attention_sink,
          title: "It found the attention sink by itself",
          notes: """
          The first verb position, with nothing useful behind it, puts 0.96 of
          its attention on start. Production transformers do exactly this and it
          has a name. 15,104 parameters reproduced it unprompted. One slide, one
          laugh, move on.
          """
        }
      ]
    },
    %Section{
      number: 5,
      title: "The rest of the block",
      minutes: 6,
      lands: "residual, MLP, and why depth would help",
      slides: [
        %Slide{
          id: :architecture,
          title: "The box with its lid off",
          steps: 6,
          notes: """
          Embedding plus position, then attention, then MLP, then the output.
          Two arrows that go around: the residuals. Two small boxes: the norms.
          """
        },
        %Slide{
          id: :residuals,
          title: "Add, do not replace",
          notes: """
          Keep what you had, add what you learned. Without this, information at
          the input has to survive every layer to reach the output; with it, the
          default is to pass through.
          """
        },
        %Slide{
          id: :mlp,
          title: "A place to think about what you gathered",
          notes: """
          Attention gathers; it cannot compute much about what it gathered. Two
          weighted sums with a ReLU between, applied to each position on its
          own. 32 in, 128 in the middle, 32 out. Half the parameters are here.
          Do not go further than that sentence.
          """
        },
        %Slide{
          id: :rmsnorm,
          title: "RMSNorm, one line",
          notes: """
          Rescale each position's vector to a fixed size before attention and
          before the MLP so nothing blows up. Learned gain. Skip the formula.
          """
        },
        %Slide{
          id: :two_hop,
          title: "The model drew the argument for depth",
          steps: 4,
          notes: """
          The who row of the same heatmap. who attends 0.57 to llama; on the
          mirror probe, the dogs who chase the llama, it attends 0.65 to dogs.
          The who position has gathered the head noun into itself, and the blank
          attends to who. So half of a two-hop route exists, and with one block
          it cannot use the second hop, because both hops happen at once. A
          second block would read who after it had already gathered the subject.
          That is what depth buys.
          """
        },
        %Slide{
          id: :scale,
          title: "Same shape, bigger numbers",
          steps: 5,
          notes: """
          One head becomes many, one block becomes dozens, 32 words becomes a
          hundred thousand tokens and a tokenizer, 16 positions becomes a
          hundred thousand. Nothing on this list is a new idea. Do not put a
          frontier parameter count on the slide; say the ratio out loud.
          """
        }
      ]
    },
    %Section{
      number: 6,
      title: "Generating",
      minutes: 5,
      lands: "the loop, and temperature",
      slides: [
        %Slide{
          id: :the_loop,
          title: "Ask, pick, append, ask again",
          steps: 4,
          notes: """
          Start with start. Ask the function. Pick a word. Append it. Stop at
          the period. Say the uncomfortable part: no state carries between
          steps, the whole prefix is re-read every time, and that is why a model
          cannot take back something it has already said.
          """
        },
        %Slide{
          id: :temperature,
          title: "Temperature",
          notes: """
          Divide the scores by a number before the softmax. Below 1 sharpens
          toward the top choice, above 1 flattens toward uniform, zero is
          argmax.
          """
        },
        %Slide{
          id: :demo_temperature,
          title: "Demo: the slider",
          notes: """
          DEMO 3. Range 0 to 3. At 0 it says one sentence forever, the fast dogs
          and the llamas are fast, which is not in the training set. At 1 it is
          89.5% grammatical and 90.5% distinct. At 3 it is word salad. Show the
          failure modes coming apart in order: a llama is dog loses meaning
          first, sleepy fast goose dogs flee loses the determiner last.
          Structure goes before content.
          """
        },
        %Slide{
          id: :the_tradeoff,
          title: "Correct and boring, or varied and wrong",
          notes: """
          Grammaticality against distinctness as temperature rises. This is the
          slide people photograph. Pause on it.
          """
        }
      ]
    },
    %Section{
      number: 7,
      title: "Close",
      minutes: 3,
      lands: "what is not here, and what is",
      slides: [
        %Slide{
          id: :what_is_not_here,
          title: "What is not here, and what is",
          steps: 2,
          notes: """
          Not here: autodiff, a tokenizer, a GPU, multi-head, depth,
          dependencies. Here: embeddings, learned positions, scaled dot-product
          attention, causal mask, residuals, RMSNorm, an MLP, cross-entropy,
          hand-written backprop with a finite-difference check, temperature
          sampling. Every one of these is the same thing a frontier model does.
          """
        },
        %Slide{
          id: :the_sentence_again,
          title: "the llama who chases the dogs flees",
          notes: """
          The bracket drawn, and the probability the model puts on flees. Repo
          link, large. Stop talking.
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
