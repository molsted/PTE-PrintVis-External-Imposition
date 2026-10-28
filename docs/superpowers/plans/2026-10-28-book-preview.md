# Book Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A flip-book preview of an imposition's bound product — placeholder pages with folio and section — reachable from the Studio before approval and from the PrintVis Job Items bar after approval.

**Architecture:** The flip-book reads only JDF. Before approval the WebApp gets JDF from `POST /jdf?dryRun=true` (nothing stored); after approval BC sends the stored `PEQI JDF Ticket` to the framed SPA in a new `book:seed` message. The JDF is parsed with `DOMParser` (no wasm) into a `BookModel`; folios are computed by a TypeScript port of the API's `StartPageCalculator`, pinned to the C# rule by generated fixtures. PageViewer's three.js book scene is ported to Vue.

**Tech Stack:** .NET 10 / Azure Functions / xUnit (API); Vue 3.5, TypeScript 5.8, Pinia, Vite 6, Vitest 3 + jsdom, Tailwind 4, three.js (WebApp); AL / BC 28, PrintVis 28 (extension).

**Spec:** `docs/superpowers/specs/2026-10-28-book-preview-design.md` (this repo).

**Repos and paths used below:**
- `IMP` = `/Users/molsted/Projects/Printers Equity/com.printersequity.impositioning`
- `BC` = `/Users/molsted/Projects/Printers Equity/PTE-PrintVis-External-Imposition`
- `PV` = `/Users/molsted/Projects/Printers Equity/PageViewer` (read-only source of the port)

**Branches:** `feat/book-preview` in both `IMP` and `BC`. `BC` has unrelated uncommitted work on `main` (setup tables/pages, `launch.json`) — never `git add -A`; stage only the files a task names.

## Global Constraints

- JDF only; no XJDF. No WebAssembly and no `jdftool` dependency anywhere in the WebApp.
- Outside embed mode and outside `/book`, the WebApp behaves exactly as today; `imposition:seed` is unchanged.
- A dry-run never calls `_tickets.AddAsync`, never sets `X-Jdf-Ticket-Id`; a non-dry-run call is byte-for-byte unchanged (golden tests keep passing).
- Dry-run always uses `flavour: 'Stripping'` (the pipeline), never `PrepsTemplate`.
- Lengths on the wire are millimetres; JDF dimensions are points (`mm = pt × 25.4 / 72`). `units` is display only.
- Embed messages carry `v: 1`; anything else is ignored. Never `postMessage(..., '*')`.
- Pre-approval Details pane shows Job ID, Customer, Project and JDF version as *set at approval*.
- BC "approved" = `PEQI Imposition Job.Status = Committed`; the latest such entry for (Case ID, Job, Version), and its newest `PEQI JDF Ticket` (by `Created At`).
- BC object IDs: page `50527` "PEQI Book Preview", pageextension `50532` "PEQI Job Items ListPart", codeunit `50552` "PEQI Book Preview Mgt."; test codeunit `50625` "PEQI Book Preview Tests".
- New WebApp code lives under `WebApp/src/bookview/`; route `/book`; BC action caption *Book Preview*.

## Review Focus

1. **A ticket whose signature has no usable `FoldCatalog`** (missing ref, or not `F<n>-<m>`) → the viewer shows "Signature '<id>' has no page count" and no book, never a silently short book. Test in Task 4.
2. **A two-page cover (`F2-1`) wrapping the block** (`cover-spread` golden: 2pp round 3×16pp) → cover folios `[1, 50]`, block 2–49, 50 pages. Test in Task 3/4.
3. **A dry-run whose `solutionId` the API no longer produces (404) or nothing fits (409)** → Studio shows the API's detail next to *Preview book* and stays put; `/book` is never opened empty. Test in Task 7.
4. **A `book:seed` from a non-allowlisted origin, with `jdf` not a string, or `v ≠ 1`** → ignored; and an `imposition:seed` carrying `mode: 'book'` still reads as `approve`. Test in Task 8.
5. **A job with a Committed entry followed by a newer Draft entry, or a Committed entry without a ticket** → *Book Preview* uses the Committed one; with no ticket anywhere the action is disabled. Test in Task 10.

---

### Task 1: `dryRun` on `POST /jdf` (IMP)

**Files:**
- Modify: `IMP/AzureFunctionApp/Functions/JdfFunction.cs` (`Post`, around the `_tickets.AddAsync` block and the response branches; update the `<returns>`/`<remarks>` docs)
- Test: `IMP/Impositioning.Tests/JdfEndpointTests.cs`
- Modify: `IMP/README.md` or the API doc that lists `/jdf` query flags (whichever documents `inline`/`download`)

**Interfaces:**
- Produces: `POST /api/imposition/jdf?dryRun=true` → 200, `Content-Type` = `JdfContentType`, body = JDF XML; ETag = `"<sha256>"`; no `X-Jdf-Ticket-Id`. Errors identical to a real call.

- [ ] **Step 1: Write the failing tests** in `JdfEndpointTests.cs`, using the existing `Body(...)`, `JdfEndpoint.PostAsync`, `InMemoryJdfTicketStore`:

```csharp
[Fact]
public async Task ADryRunReturnsTheTicketXmlAndStoresNothing()
{
    var store = new InMemoryJdfTicketStore();
    var function = JdfEndpoint.Create(store);

    var result = await JdfEndpoint.PostAsync(Golden.Fixture("saddle-stitch"), "?dryRun=true", function);

    var content = Assert.IsType<ContentResult>(result);
    Assert.Equal(Golden.Read("saddle-stitch"), content.Content);
    Assert.Empty(store.Stored);
}

[Fact]
public async Task ADryRunSetsNoTicketIdHeader() { /* inspect HttpContext response headers: no X-Jdf-Ticket-Id */ }

[Fact]
public async Task ADryRunIsRefusedExactlyAsARealCallIs() // body with an unknown solutionId → NotFoundObjectResult, same Detail as without dryRun; store empty
```

(`PostAsync` creates its own `DefaultHttpContext`; to read headers, add an overload or out-param to `JdfEndpoint.PostAsync` that exposes the context — keep existing callers unchanged.)

- [ ] **Step 2: Run** `cd IMP && dotnet test --filter "FullyQualifiedName~JdfEndpointTests"` — expect the three new tests FAIL (ticket stored / `OkObjectResult`).

- [ ] **Step 3: Implement** in `Post`: `bool.TryParse(req.Query["dryRun"], out var dryRun);`. After validation of the XML and computing `sha`, when `dryRun` set the ETag and return the same `ContentResult` the `inline` branch returns, before `_tickets.AddAsync`. Force nothing else: flavour comes from the body (the WebApp sends `Stripping`).

- [ ] **Step 4: Run** `dotnet test` (whole suite) — all pass, including `GoldenTicketTests`.

- [ ] **Step 5: Commit**

```bash
git add AzureFunctionApp/Functions/JdfFunction.cs Impositioning.Tests/JdfEndpointTests.cs Impositioning.Tests/Support/JdfEndpoint.cs README.md
git commit -m "feat: /jdf?dryRun=true returns the ticket without storing it"
```

---

### Task 2: Start-page fixtures for the WebApp, generated from C# (IMP)

**Files:**
- Create: `IMP/Impositioning.Tests/BookViewFixtureTests.cs`
- Create (generated, committed): `IMP/WebApp/src/bookview/fixtures/start-pages.json`
- Create (copied, committed): `IMP/WebApp/src/bookview/fixtures/{saddle-stitch,perfect-bound,cover-spread,split-part}.jdf`

**Interfaces:**
- Produces `start-pages.json`:

```ts
type StartPageCase = {
  name: string;
  firstPage: number;
  sections: Array<{ signatureId: string; pages: number; children: /* same */ any[] }>;
  expected: Array<{ signatureId: string; startPage: number; pages: number; wrappedPages: number }>;
};
// file = StartPageCase[]
```

- [ ] **Step 1: Write the test class.** Two tests, both honouring `IMPOSITIONING_UPDATE_GOLDEN=1` (write instead of compare) exactly like `Golden.AssertMatches`, writing under `Golden.RepoRoot/WebApp/src/bookview/fixtures/`:
  - `TheWebAppStartPageCasesMatchTheCalculator`: builds `AssemblyPlan`s in code, runs `StartPageCalculator.Assign`, serialises to the shape above (camelCase, indented), compares with the file. Cases (signature ids/pages → expected start pages):
    - `saddle`: COVER 4 ⊃ T1 16 ⊃ T2 16 ⊃ T3 16 → 1, 3, 11, 19
    - `perfect`: COVER 4 ⊃ [T1, T2, T3, T4] 16 each → 1, 3, 19, 35, 51
    - `cover-2pp`: COVER 2 ⊃ T1 16 ⊃ T2 16 ⊃ T3 16 → 1, 2, 10, 18
    - `flat`: [A 16, B 8] (no cover) → 1, 17
    - `first-page-5`: `saddle` with `firstPage: 5` → 5, 7, 15, 23
  - `TheWebAppGoldenTicketsAreCurrent`: for each `Golden.Names`, the WebApp copy equals `Golden.Read(name)`.
- [ ] **Step 2: Run** `IMPOSITIONING_UPDATE_GOLDEN=1 dotnet test --filter BookViewFixtureTests` to generate, inspect `start-pages.json` by eye against the numbers above, then run without the variable — PASS.
- [ ] **Step 3: Commit** (`Impositioning.Tests/BookViewFixtureTests.cs`, `WebApp/src/bookview/fixtures/*`) — `test: generate book-view fixtures from the start-page calculator and golden tickets`.

---

### Task 3: `startPages.ts` — the calculator port and folio expansion (IMP/WebApp)

**Files:**
- Create: `IMP/WebApp/src/bookview/startPages.ts`
- Test: `IMP/WebApp/src/bookview/startPages.spec.ts`

**Interfaces:**
- Produces:

```ts
export interface SectionNode { signatureId: string; children: SectionNode[] }
export interface StartPageEntry { signatureId: string; startPage: number; pages: number; wrappedPages: number }
export class StartPageError extends Error { readonly signatureId: string }
export function assignStartPages(
  sections: SectionNode[], pagesBySignature: ReadonlyMap<string, number>, firstPage?: number,
): StartPageEntry[];                       // emission (depth-first) order; throws StartPageError on a missing/≤0 count
export function foliosOf(entry: StartPageEntry): number[];
// first half: startPage … startPage + pages/2 − 1; second half starts at startPage + pages/2 + wrappedPages
```

- [ ] **Step 1: Write failing tests:** (a) for every case in `fixtures/start-pages.json`, `assignStartPages(...)` deep-equals `expected`; (b) `foliosOf({startPage:1,pages:4,wrappedPages:48})` → `[1,2,51,52]`; `foliosOf({startPage:3,pages:16,wrappedPages:32})` → `[3..10, 43..50]`; `foliosOf({startPage:1,pages:2,wrappedPages:48})` → `[1,50]`; (c) a missing count throws `StartPageError` with that `signatureId`.
- [ ] **Step 2: Run** `cd IMP/WebApp && npx vitest run src/bookview/startPages.spec.ts` — FAIL (module missing).
- [ ] **Step 3: Implement** as a direct port of `StartPageCalculator.Walk/Extent`: nested children start at `cursor + pages / 2`; next sibling at `cursor + pages` (own pages, not the wrapped span). Keep a header comment pointing at the C# file and the fixture that pins them together.
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** — `feat(bookview): port the start-page rule and expand signatures to folios`.

---

### Task 4: `readJdf.ts` — JDF → `BookModel` (IMP/WebApp)

**Files:**
- Create: `IMP/WebApp/src/bookview/model.ts`, `IMP/WebApp/src/bookview/readJdf.ts`
- Test: `IMP/WebApp/src/bookview/readJdf.spec.ts`

**Interfaces:**
- Consumes: `assignStartPages`, `foliosOf`, `StartPageError` (Task 3).
- Produces (`model.ts`):

```ts
export type Binding = 'saddle-stitch' | 'perfect-bound';
export interface BookSection { signatureId: string; label: string; partName: string; folios: number[] }
export interface BookPage { folio: number; sectionId: string; sectionLabel: string; partName: string }
export interface JdfFacts {
  jobId: string; descriptiveName: string; jdfVersion: string;
  customerName: string | null; projectId: string | null; relatedJobId: string | null;
  parts: Array<{ name: string; productType: string | null; pages: number }>;
}
export interface BookModel {
  binding: Binding; bindingSide: string; trimMm: { width: number; height: number };
  pageCount: number; sections: BookSection[]; pages: BookPage[]; // pages sorted by folio, 1..pageCount
  facts: JdfFacts;
}
export class BookReadError extends Error {}
export function readJdf(xml: string): BookModel;   // throws BookReadError
```

- [ ] **Step 1: Write failing tests** against the four fixture `.jdf` files (read with `fs` in the spec):
  - `perfect-bound`: binding `perfect-bound`, `pageCount` 68, trim `{ width: 215.9, height: 279.4 }` (±0.01; `612×792 pt`), cover folios `[1,2,67,68]`, `TEXT 1` folios 3–18, `TEXT 4` 51–66; section labels `['COVER','TEXT 1','TEXT 2','TEXT 3','TEXT 4']`; `facts.jobId` `'GOLDEN'`, `jdfVersion` `'1.4'`.
  - `saddle-stitch`: binding `saddle-stitch`, `pageCount` 52, cover `[1,2,51,52]`, `TEXT 1` `[3..10, 43..50]`.
  - `cover-spread`: `pageCount` 50, cover folios `[1, 50]`, `TEXT 1` `[2..9, 42..49]`.
  - `split-part`: every folio 1..`pageCount` appears exactly once in `pages`.
  - Error cases: non-XML string → `BookReadError` "not a JDF ticket"; root not `JDF` → same; a copy of `perfect-bound` with `FoldCatalog="F16-6"` removed → `BookReadError` whose message contains `TEXT-01-F16-6-16pp` and "no page count"; no `Assembly` → `BookReadError` "no assembly".
- [ ] **Step 2: Run** `npx vitest run src/bookview/readJdf.spec.ts` — FAIL.
- [ ] **Step 3: Implement** with `new DOMParser().parseFromString(xml, 'application/xml')`; reject on a `parsererror` element. Use `getElementsByTagNameNS(JDF_NS, ...)` with `JDF_NS = 'http://www.CIP4.org/JDFSchema_1_1'`. Rules:
  - binding from `Assembly/@Order`: `Collecting`→saddle-stitch, `Gathering`→perfect-bound; `bindingSide` from `@BindingSide`.
  - section tree from nested `AssemblySection/@AssemblyIDs`.
  - pages per signature: each leaf `StrippingParams[@AssemblyIDs]` (split on whitespace) → its `BinderySignatureRef/@rRef` → `BinderySignature/@FoldCatalog` matching `^F(\d+)-\d+$` → `$1`. Never parse the signature id.
  - part name: `@DescriptiveName` of the nearest ancestor `JDF[@Type="Product"]` of that `StrippingParams`; label = part name, plus ` n` (1-based within the part, in assembly emission order) when the part has more than one signature.
  - trim: `Component[@ComponentType="FinalProduct"]/@Dimensions` (pt) → mm.
  - facts: root `@JobID`, `@DescriptiveName`, `@Version`, `@ProjectID`, `@RelatedJobID`; customer = first `CustomerInfo//Company/@OrganizationName`; parts from each Product node's `DescriptiveName`, `Component/@ProductType`, `RunList[@NPage]/@NPage`.
  - Wrap `StartPageError` into `BookReadError("Signature '<id>' has no page count, so the book cannot be paginated.")`.
- [ ] **Step 4: Run** — PASS. Also `npm run typecheck`.
- [ ] **Step 5: Commit** — `feat(bookview): read a JDF ticket into a book model without wasm`.

---

### Task 5: Spreads and navigation (port of PageViewer `book.ts`) (IMP/WebApp)

**Files:**
- Create: `IMP/WebApp/src/bookview/spreads.ts`
- Test: `IMP/WebApp/src/bookview/spreads.spec.ts`

**Interfaces:**
- Produces: `Spread` (as `PV/src/panes/vp3/book.ts`), `spreadsFor(pageCount): Spread[]`, `NavIntent`, `keyToIntent(key, ...)`, `clampSpread(index, total)`. Copy PageViewer's signatures; drop `printerSpreads`, `pageSourceFor`, `firstSpreadOf` (PDF/RunList-specific — spec §7 makes printer spreads optional; not built).

- [ ] **Step 1: Port PageViewer's existing tests for these functions** (`PV/test/vp3/book.test.ts`, only the cases for the functions kept) and add: `spreadsFor(52)` has 27 spreads, first `{left:null,right:1}`, last `{left:52,right:null}`; `spreadsFor(2)` → `[{null,1},{2,null}]`; `spreadsFor(0)` → `[]`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Port** the functions (pure TS, no three.js). **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** — `feat(bookview): reader spreads and keyboard navigation`.

---

### Task 6: The viewer — scene, `BookViewer.vue`, `JdfInfoPane.vue`, `/book` (IMP/WebApp)

**Files:**
- Modify: `IMP/WebApp/package.json` — add `three` and `@types/three` (same major as PageViewer: `^0.169.0`)
- Create: `IMP/WebApp/src/bookview/placeholder.ts` (canvas texture text), `bookScene.ts` (port of `PV/src/panes/vp3/bookScene.ts`), `BookViewer.vue` (port of `Visualizer.tsx`), `JdfInfoPane.vue` (port of `JdfInfoPane.tsx`), `BookView.vue`
- Create: `IMP/WebApp/src/stores/bookStore.ts`
- Modify: `IMP/WebApp/src/router.ts` — route `{ path: '/book', name: 'book', component: () => import('@/bookview/BookView.vue') }`
- Test: `IMP/WebApp/src/bookview/placeholder.spec.ts`, `IMP/WebApp/src/bookview/BookView.spec.ts`

**Interfaces:**
- Consumes: `readJdf`, `BookModel`, `BookReadError` (Task 4); `spreadsFor`, `keyToIntent`, `clampSpread` (Task 5).
- Produces:

```ts
// bookStore
export type BookSource = 'dry-run' | 'approved';
useBookStore(): {
  xml: Ref<string | null>; source: Ref<BookSource>; returnTo: Ref<string | null>;
  model: ComputedRef<BookModel | null>; error: ComputedRef<string | null>;   // from readJdf, BookReadError → message
  open(xml: string, source: BookSource, returnTo?: string | null): void; clear(): void;
}
// placeholder.ts
export function placeholderLines(page: BookPage | null): string[];  // [String(folio), sectionLabel] ; null → []
// bookScene.ts
export function createBookView(canvas: HTMLCanvasElement, model: BookModel): BookView; // BookView keeps PV's showSpread/flip/dispose shape, minus setJob's PDF args
export function webglAvailable(): boolean;
```

- [ ] **Step 1: Write failing tests:**
  - `placeholderLines({folio: 3, sectionLabel: 'TEXT 1', ...})` → `['3', 'TEXT 1']`.
  - `BookView.spec.ts` (mount with Pinia + router, mock `bookScene` module): with `bookStore.open(<perfect-bound fixture>, 'approved')` the header shows the descriptive name and "68 pages"; **Details** button toggles `JdfInfoPane`, which shows `Job ID: GOLDEN`, `JDF version: 1.4`, binding, trim in mm, parts, section list; with source `'dry-run'` the pane shows *set at approval* for Job ID, Customer, Project and JDF version; with an invalid XML the view shows the `BookReadError` message and no canvas; with `webglAvailable()` mocked `false` it shows "This browser cannot display the 3-D book (WebGL is unavailable)." and still offers Details; a **Back** button appears only when `returnTo` is set and navigates there.
- [ ] **Step 2: Run** `npx vitest run src/bookview` — FAIL.
- [ ] **Step 3: Implement.** Port `bookScene.ts` replacing `pageTexture`'s PDF path with a canvas drawn from `placeholderLines` (folio large, section label small; page aspect from `model.trimMm`). Drop `PageMode`/thumbnail and `pageCache`. `BookViewer.vue` owns the canvas, `ResizeObserver`, `createBookView` lifecycle (`onMounted`/`onBeforeUnmount` → `dispose`), first/prev/next/last buttons, arrow keys via `keyToIntent`. Style with the existing Tailwind classes and `bc` theme tokens; fill the frame (add-in min size 600×400).
- [ ] **Step 4: Run** tests + `npm run typecheck` + `npm run build` — PASS. Manually: `npm run dev`, in the console `useBookStore().open(<fixture xml>, 'approved')` then visit `/book`, flip through, open Details.
- [ ] **Step 5: Commit** — `feat(bookview): 3-D flip-book with placeholder pages and a JDF details pane`.

---

### Task 7: *Preview book* in the Studio, via dry-run (IMP/WebApp)

**Files:**
- Modify: `IMP/WebApp/src/composables/useImpositionApi.ts` — add `previewJdf`
- Create: `IMP/WebApp/src/bookview/usePreviewBook.ts`
- Modify: `IMP/WebApp/src/views/ApproveView.vue` (beside *Approve & send* / the JDF form), `IMP/WebApp/src/components/studio/StudioToolbar.vue` (beside *Generate JDF*; new emit `previewBook`) and its parent `StudioShell.vue`
- Test: `IMP/WebApp/src/bookview/usePreviewBook.spec.ts`

**Interfaces:**
- Consumes: `useBookStore().open` (Task 6); `solutionStore.request`, `solutionStore.selectedSolutionId`; `product.jobId`.
- Produces:

```ts
previewJdf(req: JdfRequest): Promise<string>;  // POST `${BASE}/jdf?dryRun=true`, returns res.text(); errors via the existing ApiError path
usePreviewBook(): { previewing: Ref<boolean>; error: Ref<string | null>; preview(): Promise<void> };
```

- [ ] **Step 1: Write failing tests** (mock `useImpositionApi`, real Pinia, mock router):
  - `preview()` posts a body equal to `{ ...solutionStore.request, jobId: product.jobId || 'PREVIEW', flavour: 'Stripping', solutionId: <selected>, emitNumberUp: true }` — the inline `sheets`/`presses` of the seed survive (assert a key the types don't know survives) — then calls `bookStore.open(xml, 'dry-run', <current route path>)` and navigates to `/book`.
  - A `previewJdf` rejection with `ApiError(404, 'No solution with id ...')` sets `error` to that detail, does not navigate, `bookStore.xml` stays null.
  - With no selected solution, `preview()` does nothing.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement**; `previewJdf` must not go through `request<T>`'s JSON parse (body is XML) — factor the error handling of `request` so both share it. Buttons: *Preview book*, disabled while `previewing` or without a selected solution; show `error` under it. Present in standalone and embedded (both modes).
- [ ] **Step 4: Run** tests + typecheck — PASS.
- [ ] **Step 5: Commit** — `feat(bookview): preview the solved layout as a book before approval`.

---

### Task 8: `book:seed` in the embed contract (IMP/WebApp)

**Files:**
- Modify: `IMP/WebApp/src/embed/contract.ts`, `embed/bridge.ts`, `embed/routing.ts`, `stores/embedStore.ts`, `composables/useEmbedSession.ts`
- Modify: `IMP/BC-EMBEDDED-EDITOR-BRIEF.md` §2 (message table)
- Test: `IMP/WebApp/src/embed/bridge.spec.ts`, `embed/routing.spec.ts`, `stores/embedStore.spec.ts`

**Interfaces:**
- Consumes: `useBookStore().open` (Task 6).
- Produces:

```ts
export interface BookSeedMessage {
  type: 'book:seed'; v: 1; jdf: string;
  options?: { entryKey?: string; units?: DisplayUnits; theme?: string };
}
export function isBookSeedMessage(data: unknown): data is BookSeedMessage; // v === 1 && typeof jdf === 'string'
// BridgeOptions gains: onBookSeed: (seed: BookSeedMessage) => void
// embedStore: session kind  `kind: Ref<'editor' | 'book'>`, `applyBookSeed(seed)`
// routing: embedRedirect gains `kind`; kind 'book' → only '/book' (everything else redirects to '/book');
//          kind 'editor' keeps today's rules, and additionally allows 'book' in both modes.
```

- [ ] **Step 1: Write failing tests:**
  - bridge: a `book:seed` from `window.parent` on an allowed origin calls `onBookSeed`; from a disallowed origin, with `jdf: 42`, or `v: 2` → neither callback; an `imposition:seed` still goes only to `onSeed`.
  - contract: `readEmbedMode('book')` is still `'approve'`.
  - routing: `kind: 'book'` + `/approve` → `'/book'`; `/book` → `true`; `kind: 'editor', mode: 'approve'` + `/book` → `true`; `mode: 'advanced'` + `/book` → `true`.
  - embedStore: `applyBookSeed` sets `kind` `'book'`, `entryKey`, units, `phase` `'seeded'`; a following `imposition:seed` switches `kind` back to `'editor'` (replacement, not merge).
- [ ] **Step 2: Run** `npx vitest run src/embed src/stores` — FAIL.
- [ ] **Step 3: Implement.** `useEmbedSession`: `onBookSeed` → `applyTheme(resolveTheme(seed.options?.theme))`, `embed.applyBookSeed(seed)`, `bookStore.open(seed.jdf, 'approved', null)`, `router.replace('/book')`, `markLanded()`; no `solve()`. If the model has an `error`, `embed.fail('The book preview could not read the JDF ticket: ' + error)`. Update the doc comments in `contract.ts` and the brief's message table.
- [ ] **Step 4: Run** full `npm test` + typecheck — PASS.
- [ ] **Step 5: Commit** — `feat(embed): book:seed opens the flip-book for an approved ticket`.

---

### Task 9: Add-in `LoadBook` (BC)

**Files:**
- Modify: `BC/PTE PrintVis External Imposition/src/Studio/PEQIImpositionStudio.ControlAddIn.al` — `procedure LoadBook(SpaUrl: Text; JdfXml: Text; OptionsJson: Text);`
- Modify: `BC/PTE PrintVis External Imposition/src/Studio/Resources/PEQIStudio.js`
- Modify: `BC/docs/superpowers/specs/2026-09-21-printvis-external-imposition-design.md` §8/§16 — add `book:seed` to the contract table

**Interfaces:**
- Produces: AL can call `CurrPage.<control>.LoadBook(SpaUrl, JdfXml, OptionsJson)`; JS posts `{ type: 'book:seed', v: 1, jdf: JdfXml, options: JSON.parse(OptionsJson) }` on `imposition:ready`; errors through the existing `EditorFailed` event.

- [ ] **Step 1: Refactor** `PEQI.load` into a shared `frameSpa(spaUrl, message)` (origin resolve, iframe creation with `embed=1`, listener) and two entry points: `load(spaUrl, requestJson, optionsJson)` (unchanged message) and `loadBook(spaUrl, jdfXml, optionsJson)`. Global `function LoadBook(spaUrl, jdfXml, optionsJson) { PEQI.loadBook(...) }`. Frame title "Book preview" for the book path. Guard against adding the `message` listener twice.
- [ ] **Step 2: Verify** `bash BC/tools/build.sh` compiles the main app. (No JS test harness exists in this repo; behaviour is covered end-to-end in Task 11's manual check.)
- [ ] **Step 3: Commit** (`PEQIImpositionStudio.ControlAddIn.al`, `PEQIStudio.js`, the 2026-09-21 spec) — `feat: the studio add-in can frame the book preview`.

---

### Task 10: Which ticket to show — `PEQI Book Preview Mgt.` (BC)

**Files:**
- Create: `BC/PTE PrintVis External Imposition/src/Document/PEQIBookPreviewMgt.Codeunit.al` (codeunit 50552, namespace `PrintersEquity.ExternalImposition.Document`)
- Test: `BC/PTE PrintVis External Imposition.Test/src/PEQIBookPreviewTests.Codeunit.al` (codeunit 50625)

**Interfaces:**
- Produces:

```al
procedure FindApprovedTicket(CaseId: Integer; JobNo: Integer; VersionNo: Integer; var JdfTicket: Record "PEQI Jdf Ticket"): Boolean
// latest (highest Entry No.) PEQI Imposition Job with Status = Committed for the job version,
// then its newest ticket (ByJob key filtered to that Entry No., highest Created At). False if either is missing.
procedure HasApprovedTicket(CaseId: Integer; JobNo: Integer; VersionNo: Integer): Boolean
procedure BookOptions(EntryKey: Text): Text   // JSON: entryKey, units (as RequestBuilder.SeedOptions does), theme 'bc'
```

- [ ] **Step 1: Write failing tests** (`Subtype = Test`, `Library Assert`, `[GIVEN]/[WHEN]/[THEN]` comments like `PEQICommitTests`), inserting `PEQI Imposition Job` / `PEQI Jdf Ticket` rows directly (`NewEntry`, `SetJdf`):
  - `NoCommittedEntryMeansNoTicket` — only a Solved entry with a ticket → `false`.
  - `TheLatestCommittedEntryWins` — Committed entry 1 (ticket A), Committed entry 2 (ticket B) → B.
  - `ANewerDraftDoesNotHideTheCommittedOne` — Committed entry 1 (ticket A), Draft entry 2 → A.
  - `TheNewestTicketOfTheEntryWins` — entry 1 with tickets at T1 < T2 → the T2 one.
  - `ACommittedEntryWithoutATicketIsNotApproved` → `false`.
  - `BookOptionsCarriesTheEntryKey` — JSON has `entryKey` and `theme` `'bc'`.
- [ ] **Step 2: Verify** `bash BC/tools/build.sh` compiles both apps (tests run on a BC server: run the codeunit there and expect FAIL until Step 3).
- [ ] **Step 3: Implement** the codeunit.
- [ ] **Step 4: Verify** compile; run `PEQI Book Preview Tests` on the BC sandbox — all PASS.
- [ ] **Step 5: Commit** — `feat: find the approved JDF ticket for a job`.

---

### Task 11: Book Preview page and the Job Items action (BC)

**Files:**
- Create: `BC/PTE PrintVis External Imposition/src/Document/PEQIBookPreview.Page.al` (page 50527, `PageType = Card`, no source table, `Editable = false`)
- Create: `BC/PTE PrintVis External Imposition/src/Extensions/PEQIJobItemsListPart.PageExt.al` (pageextension 50532 extends `"PVS Job Items ListPart"`)
- Modify: `BC/PTE PrintVis External Imposition/src/Core/PEQIImposition.PermissionSet.al` — add `page "PEQI Book Preview" = X`, `codeunit "PEQI Book Preview Mgt." = X`

**Interfaces:**
- Consumes: `FindApprovedTicket`, `HasApprovedTicket`, `BookOptions` (Task 10); `LoadBook` (Task 9); `"PEQI Imposition Setup"."Spa Url"`.
- Produces: page procedure `SetTicket(JdfTicket: Record "PEQI Jdf Ticket")`.

- [ ] **Step 1: Page:** caption *Book Preview*; one `usercontrol(Book; "PEQI Imposition Studio")`. `ControlReady` → if `Spa Url` empty, show a message group ("No editor URL is configured on the Imposition Setup page.") instead; else `CurrPage.Book.LoadBook(Setup."Spa Url", Ticket.GetJdf(), BookPreviewMgt.BookOptions(<entry key of the ticket's job entry>))`. `EditorFailed(Message)` → hide the control, show the message. Ignore `SolutionChosen`/`PreviewReady`.
- [ ] **Step 2: Action** on the list part: `addlast(processing)` → `action(PEQIBookPreview)`, Caption *Book Preview*, `Image = View`, ToolTip "Shows the approved imposition of this job as a flip-book.", `Enabled = HasApproved` (computed in `OnAfterGetCurrRecord` via `HasApprovedTicket(Rec.ID, Rec.Job, Rec.Version)`). `OnAction`: `FindApprovedTicket` → `BookPage.SetTicket(Ticket); BookPage.Run()`; otherwise `Error('This job has no approved imposition yet.')`.
- [ ] **Step 3: Verify** `bash BC/tools/build.sh` — both apps compile.
- [ ] **Step 4: Manual end-to-end** on the sandbox (Azurite + `func start` + WebApp served at the configured `Spa Url`):
  1. Job without a committed imposition → *Book Preview* disabled.
  2. Solve Imposition → in the editor, *Preview book* → flip-book opens, Details shows *set at approval*; Back returns to the approve screen.
  3. Approve and commit → on the Job Items bar *Book Preview* is enabled → flip-book of the stored ticket; Details shows the real Job ID, customer and JDF version.
  Record outcomes in the commit message body.
- [ ] **Step 5: Commit** (the page, the pageext, the permission set only) — `feat: Book Preview on the Job Items bar`.

---

## Execution order

Tasks 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 in `IMP`; Tasks 9 → 10 → 11 in `BC` can run in parallel with 3–8 once Task 1 lands, but Task 11's manual check needs Tasks 6 and 8 deployed.
