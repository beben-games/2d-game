# Arena Roguelike, tester build 0.5.0-rc2

Thanks for testing. This is an early, unsigned build of a small action roguelike. It is free and has
no online features. The only thing it writes outside its own folder is Godot's per-user data folder,
`%APPDATA%\Godot\app_userdata\Arena Roguelike\` on Windows or
`~/.local/share/godot/app_userdata/Arena Roguelike/` on Linux, which holds your volume settings
(`settings.cfg`), a log (`logs/`), and your progress (`save.cfg`, with a `save.cfg.bak` if a file
could not be read); deleting that folder resets the volumes and the progress. A save from the
first build (`0.5.0-rc1`) loads; what it bought there counts for nothing now.

## Running it

- Windows: unzip, run `ArenaRoguelike.exe`. SmartScreen will warn because the build is not signed:
  click "More info", then "Run anyway".
- Linux (x86_64): unzip, then `chmod +x ArenaRoguelike.x86_64` and run it. Needs OpenGL 3.3.

The game runs fullscreen at 1280x720 scaled. Quit from the title's Quit button or the pause screen's
"Quit game" (Alt+F4 on Windows or your window manager's close also works).

## Controls

- Move: WASD. Aim: mouse. Shoot: hold left click. Dash: Space or right click.
- Cards: click one, or press 1 to 5. The picker may show a Reroll button.
- Tab or Esc: the pause screen (your build, the volumes, restart, quit to title, quit the game).
  R: restart the run.
- Enter on the title starts; type a seed first to replay a run.
- On the end screen: Enter or a click continues, Esc returns to the title.

## What it is

Eight rounds in one arena, then the boss. Between runs you are in the grounds, where the post
sells four things.

## What we want to know

Play at least two full runs (win or fall), and buy something at the post between them, then tell us:

1. The meter under the hearts, with the two heads beside it: what did you make of it, what moved
   it up, and what moved it down? Did it ever drop while you were doing nothing wrong?
2. The coins on the floor: did they come to you, and from how far? The wait after a pick before
   the next round: a breath, or dead time?
3. The crowd: what did you hear, and when? Did you reach the loudest reaction, and how often?
4. When the cards come up: did a fourth or a fifth card ever arrive? What did you notice when it
   did?
5. The fall: what happened between going down and the hand over the box? Too long, too short, or
   right? Where was the camera looking?
6. The hand itself: what did it mean, and did it read as someone's?
7. The end screen names a gate. Did you meet two names? What did they tell you?
8. The grounds: the post sells four things. Which did you buy, and did the next run feel
   different for it? If you ever fell and kept fighting, tell us about that moment.
9. The boss: how long did it take, and where did you fall to it, if you did? Fair?
10. Where did the game explain something to you (a caption, a label, a hint)? We want that answer
    to be "nowhere"; if it is not, tell us where.
11. The fights: rounds 4 to 7, as before. Where did you fall, and did it feel fair?
12. Sound and music: the run's loop, the boss's, the grounds', the crowd, the drum, the fanfare:
    too loud, too soft, missing anywhere?
13. Anything ugly, laggy, or broken (say what you were doing).

The end screen shows a seed number. Include it with any bug so we can replay your run.

Send feedback to Benjamin however you got this build.

## For testers only

The seed field on the title takes three code words instead of a number: `permawhat?` (no damage),
`verso` (the thumb goes down), `dives` (1000 coins). A cheated run says so on its end screen.
