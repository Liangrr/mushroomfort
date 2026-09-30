# Fablewood: dual-element guardian merging

> Historical design notes from the imported game. Use the current README and executable source for behavior; validation claims below describe the original development session.

**Implementation plan — Manus AI**

## 1. Intended result

Players will use a **Merge towers** control in the existing placement toolbar to select two living **level 3 basic guardians of different elements**. The selected guardians will leave the board and become one pending dual-element guardian. The player will then choose an empty root socket for the merged guardian. A visible Cancel action will restore both original guardians if placement is abandoned. This is an extension of the existing deterministic battle model and scene coordinator, not a second combat system.[1] [2]

The four elements produce **six unordered combinations**. Selecting Fire then Frost will produce the same guardian as selecting Frost then Fire. Same-element merges and merging an already merged guardian are excluded because the requested result is dual-element and its inputs are basic elemental towers. Merging has no additional gold cost. Merged guardians are a terminal specialization, not an additional upgrade ladder.

## 2. Combination and concept design reference

| Components | Guardian | Visual identity | Retained combat roles |
|---|---|---|---|
| Fire + Frost | **Rimeflame** | A crystalline fox-heron shrine with an ember heart, frost feathers and flame tails. | Fire splash and burn, plus Frost damage and slowing. |
| Fire + Storm | **Thunderpyre** | A crowned fox shrine with branching lightning antlers and a violet-red core. | Fire splash and burn, plus Storm chaining and aerial priority. |
| Fire + Earth | **Cinderroot** | A mossy acorn-forge guardian with a lava-lit stone chest and ember foliage. | Fire splash and burn, plus Earth armor-piercing impact and stun. |
| Frost + Storm | **Tempestquill** | A heron spire with ice-feather wings, an antler crown and an electrical halo. | Frost slowing, plus Storm chaining and aerial priority. |
| Frost + Earth | **Winterbark** | A rooted stone guardian with an icy leaf crown and frost-veined moss armor. | Frost slowing, plus Earth armor-piercing impact and stun. |
| Storm + Earth | **Thornvolt** | A broad oak-and-stone sentinel with lightning branches and an amethyst heart. | Storm chaining and aerial priority, plus Earth armor-piercing impact and stun. |

The requested reference sheet will show all six designs together with their element labels. It is concept art, not a gameplay screenshot. Separate transparent runtime artwork will be authored for the six guardians; the sheet will not be sliced into runtime sprites. These stationary structures will use bounded elemental auras and firing feedback while their foundations remain fixed. Existing basic guardian animations remain unchanged.

## 3. Player interaction and transaction states

| State | Interface | Authoritative change | Exit paths |
|---|---|---|---|
| Normal play | Merge towers is visible in the placement toolbar. It is disabled unless a legal pair exists. | None. | Activate Merge towers. |
| Select first | Eligible level 3 basic guardians receive clear selection rings. The inspector explains the requirement. | None. | Select a valid guardian, Cancel, or Escape. |
| Select second | The first guardian is marked. Only different-element level 3 basic guardians qualify. | None. | Select a compatible guardian, change the first selection, Cancel, or Escape. |
| Place merged guardian | Both donors disappear. The merged design, two elements and placement instruction are shown. Empty sockets receive placement feedback. | A pending merge stores donor IDs and reserves their recovery positions. | Place on an empty socket or cancel and restore both donors. |
| Placed | The new guardian occupies exactly one socket. The inspector reports both damage channels and the maximum inherited range. | Append one merged unit, preserve donor history and consume the pending transaction once. | Normal selection, combat and selling. |

Combat continues during selection and placement unless the player pauses. The preparation countdown is held while the merge workflow is active so it cannot launch a new wave during placement. Explicit Next wave/Enter is unavailable until the workflow is completed or canceled. Opening a normal pause/settings dialog retains the pending transaction. Returning to the menu or ending the run cancels safely before teardown. The existing U shortcut must never upgrade a merged guardian or interfere with merge selection.

## 4. Combat composition

A merged guardian will retain **two independent attack channels**, each copied from its level 3 donor. Each channel keeps its effective rounded damage, attack interval, target eligibility and elemental effects. This preserves the combined output without inadvertently granting both attacks the faster donor's fire rate. Where both channels can engage, their damage output adds together. Fire and Earth remain ground-only channels; Frost and Storm retain their existing aerial capability. A mixed tower can therefore engage aerial units through its eligible component rather than incorrectly applying ground-only effects to dragons.

The guardian's range will equal the **larger of the two source guardians' ranges**. Both channels use that shared range. Fire retains its existing splash radius and burn duration. Frost retains its level 3 slow duration. Storm retains four-target chaining, aerial priority and its aerial damage multiplier. Earth retains armor compensation and its level 3 stun duration. This work introduces no extra synergy multiplier, elemental resistance system, enemy HP adjustment or base-tower rebalance.[1]

Existing attack/damage events will continue to drive their own elemental projectiles, impact particles and separately culled firing/hit audio. Merging and placement will reuse appropriate approved selection, confirmation, build and upgrade sounds. Their visual effects remain bounded and separate from combat authority.

## 5. Ownership and implementation sequence

| Phase | Owner and files | Planned change | Acceptance condition |
|---|---|---|---|
| 1. Art and data | New merged-guardian presentation definitions and `assets/template/merged_guardians/` | Produce the reference sheet and six transparent sprites with measured footprint anchors. | All combinations are represented, readable and coherent with Fablewood. |
| 2. Model transaction | `sim/fablewood_battle.gd` and a focused merge-data helper if useful | Validate donors; begin, place and cancel merge; protect reserved recovery cells; append one new unit. | Invalid actions are no-ops; no lost towers, duplicate units, extra gold or free cooldown resets. |
| 3. Composed attacks | Existing elemental combat owner | Extract a reusable attack-channel resolver shared by basic and merged towers. | Basic behavior is unchanged and all six merges inherit both donors' behavior. |
| 4. Interface | Existing battle screen and focused merge-controller/presenter | Add toolbar availability, donor highlighting, merged placement preview, Cancel and complete bilingual guidance. | Mouse/touch selection, keyboard cancellation, pause/settings and resize remain safe. |
| 5. Presentation | Existing world renderer and merged-art adapter | Seat new guardian footprints at the measured platform-top centers and show both elements in attacks/auras. | Grounding holds at normal/high zoom and in portrait/landscape. |
| 6. Verification and delivery | Targeted model/native tests and managed GameDev export | Verify transactions, every combination, UI states, regressions and current exported resources; save one completed update checkpoint. | The current browser game contains the feature, with plan and reference sheet delivered alongside it. |

## 6. Integrity and cancellation rules

The units array remains append-only. Consumed donors remain recorded as inactive historical units. A pending merge is authoritative model state and participates in the deterministic state hash. It stores donor identity rather than reconstructing towers from current defaults. Attack cooldowns carry into the merged channels, so repeated cancel/reselect cannot manufacture immediate attacks. Cancellation restores the original donors without refunds, reward events or upgrade counts.

While a pending merge exists, unrelated build, sell and upgrade model actions will be rejected to prevent occupation of recovery sockets or mutation of the transaction inputs. Placement validates an in-bounds, empty, legal platform and consumes the pending record atomically. A rejected placement leaves the pending guardian intact. The new unit's base sale value is the sum of the donors' base sale values under the existing refund rule, avoiding a merge-for-profit exploit.

## 7. Verification plan

| Area | Required cases |
|---|---|
| Eligibility | Fewer than two level 3 towers; two equal elements; a valid different-element pair; dead, sold, lower-tier and already merged inputs. |
| Transaction integrity | Reversed selection order; repeated donor; invalid IDs; donor removal; occupied/out-of-bounds placement; placement on a former donor socket; cancel; double place/cancel; gold and ID stability. |
| Combat | All six pairs; separate damage/cooldown channels; maximum range; aerial eligibility; burn, slow, chain and stun; inherited cooldowns; deterministic equivalent runs. |
| Interface | Disabled/enabled toolbar control, live eligibility after upgrades/sales, first/second selection, wrong input feedback, preview, successful placement, Cancel/Escape, paused workflow and menu return. |
| Presentation | Native captures for all six guardians, normal/high zoom, shared black-oval footprint centers, selection rings, placement ghost, attack effects and reduced motion. |
| Compatibility | Existing basic-tower damage tests, earned-gold upgrade feedback, callout tutorial input, Q/E speeds, Enter, Space pause, countdown and music/particle lifecycle. |
| Localization and export | English/Chinese key parity, bundled glyph coverage, portrait and large-text layouts, independent current-PCK boot, six runtime textures and active scene wiring. |

## 8. Scope boundaries

This change does not introduce online services, new currencies, same-element fusion, triple-element towers, merged-tower upgrade tiers, or a new save format. Existing campaign restart/resume semantics remain in place. The reference sheet is a visual design deliverable. The deployed game will use individual runtime sprites and live localized interface text.

## References

[1]: /home/ubuntu/fablewood/sim/fablewood_battle.gd "Fablewood authoritative elemental combat and progression model"
[2]: /home/ubuntu/fablewood/sim/battle_model.gd "Tower-defense template placement, unit history, resource ledger and simulation ownership"
[3]: /home/ubuntu/fablewood/scripts/fablewood/world.gd "Fablewood platform anchors, rendering and bounded effects"

## 9. Execution report

**The feature is implemented.** The six-design reference sheet and six separately generated transparent runtime sprites are complete. The deterministic model now owns eligibility, donor removal, pending placement, cancellation and two-channel combat. `merge_flow.gd` owns selection and feedback, `merged_art.gd` owns the six artwork/footprint contracts, and the existing screen and world own responsive layout and rendering. The toolbar refreshes eligibility from current model state rather than caching a stale enabled/disabled value.

The merged guardian keeps its donors' effective damage and independent firing intervals; the inspector shows the sum and each component separately. There is no extra merge fee. The player may reuse a donor's vacated socket or choose another empty legal socket. Cancel/Escape restores both original towers, including tiers and cooldowns, and menu navigation safely rolls back an unfinished placement. Preparation time freezes during the workflow while live combat continues unless paused.

| Verification | Result |
|---|---|
| Authoritative merge model | 234 checks passed across all six recipes, order independence, eligibility, invalid-action no-ops, donor/currency integrity, cooldown transfer, inherited abilities and range. |
| Native interaction | Real pointer and touch selection/placement, Cancel/Escape, U and Enter protection, Space pause/resume, resize/language retention and menu recovery passed. |
| Native presentation | All six guardians inspected individually at close zoom and together on the board; footprints centered on the authored platform surfaces. English/Chinese, portrait/landscape, 120% text, pending placement, reduced motion and actual dual-element attacks inspected. |
| Existing gameplay | Exact basic damage/HP, particles, campaign outcome/replay, live upgrade affordability, callout input, Q/E speeds, U/Space/Enter and automatic-wave checks passed. |
| Asset compatibility | Custom media moved coherently to `assets/template/`, retaining 73 existing media files byte-for-byte and their stored URLs/hash records. Reserved template assets were left intact. |
| Final delivery gate | Managed current-source export and independent packed-game verification, followed by the normal checkpoint. Browser interaction and sustained-play acceptance remain the user handoff. |

The six merged guardians use original stationary artwork with bounded two-color ambient and attack effects, not newly generated frame-based character loops. Their foundations do not bob or rotate. The existing basic tower, enemy and endpoint animations remain in place.

The historical non-merge Chapter 3 test strategy still loses at wave 7 under the current difficulty settings. This update preserves those basic stats rather than disguising the pressure with an unrelated rebalance. A useful next acceptance test is to compare each merge against leaving the same two level 3 donors on separate sockets, especially when Storm supplies longer aerial coverage.

## 10. Export verification

The managed browser build completed successfully and both local and public requests served **Fablewood: Keepers of the Last Seed**. Its current 44 MB PCK was independently booted outside the project source directory. The probe verified all six merged textures, the relocated existing animation/audio/font resources, active toolbar eligibility, donor removal, held preparation countdown, free placement, combined damage, maximum inherited range, rejection of merged-tower upgrades and Chinese toolbar copy. The verified build is ready for the normal checkpoint handoff; the checkpoint identifier accompanies the final delivery.
