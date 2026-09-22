# PTE PrintVis External Imposition

Solves a PrintVis job's imposition with the external Impositioning engine, lets a
planner choose a layout in the engine's own editor embedded in Business Central,
and writes the CIP4 JDF ticket for that choice.

## How it works

1. **Solve Imposition** on a PrintVis job builds a self-contained
   `CalculateRequest` — the product from the job's components, and the paper and
   presses from PrintVis's own masters, sent inline. Nothing is registered with
   the engine.
2. The Impositioning editor opens in a frame on the imposition card, seeded with
   that request. The planner picks a layout.
3. **Generate JDF** posts the chosen solution to the engine and stores the
   ticket on the job.

Nothing is written back to the PrintVis calculation. The one exception is the
sheet preview image, written to `PVS Job Sheet Imposition` when the plan's press
runs line up one-to-one with the job's PrintVis sheets.

## Setup

| Page | What to fill in |
|---|---|
| Imposition Setup | Engine URL, editor URL, API key, defaults |
| Imposition Press Setup | One row per press configuration: mark it, name the gripper edge, state the work styles |
| Imposition Paper Setup | Mark each paper to be considered; fill grain and caliper where PrintVis is silent |
| Imposition Binding Mappings | PrintVis finishing code → binding |
| Imposition Part Mappings | PrintVis component type → part product type |

## Development

```bash
tools/build.sh        # compile both apps locally (~3s)
```

Tests are AL test codeunits in `PTE PrintVis External Imposition.Test` and run in
CI or a container — they cannot execute against a local compile.

## Documents

- [Design](docs/superpowers/specs/2026-09-21-printvis-external-imposition-design.md)
- [Implementation plan](docs/superpowers/plans/2026-09-21-printvis-external-imposition.md)
- [Seed payload measurement](docs/seed-payload-measurement.md)
