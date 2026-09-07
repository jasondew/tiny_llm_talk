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
| 0 | Cold open | 4 | **vote: flees, or flee** (the sentence and the join link, on screen while the room arrives), title, what a transformer is (one block, drawn; every frontier model uses the same pieces), the model I built (every parameter table, by stage, with its shape and count) | audience vote |
| 1 | Words become numbers | 4 | 32 words, the grammar, one function, **it writes** (the writer: the whole path once, fast) | presenter pace |
| 2 | Embedding and position | 3 | a word is a row, position is added, the model forgets it saw words | |
| 3 | Attention | 11 | **softmax playground**, one head of attention (the formula over the code, sixteen lines), **dot product** with two arrows to drag, **fuzzy map**, learn the lookup, three details with a **mask toggle**, **bet: where will the blank look**, **the walkthrough** | presenter drags, slider, picks; audience bet |
| 4 | Look at what it did | 5 | heatmap, read it honestly, the sink, half a route, **your sentence** | audience builds sentences |
| 5 | The rest of the block | 3 | lid off, three pieces of plumbing | |
| 6 | Back to words | 4 | rows become a distribution, the loop, **one word at a time**, **temperature dial**, **vote: spot the human** | presenter, audience vote |
| 7 | Training | 4 | **training, live** (press start, talk over it), guess / measure / nudge / repeat, the loss replayed, tests for math | presenter start |
| 8 | Did it learn it | 3 | the number, **rematch: room vs model**, **scoreboard**, this was all of it (the seven lines, walked), what is not here, the sentence again, **it writes** again under the repo link, sources | audience vote |

## Live training and the writer

Training runs live at the top of the training section, in the deck's own BEAM, with the
checkpoint's config and seed. Pure Elixir and seeded `:rand` make it the same
run, so the loss it lands on is the checkpoint's loss and the slide says
whether it matched. Every other slide reads the checkpoint, so nothing
depends on the live run finishing. Rehearse on the laptop you
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

Five audience moments is a lot for forty-one minutes. If rehearsal says so,
cut **spot the human** first; it is marked in its speaker notes.

## The speaker

Every demo can be driven from the presenter view: a control clicked in the
preview is a control turned on the big screen. The controls are

- start and start over, for training (section 7)
- pace, step while paused, and reset, for the writer (sections 1 and 8)
- the two arrows on the dot product graph, dragged by their tips (section 3)
- the softmax slider (section 3)
- the fuzzy map's query word (section 3)
- the mask toggle (section 3)
- the position in the walkthrough (section 3)
- next word and restart (section 6)
- the temperature dial (section 6)

## What is not in the talk, and where it went

The neural bigram, the entropy floor as a section, PCA, and the
temperature trade-off chart are in the repo and the Livebook, not on stage.
They exist so that the two claims made in section 8 are true.
