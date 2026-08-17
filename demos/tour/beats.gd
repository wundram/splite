class_name TourBeats
extends RefCounted
## Living feature reel. When a visible engine feature ships, add a beat.
##
## Required keys: id, title, body, x, z, level
## Optional: hold, pan, dir, clock (hours), interact (bool).

static func all() -> Array[Dictionary]:
	var beats: Array[Dictionary] = [
		{
			"id": "intro",
			"title": "Splite  ·  splat-tile engine",
			"body": "Locked top-down camera. Tiles and sprites are volumetric Gaussian clouds. This reel walks every feature that ships today, then quits.",
			"x": 8.0, "z": 11.0, "level": 0, "hold": 4.4, "pan": 3.2,
		},
		{
			"id": "parallax",
			"title": "Perspective parallax",
			"body": "Close camera, wide lens — not ortho. Canopy, walls, and the walkway slide against the ground as you walk. That shear is the 3D.",
			"x": 8.0, "z": 10.4, "level": 0, "hold": 4.6, "pan": 3.6,
		},
		{
			"id": "splat-tiles",
			"title": "Splat tiles",
			"body": "Grass is a cloud of Gaussians, not a flat sprite. Soft volume with a gameplay bounding box. Three grass variants so the lawn is not a glyph stamp.",
			"x": 8.0, "z": 11.0, "level": 0, "pan": 3.2,
		},
		{
			"id": "brush",
			"title": "Volume, not a layer",
			"body": "Heavy brush is a taller cloud. A splite standing in it occupies the same matter — the old 2D “sink” bands fall out of the volume.",
			"x": 6.0, "z": 10.2, "level": 0, "pan": 2.6,
		},
		{
			"id": "mesh-surfaces",
			"title": "Mesh surfaces",
			"body": "Walls, water, and floors are ordinary polygons. They write the depth buffer so splats and the player can occlude against them.",
			"x": 8.0, "z": 7.2, "level": 0, "pan": 2.8,
		},
		{
			"id": "hybrid",
			"title": "Hybrid tile",
			"body": "Stone is a mesh slab plus splat dressing. The hull casts the shadow; the cloud is the surface grit. Same authoring unit, two draw paths.",
			"x": 10.0, "z": 8.0, "level": 0, "pan": 2.2,
		},
		{
			"id": "drop-shadows",
			"title": "Drop shadows",
			"body": "4pm sun, not noon. Each tile and splite has a cheap cast model — hull or blob — projected along that off-axis light.",
			"x": 8.0, "z": 7.4, "level": 0, "pan": 3.0,
		},
		{
			"id": "splite",
			"title": "Splite",
			"body": "A sprite whose frames are splat clouds. Walk cycle = four clouds at 10 fps. Motion is still smooth at display refresh.",
			"x": 8.0, "z": 9.0, "level": 0, "pan": 3.0,
		},
		{
			"id": "cutaway",
			"title": "Cut-away",
			"body": "The walkway is between the camera and the player, so the engine discards a dollhouse hole. Center fade, then fragment discard — the lid does not pop or refill.",
			"x": 10.0, "z": 5.5, "level": 0, "pan": 1.8,
		},
		{
			"id": "verticality",
			"title": "Verticality",
			"body": "Same world, higher level. The garden shrinks by perspective; the tile asset does not change. Stairs interpolate elevation.",
			"x": 10.5, "z": 5.5, "level": 1, "pan": 1.6,
		},
		{
			"id": "room-outside",
			"title": "Room visibility  ·  outside",
			"body": "The cellar is sealed. It is not rendered. Its torch does not exist. Light is knowledge.",
			"x": 4.6, "z": 6.6, "level": 0, "pan": 2.4,
		},
		{
			"id": "world-hint",
			"title": "World hint",
			"body": "“Open the door” sits on the door, not in the corner. One Label3D retargets to the nearest in-range interactable.",
			"x": 5.0, "z": 6.3, "level": 0, "pan": 1.2,
		},
		{
			"id": "door-states",
			"title": "Door states",
			"body": "Closed → opening (four yaw frames at 10 fps) → open. The slab actually moves. Walkable flips when the sequence finishes.",
			"x": 5.0, "z": 6.2, "level": 0, "pan": 0.8, "interact": true,
		},
		{
			"id": "room-inside",
			"title": "Room visibility  ·  inside",
			"body": "Step through the door and only this room is submitted. The torch is real now. The garden is gone.",
			"x": 5.0, "z": 3.6, "level": 0, "pan": 1.4,
		},
		{
			"id": "pond",
			"title": "Pond and bridge",
			"body": "Water is a mesh plane you cannot wade. The bridge is a walkable hull at the same level and casts onto the pond.",
			"x": 12.0, "z": 9.5, "level": 0, "pan": 2.0,
		},
		{
			"id": "distortion",
			"title": "Distortion field",
			"body": "Nearby Gaussians are warped in world space — heat over the pond. A 2D pixel sprite cannot occupy a twisted volume. A splat can.",
			"x": 12.0, "z": 10.0, "level": 0, "pan": 1.8,
		},
		{
			"id": "day-night",
			"title": "Day / night + lantern",
			"body": "Keyframe clock. 16:00 is the 4pm sun exactly. Night is moon plus a swaying lantern and radial drops. The void stays black.",
			"x": 8.0, "z": 11.0, "level": 0, "pan": 2.4, "clock": 23.0,
		},
	]
	if ResourceLoader.exists("res://assets/clouds/tree_hero.tres"):
		beats.append({
			"id": "tree",
			"title": "Environmental volume",
			"body": "The canopy is a SplatVolume, not a 3×3 of cell clouds. IF_OCCLUDES still opens a hole. Fitted tree_hero when the .tres exists.",
			"x": 12.0, "z": 2.2, "level": 0, "pan": 2.2,
		})
	beats.append({
		"id": "end",
		"title": "That’s everything shipping today",
		"body": "Add a beat in demos/tour/beats.gd when the next visible feature lands. Exiting.",
		"x": 8.0, "z": 11.0, "level": 0, "hold": 2.4, "pan": 2.4, "clock": 16.0,
	})
	return beats
