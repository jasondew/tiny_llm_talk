# the llama who chases the dogs

Attention from scratch, in Elixir. Forty-five minutes: thirty-three of talk,
twelve for questions.

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
| 0 | Cold open | 5 | **vote: flees, or flee** (the sentence and the join link, on screen while the room arrives), title, a language model is one function, the transformer (one block, drawn, × N then × 1), the model I built (every parameter table, by stage, with its shape and count) | audience vote |
| 1 | Words become numbers | 3 | the grammar, 32 words, **it writes** (the writer: the whole path once, fast) | presenter pace |
| 2 | Embedding and position | 3 | each word is a row and its position is added on, the model forgets it saw words | |
| 3 | Attention | 11 | math break: **dot product** with two arrows to drag and **softmax playground**; then ask/offer/hand over with the formula, **a small example by hand** on a toy map, one head of attention (the formula over sixteen annotated lines, the heatmap beside them going dark when the focus reaches the mask), **bet: where will the blank look**, **the walkthrough**, LLMs are weird | presenter drags, slider, picks; audience bet |
| 4 | The rest of the block | 4 | the transformer in this talk (the block diagram again, × 1, the box named), Block.forward whole, normalization, the neural network, the residual, each over the block's code with the dogs row beside it | |
| 5 | Back to words | 3 | rows become a distribution, **one word at a time** with the **temperature dial** | presenter |
| 6 | Training | 3 | **training, live** (press start, talk over it, the four beats stepped beside the curve) | presenter start |
| 7 | Did it learn it | 2 | this was all of it (the seven lines, walked), what is not here, the sentence again, **it writes** again under the repo link, with the sources along its foot | |

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
whether its owner agreed. The record is kept in `TinyLlmTalk.Room`.

Two audience moments: the vote and the bet. Spot the human, the rematch and
the scoreboard were cut when the deck ran long.

## The speaker

Every demo can be driven from the presenter view: a control clicked in the
preview is a control turned on the big screen. The controls are

- start and start over, for training (section 6)
- pace, step while paused, and reset, for the writer (sections 1 and 7)
- the two arrows on the dot product graph, dragged by their tips (section 3)
- the softmax slider (section 3)
- the fuzzy map's query word (section 3)
- the position in the walkthrough (section 3)
- next word and restart (section 5)
- the temperature dial (section 5)

## What is not in the talk, and where it went

The neural bigram, the entropy floor as a section, PCA, and the
temperature trade-off chart are in the repo and the Livebook, not on stage.
They exist so that the claims the repo makes about what the model learned
are true.
