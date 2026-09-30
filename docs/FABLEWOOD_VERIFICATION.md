# Fablewood verification

The current starter README and `game-verification.json` own the verification workflow.
Restore `assets.lock.json`, then use the installed runtime’s `npm run check`, `npm run build`
and `npm run check -- --pack` from a disposable project. The isolated runners in `tools/`
support focused native checks without touching playable saves.

The registered checks cover combat, merging, ultimates, Worldheart, late enemies,
save compatibility, interpolation, effects, endpoint animation, atlas layout, placement
and the browser music marker. Browser testing must use the current exported game.
Historical screenshots and results from the source session are not current build evidence.

The Chapter 1/2 reference strategy clears; its Chapter 3 loss is a regression baseline,
not a claim about all strategies or campaign balance.
