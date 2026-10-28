# Book Preview — design

**Date:** 2026-10-28
**Spans:** `com.printersequity.impositioning` (API + WebApp) and `PTE-PrintVis-External-Imposition` (BC extension).
**Source being ported:** `PageViewer` (React + three.js + `jdftool` wasm).

## 1. Intent

A planner wants to see the product an imposition describes — the folded, bound book — before
and after it is approved, as a flip-book they can page through. PageViewer already does this as a
standalone React app; this work brings its book view into the Impositioning WebApp (Vue) and
into Business Central/PrintVis, built on what PEQIStudio already produces.

The flip-book is a **read-only check of the imposition's structure**: page order, sections,
binding. It is not a prepress tool yet.

## 2. Goals

1. **Before approval, in the Studio:** once a layout is solved (not necessarily approved), the
   operator can open a flip-book preview of the current solution.
2. **After approval, from the Job:** a *Book Preview* action on the **Job Items** action bar of
   the PrintVis Job Card opens the flip-book for the job's approved imposition.
3. **JDF is the only input** to the flip-book, in both cases. One reader.
4. **No WebAssembly.** The JDF is parsed in the browser with the platform XML parser
   (`DOMParser`). `jdftool` is not a dependency.
5. The UI is **Vue 3**, living in the WebApp under its own directory.
6. **Placeholder pages:** each page shows its folio (page number) and its section.
7. A **Details** button opens a JDF info pane (technical data), ported from PageViewer's
   `JdfInfoPane`.

## 3. Non-goals (for now)

- PDFs: loading, placing or rendering artwork. Comes later; the model should leave room for it
  (a page has a position that content could later be assigned to) but nothing is built for it.
- XJDF. JDF only.
- PageViewer's other panes: PDF panel, RunList panel, assembly panel, product form, save/export,
  session manifest, entitlements, help panel.
- Editing anything. The flip-book never writes to the JDF, the request or BC.
- In-browser schema validation (that was jdftool's job). The API already validates every
  pipeline ticket before returning it (`JdfTicketValidator`).

## 4. Anti-goals (would make this a failure even if it works)

- The pre-approval preview showing something different from what approval will produce. This is
  why both paths read JDF from the same writer.
- A dry-run preview leaving tickets behind in storage, or changing the `X-Jdf-Ticket-Id`/ETag
  behaviour of a real `POST /jdf`.
- Breaking the existing v1 embed contract or the existing Studio/Approve flows. Outside the new
  route and messages, everything behaves exactly as today.
- Pulling wasm back in by the side door (a library that bundles libxml2, etc.).

## 5. Decisions made

### 5.1 Data flow — one reader, always JDF

```
Before approval (Studio, standalone or embedded)
  WebApp ──POST /api/imposition/jdf?dryRun=true (current request + solutionId)──▶ API
  WebApp ◀── JDF XML (not stored) ───────────────────────────────────────────────
  WebApp opens /book with that XML

After approval (BC Job Items → Book Preview)
  BC finds the latest Committed PEQI Imposition Job for (Case ID, Job, Version)
  BC reads its newest PEQI JDF Ticket.Jdf blob
  BC page frames the SPA (?embed=1) and posts the XML in a new seed message
  SPA opens /book with that XML
```

### 5.2 API — dry-run on `POST /jdf`

- New query flag `dryRun` (parsed like `inline`/`download`).
- With `dryRun=true` the endpoint does everything it does today — validation, solve, solution
  lookup, writing, `JdfTicketValidator` — **except** `_tickets.AddAsync`. No ticket row, no blob,
  no `X-Jdf-Ticket-Id` header.
- Response: the JDF XML inline (`JdfContentType`, 200), as `inline=true` returns today. ETag may
  still carry the SHA-256 of the XML (harmless, useful for caching).
- Errors are identical to a real call (400/404/409/500 with the same `ProblemDetails`).
- Tests: dry-run returns the same XML as a real call for the same body; dry-run stores nothing.

### 5.3 WebApp — the book viewer

- **Location:** `WebApp/src/bookview/` (own directory: reader, model, scene, components,
  tests). Route `/book` (`views/BookView.vue` or a view inside `bookview/` — builder's call).
- **New dependency:** `three` (+ `@types/three`). Pinned like the other deps.
- **Ported from PageViewer, translated to TS/Vue:**
  - `panes/vp3/book.ts` → pure pagination/spread logic (no three.js), kept testable.
  - `panes/vp3/bookScene.ts` → three.js scene; placeholder page textures drawn on a canvas
    (folio + section label) instead of PDF renders.
  - `panes/vp3/Visualizer.tsx` → `BookViewer.vue` (canvas host, navigation: first/prev/next/last,
    keyboard arrows, click-to-flip as PageViewer does).
  - `panes/vp2/JdfInfoPane.tsx` → `JdfInfoPane.vue`, opened by a **Details** button, shown as a
    side panel/overlay. Shows job-level facts (job ID, name, JDF version, binding, trim size,
    page count, parts, sections). PageViewer's validation-message list is dropped (no in-browser
    validation); if desired it can show "Validated by the Impositioning API" since only validated
    tickets reach the viewer.
- **JDF reader (`bookview/readJdf.ts`):** `DOMParser` with `application/xml`, namespace-aware
  lookups. Reject on `parsererror`. Reads only what the book needs:
  - page count, trim size (finished dimensions),
  - binding: `Collecting` → saddle-stitch, `Gathering` → perfect-bound (PageViewer's
    `BINDING_MAP`),
  - sections: the `Assembly` tree (`Order`, `AssemblySection/@AssemblyIDs`), the per-signature
    fold catalogs and `RunList/@NPage` per part, as the API's pipeline writer emits them
    (`Jdf/Modules/PrepressModule.cs`, `JdfAssembly.cs`),
  - parts (e.g. cover vs. text) where present, for the info pane.
  - **folios per section:** the pipeline JDF does not state them (only the Preps-template writer
    emits `SSi:StartPage`). The reader computes them by porting
    `AzureFunctionApp/Domain/Assembly/StartPageCalculator.cs` to TypeScript
    (`bookview/startPages.ts`): a nested section starts halfway through its parent, a sibling
    starts after the previous section's own pages (not everything it wraps), and a wrapping
    signature holds split pages (a 4pp cover round a 48pp block carries 1, 2, 51, 52).
    **Drift guard:** a set of shared golden fixtures (assembly tree in → start pages/folios out)
    generated from the C# calculator by a test in `Impositioning.Tests`, checked into the WebApp
    and asserted by a Vitest suite. Changing the C# rule without regenerating fails the build.
  It is written against the JDF **our API writes** (both JDF 1.4 and 1.5 profiles); it does not
  need to handle arbitrary third-party JDF. Fixtures: real dry-run output from the API for a
  saddle-stitched and a perfect-bound product, plus one multi-part (cover + text).
- **Model:** a small format-neutral `BookModel` (`pages[]` with folio, section id/label, part;
  `sections[]`; `binding`; `trimSize`) — the reader produces it, the scene consumes it.
  PDF content later attaches to `pages[]`.

### 5.4 WebApp — entry points

- **Studio, pre-approval:** a *Preview book* button where a solved solution is shown (the
  approve screen and the studio/layout toolbar — wherever a single solution is selected). It
  calls `/jdf?dryRun=true` with the same request + `solutionId` the approve path would send, then
  navigates to `/book` with the XML held in a small store (`bookStore`). The dry-run always uses
  the pipeline flavour (never `PrepsTemplate`), whatever the Studio's flavour setting.
  **Known difference, accepted:** embedded, BC adds `jobId`, `relatedJobId`, `projectId`,
  `customer` and the JDF version at approval; the SPA has none of them. Pages and sections are
  unaffected. In a dry-run preview the Details pane labels job ID, customer, project and JDF
  version as *set at approval* rather than showing the dry-run's defaults. The existing
  `imposition:seed` is not changed. A *Back* control returns
  to where the operator came from. Works both standalone and embedded.
- **Embedded, post-approval:** a new seed message (see §5.5) puts the SPA directly on `/book`.
  In that session the viewer is the only screen: no back-to-editor, no settings.
- The embed route guard (`embed/routing.ts`) must allow `/book` in both `approve` and
  `advanced` modes, and must keep a book-only session on `/book`.

### 5.5 Embed contract — additions (v1 stays v1; additive)

New BC → SPA message:

| `type` | Payload |
|---|---|
| `book:seed` | `{ v: 1, jdf: string, options: { entryKey?: string, units?: DisplayUnits, theme?: string } }` |

- Handled by the same bridge and origin allowlist as `imposition:seed`. The SPA still posts
  `imposition:ready` first; BC holds the seed until it sees it (same rule).
- A `book:seed` puts the session in book-only mode and routes to `/book`. A second seed replaces
  the first.
- On a parse failure the SPA posts `imposition:error` with a message.
- No SPA → BC messages beyond `ready`/`error`; the viewer reports nothing back.
- Contract change is recorded in both `contract.ts` and the BC spec (§8/§16 of the 2026-09-21
  design).

### 5.6 BC extension

- **Action:** `pageextension` on `"PVS Job Items ListPart"` (source table `"PVS Job Item"`)
  adding *Book Preview* to its action bar (next to Job Signatures/Specification, as in the
  screenshot). Enabled when the job version has a Committed `PEQI Imposition Job` with a JDF
  ticket.
- **Which imposition:** the **latest Committed** `PEQI Imposition Job` for the job's
  (Case ID, Job, Version) — highest `Entry No.` with `Status = Committed` — and its newest
  `PEQI JDF Ticket` (by `Created At`/`Entry No.` link). Not tied to the selected job item.
- **Page:** a new page `PEQI Book Preview` hosting the existing `"PEQI Imposition Studio"`
  control add-in with a new procedure `LoadBook(SpaUrl: Text; JdfXml: Text; OptionsJson: Text)`.
  `PEQIStudio.js` gains a `loadBook` path that frames `SpaUrl` with `?embed=1` and posts
  `book:seed` on `imposition:ready`. Reuses `Setup."Spa Url"`, the same origin checks, and the
  existing `EditorFailed` event for errors.
- No new tables or fields. Permission sets get the new page.
- Tests in the `.Test` app: action enablement (no committed entry → disabled), selection of the
  latest committed entry and its newest ticket.

## 6. Constraints

- Outside embed mode and outside `/book`, the WebApp behaves exactly as today.
- Embed origin allowlist and `frame-ancestors` CSP apply unchanged to the book view.
- The flip-book must render inside a BC control add-in frame (resizable; respect the add-in's
  min sizes) — WebGL must be available; if it isn't, show a clear message rather than a blank
  frame.
- Lengths on the wire stay in millimetres; `units` is display only (as in the existing contract).
- Large JDFs: the stored ticket is passed as text through AL → JS → postMessage, as the request
  JSON already is.

## 7. Left to the builder

- Exact styling/layout of the viewer and info pane (follow the WebApp's Tailwind tokens and the
  `bc` theme when embedded).
- Exact placement of *Preview book* in the Studio UI.
- How much of PageViewer's printer-spread ("as printed") mode to bring; the reader-spread view is
  required, printer spreads are optional.
- Action image/caption wording in BC.
- Whether `bookStore` holds the XML or the parsed `BookModel`.

## 8. My calls (not discussed explicitly)

- Dry-run is a query flag on the existing endpoint, not a new route.
- `book:seed` is a new message type under v1 rather than a v2 or an option on `imposition:seed`.
- BC reuses the existing control add-in rather than adding a second one.
- Directory name `src/bookview/`, route `/book`, BC action caption *Book Preview*.
- Browser-side validation is dropped; the API's validation is trusted.
- Dry-run always uses the pipeline flavour.
- TS port of `StartPageCalculator` lives in `bookview/startPages.ts`; golden fixtures generated
  from the C# side.

## 9. Decided with the user after review

- Folios: computed in the reader by porting `StartPageCalculator` (not written into the JDF).
- Pre-approval Details pane: job ID / customer / project / JDF version shown as *set at
  approval*; no change to `imposition:seed`, no SPA → BC dry-run round trip.
