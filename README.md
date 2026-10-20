# Living Print

https://github.com/user-attachments/assets/67a54c2a-8423-47f6-8fd7-fc6376db20ac

A shoe configurator built entirely with the [Rive CLI](https://rive.app/docs/cli/overview). The control
panel is a sheet of paper that curls through the 3D scene: its typography, scrolling pattern list, palette
swatches, sliders, text field and icons are live Rive artboards with layouts, data binding and timelines,
mapped onto a curved surface by WGSL shaders on Rive's GPU canvas. The same animated vector patterns print
onto the shoe, the ribbons around it and the list previews, and the name you type appears on the shoe.

Pointer input is mapped back through the curved surface to the artboard, so every control works where you
see it, even while the sheet bends, lifts or unfolds. The whole project is plain source files: RML markup for
the artboards (`scene.rml`), AnimaScript for the scene and input, and WGSL for the shaders. It builds into one
`.riv` file.

## Run it

1. Install the Rive CLI:

   ```bash
   curl -fsSL https://releases.rive.app/cli/install.sh | sh
   ```

2. From this folder:

   ```bash
   rive .
   ```

   This builds `build/living-print.riv` and opens the preview window. The build takes about a second.

Builds with Rive CLI 1.5.1 and newer. The scene is composed for 1600x900 and reflows to the window size,
down to a phone shape.

## Controls

| Input | Action |
|---|---|
| click a pattern (Waves, Checker, Orbit, Fragments) | print it on the shoe; a strip travels from the row to the shoe |
| drag the pattern list | scroll it (the Patterns tab scrolls back to the top) |
| click a swatch | pick one of six palettes (the Color tab steps through them) |
| drag Scale / Motion | pattern size and speed |
| round button, or Space | pause and play the print |
| click the name field, then type | the name on the shoe: up to 12 letters, digits or hyphens; arrows, Delete, Esc and Enter work |
| drag PULL THE CORNER up | lift the sheet |
| click PULL THE CORNER, or F | unfold and fold the sheet |
| drag outside the sheet | rotate the shoe |
| move the pointer | the camera leans toward it |
| R | reset the shoe and camera |
| M | reduced motion: no camera lean, controls change state at once |

The keys work while the name field isn't focused. Hosts can also set the `reduceMotion` view model property.

## Edit it in the Rive Editor

The project is laid out the way `rive pull` writes it (`scene.rml`, with every script, shader, font, image and
mesh as a file next to it), so it round-trips cleanly between the CLI and the Rive Editor:

```bash
rive login
rive push            # first push: creates a file in your Rive account and records the link in rive.yaml
```

Designers open that file in the Rive Editor and change layouts, colors, text, patterns, animations and state
machines. Bring their work back with:

```bash
rive pull            # writes the Editor's version over scene.rml and the script, shader and asset files
git diff             # review what changed
```

Keep the project in Git: a pull overwrites the local files with the Editor's version, and a push replaces the
Editor's content with yours, so commit before either one. Edits made on both sides at once are not merged.

Some code is tied to the artboards by name, so keep these in step when you change them:

- `main.as` gets the artboards through the script inputs on the `Living Print` layout (`ui` is Pattern browser,
  `header` is Masthead, `mark` is Personalization, `manifesto`, `waves`, `checker`, `orbit`, `stripes`), and
  reads and writes the view model by property name (`pattern`, `palette`, `tab`, `scale`, `speed`, `paused`,
  `mark`, `flat`, `pull`, `orbitYaw`, `reduceMotion` and others). Keep those names.
- `micro.as` finds the controls on the Pattern browser artboard by node name (`Pattern viewport`,
  `Choose Waves`, `Patterns`, `Palette 1` to `Palette 6`, `Play pause`, `Scale vector slider`, `Mark field`,
  `Lift the paper` and so on) and plays its 42 hover, press and selection timelines by name (`Select Waves`,
  `Hover Checker`, `Tab Color`, `Press Palette 3`, `Transport state`, `Focus mark`).
- The hit areas in `micro.as` use fixed sizes (pattern rows 82 tall, swatches 56, the play button 54, the name
  field 43). If a designer resizes those controls, update the numbers.
- The curved sheet is defined twice, once for drawing (`panel.wgsl`) and once for mapping the pointer back to
  the artboard (`surfaces.as`). A change to the shape goes in both.
- `tools/check_interactions.py` clicks fixed points in the 1600x900 layout. Update them if controls move.

## How it's built

| Piece | Where |
|---|---|
| Artboards: Pattern browser (the sheet), Masthead, Manifesto, Personalization, the four patterns; view model, timelines | `scene.rml` |
| Scene layout, shared state, texture passes, input forwarding | `main.as` |
| Curved sheet, ribbons, transfer strip, and the inverse pointer mapping | `panel.wgsl`, `surfaces.as` |
| Shadow map, studio floor, plinth with Rive lettering on its side | `stage.as`, `environment.wgsl` |
| Shoe: mesh, materials, the live print and the name | `shoe.as`, `footwear.wgsl`, `shoeVertices.bin`, `shoeIndices.bin`, `shoeColor.jpeg`, `shoeNormal.jpeg`, `shoeOrm.jpeg` |
| Backdrop | `studio.wgsl` |
| Name field: text input, caret and selection | `entry.as` |
| Hover, press and selection animations | `micro.as` |
| Helpers | `support.as`, `gpu_helpers.as` |
| Fonts | `Instrument Sans.ttf`, `Inter.ttf` |

The UI artboards are drawn into textures at 2x and the patterns into a 1536x1536 texture, then mapped onto the
meshes. Shadows use a 4096x4096 depth map with soft, contact-hardening filtering shared by the shoe, the sheet
and the plinth.

### Checks

```bash
rive . --verify                       # compile check
rive . --test                         # 11 unit tests: text editing, surface continuity, pointer mapping
python3 tools/check_interactions.py   # 14 pointer and key replays through the curved sheet
```

### Rebuilding the shoe assets

The shoe files are extracted from the Khronos sample model with no changes to the geometry or textures; each
vertex gets one extra value that tags its part (laces, upper, eyelets, sole, heel patch). To rebuild them:

```bash
curl -fsSL -o tools/MaterialsVariantsShoe.glb \
  https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/MaterialsVariantsShoe/glTF-Binary/MaterialsVariantsShoe.glb
python3 tools/prepare_shoe.py
```

This reproduces the shipped files byte for byte (Python 3 standard library only).

## Credits

- **Materials Variants Shoe** © 2021 Shopify, from the
  [Khronos glTF Sample Assets](https://github.com/KhronosGroup/glTF-Sample-Assets/blob/main/Models/MaterialsVariantsShoe/README.md).
  Licensed [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The mesh and the Midnight color,
  normal and occlusion/roughness/metalness textures are used unchanged, with a part tag added to each vertex;
  this project renders the shoe with its own shaders and prints its own patterns on the upper.
- **Fonts**, under the [SIL Open Font License 1.1](https://openfontlicense.org) (license texts in
  `licenses/`): [Instrument Sans](https://github.com/Instrument/instrument-sans) by The Instrument Sans
  Project Authors, [Inter](https://github.com/rsms/inter) by The Inter Project Authors.
- FORMA is a fictitious brand.

## License

The code and tools are released under the [MIT License](LICENSE). Third-party content keeps its own license
as listed under Credits (Materials Variants Shoe: CC BY 4.0; fonts: SIL OFL 1.1). The Rive name and logo are
trademarks of Rive Inc.
