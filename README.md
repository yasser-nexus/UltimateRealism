# Ultimate Realism Framework

An industrial-grade, modular ultra-realism framework for **GTA V**, written in **C#** for
**ScriptHookVDotNet3** (.NET Framework 4.8, x64).

It simulates the parts of the world the base game abstracts away — metabolism and
thermoregulation, ballistic trauma and haemorrhage, tyre and engine thermodynamics, real
surface friction, pedestrian self-preservation and dispatch response — while being
**non-destructive** and **conflict-aware** by construction.

```
  +-----------------------------------------------------------------------+
  |  UltimateRealism.dll  (single assembly, no dependencies)              |
  |                                                                       |
  |  [Compatibility]  safety + conflict arbitration + diagnostics         |
  |  [Survival]       metabolism, hydration, fatigue, thermoregulation    |
  |  [Trauma]         wounds, bleeding, shock, limp, recoil, pain         |
  |  [VehicleDynamics] surface grip, braking, traction, steering          |
  |  [VehicleMechanics] fuel, engine heat, oil, tyres, brakes             |
  |  [AmbientAI]      weather/danger/posture reactions, shelter, chatter  |
  |  [EmergencyDispatch] real call delay, out-of-sight spawn, self-drive  |
  |  [AdvancedKinematics] slope adaptation, leg IK, physique variation    |
  |  [EnvironmentLighting] exposure + shadow + reflection calibration    |
  |  [DebugOverlay]   live diagnostics overlay                            |
  +-----------------------------------------------------------------------+
              |                    |                      |
      UltimateRealism.ini   UltraRealism.log   UltimateRealism_SystemReport.txt
```

---

## 1. The engineering mandates, and how they are met

### 1.1 Zero-conflict compatibility

| Mechanism | Where | What it prevents |
|---|---|---|
| **Runtime-only mutation.** Nothing is written to `handling.meta`, `visualsettings.dat`, `timecycle` or any other file. | everywhere | conflicts with VisualV / NaturalVision / car packs, and uninstall damage |
| **Compare-and-restore handling edits.** A handling field is only written back if it still holds the value *we* wrote. | `VehicleDynamicsModule` | two mods fighting over `fTractionCurveMax` every frame |
| **`StateReverter` leases.** Every persistent override registers a revert action, executed in reverse order on disable / unload / fault. | `Core/StateReverter.cs` | mods leaving grip reduction, clipsets or engine multipliers behind |
| **Auto-yield.** If a dedicated fuel / damage / dispatch mod is sensed, the overlapping subsystem vetoes itself. | `CompatibilityModule`, `[Compatibility] AutoYield.*` | two fuel models draining the same tank |
| **Read-only sensing.** Other mods are detected by scanning the `scripts` folder, never by poking their runtime state. | `ModSensor` | hooking conflicts, race conditions |
| **Native quarantine.** A native that throws is counted and quarantined; dependent features degrade. | `NativeGuard` | crash loops caused by another mod hooking the same native |
| **Per-module fault isolation.** Five consecutive exceptions disable one module and revert only its overrides. | `ModuleBase.TickInternal` | one bug taking the whole script down |

### 1.2 Cross-version resilience

* No hardcoded memory addresses, offsets or call gadgets — **anywhere** (`grep -rn "0x" src/`).
* Game build is parsed from `Game.Version` into an integer; features are gated by
  **reviewable, named build constants** (`GameVersionInfo.Build_1_0_2802`, …).
* Unrecognised (brand-new) builds are **not** treated as errors: the framework assumes the
  modern API surface and lets runtime quarantine remove whatever actually broke.
* `NativeGuard` validates every native three ways: the `Hash` enum (compile-time table),
  a version-gate table, and a runtime failure counter.
* `SafeMemory` exists but is opt-in and never required: pattern scan → pointer validation →
  protected access → protection restore. If a pattern is absent on a new patch, the dependent
  feature disables itself instead of crashing.

### 1.3 High-refresh and multi-hour stability

A per-frame budget is the wrong unit above 60 Hz: 3 % of a 4.2 ms frame at 240 fps is *four times*
the CPU per second of 3 % of a 16.6 ms frame. `PerformanceGovernor` therefore budgets **CPU
milliseconds per second of wall-clock time** (28 ms default) and stretches module intervals when the
budget is exceeded, with a floor/ceiling that is reported live.

* Frame spikes are detected against a rolling **median** frame time, not a mean (one hitch must not
  poison the baseline) and trigger an immediate back-off.
* No allocation in any per-frame path; every cache is bounded and evicts by least-recent use.
* No `GC.Collect()` anywhere; memory is measured with `GC.GetTotalMemory(false)` and logged with the
  owning cache named. Theories about leaks are answered by the report, not by guesswork.
* All timers use real elapsed milliseconds, so a stretched tick produces a *larger step*, not a
  slower process — hour four behaves exactly like minute one.

Full mechanism table: [`docs/ARCHITECTURE.md` §7.1](docs/ARCHITECTURE.md).

### 1.4 Free and open source, permanently

MIT licensed, no telemetry, no network calls, no auto-updater, no account, no paid tier, no
"premium" features held back. The entire feature set ships in the DLL you compile from this source,
and the `.ini` is the only product surface. Contributions are welcome; the project has nothing to
monetise and no incentive to add anything that watches you.

### 1.5 Immersive realism

Every model is expressed in **physical units** before being normalised for gameplay. Full
equations and tuning guidance: [`docs/PHYSICS_MODELS.md`](docs/PHYSICS_MODELS.md).

| Domain | Model |
|---|---|
| Metabolism | MET-based energy expenditure (`kcal/min = MET·3.5·kg/200`), sweat-scaled water turnover, sleep-pressure fatigue |
| Thermoregulation | first-order heat balance; ambient = seasonal + diurnal + weather + zone + lapse rate; wet clothing loses 75% insulation; shivering thermogenesis; evaporative cooling limited by humidity |
| Trauma | hit-region from the damaged bone, wound class from weapon family, severity from damage actually landed, 5 L blood compartment, shock/collapse/bleed-out thresholds |
| Pain / adrenaline | adrenaline masks pain, then crashes: pain floods back, fatigue spikes |
| Mobility | leg injury → limp (speed + injured movement clipset), arm injury → accuracy loss + camera recoil |
| Vehicle grip | `grip = surface · weatherRetention · tyreCondition · tyreTemperature`; aquaplaning above a speed threshold; wheelspin from `fLowSpeedTractionLossMult` |
| Engine | first-order thermal model with load-based heat and airflow cooling; overheat → derate → damage → stall; cold-start rich mixture |
| Fuel | load-based consumption (idle draw + throttle·RPM), tank leaks on damage, EVs get a battery model with regen |
| Tyres | per-wheel wear integrating slip, abrasiveness and speed; temperature build-up; punctures and blow-outs |
| Brakes | energy-based temperature, fade and recovery via `BrakePower` |
| Pedestrians | rotating AI budget; shelter-seeking in weather, gunfire panic, hostile-posture reaction, startle and horn |
| Dispatch | call-handling delay, nearest station, out-of-sight spawn on a real road node, unit drives itself in, re-tasking instead of double-dispatching |
| Movement | terrain gradient from four ground samples → move-rate multiplier (uphill costs, downhill returns less), leg IK foot planting, Euphoria balance stiffness scaled by body mass and slope |
| Procedural bodies | deterministic per-ped physique (stature 0.88–1.12, mass 0.85–1.18) driving gait, balance, run speed and optionally the collision capsule — the world stops reading as clones |
| Lighting | exposure target from sun angle + weather (night 0.92, dusk 0.96, day 1.00, +0.04 rain), shadow-cascade scale from sun height, per-entity water reflections, rain-driven wet sheen |
| Performance | CPU **ms per second** governor (not per frame), median-based frame-spike detection, GC/gen-0 telemetry, bounded caches |

---

## 2. Installation

**Requirements**

| Component | Version |
|---|---|
| GTA V | any build supported by your ScriptHookV (1.0.1290 … current) |
| [ScriptHookV](http://www.dev-c.com/gtav/scripthookv/) | matching your game build |
| [ScriptHookVDotNet3](https://github.com/scripthookvdotnet/scripthookvdotnet/releases) | **3.6.0 or newer** |
| .NET Framework | 4.8 (already present on current Windows 10/11) |

**Steps**

1. Put `UltimateRealism.dll` in `<GTA V>\scripts\`.
2. For the first run, also put `UltimateRealism.ini` in the same folder
   (if you forget, the DLL extracts its embedded default on first launch).
3. Launch the game. On start you get one notification and `scripts\UltraRealism.log`.

**Uninstalling is a file delete.** Nothing is patched, no save game is edited, and no state
survives the session except `UltimateRealism_State.ini` (your survivor's condition), which you
can also delete.

---

## 3. Building from source

```bash
# Windows (Visual Studio 2019/2022)
#   open UltimateRealism.sln, select Release | x64, Build.

# Any OS with the .NET SDK
dotnet build -c Release

# With the config/code consistency gate (recommended before shipping)
python3 tools/validate_config.py && dotnet build -c Release
```

Windows deployment helper:

```powershell
.\build.ps1 -GamePath "D:\Games\GTAV" -ShvdnPath "D:\Games\GTAV\ScriptHookVDotNet3.dll" -RunConfigValidator
```

The project references `refs\ScriptHookVDotNet3.dll` by default; override with
`-p:ShvdnPath=...`. Building against the DLL from *your* game install is recommended, because
that assembly is what actually loads into the process.

Output: `src/UltimateRealism/bin/Release/UltimateRealism.dll` (~250 KB, no other dependencies).

---

## 4. Default hotkeys

| Key | Action |
|---|---|
| `F5` | Bandage the worst bleeding wound |
| `F6` | Tourniquet a bleeding limb |
| `Ctrl+F5` | Take painkillers |
| `Ctrl+F6` | Use a medical kit |
| `F7` / `F8` | Eat a ration / drink water |
| `F9` | Trauma status |
| `F10` | Survival status |
| `F11` | Refuel (pays from your cash) |
| `Ctrl+F11` | Vehicle status |
| `F4` | Toggle diagnostic overlay |
| `Ctrl+F12` | Write `UltimateRealism_SystemReport.txt` |

All of them are rebindable (`Hotkey.*` inside each module's section). Any collision — with each
other or with a trainer you have installed — is reported in the log at startup; the framework
never changes another mod's bindings.

---

## 5. Configuration

`UltimateRealism.ini` is documented inline, grouped by module, and **hot-reloadable**: save the
file while the game is running and it is applied within half a second — including switching whole
modules on and off. Disabling a module reverts everything it changed.

```ini
[Modules]
VehicleMechanics.Enabled = false   ; I use a dedicated fuel mod

[VehicleMechanics]
Fuel.Enabled = false               ; ...or just the fuel subsystem

[Survival]
Metabolism.Scale = 0.7             ; slower, gentler survival pace
```

Every value is validated and clamped, and a bad line degrades to the default with a warning in
the log instead of breaking startup. `tools/validate_config.py` keeps the shipped `.ini` and the
code in lock-step (185 keys across 12 sections, both directions, plus range, module and
hotkey-collision checks).

---

## 6. Troubleshooting

| Symptom | What to do |
|---|---|
| Nothing happens in game | Check `scripts\UltraRealism.log` exists. If not, ScriptHookVDotNet is not loading the DLL (check it's x64 and that SHVDN is installed). |
| "failed to start" notification | Read `scripts\UltraRealism_Error.log`. It contains the exact module and stack trace. |
| A feature silently does nothing | `Ctrl+F12`, then read `UltraRealism_SystemReport.txt`: module status, quarantined natives, vetoed subsystems and active overrides are all listed. |
| Stutters | Lower `[Framework] WorkBudgetMsPerSecond` (e.g. 14) — the governor will thin the simulation automatically. Then, if needed, raise `[AmbientAI] Performance.PassIntervalMs`, lower `Performance.MaxPedsPerPass`, lower `[AdvancedKinematics] Performance.MaxManagedPeds`, or set `Physics.AffectTrafficVehicles = false`. The overlay (`F4`) shows each module's per-tick cost. |
| Stutter only on a 120/180/240 Hz display | Check the governor block in `UltraRealism_SystemReport.txt`: it prints the estimated refresh rate, measured ms/s against budget and the current scheduler scale. If `scale` is climbing, lower `WorkBudgetMsPerSecond`. |
| Night looks washed out / lights bloom | Raise exposure contrast: lower `[Lighting] Exposure.Night` (0.88–0.92), or disable `Exposure.Enabled` to compare against vanilla. |
| A visual pack looks different than before | `[Lighting] AutoYield.VisualPacks` should be `true` (default). If you enabled `Timecycle.Enabled` yourself, turn it off — the pack owns that look. |
| Conflicts | See [`docs/COMPATIBILITY.md`](docs/COMPATIBILITY.md) — it has a per-mod matrix and a debugging procedure. |

---

## 7. Verification status (read this before you ship it widely)

Compiled against the **real** `ScriptHookVDotNet3.dll` 3.6.0 reference assembly, with every
native name, property and enum member in this codebase checked against that assembly's public
API. The build is clean (0 errors, 0 warnings).

What that means, precisely:

* **Verified:** every API call in this codebase exists on SHVDN 3.6.0 with the signature used;
  every native hash referenced is present in that build's `Hash` enum; the config, code and
  module registry agree with each other.
* **Not yet verified here:** in-game runtime behaviour — this project was authored and compiled
  in a sandbox without GTA V. Expect to tune, in particular:
  * the absolute magnitudes of the physics multipliers (grip/brake/power scales) against your
    own handling feel,
  * the thermal model's time constants (`Heat.Scale`, `Metabolism.Scale`),
  * the dispatch spawn geometry on your map/mods,
  * the injured movement clipset names, which are config-driven and fall back gracefully.

The debug overlay plus the system report are the tools for that tuning pass; both were built
first for exactly this reason.

---

### 7.1 Pillar coverage

The four pillars the project was commissioned against, and where each one lives:

| Pillar | Implementation | Verified statically | Needs your tuning pass |
|---|---|---|---|
| **1. Advanced kinematics & procedural scaling** | `AdvancedKinematicsModule`: 4-point terrain sampling → move-rate curve, leg IK, Euphoria balance from body mass + slope, deterministic physique profiles (stature/mass/gait), optional capsule variation | all natives exist in SHVDN 3.6.0 (`SET_PED_LEG_IK_MODE`, `SET_PED_CAPSULE`, Euphoria `BodyBalance` properties) | slope penalty magnitudes, Euphoria stiffness ranges |
| **2. Environmental lighting & reflections** | `EnvironmentLightingModule`: exposure target from sun angle + weather, shadow-cascade scale, per-entity water reflection flags with stale release, rain-driven wet sheen, opt-in timecycle grading | `SET_EXPOSURETWEAK`, `FORCE_EXPOSURE_READBACK`, `CASCADE_SHADOWS_SET_CASCADE_BOUNDS_SCALE`, `SET_ENTITY_WATER_REFLECTION_FLAG`, `SET_PED_ENVEFF_SCALE`, `SET/CLEAR_TIMECYCLE_MODIFIER` all present | exposure numbers against your taste and monitor |
| **3. Zero-crash & high-refresh architecture** | `PerformanceGovernor` (ms per second, median spike detection, GC telemetry), bounded caches, no allocation in frame paths, real-dt integration, 8 safety layers | build is 0 errors / 0 warnings; governor unit-reasoned in `ARCHITECTURE.md` §7.1 | confirm on your hardware at your refresh rate |
| **4. Open source & community first** | MIT `LICENSE`, no telemetry/network/updater/paywall, one `.ini` as the only product surface | `grep -rn "HttpClient\|WebClient\|Socket" src/` returns nothing | — |

An honest statement about pillar 2's "no CPU/GPU cost" requirement: the module adds no render pass, no
texture and no shader. It writes a handful of engine-owned values once per second (cost: microseconds),
and its reflection flags *reduce* the number of entities in the water-reflection set. The one place it
can cost GPU time — `Shadows.DayScale`/`NightScale` above 1.0 — defaults to the vanilla value of 1.0.

## 8. Documentation

| File | Contents |
|---|---|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | layer map, frame loop, module contract, lifecycle, extension guide, performance budget |
| [`docs/COMPATIBILITY.md`](docs/COMPATIBILITY.md) | conflict matrix per popular mod, memory policy, patch-resilience strategy, debugging a conflict |
| [`docs/PHYSICS_MODELS.md`](docs/PHYSICS_MODELS.md) | every equation, unit, constant and tuning knob — thermal energy balance, kinematics, lighting calibration tables |
| [`docs/SHVDN3_3.6.0_API_Reference.txt`](docs/SHVDN3_3.6.0_API_Reference.txt) | generated reference of the API surface this project compiles against |

## 9. Licence

MIT — see [`LICENSE`](LICENSE). Use it, fork it, ship it in a pack, modify it commercially; the only
requirement is that the copyright notice travels with it. No paywall, no subscription, no
"supporter edition", nothing withheld.

---

## 10. What this project deliberately does not do

Listed here because promise-keeping is easier to judge against explicit limits:

* no mesh/model rescaling of pedestrians (no such native exists; it would require shipping files),
* no water-shader rewrite for currents and ripples (engine-owned; native API exposes only flags),
* no bloom/HDR setters beyond the exposure tweak (they do not exist in the native surface),
* no editing of `handling.meta`, `visualsettings.dat`, `timecycle` files or any other shared file,
* no hooks, detours or hardcoded memory addresses,
* no background threads, no telemetry, no network access of any kind.
