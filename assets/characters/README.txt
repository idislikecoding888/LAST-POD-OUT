OPTIONAL PLAYER MODEL

Drop one animated character model here as:
  player.glb   (recommended)
  player.gltf
  player.fbx   (Godot 4.3+ imports FBX using ufbx)

For animation switching, the imported AnimationPlayer should contain clip names
including Idle, Run/Walk, and Push/Shove/Attack. The loader scans these names.
The model should face local -Z, use a humanoid skeleton, and be approximately
1.6-2.0 metres tall. Keep GLTF sidecar textures and .bin files beside the .gltf.

The procedural rounded worker rig remains active if no player model is present.
