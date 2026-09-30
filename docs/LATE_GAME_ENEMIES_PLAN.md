# Late-game enemy expansion

> Historical design notes from the imported game. Use the current README and executable source for behavior; validation claims below describe the original development session.

## Goal and scope

Three enemies increase late-game decision pressure without nerfing the newly earned dual-element guardians or Worldheart. Chapter 1 and the existing four enemy definitions remain unchanged. Introductions occur in Chapter 2 waves 5–7, with a combined wave 8. Chapter 3 begins mixing the new threats from wave 3 and increases their combined presence toward the finale. Existing enemies and boss dragons are retained, not replaced by unexplained health inflation.

| Enemy | Identity | Rules and counterplay |
|---|---|---|
| Prismback Behemoth / 棱晶巨兽 | Armored rhinoceros–tortoise with azure/amethyst shell crystals. | Grounded tank. Its shell absorbs resolved Arts damage, while Earth’s physical damage bypasses it. Any hit delays shell regeneration. Keep attacking or invest in Earth rather than relying only on elemental burst. |
| Galeshard Harrier / 裂风掠翼 | Sleek four-winged hawk–storm-moth with teal crystal feather tips. | Airborne hunter. Telegraphs a 1.75× speed burst; Frost slow or stun cancels that burst for its cycle. Storm’s established aerial priority is retained. It never becomes untargetable or teleports. |
| Grimroot Broodmother / 墨根巢母 | Six-legged root-and-ink beetle with a storybook shell and amber ink pods. | Grounded summoner. Releases pairs of existing ink-goblins behind itself. Kill it early, interrupt a spawning interval with freeze, or keep Fire splash covering the rear. Spawn budgets prevent endless minions or farming. |

## Authoritative values

| Value | Prismback | Harrier | Broodmother |
|---|---:|---:|---:|
| Resource HP before existing ×1.5 rule | 600 | 210 | 420 |
| Effective base HP | 900 | 315 | 630 |
| Speed, tiles/second | 0.38 | 0.95 | 0.46 |
| Defense | 14 | 2 | 6 |
| Leak damage | 4 | 2 | 3 |
| Kill gold before existing gold multiplier | 48 | 24 | 38 |

Prismback’s initial shell is 35% of scaled maximum HP, rounded upward. After four seconds without any positive incoming damage it restores one eighth of its maximum shell per second. Shield absorption occurs after the existing integer mitigation function and before the existing HP/death application function. Shell hits update hit feedback but do not spray blood or grant rewards. The shell is finite, never an invulnerability flag.

Harrier’s first burst begins four seconds after spawning and lasts 1.5 seconds; subsequent bursts repeat every six seconds. Its preceding 0.75-second tell is visible. Any active slow/stun during the tell or burst cancels that cycle. Existing slow still multiplies its ordinary movement speed. The model owns phase, cancellation and speed; rendering never advances it.

Broodmother attempts its first brood six seconds after spawning and repeats every seven seconds. A one-second tell precedes each attempt. Freeze postpones the spawn until it can act. Each mother can release at most three pairs, with at most four living children simultaneously; the overall battlefield cap is 96 living enemies. Children use existing goblin art/movement, their current chapter/wave HP scaling, a reduced once-only 4-gold reward, and spawn 0.75 and 1.0 tile behind the mother on the same route, so the pair remains visually separable. There is no on-death spawn, no recursive summoning, no spawn after a terminal result, and no scheduled children after their mother dies. Wave completion waits for surviving children.

## Ownership and presentation

A focused model module owns per-enemy clocks, shell values, summon limits and child provenance, included in the battle hash. FablewoodBattle retains the inherited damage, death, movement, leak and wave authority and calls this module through explicit seams. The screen presents new-enemy descriptions and pre-wave warnings; world presentation shows bounded shells, telegraphs and spawn effects. New copy is English/Simplified Chinese with refreshed bundled glyph coverage. Existing controls, music, default SFX volume, pause, reduced motion, zoom and all existing art remain intact.

The established custom generative production approach is retained. Each original non-humanoid reference is shown before animation production. Each creature receives one continuous fixed-camera animation carrier containing SE, SW, NW and NE motion; stable segments are extracted separately with source-pace timing. Prismback and Harrier have four generated directions. Broodmother has three generated directions plus a mirror-safe NE counterpart derived from its genuine NW rear view; both full-direction source attempts failed to hold a rear-right view, so the wrong-facing interval is not shipped. The correct directional neutral frames are the reduced-motion fallback. Final transparent atlases use a shared source-space scale/crop and measured contact anchors, with pages no larger than 4096 pixels and raw authoring files outside the project. The completed native movement sweep verified each facing, route turns, start/stop, special tells, grounding, pause, portrait and maximum zoom. The three characters are creatures, not humanoids; the humanoid mannequin gait is not an anatomical match.

## Validation and delivery

Focused tests cover mitigation/shield bypass/regeneration, exact dash thresholds and Frost cancellation, summon telegraph/timing/caps/provenance/rewards, dead/terminal cleanup, correct wave gating, deterministic replay and the unchanged old enemies/merges/ultimates. Earned-gold simulations compare old and counter-aware defenses, including a merged-guardian strategy, without debug grants being reported as balance evidence. Real-renderer captures and centralized sound checks precede one managed export, an independent current-PCK probe and a single checkpoint. Browser play remains the user acceptance step.

## References

The numerical values and enemy identities above are original proposed game design, not external factual claims. Runtime ownership follows the active `sim/fablewood_battle.gd`, `sim/battle_model.gd`, `sim/damage_rules.gd`, `scripts/fablewood/world.gd` and chapter resources.

## Execution result

All three enemies are implemented in the active Fablewood battle, with the staged Chapter 2/3 wave additions. Their counterplay is presented in a player-opened bilingual Threats guide, visible ability tells, separate shell/health bars and actual-next-wave warnings. The guide correctly freezes combat and restores prior pause/focus state; it does not interrupt a merge or tutorial. A small same-route stagger makes Broodmother’s two children visually separable.

The new focused model suite passes **913 checks**. Existing suites pass **234 merge checks**, **713 ultimate checks** and **3,591 Worldheart checks**; merge-celebration, 30-second countdown and pointer/touch/keyboard tutorial regressions also pass. Earned-gold comparisons preserve Chapter 1, show increased late-game pressure, and retain successful merge-aware strategies rather than requiring debug currency or forced victories. These scripted strategies are evidence of viable builds, not a guarantee of every player’s difficulty experience.

Native OpenGL captures cover all twelve facings, actual displacement, starts/stops, route turns, loop boundaries, visible grounding/hovering, special tells, paired minions, camera culling, pause, reduced motion, and English/Chinese portrait/large-text UI. The three semantic sound events pass real-audio routing, active/offscreen culling, eight-voice limits and the unchanged 0.4875 default. The final sprite set contains 288 384×384 alpha-safe frames across twelve pages. Broodmother’s rear-right is an explicitly documented symmetric reflection of its generated rear-left view, not a falsely claimed successful fourth generated view.

The campaign environment binding was recomputed through the existing canonical codec for the added enemy definitions. An actual prior-checkpoint save fixture successfully decodes and resumes with campaign UID, stars, marks and heroes retained. Validation remains enabled; no reset or permissive save bypass was added. Current exported-pack validation and user browser acceptance complete the delivery sequence.

The final managed export completed successfully. Its current 160 MiB PCK was booted independently outside the project and passed all twelve directional texture loads, three sound resources, actual Chapter 2/3 final-wave spawns, shell/Earth bypass, Harrier/Frost cancellation, brood timing and once-only rewards, presentation isolation, English/Chinese glyph parity, terminal cleanup and return to title. Both local and public HTTP previews serve the Fablewood identity. Browser gameplay/performance acceptance remains with the user.
