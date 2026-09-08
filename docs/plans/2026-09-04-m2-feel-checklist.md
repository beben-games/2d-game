# Milestone 2 feel checklist

Play a full run (win or die), then rate each line good / meh / bad with a note. The milestone
closes when a run has a beginning and an end that feel right.

- Shooter: can you always tell a bolt is coming? Is the bolt dodgeable at 120 px/s? Do two shooters firing in lockstep feel unfair? (telegraph_time, recover_time (fire cadence, and what two shooters lock to), preferred_range in data/enemies/shooter.tres; projectile_speed in data/weapons/shaman_bolt.tres)
- Dash: does it get you out of a pin and past bolts? Cooldown too long or too short? (DashRules in scripts/dash_rules.gd)
- Wave pacing per room: breathers, group sizes, the room 4 crowd. (data/waves/*.tres; SPAWN_INTERVAL in scripts/wave_progress.gd)
- Room size at one screen: enough space to kite, or cramped? (RoomDef width/height in data/rooms/*.tres)
- Door and transition: does the fade read as moving on? Is the entry position right? (FADE_TIME in scripts/main.gd for the fade; Room.entry_position() in scripts/room.gd for the entry)
- Heart reward: worth walking to? Two hp right? Walking onto it heals; a full player standing on it when hit has to step off and back on. Fair? (HEAL in scripts/heart_pickup.gd)
- HUD: legible at a glance, in the way of anything? (scenes/ui/hud.tscn)
- Summary: the right numbers, the right beat before it shows? (DEATH_SUMMARY_DELAY, WIN_SUMMARY_DELAY in scripts/main.gd)
- A full run: how long did it take, and did it end the way you expected?
