# Worldheart — the Fourfold Warden

> Historical design notes from the imported game. Use the current README and executable source for behavior; validation claims below describe the original development session.

## Concept and scope

Worldheart (万象树心) is the ultimate convergence guardian of Fablewood: a rooted ancient warden with a stag-like carved face, four elemental branch crests and a luminous star-seed heart. The visual follows the established original storybook artwork and high-resolution animation workflow. Existing guardians, art direction, controls, audio settings, deterministic authority and bilingual support remain intact. The user has explicitly requested conceptualization, proposal and implementation; this is a scoped extension, not a new game or a new concept-approval gate.

## Summoning recipes

Only two living dual-element guardians with disjoint element sets can summon Worldheart. Both donors are consumed, and the player chooses an empty existing tower socket. The current reversible Merge/Cancel/Escape flow is reused. Basic-to-dual merging still requires two distinct level-three basic guardians. Mixing basic and dual guardians, overlapping dual elements, the same unit twice, dead donors, or attempting to merge Worldheart again is illegal.

| Complementary pair | Complete elements |
|---|---|
| Rimeflame + Thornvolt | Fire, Frost, Storm, Earth |
| Thunderpyre + Winterbark | Fire, Frost, Storm, Earth |
| Cinderroot + Tempestquill | Fire, Frost, Storm, Earth |

Worldheart inherits all four basic attack channels, including their exact damage, intervals, attack-counter phase and ground/air restrictions. Its attack range is the arithmetic sum of the two constituent dual guardians’ ranges. At default balance this is seven tiles. Development range adjustments are counted once for each constituent, so the sum remains consistent after a tuning change. It has no further upgrade or merge tier. Gold expenditure, sell refund and donor health/legacy fields follow the existing sum-of-donors transaction. Donor special skills are replaced by Convergence Meteor, not accumulated.

## Convergence Meteor

The ability recharges automatically over 20 seconds (600 fixed combat ticks). It follows existing ultimates: time advances only with active combat and living enemies, pauses with simulation, carries charge between waves, and holds Ready until a legal target enters range. Target selection is deterministic: the furthest-progressed living enemy in range, breaking ties by ID. A launch locks its current tile, shows a visible four-color impact marker, and starts a one-second model-owned flight. The meteor does not home after launch; enemies can move into or out of its impact area.

At impact, every living enemy within three tiles of the locked center is considered, sorted by progress and ID, with a maximum of twelve direct victims. Ground and aerial enemies can be hit. Each direct victim receives four damage components equal to five times each inherited channel’s damage; Fire/Frost/Storm use the existing magical mitigation, and Earth uses the inherited armor-bypassing physical channel. Survivors are frozen for one second, slowed for three seconds and grounded victims burn for four seconds. Violet aftershocks strike up to three additional nearby enemies within two tiles of a direct victim, excluding direct victims, for three times the inherited Storm channel’s damage and two seconds of slow. Selection, damage, statuses, rewards and flight/impact scheduling remain entirely model-owned.

The meteor is cancelled if its owner is sold/consumed, the wave ends or the run becomes terminal. Removing donors during merge placement holds their existing ability states; cancelling restores their charge and any delayed pulse schedule without losing or duplicating work. Successful placement removes donor ability states and starts Worldheart’s recharge from full duration. Any authoritative step performed during a pending transaction must not advance suspended donors’ abilities.

## Presentation and production plan

The parent battle model and focused ultimate module own all behavior. MergeFlow translates clicks into legal model actions; the screen exposes localized requirements, compatible highlights, the full four-channel sum, additive range, ability description and cooldown. Art/animation modules present the new guardian with measured pixel geometry and fixed ground contact. The meteor presentation consumes distinct launch and impact semantic events; its trajectory is sampled from current model flight ticks, never from wall-clock damage timers. Four-color flame/ice/lightning/stone detail, a restrained grounded shockwave and elemental fragments provide readable feedback without obscuring the HUD. Reduced motion keeps a static warning/impact alternative; off-screen presentation is culled and effects remain bounded.

One approved-style static reference establishes identity, followed by one fixed-camera in-place video containing idle and casting motion. Extraction retains full 1280×720 source detail, a single common crop and foundation anchor, lossless alpha and bounded atlas pages. Existing original SFX can support summoning and elemental impacts; a new short meteor cue may be authored if needed through the centralized SFX owner. No BGM replacement, remote service, new input key or external multiplayer is introduced.

## Verification

Focused deterministic tests cover all three recipes in both donor orders; all overlapping/mixed/invalid combinations; exact additive range including tuning; inherited channels and counter preservation; rollback and donor ability state; initial recharge, Ready holding, one-second flight, locked target position, area/aftershock exclusions, ground/air mitigation, status durations, no duplicate rewards, pause, sell/wave/terminal cleanup and replay equivalence. Existing 234-check merge and 713-check ultimate suites remain regression gates.

Native real-renderer checks cover the new guardian’s neutral/idle/casting/recovery foundation, maximum zoom, both launch directions and descent/impact alignment, effects behind readable HUD, EN landscape, CN portrait, four-element previews/meters, pointer merge flow, incompatible selection, cancellation, reduced motion, culling and teardown. One final managed export is independently booted from its current PCK to verify legal summoning, all four channels, additive range, actual timed meteor damage, resources and bilingual glyphs before one checkpoint.

## Execution result

The design has been implemented in the active Fablewood project. All three complementary recipes, exact additive range, four inherited channels and timed meteor behavior pass the 3,591-check focused model suite. The 234-check original merge suite was updated only for the explicitly changed dual-donor eligibility rule; all checks pass. The existing 713-check ultimate suite, merge-celebration lifecycle tests and six-guardian high-resolution native regression also pass.

One original static guardian reference and one eight-second image-conditioned carrier produced 48-frame idle/casting sequences at native source resolution. The final renderer uses 451×660 cells across three lossless atlas pages, a 512×640 static reference, a 124-unit display height and a rigid shared foundation. The meteor body uses matching original artwork; trajectory and impacts remain separate presentation code. A short original impact cue is registered in the existing centralized sound catalog without changing the BGM or saved/default volume behavior.

Final native OpenGL/PulseAudio acceptance covers actual summoning/rejection/cancel input, charge preservation, correct range, fixed poses and recovery, two opposing meteor trajectories, actual impacts, readiness, pause/reduced motion, culling/caps/teardown and English/Chinese layouts. A concrete English inspector overflow was fixed by compacting the visible four-channel summary while retaining full inherited details in its tooltip; Sell now remains visible at the normal landscape size. Sustained browser behavior and damage pacing remain user acceptance, not a claimed automated browser test.

The final managed export has now been independently booted from its current PCK. It passes all three summon recipes at range seven, all 96 native animation frame mappings, exact initial recharge and meteor flight/impact, actual damage, model/presentation isolation, complete game-specific Chinese glyph coverage and title recovery. The exported pack is approximately 134 MiB, reflecting the intentionally high-resolution new animation assets. No routine browser automation was performed; the checkpoint is the browser acceptance handoff.
