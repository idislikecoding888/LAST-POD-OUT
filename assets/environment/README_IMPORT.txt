LAST POD OUT — CURATED QUATERNIUS ENVIRONMENT ASSETS

Copy the assets/environment folder contents into your project's:
  res://assets/environment/

Included aliases expected by LAST POD OUT's optional asset loader:
  wall.gltf + wall.bin       <- Walls/WallAstra_Straight
  floor.gltf + floor.bin     <- Platforms/Platform_Metal (4m x 4m floor tile)
  door.gltf + door.bin       <- Platforms/Door_DarkMetal
  console.gltf + console.bin <- Props/Prop_Computer
  crate.gltf + crate.bin     <- Props/Prop_Crate3

The required shared texture files are in Textures/. Do not separate the .gltf
from its matching .bin or the Textures directory. Their URIs have been rewritten
for this curated folder layout.

IMPORTANT: The free Standard MegaKit does not contain an actual escape pod
capsule model. Keep the game's procedural EscapePod visuals. This pack's
Platform_Round1 is a round deck/platform, not an escape-pod model, so it is
intentionally NOT renamed to pod.gltf (doing so would replace the procedural pod
with the wrong object).

Door orientation note: Door_DarkMetal is authored with its wide axis along local
X and a thin local Z depth. The V2 arena door-fit call should fit it to
Vector3(5.0, 3.3, 0.5) and rotate it 90 degrees around Y if the blast-door opening
runs along world Z. Keep the collision door already in the arena script.

Licence: CC0 1.0 Universal, as stated in Quaternius_License_Standard.txt.
