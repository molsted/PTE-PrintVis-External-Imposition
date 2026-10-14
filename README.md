# PTE PrintVis External Imposition

Solves a PrintVis job's imposition with the external Impositioning engine, lets a
planner choose a layout in the engine's own editor embedded in Business Central,
and writes the CIP4 JDF ticket for that choice.

## How it works

1. **Solve Imposition** on a PrintVis job builds a self-contained
   `CalculateRequest` — the product from the job's components, the paper from the
   job's own `PVS Job Sheet` rows, and the presses from the cost center
   configurations marked for imposition, sent inline. Nothing is registered with
   the engine.
2. The Impositioning editor opens in a frame on the imposition card, seeded with
   that request. The planner picks a layout.
3. **Generate JDF** posts the chosen solution to the engine and stores the
   ticket on the job.

Nothing is written back to the PrintVis calculation. The one exception is the
sheet preview image, written to `PVS Job Sheet Imposition` when the plan's press
runs line up one-to-one with the job's PrintVis sheets.

## Setup

Imposition reads what PrintVis already records. There are no separate paper, press,
part or binding lists to keep; the few things PrintVis has no field for sit on
PrintVis's own pages.

Start with **Assisted Setup → Set up imposition** (also *Setup Guide* on the
Imposition Setup page). It checks everything in the table below, lets you fix it in
place, and stays unfinished on Assisted Setup while anything that would stop every
job remains: no engine connection, no press marked for imposition, a marked press
without a gripper side, work style or PrintVis format, or no Standard Units. A
component type or finishing type that is not set up is a warning — it stops only
the jobs that use it.

| Where | What to fill in |
|---|---|
| Imposition Setup | Engine URL, editor URL, API key, defaults, and the default trims used when a job item states none |
| PVS Cost Center Card, **Imposition** section | One row per configuration: mark **Use for Imposition**, name the gripper edge side, state the work styles |
| Component Types card | **JDF Product Type** and **Imposition Grain Rule** |
| Finishing Types | **CIP4 Binding** and **CIP4 BindingSide** |

- **Paper** is the paper on the job's own sheets. Nothing is marked.
- **Trims** are taken from the job item, falling back to Imposition Setup's default
  trims, and are read in the installation's margin unit.
- **Lengths** are entered in the installation's own unit; captions show which.
- **First publish after this change** needs `"schemaUpdateMode": "ForceSync"` in
  `launch.json`, because four of the extension's tables were removed.

## Development

```bash
tools/build.sh        # compile both apps locally (~3s)
```

Tests are AL test codeunits in `PTE PrintVis External Imposition.Test`. They
cannot execute against a local compile, and they do not run in CI either.

**CI is a compile gate only.** AL-Go builds with `useCompilerFolder`, so it
compiles both apps against downloaded symbols and runs the analyzers, but does
not publish into a container. Publishing would require PrintVis and PrintVis
System Library to be installed there, and those are licensed ISV apps that
cannot be handed to a public repository's CI.

To execute the tests, use a sandbox where PrintVis is already installed:

```powershell
.AL-Go/cloudDevEnv.ps1     # create or refresh the online dev environment
```

then publish both apps to it and run the test codeunits from VS Code.

## Documents

- [Design](docs/superpowers/specs/2026-09-21-printvis-external-imposition-design.md)
- [Implementation plan](docs/superpowers/plans/2026-09-21-printvis-external-imposition.md)
- [Seed payload measurement](docs/seed-payload-measurement.md)
