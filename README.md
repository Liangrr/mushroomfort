# Game Template — Elemental Tower Defense

This versioned source is owned by the Webdev Addon. Use the installed Game workflow for initialization, preview, release and publishing. Matching gameplay source: template-provenance.json. Existing projects are never overwritten by a new starter.

For online multiplayer, read [the shared service guide](docs/game-multiplayer.md).

## Shared game-development workflow

Applies to Standard effort, not `fast_prototype`; Fast uses its dedicated section instead. Keep edits scoped and preserve explicit constraints.

### Preserve the selected template
Extend the initialized project and keep its working simulation, controls, saves and delivery. Integrate supplied
games into that project. The first Preview must show the requested game, not a renamed demo; replace the Generic
maze gameplay unless a maze was requested.

### First-checkpoint completion contract
Deliver the requested goal, actions and outcome loop with understandable controls and feedback, recovery or replay
where it fits, coherent readable visuals, the necessary start, pause and results screens, and any requested
deliverable. Match run length and content to the brief; there is no minimum playtime, campaign, extra mode or screen
quota. Prioritize gameplay, broken resources, responsiveness and visible defects, and stop when the requested
experience works. Add art, audio or polish only for a concrete benefit. Leaderboards, new Tweak controls and extra
languages are optional; required Share OG and explicit media, concept or feature requests are not.
Default to desktop. Add or test touch controls, portrait layouts or mobile-browser support only when the user asks.
Sharing a Web link is not a mobile request. Keep inherited controls working without expanding mobile coverage.

Choose the [delivery scope](game-delivery.md#delivery-scope-and-stopping-boundary) from the request. Ordinary managed
delivery is check → save-release.mjs → applicable check --pack → push the exact SHA and confirm the checkpoint.
Documentation-only edits need no engine boot. Do not add audit reports, speculative test suites, a separate
self-review phase or duplicate validation workers.

### Ownership boundaries
Keep flow, authoritative simulation and scoring, input, entities, tuning, presentation and persistence in their
existing owners; cosmetics never decide collisions or rewards. Offline authority stays in Godot and online authority
on the dedicated server. WASD is reserved for player movement or camera panning, never abilities or menu actions;
leave it unbound when nothing moves, and update remapping, tutorials and hints when replacing conflicting shortcuts.

### Gameplay feedback and optional polish
Make actions, damage, rewards and outcomes readable with fitting cues. Reuse feedback and add effects only where they improve readability or the requested feel; particles, reward flights, shake and animated counters are optional. Keep overlays input-transparent, cosmetics independent of simulation and reduced-motion settings intact.

### Tutorial content boundary
Explain goals, controls and rules briefly in the game's language; simple games may use a start-screen hint.
A staged tutorial needs a working Skip that releases input/pause locks and remembers dismissal. Keep implementation values
and Tweak controls out of player instructions.

### Optional local leaderboard
Add local standings only when requested or integral to scoring and replay, and keep a useful existing one; changes
keep bounded records, once-only terminal submissions and deterministic ties. Online
rankings need an explicit request and the installed leaderboards guide; never provision a backend for an offline
game by default.

### Native verification
Reuse existing checks for changed gameplay, input, audio, saves, localization or tuning. For visual questions,
capture with the real renderer (`get_viewport().get_texture().get_image()` and `Image.save_png()`); headless Dummy
rendering proves nothing visual. Do not drive the Preview with browser automation, screenshots or self-tests unless
the user asks for browser debugging; use logs and report Web input, audio and layout as pending user acceptance.

### Concept work by request
Concepts are conditional, not a routine production step. Follow the Blueprint's recorded mockup choice and do not
offer a second concept workflow when the direction is already clear. For an explicit request, produce distinct,
coherent interpretations of the brief and keep the selected identity through revisions. The Game Concept Design flow
needs exactly three separate mockups generated under the recorded image consent, presented through the existing card
and explicitly approved; never label mockups as screenshots. Outside that flow, honor the requested count and
approval method. Mockup consent is not consent for production assets.
## Shared art and audio production

### Asset reuse and targeted production
Reuse suitable supplied, template and already available assets within their recorded permissions and the user's
source restrictions; template reuse needs no extra approval. Replace only assets that conflict with the requested
theme, lack necessary states or look visibly wrong. A new game or reskin does not require replacing every image,
animation, icon, track or effect unless the user asks for original art or a full replacement. Retain unused
reference files and supplied license notices, describe reused assets honestly, and update visible titles and themed
copy. Rename internal IDs only when needed, together with their consumers, saves and tests.

### Coherent scene and title art
Fulfill the requested visual scope with readable actors, hazards, UI and a coherent scene. Simple intentional
visuals are acceptable within the recorded source choice. Title and loading screens may reuse permitted game art
with live text; no separate key art is needed. A download is not integration: inspect the affected scene.

### 3D texture budgets
Budget the project's stored textures, including bytes embedded in GLB/glTF, not catalog masters or import limits.
Longest edge: 256–512 for small or distant props, 1024 by default, 2048 for close main actors or shared atlases,
4096 only for a justified visible difference. Never upscale, and keep UVs, channel packing and material bindings
intact. Remove replaced embedded bytes, keep ancestry and sync the changed files. If suitable tools are missing,
report it rather than replacing working assets. Claim only measured savings.

### Continuous animation and alignment
Use the approved animation method. AI continuous motion goes from approved static references to a guided
fixed-camera, in-place video to fixed-FPS extracted loops; independent poses need an approved stepped style. Keep a
shared canvas, scale, pivot and contact anchor across states and facings instead of per-state placement patches, and
keep raw masters outside the game. Check representative movement, reversal and ground contact with the native
renderer.

### Mandatory background removal for composited assets
Composited sprites, icons, portraits, cursors and loader art need clean real alpha that survives resize, import and
export; check changed edges on contrasting backgrounds at display scale. Opaque plates and terrain are exempt. Keep
words, numbers and HUD labels live, and never slice concept collages into runtime assets. Generate cursors on a
hot-pink or neon-green background and remove it before use.

### Seamless parallax backgrounds
Repeating layers must tile left and right without mirroring; check the joins between adjacent copies at the intended
scale after any crop, import or scale change. Side-scrollers keep a low scenic foreground above world actors and
below the HUD without hiding combat.

### Audio production as needed
BGM is optional unless requested or essential to the brief. Reuse a fitting permitted template, supplied or catalog
track when the source restrictions allow; silence with safe empty routes is valid, and a new Standard effort game is not a
reason to generate custom BGM. Honor explicit silence, supplied-only, AI-only and custom-music requests, and add only
useful event SFX. Generate audio only for an explicit request or a concrete
unmet need within recorded permissions: one usable result per needed track or cue, retried only for an actionable
correction. If requested custom music cannot be produced, report the unmet requirement. Audition changed audio and
ship compressed runtime audio, not raw WAV masters.

### Audio integration
Reuse the existing Music/SFX routing, gesture unlock and bounded voices, and keep empty routes safe across pause,
retry and scenes. New games that use audio keep the absolute base gains BGM 3× (+9.5424 dB) and SFX/UI 2×
(+6.0206 dB) over the inherited originals: place MusicBase/SfxBase before senders so each route crosses once,
replace old targets instead of stacking boosts, and keep the ≤0 dB guards, saved settings and explicit mixes.
Silent games need no gain plumbing, and existing delivered mixes stay unchanged. Spatial audio keeps real source
positions; music and global HUD sounds are separate. When music is used, keep the shared browser BGM adapter and
its native fallback.

### Asset generation mode gate
Recorded permissions decide what may be generated, regardless of mode or available tools. Hybrid, AI or explicit
permission covers its scoped generated visuals and SFX; mockup consent does not. For authorized images choose the
latest GPT Image model offered by the live schema unless the user named one. Tools record generation metadata
automatically; keep tool, provider, model and internal path details out of user-facing copy.

### Asset-production choice wording
Fast prototype follows its bounded workflow. New managed games call `webdev.init_project` once direction is clear,
with the complete brief; the canonical card settles unresolved choices, not parallel chat questions or a separate
Blueprint. Session-agent catalog search, access, downloads and delegation wait for successful initialization plus a
settled Blueprint, required plan and requested concept approval; in-flight or failed init is not success. Only
initialization's bounded metadata assessment may precede the card, never production downloads, generation or
integration. Standalone search or retrieval needs no project but does not justify speculative new-build sourcing.
Use the conversation language and call the catalog 游戏素材库 in Chinese. Recommend Hybrid mode for 2D, 3D and
unknown games. Card options for 2D/unknown: Manus game assets catalog, Hybrid mode, AI generation; Hybrid means
catalog plus AI art/audio, not scratch visuals. Known 3D: Game asset library and procedural generation, Hybrid mode,
AI generation. Only initialization's evidence-backed insufficient core-visual fit changes the first 3D label to
Procedural generation (Faster, lightweight, minimal token consumption); Unknown/sufficient fit or missing decoration
does not. Preserve historical accepted permissions; never infer them from option names or recommendations.
Only missing card support or a structured `planning_unavailable` receipt moves unresolved setup to one native
single-choice question; canonical state wins. For 2D/unknown: Manus game assets catalog, Hybrid (Recommended), AI
generated. Known 3D: Curated asset catalog and procedural (lowest token cost; catalog first, permitted gaps),
Hybrid (Recommended), AI generated (highest token cost). Keep these labels and this order, and record the answers.
No-questions sessions use
the recommended option within existing permission, which is not new consent. Additions to an existing game ask only
an unresolved production choice; delegation inherits constraints.
Accepted `choices.visualAssetSource: procedural` needs no repeated visual search/gap proof; audio follows its own
source restrictions and optional-production workflow. Catalog and Hybrid sourcing, including required-gap handling,
follows the game-asset-catalog Skill. Procedural permission never implies music composition.
## Shared Web runtime and delivery contract

### Browser-safe lifecycle
Bound and reuse voices, projectiles, particles, timers and subscriptions across pause, retry and scenes; change
pause or stream state on transitions, not every frame. Browser BGM uses the independent Web Audio renderer in
`scripts/manus/browser_bgm_player.gd`, never frame- or timer-fed PCM or finished-callback loops. It decodes once into
a bounded LRU AudioBuffer cache: call `prepare()` during loading or a transition before gameplay, then `play()`
reuses the buffer. Imported duplicates share an explicit original-path `buffer_key`, and changed PCM needs a new key.
Decode imported resources from the PCK, keep SFX in Godot and keep `thread_support=false`.
Route track, loop, position, pitch, mute, pause, duck, crossfade and Music/Master controls through the adapter.
External BGM does not inherit buses: mirror linear gain, limiter makeup and AudioEffectAmplify only. Keep native
Godot and the guarded Web fallback (`PLAYBACK_TYPE_STREAM` for long BGM) without overlapping backends; pending
autoplay waits for valid input, and stale starts are guarded. Stop voices and release removed cues with
`release_cached_stream()`, evict only unreferenced tracks, keep OS/bfcache suspend and restore, and release the context
on real teardown. Native tests cannot prove browser continuity through
main-thread stalls, so report that as pending user acceptance.

### Fast, recoverable startup
Keep the title and controls interactive with only the required fonts, UI, settings and small art. Defer scenes,
generation, media and decoding until needed, in bounded per-frame work; instantiate scenes on the main thread. Start
blocks duplicate transitions and reports recoverable content errors. Lazy PCK content reduces work, not transfer
bytes. Loading progress uses real bytes or phases and an indeterminate state for unknown totals; slow or stalled
notices are nonfatal, offer Retry, and clear on late success. When changing this mechanism, check cold load,
repeated Start, stall, unknown total, late success and Retry.

### Animated backgrounds without startup blocking
Show a small static placeholder immediately and retain it as fallback. Load animations asynchronously after the
title is interactive, outside Start/preload dependencies; swap on a ready frame, guarding exited scenes and stale
completions.

### Large explorable maps: presentation culling and live state
Offscreen simulation, pathfinding, orders, combat, economy, timers, replication, saves and minimap stay live. Cull
only cosmetics against current camera bounds, with sprite margins and separate fog; never remove gameplay actors,
projectiles or collision by distance. Reentry shows current state without replaying missed effects. Optimize measured
bottlenecks with existing spatial or dirty-region mechanisms; compare crowded, zoomed and revisited views to a
baseline rather than relying on empty-map FPS.

### Destructible props
Destroyed rubble and fragments render below actors in effective world z while keeping footprint, collision release
and reward position; reset restores the intact state.

### Language scope and bundled fonts
Use the requested game language, defaulting to the conversation language. New games need no extra language or
EN/CN toggle unless requested; keep working localization on existing projects, and every exposed locale must be
complete. Keep player-facing words live instead of baked into art. Do not rebuild or re-audit the unchanged bundled
fonts; check changed text bindings, layouts and supported player names only. Keep name validation and save behavior,
and do not claim unsupported character coverage.

### Default typography
Default to the template's bundled theme: its display faces for titles/headings, its body face
(`assets/template/fonts/ui_{regular,medium,bold}.tres`) for UI text, then Noto Sans SC (6,547-codepoint repertoire)
for Chinese; Web loaders embed a small Noto Sans SC subset. Noto Sans SC is variable and its default instance is Thin,
so bind a weight through the template's font resources, not the raw file. Keep each bundled font's license
(`<Family>-OFL.txt`) beside it when copying, renaming or adding fonts; the Web export lists them on its Open Source
Licenses page. Missing template fonts restore from `assets.lock.json`; do not substitute system fonts. Existing
ManusCC0 projects keep their fonts unless the user asks for new typography. User-uploaded fonts are unrestricted: no
licensing, family, glyph-coverage, font-file, font-resource or font-pack size gates, and no rights review,
redistribution proof or notices. Theme or mood alone does not imply replacing the default fonts. This supersedes font
restrictions in frozen READMEs and local checks, including older ManusCC0 defaults: remove those policy gates when
integrating uploads, and keep only technical file-integrity and path checks.

### Viewport and background coverage
For fixed-coordinate Godot layouts set `[display]` `window/stretch/mode="canvas_items"`,
`window/stretch/aspect="keep"` and logical viewport size; retain working adaptive layouts. Input targets the active
surface, not letterbox margins. Check affected desktop resize, aspect and DPR. Isometric zoom uses ordinary wheel or
trackpad without Ctrl/Meta, with pointer-anchored picking and fixed-scale HUD. Mobile, touch and portrait work follows
the workflow's user-request rule even when template guides list those cases.

### Development Tweak when needed
The Addon generates the floating frosted-glass Tweak popover from the game's descriptors; never create an in-game
panel, launcher or F10 shortcut. Adapt the existing catalog to the requested game, extend it for meaningful tuning
and remove controls with no real consumer (at most 128). Keep one parameter manager with stable IDs, typed defaults,
bounds/options, localized labels, honest apply timing and existing run eligibility. Edits/reset affect only the
Addon draft. Apply validates and commits the whole patch without disk writes or preview reload; unchanged values
emit nothing. Gameplay boundaries consume pending values but never send catalogs. Do not add numeric revisions.
Save with Manus sends selected values to the task for source edits and the normal build/checkpoint flow; it does
not publish. Keep the adapter in `scripts/manus/preview/`, which release excludes with its autoload entry. Normal
player Settings and gameplay consumers remain. Existing genre rules below identify the actual parameter owners.

### Export constraints
Include runtime JSON/CSV/TXT through include_filter or Godot resources. Keep Web thread_support=false, resource paths discoverable, and the template-specific size budget. Use the Session port and the Addon preview/export workflow; do not hardcode the old Sandbox port or overwrite generated site/dist. Change identity through project.godot and the editable game loading shell, not generated HTML.

**Fablewood: Keepers of the Last Seed** uses `junnyboi/game-td-elemental` art.
Follow the installed Game workflow; do not restore predecessor roster, traps or campaign.

## Playable loop

Defend the Last Seed across three eight-wave chapters. Place guardians on raised platforms, earn
gold, upgrade three tiers and merge elements. Clears improve stars/unlocks. Replays, tutorials,
pause/settings, durable results and standings are integrated. Normal/Hard is fixed at battle start.

`scripts/fablewood/tuning_catalog.gd` starts gold at 300 (200–800/25) and health at 20 (5–20/1).
On launch, `screen.gd::_apply_tuning()` overrides model `dp/base_hp`; align its fallbacks with
`sim/fablewood_battle.gd::create_fablewood()` and test chapter launches. For health above 20,
raise `_check_terminal()`'s `mini(20, base_hp + 1)` cap too.

| Element | Combat role |
|---|---|
| Fire | Ground splash and burning; suppresses troll regeneration. |
| Frost | Slows ground and flying enemies. |
| Storm | Chains lightning with aerial priority. |
| Earth | Ground-only armor-piercing physical damage and stagger; bypasses Prismback’s Arts shell. |

Invaders: Goblin, Orc, Troll, Dragon, Prismback, Harrier and Broodmother. Prismback's shell regenerates;
slow/stagger interrupts Harrier bursts; Broodmother spawns bounded children. Hard strengthens/compresses
late schedules. Counter feedback adds no damage bonuses.
Basic hits use `ceil(attack_rating * 0.25)` at every tier. Base enemy HP uses
`floor(authored_hp * 1.5)` before chapter/wave/difficulty multipliers. Preserve rounding, costs
and rewards. The Chapter 3 regression proves one eight-wave clear using starting and earned gold.

## Source owners and extension seams

| Owner | Responsibility |
|---|---|
| `autoloads/game.gd` | Routes, tickets, results, score retry, data clearing. |
| `sim/fablewood_battle.gd` | Fixed-tick combat, upgrades, waves, merges, terminal metadata. |
| `sim/fablewood_ultimates.gd` | Recharge, targets, delayed pulses and Convergence Meteor. |
| `sim/battle_model.gd`, `sim/campaign_*`, `sim/battle_ticket*` | Combat, campaign commands, recovery and launch validation. |
| `data/{stages,operators,enemies}/` | Grids, paths, schedules, base definitions. |
| `scripts/fablewood/screen.gd` | Title/chapter/battle/result/settings/tutorial UI and input. |
| `scripts/fablewood/world.gd`, animation/effect helpers | Projection, actors, camera, bounded effects. |
| `autoloads/{music,sfx}.gd` | Playback and routing. |
| `scripts/fablewood/tuning{,_catalog}.gd` | Typed parameters, requested/active state, integrity. |
| `scripts/manus/preview/tuning_{adapter,transport}.gd` | Addon Tweak bridge, excluded from player builds. |
| `scripts/fablewood/screen_filter.gd{,shader}` | Optional static presentation filter. |

The model owns combat, RNG, ticks and rewards; views cannot mutate simulation or saves.
`Game` owns routes and campaign saves.
Launch commits before battle. Failed results retain their ticket/outcome; pending-attempt recovery
restarts the chapter. Clear data through `Game.clear_player_data()`.

Only `s1`–`s3` are playable; retained `s4`–`s10` still affect campaign identity.
`sim/campaign_runtime_context.gd` and `sim/campaign_v3_codec.gd` include **every stage with
`campaign_index >= 1`** in stage order, rewards and combat binding; do not delete them.
Schedules use `wave_index * 30000 + within_wave_tick` with zero-based waves. More waves/chapters
require coordinated launch, navigation, clear rules, rewards and tests.
`CampaignV3Codec.derive_environment_sha256()` binds operator resource bytes/combat fields, classes,
skill/target policy, campaign/reward rules, traps and campaign stage IDs/order. Its
`sim/combat_content_binding.gd` projection also binds the enemy IDs referenced by waves across
all those stages and each enemy's `defense`, `resistance_permille` and `attack_damage_kind`.
Stage/enemy resources contribute this projection, not all their bytes. After editing identity inputs, run
`tools/run_godot_test.sh res://test/fablewood_context.gd`. Synchronize its derived hash in
`data/campaigns/p16_v3.tres` and `data/campaign_def.gd` (`P16_V3_ENVIRONMENT_SHA256`), then verify
launch/result commit. Preserve old saves through explicit migration or a new fork save identity.
Runtime Tweak does not edit these authored files.

## Merging and ultimates

Two living, different-element tier-III guardians produce six dual guardians: Fire/Frost → Rimeflame;
Fire/Storm → Thunderpyre; Fire/Earth → Cinderroot; Frost/Storm → Tempestquill;
Frost/Earth → Winterbark; Storm/Earth → Thornvolt. The model owns donor eligibility, reversible
removal and legal placement. Pending placement holds preparation and blocks conflicting actions.
Cancel, Escape and teardown restore donors, counters and ultimates. Execute cancellation outside
`assert()`. Merging costs no currency.
Dual guardians retain independent attack channels and the larger donor range; ordinary upgrades end.

Complementary duals with no shared element summon **Worldheart, the Fourfold Warden**:
Rimeflame + Thornvolt, Thunderpyre + Winterbark, or Cinderroot + Tempestquill. It inherits four
channels and summed donor ranges, then cannot upgrade/merge. Reject mixed basic/dual, same-element,
overlapping-element or dead donors without losing units or spending gold.
Dual ultimates recharge in active waves with living enemies, wait for eligible targets and retain
charge between waves. Preserve integer-tick periods and masks.
Worldheart’s meteor charges for 600 combat ticks and flies for 30 ticks to a locked position.
Removal, cancellation and terminal states clear/restore pending work in the model;
meters, localized inspectors and effects only display it.

## Results and recovery

Score remains `clamp(win * 2,000,000 + chapter * 100,000 + stars * 20,000 + kills * 50 -
leaks * 500, 0, 4,000,000)`. Duration is terminal combat ticks divided by tick rate, excluding
wall-clock pauses. The model seals mode, terminal tick, tick rate, duration, run hash and tuning
provenance. Fatal damage wins over simultaneous final-wave completion. Preferences/resets cannot
relabel finished attempts; hashes prove local consistency, not server-certified anti-cheat.

Standings retain 50 rows/group, filter before showing eight, and break ties deterministically.
**Normal/Hard** contain eligible runs; **Practice** contains
applied gameplay tuning; **Legacy** preserves records without sufficient provenance. Pending
NEXT_STAGE edits do not taint a current run. Applied gameplay changes remain marked through Reset;
cosmetic/audio changes remain eligible. No remote leaderboard is configured.

Failed campaign saves retain their mutation behind Retry Save, which survives resize/language changes
and cannot be dismissed. Failed launches retain the screen with retry feedback. After campaign commit,
score-only retries retain submission ID/time without repeating progression. Corrupt scores recover
from a valid backup.

## Controls, onboarding and localization

Pointer/touch controls place, select, upgrade, merge, pan and zoom. Preserve inverse picking,
platform contacts, bounds and single touch ownership; ignore emulated mouse events in the world.
Keyboard: 1–4 select; U upgrades; Enter/keypad Enter starts a wave; Space opens Pause;
Q/E changes 1×–4× speed; WASD pans; Escape cancels placement/merge or follows the active modal.
Ignore repeated/modifier gameplay shortcuts and focused text input. Keep speed across pause/relayout.

Each wave has 30 seconds of preparation independent of speed; Pause, modals, tutorials and pending
merges hold it. Manual start/expiry share one action without duplicate waves. Preserve ready pulse/bar,
upgrade shortfalls, affordability and reduced motion. Modals own focus/input; Settings returns to
Pause, Resume works after Threats/How to Play, and resize/language changes retain state and camera.

The six-step tutorial offers Skip. Selection, placement, upgrade and wave steps require successful
actions; informational pages allow Next. Hints follow input method. Persist versioned completion/skip,
migrate old seen flags once and respect completion on Retry. How to Play replays it; omit developer controls.
All copy uses matching keys and whole-message placeholders in `localization/{en-US,zh-CN}.json`,
including narrow guardian labels, inspectors, rankings and Tweak. Figtree regular/medium/bold use
the full approved Noto Sans SC fallback; retain OFL notices and the loader’s embedded subset.

## Art, audio and player settings

For new TD games, theme towers and raised pads within the complete brief, saved Blueprint roles,
accepted asset source and permissions. Preserve approved reuse/exclusions and empty coverage;
generate only when authorized, else adapt suitable supplied/catalog art.
Backgrounds cannot theme towers; report retained starter art.
For selected roles, replace four elements at all tiers, six merges and Worldheart: static and
basic idle/merged idle/cast sheets (48 frames, 8×6), plus pads. Use new paths and update
preloads in `presentation.gd`, `guardian_animation.gd`, `merged_art.gd` and
`merged_animation_layout.gd`. Align logical cells, trim, pivots, anchors and pad contact/picking
with new art. Atlas metadata is path-keyed; do not overwrite packed paths with
raw sheets or run `pack_atlas_padding.py --apply` while packing is enabled. Save/prepare syncs
media; never hand-edit lock facts. Run atlas check; render idle/cast, reduced motion and placement.

Starter maintenance keeps imported art/effects. `assets.lock.json` restores `assets/template/`
by path/size/hash with matching imports. `asset-provenance.json` and `THIRD_PARTY_NOTICES.md`
retain known source/license facts; unknown historical models stay unknown. Exclude obsolete
`refined_animation/` from exports. Preserve animation states, bounded caches, culling and teardown.

Music cue `fablewood` uses `Audio/illuminated_theme.ogg`, a 138-second loop across title, chapters,
battle and results. SFX keys map to `Audio/illuminated_<cue>.ogg`: `hover/confirm/back/invalid`,
`build/upgrade`, `fire/frost/storm/earth` and `_hit`, `enemy/breach/wave/merge_success`,
`enemy_shell_break/enemy_harrier_dash/enemy_brood_spawn`, `meteor_impact`, `victory/defeat`.
Check `bundled/{music,sfx}/catalog.tres` and event routing before altering the map. Reuse supplied media.

Routing: Music → Master; UI → SFX → Master. Master/UI default to unity. Preserve Music/SFX gains,
eight SFX voices, cooldowns, deduplication and spatial checks. Settings persist four volumes, reduced
motion and a default-off static filter: intensity zero disables rendering; it ignores input/simulation.
Pause preserves music/existing SFX without new combat events. SceneTree pause suspends/resumes the
same native voice. Stage pitch updates a playing cue without restarting; the browser BGM adapter owns unlock/Master gain.

## Tweak boundaries and player exports

The Addon popover reads 15 localized descriptors in six categories via `TuningBridge`.
The game has no panel/launcher/shortcut. The Addon owns drafts, Reset and Save with Manus.
Apply validates one atomic patch without persistence/reload; unchanged values emit nothing.
Requested/active state stays distinct; schema identity is locale-independent.

| Boundary | Controls |
|---|---|
| LIVE, cosmetic | Guardian/enemy visual scale, effect opacity. |
| NEXT_ACTION, cosmetic | SFX pitch, acknowledged when a cue starts. |
| NEXT_STAGE, cosmetic | Text scale, initial camera zoom, music pitch. |
| NEXT_STAGE, gameplay | Starting gold, reward scale, town health, attack damage/speed, range bonus, enemy health/speed. |

Validate numeric types, finite bounds and steps before consumption. UI rebuilds retain active chapter
values. The bridge checks leases, schema, membership and values. Only the adapter/transport live in
`scripts/manus/preview/`; common release preparation removes that directory and its autoload. The
production manager starts at canonical defaults with no draft-file reads/writes; old debug config
cannot affect release. Player Settings, audio and filter remain available.

Web exports use `web/loading.html` and include locale/atlas metadata and font notices;
exclude tests/tools, obsolete media, locks/provenance and generated output.

## Verification

`game-verification.json` registers twelve bounded checks: base loop, merges, ultimates, Worldheart,
late enemies/old saves, interpolation, particles, endpoints, atlases, results/retries and a source suite.
The suite covers music markers, real Tweak consumers/bridge, audio/filter, modal/tutorial recovery,
Hard standings, placement/touch, isolated test guards and a Chapter 3 earned-gold clear.
Children require clean markers, isolated saves and frame limits. Packed hooks run externally against
the exact PCK; fixtures are not shipped. Launch checks cover repeated Play/Replay/Continue and failed-launch retries.

Run `npm run check`, the installed release preparation workflow, then `npm run check -- --pack`.
Focused `SceneTree` scripts use
`tools/run_godot_test.sh res://test/<check>.gd` with resolved `GODOT_BIN`; Node fixtures use their
`.tscn` scenes (attach the script to a Node in a disposable wrapper if needed). Render-capture
fixtures need native Godot scenes, not headless `--script`. Use disposable copies.
`FABLEWOOD_UI_CAPTURES` captures the integrated UI with a real renderer; Dummy audio cannot prove
audibility. Use registered Fablewood checks; predecessor `tests/` UI fixtures are historical.
Shared workflow controls native screenshots and requested browser/mobile checks.
Source/native/PCK checks do not prove browser acceptance, deployment or session adoption.
