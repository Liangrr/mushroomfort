class_name CampaignPendingAttempt
extends RefCounted

## Nonpersisted capability metadata. Issuance, membership, reservation, and
## finalization live in CampaignState-owned closures; this object exposes no
## lifecycle mutation surface and is never authoritative by itself.

const ACTIVE := &"active"
const RESERVED := &"reserved"
const RESOLVED := &"resolved"
const ABORTED := &"aborted"

var _ticket: CampaignBattleTicket
var _committed_hash := ""
var _status_cell: RefCounted


func ticket() -> CampaignBattleTicket:
	return _ticket


func campaign_uid() -> String:
	return _ticket.campaign_uid()


func attempt_id() -> int:
	return _ticket.attempt_id()


func stage_id() -> StringName:
	return _ticket.stage_id()


func manifest_hash() -> String:
	return _ticket.manifest_hash()


func committed_strategic_hash() -> String:
	return _committed_hash


func status() -> StringName:
	if _status_cell == null:
		return ABORTED
	return _status_cell.get_meta(&"status", ABORTED)
