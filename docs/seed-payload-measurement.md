# Seed payload measurement

Spec §8.3. To be taken before the control add-in (Task 15) is built.

## Status: NOT YET TAKEN — this gate is open

The instrument exists: **Measure Request Size** on the Imposition Job card
(`page 50517 "PEQI Imposition Job Card"`). Taking the reading needs a Business
Central sandbox with a representative catalogue, which the local compile gate
cannot provide.

## How to take it

1. Deploy the extension to a sandbox with a representative catalogue — every
   paper and press a real shop would mark `Use for Imposition`. A catalogue of
   two rows proves nothing; the whole point is the size a real shop produces.
2. Open a real job's **PVS Job Card** → **External Imposition** → **Solve Imposition**.
3. On the Imposition Job card, run **Measure Request Size**.
4. Fill the table below and set the verdict.

| Measured | Value |
|---|---|
| Date | *(not taken)* |
| Environment | *(not taken)* |
| Marked paper rows | *(not taken)* |
| Marked press rows | *(not taken)* |
| Request size | *(not taken)* |

**Verdict:** *(pending)* — fits in one add-in argument / needs a chunked seed

## If a chunked seed is needed

The add-in's `Seed` procedure takes the request in numbered slices and the
JavaScript reassembles before posting to the frame. The §8.1 message contract is
unchanged; only the host-to-add-in call is.

## Why this blocks Task 15

The add-in is built on the assumption that the whole inline catalogue fits in a
single control add-in argument. Discovering otherwise after the add-in is
written is a rewrite of the host-to-add-in call, not a tweak — which is why the
spec puts this measurement first.
