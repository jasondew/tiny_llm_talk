# the llama who chases the dogs

Attention from scratch, in Elixir. Forty-five minutes: forty-one of talk,
four for questions.

The arc is one sentence going through one forward pass, in the order
`TinyLlm.Transformer.forward/2` runs it. There is no history and no
derivation on stage. The room leaves able to explain, in three verbs, what a
transformer does: each position looks back, scores what it sees, and pulls
in what it needs.

Three things move across the talk, and every section moves one of them:
the sentence, the picture of where attention looks, and the score.

`TinyLlmTalk.Deck` is this outline as data and must diff cleanly against it.

## Running order

| # | section | min | slides | interactive |
| --- | --- | --- | --- | --- |
| 0 | Cold open | 5 | **training, live** (under the introduction), **it writes** (the forward pass animated, word by word), this is all of it (the seven lines, said not shown), from nothing | presenter start |
| 1 | Words become numbers | 3 | 32 words, the grammar, one function, **vote: you are a count table** | audience vote |
| 2 | All the math there is | 2 | the `Tensor` list with everything but `dot` and `softmax` dimmed, dot product, **softmax playground** | presenter slider |
| 3 | Embedding and position | 3 | a word is a row, position is added, the model forgets it saw words | |
| 4 | Attention, from `Map` | 10 | `Map.get`, **fuzzy map**, learn the lookup, the code, three details with a **mask toggle**, **bet: where will the blank look**, **the walkthrough** | presenter picks, audience bet |
| 5 | Look at what it did | 5 | heatmap, read it honestly, the sink, half a route, **your sentence** | audience builds sentences |
| 6 | The rest of the block | 3 | lid off, three pieces of plumbing | |
| 7 | Back to words | 4 | rows become a distribution, the loop, **one word at a time**, **temperature dial**, **vote: spot the human** | presenter, audience vote |
| 8 | Training, in one slide | 3 | guess / measure / nudge / repeat, a loss chart that draws itself, tests for math | |
| 9 | Did it learn it | 3 | the number, **rematch: room vs model**, **scoreboard**, this was all of it (the seven lines, walked), what is not here, the sentence again, **it writes** again under the repo link | audience vote |

## The opener

Training runs live on the first slide, in the deck's own BEAM, with the
checkpoint's config and seed. Pure Elixir and seeded `:rand` make it the same
run, so the loss it lands on is the checkpoint's loss and the slide says
whether it matched. Every later slide reads the checkpoint, so nothing
downstream depends on the live run finishing. Rehearse on the laptop you
present from; the match is a claim about that machine.

The writer is the forward pass animated: a paragraph drawn from a seed at
temperature 0.8, seven phases a word, one every 0.7 seconds at the normal
pace. The temperature is on the slide; at 1.0 the model slips on agreement in
about one paragraph in nine, and 0.8 halves that without flattening the
variety. Both windows keep their own clock and agree because a frame is a
pure function of its number (`TinyLlmTalk.Writer`).

## The audience

Every vote has a right answer and a reveal step. On reveal every phone says
whether its owner agreed, and the room's record accumulates for the
scoreboard. The record is kept in `TinyLlmTalk.Room`.

Six audience moments is a lot for forty-one minutes. If rehearsal says so,
cut in this order: **you are a count table** first, **spot the human**
second. Both are marked in their speaker notes.

## The speaker

Every demo can be driven from the presenter view: a control clicked in the
preview is a control turned on the big screen. The controls are

- start and start over, for training (section 0)
- pace, step while paused, and reset, for the writer (sections 0 and 9)
- the softmax slider (section 2)
- the fuzzy map's query word (section 4)
- the mask toggle (section 4)
- the position in the walkthrough (section 4)
- next word and restart (section 7)
- the temperature dial (section 7)

## What is not in the talk, and where it went

The neural bigram, the entropy floor as a section, PCA, and the
temperature trade-off chart are in the repo and the Livebook, not on stage.
They exist so that the two claims made in section 9 are true.
