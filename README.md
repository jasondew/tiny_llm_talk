# Transformers from Scratch, in Elixir

The slide deck for a talk that takes one sentence, **the llama who chases the
dogs ____**, through one forward pass of a transformer written in pure Elixir,
and asks the room whether the blank is *flees* or *flee*. The deck is a Phoenix
LiveView app so that every number on every slide comes from the model itself.

The model is [`tiny_llm`](https://github.com/jasondew/tiny_llm): one block, one
head, 32 words, about fifteen thousand floats, and an empty dependency list.
This deck lives beside it rather than inside it, and depends on it by path, so
the model's `mix.exs` keeps that empty list. The talk's strongest claim is that
nothing is hidden; a reader who follows the repo link on a slide has to find
that claim intact.

    ~/src/
      tiny_llm/        the model, zero deps
      tiny_llm_talk/   this deck, path dep on ../tiny_llm

## Running it

    mix setup
    mix phx.server

- <http://localhost:4000/> the deck, for the screen
- <http://localhost:4000/presenter> the presenter view, for the laptop

Either window can hold the clicker; they follow each other over PubSub. Put the
deck on the projector and the presenter view on the laptop.

Keys: space or the arrows move, shift with an arrow skips a slide's steps and
moves a whole slide, `Home` and `End` jump to either end, and in the presenter
view `t` pauses the clock and `r` resets it.

Run it on localhost at the podium. Do not depend on conference wifi.

## The arc

Eight sections, thirty-one slides, in `docs/talk-outline.md`:

0. **Cold open.** The model trains itself, live, while the room arrives. The
   vote. A language model is one function. A transformer is one block, repeated.
1. **Words become numbers.** The vocabulary, the grammar we wrote, every
   parameter with its shape, and the model writing a paragraph with its forward
   pass drawn beside it.
2. **Embedding and position.** A word becomes a row of floats, position is
   added, and the model forgets it ever saw words.
3. **Attention.** A math break for the dot product and the softmax, then
   attention as a fuzzy lookup, by hand on a toy map and then as sixteen lines
   of real code with the real numbers beside them. Where will the blank look?
4. **The rest of the block.** Normalization, the activation, a feed forward
   network from one node up, and `Block.forward` walked a line at a time.
5. **Back to words.** Thirty-two floats become thirty-two probabilities, the
   whole pass in seven lines, and generating one word at a time with a
   temperature dial.
6. **Training.** The whole backward pass on screen for effect, then the five
   sentences that are all training is.
7. **Did it learn it.** What is not here, and the writer again under the repo
   link.

## The presenter view

The laptop screen shows, top to bottom: where the talk is and the clocks, the
line the section must land, the slide the room is looking at, and under it the
notes on the left with the next press on the right.

The big clock is the section's, against the minutes the outline gives it. Under
it is whether the talk is on pace, ahead, or behind, measured against the window
the outline gives the current slide. The whole talk's clock is the small line at
the bottom. Press `r` when you actually start talking.

Notes are written in `TinyLlmTalk.Deck` with three kinds of line:

    - a cue, a short phrase
    ! a point that must be made out loud; drawn lit and tagged "say"
    = term: a definition, for when accuracy matters

Every demo is driven from the presenter view: a control clicked in its preview
is a control turned on the projector.

## How a slide gets written

The running order is data, in `TinyLlmTalk.Deck`: every section, every slide,
with its notes and its count of reveal steps. It is one readable file that can
be diffed against the outline. The arc is one sentence going through one
forward pass, in the order `TinyLlm.Transformer.forward/2` runs it.

Drawing is separate. `TinyLlmTalkWeb.SlideComponents.slide/1` has one function
clause per slide id, and any slide without a clause falls through to a stub that
shows its title and notes on a hatched background.

To write a slide, add a clause:

```elixir
def slide(%{slide: %Slide{id: :the_floor}} = assigns) do
  ~H"""
  <section class="slide slide--centred">
    <h2 class="slide__title">{@slide.title}</h2>
    <.step n={2} step={@step}>...</.step>
  </section>
  """
end
```

`@step` is the current reveal step, `<.step n={2}>` shows its contents from step
two onward, and `steps:` in the deck says how many the slide has.

## Code slides

Code is quoted out of the sibling checkout at request time, never pasted:

```elixir
<.code path="lib/tiny_llm/attention.ex" range={198..213} step={@step}
       focus={[:all, 1..3, 5..7, 8..8, 9..13, 14..14, 16..16, :all]} />
```

`function={:forward}` takes a whole function instead of a range. `focus` is one
window per step; everything outside it dims rather than disappearing, because a
function is easier to follow when you can see where the current lines sit. The
caption names the file and lines, which is the claim the talk rests on: this is
the code, not a simplified version of it.

## Figures come from the model, not from a screenshot

`TinyLlmTalk.Model` holds the corpus, the count table, and the trained weights,
memoized behind an Agent and warmed at boot. Every figure is handed the plain
lists of floats the model returns, so a slide cannot quote a number this
checkpoint does not produce. Change the model and the slides change with it.

Colour has one job per figure. Magnitude (heatmaps, bars) gets a single hue from
the surface up to the accent. Text never wears a series colour.

## Checkpoints

    mix talk.train

Trains the neural bigram and the transformer and writes `priv/checkpoints/`,
which is committed. Both runs are seeded, so the attention weights the slides
quote reproduce exactly.

Without checkpoints the deck still runs; the figures that need trained weights
say so and tell you to run the task.

## It trains and writes, live

`TinyLlmTalk.Trainer` runs the checkpoint's training run again on the first
slide, in the same BEAM, with the same config and seed, while the room is
arriving. Because the model is pure Elixir over a seeded `:rand`, that is the
same run: the loss it lands on is the checkpoint's loss, and the slide says
whether it matched. Nothing else depends on it; every other slide reads the
checkpoint. Rehearse once on the laptop you present from; the match is a claim
about that machine.

`TinyLlmTalk.Writer` is the model writing a paragraph with its forward pass
drawn beside it, one phase of one word per frame. A slide marked `ticks: true`
gets a clock from `TinyLlmTalkWeb.Animation`; each window runs its own, and
they agree because a frame is a pure function of its number and a seed.

## Sources

The frontier models quoted on the architecture slide, and the paper the block
comes from, are listed along the foot of the last slide: Vaswani et al. 2017,
the GPT-4, Gemini, and DeepSeek-V3 reports, and the Llama 4 announcement.
