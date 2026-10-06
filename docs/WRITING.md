# Writing for the game: the brief

This is for you as the writer. It covers what the story files hold, when an event plays and why,
the rules the words follow, the Story tab in the Godot editor, the lint, and two walkthroughs that
end with your own event playing in the game. Nothing here needs code; the files you open are
under [`data/story/`](../data/story/).

Every line in the game today is a placeholder: it starts with `PLACEHOLDER`, which the game strips
before showing it. Your writing replaces them. The lines quoted below are illustrations of the
format and the rule, marked as examples; none of them is meant for the game.

Contents: [the files](#the-files) · [the format](#the-format) · [when an event plays](#when-an-event-plays-the-triggers) ·
[what a condition can read](#what-a-condition-can-read) · [which event plays](#which-event-plays-priorities-and-one-new-thing-a-return) ·
[the limits](#the-limits) · [the writing rule](#the-writing-rule) · [comments](#comments-and-where-a-rewrite-puts-them) ·
[ids and renames](#ids-renames-and-saves) · [the Story tab](#the-story-tab) · [the lint](#the-lint) ·
[playing from an act](#playing-from-an-act-actus2-actus3) · [the placeholders](#the-placeholders-to-replace) ·
[your first event](#walkthrough-1-your-first-event) · [an event across two characters](#walkthrough-2-an-event-gated-across-two-characters) ·
[the character page](#the-character-page-template)

## The files

| File | What it is |
|---|---|
| [`data/story/<cast id>.txt`](../data/story/) | One pool of events per member of the cast: `lanista`, `armourer`, `veteran`, `doctor`, `attendant`, `narrator`, `crowd`. You edit these, by hand or in the Story tab. |
| [`data/story/flags.txt`](../data/story/flags.txt) | Every story flag, declared once with its starting value. You edit it by hand (the tab does not). |
| [`data/story/cast.json`](../data/story/cast.json) | The cast: each member's name in the box, sprite, and voice; `timed` for the two who speak in the timed window. A new member is a row here and a pool file; a place for them in the grounds is an edit to a room in `data/grounds/` (a developer's task). |
| [`data/story/lint_words.txt`](../data/story/lint_words.txt) | The lint's word list ([the lint](#the-lint)). |
| [`data/story/acts.json`](../data/story/acts.json) | The act presets for `actus2` and `actus3` ([playing from an act](#playing-from-an-act-actus2-actus3)). Placeholders until the acts are defined. |

Who is where:

| Pool | Where | How they speak |
|---|---|---|
| `lanista` | the Ludus, beside the training post | the text box; a new word plays before the post's panel opens |
| `veteran` | the Ludus's yard | the text box |
| `armourer` | the Armamentarium, beside the rack | the text box; a new word plays before the rack's panel opens |
| `doctor` | the Sanitarium (the Ludus's right door) | the text box |
| `attendant` | the Hypogeum (the Ludus's top door), by the lift | the text box |
| `narrator` | at the emperor's verdict, and on waking in the Spoliarium | the timed window: one line, no input, a dark portrait |
| `crowd` | over "Pick a boon" after each round | the timed window's line on the picker |

## The format

An event, as an example of every part (illustrative names and lines, not content to ship):

```text
# The veteran warns the gladiator once both others have spoken.
== the_warning
requires: lanista.after_first_win, doctor.the_wound
unless: veteran.the_goodbye
when: deaths >= 1 and not veteran_distant
priority: high
repeat
trigger: talk
act: 2

VETERAN: {wins} nights, and you still walk.
[last_verdict == down] VETERAN: I saw them carry you out.
? Say nothing.
    set: veteran_distant
? "So did you."
    set: veteran_trust
    VETERAN: Hm.
set: veteran_met
```

Line by line:

- `# ...` is a comment: never shown. Put a note on its own line, above what it is about
  ([comments](#comments-and-where-a-rewrite-puts-them)).
- `== the_warning` starts an event and names it. A name is letters, digits, and `_`, not starting
  with a digit. The event's id is `<pool>.<name>`: this one, in `veteran.txt`, is
  `veteran.the_warning`.
- The header follows, one key a line, and ends at the first blank line. Every key is optional,
  and one at its default is left out when the tab saves the pool:
  - `requires:` events that must have played first, from any pool, separated by commas.
  - `unless:` events that must not have played.
  - `when:` a condition ([what a condition can read](#what-a-condition-can-read)).
  - `priority:` `story`, `high`, `normal` (the default), or `filler`.
  - `once` (the default) or `repeat`.
  - `trigger:` `talk` (the default), `enter <room>`, `verdict_wait`, `verdict_up`,
    `verdict_down`, or `pick`.
  - `act:` 1, 2, or 3. Nothing in the game reads it: it is for the Story tab's act filter.
- The body follows the blank line:
  - `SPEAKER: text` is a line. The speaker is a cast id in capitals (`LANISTA`, `ARMOURER`,
    `VETERAN`, `DOCTOR`, `ATTENDANT`, `NARRATOR`, `CROWD`); any member may speak in any pool's
    event, and the box shows that member's name, portrait, and voice.
  - `[condition] SPEAKER: text` plays the line only when the condition holds.
  - `{name}` in a line or a choice is replaced by the name's value when it plays (`{wins}` becomes
    the number of wins; a true-or-false flag shows `true` or `false`).
  - `? text` is a choice. Under it, indented four spaces: its effects (`set: ...`), then the lines
    that play when it is taken. A choice has no choices of its own.
  - `set: flag` at the left margin after the body is an end effect: it runs when the event ends.
    Nothing may follow the end effects.
- `set: flag` sets a true-or-false flag true; `set: flag = 3` or `set: flag = word` sets a number
  or a word flag. The flag must be declared in [`flags.txt`](../data/story/flags.txt) with that
  kind of value: one a line, `name` (true or false, starting false), `name = 0` (a number), or
  `name = word` (a word). A flag cannot take a name the story already reads (`wins`, `last_band`,
  and the rest below).

A number is digits with an optional `-` in front and no leading zero: `0`, `3`, `-2` (never
`+3`, `03`, or `-0`).

The game checks every file when it loads. A mistake (an unknown speaker, an unknown event in
`requires`, a flag not declared, a line over its limit, a `requires` chain that loops back on
itself) is an error that names the file and the line, as `veteran.txt:12: unknown speaker
'VETRAN'`. An event with an error does not load, nor does any event that names it in `requires` or
`unless`; the rest of the story loads. The boot check and the test suite fail on any error, so none ships.

## When an event plays: the triggers

| Trigger | When the game asks | Which pools it asks | Shown |
|---|---|---|---|
| `talk` | E on a character, or on the post or the rack with their keeper | that character's pool (never the narrator's or the crowd's) | the text box |
| `enter <room>` | every arrival in the room, once the screen has faded in | every pool at once: one event plays | the box, or the timed window for a timed pool's event |
| `verdict_wait` | after a fall, while the emperor decides | the narrator | the timed window |
| `verdict_up`, `verdict_down` | under the thumb | the narrator | the timed window |
| `pick` | over "Pick a boon", at a round's first offer | the crowd | the line on the picker |

`<room>` is `ludus`, `armamentarium`, `sanitarium`, `hypogeum`, or `spoliarium`.

Three things to know:

- **`enter <room>` fires on every arrival in that room**: from the title's Play, from the gate
  screen after a run, and from every walk through a door. A `once` entry event plays on the first
  arrival it can; a `repeat` one plays again at every door walk unless its `when` rules that out
  (`when: arrival == gate` plays only after a run). The lint warns on both pitfalls.
- **A timed event is one line.** The narrator's and the crowd's events (every event of a pool
  marked `timed` in `cast.json`, and any event on a verdict or pick trigger) show only their
  first line that plays; a second line is never shown. They take no choices.
- **The verdict lines read the runs before the one ending**: at the verdict the counts and the
  last run's facts have not yet taken in the run on screen. Back in the grounds they have.

## What a condition can read

A condition is a `when:` or a line's `[...]`. Its grammar: a comparison (`==`, `!=`, `<`, `<=`,
`>`, `>=`) of a name with a value (a number, `true`, `false`, or a word) or with another name;
`not`, `and`, `or` (a comparison binds tightest, then `not`, then `and`, then `or`: `not a or b
and c` reads `(not a) or (b and c)`); parentheses to group. A name alone is
true when it is true, a number other than 0, or a word other than `none`.

The names, and where they mean something:

| Name | Values | Available |
|---|---|---|
| your story flags (`flags.txt`) | as declared | everywhere |
| `runs`, `wins`, `falls`, `deaths`, `perfect_runs` | numbers: runs played (a run quit midway counts as a run and a fall), wins, falls, thumbs down, wins with no hit taken and every round ended at Roar | everywhere |
| `returned` | true after the first return to the grounds | everywhere |
| `spoliarium_seen` | true after the first waking in the Spoliarium | everywhere |
| `tier_unlocked` | a number: the highest tier the save has opened, 1 at the start (winning tier 1 opens 2) | everywhere |
| `last_outcome` | `win`, `fall`, `yield` (quit midway), `none` (no run yet) | everywhere |
| `last_verdict` | `up`, `down`, `none` (a quit run, or no run) | everywhere |
| `last_band` | `boo`, `quiet`, `cheer`, `roar`, `none`: the crowd at the end of the last run's last finished round | everywhere |
| `last_killer` | the enemy that felled the gladiator, by its id (`chaser`, `chaser_shield`, `shooter`, `charger`, `boss`, `beast`, `handler`, ...: a lint message lists them all), or `none` | everywhere |
| `last_tier` | a number: the tier the last run was fought in, 0 (no run yet) | everywhere |
| `arrival` | `gate` (the gate screen after a run), `door` (a door walk), `start` (the title's Play) | `enter` events; `none` elsewhere |
| `run_band` | `boo`, `quiet`, `cheer`, `roar` | the verdict's three triggers; `none` elsewhere |
| `round_band` | `boo`, `quiet`, `cheer`, `roar` | `pick`; `none` elsewhere |
| `round_loss` | what cost the most favour in the round: `hit`, `fled`, `slow`, `none` | `pick`; `none` elsewhere |

A word compared with a name must be one of that name's words: `last_band == rore` is an error.
`last_killer` takes any word (new enemies come), so the lint checks its words instead. A
`{substitution}` may use any name in the table.

## Which event plays: priorities and one new thing a return

When the game asks a pool at a trigger, it takes the pool's events on that trigger (and room)
that can play now: every `requires` played, no `unless` played, the `when` holding, and a `once`
event not yet played. Then:

1. The highest priority wins: `story`, then `high`, then `normal`, then `filler`.
2. Among equals, the one played longest ago (never played comes first), so `repeat` events take
   turns.
3. Then the order in the file. For an entry, which asks every pool at once, the cast's order
   comes first (`cast.json`: lanista, armourer, veteran, doctor, attendant, narrator, crowd).

**One new thing a return.** A return is the time in the grounds between two runs (quitting the
game does not end it). Each character says at most one new thing a return: a `talk` event that
is not `filler` uses the character's turn when it starts. After that, E gives their `filler`
(if they have one that can play), or nothing. The two merchants have no filler that plays: E on
their station opens the panel at once when they have nothing new. `enter` events and the timed
moments never use a turn.

**The mark.** A small gold bubble floats over a character while they have something new: their
turn is not used and a `talk` event that is not `filler` can play.

An event counts as played the moment it starts; its end effects run when the box closes, and a
choice's effects when the choice is taken.

## The limits

| What | Limit |
|---|---|
| A line in the text box | 180 characters (three rows of the box) |
| A line in the timed window (the narrator, the crowd) | 48 characters |
| Choices in a row | 5 (a comment, or a line with a condition, between two choices does not break the row) |
| A choice's text | 60 characters (one row) |

Lengths count the text as written, without the `PLACEHOLDER` marker and before `{substitution}`:
`{wins}` counts as six characters, whatever number it shows. A line over its limit is an error.

## The writing rule

The rule of the whole game is **show, don't tell**. No caption, hint, tutorial, or character line
explains a mechanic, names a system, or tells the player what to do. The player learns the rules
by playing them.

**Text may reinforce, never explain.** Words are welcome when they are in the world's voice and
reinforce a feeling the player already has (the crowd's judgement at the pick, the narrator at the
verdict). A line that breaks the fourth wall, infodumps, or says how a system works stays out.

**UI may name, never narrate.** A thing may carry its name (a card's text, the post's rows,
"Pick a boon"); nothing on screen says how a system works. That is the interface's rule; the
cast's lines follow the one above.

Examples, written for this brief and not for the game:

| In (example) | Out (example) | Why it is out |
|---|---|---|
| `LANISTA: Sand in the cuts again. Wash before you bleed on my floor.` | `LANISTA: Press E at the post to buy training.` | names a key, tells the player what to do |
| `CROWD: They wanted blood and got a stumble.` | `CROWD: You were hit, so your favour dropped.` | explains a mechanic |
| `DOCTOR: Hold still. The cut is closing already. It should not be.` | `DOCTOR: Heal cards restore half your hearts.` | names a system, infodumps |
| `NARRATOR: Cold stone. Somehow, breath.` | `NARRATOR: You died, but you respawn here.` | explains, speaks over the player's head |
| `VETERAN: I heard them roar for you. I remember that sound.` | `VETERAN: Dash past bolts to fill the meter faster.` | a tutorial in a character's mouth |
| `ATTENDANT: The lift is cold tonight.` | `ATTENDANT: Thanks for playing!` | breaks the fourth wall |

The lint backs the rule with a word list ([the lint](#the-lint)); the rule itself is yours to
judge, line by line.

## Comments and where a rewrite puts them

Write a note about a line on its own line above it. A comment after text on the same line (an
inline comment) is allowed only on the `==` line, a header line, and a `set:` line, and only
until the file is rewritten: the tab warns of it at the load and drops it at the next save of that
pool, and Apply refuses a text holding one. In a speaker line or a choice a `#` is prose
(`Gate #3`).

The Story tab saves a pool in one canonical form: the header keys in the order of the example
above, each left out at its default, one blank line between events, four spaces for a choice's
lines, a comment block directly above the `==` it belongs to. A file you write by hand keeps its
form until the tab saves that pool. No comment is lost, but a rewrite moves some to their
canonical place:

- A comment at the end of an event (after its last line, with no end effect after it) becomes the
  next event's comment; after the last event, the file's closing comment.
- A comment between two end effects moves before both.
- A comment at the left margin between a choice and its indented lines moves below those lines.
- An indented comment above a choice's `set:` moves below the choice's effects (and, with nothing
  after it in the event, becomes the next event's comment or the file's closing comment).
- A file's closing comment becomes its opening comment once its last event is deleted.
- A comment that is a lone `#` with no text, as a file's opening or closing block or an event's
  comment, is dropped.
- Deleting an event deletes the comment block above it, which may hold comments you wrote at the
  end of the event before it (the first move).
- Inline comments are dropped, with the warning above.

In the side panel, Apply refuses a comment after the event's last line ("put it above the line it
is about") and a comment left last under the event's last choice, since the saved form would move
it out of the event.

## Ids, renames, and saves

- **Event ids are yours.** The game and its checks never depend on an event's name, only on its
  pool and its shape. Name events for yourself.
- **Renaming an event resets it for every player who saw it.** A save remembers played events by
  id, so a renamed event plays again, and every event whose `requires` names it waits for it
  again. Rename freely before release; after, think twice. The tab updates every `requires` and
  `unless` that names it, in every pool.
- **A flag is declared once** in `flags.txt`; a typo in a `set:` or a `when:` is an error, never a
  new flag.

## The Story tab

The Story tab is a screen of the Godot editor that draws the events as a graph and edits them.
It reads and writes the same files: a file written by hand and one saved from the tab are the
same thing.

### Opening it

Open the project in the Godot editor (4.7.2): the Godot app on the project's folder, or from the
repo root `source tools/godot.sh && "$GODOT_BIN" --editor --path .`. At the top of the editor,
beside 2D, 3D, Script, and the other screens, click **Story**. The graph is built the first time you show
it.

### What you see

- **Lanes**: a frame per character, in the cast's order, titled with the pool's id. Each lane's
  title bar has a **+ Event** button. A lane whose pool has unsaved edits says `(unsaved)`.
- **Nodes**: an event each, placed left to right by how deep it sits in its chain of `requires`
  (positions are computed: drag a node to see behind it, but the next edit or Reload lays it out
  again). A node shows:
  - its name in a title bar coloured by priority (story gold, high red-brown, normal blue, filler
    grey), with a menu button (Rename..., Delete...; a right-click on the node opens it too);
  - its trigger; once or repeat, and its act;
  - badges: `N placeholder` (yellow, lines and choices still marked), `N lint` (orange, the
    lint's warnings), `N errors` or `not loaded` (red); an event with an error has a red border.
- **Edges**, told apart by colour (the legend in the toolbar shows them, and the four priorities):
  `requires` pale blue, `unless` red, a flag link green. A flag link joins an event whose `set:`
  gives a flag to an event whose `when:` reads it. Each node has three rows with a dot at each
  side: the first row's dots are the requires edges', the second's the unless edges', the third's
  the flag links'. An edge runs from the right-hand dot of the event that must come first (or the
  one that shuts the other out) to the left-hand dot of the event that waits on it.

### The toolbar

- **Reload** reads `data/story` again from disk (after you edit a file outside the tab). With
  unsaved edits or text not applied it asks first, since it drops them.
- **Save** writes the pools with unsaved edits (enabled only then; its tooltip names them).
- **All characters** and **All acts** (Act 1 to 3, No act) dim every event but the chosen
  character's or act's; **Search ids and text** dims every event whose id and lines do not hold
  the text. Dimmed events and their edges stay where they are.
- The legend, then the status line: events, shown, errors, warnings, lint, the placeholders left
  (`placeholders: N of M lines and choices`), and the unsaved files.
- Under the toolbar, a notice (green when saved, red when refused, yellow for a warning) and the
  list: the story's errors (red), the load's warnings (yellow, `warning: ...`), the lint's
  (orange, `lint: ...`), and a failed save's errors. A click on one selects its event.

### Linking events

- **Add a link by dragging** from a node's right-hand dot to another node's left-hand dot **on
  the same row**: the first row adds a `requires` (the node you drag to gains the one you drag
  from), the second row an `unless`. A drag between different rows does not connect. The flag row
  is refused with why: change the `set:` or the `when:` instead.
- **Remove a link** by picking up its right end (the left-hand dot it arrives at) and dropping it
  in empty space, or by right-clicking near the edge and choosing **Remove: ...**. Dropped back
  where it was, or a click without moving, changes nothing; dropped on another event's dot of the
  same row, it moves there.
- A link that would loop a `requires` chain back on itself is refused with the reason in the
  notice; nothing changes.

### Adding, renaming, deleting

- **+ Event** on a lane asks for a name (a free one suggested) and adds an empty event at the end
  of that pool, selected.
- **Rename...** in a node's menu renames the event and every `requires` and `unless` that names
  it, in every pool ([renames reset players](#ids-renames-and-saves)).
- **Delete...** in a node's menu, or the Delete key on the selected nodes, asks first, then
  deletes. An event another event names is refused, naming who names it; select both to delete
  them together. Each deleted event's comment block goes with it.

### The side panel: the Event tab

Select a node to show its event in the side panel: its id, its facts (errors and lint lines on
it), then:

- **The header controls**: Priority, Plays (once or repeat), Trigger (and its room for `enter`),
  Act, and When (type a condition, then Enter or **Set**; empty for none). Each change is made at
  once. A refused When keeps what you typed, tinted, and lists why.
- **The text**: the whole event in the file's format (its comment, `==` line, header, body). Edit
  it, then **Apply**: the text is checked and replaces the event; refused, the event stays as it
  was, the errors list under the text, and a click on one goes to its line (marked red). **Revert**
  drops your changes. A new name in the `==` line renames the event (but only Rename updates the
  events that name it: Apply refuses while another event names the old id).
- Text you have not applied is kept per event, across selections and other edits, until Apply or
  Revert. While an event has such text its header controls are off ("Apply or Revert them
  first"), so one edit never overwrites the other. If another edit changes that event meanwhile (a
  link dragged into it, say), the notice says so; Apply then puts your text in its place.

Nothing reaches the files until Save.

### Saving, quitting, and what cannot be undone

- **Save** writes every pool marked `(unsaved)`; the notice says `Saved <file>.`.
- **The editor's own save** (Cmd+S on a Mac, Ctrl+S elsewhere, Save All, running the project
  from the editor, Save & Quit) writes the unsaved pools too, so the game always plays what the
  tab shows. It **never applies text you have not applied**: that text is named in the notice as
  not saved, and stays until you Apply or Revert it.
- **Quitting the editor** with unsaved pools or text not applied lists them in the editor's own
  prompt. A save refused during Save & Quit cannot stop the quit (its message shows as the editor
  closes): save from the tab first.
- **A file changed on disk** since the tab read it (edited by hand, or by git) is never
  overwritten: Save is refused and says so. Copy your edited events' text aside, Reload, and make
  the edits again.
- **There is no undo** for the tab's edits (a link, an add, a rename, a delete, a header change,
  an Apply). Before Save, Reload drops every unsaved edit; after Save, git has the old file.

### A story with errors is read only

While the story has an error, the tab shows it but edits nothing: the text is read only, the
header controls, + Event, and the menus are off, and a drag is refused with the reason ("The story
has errors: fix the files and Reload to edit."). An event with an error is drawn from the file
with a red border and its errors in its facts. Fix the file in a text editor, then Reload.

### What-if

The side panel's **What-if** tab asks the story what would play, for a state you set, without
touching the files or your save. While it is shown:

- each pool's next event at the chosen moment is marked `next` in green in its title bar;
- the events that would not play are dimmed;
- every node has a **played** box: tick it to mark the event played in the What-if state (its
  `set:` effects do not run: set those flags in the panel), untick to unmark;
- the selected event lists why it would not play, in the file's words: `trigger: enter ludus (the
  moment is talk)`, `the game asks only narrator at verdict_up`, `already played`, `requires
  <id>`, `unless <id> (played)`, `when: <condition> (<name> is <value>, ...)`, `<pool> has spoken
  this return`; or `plays next at <moment>`, or `eligible, but <id> plays first`.

Back on the Event tab, all of it goes. The panel, top to bottom:

- **Blank** (nothing played, no runs, no flags) and **Load my save**, which reads a copy of the
  game's save (`~/Library/Application Support/Godot/app_userdata/Arena Roguelike/save.cfg` on a
  Mac). The save itself is never written or moved; the message under the buttons says what was
  loaded, or why not.
- **Moment**: the trigger (talk, each room's enter, the verdict's three, pick) and the facts the
  game hands in at it (`arrival` at an entry, `run_band` at the verdict, `round_band` and
  `round_loss` at the pick). An entry marks one event across all pools, as the game plays one.
- **Selected**: the selected event and its reasons.
- **This return**: who has spoken, and **Return** (a run's end: every character may speak again).
- **Profile**, **Last run**, **Story flags**: the counts, the last run's facts, and each declared
  flag, to set as you like. `tier_unlocked` is the last Profile row; with a win it reads at least
  2, as in the game, so a 1 there goes back to 2 while `wins` is above 0. `last_tier` is the last
  Last run row (0 for no run).

The What-if state stays across Reload and every edit. Played marks are kept by id, as a real save
keeps them: a renamed event reads as unplayed.

### Flags

The side panel's **Flags** tab is the flag map: each declared flag with its starting value, then
`set by` and `read by` with the events under them (a grounds door whose condition reads a story
flag is listed among its readers). A click on an event selects it.

### Lint in the tab

The lint runs after every load and every edit. Its warnings are the orange `N lint` badge, the
`lint: ...` lines in the list, and the lines in the selected event's facts; the status line counts
them. The lint never changes anything.

## The lint

`tools/story_lint.sh` checks the story from a terminal at the repo root, without the editor. It
prints the errors, the warnings (`[kind] message`), the flag map, the placeholder count
(`Placeholders: N of M lines and choices`), and a last line `STORY_LINT errors=.. warnings=..
placeholders=../..`. It exits 1 on any error (the game would leave an event out) and 0 otherwise.
`tools/story_lint.sh res://some/dir` lints another directory.

A warning never stops the game, but the test suite expects the shipped story to lint clean, so
fix each one or narrow the word list before committing. The warnings, and what to do:

| Kind | It says | What to do |
|---|---|---|
| `parse` | an inline comment is dropped when the file is rewritten | move the comment to its own line above |
| `never_asked` | never plays: the game asks only narrator at verdict_up, or never talks to narrator | move the event to the pool the game asks, or change its trigger |
| `merchant_filler` | never plays: lanista keeps a station | a merchant's filler is never heard: delete it, or make it a normal event |
| `never_fires` | it requires X and has it in its unless, or requires X, which never plays | fix the links |
| `moment_fact` | reads arrival (or run_band, round_band, round_loss) where the game never hands it in | read it only at its trigger, or change the trigger |
| `killer` | last_killer is compared with a word that is no enemy's id | fix the spelling (the message lists the ids) |
| `timed_lines` | never shown: a timed event shows only its first shown line | split it into events, or put conditions on the lines |
| `enter_clash` | two `enter` events of one room in different pools, not in each other's unless | one plays on an arrival and the other on a later one, a door walk perhaps: put each in the other's `unless` if only one should ever play, or give them different arrivals (`when: arrival == gate` and `when: arrival == start`) |
| `enter_repeat` | repeat on enter: it plays on every arrival there, door walks included | make it `once`, or rule the door out (`when: arrival == gate`) |
| `flag_unread` | sets a flag nothing reads | read it somewhere, or drop the `set:` |
| `flag_unset` | reads a flag nothing sets (it is always its starting value) | set it somewhere, or drop the reading |
| `flag_unused` | a flag declared that nothing sets or reads | remove it from `flags.txt`, or use it |
| `word` | says a word on the lint list | rewrite the line, or narrow the list (below) |
| `pick_unanswered` | nothing always answers the pick at some band and loss | add a `repeat` crowd `pick` event with no `requires` or `unless` whose `when` reads only `round_band` and `round_loss` |

The flag checks wait for a story without errors (an event that did not load may set or read a
flag); the tool and the status line say so.

### The word list

[`data/story/lint_words.txt`](../data/story/lint_words.txt) holds the words no line should say.
One entry a line, any case, `#` for a comment. Two forms:

- **A plain entry** (`menu`, `hit points`): a word or a phrase matched anywhere in a line or a
  choice, as whole words. Only terms that are never in the world's voice belong here.
- **A key entry** (`key: e`, `key: space`): a key's or an input's name, matched only where a line
  tells someone to use it: "press E", "hit the Space", "the E key", "the E-key", "use the mouse
  to". "Enter.", "a shift of guards", or "the key to the gate" pass. Such a frame never crosses
  punctuation: "Press. E" is not one. Every key bound to an action a line could name is listed
  (the moves as the plain `wasd`); the test suite fails until a new binding's name is added.

To add an entry, add a line. When an entry catches honest prose, narrow it: remove it, or make it
a phrase that pins its mechanic sense (`save the game` rather than `save`, `level up` rather than
`level`). Never mark the prose to silence the lint: the list is the one place to change.

## Playing from an act: `actus2`, `actus3`

To see the story from a later act, type `actus2` or `actus3` in the seed field of the title and
press Play. The game copies your save to `save.cfg.bak` beside it, replaces the save with that
act's preset from [`acts.json`](../data/story/acts.json) (the profile's counts and flags, the
story flags, the events already played), and plays on from there (both presets have returned, so
you land in the Ludus). `tabula` wipes the save the same way and plays a first run. To get your own save back,
copy `save.cfg.bak` over `save.cfg` with the game closed.

- The presets are placeholders until the acts are defined (M9).
- After an act cheat the run log is empty, so `last_outcome`, `last_verdict`, `last_band`, and
  `last_killer` read `none` and `last_tier` reads 0: content gated on the last run cannot be
  previewed from an act's start. Play a run, or use What-if.
- A preset names events by id. If you rename or delete one in the tab, the notice warns
  ("acts.json names <id> (act 2, 3): change it there by hand before the next load."); the tab does
  not edit `acts.json`. Fix it by hand, or the next load (Reload, the lint, the game) reports an
  error.

## The placeholders to replace

Every shipped line and choice is a placeholder: its text starts with `PLACEHOLDER`, which the game
strips before showing it. To find what is left:

- the yellow `N placeholder` badge on a node, and the status line's `placeholders: N of M lines
  and choices`;
- the lint's `Placeholders: N of M` line;
- the search box: `PLACEHOLDER` dims every event that has none left.

Replace a placeholder by rewriting the line without the marker. Keep the shape until you mean to
change it: the shipped events carry the game's beats (each character's introduction, their word
after the first win, the narrator's lines at the verdict and the wake, the crowd's judgement for
each band and loss), and some are named by `acts.json`.

## Walkthrough 1: your first event

You will add a line for the doctor and hear it in the Sanitarium.

1. Open the editor and the **Story** tab.
2. On the `doctor` lane, click **+ Event**, name it (say `my_first`), and OK. The new event is
   selected.
3. In the side panel, set **Priority** to `story`, so it plays before the doctor's other news.
4. In the text, after the header, add a blank line and a line of your own:
   `DOCTOR: <your line>`. Click **Apply**. If it is refused, read the error under the text, fix
   the line, and Apply again.
5. Open **What-if**, click **Load my save**, and leave the moment at `talk`: your event should be
   marked `next` in the doctor's lane. If it is not, select it and read why (the doctor may have
   spoken this return).
6. Click **Save** (the lane loses its `(unsaved)` mark).
7. From a terminal at the repo root, `tools/run.sh`. Play from the title (after your first run,
   Play lands in the Ludus), walk
   through the right-hand door to the Sanitarium, and press E on the doctor (the gold bubble over
   their head says they have something new). If the doctor already said something new this
   return, play a run first.

Run `tools/story_lint.sh` before committing: zero errors, zero warnings.

## Walkthrough 2: an event gated across two characters

The doctor mentions the veteran; the veteran answers only once the doctor has spoken.

1. On the `doctor` lane, add `speaks_of_him`, set its Priority to `story`, then write a line or
   two in its text and Apply.
2. On the `veteran` lane, add `heard_of_it` the same way: Priority `story`, a line, Apply.
3. Drag from the right-hand dot of `doctor.speaks_of_him`'s **first** row to the left-hand dot of
   `veteran.heard_of_it`'s first row. A pale blue edge joins them, and the veteran's text now has
   `requires: doctor.speaks_of_him`.
4. In What-if (Load my save, moment `talk`): `veteran.heard_of_it` is dimmed and says `requires
   doctor.speaks_of_him`. Tick the doctor event's **played** box: the veteran's event is marked
   `next` (if the veteran has not spoken this return).
5. Save, then `tools/run.sh`: talk to the doctor in the Sanitarium first, then walk back to the
   Ludus. The veteran now has the bubble; E plays your event. Talk to the veteran first instead,
   and your event does not play: it waits for the doctor's (and, if the veteran says something
   else new meanwhile, for the next return).

A variant with a flag: Save, declare a flag in `flags.txt` (say `heard_the_doctor`), and
Reload (it reads the flags again; with unsaved edits it would drop them). Put
`set: heard_the_doctor` at the end of the doctor's event, remove the requires edge, and give the
veteran's event `when: heard_the_doctor`. A green flag link joins them, and the Flags tab shows
who sets and who reads it.

## The character page template

One page per character, in your own words; the story is built from these. For each of the five
in the grounds (the lanista, the armourer, the veteran, the doctor, the attendant), and any you
add:

```text
Name:
Background (a paragraph: where they come from, how they came to the colosseum):
What they want:
What they hide:
Voice (a few lines they might say, in their own words):
-
-
-
The arc over three acts:
  Act 1 (the arrival, the crowd's taste, the thumb always up):
  Act 2 (the wins that cost more, the thumb a judgement, the emperor coming down):
  Act 3 (the descent, the emperor beaten, the reveal):
```

The emperor gets two faces:

```text
Name:
His public face (as the arena and the grounds see him):
His true nature:
What he knows about the gladiator's immortality:
What he wants; what he hides:
Voice (a few lines from the box, and a few up close):
The arc over three acts:
```

The narrator and the crowd need no page of their own, but their voice is worth a paragraph each:
who is speaking at the verdict, and how the crowd judges.
