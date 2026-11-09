# [TF2] Behold, the Skeleton King!

Inspired by FlaminSarge's and Pelipoika's [Be the Skeleton King](https://forums.alliedmods.net/showthread.php?p=2324245)

Allows admins and other plugins to turn players into the Skeleton King.

The Skeleton King is made to be faithful to the boss NPC both visually and mechanically, while still being loyal to RED/BLU.

[Video Demonstration](https://youtu.be/oibP6l0u05c)

### Dependencies

- SourceMod 1.12+
- This plugin will not work without the custom model provided in the repo!

### Admin Command

- `sm_beskeletonking <#userid|name> [health] [0/1 (Default: 0) Use alternate skin] [0/1 (Default: 0) Do spawn animation]` - Choose a player to become the Skeleton King. Optionally set the health, alternate skin, and whether to do the spawn animation for the player. Setting the health to 0 or below will default to the value of `sm_beholdskeletonking_maxhealth`.

### Convars

- `sm_beholdskeletonking_dropammo (Default 0)` - Whether Skeleton King should drop an ammo kit on death.
- `sm_beholdskeletonking_maxhealth (Default 1000)` - Skeleton King max health.
- `sm_beholdskeletonking_melee_damage (Default 100)` - Skeleton King melee damage.
- `sm_beholdskeletonking_stomp_radius (Default 200)` - Skeleton King stomp radius.
- `sm_beholdskeletonking_stomp_damage (Default 100)` - Skeleton King stomp damage.
- `sm_beholdskeletonking_stomp_cooldown (Default 8.0)` - Skeleton King stomp cooldown.
- `sm_beholdskeletonking_spelltier (Default 2)` - The tier of spell Skeletong King should drop (0 = None, 1 = Normal, 2 = Rare)