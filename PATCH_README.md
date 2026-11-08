# LAST POD OUT — Visual Overhaul Patch

This ZIP is an **overlay patch**, not a second complete project. It uses the same
folder layout as your existing LAST POD OUT project. Extract the ZIP directly into
your existing project root (the folder containing project.godot) and allow overwrite.

## Patch contents
- `scripts/arena.gd`: five connected enclosed rooms, bright room fixtures, PBR floors/walls, reactor generators, cargo crates, gravity catwalk shaft, Med-Bay oxygen stations, black-hole window, emergency beacons, void kill plane, optional modular-model loader integration.
- `scripts/asset_loader.gd`: recursive optional GLB/GLTF/FBX discovery and safe model fitting.
- `scripts/industrial_rig_visual.gd`: smooth procedural worker fallback, role-color visor/ring, oxygen tanks/gauge, shoulder light, optional Mixamo model and animation-name mapping.
- `scripts/isometric_camera.gd`: orthographic isometric camera tracking active players.
- `scripts/minimap.gd`: five-room corner radar with player and fuel markers.
- `scripts/hud.gd`: shorter lobby, clearer objective/HUD, mini-map and typewriter corporate ticker.
- `scripts/player.gd`: connects worker rig, animation, nameplate, role ring and immediate fall death while retaining existing combat/input interfaces.
- `scripts/industrial_materials.gd`: procedural PBR and accretion-disk materials.
- `scenes/main.tscn`: explicit orthographic camera settings.
- `project.godot`: Forward+ renderer and default clear color.
- `assets/characters/README.txt`, `assets/environment/README.txt`: optional asset instructions.

## Install
1. Back up your project folder.
2. Extract this ZIP into the project root (do not create a nested project folder).
3. Open the existing `project.godot` in Godot 4.3+; this patch was authored for the Godot 4.7 project you provided.
4. Let Godot import new files, then run with F5.
5. First test with no external assets. The project should use procedural fallback geometry.

## Optional external assets
The scripts do not bundle third-party models. To add them, follow the asset README files. The fallback level and character remain usable if the folders stay empty.

### Recommended environment pack: Quaternius Modular Sci-Fi MegaKit
Use the [Quaternius Modular Sci-Fi MegaKit](https://quaternius.com/packs/modularscifimegakit.html) rather than the Ultimate Space Kit for the main station. It is specifically a modular interior set with walls, floors, doors, props and other room pieces; Quaternius lists glTF, FBX, OBJ and Blender formats and a CC0 licence. The free Standard download is also listed in the [Godot Asset Library](https://store.godotengine.org/asset/quaternius/modular-sci-fi-megakit/). Pick one suitable module per category and place/rename it in `assets/environment/` as `wall.glb`, `floor.glb`, `door.glb`, `console.glb`, `crate.glb`, and `pod.glb`. The loader finds filename keywords recursively; imported meshes are visual-only and game-generated collision boxes remain in place.

### Recommended character source: Mixamo
Use [Adobe Mixamo](https://www.mixamo.com/) to choose a humanoid space-suit/armored worker character. Mixamo download workflow is FBX-based; Godot 4.3+ imports FBX through the ufbx importer by default. Save the base character as `assets/characters/player.fbx` (or convert it to `player.glb`). To get all runtime states, download the same character with Idle, Run/Walk and Push animations, combine the clips into one AnimationPlayer using Blender (each animation should target the same Mixamo skeleton), then export one `player.glb`. The auto-loader only uses external characters when both Idle and Run/Walk clips are present; otherwise it deliberately uses the procedural rig instead of showing a frozen T-pose. The Push clip is optional but enables the shove animation.

## Validation
The patch was inspected for file paths and obvious static issues. Godot is not installed in the build environment, so it has **not** been run through the Godot parser or runtime here. Test the import and scene in your installed Godot version before treating it as production-ready.
