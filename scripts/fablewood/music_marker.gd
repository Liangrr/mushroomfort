class_name FablewoodMusicMarker
extends RefCounted
## Audio-time only: no timers, game ticks, persistent state or deferred event queue.
const MAX_LATE_SECONDS:=0.4
var serial:=-1
var cycle:=-1
var previous:=-1.0
var consumed:=false
func reset()->void:
	serial=-1;cycle=-1;previous=-1.0;consumed=false
func sample(play_serial:int,loop_index:int,position:float,marker:float)->bool:
	if position<0 or marker<0:return false
	if serial!=play_serial:
		serial=play_serial;cycle=loop_index;previous=position
		consumed=position>=marker
		return false
	if cycle!=loop_index:
		cycle=loop_index;previous=-1.0;consumed=false
	var crossed:=previous<marker and position>=marker
	previous=position
	if consumed or not crossed:return false
	consumed=true
	# Hidden-tab stalls and seeks past the entrance must not cause a late burst.
	return position-marker<=MAX_LATE_SECONDS
