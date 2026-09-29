# Art status

The art pipeline's living page, the art counterpart of `docs/STATUS.md`: the routine of an art
session, this period's budget, the concepts, what waits on the user, the approved references, the
hand queue, and the log. The design and its reasons are
`docs/plans/2026-09-26-art-pipeline-design.md` ("## The budget loop and the review"). Updated
2026-09-27.

## The rules

- **The user is the only judge of the look**, at every step: bake-offs, bases, and finals. Claude
  never picks a winner. Claude may set a candidate aside only for a fault it can state (the wrong
  canvas or view, a broken limb, off the palette, semi-transparent pixels, cut off), and the
  set-aside ones stay visible in the review with their reason.
- **Cost is not quality.** A custom animation is not assumed better than a template, a Pro call not
  better than v3 or a standard one, a generation not better than code or hand work. Where two
  methods can make the same thing, the user compares them on one direction of one state first
  (the method bake-off), each shown with what its production would cost, and picks.
- **References are the user's.** No image goes into a call to steer it (a reference, style, init,
  or colour image, on any endpoint, Pro or not) unless it is in "## References" below, approved by
  the user or brought by the user. Claude proposes references; the user approves them before the
  first call that uses them.
- **References where they earn their place** (the user, 2026-09-27, revising "every Pro call
  carries references" the same day: a character is no style source for tiles or for enemies meant
  to look different). Style across kinds is held by the prompts (one style wording on every call),
  the master palette enforced in code afterwards, and the user's review. A Pro call uses approved
  references only for: consistency within a set of one kind (the first approved icon for the
  other icons, the approved sand for the walls, a kept creature for its family); an image the user
  brings (a concept, a sketch, a look); identity and edits (a figure's own animations, class
  skins, portrait, where it is the subject, a base rather than a reference). A Pro call without
  references says why in its job file (`no_refs_reason`; `gen.py` refuses one without), so the
  choice is always written down.
- **Concepts, not prompts.** The user approves each concept and its budget range; Claude writes
  every prompt and makes every call inside it.
- **The cheapest rung first** for spending: what code, a two-minute Aseprite job, scripted
  Aseprite, or Claude Design can do confidently is not generated. Where a cheap rung and a
  generation could both serve, the look is a bake-off like any other.

| Rung | Who | For |
|---|---|---|
| Code (Python/Pillow, Godot shaders and particles) | Claude | Mirroring the west directions, palette swaps and recolours, the palette remap, hit flashes, afterimages, dissolves, effects, tile variants by flip |
| Aseprite by hand, 2 minutes or less | the user (the hand queue) | A pose touch-up, a corpse frame, a heart's half and empty states, a stray pixel |
| Aseprite scripted (`aseprite -b`, Lua) | Claude | Sheets, frame timing, batch recolours, exports |
| Claude Design | the user or Claude | Style boards, palette candidates, UI and 1080p layout mock-ups |
| PixelLab standard | Claude | v3 characters (1 or 2 generations), template animations (1 a direction), pixflux images (1) |
| PixelLab Pro | Claude | Custom animations (20 to 40 a direction), Pro images and grids, Pro tiles, objects, portraits (20 to 40) |

## The art session

Art moves when the user calls an art session; there is no scheduled run. Each session, in order:

1. **Relevance check.** Read `docs/STATUS.md`, the latest milestone design and feel checklist it
   points to, and what changed since the last session (`git log --oneline <game commit in the last
   log line>..HEAD -- docs data scripts`). For each concept, does what it serves still hold? A cut
   enemy, a new class, a changed size, or a playtest note on the look is raised with the user
   before anything is spent, and the table updated.
2. **Budget.** `tools/art/budget.py` (the live balance and what this session may spend).
3. **Clear the user's answers** from "## Waiting on the user": approved concepts, approved or
   brought references, bake-off picks, approved bases and finals, send-backs with their notes.
4. **Work** the approved concepts in the table's order, within the allowance, each up to its next
   gate (a bake-off to show, a base to approve, a final), with approved references only.
5. **Gather the review**: every gate reached this session on one page (the review page once
   built; a contact sheet in `reports/` until then), each candidate at 2x and at game scale beside
   today's sprite, the set-aside ones with their reasons, each bake-off option with its production
   cost. Add them to "## Waiting on the user".
6. **Record.** Update the table (status, spent), the references, the hand queue, and add a log
   line naming the game commit read in step 1.

## This period

Tier 2 (Pixel Artisan): 5,000 generations from 2026-09-27, renewing 2026-10-27 (unspent
generations expire). 4,956 left on 2026-09-27 (the bake-off spent 44). The sink opens 2026-10-24:
from then on everything left goes to the sink concepts and to bake-offs for concepts not yet
started. Split: style probe and bake-offs 500, production 3,250, rerolls 750, sink 500.

## Concepts

The user approves each concept and its range. **Bake-off** is what the method comparisons cost
(the methods named are the ones compared; the user picks); **production** runs from "every cheaper
method wins" to "every dearer method wins", in generations, from the API's published formulas
(each call type's real cost is measured on its first use and replaces the estimate). Readiness:
*locked* (the design fixes it), *provisional* (a later milestone may change it: drafts only),
*pending* (not designed yet: nothing spent).

| # | Concept | Serves | Readiness | Methods compared (the user picks) | Local work | Bake-off | Production | Status |
|---|---|---|---|---|---|---|---|---|
| C1 | Style lock | every concept | locked | Decided by the user: Pro for figures in S5's wording; Pro grids for small images; the sand of S3, S4, S5 and the wall of S2 liked (round 1, pixflux) | The master palette: our own, `art/style/palette.gpl` (43 colours drawn from the approved sprites; expanded with `tools/art/palette.py extend` when a new asset needs a colour it lacks) | 100 to 250 | - | decided (257 spent, `art/jobs/c1_*.json`) |
| C2 | The gladiator (48 px, 8 directions, 5 generated) | the player | locked | Idle and run: template against custom; the fall: a v3 state against custom against a hand pose; hit and dash: code (flash, afterimage) against generated | West mirrored in code | 100 | 15 to 750 | proposed |
| C3 | Tier 1 mobs: chaser, shielded chaser, shooter (the chaser's skins: the lemur, the masked condemned, the strix, perhaps the hound; a skin per series, maybe) | M4/M5 enemies | locked | Imp and shaman idle and run: template against custom; the shaman's wind-up and cast: template attack against custom; deaths: code dissolve with a hand corpse against custom | The shielded chaser as a recoloured imp with a shield sprite facing its arc | 120 | 30 to 1,200 | proposed |
| C4 | Tier 1 boss (96 px) | M4 boss | locked | Idle and run: template against custom; the charge, ring, and summon: effects over a held pose against custom | - | 60 | 15 to 1,000 | proposed |
| C5 | The arena: sand, sandstone walls, the emperor's box, the gate | the arena, the grounds | locked | Standard tileset (its lower, upper, and transition reference images) against Pro tiles (style images), both from the liked sand and wall if the user approves them as references; the box and the gate: a Pro grid against an object | Variants by flip and recolour, cracks by hand | 80 | 60 to 180 | proposed |
| C6 | Boon and HUD icons (the 18 names in `data/icons.json`) | M5 cards, HUD | provisional (M7 adds boons) | Pro grids (the user's pick): one call a name gives 64 candidates at 32 px; the first approved icon may steer the rest (a set of one kind) | The thumb down as the thumb up turned in code | 0 | 340 (17 calls) | proposed |
| C7 | Props and pickups: coin (spinning), heart, crate, spear, handgun, crossbow | M5 piles, grounds, weapons | locked | Pro grids for the stills (the user's pick); the coin's spin: animated against hand frames | Heart states by hand, projectiles by hand or code, weapons rotated in the engine | 20 | 120 to 160 | proposed |
| C8 | Effects: muzzle flash, hits, the boss's ring, coin burst | juice | locked | Nothing generated unless the user asks for a bake-off | Godot particles and shaders, Aseprite | 0 | 0 | proposed |
| C9 | UI frames at 1080p | every panel | provisional (the 1080p move) | Nothing generated yet | DungeonUI remapped to the palette in code, touched up in Aseprite; layouts in Claude Design | 0 | 0 | proposed |
| C10 | The crowd (M8) | the border, the favour | provisional (1080p, M7 tiers) | One body's cheer: template against custom | Recolours for variety, tiling in code | 25 | 30 to 250 | sink |
| C11 | Portrait probe: the gladiator's bust, talking | M6 dialogue | pending (no characters written) | `character_to_portrait` from the approved sprite against a Pro image of the bust with the sprite as an approved reference; then its visemes for one mood | Blink and arm layers by hand | 40 to 100 | - | sink |
| C12 | The emperor in his box: seated, thumb up and down | M8 box, M9 verdict | provisional (M7 fight, M9 story) | v3 against Pro for the figure; the gestures: template against custom | - | 40 | 20 to 120 | sink |
| C13 | Later casts: M6 grounds characters, M7 classes, tier 2 and 3 enemies and bosses | M6, M7 | pending | Nothing until their designs exist | - | 0 | 0 | held |

Totals for C2 to C7 (C1 spent 257): about 960 if every cheaper method wins, about 4,010 if every
dearer one does (the bake-offs are 380 of either). 4,699 are left this period; each bake-off's
options are shown with their production cost, so the user picks knowing what the month can hold.

**Talking portraits are in the API** (checked 2026-09-27): `portrait-character-pro`
(`character_to_portrait`, sizes 16 to 160, or `portrait_to_character` for a bust the user brings),
`characters/{id}/portrait` (free), `vocal-animation` (the paid step, once per mood), then
`lip-sync` (free: the frame plan an engine plays) and `talking-gif` (free: a GIF to review). C11
tries the chain on the gladiator; its cost is measured there.

## Waiting on the user

- **The tier 1 stage, whole** (`reports/art_ring_stage.png`, the gladiator placed at true size;
  `art/work/c5_ring_stage.png`, 640x620): the approved top wall joined to a near edge generated with
  it as the reference (`c5_ring_bottom_a`; the b seed redrew the far wall and was dropped), the join
  cut through the sand along the least-different path, the near sand's tones rank-matched onto the
  top's, and both open ends of the oval closed by inpainting (`c5_ring_close_left`, `_right`). The
  near wall shows its outer face under the coping (the user: kept, for the lore). The game's side is
  noted in the colosseum design ("## Later, from the user's notes", 2026-09-28).
- Later (the user: not yet): the concepts C3 to C12.

## References

Approved references (`art/refs/refs.json` holds the files, hashes, sources, and what each may
steer).

- 2026-09-28, brought by the user for C5's stage: `user_colosseum_topdown`
  (`art/refs/user/colosseum_topdown.png`, made in PixelLab's web creator), the colosseum's layout
  and look.
- 2026-09-27, for C5's arena tiles (a set of one kind): the sands of C1 round 1's S3, S4, and S5
  and its S2 wall (`c1_sand_s3`, `c1_sand_s4`, `c1_sand_s5`, `c1_wall_s2`), approved by the user
  for the comparison with and without references.

## Approved

Bases and results the user approved (a base is not a reference until approved as one).

- 2026-09-28, the run: skeleton-v3 on `running-8-frames` (`c2_run_skeleton`, "by far the best"; a
  little slow, the game sets the tempo); `c2r2_run_skeleton6` second.
- 2026-09-28, the fallen still (`c2_fall_state`, PixelLab character `258fcc0b-7de9-4e35-90a7-b4b7378cb047`, 8
  directions) and the dash pose (`c2r2_dash_pose`, `e7b42283-18d6-4bb9-b6b2-81ab0562d2f4`), "good enough for now";
  the dash is the pose plus code effects (afterimages, a speed blur), not an animation.
- 2026-09-28, the top wall's gate: the wider inpaint a (`c5_gate_wide_a`, pasted into A:
  `art/work/c5_gate_wide/stage_a.png`), the open arch with the sand running in.
- 2026-09-28, the north fallen still's crest recolour: "not perfect but good enough".
- 2026-09-28, the top wall: `c5_stage_topwall_a` (the far wall facing the camera, the monumental gate,
  the emperor's red-canopied balcony above it), its gate to be a little wider, like B's.
- 2026-09-28, the stage's look: the native-density section (`c5_stage_native_gate`, the user's
  image as the style), "looks good"; the gate to be monumental after all (the user: about three
  times the gladiator's height).
- 2026-09-28, the fallen still: the template fall's last frames (`art/work/c2_fallen_from_template/`),
  the north one from the skeleton-v3 north fall (`c2r5_fall_north_skeleton`, which keeps the crest);
  replaces the `c2_fall_state` still; the north frame's crest recoloured onto the others' crimson.
- 2026-09-28, the dash: the code version (`reports/anim/mock_dash.gif`, `tools/art/mock_fx.py`: a
  crouch, the approved pose stretched with speed streaks and a dust puff, a landing squash, fading
  afterimages); the game tunes its numbers.
- 2026-09-28, the stage's scale: option 2 (the stage at about twice the concept's detail, the
  camera framed on the sand, the stands as the border), painted at the characters' pixel density.
- 2026-09-28, the hit: in code (a white flash and a small knockback on the current frame, the
  game's flash shader), no generated hit animation.
- 2026-09-28, the balcony: stage B's, under a red canopy ("more imperial").
- 2026-09-28, the idle: the template animation (`breathing-idle`, `c2_idle_template`), slower than
  PixelLab's tempo.

- 2026-09-27, the gladiator: C1 round 2's S5 Pro character (`r2_S5_gladiator_pro`, PixelLab
  character `e3f8e681-d12c-49ed-b758-703d40c3ebee`), "better", with colour tweaks to come: the red crest
  kept (it reads on sand); the forearm wraps brown (the user's pick of `reports/art_C1_wraps.png`:
  the belt's browns, recoloured in code by `tools/art/wraps.py`; PixelLab's stored character keeps
  its white wraps, so every frame generated from it, animations included, gets the same recolour).
- 2026-09-27, the chaser's skins, kept as they are: the lemur (`3ee990a7-1fff-4273-b114-57eda5887d7e`), the masked
  condemned (`9e079c70-35b2-442e-a9d2-2dd57cd3205d`), the strix (`d26e45cc-79cd-4abe-9226-495dff451690`), from C1 round 2; both
  the Pro hound of round 3 (`dog` at 48 px, `bd7387df-c4e3-4739-bb3c-79db6de2cb5c`) to try as well; the v3
  hound (black, 32 px) scrapped by the user on 2026-09-28.

## Hand queue

Two-minute Aseprite jobs for the user, filled as concepts land. Empty.

## Log

- 2026-09-27: the keychain key in, `pixellab.py balance` and `budget.py` working (Tier 2 active,
  4,956 of 5,000 left). Concepts drafted for the user's review; revised the same day with the
  user's rules (the user judges the look at every step, cost is not quality, references approved
  by the user before use) and the portrait chain found in the API. Game commit read: `573f870`.
- 2026-09-27: `gen.py` (plan and run, refs enforced, the ledger, jobs posted side by side) and
  `sheet.py` built; C1 round 1 on prompts alone: five styles on v3 and pixflux, Pro in S1's words
  (29 calls, 115 generations; measured: v3 figure 2, pixflux 1, Pro character 20, Pro image grid
  20). 4,841 left. Game commit read: `89c79ae`.
- 2026-09-27: C1 round 2 from the user's notes: the gladiator redesigned, four chaser ideas in Pro
  (six calls, 120 generations; the hound failed twice, not charged). The rule "Pro calls carry
  references" added (the user), enforced by `gen.py`. 4,721 left. Game commit read: `66376cd`.
- 2026-09-27: the user picked the S5 gladiator and kept the lemur, the condemned, and the strix as
  the chaser's skins. The hound: Pro on the `dog` template works at 48 px (failed at 32), v3 on
  `dog` at 32 (22 generations). The wraps recoloured in code (`tools/art/wraps.py`). 4,699 left.
  This page rebuilt from `89c79ae` (the edits of `66376cd` and `be68b75` had matched a heading's
  name inside the routine's text and duplicated a block). Game commit read: `be68b75`.
- 2026-09-27: the user picked brown wraps and kept both hounds to try. References asked by use.
- 2026-09-27: the user declined the gladiator as a style reference for other figures or for tiles,
  icons, and props; the references rule revised to "references where they earn their place"
  (within a set of one kind, the user's own images, identity and edits); style across kinds by
  the prompts, the palette, and the review.
- 2026-09-27: the user's picks close C1 but for the palette: Pro grids for small images; the sand of
  S3, S4, S5 and the wall of S2 liked. C5 to C7's methods and ranges updated to match.
- 2026-09-27: the palette measured (`tools/art/palette.py`: AAP-64, a 48-colour candidate from
  the approved sprites, AAP-64 plus 8). The four arena references approved for C5's comparison
  (`art/refs/refs.json`). C5 and C2's bake-offs started; `gen.py` learned job lists per call,
  detail fetches, the job-slot cap (HTTP 429: waits), dropped connections (polls retried, posts
  never), and held calls.
- 2026-09-28: C2 and C5's bake-offs in (76 generations; measured: template 1, v3 1, skeleton-v3
  3, Pro animation 20, state 20, standard tileset 4, Pro tiles 20). `gen.py`: storage downloads with
  a User-Agent (the storage refuses Python's), links only when a result has no inline image, no
  retry on an HTTP refusal, `{"ref", "as": "sized"}` refs. `sheet.py`: animation frames and states,
  repeats dropped by pixels. 4,623 left.
- 2026-09-28: the user chose our own palette (`art/style/palette.gpl`, v1: the 48-colour candidate
  with its near-blacks merged, 43 colours, pure black the outline; fit to the approved sprites:
  mean 1.5, 1% moved); AAP-64 dropped (and the licence question with it). `tools/art/preview.py`:
  animated GIFs. The crops proposed for the tileset's references.
- 2026-09-28: C2 round 2 (32 generations), the painted stage's left half (40), the tile stages
  laid out in code (`tools/art/stage.py`). Fixed: the preview's per-frame anchor (jitter), stills
  shown as stills, a state's rotations read live by its id (the download's copy of a new state was
  stale), link downloads named by direction. The v3 hound scrapped. 4,551 left.
- 2026-09-28: the stage from the user's own image (two at 640x360, 80 generations); the fall toward
  the approved still (2); the dash and the hit mocked in code (`tools/art/mock_fx.py`). `gen.py`:
  Pro image references wrapped (`"as": "reference"`), a busy character (HTTP 423) waited on.
  4,429 left.
- 2026-09-28: the hit in code and B's balcony approved; the falls animated side by side, a code
  fall and a livelier code dash (`tools/art/mock_fx.py`), the stage's scale mocked three ways. No
  generation. 4,429 left.
- 2026-09-28: the dash (code) and the stage's scale (option 2) approved; the template fall in the
  four other generated directions (4) and its last frames as a fallen still; a stage section at
  native density (40). 4,385 left.
- 2026-09-28: the stage's look approved; the fallen still rebuilt from the template's last frames,
  the north crest painted in code (no generation). The north fall animation found crestless.
  4,385 left.
- 2026-09-28: the north fall regenerated (skeleton-v3 keeps the crest, 3; a template retry, 1) and
  its last frame made the north fallen still; the gate kept at its size. 4,381 left.
- 2026-09-28: the north fallen still warmed in code; two monumental-gate sections (80): both
  overshoot the three times, and the gate's face shows only in the far wall from this view.
  4,301 left.
- 2026-09-28: the north fallen still's crest recoloured (the body's warm shift undone); the top wall
  with the gate and the balcony, two seeds (80). 4,221 left.
- 2026-09-28: the top wall A approved; its gate widened by inpainting the gate's band, two seeds
  (80; `gen.py` wraps a file input as {image, size} with "as": "sized"). 4,141 left.
- 2026-09-28: the wider gate a and the north crest recolour approved. 4,141 left.
- 2026-09-28: the approved top wall made the ring's reference (`c5_topwall_approved`); the near edge
  (two seeds, 80), the join in code (a least-difference cut through the sand, the sand tones
  matched), both ends closed by inpainting (80): the tier 1 stage whole at 640x620. The oval and the
  stage's game work noted in the colosseum design. 3,981 left.
