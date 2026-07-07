# Arcadia Mod Installation

This mod merges Arcadia content into a **copy** of [Reforged Eden 2](https://steamcommunity.com/sharedfiles/filedetails/?id=3143225812) (Steam Workshop `3143225812`). It is not a standalone scenario.

**Recommended:** use [`Install-ArcadiaMod.ps1`](Install-ArcadiaMod.ps1) after preparing your RE2 scenario copy. It automates the merge and copy steps below and is much faster than doing them by hand.

---

## Before You Start (Required for Both Methods)

1. Grab a fresh copy of Reforged Eden 2 from the workshop
   - `D:\Program Files (x86)\Steam\steamapps\workshop\content\383120\3143225812`

2. Create a copy of this folder in your Empyrion installation's scenarios folder
   - `D:\Program Files (x86)\Steam\steamapps\common\Empyrion - Galactic Survival\Content\Scenarios`
   - So you should have something like this `D:\Program Files (x86)\Steam\steamapps\common\Empyrion - Galactic Survival\Content\Scenarios\3143225812`

3. Rename `3143225812` however you like. We'll call it `MyRE2Scenario`. So now you should have this:
   - `D:\Program Files (x86)\Steam\steamapps\common\Empyrion - Galactic Survival\Content\Scenarios\MyRE2Scenario`

Always start from a **new** RE2 copy. If you reinstall Arcadia on the same scenario folder, merged content will be duplicated.

---

## PowerShell Installation (Recommended)

The script [`Install-ArcadiaMod.ps1`](Install-ArcadiaMod.ps1) in this repo performs steps 4–11 of the manual install automatically.

### What you need

- Windows PowerShell 5.1 or later
- Steps 1–3 completed above (a renamed RE2 scenario folder in `Content\Scenarios`)
- This ArcadiaProject repo on disk (the script defaults to its own folder for mod files)

### Install

Open PowerShell, go to this repo folder, and run:

```powershell
cd "D:\Path\To\ArcadiaProject"

.\Install-ArcadiaMod.ps1 -ScenarioPath "D:\Program Files (x86)\Steam\steamapps\common\Empyrion - Galactic Survival\Content\Scenarios\MyRE2Scenario"
```

Replace the `-ScenarioPath` value with the full path to **your** RE2 scenario copy from step 3.

### Preview first (optional)

To see what would change without writing any files:

```powershell
.\Install-ArcadiaMod.ps1 -ScenarioPath "D:\Program Files (x86)\Steam\steamapps\common\Empyrion - Galactic Survival\Content\Scenarios\MyRE2Scenario" -WhatIf
```

### What the script does

- Merges Arcadia configs into RE2 `Dialogues.csv`, `Dialogues.ecf`, `TokenConfig.ecf`, `TraderNPCConfig.ecf`, `PDA.csv`, `PDA.yaml`, and `Sectors.yaml`
- Copies all `Playfields`, `Prefabs`, and `SharedData` files from this repo into your scenario (SharedData is additive only; existing RE2 files are not modified)
- Warns if Arcadia content may already be installed (continues anyway; use a fresh RE2 copy to reinstall cleanly)

### What the script does not do

- Does **not** copy Reforged Eden 2 from the workshop (steps 1–3 are still manual)

### After running the script

1. Select `MyRE2Scenario` in the Empyrion scenario menu
2. Confirm **Arcadia Station** appears on the galaxy map near `[90, 0, -45]`

---

## Manual Installation Steps

Use these steps if you prefer to install by hand, or if you need to troubleshoot what the script automates.

### Merge Arcadia configs

4. Next we'll merge the ArcadiaProject files into your new `MyRE2Scenario` scenario folder

5. `ArcadiaProject\Content\Configuration` ==merge==> `MyRE2Scenario\Content\Configuration`
   - `Dialogues.Arcadia.csv` ==merge values into==> `Dialogues.csv` (Keep existing RE2 values, add new Arcadia values)
   
   - Copy all rows from `Dialogues.Arcadia.csv` into `Dialogues.csv` immediately after the header row
   
   - `Dialogues.Arcadia.ecf` ==merge values into==> `Dialogues.ecf` (Keep existing RE2 values, add new Arcadia values)
   
   - Copy all values from `Dialogues.Arcadia.ecf` before `{ +Dialogue Name: Trader_DialogueSwitch_Start` line in `Dialogues.ecf` (At the beginning of the file after the comments)
   
   - `TokenConfig.Arcadia.ecf` ==merge values into==> `TokenConfig.ecf` (Keep existing RE2 values, add new Arcadia values)
   
   - Copy entire contents of `TokenConfig.Arcadia.ecf` and paste at the end of `TokenConfig.ecf`
   
   - `TraderNPCConfig.Arcadia.ecf` ==merge values into==> `TraderNPCConfig.ecf` (Keep existing RE2 values, add new Arcadia values)
   
   - Copy entire contents of `TraderNPCConfig.Arcadia.ecf` and paste at the end of `TraderNPCConfig.ecf`

6. `ArcadiaProject\Extras\PDA` ==merge==> `MyRE2Scenario\Extras\PDA`
   - `PDA.Arcadia.csv` ==merge values into==> `PDA.csv` (Keep RE2 values, add Arcadia values)
   
   - Copy all rows from `PDA.Arcadia.csv` into `PDA.csv` immediately after the header row
   
   - `PDA.Arcadia.yaml` ==merge values into==> `PDA.yaml` (Keep RE2 values, add Arcadia values)
   
   - Copy all values from `PDA.Arcadia.yaml` after `Chapters:` line in `PDA.yaml`

7. `ArcadiaProject\Sectors` ==merge==> `MyRE2Scenario\Sectors`
   - `Sectors.Arcadia.yaml` ==merge values into==> `Sectors.yaml` (Keep existing RE2 values, add new Arcadia values)
   - Find this line in the Sectors.yaml
   - ```yaml
          - ['0,0,0', 'Alpha [Sun Back]', SpaceWarpTargetFixed, '']
     ```
   - Copy and paste the entire contents of `Sectors.Arcadia.yaml` on a new line after this line. Persist all spacing, ensure yaml is well-formatted.

### Copy Arcadia files and folders

8. `ArcadiaProject\Playfields` ==copy folders==> `MyRE2Scenario\Playfields`

9. `ArcadiaProject\Prefabs` ==copy files==> `MyRE2Scenario\Prefabs`

10. `ArcadiaProject\SharedData\Content\Bundles\ItemIcons` ==copy files==> `MyRE2Scenario\SharedData\Content\Bundles\ItemIcons`

11. `ArcadiaProject\SharedData\Extras\PDA` ==copy files==> `MyRE2Scenario\SharedData\Content\Extras\PDA`
