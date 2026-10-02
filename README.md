# fisch-botting

Fisch fishing hub + rod progression. The script lives in the executor's `workspace/fishtp/` folder; `loader.lua` joins the parts in `fishtp/parts.txt` and runs them.

## UI

Own UI library in `fishtp/modules/FishUI.lua`.

- **RightShift** shows/hides the window; drag it by the title bar.
- **Settings tab**
  - Left: theme. RGB sliders for accent, background and text (default: purple accent, gray background, white text), a rainbow accent switch, and saved themes (create, save, load, delete, autoload).
  - Right: configs. Every toggle, slider and dropdown on the Fishing and Progression tabs is saved (create, save, load, delete, autoload). The TP tab and text inputs are left out.
- Files: `fishtp/configs/*.json`, `fishtp/themes/*.json`, `fishtp/autoload.json`.
