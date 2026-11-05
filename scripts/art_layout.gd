class_name BidArtLayout
extends RefCounted

# One scale contract for the 320x180 logical viewport and the 2D auction hall.
const VIEWPORT := Vector2(320, 180)
const WORLD_WIDTH := 3200.0
const FLOOR_Y := 520.0
const APPRAISER_POSITION := Vector2(320,520)
const APPRAISAL_MAX_X := 700.0
const WORLD_X_MARGIN := 90.0
const CAMERA_START := Vector2(1210, 350)
const CAMERA_ZOOM := 0.35
const LOT_STAGE_POSITION := Vector2(1450, 260)
const SEAT_POSITIONS := [Vector2(1195, 526), Vector2(1365, 526), Vector2(1535, 526), Vector2(1705, 526)]

# Actor and scenery source texels share the same projected pixel size.
const ACTOR_FRAME_PIXELS := Vector2(96, 128)
const PIXEL_FRAME_SIZE := Vector2i(96, 128)
const BODY_BASELINE_PIXEL_Y := 113
const BODY_CENTER_PIXEL_X := 48
const CAP_ANCHOR_PIXEL := Vector2i(24,25)
const CAP_OFFSET_PIXEL := Vector2i(-7,-7)
const HEAD_ANCHOR_PIXEL := Vector2i(48, 38)
const EYE_ANCHOR_PIXEL := Vector2i(48, 47)
const MOUTH_ANCHOR_PIXEL := Vector2i(48, 70)
const CARRY_ANCHOR_PIXEL := Vector2i(86, 50)
# Measured button centers in the normalized source frames, ordered 00..07.
const NEAR_EYE_PIXELS := [Vector2i(55,37), Vector2i(55,39), Vector2i(55,37), Vector2i(56,43), Vector2i(55,38), Vector2i(54,33), Vector2i(55,38), Vector2i(56,35)]
const FAR_EYE_PIXELS := [Vector2i(72,35), Vector2i(73,37), Vector2i(72,35), Vector2i(73,41), Vector2i(73,37), Vector2i(72,30), Vector2i(73,37), Vector2i(73,33)]
const SOURCE_PIXEL_SCREEN_SIZE := 0.5
const ACTOR_DRAW_SCALE := SOURCE_PIXEL_SCREEN_SIZE / CAMERA_ZOOM
const ROOM_AMBIENT := Color(0.94, 0.88, 0.78, 1.0)
const ACTOR_WORLD_SIZE := ACTOR_FRAME_PIXELS * ACTOR_DRAW_SCALE
const ACTOR_SCREEN_SIZE := ACTOR_WORLD_SIZE * CAMERA_ZOOM

# Sockets are measured from the actor root, not from a per-frame alpha box.
const SPRITE_OFFSET := Vector2(0, -68)
const HEAD_SOCKET := Vector2(0, -68)
const MOUTH_SOCKET := Vector2(0, -52)
const CARRY_SOCKET := Vector2(76, -76)
const CARRY_TETHER_SOURCE := Vector2(32, -72)
const CARRY_TETHER_TARGET := Vector2(-8, 3)
const LOT_CARRY_OFFSET := Vector2(-56, -70)

const BACKGROUND_SOURCE_DIVISOR := 2
const BACKGROUND_WORLD_SCALE := ACTOR_DRAW_SCALE

static func carry_position(facing: int, bob := 0.0) -> Vector2:
	return Vector2(CARRY_SOCKET.x * facing, CARRY_SOCKET.y + bob)

static func carry_source(facing: int) -> Vector2:
	return Vector2(CARRY_TETHER_SOURCE.x * facing, CARRY_TETHER_SOURCE.y)

static func carry_target(facing: int) -> Vector2:
	return Vector2(CARRY_TETHER_TARGET.x * facing, CARRY_TETHER_TARGET.y)
