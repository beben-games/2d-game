# Milestone 2 feel checklist

Play a full run (win or die), then rate each line good / meh / bad with a note. The milestone
closes when a run has a beginning and an end that feel right.

- Shooter: can you always tell a bolt is coming? Is the bolt dodgeable at 120 px/s? Do two shooters firing in lockstep feel unfair? (telegraph_time, preferred_range in data/enemies/shooter.tres; speed in data/weapons/shaman_bolt.tres)
- Dash: does it get you out of a pin and past bolts? Cooldown too long or too short? (DashRules in scripts/dash_rules.gd)
- Wave pacing per room: breathers, group sizes, the room 4 crowd. (data/waves/*.tres)
- Room size at one screen: enough space to kite, or cramped? (RoomDef width/height)
- Door and transition: does the fade read as moving on? Is the entry position right? (FADE_TIME in scripts/main.gd)
- Heart reward: worth walking to? Two hp right? It is taken on re-entry, not by standing on it. (HEAL in scripts/heart_pickup.gd)
- HUD: legible at a glance, in the way of anything? (scenes/ui/hud.tscn)
- Summary: the right numbers, the right beat before it shows? (DEATH_SUMMARY_DELAY, WIN_SUMMARY_DELAY in scripts/main.gd)
- A full run: how long did it take, and did it end the way you expected?
