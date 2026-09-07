# tiny_llm_talk

The slide deck for **the llama who chases the dogs**, as a Phoenix LiveView app.

It lives beside `tiny_llm` rather than inside it, and depends on it by path, so
that `tiny_llm/mix.exs` keeps an empty dependency list. The talk's strongest
claim is that nothing is hidden and there are no dependencies; a reader who
follows the repo link on a slide has to find that claim intact.

    ~/src/
      tiny_llm/        the model, zero deps
      tiny_llm_talk/   this deck, path dep on ../tiny_llm

## Running it

    mix setup
    mix phx.server

- <http://localhost:4000/> the deck, for the room
- <http://localhost:4000/presenter> notes, clock, and what comes next

Either window can hold the clicker; they follow each other over PubSub. Put the
deck on the projector and the presenter view on the laptop.

Keys: space or the arrows move, `Home` and `End` jump to either end, and in the
presenter view `t` pauses the clock and `r` resets it.

Run it on localhost at the podium. Do not deploy it and do not depend on
conference wifi.

## How a slide gets written

The running order is data, in `TinyLlmTalk.Deck`: ten sections, every slide
the outline names, with its speaker notes and its count of reveal steps. It is
one readable file that can be diffed against `docs/talk-outline.md`. The arc is
one sentence going through one forward pass, in the order
`TinyLlm.Transformer.forward/2` runs it.

Drawing is separate. `TinyLlmTalkWeb.SlideComponents.slide/1` has one function
clause per slide id, and any slide without a clause falls through to a stub that
shows its title and notes on a hatched background. So the deck is presentable
from the first minute and gets less grey as it gets written.

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
       focus={[:all, 1..3, 5..8, 9..13, 14..14, 16..16, :all]} />
```

`function={:forward}` takes a whole function instead of a range. `focus` is one
window per step; everything outside it dims rather than disappearing, because a
function is easier to follow when you can see where the current lines sit. The
caption names the file and lines, which is the claim the talk rests on: this is
the code, not a simplified version of it.

Snippets size themselves to the space a slide has. If the type comes out small,
the snippet is too long for a room; quote a range instead of the whole function.

## Figures come from the model, not from a screenshot

`TinyLlmTalk.Model` holds the corpus, the count table, and the trained weights,
memoized behind an Agent and warmed at boot. Every figure is handed the plain
lists of floats the model returns:

```elixir
<.heatmap values={Model.bigram()} row_labels={Vocab.words()} ... />
<.bars values={Model.bigram_row("dogs")} words={Vocab.words()} ... />
```

So a slide cannot quote a number this checkpoint does not produce. Change the
model and the slides change with it.

Colour has one job per figure. Magnitude (heatmaps, bars) gets a single hue from
the surface up to the accent. Identity (the scatter, the two-series chart) gets a
fixed categorical order, validated against this surface for lightness, chroma,
colour-vision separation, and contrast. Text never wears a series colour.

## Checkpoints

    mix talk.train

Trains the neural bigram (about 11 seconds) and the transformer (about 77
seconds) and writes `priv/checkpoints/`, which is committed. Both runs are
seeded, so the attention weights the slides quote reproduce exactly.

Without checkpoints the deck still runs; the figures that need trained weights
say so and tell you to run the task.

## It trains and writes, live

`TinyLlmTalk.Trainer` runs the checkpoint's training run again on the training
slide, near the end, in the same BEAM, with the same config and seed. Because the model is
pure Elixir over a seeded `:rand`, that is the same run: the loss it lands on
is the checkpoint's loss, and the slide says whether it matched. Nothing else
depends on it; every other slide reads the checkpoint.

`TinyLlmTalk.Writer` is the model writing a paragraph with its forward pass
drawn beside it, one phase of one word per frame. A slide marked `ticks: true`
gets a clock from `TinyLlmTalkWeb.Animation`; each window runs its own, and
they agree because a frame is a pure function of its number and a seed.

## The speaker's controls

Some slides have a control the room watches you turn: start and start over on
the training slide, pace and new paragraph on the writer, the softmax slider,
the fuzzy map's query word, the position in the walkthrough,
the next-word button, the temperature dial. They live in the socket's `controls`
map and travel over the same PubSub topic as the position, so a control turned
in the presenter view's preview turns on the projector. Every demo is driven
from the podium; nobody reaches for the big screen's mouse.

`TinyLlmTalkWeb.Controls` handles them, for both windows.

## The audience

The talk is delivered over Zoom, so the audience is already in a browser. They
open `/join` on any device and it shows whatever question the deck is on:

- **section 0** flees, or flee? The first slide, on screen while the room arrives.
- **section 3** where will the blank look? They bet, then the walkthrough answers.

Every question with a right answer reveals it on the slide's second step. The
room does the revealing, so every phone says whether its owner agreed.

`TinyLlmTalk.Room` holds it. Arriving at a slide opens its activity and leaving
closes it, so there is nothing extra to remember while presenting, and walking
backwards asks the question again rather than showing a stale answer. Every
one of those slides renders correctly with nobody in the room.

Because it is a screen share, the join card leads with the URL and keeps the QR
code small: everyone watching can click a link, and only the people on a
television reach for a phone. Paste the link in the chat when the first vote
opens.

This is the part that has to be deployed. The audience is not on your network.

    fly deploy

`JOIN_URL` overrides what the card shows, if the deployed host is not where you
want people to land. One machine, never scaled to zero and never two: a second
machine would hold a second room and half the audience would vote into a tally
nobody sees.

## Still to build

- PDF export, for the conference and as the backup if the server dies.
- The pass over wording and pacing that only rehearsal finds.
