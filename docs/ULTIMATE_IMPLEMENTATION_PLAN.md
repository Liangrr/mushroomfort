# Merged Guardian Ultimates — Implementation Plan

> Historical design notes from the imported game. Use the current README and executable source for behavior; validation claims below describe the original development session.

## Scope and ownership

Each of the six existing merged guardians gains one automatic ultimate. The authoritative combat extension owns charging, target selection, delayed pulses, damage and status changes. The existing screen projects cooldown state; the world presents semantic events with bounded effects. Existing merged damage channels, donor range, prices, enemy stats, animation atlases, foundation anchors, score bookkeeping, controls and music remain unchanged.

## Ability design

Damage below uses **D**, the sum of the two inherited basic channel damage values. Damage uses the existing mitigation and once-only kill/reward path. Cells use the existing Chebyshev distance and foremost-progress/lowest-ID tie breaking. Acquisition and every affected target stay inside the guardian's inherited range.

| Guardian | Ultimate | Recharge at 1× | Authoritative effect |
|---|---|---|---|
| Rimeflame — Fire/Frost | Solstice Nova | 12 s | A radius-2 burst around the foremost enemy hits up to 8 ground/air enemies for 2D Arts damage, freezes them for 1 s, and burns ground targets for 3 s. |
| Thunderpyre — Fire/Storm | Thunderfire Cascade | 14 s | A connected chain hits up to 6 distinct enemies for 3D Arts damage. Starts with air priority; each later hop must be within 3 cells of the preceding target and within tower range. Ground targets burn for 4 s. |
| Cinderroot — Fire/Earth | Magmafault | 16 s | A radius-2 quake around a ground enemy hits up to 8 ground targets for 3D armor-piercing physical damage, roots them for 1.5 s and burns them for 4 s. Never hits air. |
| Tempestquill — Frost/Storm | Winterwing Barrage | 12 s | Three seeking volleys, 0.5 s apart, each hit up to 4 in-range enemies for D Arts damage, with air priority and a 2 s slow. Reacquires living targets for every volley. |
| Winterbark — Frost/Earth | Glacial Grove | 18 s | A stationary radius-2 grove lasts 5 s around the initial enemy. Five pulses at 1 s intervals hit up to 8 in-range ground/air enemies for half D (rounded up) Arts damage and renew a 2 s slow. |
| Thornvolt — Storm/Earth | Living Circuit | 15 s | Roots up to 4 ground enemies for 2 s with 2D armor-piercing physical damage, while arcing into up to 2 airborne enemies for 3D Arts damage and a 2 s slow. Can fire against either eligible group. |

## Deterministic lifecycle

A successful merged placement initializes a full recharge. Charge advances only on simulation ticks while a wave is active and at least one enemy is alive. It freezes during preparation, pause and empty spawn gaps. A charged ultimate holds at Ready until a legal target is in range, rather than wasting its charge. Ready casts precede basic channels in the same combat phase; basics continue with their original independent counters. Recharge begins immediately after a cast and cannot accumulate multiple stored casts. Game speeds alter tick delivery, so these are simulation seconds.

The model rejects repeat processing of the same ultimate tick. It hashes cooldowns and all pending pulse state. Existing burn, slow and stun extensions use maximum expiry so a basic attack cannot shorten an ultimate's status. Status strengths do not stack; longer expiry wins. Delayed effects stop on sell/removal, wave clear or terminal outcome. Cooldowns carry across waves and reset with a new battle. No position displacement, new reward path or model randomness is introduced.

## Presentation and localization

Reuse the six approved casting atlases, existing elemental sound cues and the central eight-voice SFX owner. Each ultimate emits a typed event containing its recipe, caster, impacted enemy IDs, center, pulse index and model tick. New code-drawn effects distinguish a two-tone nova, branching lightning, magma fissures, falling frost feathers, a glacial grove and lightning-root cages. Effects do not change gameplay and use a fixed cap, visibility checks, pause freezing and a static reduced-motion alternative. Source/impact sound visibility is checked separately; no missed sounds are replayed. Preserve SFX default 0.4875 and BGM bytes.

The selected merged inspector shows the ultimate name, concise description, live charging/ready/active text and progress bar. A small two-tone charge meter below the guardian provides glanceable feedback without text over the battlefield. Retain inherited-channel details as localized tooltips if needed to keep the inspector readable. English and Simplified Chinese keys and placeholders remain identical; regenerate the licensed font subset from the existing full source.

## Verification plan

Focused model tests cover all six legal recipes, exact first and repeat thresholds, hold-without-target behavior, preparation/empty-gap freeze, air/ground filters, chain connectivity, pulse cadence and reacquisition, exact mitigated damage, strongest-duration status preservation, deaths/rewards, sell/terminal cleanup, unchanged basic channels/range and equal replay hashes. Retain the 234-check merge regression and relevant control/particle lifecycle checks.

Native real-renderer evidence will exercise each actual ultimate event at game scale, its cast animation and grounded effects, English landscape, Chinese portrait, large text, pause, reduced motion, effect caps/culling and teardown. Finish with one managed export restart, independent current-PCK boot/resource/ability checks and one saved checkpoint. Browser interaction and sustained-play acceptance remain with the user; no routine browser automation is added.

## Implementation status

Implemented in the active Fablewood project, extending checkpoint `3ee24357`. The ability table above matches the shipped model. The new `sim/fablewood_ultimates.gd` owns ability state; `scripts/fablewood/ultimate_effects.gd` owns bounded presentation. No new media was generated: existing approved animations and elemental cues are reused. The font subset includes all new Chinese copy.

The final run passes **713 ultimate-model assertions**, the **234-check merge regression**, particle/celebration lifecycle checks, and native readiness, upgrade and automatic-wave control checks. Actual OpenGL captures cover all six ready/casting states, English landscape, Chinese portrait, 150% text and scrolling, pause, reduced motion, culling, caps and teardown. Real PulseAudio checks cover all six paired cues, eight-voice bounds, off-screen silence and unchanged mute/default settings. Native inspection exposed and corrected the localization namespace, large-text horizontal overflow and an aerial root-cage mismatch.

The managed export completed successfully. An independently booted current 68 MB PCK performed legal upgrades/merges and reached the exact natural first-cast threshold for every recipe with original basic attacks still running. It also passed effect/state separation, removal, both localization catalogs, bundled Chinese glyph coverage, the unchanged SFX default and return-to-title routing. Native screenshots and authoring/test intermediates remain outside shipped assets. Sustained browser play and comparative late-chapter balance are user acceptance items, not claims established by these deterministic fixtures.

## References

[1]: ../sim/fablewood_battle.gd "Fablewood combat and merge authority"
[2]: ../scripts/fablewood/world.gd "Fablewood world presentation"
[3]: ../scripts/fablewood/screen.gd "Fablewood session and inspector"
