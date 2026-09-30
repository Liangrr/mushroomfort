# Third-Party Notices

Mushroom Garrison (蘑菇要塞) is an original game. Its name, characters, artwork, music, sound effects and text are original to this project.

## Engine

Built with the Godot Engine (MIT License). The full engine license and its third-party component notices are shown on the in-game **Licenses** page.

## Typography

| Font | Use | License | Notice |
| --- | --- | --- | --- |
| Fredoka | Display lettering (titles, buttons, numbers) | SIL Open Font License 1.1 | `assets/mg/fonts/Fredoka-OFL.txt` |
| Figtree | UI body text (regular / medium / bold) | SIL Open Font License 1.1 | `assets/template/fonts/Figtree-OFL.txt` |
| Noto Sans SC (common-character subset) | Chinese UI text and the loading-screen subset | SIL Open Font License 1.1 | `assets/template/fonts/NotoSansSC-OFL.txt` |

The runtime CJK fallback keeps the canonical codepoint repertoire documented in `assets/template/fonts/runtime-cjk.json`.

## Art and audio

All sprites, map paintings, UI art, the title key art, the logo lettering, the share cover, the background music and the sound effects were created for this project with Manus built-in generative tools, then processed deterministically (background cleanup, trimming, resizing, loudness normalisation and looping) by `tools/mg_process_art.py`, `tools/mg_loader_art.py` and ffmpeg. Per-file hashes are recorded in `asset-provenance.json`.

Earlier template media still recorded in `assets.lock.json` under `assets/template/` (other than `fonts/`) is not used by this game: those folders carry a `.gdignore` and are excluded from the player export.
