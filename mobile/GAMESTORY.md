# Expat8 game story

## Story premise

The learner travels through the Atlas of Learning, restoring five places by
solving short language and number challenges. Each level reveals a new place,
adds a visual landmark, and introduces a richer arrangement of the same
musical motif. The player is an explorer; mistakes are practice clues and
never damage the world.

## Chapter progression

| Level | Chapter | Visual landmark | Music resource | Mood |
| --- | --- | --- | --- | --- |
| 1 | Study Grove | Leaf canopies and a first trail | `music_story_01.wav` | Calm, open, curious |
| 2 | Paper City | Lit rooftops and book-shaped towers | `music_story_02.wav` | Brighter pulse, forward motion |
| 3 | Signal Harbor | Layered water and a guiding beacon | `music_story_03.wav` | Wider, more rhythmic |
| 4 | Moonlit Library | Shelves, arches, and constellation rings | `music_story_04.wav` | Rich harmony and lifted melody |
| 5 | Word Summit | Rising peaks and a warm summit flare | `music_story_05.wav` | Fullest arrangement and resolution |

The visual palette grows from Expat8 indigo and teal. Amber marks the final
chapter's earned milestone; it does not replace the app's primary accent.

## Level mapping

- Word Blaster maps each cleared wave to the next level. Its five chapters
  repeat in order after level 5 so every wave changes the scene and soundtrack.
- Math games map their selected Grade 1–5 level to chapters 1–5.
- Sudoku maps Beginner, Easy, Medium, Hard, and Expert to chapters 1–5.
- A chapter change affects the scene, chapter label, and background music only.
  Game rules, difficulty, scoring, and learning outcomes stay owned by each game.

## Audio direction

All five loops are original synthesized assets produced by
`tool/generate_game_audio.py`. They share a short melodic motif and loop length;
each chapter adds harmonic and rhythmic layers while preserving a soft mix
under questions and voice prompts. `GameAudio` owns chapter selection, looping,
and the user's music setting. Sound effects remain shared across games.

## Motion and accessibility

Story scenery is vector artwork, cached by the existing game scene. A level
change swaps the scene and soundtrack at the wave break; gameplay input is not
blocked by the transition. Reduced-motion settings keep the same still scene
and suppress the existing particle effects. Chapter identity is shown with a
text label as well as color.
