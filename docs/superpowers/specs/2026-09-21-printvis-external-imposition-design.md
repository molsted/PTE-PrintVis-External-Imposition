# PTE PrintVis External Imposition — Design

**Date:** 2026-09-21
**Status:** Approved for planning
**Repo:** `PTE-PrintVis-External-Imposition`
**Companion repo:** `ImpositioningApp` (Azure Functions API + Vue SPA)

---

## 1. Purpose

Let a PrintVis planner solve a job's imposition with the external Impositioning
engine, choose a layout in the engine's own editor without leaving Business
Central, and produce a CIP4 JDF ticket from the chosen layout.

The pattern is **quote then commit**: `/calculate` while the operator is
deciding, `/jdf` once they have decided, with the chosen `solutionId` carried
between the two.

## 2. Context

| System | Role |
|---|---|
| **PrintVis** (BC 28, PrintVis A/S 28.0.0.2) | Owns the case, the job, the components, the paper and the presses |
| **This extension** (AL PTE, ids 50500–50600) | Builds the request, talks to the engine, hosts the editor, stores the plan and the ticket |
| **Impositioning API** (Azure Functions, `/api/imposition/…`) | Solves the imposition, writes the JDF |
| **Impositioning Editor** (Vue 3 SPA) | The operator's editor, embedded in BC in an iframe |

## 3. Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Quote then commit (API guide Pattern B) | The operator picks the layout; the ticket is written from that pick |
| D2 | Unit of work is the **job version** — `PVS Job` (`ID`, `Job`, `Version`) and its job items | A case holds several jobs, each with versions and alternatives; solving "the case" would mix quote alternatives |
| D3 | Self-contained requests — `sheets[]` and `presses[]` pushed inline on every call | PrintVis owns both masters. No catalogue registration, no sync job, no inbound access to BC, and the ids stay PrintVis's own |
| D4 | Nothing is written back to the PrintVis calculation | The engine's plan does not disturb any figure PrintVis costs from |
| D5 | Except the sheet preview image, best-effort (see §9.3) | `PVS Job Sheet Imposition` is a picture PrintVis already renders; it makes the plan visible where planners look |
| D6 | The Vue SPA is embedded as a control add-in | The canvas, funnel and fold-pattern editor are not worth rebuilding in AL |
| D7 | BC posts `/jdf` and stores the XML | BC owns the artifact and can re-send it |
| D8 | BC owns the conversation; the add-in is a seeded editor (Approach A) | Outbound HTTP only, no BC API surface; the request exists in BC whether or not the add-in loads |
| D9 | Engine-specific press attributes live in setup tables in this app | PrintVis measures a gripper but does not name its edge, and knows nothing of plate punch or max image area |

## 4. Architecture

```
Business Central ── PTE PrintVis External Imposition ──┐
  PVS Case / PVS Job card                              │ outbound HTTPS
   └─ "External Imposition" action                     │
        ├─ Request Builder    job + items + setup      │
        │                     → CalculateRequest JSON  │
        ├─ Engine Client      POST /calculate          ├──▶ Impositioning API
        │                     POST /jdf, GET /jdf/{id} │
        ├─ Imposition Job pg  hosts control add-in ────┼──▶ Vue SPA in iframe
        │                       seed ▼   ▲ chosen      │    (solves via /calculate
        └─ Storage            job, runs, ticket,       │     from the browser)
                              diagnostics
```

### 4.1 Unit boundaries

| Unit | Does | Must not |
|---|---|---|
| **Request Builder** | `PVS Job` + setup → `CalculateRequest` JSON | Touch HTTP |
| **Engine Client** | HTTP, auth, retry, RFC 7807 parsing | Read a PrintVis table |
| **Commit Manager** | Orchestrates: store choice → post `/jdf` → store ticket → attempt preview | Build JSON or issue HTTP itself |
| **Preview Writer** | Writes `PVS Job Sheet Imposition` under the §9.3 guard | Create `PVS Job Sheet` rows |

The builder/client seam is load-bearing: it makes the mapping testable without a
server and the client testable without PrintVis data.

## 5. Data model

All tables prefixed `PEQI`. Setup and mapping tables are configuration; document
tables are per solve.

### 5.1 `PEQI Imposition Setup` (50500) — singleton

Engine base URL; SPA URL; HTTP timeout; retry count; default grain policy; default
max solutions; default JDF version and flavour; default trim margins; JobID format
string; `Thickness Unit` and `Weight Unit` conversion settings; `Enabled`.

The API key is **not** a field. It lives in isolated storage, written through the
setup page and never read back into the UI.

### 5.2 `PEQI Press Setup` (50501) — key: `Cost Center Code`, `Configuration`

Annotates `PVS Cost Center Configuration`. Holds **only what PrintVis lacks**:

`Use for Imposition`; `Press Id` (GUID, generated once, never regenerated);
`Gripper Edge Side` (*which* physical edge — PrintVis's `Gripper Edge` is a
measurement and never names the edge it applies to); the four
`Non-Printable Margin` values where `Gripper Edge`, `Pull` and
`Strip` do not cover them; `Max Image Area Width`/`Height`; `Plate Punch`;
`Sheets Per Hour`; five work-style booleans (`Simplex`, `Work And Back`,
`Work And Turn`, `Work And Tumble`, `Perfecting`); `Press Type Override`.

Read live from PrintVis and never copied: `Max`/`Min Printing Format Length` and
`Width`, `Gripper Edge` (the measurement), `Pull`, `Pull Side`, `Strip`,
`Max No. Of Colors`, `Perfection Printing`, `Plate No.`, `Plate Length`,
`Plate Width`, `Min Weight`, `Max Weight`.

**`Press Id` must be stable.** The `solutionId` returned by `/calculate` is a hash
that includes the press id, and `/jdf` re-solves and looks that id up. A fresh
GUID per call makes every quoted solution stale on arrival.

### 5.3 `PEQI Paper Setup` (50502) — key: `Item No.`, `Variant Code`

`Use for Imposition`; `Substrate Id` (auto-numbered integer surrogate, assigned
once, never reused); blank-field overrides for grain, caliper and grammage.

Read live from the BC Item: `PVS Format 1`/`2` (dimensions), `PVS Weight` +
`PVS Weight Unit` (grammage), `PVS Thickness` (caliper), `PVS Grain Direction`
(`1>2` = Short, `1<2` = Long, blank = not recorded).

**`Substrate Id` exists because the engine types `sheets[].id` as `int` and BC
item numbers are `Code[20]`.** It is what a part selects on, what the response
reports and what diagnostics name, so it must survive for the life of the item.

Omitting grain makes every grain verdict `Unverified`, and under
`grainPolicy: Required` eliminates the sheet. Omitting caliper yields no creep and
no spine thickness. Both matter for the saddle-stitched and perfect-bound work
this is for, so the setup page surfaces them as warnings rather than leaving them
blank in silence.

### 5.4 `PEQI Binding Mapping` (50503) — key: `Finishing Code`

Maps `PVS Job`.`Finishing` to the engine's `binding` enum, plus the default
product type and the default trim/milling values for that binding.

### 5.5 `PEQI Part Mapping` (50504) — key: `Component Type`

Maps `PVS Job Item`.`Component Type` to the engine's part `productType` and a
default `grainRule`.

§5.4 and §5.5 are data rather than code because an unmapped code must be an
error naming the code, not a silent default.

### 5.6 `PEQI Imposition Job` (50505) — key: `Case ID`, `Job`, `Version`, `Entry No.`

`Status` (`Draft` / `Solved` / `Committed` / `Failed`); `Request JSON` (blob);
`Snapshot Id`; `Solution Id`; solution summary (`Sheet Count`,
`Total Signatures`, `Utilisation`, `Wasted Area`, `Worst Grain Verdict`, `Score`,
`Runnable`); `Built At`; `Built By`; `Last Error`.

**`Entry No.` rather than one row per job** — a product changes and is re-solved,
and a committed ticket must keep pointing at the request it was written from.
Re-solving opens a new entry; the previous entry and its ticket stay intact.

### 5.7 `PEQI Press Run` (50506) — key: parent + `Line No.`

One row per `runs[]` in the chosen solution: stock name and `Substrate Id`, press
name and id, work style, sheet count, passes, signature ids, and the
`PVS Job Sheet`.`Sheet ID` it corresponds to by ordinal (blank when the counts
disagree — see §9.3).

This is the readable record of the plan inside BC, since nothing is written back
to the calculation.

### 5.8 `PEQI JDF Ticket` (50507) — key: `Ticket Id` (GUID)

`Case ID`, `Job`, `Version`, `Entry No.`, `Job Id` sent, `Solution Id`, `Flavour`,
`JDF Version`, `File Name`, `SHA256`, `Created At`, `JDF` (blob).

Separate table because a job can be re-ticketed.

### 5.9 `PEQI Diagnostic` (50508) — key: parent + `Line No.`

`Severity`, `Code`, `Count`, `Example Message`, `Source` (engine / builder /
preview). Includes the ones a self-contained request always raises, such as
`IMPOSITION_RULES_NOT_APPLIED`.

## 6. Request Builder

Input: one `PVS Job` (`ID`, `Job`, `Version`), `Active` and not `Archived`.
Output: a `CalculateRequest` JSON document. No HTTP, no persisted state.

### 6.1 Parts

**One engine part per `Component Type`, not per `PVS Job Item`.** PrintVis job
items are already split across sheets (each carries a `Sheet ID`); feeding that
split to the engine would ask it to confirm its own input, when deciding the
sheet breakdown is the reason for the call. Job items are grouped by component
type and `No. Of Pages` summed.

| Engine field | Source |
|---|---|
| `name` | `Component Type` + description |
| `productType` | `PEQI Part Mapping` |
| `pageCount` | Σ `No. Of Pages` |
| `trimWidthMm` | Job item `Width` |
| `trimHeightMm` | Job item `Length` (Length is the height) |
| `frontColors` / `backColors` | `Colors Front` / `Colors Back` |
| `grainRule` | `PEQI Part Mapping` default |
| `catalog.substrateIds` | `PEQI Paper Setup`.`Substrate Id` for the job item's `Item No.` |
| `trimHeadMm` / `FootMm` / `FaceMm` / `SpineMm`, `millingDepthMm` | `PEQI Binding Mapping`, falling back to Setup defaults |

A component spanning two trim formats is an invariant violation in PrintVis, not
a case to reconcile; the builder asserts it and fails naming both job items.

### 6.2 Job level

`binding` ← `PEQI Binding Mapping` on `PVS Job`.`Finishing`.
`bindingSide` ← `PVS Imposition Code`.`Spine Side`.
`amount` ← `PVS Job`.`Quantity`.
`maxSolutions`, `grainPolicy`, `rotations`, `allowedWorkStyles` ← Setup defaults,
intersected with the work styles the sent presses declare.

### 6.3 Catalogue halves

`sheets[]` — every `PEQI Paper Setup` row marked `Use for Imposition`, joined to
its BC Item for dimensions, grammage, caliper and grain.

`presses[]` — every `PEQI Press Setup` row marked `Use for Imposition`, joined to
its `PVS Cost Center Configuration`.

Because a stated half **replaces** its catalogue rather than joining it, the
matching `catalog` filters are refused by the engine. The builder omits them by
construction rather than discovering this as a 400.

### 6.4 Fold patterns

`foldPatterns[]` — the distinct `Folding Catalog Code (CIP4)` values from
`PVS Imposition Code`. Without this the request inherits whatever the host has
marked, and two hosts answer the same body differently.

### 6.5 Imposition rules

`impositionRules` is **omitted in v1**. The engine then centres each signature in
its share and returns `IMPOSITION_RULES_NOT_APPLIED`, which is stored as a
diagnostic rather than suppressed. Those rules are measurements of a specific
building; synthesising them from `Cutting Distance` would move geometry by a
number nobody measured.

### 6.6 Validation before serialising

Each failure names the PrintVis record an operator must go and fix:

- `Finishing` code with no `PEQI Binding Mapping`
- `Component Type` with no `PEQI Part Mapping`
- odd `pageCount` on a folded part
- paper marked for imposition with no `PVS Format 1`/`2`
- press marked for imposition with no max printing format
- job item whose `Item No.` has no `PEQI Paper Setup` row

A 400 from the engine keyed on `parts[1].pageCount` means nothing to a planner.

## 7. Engine Client

`interface PEQI IEngine Transport` with two implementations: `PEQI Http
Transport` (production, `HttpClient`) and a test double in the test app.
Interfaces carry no object id.

Operations: `POST /imposition/calculate`, `POST /imposition/jdf`,
`GET /imposition/jdf/{id}`.

The client knows the base URL, the auth header, the timeout and the retry policy.
It parses RFC 7807 `ProblemDetails` including the `errors` member and the
`diagnostics` extension. It does not know what a case is.

## 8. Embedded editor

A `controladdin` whose startup script creates a nested iframe to the Setup's SPA
URL with `?embed=1`, and relays messages to AL with
`InvokeExtensibilityMethod`.

```
AL ──Seed(requestJson, optionsJson)──▶ add-in JS
                                         │ postMessage
                                         ▼
                                    SPA (?embed=1)
                                         │ postMessage
                                         ▼
AL ◀──OnSolutionChosen(resultJson)── add-in JS
```

### 8.1 Message contract (version 1)

Host → SPA:

| Message | Payload |
|---|---|
| `imposition:seed` | `{ v: 1, request: <CalculateRequest>, options: { readonlyProduct: true, startRoute: "layout" } }` |

SPA → host:

| Message | Payload |
|---|---|
| `imposition:ready` | `{ v: 1 }` |
| `imposition:chosen` | `{ v: 1, solutionId, request: <effective CalculateRequest>, summary, diagnostics }` |
| `imposition:preview` | `{ v: 1, ordinal, side: "Front" \| "Back", widthPx, heightPx, png: <base64> }` |
| `imposition:error` | `{ v: 1, message }` |

**The full solution does not cross the bridge.** `POST /jdf` returns the complete
`solution` in its envelope, so BC gets the fat object from the source of truth on
a call it makes anyway; a second copy over the bridge could diverge from it.

### 8.2 Origin checks

The add-in validates `event.origin` against the configured SPA URL. The SPA
validates its parent against an allowlist. Without the second check any page
could frame the editor and seed it.

### 8.3 Seed size

The seed carries the whole inline catalogue. **The first implementation task is
to measure a real seed payload** for a representative shop before anything is
built on the assumption that it fits in a control add-in argument. If it does
not, the remedy is a chunked seed, not a change of approach.

### 8.4 Degraded mode

If the add-in does not load, the page shows the stored request, its validation
state, and a link that opens the SPA in a browser tab. It does not present an
unsolved job as solved.

## 9. Commit

### 9.1 Storing the choice

Building the request creates the entry with status `Draft`. `OnSolutionChosen`
then writes the effective request, `solutionId`, summary and diagnostics to that
`PEQI Imposition Job` (status `Solved`) and creates the
`PEQI Press Run` lines.

### 9.2 Writing the ticket

A separate **Generate JDF** action posts `/jdf` with the stored effective request
plus the chosen `solutionId`, `jobId`, `jobPartId`, `descriptiveName`, `amount`,
and the Setup's `version` and `flavour`. Response `ticketId`, `sha256`,
`fileName` and XML are stored in `PEQI JDF Ticket`; status becomes `Committed`.

Because both catalogue halves are stated inline, the snapshot is a hash of the
rows sent and nothing can move between the two calls — the quoted `solutionId`
cannot go stale.

`jobId` (JDF `@JobID`, 1–64 chars) defaults to `<ID>-<Job>-<Version>` and is
Setup-configurable via a format string.

### 9.3 Sheet preview — best effort, with a guard

The image can only come from the SPA's canvas: the engine has no rendering
endpoint and AL cannot draw. The SPA sends one `imposition:preview` per sheet
after `imposition:chosen`.

`PVS Job Sheet Imposition` is keyed on PrintVis's `Sheet ID`. **Previews are
written by ordinal only when the engine's run count equals the job's
`PVS Job Sheet` count.** When the counts differ there is no key for the surplus
run, and creating `PVS Job Sheet` rows would be write-back to the calculation,
which D4 excludes. In that case no preview is written and a `PREVIEW_NOT_WRITTEN`
diagnostic records why.

A picture of a four-sheet plan filed against three sheets is worse than no
picture.

## 10. Error handling

| Status | Handling |
|---|---|
| `400` | Parse `ProblemDetails` + `errors`; re-key each message onto the PrintVis record it came from |
| `404` on `/jdf` | Stale `solutionId` — re-solve. Should not arise with both halves inline; the handler exists regardless |
| `409` | No imposition fits. Surface the `diagnostics` extension, which is what explains why |
| `429`, `500` | Exponential backoff, capped by the Setup retry count |
| timeout | A failed job with `Last Error` set — never a silent empty result |

## 11. Security and configuration

- The API key lives in isolated storage, write-only from the setup page, sent
  server-to-server by the Engine Client.
- **Open deployment decision:** the SPA runs in the operator's browser and cannot
  hold a secret, so whatever guards the engine must also admit a browser. Entra
  SSO at the gateway is the clean answer; a function key in a frontend is not,
  and the engine's triggers are currently `Anonymous`. This changes no code in
  this design but must be settled before any non-lab exposure.
- The SPA's host must permit framing from Business Central
  (`Content-Security-Policy: frame-ancestors`), and only from Business Central.

## 12. Testing

| Test | Covers |
|---|---|
| Request Builder golden files | Fixture `PVS Job` + items + setup → committed JSON. Catches mapping regressions, which is where this kind of integration rots |
| Builder validation | Each §6.6 failure, asserting the message names its record |
| Client against the test transport | 200 / 400 / 409 / 429 / 500, retry behaviour, `ProblemDetails` parsing |
| Commit | `Solved` → `Committed`; ticket stored; re-solve opens a new `Entry No.` and leaves the previous ticket intact |
| Preview guard | Run count ≠ sheet count skips and diagnoses instead of writing by ordinal |
| Contract smoke | The integration guide's sample payload against a dev instance. Manual, not CI |

## 13. Object inventory

`app.json` changes: `application` and `platform` to `28.0.0.0`; `runtime` to `17.0`,
adjusted only if the AL compiler in the AL-Go pipeline rejects it; dependencies on
PrintVis (`5452f323-059e-499a-9753-5d2c07eef904`, 28.0.0.0), PrintVis System
Library (`a1775e0b-ae52-43ed-9eb9-8e23a6214831`, 28.0.0.0) and Printer's Equity
Library (`63bb5701-ecc7-4a35-b851-0593b74d74e2`, 25.0.0.0).

| Ids | Objects |
|---|---|
| 50500–50508 | Tables (§5) |
| 50510–50521 | Pages: setup card, press setup list + card, paper setup list, binding mapping, part mapping, imposition job list + card (hosts the add-in), press run part, diagnostics part, ticket list, case factbox |
| 50530–50531 | Page extensions: `PVS Case` card, `PVS Job` card — the **External Imposition** action |
| 50540–50548 | Codeunits: Request Builder, Engine Client, Http Transport, Json Helper, Response Reader, Commit Manager, Preview Writer, Install, Upgrade |
| 50550–50562 | Enums: job status, press type, sheet grain, press edge, work style, binding type, binding side, part product type, grain rule, grain policy, JDF flavour, JDF version, diagnostic severity |
| 50580–50581 | Permission sets |
| — | `interface PEQI IEngine Transport` and `controladdin` carry no object id |

Source layout follows house style: `src/<Area>/<Name>.<ObjectType>.al`, with the
Printers Equity copyright header on every file.

## 14. Out of scope for v1

- Headless auto-solve (no operator). The Engine Client supports it; no action
  exposes it.
- `impositionRules` (§6.5).
- Writing `External Imposition Template` / `External Imposition Name` on
  `PVS Imposition Code`.
- Any write-back to the PrintVis calculation (D4).
- `/evaluate` continuous validation during order entry.
- Importing Preps `.job` files.

## 15. Open items to resolve during planning

Each has a default so planning is not blocked:

1. **`PVS Thickness` unit** — microns or millimetres. Default: treat as
   millimetres and convert, with the unit configurable in Setup.
2. **`PVS Job Sheet Imposition`.`Picture` format** — what PrintVis renders.
   Default: PNG; verify against an existing record before writing one.
3. **`jobId` convention** — whether these tickets must correlate with PrintVis
   CIM's. Default: `<ID>-<Job>-<Version>`, Setup-configurable.
4. **Seed payload size** (§8.3) — measure before building.
5. **Browser-side auth** (§11) — a deployment decision, not a code one.
6. **`runtime` value** for BC 28 in AL-Go. Default: `17.0`, corrected on the
   first pipeline run if the compiler rejects it.

## 16. Companion spec

The WebApp changes are specified separately in `ImpositioningApp`:

- `?embed=1` mode routing past `ProductView` with the product frozen
- hydrating `productStore` / `editorStore` from the seed
- emitting `imposition:chosen` at Approve instead of writing a ticket
- emitting `imposition:preview` per sheet
- parent-origin allowlist and `frame-ancestors`
- hiding tenant and plant settings, which are meaningless with an inline catalogue

The §8.1 message contract is the interface between the two specs and the only
thing both sides must agree on.
