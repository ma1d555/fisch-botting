# fisch-botting

Nova: Fisch fishing hub + rod progression.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ma1d555/fisch-botting/claude/gallant-lamport-7dusyx/nova/loader.lua"))()
```
 The script lives in the executor's `workspace/nova/` folder; `loader.lua` joins the parts in `nova/parts.txt` and runs them.

## UI

Own UI library in `nova/modules/NovaUI.lua`.

- **RightShift** shows/hides the window (rebind in Settings > Interface); drag it by the title bar, resize it from the corner. Position and size are remembered. Every tab has a search box, long dropdowns have one too.
- **Settings tab**
  - Left: theme. RGB sliders for accent, background and text (default: purple accent, gray background, white text), a rainbow accent switch, and saved themes (create, save, load, delete, autoload).
  - Right: configs. Every toggle, slider and dropdown on the Fishing and Progression tabs is saved (create, save, load, delete, autoload). The TP tab and text inputs are left out.
  - Configs also keep your saved Locations and TP positions, and can be exported to the clipboard / imported from pasted text.
  - Interface: toggle key, panic key, reset window.
- **Misc tab**: session stats (catches, C$, XP, levels per hour), Anti AFK, Auto Rejoin, Pause Near Players, Discord webhook alerts (rod obtained, stuck, done, panic, disconnect), catch alerts by rarity or fish name (webhook and/or toasts), a switch for all toasts.
- **Panic key** (End by default) stops auto cast/reel/shake/sell, the progression and anything held down.
- Files: `nova/configs/*.json`, `nova/themes/*.json`, `nova/autoload.json`, `nova/ui.json` (keys, window layout, webhook URL).
