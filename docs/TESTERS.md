# Arena Roguelike, tester build 0.6.0-rc1

Thanks for testing. This is an early, unsigned build of a small action roguelike. It is free and has
no online features. The only thing it writes outside its own folder is Godot's per-user data folder,
`%APPDATA%\Godot\app_userdata\Arena Roguelike\` on Windows or
`~/.local/share/godot/app_userdata/Arena Roguelike/` on Linux, which holds your volume settings
(`settings.cfg`), a log (`logs/`), and your progress (`save.cfg`, with a `save.cfg.bak` if a file
could not be read); deleting that folder resets the volumes and the progress. A save from an
earlier build (`0.5.0-rc1` to `0.5.0-rc3`) loads; what rc1 bought counts for nothing now.

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

## What we want to know

Play at least two full runs (win or fall), walk every room you can find between them, talk to
whoever will talk, and buy something at the post. Then tell us:

1. The grounds: how many rooms did you find, and how did you get from one to the next? Did you
   ever look for a way through and not find it? The walk to the arena: fine, or a chore?
2. The people: who did you talk to, and did you go back? The small bubble over some heads: what
   did you take it to mean, and did it go when you expected?
3. The talk: the box, the voices, the speed of the text. Too fast, too slow, too loud? Did you pick
   a reply, and did anyone seem to remember it later?
4. The meter under the hearts: when did you see it drop, and how fast? Did it drop while you
   thought you were doing well? Against the boss?
5. After a round, the line over the cards: what did it say, did it fit how the round went, and
   could you read it?
6. Did a card ever come up that you could not take? What did you make of it, and did it feel fair?
7. The fall: the voice at the bottom of the screen while the emperor decides. Did you read it, and
   did it hide anything you wanted to see? The hand over the box: what did it mean?
8. If you fell with `verso` (below): what happened after the end screen, and where did you go
   from there?
9. The post: which of its four things did you buy, did the names tell you enough, and did the next
   run feel different for it?
10. The boss: how long did it take, and where did you fall to it, if you did? Fair?
11. Where did the game explain something to you (a caption, a label, a hint, a line someone said)?
    We want that answer to be "nowhere"; if it is not, tell us where.
12. Sound and music: the run's loop, the boss's, the grounds', the crowd, the voices, any silence:
    too loud, too soft, missing anywhere?
13. Anything ugly, laggy, or broken (say what you were doing).

The end screen shows a seed number. Include it with any bug so we can replay your run.

Send feedback to Benjamin however you got this build.

## For testers only

The seed field on the title takes three code words instead of a number: `permawhat?` (no damage),
`verso` (the thumb goes down), `dives` (1000 coins). A cheated run says so on its end screen.
`tabula` wipes the save (the old one is kept beside it as `save.cfg.bak`) and plays from the start,
the first return to the grounds included.
