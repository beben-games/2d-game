# Arena Roguelike, tester build 0.7.0-rc1

Thanks for testing. This is an early, unsigned build of a small action roguelike. It is free and has
no online features. The only thing it writes outside its own folder is Godot's per-user data folder,
`%APPDATA%\Godot\app_userdata\Arena Roguelike\` on Windows or
`~/.local/share/godot/app_userdata/Arena Roguelike/` on Linux, which holds your volume settings
(`settings.cfg`), a log (`logs/`), and your progress (`save.cfg`, with a `save.cfg.bak` if a file
could not be read); deleting that folder resets the volumes and the progress. A save from an
earlier build (`0.5.0-rc1` to `0.6.0-rc4`) loads; what `0.5.0-rc1` bought counts for nothing now.

## Running it

- Windows: unzip, run `ArenaRoguelike.exe`. SmartScreen will warn because the build is not signed:
  click "More info", then "Run anyway".
- Linux (x86_64): unzip, then `chmod +x ArenaRoguelike.x86_64` and run it. Needs OpenGL 3.3.

The game runs fullscreen at 1280x720 scaled. Quit from the title's Quit button or the pause screen's
"Quit game" (Alt+F4 on Windows or your window manager's close also works).

## Controls

- Move: WASD. Aim: mouse. Shoot: hold left click. Dash: Space or right click.
- E: use what is in reach (a door, the post, the rack, the lift, someone to talk to).
- Talking: E, Enter, or a click goes on; 1 to 5 or a click picks a reply.
- Cards: click one, or press 1 to 5. The picker may show a Reroll button.
- Esc or Tab: the pause screen, in three tabs (Options, Boons, Training); Esc opens it on Options,
  Tab on Boons, either closes it. R: restart the run.
- Enter on the title starts; type a seed first to replay a run.
- On the end screen: Enter or a click continues, Esc returns to the title.

## What it is

Eight rounds in one arena, then the boss. Between runs you are in the grounds: a few rooms with
people in them, a post that sells four things (Offer, Reroll, Mercy, Reach), and the way back to
the arena. Every line anyone says is a placeholder for now: tell us where the words sit and when
they come, not what they say.

New in this build: a second, bigger arena with enemies and a boss of its own. Finding the way to it
is part of the test; if you cannot wait, see "For testers only".

## What we want to know

Play a full run of the first arena to the end (win if you can), go back to the grounds, and look
around; then play the second arena at least once, twice if you can. Then tell us:

1. The lifts in the Hypogeum: how many did you see, which could you ride, and did that
   ever change? What did you take the shut ones to mean?
2. The bigger arena: did you ever lose track of where you were, or of the enemies? The arrows at
   the edge of the screen: did you notice them, and did you follow them?
3. The edge of the screen: did a shot (yours or theirs) ever do something there you did not
   expect?
4. Did anything hurt you that you never saw coming? Where were you, and what was it?
5. The charger: could you tell where it was going before it went? What worked against it?
6. The one carrying a banner: what did you make of the ring on the floor and of the enemies near
   it? Who did you go for first?
7. The second arena's boss: which did you kill first, and what changed
   when one fell? How long did the fight take, and was it fair?
8. The second arena as a whole: too long, too hard, too easy? Did it pay better than the first?
9. The meter under the hearts: did it behave as in the first arena?
10. Where did the game explain something to you (a caption, a label, a hint, a line someone said)?
    We want that answer to be "nowhere"; if it is not, tell us where.
11. Sound and music: anything too loud, too soft, missing, or wrong for what you saw (the new
    enemies, the boss, a lift)?
12. Anything ugly, laggy, or broken (say what you were doing).

The end screen shows a seed number. Include it with any bug so we can replay your run.

Send feedback to Benjamin however you got this build.

## For testers only

The seed field on the title takes three code words instead of a number: `permawhat?` (no damage),
`verso` (the thumb goes down), `dives` (1000 coins). A cheated run says so on its end screen.
`tabula` wipes the save (the old one is kept beside it as `save.cfg.bak`) and plays from the start,
the first return to the grounds included. `scalae` opens every lift there is on your save (nothing
is wiped) and plays on.
