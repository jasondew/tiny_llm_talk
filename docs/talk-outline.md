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
| 0 | Cold open | 3 | the sentence, **vote: flees or flee**, the bracket, the promise, from nothing | audience vote |
| 1 | Words become numbers | 3 | 32 words, the grammar, one function, **vote: you are a count table** | audience vote |
| 2 | All the math there is | 2 | the `Tensor` list with everything but `dot` and `softmax` dimmed, dot product, **softmax playground** | presenter slider |
| 3 | Embedding and position | 3 | a word is a row, position is added, the model forgets it saw words | |
| 4 | Attention, from `Map` | 11 | `Map.get`, **fuzzy map**, learn the lookup, the code, three details with a **mask toggle**, **bet: where will the blank look**, **the walkthrough** | presenter picks, audience bet |
| 5 | Look at what it did | 5 | heatmap, read it honestly, the sink, half a route, **your sentence** | audience builds sentences |
| 6 | The rest of the block | 3 | lid off, three pieces of plumbing | |
| 7 | Back to words | 5 | rows become a distribution, the loop, **one word at a time**, **temperature dial**, **vote: spot the human** | presenter, audience vote |
| 8 | Training, in one slide | 3 | guess / measure / nudge / repeat, a loss chart that draws itself, tests for math | |
| 9 | Did it learn it | 3 | the number, **rematch: room vs model**, **scoreboard**, what is not here, the sentence again | audience vote |

## The audience

Every vote has a right answer and a reveal step. On reveal every phone says
whether its owner agreed, and the room's record accumulates for the
scoreboard. The record is kept in `TinyLlmTalk.Room`.

Seven audience moments is a lot for forty-one minutes. If rehearsal says so,
cut in this order: **you are a count table** first, **spot the human**
second. Both are marked in their speaker notes.

## The speaker

Every demo can be driven from the presenter view: a control clicked in the
preview is a control turned on the big screen. The controls are

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
