# LAST POD OUT — Gray-Box Prototype v1

**Engine:** Godot 4.4+ recommended (Forward+ renderer, built-in Jolt Physics). The project is written against Godot 4.x APIs and the game scripts are intended to remain compatible with 4.3. **Jolt caveat:** built-in Jolt was added in Godot 4.4. On Godot 4.3, install the compatible Godot Jolt extension and select it as the 3D physics engine; without that extension, Godot 4.3 will fall back to its built-in physics backend.

## Run

1. Unzip this folder (or open it directly if you already have it).
2. Open `project.godot` in Godot.
3. Use the **Forward+** renderer. The project sets `Jolt Physics` as the 3D physics engine.
4. Press **F6** for the current scene or **F5** to run the project. The main scene is `scenes/main.tscn`.

No external models, textures, audio, fonts, plugins, or imported assets are required. All geometry and materials are generated from Godot primitives.

## Local multiplayer controls

| Action | Keyboard / Mouse (Player 1) | Xbox-style controller |
|---|---|---|
| Join in lobby | Space | A |
| Start match | Enter | Start |
| Move | WASD | Left stick |
| Aim | Mouse | Right stick |
| Heavy shove | Right mouse button | Left trigger |
| Counter-parry | Q | Right bumper |
| Dodge / dash | Shift | B |
| Interact / pick up / deposit | E | X |
| Hold for Dead Man's Pact | F | Y |
| Toggle Test Dummy Bot in lobby | Y or Tab | Y |
| Rematch on incident report | Enter / Space | A |

To test with one controller, press **Space** to join Player 1 on keyboard, then press **A** on the controller to join Player 2. You can also toggle the Test Dummy Bot with **Y** or **Tab** in the lobby. The dummy uses `BotInputSource`, not a special player controller.

Gamepads are assigned by Godot device ID (0–3). If operating-system enumeration differs, the displayed player slot follows join order while the input source keeps the actual device ID.

## Prototype loop

- Deliver three Fuel Cells into the center pod before the reactor timer expires.
- At 2/3 cells the emergency state starts, oxygen drains twice as fast, and the two sabotage terminals unlock.
- At 3/3 cells, the 30-second launch countdown starts and shoves become lethal.
- At launch, exactly one living player must be inside the pod. Multiple pod occupants trigger repeated five-second `DOOR JAMMED — OVERTIME` windows until only one remains. A sole occupant wins the payout; otherwise the report records no payout.
- The report lists the eliminated crew and their corporate incident causes. Press A, Enter, or the on-screen button for an immediate rematch.

## Physics layers

The project names the five 3D physics layers in `project.godot`:

1. World / Walls
2. Players
3. Interactive Terminals / Pod
4. Fuel Cells
5. Hazard / Airlock Zones

Player shoves raycast against **World + Players**, so walls occlude a shove. Player flashlights are real `SpotLight3D` nodes with shadows enabled, allowing walls to occlude the beam. Terminal and hazard trigger areas only monitor players. Fuel cells are rigid bodies and become frozen/temporarily collision-disabled while carried.

## Architecture

- `InputSource` is the shared input interface.
- `KeyboardInputSource`, `GamepadInputSource`, and `BotInputSource` implement that interface.
- `PlayerController` owns movement, oxygen, parry, shove response, dodge, pickup/drop, and pact state.
- `GameManager` (the main scene root) owns the phase state machine, countdowns, payouts, terminal effects, and incident report.
- `GameArena`, `EscapePod`, `FuelCell`, and `SabotageTerminal` are composed nodes/scenes.
- `IsometricCamera` follows the midpoint of living players and clamps dynamic distance.

## Exported tuning

Movement, acceleration, shove/reflect/dodge values, parry duration, pact timing/range, oxygen drain, reactor/launch/overtime durations, airlock suction, terminal cooldowns, and gravity inversion duration are exposed as Inspector exports in their owning scripts.

## Scope notes

This is a playable gray-box prototype, not a production network game. It is local shared-screen multiplayer, uses simple collision geometry and intentionally compact rules, and has no online networking, persistence, controller remapping UI, or content pipeline. The life-support / launch pacing and combat values are meant to be tuned in the Inspector.
