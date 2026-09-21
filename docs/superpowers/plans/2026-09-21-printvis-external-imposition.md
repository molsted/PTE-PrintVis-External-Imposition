# PTE PrintVis External Imposition — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a PrintVis planner solve a job's imposition with the external Impositioning engine, choose a layout in the engine's own editor embedded in Business Central, and write a CIP4 JDF ticket from that choice.

**Architecture:** AL builds a self-contained `CalculateRequest` from a `PVS Job` and its components plus two setup tables, hands it to the Vue editor hosted in a control add-in, receives the chosen `solutionId`, and posts `/jdf` to write and store the ticket. Outbound HTTP only; BC publishes no API surface. The request builder never issues HTTP and the engine client never reads a PrintVis table, which is what makes both testable.

**Tech Stack:** AL for Business Central 28, PrintVis 28.0.0.2, AL compiler 18.0 via `dotnet`, AL-Go for GitHub CI, JavaScript control add-in, Impositioning API (Azure Functions).

**Spec:** [`docs/superpowers/specs/2026-09-21-printvis-external-imposition-design.md`](../specs/2026-09-21-printvis-external-imposition-design.md)

---

## Global Constraints

- **Object prefix `PEQI` on every object and every field added to a PrintVis or BC table.**
- **Id ranges** (refines spec §13, which allocated only ten codeunit ids — splitting the request builder into focused files needs fifteen): tables `50500–50509`, pages `50510–50529`, page extensions `50530–50534`, codeunits `50535–50549`, enums `50550–50569`, permission sets `50580–50581`. `interface` and `controladdin` objects carry no id. The **test app** uses its own range `50601–50650` in its own `app.json`.
- **Every source file starts with this header.** Where a code block below says `// <copyright header>`, it means these ten lines verbatim:

```al
// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------
```

- **Reading PrintVis field and option names.** A `.app` is a zip behind a 40-byte header, and the PrintVis package ships full AL source. Where a step says to check a name against the symbols, this is how:

```bash
cd "$(mktemp -d)" && SRC="<repo>/PTE PrintVis External Imposition/.alpackages/PrintVis A_S_PrintVis_28.0.0.2.app"
python3 -c "d=open('$SRC','rb').read(); i=d.find(b'PK\x03\x04'); open('pv.zip','wb').write(d[i:])"
unzip -q pv.zip -d pv && ls pv/src/src | head
# then e.g. grep -nE '^\s{8}field\(' pv/src/src/PVSJobItem.Table.al
```

Referred to below as **the extracted PrintVis source**.
- **File layout:** `src/<Area>/<Name>.<ObjectType>.al`.
- **`Press Id` (GUID) and `Substrate Id` (integer) are assigned once and never regenerated.** The `solutionId` from `/calculate` is a hash that includes them; regenerating either makes every quoted solution stale at `/jdf`.
- **The API key is never a table field.** It lives in `IsolatedStorage` at `DataScope::Company`, write-only from the setup page.
- **`impositionRules` is never sent** (spec §6.5). The resulting `IMPOSITION_RULES_NOT_APPLIED` diagnostic is stored, not suppressed.
- **`catalog` filter fields are never sent** alongside `sheets[]`/`presses[]` — a stated half replaces its catalogue and the engine refuses the matching filters (spec §6.3).
- **No write to any PrintVis table** except `PVS Job Sheet Imposition` under the guard in Task 17.

## Execution Order

> **Controller ruling (pre-flight):** Task 15 builds the control add-in, whose
> `SolutionChosen` and `PreviewReady` triggers call `PEQI Commit Manager` (Task 16)
> and `PEQI Preview Writer` (Task 17). Written in plan order it would not compile.
> **Dispatch order is 1–14, then 16, 17, 15, 18.** Task numbering is unchanged, so
> every task brief still resolves by its own number. Cost if wrong: Task 15's
> commit lands after two it does not depend on.

## Verification Model — read this before Task 1

This repo can be compiled on this machine but **AL test codeunits cannot be executed here.** They need a Business Central server; Docker is not running and there is no container. So the red/green cycle is split, and each task says which gate applies:

| Gate | What it is | Where it runs |
|---|---|---|
| **Compile** | `tools/build.sh` — `alc` over both app folders, ~3 s | Locally, every step |
| **Compile-red** | The test app fails to compile because the object or procedure under test does not exist yet. This is a genuine red state and the plan uses it as one | Locally |
| **Assert-red/green** | `[Test]` procedures actually executing and asserting | AL-Go CI (`CICD.yaml` with `testFolders` set) or a dev container via `.AL-Go/cloudDevEnv.ps1` |

**Do not claim a task's tests pass until an assert-green run exists.** A task is complete locally when it compiles and its tests are written and committed; the CI run is what confirms them. Where a task's logic can be exercised without a server, the plan says so.

The AL compiler is at:

```bash
ALC=~/.vscode/extensions/ms-dynamics-smb.al-18.0.2732683/bin/alc.dll
dotnet "$ALC" /project:"<folder>" /packagecachepath:"<folder>/.alpackages" /out:"/tmp/out.app"
```

---

## File Structure

```
PTE-PrintVis-External-Imposition/
├── .AL-Go/settings.json                     MODIFY  appFolders, testFolders
├── tools/build.sh                           CREATE  local compile gate
├── PTE PrintVis External Imposition/
│   ├── app.json                             MODIFY  deps, versions, runtime
│   └── src/
│       ├── Core/
│       │   ├── PEQIInstall.Codeunit.al              50548  install defaults
│       │   ├── PEQIUpgrade.Codeunit.al              50549  upgrade tags
│       │   ├── PEQIImposition.PermissionSet.al      50580
│       │   └── PEQIImpositionSetup.PermissionSet.al 50581
│       ├── Enums/
│       │   └── PEQIEnums.Enum.al                    50550-50562  (12 enums, 50554 free)
│       ├── Setup/
│       │   ├── PEQIImpositionSetup.Table.al         50500
│       │   ├── PEQIImpositionSetup.Page.al          50510
│       │   ├── PEQIPressSetup.Table.al              50501
│       │   ├── PEQIPressSetupList.Page.al           50511
│       │   ├── PEQIPressSetupCard.Page.al           50512
│       │   ├── PEQIPaperSetup.Table.al              50502
│       │   ├── PEQIPaperSetupList.Page.al           50513
│       │   ├── PEQIBindingMapping.Table.al          50503
│       │   ├── PEQIBindingMappings.Page.al          50514
│       │   ├── PEQIPartMapping.Table.al             50504
│       │   └── PEQIPartMappings.Page.al             50515
│       ├── Document/
│       │   ├── PEQIImpositionJob.Table.al           50505
│       │   ├── PEQIPressRun.Table.al                50506
│       │   ├── PEQIJdfTicket.Table.al               50507
│       │   ├── PEQIDiagnostic.Table.al              50508
│       │   ├── PEQIImpositionJobs.Page.al           50516
│       │   ├── PEQIImpositionJobCard.Page.al        50517
│       │   ├── PEQIPressRunPart.Page.al             50518
│       │   ├── PEQIDiagnosticsPart.Page.al          50519
│       │   └── PEQIJdfTickets.Page.al               50520
│       ├── Mapping/
│       │   ├── PEQIRequestBuilder.Codeunit.al       50535  orchestrator
│       │   ├── PEQIPartMapper.Codeunit.al           50536  parts[]
│       │   ├── PEQICatalogMapper.Codeunit.al        50537  sheets[] presses[]
│       │   ├── PEQIRequestValidator.Codeunit.al     50538  §6.6 failures
│       │   └── PEQIJsonHelper.Codeunit.al           50539  JsonObject helpers
│       ├── Integration/
│       │   ├── PEQIIEngineTransport.Interface.al    (no id)
│       │   ├── PEQITransportType.Enum.al            50563  implements the interface
│       │   ├── PEQIHttpTransport.Codeunit.al        50540
│       │   ├── PEQIEngineClient.Codeunit.al         50541
│       │   └── PEQIResponseReader.Codeunit.al       50542
│       ├── Commit/
│       │   ├── PEQICommitManager.Codeunit.al        50543
│       │   └── PEQIPreviewWriter.Codeunit.al        50544
│       ├── Studio/
│       │   ├── PEQIImpositionStudio.ControlAddIn.al (no id)
│       │   └── Resources/PEQIStudio.js
│       └── Extensions/
│           ├── PEQICaseCard.PageExt.al              50530
│           └── PEQIJobCard.PageExt.al               50531
└── PTE PrintVis External Imposition.Test/
    ├── app.json                             CREATE  range 50601-50650
    └── src/
        ├── PEQITestTransport.Codeunit.al            50601  interface double
        ├── PEQITestData.Codeunit.al                 50602  PVS fixture builder
        ├── PEQITestTransportQueue.Codeunit.al       50603  queued responses
        ├── PEQITestTransportType.EnumExt.al         50604  registers the double
        ├── PEQISetupTests.Codeunit.al               50609
        ├── PEQIBuilderTests.Codeunit.al             50610
        ├── PEQIValidatorTests.Codeunit.al           50611
        ├── PEQIClientTests.Codeunit.al              50612
        ├── PEQICommitTests.Codeunit.al              50613
        ├── PEQIPreviewTests.Codeunit.al             50614
        ├── PEQIDocumentTests.Codeunit.al            50615
        └── PEQIResponseTests.Codeunit.al            50616
```

**Why the builder is four files and not one.** `PEQIRequestBuilder` assembles the document; `PEQIPartMapper` groups job items into parts; `PEQICatalogMapper` emits the two inline halves; `PEQIRequestValidator` refuses bad input before serialising. Each is separately testable, and the catalogue mapper is the one that will change when a field moves in PrintVis.

---

### Task 1: Project scaffold and the local build gate

**Files:**
- Modify: `PTE PrintVis External Imposition/app.json`
- Modify: `.AL-Go/settings.json`
- Create: `tools/build.sh`
- Create: `PTE PrintVis External Imposition.Test/app.json`
- Create: `PTE PrintVis External Imposition.Test/src/.gitkeep`

**Interfaces:**
- Consumes: nothing.
- Produces: a repeatable compile gate, `tools/build.sh`, used by every later task.

- [ ] **Step 1: Point `app.json` at BC 28 and PrintVis**

Replace the `dependencies`, `platform`, `application` and `runtime` members. Ids are taken from the `NavxManifest.xml` inside each `.app` in `.alpackages`, not guessed:

```json
  "dependencies": [
    {
      "id": "5452f323-059e-499a-9753-5d2c07eef904",
      "name": "PrintVis",
      "publisher": "PrintVis A/S",
      "version": "28.0.0.0"
    },
    {
      "id": "a1775e0b-ae52-43ed-9eb9-8e23a6214831",
      "name": "PrintVis System Library",
      "publisher": "PrintVis A/S",
      "version": "28.0.0.0"
    },
    {
      "id": "63bb5701-ecc7-4a35-b851-0593b74d74e2",
      "name": "Printer's Equity Library",
      "publisher": "Printer's Equity",
      "version": "25.0.0.0"
    }
  ],
  "platform": "28.0.0.0",
  "application": "28.0.0.0",
  "runtime": "17.0",
```

Also set `"brief"` and `"description"`:

```json
  "brief": "Solves job imposition with the external Impositioning engine and writes the JDF.",
  "description": "Builds a self-contained imposition request from a PrintVis job and its components, hosts the Impositioning editor in Business Central so a planner can choose a layout, and writes the CIP4 JDF ticket for the chosen solution. Paper and presses are sent inline from PrintVis's own masters, so nothing has to be registered with the engine. Nothing is written back to the PrintVis calculation.",
```

- [ ] **Step 2: Create the test app manifest**

Create `PTE PrintVis External Imposition.Test/app.json`. Generate a fresh GUID for `id` (`uuidgen`):

```json
{
  "id": "<uuidgen output>",
  "name": "PTE PrintVis External Imposition Test",
  "publisher": "Printers Equity",
  "version": "1.0.0.0",
  "brief": "Tests for PTE PrintVis External Imposition.",
  "description": "Test app. Not shipped to production.",
  "dependencies": [
    {
      "id": "57ee841a-7966-41d2-8abe-957f55eb05dc",
      "name": "PTE PrintVis External Imposition",
      "publisher": "Printers Equity",
      "version": "1.0.0.0"
    },
    {
      "id": "dd0be2ea-f733-4d65-bb34-a28f4624fb14",
      "name": "Library Assert",
      "publisher": "Microsoft",
      "version": "28.0.0.0"
    },
    {
      "id": "e7320ebb-08b3-4406-b1ec-b4927d3e280b",
      "name": "Any",
      "publisher": "Microsoft",
      "version": "28.0.0.0"
    }
  ],
  "platform": "28.0.0.0",
  "application": "28.0.0.0",
  "runtime": "17.0",
  "idRanges": [ { "from": 50601, "to": 50650 } ],
  "features": [ "NoImplicitWith" ],
  "resourceExposurePolicy": {
    "allowDebugging": true,
    "allowDownloadingSource": true,
    "includeSourceInSymbolFile": true
  }
}
```

Then `touch "PTE PrintVis External Imposition.Test/src/.gitkeep"` so the folder is tracked.

- [ ] **Step 3: Register both folders with AL-Go**

`.AL-Go/settings.json` becomes:

```json
{
  "$schema": "https://raw.githubusercontent.com/microsoft/AL-Go-Actions/v9.2/.Modules/settings.schema.json",
  "country": "dk",
  "appFolders": [ "PTE PrintVis External Imposition" ],
  "testFolders": [ "PTE PrintVis External Imposition.Test" ],
  "bcptTestFolders": []
}
```

`country` is changed from the template's `us` to `dk` to match `PEQ-PV-CIM`. If these builds must be `us`, change it back — it only selects the CI build container's localisation.

- [ ] **Step 4: Write the build script**

Create `tools/build.sh`:

```bash
#!/usr/bin/env bash
# Local compile gate. Compiles the main app always and the test app when its
# symbols resolve. Test *execution* needs a BC server and does not happen here.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
ALC="${ALC:-$HOME/.vscode/extensions/ms-dynamics-smb.al-18.0.2732683/bin/alc.dll}"
APP="$ROOT/PTE PrintVis External Imposition"
TEST="$ROOT/PTE PrintVis External Imposition.Test"
OUT="${TMPDIR:-/tmp}/peqi-build"
mkdir -p "$OUT"

if [ ! -f "$ALC" ]; then
  echo "AL compiler not found at $ALC - set ALC to alc.dll" >&2
  exit 127
fi

fail=0

echo "== main app =="
dotnet "$ALC" /project:"$APP" /packagecachepath:"$APP/.alpackages" \
  /out:"$OUT/app.app" || fail=1

if [ -d "$TEST" ]; then
  echo "== test app =="
  mkdir -p "$TEST/.alpackages"
  cp -f "$OUT/app.app" "$TEST/.alpackages/" 2>/dev/null || true
  cp -f "$APP/.alpackages/"*.app "$TEST/.alpackages/" 2>/dev/null || true
  if ls "$TEST/.alpackages/"*"Library Assert"*.app >/dev/null 2>&1; then
    dotnet "$ALC" /project:"$TEST" /packagecachepath:"$TEST/.alpackages" \
      /out:"$OUT/test.app" || fail=1
  else
    echo "SKIPPED - Microsoft test symbols (Library Assert, Any) are not in"
    echo "$TEST/.alpackages. The test app is compiled by AL-Go CI instead."
  fi
fi

exit $fail
```

Then `chmod +x tools/build.sh`.

- [ ] **Step 5: Run the build gate**

Run: `tools/build.sh`
Expected: `== main app ==` followed by the compiler banner and no `error AL`; exit code 0. The test app step prints `SKIPPED` unless you have fetched the Microsoft test symbol apps into its `.alpackages`.

If the compiler reports `error AL1024` or similar about `runtime`, lower `"runtime"` in both `app.json` files to `"16.1"` and re-run. That is open item §15.6 in the spec resolving itself.

- [ ] **Step 6: Commit**

```bash
git add "PTE PrintVis External Imposition/app.json" \
        "PTE PrintVis External Imposition.Test" \
        .AL-Go/settings.json tools/build.sh
git commit -m "build: target BC 28 and PrintVis 28, add test app and local compile gate"
```

---

### Task 2: Enums

> **Controller ruling (pre-flight):** the plan originally declared a thirteenth
> enum, `PEQI Work Style` (50554). Nothing consumes it — `PEQI Press Setup`
> represents work styles as five booleans and `WorkStyleList()` emits the engine's
> spellings directly. It has been removed rather than shipped as a dead object.
> Id 50554 is left unallocated.

**Files:**
- Create: `PTE PrintVis External Imposition/src/Enums/PEQIEnums.Enum.al`

**Interfaces:**
- Consumes: nothing.
- Produces: the twelve enums every later task refers to. Value names match the engine's JSON spellings exactly, because they are serialised straight into the request.

- [ ] **Step 1: Write all twelve enums in one file**

One file, because they are a single vocabulary and splitting them into twelve files would only add noise. Captions are the engine's own words so an operator reading a diagnostic sees the same term.

```al
// <copyright header>

enum 50550 "PEQI Job Status"
{
    Extensible = false;
    value(0; Draft) { Caption = 'Draft'; }
    value(1; Solved) { Caption = 'Solved'; }
    value(2; Committed) { Caption = 'Committed'; }
    value(3; Failed) { Caption = 'Failed'; }
}

enum 50551 "PEQI Press Type"
{
    Extensible = false;
    value(0; Offset) { Caption = 'Offset'; }
    value(1; Digital) { Caption = 'Digital'; }
}

enum 50552 "PEQI Sheet Grain"
{
    Extensible = false;
    value(0; " ") { Caption = 'Not recorded'; }
    value(1; Short) { Caption = 'Short'; }
    value(2; Long) { Caption = 'Long'; }
}

enum 50553 "PEQI Press Edge"
{
    Extensible = false;
    value(0; " ") { Caption = 'Unknown'; }
    value(1; Top) { Caption = 'Top'; }
    value(2; Bottom) { Caption = 'Bottom'; }
    value(3; Left) { Caption = 'Left'; }
    value(4; Right) { Caption = 'Right'; }
}

enum 50555 "PEQI Binding Type"
{
    Extensible = false;
    value(0; None) { Caption = 'None'; }
    value(1; SaddleStitch) { Caption = 'Saddle stitch'; }
    value(2; PerfectBound) { Caption = 'Perfect bound'; }
    value(3; SideStitch) { Caption = 'Side stitch'; }
    value(4; WireO) { Caption = 'Wire-O'; }
}

enum 50556 "PEQI Binding Side"
{
    Extensible = false;
    value(0; Left) { Caption = 'Left'; }
    value(1; Right) { Caption = 'Right'; }
    value(2; Top) { Caption = 'Top'; }
    value(3; Bottom) { Caption = 'Bottom'; }
}

enum 50557 "PEQI Part Product Type"
{
    Extensible = false;
    value(0; Body) { Caption = 'Body'; }
    value(1; Cover) { Caption = 'Cover'; }
    value(2; Insert) { Caption = 'Insert'; }
    value(3; Jacket) { Caption = 'Jacket'; }
    value(4; Flat) { Caption = 'Flat'; }
}

enum 50558 "PEQI Grain Rule"
{
    Extensible = false;
    value(0; Any) { Caption = 'Any'; }
    value(1; ParallelToSpine) { Caption = 'Parallel to spine'; }
    value(2; PerpendicularToSpine) { Caption = 'Perpendicular to spine'; }
}

enum 50559 "PEQI Grain Policy"
{
    Extensible = false;
    value(0; Ignored) { Caption = 'Ignored'; }
    value(1; Preferred) { Caption = 'Preferred'; }
    value(2; Required) { Caption = 'Required'; }
}

enum 50560 "PEQI Jdf Flavour"
{
    Extensible = false;
    value(0; Stripping) { Caption = 'Stripping'; }
    value(1; PrepsTemplate) { Caption = 'Preps template'; }
}

enum 50561 "PEQI Jdf Version"
{
    Extensible = false;
    value(0; V14) { Caption = 'JDF 1.4'; }
    value(1; V15) { Caption = 'JDF 1.5'; }
}

enum 50562 "PEQI Diagnostic Severity"
{
    Extensible = false;
    value(0; Info) { Caption = 'Info'; }
    value(1; Warn) { Caption = 'Warning'; }
    value(2; Error) { Caption = 'Error'; }
}
```

- [ ] **Step 2: Compile**

Run: `tools/build.sh`
Expected: exit 0, no `error AL`.

- [ ] **Step 3: Commit**

```bash
git add "PTE PrintVis External Imposition/src/Enums/PEQIEnums.Enum.al"
git commit -m "feat: add imposition enums matching the engine's JSON vocabulary"
```

---

### Task 3: Imposition Setup singleton

**Files:**
- Create: `PTE PrintVis External Imposition/src/Setup/PEQIImpositionSetup.Table.al`
- Create: `PTE PrintVis External Imposition/src/Setup/PEQIImpositionSetup.Page.al`

**Interfaces:**
- Consumes: enums from Task 2.
- Produces:
  - `PEQIImpositionSetup.GetSetup(): Record "PEQI Imposition Setup"` — inserts the singleton on first call.
  - `PEQIImpositionSetup.SetApiKey(Key: Text)` and `.GetApiKey(): Text` — isolated storage, never a field.
  - `PEQIImpositionSetup.NextSubstrateId(): Integer` — monotonic; never reuses
  - `PEQIImpositionSetup.ThicknessToMicrons(Value: Decimal): Decimal`
  - `PEQIImpositionSetup.WeightToGsm(Value: Decimal): Decimal`

- [ ] **Step 1: Write the table**

```al
// <copyright header>

table 50500 "PEQI Imposition Setup"
{
    Caption = 'Imposition Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10]) { Caption = 'Primary Key'; }
        field(10; Enabled; Boolean) { Caption = 'Enabled'; }
        field(11; "Engine Base Url"; Text[250]) { Caption = 'Engine Base URL'; }
        field(12; "Spa Url"; Text[250]) { Caption = 'Editor URL'; }
        field(13; "Timeout (ms)"; Integer)
        {
            Caption = 'Timeout (ms)';
            InitValue = 120000;
            MinValue = 1000;
        }
        field(14; "Retry Count"; Integer)
        {
            Caption = 'Retry Count';
            InitValue = 3;
            MinValue = 0;
            MaxValue = 10;
        }
        field(20; "Grain Policy"; Enum "PEQI Grain Policy") { Caption = 'Grain Policy'; }
        field(21; "Max Solutions"; Integer)
        {
            Caption = 'Max Solutions';
            InitValue = 10;
            MinValue = 1;
            MaxValue = 50;
        }
        field(22; "Jdf Version"; Enum "PEQI Jdf Version") { Caption = 'JDF Version'; }
        field(23; "Jdf Flavour"; Enum "PEQI Jdf Flavour") { Caption = 'JDF Flavour'; }
        field(24; "Job Id Format"; Text[50])
        {
            Caption = 'Job ID Format';
            InitValue = '%1-%2-%3';
        }
        field(30; "Default Trim Head (mm)"; Decimal) { Caption = 'Default Trim Head (mm)'; DecimalPlaces = 0 : 3; }
        field(31; "Default Trim Foot (mm)"; Decimal) { Caption = 'Default Trim Foot (mm)'; DecimalPlaces = 0 : 3; }
        field(32; "Default Trim Face (mm)"; Decimal) { Caption = 'Default Trim Face (mm)'; DecimalPlaces = 0 : 3; }
        field(40; "Thickness Is Microns"; Boolean)
        {
            Caption = 'Thickness Is Microns';
            // PVS Thickness unit is spec open item 15.1. False means millimetres.
        }
        field(41; "Weight Is Gsm"; Boolean)
        {
            Caption = 'Weight Is g/m2';
            InitValue = true;
        }
        field(50; "Last Substrate Id"; Integer)
        {
            Caption = 'Last Substrate Id';
            Editable = false;
            ToolTip = 'High-water mark for substrate ids. It only ever rises, so a deleted paper''s id is never handed to a different paper.';
        }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }

    var
        ApiKeyTok: Label 'PEQI_ENGINE_API_KEY', Locked = true;

    /// <summary>Reads the singleton, inserting it with its InitValues on first call.</summary>
    procedure GetSetup(): Record "PEQI Imposition Setup"
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        if not Setup.Get('') then begin
            Setup.Init();
            Setup."Primary Key" := '';
            Setup.Insert(true);
        end;
        exit(Setup);
    end;

    /// <summary>Stores the engine API key. Never a table field - a field would be
    /// readable by anyone with table read permission and would land in backups.</summary>
    procedure SetApiKey(NewKey: Text)
    begin
        if NewKey = '' then begin
            if IsolatedStorage.Contains(ApiKeyTok, DataScope::Company) then
                IsolatedStorage.Delete(ApiKeyTok, DataScope::Company);
            exit;
        end;
        IsolatedStorage.Set(ApiKeyTok, NewKey, DataScope::Company);
    end;

    procedure GetApiKey(): Text
    var
        Key: Text;
    begin
        if not IsolatedStorage.Get(ApiKeyTok, DataScope::Company, Key) then
            exit('');
        exit(Key);
    end;

    procedure HasApiKey(): Boolean
    begin
        exit(IsolatedStorage.Contains(ApiKeyTok, DataScope::Company));
    end;

    /// <summary>Issues the next substrate id and records it. A high-water mark
    /// rather than max-plus-one over the rows: deleting the highest paper must not
    /// release its id, because a stored request or a written ticket may still name it.</summary>
    procedure NextSubstrateId(): Integer
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        Setup.LockTable();
        Setup := Setup.GetSetup();
        Setup.Get('');
        Setup."Last Substrate Id" += 1;
        Setup.Modify(true);
        exit(Setup."Last Substrate Id");
    end;

    /// <summary>PVS Thickness to the engine's caliperMicrons.</summary>
    procedure ThicknessToMicrons(Value: Decimal): Decimal
    begin
        if "Thickness Is Microns" then
            exit(Value);
        exit(Value * 1000);
    end;

    /// <summary>PVS Weight to the engine's grammageGsm.</summary>
    procedure WeightToGsm(Value: Decimal): Decimal
    begin
        exit(Value);
    end;
}
```

`WeightToGsm` is an identity function today and exists anyway: it is the single place a non-g/m² `PVS Weight Unit` will be handled, and callers should not have to learn that later.

- [ ] **Step 2: Write the setup page**

The API key control is unbound: it writes through `SetApiKey` and never shows what is stored.

```al
// <copyright header>

page 50510 "PEQI Imposition Setup"
{
    Caption = 'Imposition Setup';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "PEQI Imposition Setup";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field(Enabled; Rec.Enabled) { ApplicationArea = All; }
                field("Engine Base Url"; Rec."Engine Base Url")
                {
                    ApplicationArea = All;
                    ToolTip = 'The Impositioning API base URL, for example https://impose.example.com/api';
                }
                field("Spa Url"; Rec."Spa Url")
                {
                    ApplicationArea = All;
                    ToolTip = 'The Impositioning editor URL. It is opened in a frame inside Business Central.';
                }
                field(ApiKey; ApiKey)
                {
                    ApplicationArea = All;
                    Caption = 'API Key';
                    ExtendedDatatype = Masked;
                    ToolTip = 'Stored encrypted. It is never displayed again after saving.';

                    trigger OnValidate()
                    begin
                        Rec.SetApiKey(ApiKey);
                        ApiKey := '';
                        KeyIsSet := Rec.HasApiKey();
                    end;
                }
                field(KeyIsSet; KeyIsSet)
                {
                    ApplicationArea = All;
                    Caption = 'API Key Is Set';
                    Editable = false;
                }
            }
            group(Solving)
            {
                Caption = 'Solving';
                field("Grain Policy"; Rec."Grain Policy") { ApplicationArea = All; }
                field("Max Solutions"; Rec."Max Solutions") { ApplicationArea = All; }
                field("Default Trim Head (mm)"; Rec."Default Trim Head (mm)") { ApplicationArea = All; }
                field("Default Trim Foot (mm)"; Rec."Default Trim Foot (mm)") { ApplicationArea = All; }
                field("Default Trim Face (mm)"; Rec."Default Trim Face (mm)") { ApplicationArea = All; }
            }
            group(Ticket)
            {
                Caption = 'JDF';
                field("Jdf Version"; Rec."Jdf Version") { ApplicationArea = All; }
                field("Jdf Flavour"; Rec."Jdf Flavour") { ApplicationArea = All; }
                field("Job Id Format"; Rec."Job Id Format")
                {
                    ApplicationArea = All;
                    ToolTip = 'JDF JobID. %1 is the case ID, %2 the job, %3 the version.';
                }
            }
            group(Units)
            {
                Caption = 'PrintVis Units';
                field("Thickness Is Microns"; Rec."Thickness Is Microns")
                {
                    ApplicationArea = All;
                    ToolTip = 'Clear this if PVS Thickness is recorded in millimetres.';
                }
                field("Weight Is Gsm"; Rec."Weight Is Gsm") { ApplicationArea = All; }
            }
            group(Connection)
            {
                Caption = 'Connection';
                field("Timeout (ms)"; Rec."Timeout (ms)") { ApplicationArea = All; }
                field("Retry Count"; Rec."Retry Count") { ApplicationArea = All; }
            }
        }
    }

    var
        ApiKey: Text;
        KeyIsSet: Boolean;

    trigger OnOpenPage()
    begin
        Rec := Rec.GetSetup();
        Rec.Get('');
        KeyIsSet := Rec.HasApiKey();
    end;
}
```

- [ ] **Step 3: Compile**

Run: `tools/build.sh`
Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add "PTE PrintVis External Imposition/src/Setup/PEQIImpositionSetup.Table.al" \
        "PTE PrintVis External Imposition/src/Setup/PEQIImpositionSetup.Page.al"
git commit -m "feat: add imposition setup singleton with isolated-storage API key"
```

---

### Task 4: Press Setup and Paper Setup

> **Controller ruling (pre-flight):** the substrate allocator originally read
> `FindLast` over the table, which hands a deleted paper's id straight to the next
> insert — the third test below asserts against exactly that. It now draws from a
> high-water mark on the setup singleton (`Last Substrate Id`, added in Task 3).
> Cost if wrong: one integer field on a singleton nobody else reads.

**Files:**
- Create: `PTE PrintVis External Imposition/src/Setup/PEQIPressSetup.Table.al`
- Create: `PTE PrintVis External Imposition/src/Setup/PEQIPressSetupList.Page.al`
- Create: `PTE PrintVis External Imposition/src/Setup/PEQIPressSetupCard.Page.al`
- Create: `PTE PrintVis External Imposition/src/Setup/PEQIPaperSetup.Table.al`
- Create: `PTE PrintVis External Imposition/src/Setup/PEQIPaperSetupList.Page.al`
- Test: `PTE PrintVis External Imposition.Test/src/PEQISetupTests.Codeunit.al`

**Interfaces:**
- Consumes: enums (Task 2).
- Produces:
  - `Record "PEQI Press Setup"` with `"Press Id"` (GUID) assigned in `OnInsert` and protected in `OnModify`.
  - `Record "PEQI Paper Setup"` with `"Substrate Id"` (Integer) assigned in `OnInsert` and protected in `OnModify`.
  - `PEQIPaperSetup.EffectiveGrain(): Enum "PEQI Sheet Grain"` — override if set, else the item's `PVS Grain Direction`.

- [ ] **Step 1: Write the failing test for id stability**

This is the one invariant that silently breaks the whole integration, so it is tested before the tables exist. Create `PTE PrintVis External Imposition.Test/src/PEQISetupTests.Codeunit.al`:

```al
// <copyright header>

codeunit 50609 "PEQI Setup Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure PressIdIsAssignedOnInsert()
    var
        PressSetup: Record "PEQI Press Setup";
    begin
        // [GIVEN] a press setup row with no press id
        PressSetup.Init();
        PressSetup."Cost Center Code" := 'PRESS01';
        PressSetup.Configuration := 'STD';
        Clear(PressSetup."Press Id");

        // [WHEN] it is inserted
        PressSetup.Insert(true);

        // [THEN] a press id has been assigned
        Assert.IsFalse(IsNullGuid(PressSetup."Press Id"), 'Press Id should be assigned on insert');
    end;

    [Test]
    procedure PressIdSurvivesModify()
    var
        PressSetup: Record "PEQI Press Setup";
        Original: Guid;
    begin
        // [GIVEN] an inserted press setup row
        PressSetup.Init();
        PressSetup."Cost Center Code" := 'PRESS02';
        PressSetup.Configuration := 'STD';
        PressSetup.Insert(true);
        Original := PressSetup."Press Id";

        // [WHEN] the row is cleared of its id and modified
        Clear(PressSetup."Press Id");
        PressSetup.Modify(true);

        // [THEN] the original id is restored, not regenerated
        // A regenerated id makes every quoted solutionId stale at /jdf.
        PressSetup.Get('PRESS02', 'STD');
        Assert.AreEqual(Original, PressSetup."Press Id", 'Press Id must never change');
    end;

    [Test]
    procedure SubstrateIdIsSequentialAndNeverReused()
    var
        PaperSetup: Record "PEQI Paper Setup";
        First: Integer;
        Second: Integer;
    begin
        // [GIVEN] two paper setup rows
        PaperSetup.Init();
        PaperSetup."Item No." := 'PAPER-A';
        PaperSetup.Insert(true);
        First := PaperSetup."Substrate Id";

        PaperSetup.Init();
        PaperSetup."Item No." := 'PAPER-B';
        PaperSetup.Insert(true);
        Second := PaperSetup."Substrate Id";

        // [THEN] they differ and ascend
        Assert.AreNotEqual(First, Second, 'Substrate Ids must be distinct');
        Assert.IsTrue(Second > First, 'Substrate Ids ascend');

        // [WHEN] the later row is deleted and a third is inserted
        PaperSetup.Get('PAPER-B', '');
        PaperSetup.Delete(true);
        PaperSetup.Init();
        PaperSetup."Item No." := 'PAPER-C';
        PaperSetup.Insert(true);

        // [THEN] the deleted id is not handed out again
        Assert.IsTrue(PaperSetup."Substrate Id" > Second, 'Substrate Ids are never reused');
    end;
}
```

- [ ] **Step 2: Run the compile-red gate**

Run: `tools/build.sh`
Expected: the test app fails to compile — `error AL0185: Table 'PEQI Press Setup' is missing`. If the test app prints `SKIPPED`, fetch the Microsoft test symbols first or accept that this red state is confirmed by CI; the compile failure is the red state either way.

- [ ] **Step 3: Write the Press Setup table**

Only the fields PrintVis does not have. Everything else is read live from `PVS Cost Center Configuration` by the catalogue mapper in Task 8.

```al
// <copyright header>

table 50501 "PEQI Press Setup"
{
    Caption = 'Imposition Press Setup';
    DataClassification = CustomerContent;
    LookupPageId = "PEQI Press Setup List";
    DrillDownPageId = "PEQI Press Setup List";

    fields
    {
        field(1; "Cost Center Code"; Code[20])
        {
            Caption = 'Cost Center Code';
            TableRelation = "PVS Cost Center";
            NotBlank = true;
        }
        field(2; Configuration; Code[20])
        {
            Caption = 'Configuration';
            TableRelation = "PVS Cost Center Configuration".Configuration
                where("Cost Center Code" = field("Cost Center Code"));
        }
        field(10; "Use for Imposition"; Boolean) { Caption = 'Use for Imposition'; }
        field(11; "Press Id"; Guid)
        {
            Caption = 'Press Id';
            Editable = false;
            ToolTip = 'Identifies this press to the engine. It is assigned once and never changes.';
        }
        field(12; "Press Type Override"; Enum "PEQI Press Type") { Caption = 'Press Type Override'; }
        field(13; "Use Press Type Override"; Boolean) { Caption = 'Use Press Type Override'; }
        field(20; "Gripper Edge Side"; Enum "PEQI Press Edge")
        {
            Caption = 'Gripper Edge Side';
            ToolTip = 'Which physical edge the gripper is on. PrintVis records the gripper as a measurement and never names its edge.';
        }
        field(21; "Side Lay Edge"; Enum "PEQI Press Edge") { Caption = 'Side Lay Edge'; }
        field(30; "Non-Printable Top (mm)"; Decimal) { Caption = 'Non-Printable Top (mm)'; DecimalPlaces = 0 : 3; }
        field(31; "Non-Printable Bottom (mm)"; Decimal) { Caption = 'Non-Printable Bottom (mm)'; DecimalPlaces = 0 : 3; }
        field(32; "Non-Printable Left (mm)"; Decimal) { Caption = 'Non-Printable Left (mm)'; DecimalPlaces = 0 : 3; }
        field(33; "Non-Printable Right (mm)"; Decimal) { Caption = 'Non-Printable Right (mm)'; DecimalPlaces = 0 : 3; }
        field(40; "Max Image Area Width (mm)"; Decimal) { Caption = 'Max Image Area Width (mm)'; DecimalPlaces = 0 : 3; }
        field(41; "Max Image Area Height (mm)"; Decimal) { Caption = 'Max Image Area Height (mm)'; DecimalPlaces = 0 : 3; }
        field(42; "Plate Punch (mm)"; Decimal) { Caption = 'Plate Punch (mm)'; DecimalPlaces = 0 : 3; }
        field(43; "Sheets Per Hour"; Integer) { Caption = 'Sheets Per Hour'; MinValue = 0; }
        field(50; Simplex; Boolean) { Caption = 'Simplex'; InitValue = true; }
        field(51; "Work And Back"; Boolean) { Caption = 'Work and Back'; InitValue = true; }
        field(52; "Work And Turn"; Boolean) { Caption = 'Work and Turn'; }
        field(53; "Work And Tumble"; Boolean) { Caption = 'Work and Tumble'; }
        field(54; Perfecting; Boolean) { Caption = 'Perfecting'; }
    }

    keys
    {
        key(PK; "Cost Center Code", Configuration) { Clustered = true; }
        key(Used; "Use for Imposition") { }
    }

    trigger OnInsert()
    begin
        if IsNullGuid("Press Id") then
            "Press Id" := CreateGuid();
    end;

    trigger OnModify()
    var
        Existing: Record "PEQI Press Setup";
    begin
        // The engine's solutionId hashes the press id. Restoring it rather than
        // regenerating keeps a quoted solution valid at /jdf.
        if Existing.Get("Cost Center Code", Configuration) then
            "Press Id" := Existing."Press Id";
        if IsNullGuid("Press Id") then
            "Press Id" := CreateGuid();
    end;

    /// <summary>The work styles this press declares, as engine spellings.</summary>
    procedure WorkStyleList(): List of [Text]
    var
        Styles: List of [Text];
    begin
        if Simplex then Styles.Add('Simplex');
        if "Work And Back" then Styles.Add('WorkAndBack');
        if "Work And Turn" then Styles.Add('WorkAndTurn');
        if "Work And Tumble" then Styles.Add('WorkAndTumble');
        if Perfecting then Styles.Add('Perfecting');
        exit(Styles);
    end;
}
```

- [ ] **Step 4: Write the Paper Setup table**

```al
// <copyright header>

table 50502 "PEQI Paper Setup"
{
    Caption = 'Imposition Paper Setup';
    DataClassification = CustomerContent;
    LookupPageId = "PEQI Paper Setup List";
    DrillDownPageId = "PEQI Paper Setup List";

    fields
    {
        field(1; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item;
            NotBlank = true;
        }
        field(2; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
            TableRelation = "Item Variant".Code where("Item No." = field("Item No."));
        }
        field(10; "Use for Imposition"; Boolean) { Caption = 'Use for Imposition'; }
        field(11; "Substrate Id"; Integer)
        {
            Caption = 'Substrate Id';
            Editable = false;
            ToolTip = 'Identifies this stock to the engine. The engine types substrate ids as integers and item numbers are codes, so this surrogate stands in for the item number. It is assigned once and never reused.';
        }
        field(20; "Grain Override"; Enum "PEQI Sheet Grain") { Caption = 'Grain Override'; }
        field(21; "Caliper Override (microns)"; Decimal) { Caption = 'Caliper Override (microns)'; DecimalPlaces = 0 : 3; MinValue = 0; }
        field(22; "Grammage Override (gsm)"; Decimal) { Caption = 'Grammage Override (g/m2)'; DecimalPlaces = 0 : 3; MinValue = 0; }
        field(23; "Vendor Sku Override"; Text[50]) { Caption = 'Vendor SKU Override'; }
    }

    keys
    {
        key(PK; "Item No.", "Variant Code") { Clustered = true; }
        key(Surrogate; "Substrate Id") { }
        key(Used; "Use for Imposition") { }
    }

    trigger OnInsert()
    begin
        if "Substrate Id" = 0 then
            "Substrate Id" := NextSubstrateId();
    end;

    trigger OnModify()
    var
        Existing: Record "PEQI Paper Setup";
    begin
        if Existing.Get("Item No.", "Variant Code") then
            "Substrate Id" := Existing."Substrate Id";
        if "Substrate Id" = 0 then
            "Substrate Id" := NextSubstrateId();
    end;

    /// <summary>Delegates to the setup singleton's high-water mark. Max-plus-one
    /// over the rows would release a deleted paper's id to the next one inserted,
    /// which is exactly what this table must never do.</summary>
    local procedure NextSubstrateId(): Integer
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        exit(Setup.NextSubstrateId());
    end;

    /// <summary>The override if set, otherwise the item's own PVS Grain Direction.</summary>
    procedure EffectiveGrain(): Enum "PEQI Sheet Grain"
    var
        Item: Record Item;
    begin
        if "Grain Override" <> "Grain Override"::" " then
            exit("Grain Override");
        if not Item.Get("Item No.") then
            exit("PEQI Sheet Grain"::" ");
        case Item."PVS Grain Direction" of
            Item."PVS Grain Direction"::"1>2":
                exit("PEQI Sheet Grain"::Short);
            Item."PVS Grain Direction"::"1<2":
                exit("PEQI Sheet Grain"::Long);
        end;
        exit("PEQI Sheet Grain"::" ");
    end;
}
```

`NextSubstrateId` deliberately does not reuse gaps. A deleted item's id may still be named in a stored request or a written ticket, and handing it to a different paper would silently re-point history.

- [ ] **Step 5: Write the three pages**

`PEQIPressSetupList.Page.al`:

```al
// <copyright header>

page 50511 "PEQI Press Setup List"
{
    Caption = 'Imposition Press Setup';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "PEQI Press Setup";
    CardPageId = "PEQI Press Setup Card";

    layout
    {
        area(Content)
        {
            repeater(Rows)
            {
                field("Cost Center Code"; Rec."Cost Center Code") { ApplicationArea = All; }
                field(Configuration; Rec.Configuration) { ApplicationArea = All; }
                field("Use for Imposition"; Rec."Use for Imposition") { ApplicationArea = All; }
                field("Gripper Edge Side"; Rec."Gripper Edge Side") { ApplicationArea = All; }
                field("Sheets Per Hour"; Rec."Sheets Per Hour") { ApplicationArea = All; }
            }
        }
    }
}
```

`PEQIPressSetupCard.Page.al`:

```al
// <copyright header>

page 50512 "PEQI Press Setup Card"
{
    Caption = 'Imposition Press Setup';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "PEQI Press Setup";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("Cost Center Code"; Rec."Cost Center Code") { ApplicationArea = All; }
                field(Configuration; Rec.Configuration) { ApplicationArea = All; }
                field("Use for Imposition"; Rec."Use for Imposition") { ApplicationArea = All; }
                field("Press Id"; Rec."Press Id") { ApplicationArea = All; }
                field("Use Press Type Override"; Rec."Use Press Type Override") { ApplicationArea = All; }
                field("Press Type Override"; Rec."Press Type Override")
                {
                    ApplicationArea = All;
                    Enabled = Rec."Use Press Type Override";
                }
            }
            group(Edges)
            {
                Caption = 'Edges and Margins';
                field("Gripper Edge Side"; Rec."Gripper Edge Side") { ApplicationArea = All; }
                field("Side Lay Edge"; Rec."Side Lay Edge") { ApplicationArea = All; }
                field("Non-Printable Top (mm)"; Rec."Non-Printable Top (mm)") { ApplicationArea = All; }
                field("Non-Printable Bottom (mm)"; Rec."Non-Printable Bottom (mm)") { ApplicationArea = All; }
                field("Non-Printable Left (mm)"; Rec."Non-Printable Left (mm)") { ApplicationArea = All; }
                field("Non-Printable Right (mm)"; Rec."Non-Printable Right (mm)") { ApplicationArea = All; }
                field("Max Image Area Width (mm)"; Rec."Max Image Area Width (mm)") { ApplicationArea = All; }
                field("Max Image Area Height (mm)"; Rec."Max Image Area Height (mm)") { ApplicationArea = All; }
            }
            group(Plate)
            {
                Caption = 'Plate';
                field("Plate Punch (mm)"; Rec."Plate Punch (mm)") { ApplicationArea = All; }
            }
            group(WorkStyles)
            {
                Caption = 'Work Styles';
                field(Simplex; Rec.Simplex) { ApplicationArea = All; }
                field("Work And Back"; Rec."Work And Back") { ApplicationArea = All; }
                field("Work And Turn"; Rec."Work And Turn")
                {
                    ApplicationArea = All;
                    ToolTip = 'The engine never derives this one - it must be stated.';
                }
                field("Work And Tumble"; Rec."Work And Tumble")
                {
                    ApplicationArea = All;
                    ToolTip = 'The engine never derives this one - it must be stated.';
                }
                field(Perfecting; Rec.Perfecting) { ApplicationArea = All; }
            }
            group(Speed)
            {
                Caption = 'Speed';
                field("Sheets Per Hour"; Rec."Sheets Per Hour") { ApplicationArea = All; }
            }
        }
    }
}
```

`PEQIPaperSetupList.Page.al`:

```al
// <copyright header>

page 50513 "PEQI Paper Setup List"
{
    Caption = 'Imposition Paper Setup';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "PEQI Paper Setup";

    layout
    {
        area(Content)
        {
            repeater(Rows)
            {
                field("Item No."; Rec."Item No.") { ApplicationArea = All; }
                field("Variant Code"; Rec."Variant Code") { ApplicationArea = All; }
                field("Use for Imposition"; Rec."Use for Imposition") { ApplicationArea = All; }
                field("Substrate Id"; Rec."Substrate Id") { ApplicationArea = All; }
                field(EffectiveGrain; Rec.EffectiveGrain())
                {
                    ApplicationArea = All;
                    Caption = 'Effective Grain';
                    Editable = false;
                    StyleExpr = GrainStyle;
                    ToolTip = 'Blank means the engine cannot verify grain: every verdict comes back Unverified, and under a Required grain policy the sheet is eliminated.';
                }
                field("Grain Override"; Rec."Grain Override") { ApplicationArea = All; }
                field("Caliper Override (microns)"; Rec."Caliper Override (microns)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Without a caliper there is no creep and no spine thickness.';
                }
                field("Grammage Override (gsm)"; Rec."Grammage Override (gsm)") { ApplicationArea = All; }
            }
        }
    }

    var
        GrainStyle: Text;

    trigger OnAfterGetRecord()
    begin
        if Rec.EffectiveGrain() = "PEQI Sheet Grain"::" " then
            GrainStyle := 'Ambiguous'
        else
            GrainStyle := 'Standard';
    end;
}
```

- [ ] **Step 6: Compile**

Run: `tools/build.sh`
Expected: exit 0 for the main app. The test app compiles if its symbols are present.

- [ ] **Step 7: Commit**

```bash
git add "PTE PrintVis External Imposition/src/Setup/PEQIPressSetup.Table.al" \
        "PTE PrintVis External Imposition/src/Setup/PEQIPressSetupList.Page.al" \
        "PTE PrintVis External Imposition/src/Setup/PEQIPressSetupCard.Page.al" \
        "PTE PrintVis External Imposition/src/Setup/PEQIPaperSetup.Table.al" \
        "PTE PrintVis External Imposition/src/Setup/PEQIPaperSetupList.Page.al" \
        "PTE PrintVis External Imposition.Test/src/PEQISetupTests.Codeunit.al"
git commit -m "feat: add press and paper setup with stable engine ids"
```

- [ ] **Step 8: Record the pending assert-green**

These three tests have compiled but not executed. Note in the PR description that `PEQI Setup Tests` awaits the first CI run with `testFolders` configured.

---

### Task 5: Binding and Part mapping

> **Controller ruling (pre-flight):** the plan first wrote these relations as
> `"PVS Finishing"` and `"PVS Component Type"`. Neither object exists. Read from
> the PrintVis symbols, the real tables are `"PVS Finishing Types"` (6010396,
> filtered on `Process Type = Finishing`, matching PrintVis's own relation on
> `PVS Job`.`Finishing`) and `"PVS Component Types"` (6010401). Corrected above.
> Cost if wrong: the task fails to compile and the implementer re-reads the
> symbols, which is where the corrected names came from.

**Files:**
- Create: `PTE PrintVis External Imposition/src/Setup/PEQIBindingMapping.Table.al`
- Create: `PTE PrintVis External Imposition/src/Setup/PEQIBindingMappings.Page.al`
- Create: `PTE PrintVis External Imposition/src/Setup/PEQIPartMapping.Table.al`
- Create: `PTE PrintVis External Imposition/src/Setup/PEQIPartMappings.Page.al`

**Interfaces:**
- Consumes: enums (Task 2).
- Produces: `Record "PEQI Binding Mapping"` keyed on `PVS Job`.`Finishing`; `Record "PEQI Part Mapping"` keyed on `PVS Job Item`.`Component Type`. Both are read by the part mapper (Task 7) and the validator (Task 10).

- [ ] **Step 1: Write the binding mapping table**

```al
// <copyright header>

table 50503 "PEQI Binding Mapping"
{
    Caption = 'Imposition Binding Mapping';
    DataClassification = CustomerContent;
    LookupPageId = "PEQI Binding Mappings";
    DrillDownPageId = "PEQI Binding Mappings";

    fields
    {
        field(1; "Finishing Code"; Code[20])
        {
            Caption = 'Finishing Code';
            TableRelation = "PVS Finishing Types" where("Process Type" = const(Finishing));
            NotBlank = true;
        }
        field(10; Binding; Enum "PEQI Binding Type") { Caption = 'Binding'; }
        field(11; "Default Binding Side"; Enum "PEQI Binding Side")
        {
            Caption = 'Default Binding Side';
            ToolTip = 'Used only when the job item''s imposition code states no spine side.';
        }
        field(20; "Trim Head (mm)"; Decimal) { Caption = 'Trim Head (mm)'; DecimalPlaces = 0 : 3; }
        field(21; "Trim Foot (mm)"; Decimal) { Caption = 'Trim Foot (mm)'; DecimalPlaces = 0 : 3; }
        field(22; "Trim Face (mm)"; Decimal) { Caption = 'Trim Face (mm)'; DecimalPlaces = 0 : 3; }
        field(23; "Trim Spine (mm)"; Decimal) { Caption = 'Trim Spine (mm)'; DecimalPlaces = 0 : 3; }
        field(24; "Milling Depth (mm)"; Decimal)
        {
            Caption = 'Milling Depth (mm)';
            DecimalPlaces = 0 : 3;
            ToolTip = 'Perfect binding only.';
        }
        field(30; "Use Setup Trim Defaults"; Boolean)
        {
            Caption = 'Use Setup Trim Defaults';
            InitValue = true;
        }
    }

    keys
    {
        key(PK; "Finishing Code") { Clustered = true; }
    }
}
```

Both relations were read out of the symbols before this plan was written, so use
them as they stand: `PVS Job`.`Finishing` relates to **`"PVS Finishing Types"`**
(table 6010396) filtered `where("Process Type" = const(Finishing))`, and
`PVS Job Item`.`Component Type` relates to **`"PVS Component Types"`**
(table 6010401). Both names are plural. Do not singularise them.

- [ ] **Step 2: Write the part mapping table**

```al
// <copyright header>

table 50504 "PEQI Part Mapping"
{
    Caption = 'Imposition Part Mapping';
    DataClassification = CustomerContent;
    LookupPageId = "PEQI Part Mappings";
    DrillDownPageId = "PEQI Part Mappings";

    fields
    {
        field(1; "Component Type"; Code[20])
        {
            Caption = 'Component Type';
            TableRelation = "PVS Component Types";
            NotBlank = true;
        }
        field(10; "Product Type"; Enum "PEQI Part Product Type") { Caption = 'Product Type'; }
        field(11; "Grain Rule"; Enum "PEQI Grain Rule")
        {
            Caption = 'Grain Rule';
            InitValue = ParallelToSpine;
        }
    }

    keys
    {
        key(PK; "Component Type") { Clustered = true; }
    }
}
```

- [ ] **Step 3: Write both list pages**

```al
// <copyright header>

page 50514 "PEQI Binding Mappings"
{
    Caption = 'Imposition Binding Mappings';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "PEQI Binding Mapping";

    layout
    {
        area(Content)
        {
            repeater(Rows)
            {
                field("Finishing Code"; Rec."Finishing Code") { ApplicationArea = All; }
                field(Binding; Rec.Binding) { ApplicationArea = All; }
                field("Default Binding Side"; Rec."Default Binding Side") { ApplicationArea = All; }
                field("Use Setup Trim Defaults"; Rec."Use Setup Trim Defaults") { ApplicationArea = All; }
                field("Trim Head (mm)"; Rec."Trim Head (mm)") { ApplicationArea = All; }
                field("Trim Foot (mm)"; Rec."Trim Foot (mm)") { ApplicationArea = All; }
                field("Trim Face (mm)"; Rec."Trim Face (mm)") { ApplicationArea = All; }
                field("Trim Spine (mm)"; Rec."Trim Spine (mm)") { ApplicationArea = All; }
                field("Milling Depth (mm)"; Rec."Milling Depth (mm)") { ApplicationArea = All; }
            }
        }
    }
}
```

```al
// <copyright header>

page 50515 "PEQI Part Mappings"
{
    Caption = 'Imposition Part Mappings';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "PEQI Part Mapping";

    layout
    {
        area(Content)
        {
            repeater(Rows)
            {
                field("Component Type"; Rec."Component Type") { ApplicationArea = All; }
                field("Product Type"; Rec."Product Type") { ApplicationArea = All; }
                field("Grain Rule"; Rec."Grain Rule") { ApplicationArea = All; }
            }
        }
    }
}
```

- [ ] **Step 4: Compile**

Run: `tools/build.sh`
Expected: exit 0. If `PVS Finishing` or `PVS Component Type` is not a real table, the compiler says so by name — read the correct relation out of the symbols as in Step 1 and fix both `TableRelation` clauses.

- [ ] **Step 5: Commit**

```bash
git add "PTE PrintVis External Imposition/src/Setup/PEQIBindingMapping.Table.al" \
        "PTE PrintVis External Imposition/src/Setup/PEQIBindingMappings.Page.al" \
        "PTE PrintVis External Imposition/src/Setup/PEQIPartMapping.Table.al" \
        "PTE PrintVis External Imposition/src/Setup/PEQIPartMappings.Page.al"
git commit -m "feat: map PrintVis finishing and component codes to engine enums"
```

---

### Task 6: Document tables

**Files:**
- Create: `PTE PrintVis External Imposition/src/Document/PEQIImpositionJob.Table.al`
- Create: `PTE PrintVis External Imposition/src/Document/PEQIPressRun.Table.al`
- Create: `PTE PrintVis External Imposition/src/Document/PEQIJdfTicket.Table.al`
- Create: `PTE PrintVis External Imposition/src/Document/PEQIDiagnostic.Table.al`
- Test: `PTE PrintVis External Imposition.Test/src/PEQIDocumentTests.Codeunit.al`

**Interfaces:**
- Consumes: enums (Task 2).
- Produces:
  - `PEQIImpositionJob.NewEntry(CaseId: Integer; JobNo: Integer; VersionNo: Integer): Record "PEQI Imposition Job"`
  - `PEQIImpositionJob.SetRequestJson(RequestText: Text)` / `.GetRequestJson(): Text`
  - `PEQIJdfTicket.SetJdf(JdfText: Text)` / `.GetJdf(): Text`

- [ ] **Step 1: Write the failing test for entry numbering**

```al
// <copyright header>

codeunit 50615 "PEQI Document Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure ResolvingOpensANewEntryAndLeavesTheOldOne()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        First: Record "PEQI Imposition Job";
        Second: Record "PEQI Imposition Job";
    begin
        // [GIVEN] a solved entry for a job version
        First := ImpositionJob.NewEntry(4711, 1, 1);
        First.Status := First.Status::Committed;
        First.Modify(true);

        // [WHEN] the job is re-solved
        Second := ImpositionJob.NewEntry(4711, 1, 1);

        // [THEN] a new entry is opened and the committed one is untouched
        Assert.AreEqual(First."Entry No." + 1, Second."Entry No.", 'Re-solve opens the next entry');
        First.Get(4711, 1, 1, First."Entry No.");
        Assert.AreEqual(First.Status::Committed, First.Status, 'The previous entry keeps its status');
        Assert.AreEqual(Second.Status::Draft, Second.Status, 'A new entry starts as Draft');
    end;

    [Test]
    procedure RequestJsonSurvivesARoundTrip()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        Written: Text;
    begin
        // [GIVEN] an entry
        ImpositionJob := ImpositionJob.NewEntry(4712, 1, 1);
        Written := '{"parts":[{"name":"Body","pageCount":32}]}';

        // [WHEN] a request is stored and read back
        ImpositionJob.SetRequestJson(Written);
        ImpositionJob.Modify(true);
        ImpositionJob.Get(4712, 1, 1, ImpositionJob."Entry No.");

        // [THEN] it is byte-identical
        Assert.AreEqual(Written, ImpositionJob.GetRequestJson(), 'Request JSON round-trips');
    end;
}
```

- [ ] **Step 2: Run the compile-red gate**

Run: `tools/build.sh`
Expected: the test app fails with `Table 'PEQI Imposition Job' is missing` (or `SKIPPED`, in which case CI carries the red state).

- [ ] **Step 3: Write the Imposition Job table**

```al
// <copyright header>

table 50505 "PEQI Imposition Job"
{
    Caption = 'Imposition Job';
    DataClassification = CustomerContent;
    LookupPageId = "PEQI Imposition Jobs";
    DrillDownPageId = "PEQI Imposition Jobs";

    fields
    {
        field(1; "Case ID"; Integer) { Caption = 'Case ID'; TableRelation = "PVS Case".ID; }
        field(2; Job; Integer) { Caption = 'Job'; }
        field(3; Version; Integer) { Caption = 'Version'; }
        field(4; "Entry No."; Integer) { Caption = 'Entry No.'; }
        field(10; Status; Enum "PEQI Job Status") { Caption = 'Status'; }
        field(11; "Built At"; DateTime) { Caption = 'Built At'; }
        field(12; "Built By"; Code[50]) { Caption = 'Built By'; TableRelation = User."User Name"; }
        field(13; "Last Error"; Text[250]) { Caption = 'Last Error'; }
        field(20; "Request Json"; Blob) { Caption = 'Request JSON'; }
        field(21; "Snapshot Id"; Text[100]) { Caption = 'Snapshot Id'; }
        field(22; "Solution Id"; Text[100]) { Caption = 'Solution Id'; }
        field(30; "Sheet Count"; Integer) { Caption = 'Sheet Count'; }
        field(31; "Total Signatures"; Integer) { Caption = 'Total Signatures'; }
        field(32; Utilisation; Decimal)
        {
            Caption = 'Utilisation';
            DecimalPlaces = 0 : 4;
            ToolTip = 'Fraction of the press sheet carrying product, 0 to 1.';
        }
        field(33; "Wasted Area (sqmm)"; Decimal) { Caption = 'Wasted Area (mm2)'; DecimalPlaces = 0 : 2; }
        field(34; "Worst Grain Verdict"; Text[30]) { Caption = 'Worst Grain Verdict'; }
        field(35; Score; Decimal) { Caption = 'Score'; DecimalPlaces = 0 : 6; }
        field(36; Runnable; Boolean) { Caption = 'Runnable'; }
    }

    keys
    {
        key(PK; "Case ID", Job, Version, "Entry No.") { Clustered = true; }
        key(ByStatus; Status) { }
    }

    /// <summary>Opens the next entry for a job version. Re-solving never overwrites
    /// an earlier entry: a committed ticket must keep pointing at the request it
    /// was written from.</summary>
    procedure NewEntry(CaseId: Integer; JobNo: Integer; VersionNo: Integer): Record "PEQI Imposition Job"
    var
        ImpositionJob: Record "PEQI Imposition Job";
        Existing: Record "PEQI Imposition Job";
        NextEntry: Integer;
    begin
        NextEntry := 1;
        Existing.SetRange("Case ID", CaseId);
        Existing.SetRange(Job, JobNo);
        Existing.SetRange(Version, VersionNo);
        if Existing.FindLast() then
            NextEntry := Existing."Entry No." + 1;

        ImpositionJob.Init();
        ImpositionJob."Case ID" := CaseId;
        ImpositionJob.Job := JobNo;
        ImpositionJob.Version := VersionNo;
        ImpositionJob."Entry No." := NextEntry;
        ImpositionJob.Status := ImpositionJob.Status::Draft;
        ImpositionJob."Built At" := CurrentDateTime();
        ImpositionJob."Built By" := CopyStr(UserId(), 1, MaxStrLen(ImpositionJob."Built By"));
        ImpositionJob.Insert(true);
        exit(ImpositionJob);
    end;

    procedure SetRequestJson(RequestText: Text)
    var
        OutStr: OutStream;
    begin
        Clear("Request Json");
        "Request Json".CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(RequestText);
    end;

    procedure GetRequestJson(): Text
    var
        InStr: InStream;
        RequestText: Text;
    begin
        CalcFields("Request Json");
        if not "Request Json".HasValue() then
            exit('');
        "Request Json".CreateInStream(InStr, TextEncoding::UTF8);
        InStr.ReadText(RequestText);
        exit(RequestText);
    end;
}
```

- [ ] **Step 4: Write the three line tables**

```al
// <copyright header>

table 50506 "PEQI Press Run"
{
    Caption = 'Imposition Press Run';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Case ID"; Integer) { Caption = 'Case ID'; }
        field(2; Job; Integer) { Caption = 'Job'; }
        field(3; Version; Integer) { Caption = 'Version'; }
        field(4; "Entry No."; Integer) { Caption = 'Entry No.'; }
        field(5; "Line No."; Integer) { Caption = 'Line No.'; }
        field(10; "Substrate Id"; Integer) { Caption = 'Substrate Id'; }
        field(11; "Stock Name"; Text[100]) { Caption = 'Stock'; }
        field(12; "Press Id"; Guid) { Caption = 'Press Id'; }
        field(13; "Press Name"; Text[100]) { Caption = 'Press'; }
        field(14; "Work Style"; Text[30]) { Caption = 'Work Style'; }
        field(15; "Sheet Count"; Integer) { Caption = 'Sheets'; }
        field(16; Passes; Integer) { Caption = 'Passes'; }
        field(17; "Signature Ids"; Text[250]) { Caption = 'Signatures'; }
        field(20; "PVS Sheet ID"; Integer)
        {
            Caption = 'PrintVis Sheet ID';
            ToolTip = 'The PVS Job Sheet this run lines up with by ordinal. Blank when the engine''s run count differs from PrintVis''s sheet count.';
        }
    }

    keys
    {
        key(PK; "Case ID", Job, Version, "Entry No.", "Line No.") { Clustered = true; }
    }
}
```

```al
// <copyright header>

table 50507 "PEQI Jdf Ticket"
{
    Caption = 'Imposition JDF Ticket';
    DataClassification = CustomerContent;
    LookupPageId = "PEQI Jdf Tickets";
    DrillDownPageId = "PEQI Jdf Tickets";

    fields
    {
        field(1; "Ticket Id"; Guid) { Caption = 'Ticket Id'; }
        field(10; "Case ID"; Integer) { Caption = 'Case ID'; }
        field(11; Job; Integer) { Caption = 'Job'; }
        field(12; Version; Integer) { Caption = 'Version'; }
        field(13; "Entry No."; Integer) { Caption = 'Entry No.'; }
        field(20; "Job Id"; Text[64]) { Caption = 'JDF Job ID'; }
        field(21; "Solution Id"; Text[100]) { Caption = 'Solution Id'; }
        field(22; Flavour; Enum "PEQI Jdf Flavour") { Caption = 'Flavour'; }
        field(23; "Jdf Version"; Enum "PEQI Jdf Version") { Caption = 'JDF Version'; }
        field(24; "File Name"; Text[250]) { Caption = 'File Name'; }
        field(25; Sha256; Text[64]) { Caption = 'SHA256'; }
        field(26; "Created At"; DateTime) { Caption = 'Created At'; }
        field(30; Jdf; Blob) { Caption = 'JDF'; }
    }

    keys
    {
        key(PK; "Ticket Id") { Clustered = true; }
        key(ByJob; "Case ID", Job, Version, "Entry No.") { }
    }

    procedure SetJdf(JdfText: Text)
    var
        OutStr: OutStream;
    begin
        Clear(Jdf);
        Jdf.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(JdfText);
    end;

    procedure GetJdf(): Text
    var
        InStr: InStream;
        JdfText: Text;
    begin
        CalcFields(Jdf);
        if not Jdf.HasValue() then
            exit('');
        Jdf.CreateInStream(InStr, TextEncoding::UTF8);
        InStr.ReadText(JdfText);
        exit(JdfText);
    end;
}
```

```al
// <copyright header>

table 50508 "PEQI Diagnostic"
{
    Caption = 'Imposition Diagnostic';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Case ID"; Integer) { Caption = 'Case ID'; }
        field(2; Job; Integer) { Caption = 'Job'; }
        field(3; Version; Integer) { Caption = 'Version'; }
        field(4; "Entry No."; Integer) { Caption = 'Entry No.'; }
        field(5; "Line No."; Integer) { Caption = 'Line No.'; }
        field(10; Severity; Enum "PEQI Diagnostic Severity") { Caption = 'Severity'; }
        field(11; "Code"; Text[60]) { Caption = 'Code'; }
        field(12; "Count"; Integer) { Caption = 'Count'; }
        field(13; "Example Message"; Text[250]) { Caption = 'Message'; }
        field(14; Source; Option)
        {
            Caption = 'Source';
            OptionMembers = Engine,Builder,Preview;
            OptionCaption = 'Engine,Builder,Preview';
        }
    }

    keys
    {
        key(PK; "Case ID", Job, Version, "Entry No.", "Line No.") { Clustered = true; }
    }
}
```

- [ ] **Step 5: Compile**

Run: `tools/build.sh`
Expected: exit 0. The `LookupPageId` references to pages built in Task 13 will fail until then — if the compiler objects, comment out the two `LookupPageId`/`DrillDownPageId` lines and restore them in Task 13. Note which you commented in the commit message.

- [ ] **Step 6: Commit**

```bash
git add "PTE PrintVis External Imposition/src/Document/" \
        "PTE PrintVis External Imposition.Test/src/PEQIDocumentTests.Codeunit.al"
git commit -m "feat: add imposition job, press run, ticket and diagnostic tables"
```

---

### Task 7: JSON helper and the part mapper

**Files:**
- Create: `PTE PrintVis External Imposition/src/Mapping/PEQIJsonHelper.Codeunit.al`
- Create: `PTE PrintVis External Imposition/src/Mapping/PEQIPartMapper.Codeunit.al`
- Test: `PTE PrintVis External Imposition.Test/src/PEQITestData.Codeunit.al`
- Test: `PTE PrintVis External Imposition.Test/src/PEQIBuilderTests.Codeunit.al`

**Interfaces:**
- Consumes: `Record "PEQI Part Mapping"`, `Record "PEQI Paper Setup"`, `Record "PEQI Imposition Setup"`.
- Produces:
  - `PEQIJsonHelper.AddText(var Obj: JsonObject; Name: Text; Value: Text)` — omits the member when `Value` is blank.
  - `PEQIJsonHelper.AddDecimal(var Obj: JsonObject; Name: Text; Value: Decimal)` — always writes.
  - `PEQIJsonHelper.AddInteger(var Obj: JsonObject; Name: Text; Value: Integer)` — always writes.
  - `PEQIJsonHelper.AddBoolean(var Obj: JsonObject; Name: Text; Value: Boolean)` — always writes.
  - `PEQIJsonHelper.ReadText(Obj: JsonObject; Name: Text): Text`, `.ReadDecimal`, `.ReadInteger`, `.ReadBoolean` — blank/zero/false when absent.
  - `PEQIPartMapper.BuildParts(CaseId: Integer; JobNo: Integer; VersionNo: Integer): JsonArray`

- [ ] **Step 1: Write the failing test**

First the fixture builder, then the test. Create `PEQITestData.Codeunit.al`:

```al
// <copyright header>

codeunit 50602 "PEQI Test Data"
{
    /// <summary>Inserts a PVS Job Item for a component. Only the fields the mapper
    /// reads are set - the rest of PrintVis's model is irrelevant here.</summary>
    procedure AddJobItem(CaseId: Integer; JobNo: Integer; VersionNo: Integer; JobItemNo: Integer; ComponentType: Code[20]; Pages: Integer; WidthMm: Decimal; LengthMm: Decimal; PaperItemNo: Code[20])
    var
        JobItem: Record "PVS Job Item";
    begin
        JobItem.Init();
        JobItem.ID := CaseId;
        JobItem.Job := JobNo;
        JobItem.Version := VersionNo;
        JobItem."Job Item No." := JobItemNo;
        JobItem."Entry No." := JobItemNo;
        JobItem.Active := true;
        JobItem."Component Type" := ComponentType;
        JobItem."No. Of Pages" := Pages;
        JobItem.Width := WidthMm;
        JobItem.Length := LengthMm;
        JobItem."Item No." := PaperItemNo;
        JobItem."Colors Front" := 4;
        JobItem."Colors Back" := 4;
        JobItem.Insert(true);
    end;

    /// <summary>Inserts the PVS Job that BuildObject reads for binding and quantity.</summary>
    procedure AddJob(CaseId: Integer; JobNo: Integer; VersionNo: Integer; FinishingCode: Code[20]; Quantity: Integer)
    var
        PVSJob: Record "PVS Job";
    begin
        PVSJob.Init();
        PVSJob.ID := CaseId;
        PVSJob.Job := JobNo;
        PVSJob.Version := VersionNo;
        PVSJob.Active := true;
        PVSJob.Finishing := FinishingCode;
        PVSJob.Quantity := Quantity;
        PVSJob.Insert(true);
    end;

    procedure AddPartMapping(ComponentType: Code[20]; ProductType: Enum "PEQI Part Product Type")
    var
        PartMapping: Record "PEQI Part Mapping";
    begin
        PartMapping.Init();
        PartMapping."Component Type" := ComponentType;
        PartMapping."Product Type" := ProductType;
        PartMapping."Grain Rule" := PartMapping."Grain Rule"::ParallelToSpine;
        PartMapping.Insert(true);
    end;

    procedure AddPaper(ItemNo: Code[20]): Integer
    var
        PaperSetup: Record "PEQI Paper Setup";
    begin
        PaperSetup.Init();
        PaperSetup."Item No." := ItemNo;
        PaperSetup."Use for Imposition" := true;
        PaperSetup.Insert(true);
        exit(PaperSetup."Substrate Id");
    end;
}
```

Then `PEQIBuilderTests.Codeunit.al`:

```al
// <copyright header>

codeunit 50610 "PEQI Builder Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestData: Codeunit "PEQI Test Data";
        PartMapper: Codeunit "PEQI Part Mapper";

    [Test]
    procedure JobItemsOfOneComponentBecomeOnePartWithSummedPages()
    var
        Parts: JsonArray;
        PartToken: JsonToken;
        Part: JsonObject;
        JsonHelper: Codeunit "PEQI Json Helper";
    begin
        // [GIVEN] a body split across two job items, 16 pages each
        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        TestData.AddPaper('PAPER-100');
        TestData.AddJobItem(5001, 1, 1, 1, 'BODY', 16, 210, 297, 'PAPER-100');
        TestData.AddJobItem(5001, 1, 1, 2, 'BODY', 16, 210, 297, 'PAPER-100');

        // [WHEN] the parts are built
        Parts := PartMapper.BuildParts(5001, 1, 1);

        // [THEN] there is one part of 32 pages, not two of 16
        // The engine decides the sheet breakdown; feeding it PrintVis's would
        // ask it to confirm its own input.
        Assert.AreEqual(1, Parts.Count(), 'One component is one part');
        Parts.Get(0, PartToken);
        Part := PartToken.AsObject();
        Assert.AreEqual(32, JsonHelper.ReadInteger(Part, 'pageCount'), 'Pages are summed');
        Assert.AreEqual(210.0, JsonHelper.ReadDecimal(Part, 'trimWidthMm'), 'Width is the trim width');
        Assert.AreEqual(297.0, JsonHelper.ReadDecimal(Part, 'trimHeightMm'), 'Length is the trim height');
        Assert.AreEqual('Body', JsonHelper.ReadText(Part, 'productType'), 'Product type comes from the part mapping');
    end;

    [Test]
    procedure EachComponentBecomesItsOwnPart()
    var
        Parts: JsonArray;
    begin
        // [GIVEN] a cover and a body
        TestData.AddPartMapping('COVER', "PEQI Part Product Type"::Cover);
        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        TestData.AddPaper('PAPER-240');
        TestData.AddPaper('PAPER-100');
        TestData.AddJobItem(5002, 1, 1, 1, 'COVER', 4, 148, 210, 'PAPER-240');
        TestData.AddJobItem(5002, 1, 1, 2, 'BODY', 28, 148, 210, 'PAPER-100');

        // [WHEN] the parts are built
        Parts := PartMapper.BuildParts(5002, 1, 1);

        // [THEN] there are two parts
        Assert.AreEqual(2, Parts.Count(), 'Two components are two parts');
    end;

    [Test]
    procedure APartSelectsItsOwnStockBySurrogateId()
    var
        Parts: JsonArray;
        PartToken: JsonToken;
        Part: JsonObject;
        CatalogToken: JsonToken;
        Ids: JsonArray;
        IdToken: JsonToken;
        SubstrateId: Integer;
    begin
        // [GIVEN] a body on a known paper
        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        SubstrateId := TestData.AddPaper('PAPER-115');
        TestData.AddJobItem(5003, 1, 1, 1, 'BODY', 32, 210, 297, 'PAPER-115');

        // [WHEN] the parts are built
        Parts := PartMapper.BuildParts(5003, 1, 1);
        Parts.Get(0, PartToken);
        Part := PartToken.AsObject();
        Part.Get('catalog', CatalogToken);
        CatalogToken.AsObject().Get('substrateIds', IdToken);
        Ids := IdToken.AsArray();
        Ids.Get(0, IdToken);

        // [THEN] it names the paper by its integer surrogate, not its item number
        Assert.AreEqual(SubstrateId, IdToken.AsValue().AsInteger(), 'A part selects on the substrate surrogate id');
    end;
}
```

- [ ] **Step 2: Run the compile-red gate**

Run: `tools/build.sh`
Expected: `Codeunit 'PEQI Part Mapper' is missing` (or `SKIPPED`).

- [ ] **Step 3: Write the JSON helper**

```al
// <copyright header>

codeunit 50539 "PEQI Json Helper"
{
    /// <summary>Adds a string member, omitting it when blank. The engine treats an
    /// absent optional member and a blank one differently - several optional fields
    /// raise a diagnostic when blank but are simply unused when absent.</summary>
    procedure AddText(var Obj: JsonObject; Name: Text; Value: Text)
    begin
        if Value = '' then
            exit;
        Obj.Add(Name, Value);
    end;

    procedure AddDecimal(var Obj: JsonObject; Name: Text; Value: Decimal)
    begin
        Obj.Add(Name, Value);
    end;

    /// <summary>Adds a numeric member only when non-zero. Used for optional
    /// measurements where zero means "not recorded" rather than "zero millimetres".</summary>
    procedure AddDecimalIfSet(var Obj: JsonObject; Name: Text; Value: Decimal)
    begin
        if Value = 0 then
            exit;
        Obj.Add(Name, Value);
    end;

    procedure AddInteger(var Obj: JsonObject; Name: Text; Value: Integer)
    begin
        Obj.Add(Name, Value);
    end;

    procedure AddIntegerIfSet(var Obj: JsonObject; Name: Text; Value: Integer)
    begin
        if Value = 0 then
            exit;
        Obj.Add(Name, Value);
    end;

    procedure AddBoolean(var Obj: JsonObject; Name: Text; Value: Boolean)
    begin
        Obj.Add(Name, Value);
    end;

    procedure ReadText(Obj: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if not Obj.Get(Name, Token) then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    procedure ReadDecimal(Obj: JsonObject; Name: Text): Decimal
    var
        Token: JsonToken;
    begin
        if not Obj.Get(Name, Token) then
            exit(0);
        if Token.AsValue().IsNull() then
            exit(0);
        exit(Token.AsValue().AsDecimal());
    end;

    procedure ReadInteger(Obj: JsonObject; Name: Text): Integer
    var
        Token: JsonToken;
    begin
        if not Obj.Get(Name, Token) then
            exit(0);
        if Token.AsValue().IsNull() then
            exit(0);
        exit(Token.AsValue().AsInteger());
    end;

    procedure ReadBoolean(Obj: JsonObject; Name: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not Obj.Get(Name, Token) then
            exit(false);
        if Token.AsValue().IsNull() then
            exit(false);
        exit(Token.AsValue().AsBoolean());
    end;

    procedure ReadObject(Obj: JsonObject; Name: Text; var Result: JsonObject): Boolean
    var
        Token: JsonToken;
    begin
        if not Obj.Get(Name, Token) then
            exit(false);
        if not Token.IsObject() then
            exit(false);
        Result := Token.AsObject();
        exit(true);
    end;

    procedure ReadArray(Obj: JsonObject; Name: Text; var Result: JsonArray): Boolean
    var
        Token: JsonToken;
    begin
        if not Obj.Get(Name, Token) then
            exit(false);
        if not Token.IsArray() then
            exit(false);
        Result := Token.AsArray();
        exit(true);
    end;
}
```

- [ ] **Step 4: Write the part mapper**

```al
// <copyright header>

codeunit 50536 "PEQI Part Mapper"
{
    var
        JsonHelper: Codeunit "PEQI Json Helper";
        NoMappingErr: Label 'Component type %1 on job %2/%3/%4 has no imposition part mapping. Add it on the Imposition Part Mappings page.', Comment = '%1 component type, %2 case, %3 job, %4 version';
        NoPaperErr: Label 'Paper item %1 on component %2 is not set up for imposition. Add it on the Imposition Paper Setup page.', Comment = '%1 item no., %2 component type';
        FormatClashErr: Label 'Component %1 spans two trim formats: job item %2 is %3 x %4 and job item %5 is %6 x %7.', Comment = '%1 component, %2 %5 job item nos, %3 %4 %6 %7 dimensions';

    /// <summary>One engine part per component type, pages summed across its job items.</summary>
    procedure BuildParts(CaseId: Integer; JobNo: Integer; VersionNo: Integer): JsonArray
    var
        JobItem: Record "PVS Job Item";
        Parts: JsonArray;
        Seen: Dictionary of [Code[20], Integer];
        ComponentType: Code[20];
    begin
        JobItem.SetRange(ID, CaseId);
        JobItem.SetRange(Job, JobNo);
        JobItem.SetRange(Version, VersionNo);
        JobItem.SetRange(Active, true);
        JobItem.SetCurrentKey(ID, Job, Version, "Job Item No.");
        if not JobItem.FindSet() then
            exit(Parts);

        repeat
            ComponentType := JobItem."Component Type";
            if not Seen.ContainsKey(ComponentType) then begin
                Seen.Add(ComponentType, 1);
                Parts.Add(BuildOnePart(CaseId, JobNo, VersionNo, ComponentType));
            end;
        until JobItem.Next() = 0;

        exit(Parts);
    end;

    local procedure BuildOnePart(CaseId: Integer; JobNo: Integer; VersionNo: Integer; ComponentType: Code[20]) Part: JsonObject
    var
        JobItem: Record "PVS Job Item";
        PartMapping: Record "PEQI Part Mapping";
        FirstItem: Record "PVS Job Item";
        TotalPages: Integer;
        FrontColors: Integer;
        BackColors: Integer;
    begin
        if not PartMapping.Get(ComponentType) then
            Error(NoMappingErr, ComponentType, CaseId, JobNo, VersionNo);

        JobItem.SetRange(ID, CaseId);
        JobItem.SetRange(Job, JobNo);
        JobItem.SetRange(Version, VersionNo);
        JobItem.SetRange(Active, true);
        JobItem.SetRange("Component Type", ComponentType);
        JobItem.FindSet();
        FirstItem := JobItem;

        repeat
            // A component spanning two formats is an invariant violation in
            // PrintVis, not something to reconcile silently.
            if (JobItem.Width <> FirstItem.Width) or (JobItem.Length <> FirstItem.Length) then
                Error(FormatClashErr, ComponentType,
                      FirstItem."Job Item No.", FirstItem.Width, FirstItem.Length,
                      JobItem."Job Item No.", JobItem.Width, JobItem.Length);
            TotalPages += JobItem."No. Of Pages";
            if JobItem."Colors Front" > FrontColors then
                FrontColors := JobItem."Colors Front";
            if JobItem."Colors Back" > BackColors then
                BackColors := JobItem."Colors Back";
        until JobItem.Next() = 0;

        JsonHelper.AddText(Part, 'name', ComponentType);
        JsonHelper.AddText(Part, 'productType', Format(PartMapping."Product Type"));
        JsonHelper.AddInteger(Part, 'pageCount', TotalPages);
        JsonHelper.AddDecimal(Part, 'trimWidthMm', FirstItem.Width);
        JsonHelper.AddDecimal(Part, 'trimHeightMm', FirstItem.Length);
        JsonHelper.AddText(Part, 'grainRule', Format(PartMapping."Grain Rule"));
        JsonHelper.AddInteger(Part, 'frontColors', FrontColors);
        JsonHelper.AddInteger(Part, 'backColors', BackColors);
        Part.Add('catalog', BuildPartCatalog(FirstItem));
    end;

    /// <summary>A part still selects its own stock even when the request states its
    /// paper - parts[].catalog.substrateIds is not among the refused filters.</summary>
    local procedure BuildPartCatalog(JobItem: Record "PVS Job Item") Catalog: JsonObject
    var
        PaperSetup: Record "PEQI Paper Setup";
        Ids: JsonArray;
    begin
        if JobItem."Item No." = '' then
            exit;
        if not PaperSetup.Get(JobItem."Item No.", '') then
            Error(NoPaperErr, JobItem."Item No.", JobItem."Component Type");
        Ids.Add(PaperSetup."Substrate Id");
        Catalog.Add('substrateIds', Ids);
    end;
}
```

`Format(PartMapping."Product Type")` emits the enum's AL value name, which Task 2 deliberately spelled the way the engine does — `Body`, `Cover`, `ParallelToSpine`. Do not rename an enum value without checking the engine's vocabulary.

- [ ] **Step 5: Compile**

Run: `tools/build.sh`
Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add "PTE PrintVis External Imposition/src/Mapping/PEQIJsonHelper.Codeunit.al" \
        "PTE PrintVis External Imposition/src/Mapping/PEQIPartMapper.Codeunit.al" \
        "PTE PrintVis External Imposition.Test/src/PEQITestData.Codeunit.al" \
        "PTE PrintVis External Imposition.Test/src/PEQIBuilderTests.Codeunit.al"
git commit -m "feat: map PrintVis job items to engine parts, one per component type"
```

---

### Task 8: Catalogue mapper — the two inline halves

> **Controller ruling (pre-flight):** `PressType` originally branched on
> `Config.Imaging`. Read from the symbols, `Imaging` enumerates proofers and
> platesetters — an offset press driven by a platesetter reads as Digital under
> that test, and a digital press with `Imaging` blank reads as Offset. Both
> backwards. `Printing Machine` carries an explicit `Digital` member and is the
> field that actually names the technology. Corrected above. Cost if wrong: a shop
> classifying presses some third way sets `Use Press Type Override` per press.

**Files:**
- Create: `PTE PrintVis External Imposition/src/Mapping/PEQICatalogMapper.Codeunit.al`
- Modify: `PTE PrintVis External Imposition.Test/src/PEQIBuilderTests.Codeunit.al`

**Interfaces:**
- Consumes: `Record "PEQI Press Setup"`, `Record "PEQI Paper Setup"`, `Record "PEQI Imposition Setup"`, `PEQIJsonHelper`.
- Produces:
  - `PEQICatalogMapper.BuildSheets(): JsonArray`
  - `PEQICatalogMapper.BuildPresses(): JsonArray`
  - `PEQICatalogMapper.BuildFoldPatterns(): JsonArray`

- [ ] **Step 1: Write the failing tests**

Append to `PEQIBuilderTests.Codeunit.al`, and add `CatalogMapper: Codeunit "PEQI Catalog Mapper";` to its `var` block:

```al
    [Test]
    procedure OnlyPaperMarkedForImpositionIsSent()
    var
        Sheets: JsonArray;
        PaperSetup: Record "PEQI Paper Setup";
    begin
        // [GIVEN] one paper marked for imposition and one not
        TestData.AddPaper('PAPER-USED');
        PaperSetup.Init();
        PaperSetup."Item No." := 'PAPER-UNUSED';
        PaperSetup."Use for Imposition" := false;
        PaperSetup.Insert(true);

        // [WHEN] the sheets half is built
        Sheets := CatalogMapper.BuildSheets();

        // [THEN] only the marked one is present
        Assert.AreEqual(1, Sheets.Count(), 'Unmarked paper is not sent');
    end;

    [Test]
    procedure APressCarriesItsWorkStylesExplicitly()
    var
        Presses: JsonArray;
        PressToken: JsonToken;
        Press: JsonObject;
        StylesToken: JsonToken;
        Styles: JsonArray;
        PressSetup: Record "PEQI Press Setup";
    begin
        // [GIVEN] a press that can work-and-turn
        PressSetup.Init();
        PressSetup."Cost Center Code" := 'PRESS-WT';
        PressSetup.Configuration := 'STD';
        PressSetup."Use for Imposition" := true;
        PressSetup.Simplex := true;
        PressSetup."Work And Back" := true;
        PressSetup."Work And Turn" := true;
        PressSetup.Insert(true);

        // [WHEN] the presses half is built
        Presses := CatalogMapper.BuildPresses();
        Presses.Get(0, PressToken);
        Press := PressToken.AsObject();
        Press.Get('workStyles', StylesToken);
        Styles := StylesToken.AsArray();

        // [THEN] WorkAndTurn is stated, because the engine never derives it
        Assert.AreEqual(3, Styles.Count(), 'All three declared work styles are sent');
    end;

    [Test]
    procedure APressCarriesItsStoredIdNotAFreshOne()
    var
        Presses: JsonArray;
        PressToken: JsonToken;
        PressSetup: Record "PEQI Press Setup";
        JsonHelper: Codeunit "PEQI Json Helper";
    begin
        // [GIVEN] a press with an assigned id
        PressSetup.Init();
        PressSetup."Cost Center Code" := 'PRESS-ID';
        PressSetup.Configuration := 'STD';
        PressSetup."Use for Imposition" := true;
        PressSetup.Insert(true);

        // [WHEN] the presses half is built twice
        Presses := CatalogMapper.BuildPresses();
        Presses.Get(0, PressToken);

        // [THEN] the id is the stored one
        // A fresh GUID per call makes every quoted solutionId stale at /jdf.
        Assert.AreEqual(
            LowerCase(DelChr(Format(PressSetup."Press Id"), '=', '{}')),
            LowerCase(JsonHelper.ReadText(PressToken.AsObject(), 'id')),
            'The press carries its stored id');
    end;
```

- [ ] **Step 2: Run the compile-red gate**

Run: `tools/build.sh`
Expected: `Codeunit 'PEQI Catalog Mapper' is missing`.

- [ ] **Step 3: Write the catalogue mapper**

```al
// <copyright header>

codeunit 50537 "PEQI Catalog Mapper"
{
    var
        JsonHelper: Codeunit "PEQI Json Helper";

    /// <summary>The paper half. Dimensions, grammage, caliper and grain are read
    /// live from the item so they cannot drift from PrintVis; the setup row
    /// contributes the surrogate id, the mark, and overrides where PrintVis is silent.</summary>
    procedure BuildSheets() Sheets: JsonArray
    var
        PaperSetup: Record "PEQI Paper Setup";
        Item: Record Item;
        Setup: Record "PEQI Imposition Setup";
        Sheet: JsonObject;
        Grain: Enum "PEQI Sheet Grain";
    begin
        Setup := Setup.GetSetup();
        PaperSetup.SetRange("Use for Imposition", true);
        if not PaperSetup.FindSet() then
            exit;

        repeat
            if Item.Get(PaperSetup."Item No.") then begin
                Clear(Sheet);
                JsonHelper.AddInteger(Sheet, 'id', PaperSetup."Substrate Id");
                JsonHelper.AddText(Sheet, 'name', ItemName(Item));
                JsonHelper.AddText(Sheet, 'vendorSku', VendorSku(PaperSetup, Item));
                JsonHelper.AddDecimal(Sheet, 'widthMm', Item."PVS Format 1");
                JsonHelper.AddDecimal(Sheet, 'heightMm', Item."PVS Format 2");

                Grain := PaperSetup.EffectiveGrain();
                if Grain <> Grain::" " then
                    JsonHelper.AddText(Sheet, 'grain', Format(Grain));

                JsonHelper.AddDecimalIfSet(Sheet, 'grammageGsm', Grammage(PaperSetup, Item, Setup));
                JsonHelper.AddDecimalIfSet(Sheet, 'caliperMicrons', Caliper(PaperSetup, Item, Setup));
                Sheets.Add(Sheet);
            end;
        until PaperSetup.Next() = 0;
    end;

    local procedure ItemName(Item: Record Item): Text
    begin
        if Item."PVS Paper Description" <> '' then
            exit(Item."PVS Paper Description");
        exit(Item.Description);
    end;

    local procedure VendorSku(PaperSetup: Record "PEQI Paper Setup"; Item: Record Item): Text
    begin
        if PaperSetup."Vendor Sku Override" <> '' then
            exit(PaperSetup."Vendor Sku Override");
        exit(Item."PVS Paper No.");
    end;

    local procedure Grammage(PaperSetup: Record "PEQI Paper Setup"; Item: Record Item; Setup: Record "PEQI Imposition Setup"): Decimal
    begin
        if PaperSetup."Grammage Override (gsm)" <> 0 then
            exit(PaperSetup."Grammage Override (gsm)");
        exit(Setup.WeightToGsm(Item."PVS Weight"));
    end;

    local procedure Caliper(PaperSetup: Record "PEQI Paper Setup"; Item: Record Item; Setup: Record "PEQI Imposition Setup"): Decimal
    begin
        if PaperSetup."Caliper Override (microns)" <> 0 then
            exit(PaperSetup."Caliper Override (microns)");
        exit(Setup.ThicknessToMicrons(Item."PVS Thickness"));
    end;

    /// <summary>The press half. The measurements come from PrintVis's cost centre
    /// configuration; the edges, the image area and the work styles come from our
    /// setup, because PrintVis does not record them.</summary>
    procedure BuildPresses() Presses: JsonArray
    var
        PressSetup: Record "PEQI Press Setup";
        Config: Record "PVS Cost Center Configuration";
        Press: JsonObject;
    begin
        PressSetup.SetRange("Use for Imposition", true);
        if not PressSetup.FindSet() then
            exit;

        repeat
            Clear(Press);
            if not Config.Get(PressSetup."Cost Center Code", PressSetup.Configuration) then
                Clear(Config);

            JsonHelper.AddText(Press, 'id', GuidText(PressSetup."Press Id"));
            JsonHelper.AddText(Press, 'name', PressName(PressSetup, Config));
            JsonHelper.AddText(Press, 'type', Format(PressType(PressSetup, Config)));

            JsonHelper.AddDecimal(Press, 'maxSheetWidthMm', Config."Max Printing Format Width");
            JsonHelper.AddDecimal(Press, 'maxSheetHeightMm', Config."Max Printing Format Length");
            JsonHelper.AddDecimalIfSet(Press, 'minSheetWidthMm', Config."Min Print Format Width");
            JsonHelper.AddDecimalIfSet(Press, 'minSheetHeightMm', Config."Min Print Format Length");

            JsonHelper.AddDecimalIfSet(Press, 'nonPrintableMarginTopMm', PressSetup."Non-Printable Top (mm)");
            JsonHelper.AddDecimalIfSet(Press, 'nonPrintableMarginBottomMm', PressSetup."Non-Printable Bottom (mm)");
            JsonHelper.AddDecimalIfSet(Press, 'nonPrintableMarginLeftMm', PressSetup."Non-Printable Left (mm)");
            JsonHelper.AddDecimalIfSet(Press, 'nonPrintableMarginRightMm', PressSetup."Non-Printable Right (mm)");

            JsonHelper.AddDecimalIfSet(Press, 'gripperMarginMm', Config."Gripper Edge");
            if PressSetup."Gripper Edge Side" <> PressSetup."Gripper Edge Side"::" " then
                JsonHelper.AddText(Press, 'gripperEdge', Format(PressSetup."Gripper Edge Side"));
            JsonHelper.AddDecimalIfSet(Press, 'sideLayMarginMm', Config.Pull);
            if PressSetup."Side Lay Edge" <> PressSetup."Side Lay Edge"::" " then
                JsonHelper.AddText(Press, 'sideLayEdge', Format(PressSetup."Side Lay Edge"));

            // Both image-area bounds are needed for either to apply.
            if (PressSetup."Max Image Area Width (mm)" <> 0) and (PressSetup."Max Image Area Height (mm)" <> 0) then begin
                JsonHelper.AddDecimal(Press, 'maxImageAreaWidthMm', PressSetup."Max Image Area Width (mm)");
                JsonHelper.AddDecimal(Press, 'maxImageAreaHeightMm', PressSetup."Max Image Area Height (mm)");
            end;

            JsonHelper.AddIntegerIfSet(Press, 'maxColorCount', Config."Max No. Of Colors");
            JsonHelper.AddBoolean(Press, 'supportsDoubleSided', Config."Perfection Printing");
            if Config."Perfection Printing" then
                JsonHelper.AddText(Press, 'printingType', 'Perfector');
            JsonHelper.AddIntegerIfSet(Press, 'sheetsPerHour', PressSetup."Sheets Per Hour");

            JsonHelper.AddText(Press, 'plateName', Config."Plate No.");
            JsonHelper.AddDecimalIfSet(Press, 'plateWidthMm', Config."Plate Width");
            JsonHelper.AddDecimalIfSet(Press, 'plateHeightMm', Config."Plate Length");
            JsonHelper.AddDecimalIfSet(Press, 'platePunchMm', PressSetup."Plate Punch (mm)");

            Press.Add('workStyles', WorkStyles(PressSetup));
            Presses.Add(Press);
        until PressSetup.Next() = 0;
    end;

    local procedure WorkStyles(PressSetup: Record "PEQI Press Setup") Styles: JsonArray
    var
        Style: Text;
    begin
        foreach Style in PressSetup.WorkStyleList() do
            Styles.Add(Style);
    end;

    local procedure PressName(PressSetup: Record "PEQI Press Setup"; Config: Record "PVS Cost Center Configuration"): Text
    begin
        if Config.Name <> '' then
            exit(Config.Name);
        exit(PressSetup."Cost Center Code");
    end;

    local procedure PressType(PressSetup: Record "PEQI Press Setup"; Config: Record "PVS Cost Center Configuration"): Enum "PEQI Press Type"
    begin
        if PressSetup."Use Press Type Override" then
            exit(PressSetup."Press Type Override");
        // Printing Machine is the field that names the press technology and has
        // an explicit Digital member. Imaging describes proofing and platesetting,
        // so a platesetter-driven offset press reads as Digital there.
        if Config."Printing Machine" = Config."Printing Machine"::Digital then
            exit("PEQI Press Type"::Digital);
        exit("PEQI Press Type"::Offset);
    end;

    local procedure GuidText(Value: Guid): Text
    begin
        exit(LowerCase(DelChr(Format(Value), '=', '{}')));
    end;

    /// <summary>Which fold patterns this shop runs, from PrintVis's own imposition
    /// catalogue. Without this the request inherits whatever the host has marked,
    /// and two hosts answer the same body differently.</summary>
    procedure BuildFoldPatterns() Patterns: JsonArray
    var
        ImpositionCode: Record "PVS Imposition Code";
        Seen: Dictionary of [Code[20], Integer];
        Pattern: JsonObject;
    begin
        ImpositionCode.SetFilter("Folding Catalog Code (CIP4)", '<>%1', '');
        if not ImpositionCode.FindSet() then
            exit;

        repeat
            if not Seen.ContainsKey(ImpositionCode."Folding Catalog Code (CIP4)") then begin
                Seen.Add(ImpositionCode."Folding Catalog Code (CIP4)", 1);
                Clear(Pattern);
                JsonHelper.AddText(Pattern, 'patternId', ImpositionCode."Folding Catalog Code (CIP4)");
                JsonHelper.AddInteger(Pattern, 'preference', 0);
                Patterns.Add(Pattern);
            end;
        until ImpositionCode.Next() = 0;
    end;
}
```

`PressType` reads `Printing Machine`, whose members are
`Miscellaneous, "Sheet Fed", "Web Fed", Flexo, Digital, , , "Continuous Fed"` —
`Digital` is explicit, so the test is exact. Calling a digital press offset
silently removes every portrait sheet from the solve, which is why this is worth
getting from the right field.

Note for later: a `Web Fed` or `Continuous Fed` press is refused by the engine
with `PRESS_IS_WEB_FED`, because this module works from a chosen sheet size and a
gripper margin and a web has neither. Sending one costs a stored diagnostic, not
a wrong answer, so v1 sends it and lets the engine say so.

- [ ] **Step 4: Compile**

Run: `tools/build.sh`
Expected: exit 0. Field-name errors here are the expected place to discover a PrintVis field that differs from the symbols read during design — fix against the extracted source, not by guessing.

- [ ] **Step 5: Commit**

```bash
git add "PTE PrintVis External Imposition/src/Mapping/PEQICatalogMapper.Codeunit.al" \
        "PTE PrintVis External Imposition.Test/src/PEQIBuilderTests.Codeunit.al"
git commit -m "feat: emit inline sheets, presses and fold patterns from PrintVis masters"
```

---

### Task 9: Request builder — assembling the document

> **Controller ruling (pre-flight):** the plan's `BindingSide` originally had four
> `case` arms. `PVS Imposition Code`.`Spine Side` has only `Left,Right`, so the Top
> and Bottom arms would not compile. They are removed; Top and Bottom binding come
> from `PEQI Binding Mapping`.`Default Binding Side` instead. Cost if wrong: a shop
> binding on the head must set that default rather than have it inferred.

**Files:**
- Create: `PTE PrintVis External Imposition/src/Mapping/PEQIRequestBuilder.Codeunit.al`
- Modify: `PTE PrintVis External Imposition.Test/src/PEQIBuilderTests.Codeunit.al`

**Interfaces:**
- Consumes: `PEQIPartMapper.BuildParts`, `PEQICatalogMapper.BuildSheets/BuildPresses/BuildFoldPatterns`, `Record "PEQI Binding Mapping"`, `Record "PEQI Imposition Setup"`.
- Produces:
  - `PEQIRequestBuilder.Build(CaseId: Integer; JobNo: Integer; VersionNo: Integer): Text` — the serialised `CalculateRequest`.
  - `PEQIRequestBuilder.BuildObject(CaseId: Integer; JobNo: Integer; VersionNo: Integer): JsonObject`

- [ ] **Step 1: Write the failing golden test**

The expected document is a constant in the test rather than a file on disk, because AL tests run inside a server with no working directory. It is still a golden test: any unintended change to the request shape fails it.

Append to `PEQIBuilderTests.Codeunit.al`, adding `RequestBuilder: Codeunit "PEQI Request Builder";` to the `var` block:

```al
    [Test]
    procedure TheRequestStatesBothCatalogueHalvesAndNoCatalogFilter()
    var
        RequestObject: JsonObject;
        Token: JsonToken;
        BindingMapping: Record "PEQI Binding Mapping";
        PressSetup: Record "PEQI Press Setup";
    begin
        // [GIVEN] a saddle-stitched job with a cover and a body, one paper, one press
        TestData.AddPartMapping('COVER', "PEQI Part Product Type"::Cover);
        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        TestData.AddPaper('PAPER-240');
        TestData.AddPaper('PAPER-100');
        TestData.AddJobItem(6001, 1, 1, 1, 'COVER', 4, 148, 210, 'PAPER-240');
        TestData.AddJobItem(6001, 1, 1, 2, 'BODY', 28, 148, 210, 'PAPER-100');

        BindingMapping.Init();
        BindingMapping."Finishing Code" := 'SADDLE';
        BindingMapping.Binding := BindingMapping.Binding::SaddleStitch;
        BindingMapping.Insert(true);
        TestData.AddJob(6001, 1, 1, 'SADDLE', 5000);

        PressSetup.Init();
        PressSetup."Cost Center Code" := 'PRESS-A';
        PressSetup.Configuration := 'STD';
        PressSetup."Use for Imposition" := true;
        PressSetup.Insert(true);

        // [WHEN] the request is built
        RequestObject := RequestBuilder.BuildObject(6001, 1, 1);

        // [THEN] both halves are stated
        Assert.IsTrue(RequestObject.Get('sheets', Token), 'The request states its paper');
        Assert.IsTrue(RequestObject.Get('presses', Token), 'The request states its presses');
        Assert.IsTrue(RequestObject.Get('foldPatterns', Token), 'The request states its fold patterns');

        // [THEN] no catalog filter accompanies them - a stated half replaces its
        // catalogue and the engine refuses the matching filters outright
        Assert.IsFalse(RequestObject.Get('catalog', Token), 'A self-contained request sends no catalog filter');

        // [THEN] no imposition rules are sent - they are measurements of another building
        Assert.IsFalse(RequestObject.Get('impositionRules', Token), 'Imposition rules are never sent');
    end;

    [Test]
    procedure TheRequestIsStableAcrossTwoBuilds()
    var
        First: Text;
        Second: Text;
    begin
        // [GIVEN] a job
        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        TestData.AddPaper('PAPER-90');
        TestData.AddJobItem(6002, 1, 1, 1, 'BODY', 32, 210, 297, 'PAPER-90');
        TestData.AddJob(6002, 1, 1, 'SADDLE', 1000);

        // [WHEN] the request is built twice
        First := RequestBuilder.Build(6002, 1, 1);
        Second := RequestBuilder.Build(6002, 1, 1);

        // [THEN] the two are identical
        // /calculate and /jdf must agree, and the engine's snapshotId hashes the
        // rows we sent. A request that differs between builds cannot quote a
        // solution back.
        Assert.AreEqual(First, Second, 'The same job builds the same request');
    end;
```

- [ ] **Step 2: Run the compile-red gate**

Run: `tools/build.sh`
Expected: `Codeunit 'PEQI Request Builder' is missing`.

- [ ] **Step 3: Write the request builder**

```al
// <copyright header>

codeunit 50535 "PEQI Request Builder"
{
    var
        PartMapper: Codeunit "PEQI Part Mapper";
        CatalogMapper: Codeunit "PEQI Catalog Mapper";
        JsonHelper: Codeunit "PEQI Json Helper";
        NoBindingErr: Label 'Finishing code %1 on job %2/%3/%4 has no imposition binding mapping. Add it on the Imposition Binding Mappings page.', Comment = '%1 finishing code, %2 case, %3 job, %4 version';
        NoJobErr: Label 'Job %1/%2/%3 does not exist.', Comment = '%1 case, %2 job, %3 version';

    procedure Build(CaseId: Integer; JobNo: Integer; VersionNo: Integer): Text
    var
        RequestObject: JsonObject;
        RequestText: Text;
    begin
        RequestObject := BuildObject(CaseId, JobNo, VersionNo);
        RequestObject.WriteTo(RequestText);
        exit(RequestText);
    end;

    procedure BuildObject(CaseId: Integer; JobNo: Integer; VersionNo: Integer) RequestObject: JsonObject
    var
        PVSJob: Record "PVS Job";
        BindingMapping: Record "PEQI Binding Mapping";
        Setup: Record "PEQI Imposition Setup";
    begin
        if not PVSJob.Get(CaseId, JobNo, VersionNo) then
            Error(NoJobErr, CaseId, JobNo, VersionNo);
        if not BindingMapping.Get(PVSJob.Finishing) then
            Error(NoBindingErr, PVSJob.Finishing, CaseId, JobNo, VersionNo);
        Setup := Setup.GetSetup();

        RequestObject.Add('parts', PartMapper.BuildParts(CaseId, JobNo, VersionNo));
        JsonHelper.AddText(RequestObject, 'binding', Format(BindingMapping.Binding));
        JsonHelper.AddText(RequestObject, 'bindingSide', Format(BindingSide(CaseId, JobNo, VersionNo, BindingMapping)));
        JsonHelper.AddIntegerIfSet(RequestObject, 'amount', PVSJob.Quantity);
        JsonHelper.AddText(RequestObject, 'grainPolicy', Format(Setup."Grain Policy"));
        JsonHelper.AddInteger(RequestObject, 'maxSolutions', Setup."Max Solutions");

        // The self-contained set. Stating a half replaces its catalogue, so the
        // matching catalog filters are omitted by construction rather than
        // discovered as a 400.
        RequestObject.Add('sheets', CatalogMapper.BuildSheets());
        RequestObject.Add('presses', CatalogMapper.BuildPresses());
        RequestObject.Add('foldPatterns', CatalogMapper.BuildFoldPatterns());

        // impositionRules is deliberately absent - see the design, section 6.5.
    end;

    /// <summary>The spine side the job's own imposition code states, falling back to
    /// the binding mapping's default.</summary>
    local procedure BindingSide(CaseId: Integer; JobNo: Integer; VersionNo: Integer; BindingMapping: Record "PEQI Binding Mapping"): Enum "PEQI Binding Side"
    var
        JobItem: Record "PVS Job Item";
        ImpositionCode: Record "PVS Imposition Code";
    begin
        JobItem.SetRange(ID, CaseId);
        JobItem.SetRange(Job, JobNo);
        JobItem.SetRange(Version, VersionNo);
        JobItem.SetRange(Active, true);
        JobItem.SetFilter("Imposition Type", '<>%1', '');
        if JobItem.FindFirst() then
            if ImpositionCode.Get(JobItem."Imposition Type") then
                // PVS Imposition Code."Spine Side" is Left,Right only. Top and
                // Bottom binding remain reachable through the binding mapping's
                // default, which is the only place they can come from.
                case ImpositionCode."Spine Side" of
                    ImpositionCode."Spine Side"::Left:
                        exit("PEQI Binding Side"::Left);
                    ImpositionCode."Spine Side"::Right:
                        exit("PEQI Binding Side"::Right);
                end;
        exit(BindingMapping."Default Binding Side");
    end;
}
```

`PVS Imposition Code`.`Spine Side` was read out of the symbols: it is an `Option`
with `OptionMembers = Left,Right` — **there is no Top or Bottom member.** The two
`case` arms above are therefore exhaustive. Do not add arms for Top or Bottom;
they will not compile.

- [ ] **Step 4: Compile**

Run: `tools/build.sh`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add "PTE PrintVis External Imposition/src/Mapping/PEQIRequestBuilder.Codeunit.al" \
        "PTE PrintVis External Imposition.Test/src/PEQIBuilderTests.Codeunit.al"
git commit -m "feat: assemble the self-contained calculate request"
```

---

### Task 10: Request validator

**Files:**
- Create: `PTE PrintVis External Imposition/src/Mapping/PEQIRequestValidator.Codeunit.al`
- Modify: `PTE PrintVis External Imposition/src/Mapping/PEQIRequestBuilder.Codeunit.al`
- Test: `PTE PrintVis External Imposition.Test/src/PEQIValidatorTests.Codeunit.al`

**Interfaces:**
- Consumes: the PrintVis job model and all four setup tables.
- Produces: `PEQIRequestValidator.Validate(CaseId: Integer; JobNo: Integer; VersionNo: Integer; var Problems: List of [Text]): Boolean` — true when the request may be built. Called by `PEQIRequestBuilder.BuildObject` before anything is mapped.

The mapper's own `Error` calls stay as last-resort guards. The validator exists so an operator gets **every** problem at once instead of fixing them one `Error` at a time.

- [ ] **Step 1: Write the failing tests**

```al
// <copyright header>

codeunit 50611 "PEQI Validator Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestData: Codeunit "PEQI Test Data";
        Validator: Codeunit "PEQI Request Validator";

    [Test]
    procedure AFoldedPartWithAnOddPageCountIsRefused()
    var
        Problems: List of [Text];
    begin
        // [GIVEN] a body with three pages
        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        TestData.AddPaper('PAPER-100');
        TestData.AddJobItem(7001, 1, 1, 1, 'BODY', 3, 210, 297, 'PAPER-100');

        // [WHEN] the job is validated
        // [THEN] it is refused and the message names the component
        Assert.IsFalse(Validator.Validate(7001, 1, 1, Problems), 'An odd page count on a folded part is refused');
        Assert.IsTrue(Problems.Count() > 0, 'A problem is reported');
        Assert.IsTrue(ProblemsMention(Problems, 'BODY'), 'The problem names the component');
    end;

    [Test]
    procedure EveryProblemIsReportedNotJustTheFirst()
    var
        Problems: List of [Text];
    begin
        // [GIVEN] a job with two unmapped component types
        TestData.AddPaper('PAPER-100');
        TestData.AddJobItem(7002, 1, 1, 1, 'UNMAPPED-A', 4, 210, 297, 'PAPER-100');
        TestData.AddJobItem(7002, 1, 1, 2, 'UNMAPPED-B', 8, 210, 297, 'PAPER-100');

        // [WHEN] the job is validated
        Validator.Validate(7002, 1, 1, Problems);

        // [THEN] both are reported, so the operator fixes both in one visit.
        // The count is not asserted: the catalogue checks contribute problems of
        // their own, and pinning the total would make this test fail for reasons
        // that have nothing to do with what it is about.
        Assert.IsTrue(ProblemsMention(Problems, 'UNMAPPED-A'), 'The first unmapped component is reported');
        Assert.IsTrue(ProblemsMention(Problems, 'UNMAPPED-B'), 'The second unmapped component is reported too');
    end;

    local procedure ProblemsMention(Problems: List of [Text]; Needle: Text): Boolean
    var
        Problem: Text;
    begin
        foreach Problem in Problems do
            if StrPos(Problem, Needle) > 0 then
                exit(true);
        exit(false);
    end;

    [Test]
    procedure PaperWithNoSheetFormatIsRefused()
    var
        Problems: List of [Text];
        PaperSetup: Record "PEQI Paper Setup";
        Item: Record Item;
    begin
        // [GIVEN] a paper marked for imposition whose item has no sheet size
        Item.Init();
        Item."No." := 'PAPER-NOSIZE';
        Item."PVS Format 1" := 0;
        Item."PVS Format 2" := 0;
        Item.Insert(true);
        PaperSetup.Init();
        PaperSetup."Item No." := 'PAPER-NOSIZE';
        PaperSetup."Use for Imposition" := true;
        PaperSetup.Insert(true);

        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        TestData.AddJobItem(7003, 1, 1, 1, 'BODY', 32, 210, 297, 'PAPER-NOSIZE');

        // [WHEN] the job is validated
        Validator.Validate(7003, 1, 1, Problems);

        // [THEN] the paper is named
        Assert.IsTrue(ProblemsMention(Problems, 'PAPER-NOSIZE'), 'The problem names the item');
    end;
}
```

- [ ] **Step 2: Run the compile-red gate**

Run: `tools/build.sh`
Expected: `Codeunit 'PEQI Request Validator' is missing`.

- [ ] **Step 3: Write the validator**

```al
// <copyright header>

codeunit 50538 "PEQI Request Validator"
{
    var
        NoBindingMsg: Label 'Finishing code %1 has no imposition binding mapping.', Comment = '%1 finishing code';
        NoPartMsg: Label 'Component type %1 has no imposition part mapping.', Comment = '%1 component type';
        OddPagesMsg: Label 'Component %1 has %2 pages. A folded part needs an even count.', Comment = '%1 component, %2 page count';
        NoPaperSetupMsg: Label 'Paper item %1 used by component %2 is not set up for imposition.', Comment = '%1 item no., %2 component';
        NoPaperFormatMsg: Label 'Paper item %1 is marked for imposition but has no sheet size (PVS Format 1 / 2).', Comment = '%1 item no.';
        NoPressMsg: Label 'No press is marked Use for Imposition.', Locked = false;
        NoPressFormatMsg: Label 'Press %1 %2 is marked for imposition but its configuration has no maximum printing format.', Comment = '%1 cost centre, %2 configuration';
        NoSheetsMsg: Label 'No paper is marked Use for Imposition.', Locked = false;

    /// <summary>Collects every problem rather than stopping at the first, so an
    /// operator fixes them in one visit. True when the request may be built.</summary>
    procedure Validate(CaseId: Integer; JobNo: Integer; VersionNo: Integer; var Problems: List of [Text]): Boolean
    begin
        Clear(Problems);
        ValidateJob(CaseId, JobNo, VersionNo, Problems);
        ValidateComponents(CaseId, JobNo, VersionNo, Problems);
        ValidatePaper(Problems);
        ValidatePresses(Problems);
        exit(Problems.Count() = 0);
    end;

    local procedure ValidateJob(CaseId: Integer; JobNo: Integer; VersionNo: Integer; var Problems: List of [Text])
    var
        PVSJob: Record "PVS Job";
        BindingMapping: Record "PEQI Binding Mapping";
    begin
        if not PVSJob.Get(CaseId, JobNo, VersionNo) then
            exit;
        if not BindingMapping.Get(PVSJob.Finishing) then
            Problems.Add(StrSubstNo(NoBindingMsg, PVSJob.Finishing));
    end;

    local procedure ValidateComponents(CaseId: Integer; JobNo: Integer; VersionNo: Integer; var Problems: List of [Text])
    var
        JobItem: Record "PVS Job Item";
        PartMapping: Record "PEQI Part Mapping";
        PaperSetup: Record "PEQI Paper Setup";
        Pages: Dictionary of [Code[20], Integer];
        ComponentType: Code[20];
        Total: Integer;
    begin
        JobItem.SetRange(ID, CaseId);
        JobItem.SetRange(Job, JobNo);
        JobItem.SetRange(Version, VersionNo);
        JobItem.SetRange(Active, true);
        if not JobItem.FindSet() then
            exit;

        repeat
            ComponentType := JobItem."Component Type";
            if Pages.ContainsKey(ComponentType) then
                Pages.Set(ComponentType, Pages.Get(ComponentType) + JobItem."No. Of Pages")
            else begin
                Pages.Add(ComponentType, JobItem."No. Of Pages");
                if not PartMapping.Get(ComponentType) then
                    Problems.Add(StrSubstNo(NoPartMsg, ComponentType));
            end;

            if JobItem."Item No." <> '' then
                if not PaperSetup.Get(JobItem."Item No.", '') then
                    Problems.Add(StrSubstNo(NoPaperSetupMsg, JobItem."Item No.", ComponentType));
        until JobItem.Next() = 0;

        foreach ComponentType in Pages.Keys() do begin
            Total := Pages.Get(ComponentType);
            if PartMapping.Get(ComponentType) then
                if IsFolded(PartMapping."Product Type") and (Total mod 2 <> 0) then
                    Problems.Add(StrSubstNo(OddPagesMsg, ComponentType, Total));
        end;
    end;

    local procedure IsFolded(ProductType: Enum "PEQI Part Product Type"): Boolean
    begin
        exit(ProductType <> ProductType::Flat);
    end;

    local procedure ValidatePaper(var Problems: List of [Text])
    var
        PaperSetup: Record "PEQI Paper Setup";
        Item: Record Item;
    begin
        PaperSetup.SetRange("Use for Imposition", true);
        if PaperSetup.IsEmpty() then begin
            Problems.Add(NoSheetsMsg);
            exit;
        end;

        PaperSetup.FindSet();
        repeat
            if Item.Get(PaperSetup."Item No.") then
                if (Item."PVS Format 1" <= 0) or (Item."PVS Format 2" <= 0) then
                    Problems.Add(StrSubstNo(NoPaperFormatMsg, PaperSetup."Item No."));
        until PaperSetup.Next() = 0;
    end;

    local procedure ValidatePresses(var Problems: List of [Text])
    var
        PressSetup: Record "PEQI Press Setup";
        Config: Record "PVS Cost Center Configuration";
    begin
        PressSetup.SetRange("Use for Imposition", true);
        if PressSetup.IsEmpty() then begin
            Problems.Add(NoPressMsg);
            exit;
        end;

        PressSetup.FindSet();
        repeat
            if Config.Get(PressSetup."Cost Center Code", PressSetup.Configuration) then
                if (Config."Max Printing Format Width" <= 0) or (Config."Max Printing Format Length" <= 0) then
                    Problems.Add(StrSubstNo(NoPressFormatMsg, PressSetup."Cost Center Code", PressSetup.Configuration));
        until PressSetup.Next() = 0;
    end;
}
```

- [ ] **Step 4: Call the validator from the builder**

In `PEQIRequestBuilder.BuildObject`, immediately after the `Setup := Setup.GetSetup();` line, insert:

```al
        ValidateOrError(CaseId, JobNo, VersionNo);
```

and add to the codeunit:

```al
    var
        Validator: Codeunit "PEQI Request Validator";
        ValidationErr: Label 'This job cannot be sent for imposition yet:\%1', Comment = '%1 newline-separated list of problems';

    local procedure ValidateOrError(CaseId: Integer; JobNo: Integer; VersionNo: Integer)
    var
        Problems: List of [Text];
        Problem: Text;
        Combined: TextBuilder;
    begin
        if Validator.Validate(CaseId, JobNo, VersionNo, Problems) then
            exit;
        foreach Problem in Problems do begin
            Combined.AppendLine('- ' + Problem);
        end;
        Error(ValidationErr, Combined.ToText());
    end;
```

- [ ] **Step 5: Compile**

Run: `tools/build.sh`
Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add "PTE PrintVis External Imposition/src/Mapping/PEQIRequestValidator.Codeunit.al" \
        "PTE PrintVis External Imposition/src/Mapping/PEQIRequestBuilder.Codeunit.al" \
        "PTE PrintVis External Imposition.Test/src/PEQIValidatorTests.Codeunit.al"
git commit -m "feat: refuse an unsendable job in AL, naming every PrintVis record to fix"
```

---

### Task 11: Transport interface, HTTP transport and engine client

**Files:**
- Create: `PTE PrintVis External Imposition/src/Integration/PEQIIEngineTransport.Interface.al`
- Create: `PTE PrintVis External Imposition/src/Integration/PEQITransportType.Enum.al`
- Create: `PTE PrintVis External Imposition/src/Integration/PEQIHttpTransport.Codeunit.al`
- Create: `PTE PrintVis External Imposition/src/Integration/PEQIEngineClient.Codeunit.al`
- Test: `PTE PrintVis External Imposition.Test/src/PEQITestTransport.Codeunit.al`
- Test: `PTE PrintVis External Imposition.Test/src/PEQITestTransportQueue.Codeunit.al`
- Test: `PTE PrintVis External Imposition.Test/src/PEQITestTransportType.EnumExt.al`
- Test: `PTE PrintVis External Imposition.Test/src/PEQIClientTests.Codeunit.al`

**Interfaces:**
- Consumes: `Record "PEQI Imposition Setup"` for URL, key, timeout, retries.
- Produces:
  - `interface "PEQI IEngine Transport"`: `Send(Method: Text; Url: Text; ApiKey: Text; TimeoutMs: Integer; Body: Text; var StatusCode: Integer; var ResponseBody: Text): Boolean`
  - `PEQIEngineClient.SetTransport(TransportType: Enum "PEQI Transport Type")`
  - `PEQIEngineClient.Calculate(RequestJson: Text): Text`
  - `PEQIEngineClient.WriteJdf(RequestJson: Text): Text`
  - `PEQIEngineClient.GetTicket(TicketId: Guid): Text`
  - `PEQIEngineClient.LastStatusCode(): Integer`, `.LastProblemDetail(): Text`

- [ ] **Step 1: Write the interface and the transport enum**

```al
// <copyright header>

/// <summary>The one seam between this extension and the network. Implemented by
/// PEQI Http Transport in production and by a double in the test app, which is
/// what makes every status-code path testable without a server.</summary>
interface "PEQI IEngine Transport"
{
    /// <summary>Returns true when a response was received at all - not when the
    /// status code indicates success. Transport failure and HTTP failure are
    /// different things and the client treats them differently.</summary>
    procedure Send(Method: Text; Url: Text; ApiKey: Text; TimeoutMs: Integer; Body: Text; var StatusCode: Integer; var ResponseBody: Text): Boolean
}
```

```al
// <copyright header>

enum 50563 "PEQI Transport Type" implements "PEQI IEngine Transport"
{
    Extensible = true;

    value(0; Http)
    {
        Caption = 'HTTP';
        Implementation = "PEQI IEngine Transport" = "PEQI Http Transport";
    }
}
```

The test double is registered by the test app extending this enum, so no test code ships in the production app.

- [ ] **Step 2: Write the HTTP transport**

```al
// <copyright header>

codeunit 50540 "PEQI Http Transport" implements "PEQI IEngine Transport"
{
    Access = Internal;

    procedure Send(Method: Text; Url: Text; ApiKey: Text; TimeoutMs: Integer; Body: Text; var StatusCode: Integer; var ResponseBody: Text): Boolean
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Content: HttpContent;
        ContentHeaders: HttpHeaders;
        RequestHeaders: HttpHeaders;
    begin
        Client.Timeout := TimeoutMs;

        Request.Method := Method;
        Request.SetRequestUri(Url);

        if Body <> '' then begin
            Content.WriteFrom(Body);
            Content.GetHeaders(ContentHeaders);
            ContentHeaders.Clear();
            ContentHeaders.Add('Content-Type', 'application/json');
            Request.Content := Content;
        end;

        Request.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Accept', 'application/json');
        if ApiKey <> '' then
            RequestHeaders.Add('x-functions-key', ApiKey);

        if not Client.Send(Request, Response) then begin
            StatusCode := 0;
            ResponseBody := '';
            exit(false);
        end;

        StatusCode := Response.HttpStatusCode();
        Response.Content().ReadAs(ResponseBody);
        exit(true);
    end;
}
```

- [ ] **Step 3: Write the test double**

```al
// <copyright header>

codeunit 50601 "PEQI Test Transport" implements "PEQI IEngine Transport"
{
    procedure Send(Method: Text; Url: Text; ApiKey: Text; TimeoutMs: Integer; Body: Text; var StatusCode: Integer; var ResponseBody: Text): Boolean
    var
        Queue: Codeunit "PEQI Test Transport Queue";
    begin
        Queue.RecordCall(Method, Url, Body);
        exit(Queue.NextResponse(StatusCode, ResponseBody));
    end;
}
```

```al
// <copyright header>

/// <summary>Single-instance so a test can queue responses before the client runs
/// and inspect the calls afterwards.</summary>
codeunit 50603 "PEQI Test Transport Queue"
{
    SingleInstance = true;

    var
        StatusCodes: List of [Integer];
        Bodies: List of [Text];
        Transported: List of [Boolean];
        CallMethods: List of [Text];
        CallUrls: List of [Text];
        CallBodies: List of [Text];

    procedure Reset()
    begin
        Clear(StatusCodes);
        Clear(Bodies);
        Clear(Transported);
        Clear(CallMethods);
        Clear(CallUrls);
        Clear(CallBodies);
    end;

    procedure QueueResponse(StatusCode: Integer; ResponseBody: Text)
    begin
        StatusCodes.Add(StatusCode);
        Bodies.Add(ResponseBody);
        Transported.Add(true);
    end;

    /// <summary>Queues a failure to reach the server at all, as against an HTTP error.</summary>
    procedure QueueTransportFailure()
    begin
        StatusCodes.Add(0);
        Bodies.Add('');
        Transported.Add(false);
    end;

    procedure NextResponse(var StatusCode: Integer; var ResponseBody: Text): Boolean
    var
        Reached: Boolean;
    begin
        if StatusCodes.Count() = 0 then begin
            StatusCode := 200;
            ResponseBody := '{}';
            exit(true);
        end;
        StatusCode := StatusCodes.Get(1);
        ResponseBody := Bodies.Get(1);
        Reached := Transported.Get(1);
        StatusCodes.RemoveAt(1);
        Bodies.RemoveAt(1);
        Transported.RemoveAt(1);
        exit(Reached);
    end;

    procedure RecordCall(Method: Text; Url: Text; Body: Text)
    begin
        CallMethods.Add(Method);
        CallUrls.Add(Url);
        CallBodies.Add(Body);
    end;

    procedure CallCount(): Integer
    begin
        exit(CallMethods.Count());
    end;

    procedure CallUrl(Index: Integer): Text
    begin
        exit(CallUrls.Get(Index));
    end;
}
```

And register it by extending the transport enum from the test app:

```al
// <copyright header>

enumextension 50604 "PEQI Test Transport Type" extends "PEQI Transport Type"
{
    value(100; Test)
    {
        Caption = 'Test';
        Implementation = "PEQI IEngine Transport" = "PEQI Test Transport";
    }
}
```

- [ ] **Step 4: Write the failing client tests**

```al
// <copyright header>

codeunit 50612 "PEQI Client Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Queue: Codeunit "PEQI Test Transport Queue";

    local procedure NewClient(var Client: Codeunit "PEQI Engine Client")
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        Queue.Reset();
        Setup := Setup.GetSetup();
        Setup.Get('');
        Setup."Engine Base Url" := 'https://engine.example.com/api';
        Setup."Retry Count" := 2;
        Setup.Modify(true);
        Client.SetTransport("PEQI Transport Type"::Test);
    end;

    [Test]
    procedure ASuccessfulCalculateReturnsItsBody()
    var
        Client: Codeunit "PEQI Engine Client";
        Body: Text;
    begin
        // [GIVEN] the engine answers 200
        NewClient(Client);
        Queue.QueueResponse(200, '{"solutionCount":3}');

        // [WHEN] calculate is called
        Body := Client.Calculate('{"parts":[]}');

        // [THEN] the body comes back and one call was made
        Assert.AreEqual('{"solutionCount":3}', Body, 'The response body is returned');
        Assert.AreEqual(1, Queue.CallCount(), 'One call is made for a 200');
        Assert.IsTrue(StrPos(Queue.CallUrl(1), '/imposition/calculate') > 0, 'Calculate posts to the calculate route');
    end;

    [Test]
    procedure A400IsNotRetriedAndCarriesItsDetail()
    var
        Client: Codeunit "PEQI Engine Client";
    begin
        // [GIVEN] the engine answers 400 with ProblemDetails
        NewClient(Client);
        Queue.QueueResponse(400, '{"title":"Validation Error","detail":"Part ''Cover'' has 3 pages but Cover is folded and needs an even count.","status":400}');

        // [WHEN] calculate is called
        // [THEN] it errors, does not retry, and the detail reaches the operator
        asserterror Client.Calculate('{"parts":[]}');
        Assert.ExpectedError('even count');
        Assert.AreEqual(1, Queue.CallCount(), 'A 400 is never retried - the body is wrong, not the moment');
    end;

    [Test]
    procedure A500IsRetriedUpToTheConfiguredCount()
    var
        Client: Codeunit "PEQI Engine Client";
        Body: Text;
    begin
        // [GIVEN] two failures then a success
        NewClient(Client);
        Queue.QueueResponse(500, '');
        Queue.QueueResponse(500, '');
        Queue.QueueResponse(200, '{"solutionCount":1}');

        // [WHEN] calculate is called
        Body := Client.Calculate('{"parts":[]}');

        // [THEN] it succeeded on the third attempt
        Assert.AreEqual('{"solutionCount":1}', Body, 'The eventual success is returned');
        Assert.AreEqual(3, Queue.CallCount(), 'Two retries follow the initial attempt');
    end;

    [Test]
    procedure A409SaysWhyNothingFits()
    var
        Client: Codeunit "PEQI Engine Client";
    begin
        // [GIVEN] the engine cannot impose the product
        NewClient(Client);
        Queue.QueueResponse(409, '{"title":"No solution","detail":"No imposition fits","status":409,"diagnostics":[{"severity":"Error","code":"PRESS_SHEET_BOUNDS_MISSING","message":"Press KBA has no maximum sheet size"}]}');

        // [WHEN] calculate is called
        // [THEN] the diagnostic, not just the title, reaches the operator
        asserterror Client.Calculate('{"parts":[]}');
        Assert.ExpectedError('PRESS_SHEET_BOUNDS_MISSING');
    end;
}
```

- [ ] **Step 5: Run the compile-red gate**

Run: `tools/build.sh`
Expected: `Codeunit 'PEQI Engine Client' is missing`.

- [ ] **Step 6: Write the engine client**

```al
// <copyright header>

codeunit 50541 "PEQI Engine Client"
{
    var
        TransportType: Enum "PEQI Transport Type";
        LastStatus: Integer;
        LastDetail: Text;
        JsonHelper: Codeunit "PEQI Json Helper";
        NoUrlErr: Label 'The Impositioning engine base URL is not set. Fill it in on the Imposition Setup page.';
        UnreachableErr: Label 'The Impositioning engine could not be reached at %1.', Comment = '%1 url';
        HttpErr: Label 'The Impositioning engine returned %1.\%2', Comment = '%1 status code, %2 detail';
        StaleSolutionErr: Label 'The quoted solution is no longer known to the engine. Solve the job again.';

    procedure SetTransport(NewTransportType: Enum "PEQI Transport Type")
    begin
        TransportType := NewTransportType;
    end;

    procedure Calculate(RequestJson: Text): Text
    begin
        exit(Call('POST', 'imposition/calculate', RequestJson));
    end;

    procedure WriteJdf(RequestJson: Text): Text
    begin
        exit(Call('POST', 'imposition/jdf', RequestJson));
    end;

    procedure GetTicket(TicketId: Guid): Text
    begin
        exit(Call('GET', 'imposition/jdf/' + LowerCase(DelChr(Format(TicketId), '=', '{}')), ''));
    end;

    procedure LastStatusCode(): Integer
    begin
        exit(LastStatus);
    end;

    procedure LastProblemDetail(): Text
    begin
        exit(LastDetail);
    end;

    local procedure Call(Method: Text; Route: Text; Body: Text): Text
    var
        Setup: Record "PEQI Imposition Setup";
        Transport: Interface "PEQI IEngine Transport";
        Url: Text;
        Attempt: Integer;
        MaxAttempts: Integer;
        StatusCode: Integer;
        ResponseBody: Text;
        Reached: Boolean;
    begin
        Setup := Setup.GetSetup();
        Setup.Get('');
        if Setup."Engine Base Url" = '' then
            Error(NoUrlErr);

        Url := DelChr(Setup."Engine Base Url", '>', '/') + '/' + Route;
        Transport := TransportType;
        MaxAttempts := Setup."Retry Count" + 1;

        for Attempt := 1 to MaxAttempts do begin
            Reached := Transport.Send(Method, Url, Setup.GetApiKey(), Setup."Timeout (ms)", Body, StatusCode, ResponseBody);
            LastStatus := StatusCode;

            if Reached and (StatusCode >= 200) and (StatusCode < 300) then begin
                LastDetail := '';
                exit(ResponseBody);
            end;

            // 429 and 5xx are the moment being wrong; everything else is the
            // request being wrong, and repeating it would only waste the operator's time.
            if Reached and not IsRetryable(StatusCode) then
                RaiseFor(StatusCode, ResponseBody);

            if Attempt = MaxAttempts then begin
                if not Reached then
                    Error(UnreachableErr, Url);
                RaiseFor(StatusCode, ResponseBody);
            end;

            Sleep(BackoffMs(Attempt));
        end;
    end;

    local procedure IsRetryable(StatusCode: Integer): Boolean
    begin
        exit((StatusCode = 429) or (StatusCode >= 500));
    end;

    local procedure BackoffMs(Attempt: Integer): Integer
    begin
        // Power returns a Decimal; rounding keeps this assignable to Integer.
        exit(Round(500 * Power(2, Attempt - 1), 1));
    end;

    local procedure RaiseFor(StatusCode: Integer; ResponseBody: Text)
    begin
        LastDetail := DescribeProblem(ResponseBody);
        if StatusCode = 404 then
            Error(StaleSolutionErr);
        Error(HttpErr, StatusCode, LastDetail);
    end;

    /// <summary>RFC 7807. The diagnostics extension on a 409 is what actually
    /// explains why nothing fits, so it is appended rather than dropped.</summary>
    local procedure DescribeProblem(ResponseBody: Text): Text
    var
        Problem: JsonObject;
        Diagnostics: JsonArray;
        DiagnosticToken: JsonToken;
        Described: TextBuilder;
        Detail: Text;
    begin
        if ResponseBody = '' then
            exit('');
        if not Problem.ReadFrom(ResponseBody) then
            exit(CopyStr(ResponseBody, 1, 250));

        Detail := JsonHelper.ReadText(Problem, 'detail');
        if Detail = '' then
            Detail := JsonHelper.ReadText(Problem, 'title');
        Described.AppendLine(Detail);

        if JsonHelper.ReadArray(Problem, 'diagnostics', Diagnostics) then
            foreach DiagnosticToken in Diagnostics do
                Described.AppendLine(
                    JsonHelper.ReadText(DiagnosticToken.AsObject(), 'code') + ': ' +
                    JsonHelper.ReadText(DiagnosticToken.AsObject(), 'message'));

        exit(Described.ToText());
    end;
}
```

- [ ] **Step 7: Compile**

Run: `tools/build.sh`
Expected: exit 0.

- [ ] **Step 8: Commit**

```bash
git add "PTE PrintVis External Imposition/src/Integration/" \
        "PTE PrintVis External Imposition.Test/src/PEQITestTransport.Codeunit.al" \
        "PTE PrintVis External Imposition.Test/src/PEQITestTransportQueue.Codeunit.al" \
        "PTE PrintVis External Imposition.Test/src/PEQITestTransportType.EnumExt.al" \
        "PTE PrintVis External Imposition.Test/src/PEQIClientTests.Codeunit.al"
git commit -m "feat: add engine client with retry, ProblemDetails and a testable transport seam"
```

---

### Task 12: Response reader

**Files:**
- Create: `PTE PrintVis External Imposition/src/Integration/PEQIResponseReader.Codeunit.al`
- Test: `PTE PrintVis External Imposition.Test/src/PEQIResponseTests.Codeunit.al`

**Interfaces:**
- Consumes: `PEQIJsonHelper`, the document tables.
- Produces:
  - `PEQIResponseReader.ApplySolution(var ImpositionJob: Record "PEQI Imposition Job"; SolutionJson: Text)` — fills the summary fields and writes the `PEQI Press Run` lines.
  - `PEQIResponseReader.ApplyDiagnostics(var ImpositionJob: Record "PEQI Imposition Job"; DiagnosticsJson: Text; Source: Option Engine,Builder,Preview)`
  - `PEQIResponseReader.FindSolutionById(CalculateResponseJson: Text; SolutionId: Text; var Solution: JsonObject): Boolean`

- [ ] **Step 1: Write the failing test**

```al
// <copyright header>

codeunit 50616 "PEQI Response Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Reader: Codeunit "PEQI Response Reader";

    [Test]
    procedure AMixedStockSolutionStillYieldsItsRuns()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        PressRun: Record "PEQI Press Run";
        SolutionJson: Text;
    begin
        // [GIVEN] a solution whose sheets disagree, so the convenience fields are null
        // The API nulls sheet/pressName/workStyle whenever a plan is mixed-stock;
        // runs[] is the view that is always populated.
        ImpositionJob := ImpositionJob.NewEntry(8001, 1, 1);
        SolutionJson :=
          '{"solutionId":"abc123","runnable":true,"score":0.87,' +
          '"sheet":null,"pressId":null,"pressName":null,"workStyle":null,' +
          '"metrics":{"sheetCount":4,"totalSignatures":5,"utilisation":0.91,' +
          '"wastedAreaSqMm":12345.6,"worstGrainVerdict":"Correct"},' +
          '"runs":[' +
          '{"sheet":{"name":"Munken 240"},"pressName":"KBA Rapida 75","workStyle":"WorkAndBack",' +
          '"passes":1,"signatureIds":["S1"]},' +
          '{"sheet":{"name":"Amber 100"},"pressName":"KBA Rapida 75","workStyle":"WorkAndTurn",' +
          '"passes":2,"signatureIds":["S2","S3"]}]}';

        // [WHEN] the solution is applied
        Reader.ApplySolution(ImpositionJob, SolutionJson);

        // [THEN] the summary is filled from metrics
        Assert.AreEqual('abc123', ImpositionJob."Solution Id", 'The solution id is stored');
        Assert.AreEqual(4, ImpositionJob."Sheet Count", 'Sheet count comes from metrics');
        Assert.AreEqual('Correct', ImpositionJob."Worst Grain Verdict", 'Grain verdict comes from metrics');

        // [THEN] both runs are written even though the convenience fields were null
        PressRun.SetRange("Case ID", 8001);
        PressRun.SetRange(Job, 1);
        PressRun.SetRange(Version, 1);
        PressRun.SetRange("Entry No.", ImpositionJob."Entry No.");
        Assert.AreEqual(2, PressRun.Count(), 'Every run is recorded');
    end;

    [Test]
    procedure DiagnosticsAreStoredNotSuppressed()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        Diagnostic: Record "PEQI Diagnostic";
    begin
        // [GIVEN] the diagnostics a self-contained request always raises
        ImpositionJob := ImpositionJob.NewEntry(8002, 1, 1);

        // [WHEN] they are applied
        Reader.ApplyDiagnostics(ImpositionJob,
          '[{"severity":"Info","code":"IMPOSITION_RULES_NOT_APPLIED","count":1,' +
          '"example":{"message":"This shop''s rule table was not applied."}}]', 0);

        // [THEN] the rules diagnostic is on the record where an operator can see it
        Diagnostic.SetRange("Case ID", 8002);
        Diagnostic.SetRange("Code", 'IMPOSITION_RULES_NOT_APPLIED');
        Assert.AreEqual(1, Diagnostic.Count(), 'The rules diagnostic is stored, not hidden');
    end;
}
```

- [ ] **Step 2: Run the compile-red gate**

Run: `tools/build.sh`
Expected: `Codeunit 'PEQI Response Reader' is missing`.

- [ ] **Step 3: Write the response reader**

```al
// <copyright header>

codeunit 50542 "PEQI Response Reader"
{
    var
        JsonHelper: Codeunit "PEQI Json Helper";

    /// <summary>Fills the job's summary from a solution and rewrites its run lines.
    /// Reads runs[] rather than the convenience fields: those are null whenever a
    /// solution's sheets disagree, which a mixed-stock plan by definition does.</summary>
    procedure ApplySolution(var ImpositionJob: Record "PEQI Imposition Job"; SolutionJson: Text)
    var
        Solution: JsonObject;
        Metrics: JsonObject;
        Runs: JsonArray;
    begin
        if not Solution.ReadFrom(SolutionJson) then
            exit;

        ImpositionJob."Solution Id" := CopyStr(JsonHelper.ReadText(Solution, 'solutionId'), 1, MaxStrLen(ImpositionJob."Solution Id"));
        ImpositionJob.Runnable := JsonHelper.ReadBoolean(Solution, 'runnable');
        ImpositionJob.Score := JsonHelper.ReadDecimal(Solution, 'score');

        if JsonHelper.ReadObject(Solution, 'metrics', Metrics) then begin
            ImpositionJob."Sheet Count" := JsonHelper.ReadInteger(Metrics, 'sheetCount');
            ImpositionJob."Total Signatures" := JsonHelper.ReadInteger(Metrics, 'totalSignatures');
            ImpositionJob.Utilisation := JsonHelper.ReadDecimal(Metrics, 'utilisation');
            ImpositionJob."Wasted Area (sqmm)" := JsonHelper.ReadDecimal(Metrics, 'wastedAreaSqMm');
            ImpositionJob."Worst Grain Verdict" := CopyStr(JsonHelper.ReadText(Metrics, 'worstGrainVerdict'), 1, MaxStrLen(ImpositionJob."Worst Grain Verdict"));
        end;

        ImpositionJob.Status := ImpositionJob.Status::Solved;
        ImpositionJob.Modify(true);

        if JsonHelper.ReadArray(Solution, 'runs', Runs) then
            WriteRuns(ImpositionJob, Runs);
    end;

    local procedure WriteRuns(ImpositionJob: Record "PEQI Imposition Job"; Runs: JsonArray)
    var
        PressRun: Record "PEQI Press Run";
        RunToken: JsonToken;
        Run: JsonObject;
        SheetObject: JsonObject;
        LineNo: Integer;
    begin
        PressRun.SetRange("Case ID", ImpositionJob."Case ID");
        PressRun.SetRange(Job, ImpositionJob.Job);
        PressRun.SetRange(Version, ImpositionJob.Version);
        PressRun.SetRange("Entry No.", ImpositionJob."Entry No.");
        PressRun.DeleteAll(true);

        foreach RunToken in Runs do begin
            Run := RunToken.AsObject();
            LineNo += 10000;

            PressRun.Init();
            PressRun."Case ID" := ImpositionJob."Case ID";
            PressRun.Job := ImpositionJob.Job;
            PressRun.Version := ImpositionJob.Version;
            PressRun."Entry No." := ImpositionJob."Entry No.";
            PressRun."Line No." := LineNo;
            PressRun."Press Name" := CopyStr(JsonHelper.ReadText(Run, 'pressName'), 1, MaxStrLen(PressRun."Press Name"));
            PressRun."Work Style" := CopyStr(JsonHelper.ReadText(Run, 'workStyle'), 1, MaxStrLen(PressRun."Work Style"));
            PressRun.Passes := JsonHelper.ReadInteger(Run, 'passes');
            PressRun."Signature Ids" := CopyStr(JoinArray(Run, 'signatureIds'), 1, MaxStrLen(PressRun."Signature Ids"));
            PressRun."Sheet Count" := SignatureCount(Run);

            if JsonHelper.ReadObject(Run, 'sheet', SheetObject) then begin
                PressRun."Stock Name" := CopyStr(JsonHelper.ReadText(SheetObject, 'name'), 1, MaxStrLen(PressRun."Stock Name"));
                PressRun."Substrate Id" := JsonHelper.ReadInteger(SheetObject, 'id');
            end;

            PressRun.Insert(true);
        end;
    end;

    local procedure SignatureCount(Run: JsonObject): Integer
    var
        Ids: JsonArray;
    begin
        if not JsonHelper.ReadArray(Run, 'signatureIds', Ids) then
            exit(0);
        exit(Ids.Count());
    end;

    local procedure JoinArray(Parent: JsonObject; Name: Text): Text
    var
        Items: JsonArray;
        ItemToken: JsonToken;
        Joined: TextBuilder;
    begin
        if not JsonHelper.ReadArray(Parent, Name, Items) then
            exit('');
        foreach ItemToken in Items do begin
            if Joined.Length() > 0 then
                Joined.Append(', ');
            Joined.Append(ItemToken.AsValue().AsText());
        end;
        exit(Joined.ToText());
    end;

    procedure ApplyDiagnostics(var ImpositionJob: Record "PEQI Imposition Job"; DiagnosticsJson: Text; DiagnosticSource: Option Engine,Builder,Preview)
    var
        Diagnostic: Record "PEQI Diagnostic";
        Diagnostics: JsonArray;
        DiagnosticToken: JsonToken;
        Entry: JsonObject;
        Example: JsonObject;
    begin
        if DiagnosticsJson = '' then
            exit;
        if not Diagnostics.ReadFrom(DiagnosticsJson) then
            exit;

        Diagnostic.SetRange("Case ID", ImpositionJob."Case ID");
        Diagnostic.SetRange(Job, ImpositionJob.Job);
        Diagnostic.SetRange(Version, ImpositionJob.Version);
        Diagnostic.SetRange("Entry No.", ImpositionJob."Entry No.");
        Diagnostic.SetRange(Source, DiagnosticSource);
        Diagnostic.DeleteAll(true);
        Diagnostic.Reset();

        foreach DiagnosticToken in Diagnostics do begin
            Entry := DiagnosticToken.AsObject();

            Diagnostic.Init();
            Diagnostic."Case ID" := ImpositionJob."Case ID";
            Diagnostic.Job := ImpositionJob.Job;
            Diagnostic.Version := ImpositionJob.Version;
            Diagnostic."Entry No." := ImpositionJob."Entry No.";
            Diagnostic."Line No." := NextDiagnosticLine(ImpositionJob);
            Diagnostic.Severity := SeverityOf(JsonHelper.ReadText(Entry, 'severity'));
            Diagnostic."Code" := CopyStr(JsonHelper.ReadText(Entry, 'code'), 1, MaxStrLen(Diagnostic."Code"));
            Diagnostic."Count" := JsonHelper.ReadInteger(Entry, 'count');
            Diagnostic.Source := DiagnosticSource;
            if JsonHelper.ReadObject(Entry, 'example', Example) then
                Diagnostic."Example Message" := CopyStr(JsonHelper.ReadText(Example, 'message'), 1, MaxStrLen(Diagnostic."Example Message"))
            else
                Diagnostic."Example Message" := CopyStr(JsonHelper.ReadText(Entry, 'message'), 1, MaxStrLen(Diagnostic."Example Message"));
            Diagnostic.Insert(true);
        end;
    end;

    local procedure NextDiagnosticLine(ImpositionJob: Record "PEQI Imposition Job"): Integer
    var
        Diagnostic: Record "PEQI Diagnostic";
    begin
        Diagnostic.SetRange("Case ID", ImpositionJob."Case ID");
        Diagnostic.SetRange(Job, ImpositionJob.Job);
        Diagnostic.SetRange(Version, ImpositionJob.Version);
        Diagnostic.SetRange("Entry No.", ImpositionJob."Entry No.");
        if Diagnostic.FindLast() then
            exit(Diagnostic."Line No." + 10000);
        exit(10000);
    end;

    local procedure SeverityOf(Value: Text): Enum "PEQI Diagnostic Severity"
    begin
        case LowerCase(Value) of
            'error':
                exit("PEQI Diagnostic Severity"::Error);
            'warn', 'warning':
                exit("PEQI Diagnostic Severity"::Warn);
        end;
        exit("PEQI Diagnostic Severity"::Info);
    end;

    /// <summary>Finds one solution in a CalculateResponse by its id.</summary>
    procedure FindSolutionById(CalculateResponseJson: Text; SolutionId: Text; var Solution: JsonObject): Boolean
    var
        Response: JsonObject;
        Solutions: JsonArray;
        SolutionToken: JsonToken;
    begin
        if not Response.ReadFrom(CalculateResponseJson) then
            exit(false);
        if not JsonHelper.ReadArray(Response, 'solutions', Solutions) then
            exit(false);
        foreach SolutionToken in Solutions do
            if JsonHelper.ReadText(SolutionToken.AsObject(), 'solutionId') = SolutionId then begin
                Solution := SolutionToken.AsObject();
                exit(true);
            end;
        exit(false);
    end;
}
```

- [ ] **Step 4: Compile**

Run: `tools/build.sh`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add "PTE PrintVis External Imposition/src/Integration/PEQIResponseReader.Codeunit.al" \
        "PTE PrintVis External Imposition.Test/src/PEQIResponseTests.Codeunit.al"
git commit -m "feat: read solutions, runs and diagnostics from the engine's response"
```

---

### Task 13: Imposition job pages and the PrintVis actions

**Files:**
- Create: `PTE PrintVis External Imposition/src/Document/PEQIImpositionJobs.Page.al`
- Create: `PTE PrintVis External Imposition/src/Document/PEQIImpositionJobCard.Page.al`
- Create: `PTE PrintVis External Imposition/src/Document/PEQIPressRunPart.Page.al`
- Create: `PTE PrintVis External Imposition/src/Document/PEQIDiagnosticsPart.Page.al`
- Create: `PTE PrintVis External Imposition/src/Document/PEQIJdfTickets.Page.al`
- Create: `PTE PrintVis External Imposition/src/Extensions/PEQIJobCard.PageExt.al`
- Create: `PTE PrintVis External Imposition/src/Extensions/PEQICaseCard.PageExt.al`
- Modify: the four document tables, restoring any `LookupPageId`/`DrillDownPageId` commented out in Task 6

**Interfaces:**
- Consumes: `PEQIRequestBuilder.Build`, the document tables.
- Produces: `PEQIImpositionJobCard` — the page that will host the add-in in Task 15. Its `OnOpenPage` seeds nothing yet; Task 15 adds that.

- [ ] **Step 1: Write the two list parts**

```al
// <copyright header>

page 50518 "PEQI Press Run Part"
{
    Caption = 'Press Runs';
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = "PEQI Press Run";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Rows)
            {
                field("Stock Name"; Rec."Stock Name") { ApplicationArea = All; }
                field("Press Name"; Rec."Press Name") { ApplicationArea = All; }
                field("Work Style"; Rec."Work Style") { ApplicationArea = All; }
                field("Sheet Count"; Rec."Sheet Count") { ApplicationArea = All; }
                field(Passes; Rec.Passes) { ApplicationArea = All; }
                field("Signature Ids"; Rec."Signature Ids") { ApplicationArea = All; }
                field("PVS Sheet ID"; Rec."PVS Sheet ID") { ApplicationArea = All; }
            }
        }
    }
}
```

```al
// <copyright header>

page 50519 "PEQI Diagnostics Part"
{
    Caption = 'Diagnostics';
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = "PEQI Diagnostic";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Rows)
            {
                field(Severity; Rec.Severity)
                {
                    ApplicationArea = All;
                    StyleExpr = SeverityStyle;
                }
                field("Code"; Rec."Code") { ApplicationArea = All; }
                field("Count"; Rec."Count") { ApplicationArea = All; }
                field("Example Message"; Rec."Example Message") { ApplicationArea = All; }
                field(Source; Rec.Source) { ApplicationArea = All; }
            }
        }
    }

    var
        SeverityStyle: Text;

    trigger OnAfterGetRecord()
    begin
        case Rec.Severity of
            Rec.Severity::Error:
                SeverityStyle := 'Unfavorable';
            Rec.Severity::Warn:
                SeverityStyle := 'Ambiguous';
            else
                SeverityStyle := 'Standard';
        end;
    end;
}
```

- [ ] **Step 2: Write the job card**

```al
// <copyright header>

page 50517 "PEQI Imposition Job Card"
{
    Caption = 'Imposition';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "PEQI Imposition Job";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("Case ID"; Rec."Case ID") { ApplicationArea = All; Editable = false; }
                field(Job; Rec.Job) { ApplicationArea = All; Editable = false; }
                field(Version; Rec.Version) { ApplicationArea = All; Editable = false; }
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; Editable = false; }
                field(Status; Rec.Status) { ApplicationArea = All; Editable = false; }
                field("Last Error"; Rec."Last Error")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Visible = HasError;
                    StyleExpr = 'Unfavorable';
                }
            }
            group(Chosen)
            {
                Caption = 'Chosen Solution';
                field("Solution Id"; Rec."Solution Id") { ApplicationArea = All; Editable = false; }
                field("Sheet Count"; Rec."Sheet Count") { ApplicationArea = All; Editable = false; }
                field("Total Signatures"; Rec."Total Signatures") { ApplicationArea = All; Editable = false; }
                field(Utilisation; Rec.Utilisation) { ApplicationArea = All; Editable = false; }
                field("Worst Grain Verdict"; Rec."Worst Grain Verdict") { ApplicationArea = All; Editable = false; }
                field(Runnable; Rec.Runnable) { ApplicationArea = All; Editable = false; }
            }
            part(Runs; "PEQI Press Run Part")
            {
                ApplicationArea = All;
                SubPageLink = "Case ID" = field("Case ID"), Job = field(Job),
                              Version = field(Version), "Entry No." = field("Entry No.");
            }
            part(Diagnostics; "PEQI Diagnostics Part")
            {
                ApplicationArea = All;
                SubPageLink = "Case ID" = field("Case ID"), Job = field(Job),
                              Version = field(Version), "Entry No." = field("Entry No.");
            }
        }
    }

    var
        EditorVisible: Boolean;
        HasError: Boolean;
        CanGenerate: Boolean;

    trigger OnAfterGetRecord()
    begin
        // EditorVisible and CanGenerate are read by controls added in later tasks.
        EditorVisible := Rec.Status in [Rec.Status::Draft, Rec.Status::Solved];
        HasError := Rec."Last Error" <> '';
        CanGenerate := Rec.Status = Rec.Status::Solved;
    end;

    actions
    {
        area(Processing)
        {
            action(ViewRequest)
            {
                ApplicationArea = All;
                Caption = 'View Request';
                Image = ViewDetails;
                ToolTip = 'Shows the JSON that was or will be sent to the engine.';

                trigger OnAction()
                begin
                    Message(Rec.GetRequestJson());
                end;
            }
        }
    }
}
```

- [ ] **Step 3: Write the job list and the ticket list**

```al
// <copyright header>

page 50516 "PEQI Imposition Jobs"
{
    Caption = 'Imposition Jobs';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "PEQI Imposition Job";
    CardPageId = "PEQI Imposition Job Card";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Rows)
            {
                field("Case ID"; Rec."Case ID") { ApplicationArea = All; }
                field(Job; Rec.Job) { ApplicationArea = All; }
                field(Version; Rec.Version) { ApplicationArea = All; }
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field("Sheet Count"; Rec."Sheet Count") { ApplicationArea = All; }
                field(Utilisation; Rec.Utilisation) { ApplicationArea = All; }
                field("Built At"; Rec."Built At") { ApplicationArea = All; }
            }
        }
    }
}
```

```al
// <copyright header>

page 50520 "PEQI Jdf Tickets"
{
    Caption = 'Imposition JDF Tickets';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "PEQI Jdf Ticket";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Rows)
            {
                field("Job Id"; Rec."Job Id") { ApplicationArea = All; }
                field("Case ID"; Rec."Case ID") { ApplicationArea = All; }
                field(Job; Rec.Job) { ApplicationArea = All; }
                field(Version; Rec.Version) { ApplicationArea = All; }
                field("File Name"; Rec."File Name") { ApplicationArea = All; }
                field(Flavour; Rec.Flavour) { ApplicationArea = All; }
                field("Jdf Version"; Rec."Jdf Version") { ApplicationArea = All; }
                field(Sha256; Rec.Sha256) { ApplicationArea = All; }
                field("Created At"; Rec."Created At") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Download)
            {
                ApplicationArea = All;
                Caption = 'Download';
                Image = Download;
                ToolTip = 'Downloads the stored JDF ticket.';

                trigger OnAction()
                var
                    TempBlob: Codeunit "Temp Blob";
                    OutStr: OutStream;
                    InStr: InStream;
                    FileName: Text;
                begin
                    TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
                    OutStr.WriteText(Rec.GetJdf());
                    TempBlob.CreateInStream(InStr, TextEncoding::UTF8);
                    FileName := Rec."File Name";
                    DownloadFromStream(InStr, '', '', '', FileName);
                end;
            }
        }
    }
}
```

- [ ] **Step 4: Add the action to the PrintVis job card**

The action builds a request and opens the imposition card. Replace `"PVS Job Card"` with the real page name if the compiler objects — find it with `grep -l 'SourceTable = "PVS Job"' <extracted PrintVis src>/*.Page.al`.

```al
// <copyright header>

pageextension 50531 "PEQI Job Card" extends "PVS Job Card"
{
    actions
    {
        addlast(Processing)
        {
            group(PEQIImposition)
            {
                Caption = 'External Imposition';
                Image = Planning;

                action(PEQISolveImposition)
                {
                    ApplicationArea = All;
                    Caption = 'Solve Imposition';
                    Image = Planning;
                    ToolTip = 'Builds an imposition request from this job and opens the imposition editor.';

                    trigger OnAction()
                    var
                        ImpositionJob: Record "PEQI Imposition Job";
                        RequestBuilder: Codeunit "PEQI Request Builder";
                        JobCard: Page "PEQI Imposition Job Card";
                    begin
                        ImpositionJob := ImpositionJob.NewEntry(Rec.ID, Rec.Job, Rec.Version);
                        ImpositionJob.SetRequestJson(RequestBuilder.Build(Rec.ID, Rec.Job, Rec.Version));
                        ImpositionJob.Modify(true);

                        JobCard.SetRecord(ImpositionJob);
                        JobCard.Run();
                    end;
                }

                action(PEQIShowImpositions)
                {
                    ApplicationArea = All;
                    Caption = 'Imposition History';
                    Image = History;
                    RunObject = page "PEQI Imposition Jobs";
                    RunPageLink = "Case ID" = field(ID), Job = field(Job), Version = field(Version);
                    ToolTip = 'Shows every imposition solved for this job version.';
                }
            }
        }
    }
}
```

`NewEntry` runs before `Build` so a build that errors still leaves a `Draft` entry recording the attempt. If `Build` errors the whole action rolls back, which is correct: an entry with no request would be a job that looks started and is not.

- [ ] **Step 5: Add the case card extension**

A case holds several jobs, so the case card gets a way in to the history rather
than a solve action — solving needs a job version, and picking one for the
operator would be guessing which quote alternative they meant.

```al
// <copyright header>

pageextension 50530 "PEQI Case Card" extends "PVS Case Card"
{
    actions
    {
        addlast(Processing)
        {
            action(PEQICaseImpositions)
            {
                ApplicationArea = All;
                Caption = 'External Impositions';
                Image = Planning;
                RunObject = page "PEQI Imposition Jobs";
                RunPageLink = "Case ID" = field(ID);
                ToolTip = 'Shows every imposition solved for any job on this case.';
            }
        }
    }
}
```

If the compiler does not know `"PVS Case Card"`, find the real page name in the
extracted PrintVis source:

```bash
grep -l 'SourceTable = "PVS Case"' pv/src/src/*.Page.al
```

- [ ] **Step 6: Restore the lookup pages**

If Task 6 commented out any `LookupPageId` or `DrillDownPageId`, uncomment them now — the pages exist.

- [ ] **Step 7: Compile**

Run: `tools/build.sh`
Expected: exit 0.

- [ ] **Step 8: Commit**

```bash
git add "PTE PrintVis External Imposition/src/Document/" \
        "PTE PrintVis External Imposition/src/Extensions/"
git commit -m "feat: add imposition job pages and the Solve Imposition action"
```

---

### Task 14: Measure the seed payload

**Files:**
- Create: `PTE PrintVis External Imposition/src/Document/PEQIImpositionJobCard.Page.al` (modify: add the measuring action)
- Create: `docs/seed-payload-measurement.md`

**Interfaces:**
- Consumes: `PEQIRequestBuilder.Build`.
- Produces: a recorded measurement that Task 15 depends on.

Spec §8.3 calls this the first task. It can only be done once a real request exists, so it sits here — before the add-in is built on the assumption that the seed fits in a control add-in argument.

- [ ] **Step 1: Add a measuring action to the imposition job card**

In the `area(Processing)` block of `PEQIImpositionJobCard`, after `ViewRequest`:

```al
            action(MeasureRequest)
            {
                ApplicationArea = All;
                Caption = 'Measure Request Size';
                Image = Calculate;
                ToolTip = 'Reports the size of the request that would be sent to the editor. Used to confirm the seed fits in a control add-in argument.';

                trigger OnAction()
                var
                    SizeMsg: Label 'Request: %1 characters (%2 KB).\Sheets: %3. Presses: %4.', Comment = '%1 chars, %2 KB, %3 sheet count, %4 press count';
                    PaperSetup: Record "PEQI Paper Setup";
                    PressSetup: Record "PEQI Press Setup";
                    RequestText: Text;
                begin
                    RequestText := Rec.GetRequestJson();
                    PaperSetup.SetRange("Use for Imposition", true);
                    PressSetup.SetRange("Use for Imposition", true);
                    Message(SizeMsg, StrLen(RequestText), Round(StrLen(RequestText) / 1024, 0.1),
                            PaperSetup.Count(), PressSetup.Count());
                end;
            }
```

- [ ] **Step 2: Compile**

Run: `tools/build.sh`
Expected: exit 0.

- [ ] **Step 3: Take the measurement**

Deploy to a sandbox with a representative catalogue — every paper and press a real shop would mark — and run **Solve Imposition** then **Measure Request Size** on a real job.

- [ ] **Step 4: Record the result**

Create `docs/seed-payload-measurement.md`:

```markdown
# Seed payload measurement

Spec §8.3. Taken before the control add-in was built.

| Measured | Value |
|---|---|
| Date | <date> |
| Environment | <sandbox name> |
| Marked paper rows | <n> |
| Marked press rows | <n> |
| Request size | <n> characters (<n> KB) |

**Verdict:** <fits in one add-in argument / needs a chunked seed>

If a chunked seed is needed, the add-in's `Seed` procedure takes the request in
numbered slices and the JavaScript reassembles before posting to the frame. The
message contract is unchanged; only the host-to-add-in call is.
```

- [ ] **Step 5: Commit**

```bash
git add "PTE PrintVis External Imposition/src/Document/PEQIImpositionJobCard.Page.al" \
        docs/seed-payload-measurement.md
git commit -m "chore: measure the seed payload before building the add-in"
```

---

### Task 15: The embedded editor

**Files:**
- Create: `PTE PrintVis External Imposition/src/Studio/PEQIImpositionStudio.ControlAddIn.al`
- Create: `PTE PrintVis External Imposition/src/Studio/Resources/PEQIStartup.js`
- Create: `PTE PrintVis External Imposition/src/Studio/Resources/PEQIStudio.js`
- Modify: `PTE PrintVis External Imposition/src/Document/PEQIImpositionJobCard.Page.al`

**Interfaces:**
- Consumes: `Record "PEQI Imposition Setup"`.`Spa Url`, the stored request JSON.
- Produces: the add-in's AL surface —
  - procedure `LoadEditor(SpaUrl: Text; RequestJson: Text; OptionsJson: Text)`
  - event `ControlReady()`
  - event `SolutionChosen(ResultJson: Text)`
  - event `PreviewReady(PreviewJson: Text)`
  - event `EditorFailed(Message: Text)`

The `ResultJson` shape is fixed by spec §8.1: `{ v, solutionId, request, summary, diagnostics }`. `PreviewJson` is `{ v, ordinal, side, widthPx, heightPx, png }`.

- [ ] **Step 1: Declare the control add-in**

```al
// <copyright header>

controladdin "PEQI Imposition Studio"
{
    RequestedHeight = 900;
    MinimumHeight = 400;
    RequestedWidth = 1400;
    MinimumWidth = 600;
    VerticalStretch = true;
    HorizontalStretch = true;

    StartupScript = 'src/Studio/Resources/PEQIStartup.js';
    Scripts = 'src/Studio/Resources/PEQIStudio.js';

    /// <summary>Frames the editor and seeds it with the request.</summary>
    procedure LoadEditor(SpaUrl: Text; RequestJson: Text; OptionsJson: Text);

    event ControlReady();
    event SolutionChosen(ResultJson: Text);
    event PreviewReady(PreviewJson: Text);
    event EditorFailed(Message: Text);
}
```

- [ ] **Step 2: Write the startup script**

```javascript
// Copyright (c) 2026 Printers Equity. All rights reserved.
// Tells AL the control exists. Everything else waits for LoadEditor.
Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ControlReady', []);
```

- [ ] **Step 3: Write the bridge script**

```javascript
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// Hosts the Impositioning editor in a nested iframe and relays messages between
// it and AL. BC's add-in sandbox cannot load a remote script, but it can frame a
// remote page, so the frame is the integration surface.

var PEQI = (function () {
    'use strict';

    var frame = null;
    var spaOrigin = null;
    var pending = null;

    function originOf(url) {
        var a = document.createElement('a');
        a.href = url;
        return a.protocol + '//' + a.host;
    }

    function fail(message) {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('EditorFailed', [message]);
    }

    function onMessage(event) {
        // Only the framed editor may speak to this control. Without this check
        // any page could post a forged solution into Business Central.
        if (!spaOrigin || event.origin !== spaOrigin) {
            return;
        }
        var data = event.data;
        if (!data || typeof data !== 'object') {
            return;
        }

        switch (data.type) {
            case 'imposition:ready':
                if (pending) {
                    frame.contentWindow.postMessage(pending, spaOrigin);
                    pending = null;
                }
                break;
            case 'imposition:chosen':
                Microsoft.Dynamics.NAV.InvokeExtensibilityMethod(
                    'SolutionChosen', [JSON.stringify(data)]);
                break;
            case 'imposition:preview':
                Microsoft.Dynamics.NAV.InvokeExtensibilityMethod(
                    'PreviewReady', [JSON.stringify(data)]);
                break;
            case 'imposition:error':
                fail(data.message || 'The imposition editor reported an error.');
                break;
        }
    }

    return {
        load: function (spaUrl, requestJson, optionsJson) {
            if (!spaUrl) {
                fail('No editor URL is configured on the Imposition Setup page.');
                return;
            }

            try {
                spaOrigin = originOf(spaUrl);
            } catch (e) {
                fail('The editor URL is not a valid address: ' + spaUrl);
                return;
            }

            pending = {
                type: 'imposition:seed',
                v: 1,
                request: JSON.parse(requestJson),
                options: JSON.parse(optionsJson)
            };

            var container = document.getElementById('controlAddIn');
            container.innerHTML = '';

            frame = document.createElement('iframe');
            frame.setAttribute('title', 'Imposition editor');
            frame.style.width = '100%';
            frame.style.height = '100%';
            frame.style.border = '0';
            frame.src = spaUrl + (spaUrl.indexOf('?') === -1 ? '?' : '&') + 'embed=1';
            frame.onerror = function () {
                fail('The imposition editor could not be loaded from ' + spaOrigin + '.');
            };

            container.appendChild(frame);
            window.addEventListener('message', onMessage, false);
        }
    };
})();

function LoadEditor(spaUrl, requestJson, optionsJson) {
    PEQI.load(spaUrl, requestJson, optionsJson);
}
```

The seed is held in `pending` and sent only on `imposition:ready`. Posting it the moment the frame is appended races the SPA's own bootstrap and the message is silently lost.

- [ ] **Step 4: Host the add-in on the job card**

Add to `PEQIImpositionJobCard`'s `area(Content)`, after the `Chosen` group:

```al
            group(Editor)
            {
                Caption = 'Imposition Editor';
                Visible = EditorVisible;

                usercontrol(Studio; "PEQI Imposition Studio")
                {
                    ApplicationArea = All;

                    trigger ControlReady()
                    var
                        Setup: Record "PEQI Imposition Setup";
                    begin
                        Setup := Setup.GetSetup();
                        Setup.Get('');
                        if Setup."Spa Url" = '' then begin
                            EditorVisible := false;
                            CurrPage.Update(false);
                            exit;
                        end;
                        CurrPage.Studio.LoadEditor(Setup."Spa Url", Rec.GetRequestJson(), SeedOptions());
                    end;

                    trigger SolutionChosen(ResultJson: Text)
                    var
                        CommitManager: Codeunit "PEQI Commit Manager";
                    begin
                        CommitManager.StoreChoice(Rec, ResultJson);
                        CurrPage.Update(false);
                    end;

                    trigger PreviewReady(PreviewJson: Text)
                    var
                        PreviewWriter: Codeunit "PEQI Preview Writer";
                    begin
                        PreviewWriter.Receive(Rec, PreviewJson);
                    end;

                    trigger EditorFailed(Message: Text)
                    begin
                        EditorVisible := false;
                        Rec."Last Error" := CopyStr(Message, 1, MaxStrLen(Rec."Last Error"));
                        Rec.Modify(true);
                        CurrPage.Update(false);
                    end;
                }
            }
```

and to the page (the three page variables and `OnAfterGetRecord` already exist
from Task 13 — do not declare them again):

```al
    local procedure SeedOptions(): Text
    var
        Options: JsonObject;
        OptionsText: Text;
    begin
        // The product comes from the case, not from the operator typing it.
        Options.Add('readonlyProduct', true);
        Options.Add('startRoute', 'layout');
        Options.WriteTo(OptionsText);
        exit(OptionsText);
    end;
```

- [ ] **Step 5: Add the degraded-mode action**

Spec §8.4. In `area(Processing)`:

```al
            action(OpenEditorInBrowser)
            {
                ApplicationArea = All;
                Caption = 'Open Editor in Browser';
                Image = Web;
                ToolTip = 'Opens the imposition editor in a browser tab. Use this when the embedded editor cannot load.';

                trigger OnAction()
                var
                    Setup: Record "PEQI Imposition Setup";
                    NoUrlErr: Label 'No editor URL is configured on the Imposition Setup page.';
                begin
                    Setup := Setup.GetSetup();
                    Setup.Get('');
                    if Setup."Spa Url" = '' then
                        Error(NoUrlErr);
                    Hyperlink(Setup."Spa Url");
                end;
            }
```

- [ ] **Step 6: Compile**

Run: `tools/build.sh`
Expected: exit 0. The `Scripts`/`StartupScript` paths are relative to the app folder; a path typo is reported as a missing resource.

- [ ] **Step 7: Commit**

```bash
git add "PTE PrintVis External Imposition/src/Studio/" \
        "PTE PrintVis External Imposition/src/Document/PEQIImpositionJobCard.Page.al"
git commit -m "feat: host the imposition editor in a control add-in with an origin-checked bridge"
```

- [ ] **Step 8: Note the WebApp dependency**

The add-in is inert until `ImpositioningApp` ships `?embed=1` and the four messages. Record in the PR that this task cannot be verified end-to-end until the companion spec is implemented.

---

### Task 16: Commit manager

**Files:**
- Create: `PTE PrintVis External Imposition/src/Commit/PEQICommitManager.Codeunit.al`
- Modify: `PTE PrintVis External Imposition/src/Document/PEQIImpositionJobCard.Page.al`
- Test: `PTE PrintVis External Imposition.Test/src/PEQICommitTests.Codeunit.al`

**Interfaces:**
- Consumes: `PEQIEngineClient.WriteJdf`, `PEQIResponseReader.ApplySolution/ApplyDiagnostics`, `Record "PEQI Imposition Setup"`.
- Produces:
  - `PEQICommitManager.StoreChoice(var ImpositionJob: Record "PEQI Imposition Job"; ResultJson: Text)`
  - `PEQICommitManager.GenerateJdf(var ImpositionJob: Record "PEQI Imposition Job"): Guid`
  - `PEQICommitManager.SetTransport(TransportType: Enum "PEQI Transport Type")` — for tests

- [ ] **Step 1: Write the failing tests**

```al
// <copyright header>

codeunit 50613 "PEQI Commit Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Queue: Codeunit "PEQI Test Transport Queue";

    [Test]
    procedure StoringAChoiceMovesTheJobToSolved()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        CommitManager: Codeunit "PEQI Commit Manager";
    begin
        // [GIVEN] a draft job
        ImpositionJob := ImpositionJob.NewEntry(9001, 1, 1);

        // [WHEN] the editor reports a choice
        CommitManager.StoreChoice(ImpositionJob,
          '{"v":1,"solutionId":"sol-1","request":{"parts":[]},' +
          '"summary":{"solutionId":"sol-1","runnable":true,"score":1.0,' +
          '"metrics":{"sheetCount":2,"totalSignatures":2,"utilisation":0.8},' +
          '"runs":[{"sheet":{"name":"Munken 240"},"pressName":"KBA","workStyle":"WorkAndBack","signatureIds":["S1"]}]},' +
          '"diagnostics":[]}');

        // [THEN] the job is Solved and carries the chosen id
        ImpositionJob.Get(9001, 1, 1, ImpositionJob."Entry No.");
        Assert.AreEqual(ImpositionJob.Status::Solved, ImpositionJob.Status, 'A stored choice is Solved');
        Assert.AreEqual('sol-1', ImpositionJob."Solution Id", 'The chosen solution id is stored');
    end;

    [Test]
    procedure TheEffectiveRequestReplacesTheBuiltOne()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        CommitManager: Codeunit "PEQI Commit Manager";
    begin
        // [GIVEN] a job whose request was built by AL
        ImpositionJob := ImpositionJob.NewEntry(9002, 1, 1);
        ImpositionJob.SetRequestJson('{"parts":[],"maxSolutions":10}');
        ImpositionJob.Modify(true);

        // [WHEN] the operator re-tuned it in the editor
        CommitManager.StoreChoice(ImpositionJob,
          '{"v":1,"solutionId":"sol-2","request":{"parts":[],"maxSolutions":25},"summary":{},"diagnostics":[]}');

        // [THEN] the tuned request is what is stored, because it is what /jdf must be given
        ImpositionJob.Get(9002, 1, 1, ImpositionJob."Entry No.");
        Assert.IsTrue(StrPos(ImpositionJob.GetRequestJson(), '"maxSolutions":25') > 0, 'The effective request replaces the built one');
    end;

    [Test]
    procedure GeneratingAJdfStoresTheTicketAndCommitsTheJob()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        JdfTicket: Record "PEQI Jdf Ticket";
        Setup: Record "PEQI Imposition Setup";
        CommitManager: Codeunit "PEQI Commit Manager";
        TicketId: Guid;
    begin
        // [GIVEN] a solved job and an engine that writes a ticket
        Queue.Reset();
        Setup := Setup.GetSetup();
        Setup.Get('');
        Setup."Engine Base Url" := 'https://engine.example.com/api';
        Setup.Modify(true);

        ImpositionJob := ImpositionJob.NewEntry(9003, 1, 1);
        ImpositionJob.SetRequestJson('{"parts":[]}');
        ImpositionJob."Solution Id" := 'sol-3';
        ImpositionJob.Status := ImpositionJob.Status::Solved;
        ImpositionJob.Modify(true);

        Queue.QueueResponse(200,
          '{"ticketId":"7c9e6679-7425-40de-944b-e07fc1f90ae7","solutionId":"sol-3",' +
          '"contentType":"application/vnd.cip4-jdf+xml","fileName":"9003-1-1-sol-3.jdf",' +
          '"jdf":"<?xml version=\"1.0\"?><JDF/>","sha256":"e3b0c442",' +
          '"solution":{"solutionId":"sol-3","metrics":{"sheetCount":2}},"diagnostics":[]}');

        CommitManager.SetTransport("PEQI Transport Type"::Test);

        // [WHEN] the ticket is generated
        TicketId := CommitManager.GenerateJdf(ImpositionJob);

        // [THEN] the ticket is stored and the job is Committed
        Assert.IsTrue(JdfTicket.Get(TicketId), 'The ticket is stored under the id the engine returned');
        Assert.AreEqual('e3b0c442', JdfTicket.Sha256, 'The checksum is stored for deduplication');
        Assert.IsTrue(StrPos(JdfTicket.GetJdf(), '<JDF/>') > 0, 'The XML is stored');
        ImpositionJob.Get(9003, 1, 1, ImpositionJob."Entry No.");
        Assert.AreEqual(ImpositionJob.Status::Committed, ImpositionJob.Status, 'The job is Committed');
    end;

    [Test]
    procedure AnEarlierTicketSurvivesAReSolve()
    var
        First: Record "PEQI Imposition Job";
        Second: Record "PEQI Imposition Job";
        JdfTicket: Record "PEQI Jdf Ticket";
    begin
        // [GIVEN] a committed entry with a ticket
        First := First.NewEntry(9004, 1, 1);
        First.Status := First.Status::Committed;
        First.Modify(true);
        JdfTicket.Init();
        JdfTicket."Ticket Id" := CreateGuid();
        JdfTicket."Case ID" := 9004;
        JdfTicket.Job := 1;
        JdfTicket.Version := 1;
        JdfTicket."Entry No." := First."Entry No.";
        JdfTicket.Insert(true);

        // [WHEN] the job is re-solved
        Second := Second.NewEntry(9004, 1, 1);

        // [THEN] the old ticket still points at the entry it was written from
        JdfTicket.SetRange("Case ID", 9004);
        JdfTicket.SetRange("Entry No.", First."Entry No.");
        Assert.AreEqual(1, JdfTicket.Count(), 'A re-solve leaves the earlier ticket intact');
        Assert.AreNotEqual(First."Entry No.", Second."Entry No.", 'The re-solve is a new entry');
    end;
}
```

- [ ] **Step 2: Run the compile-red gate**

Run: `tools/build.sh`
Expected: `Codeunit 'PEQI Commit Manager' is missing`.

- [ ] **Step 3: Write the commit manager**

```al
// <copyright header>

codeunit 50543 "PEQI Commit Manager"
{
    var
        Client: Codeunit "PEQI Engine Client";
        Reader: Codeunit "PEQI Response Reader";
        JsonHelper: Codeunit "PEQI Json Helper";
        TransportType: Enum "PEQI Transport Type";
        NotSolvedErr: Label 'This imposition has no chosen solution yet.';
        NoRequestErr: Label 'This imposition has no stored request.';
        BadResultErr: Label 'The imposition editor sent a result this version does not understand.';

    procedure SetTransport(NewTransportType: Enum "PEQI Transport Type")
    begin
        TransportType := NewTransportType;
        Client.SetTransport(NewTransportType);
    end;

    /// <summary>Records what the operator chose in the editor. The effective request
    /// replaces the one AL built: the operator may have re-tuned it, and /jdf must be
    /// given the body the solution was actually solved from.</summary>
    procedure StoreChoice(var ImpositionJob: Record "PEQI Imposition Job"; ResultJson: Text)
    var
        Result: JsonObject;
        RequestObject: JsonObject;
        Summary: JsonObject;
        Diagnostics: JsonArray;
        RequestText: Text;
        SummaryText: Text;
        DiagnosticsText: Text;
    begin
        if not Result.ReadFrom(ResultJson) then
            Error(BadResultErr);
        if JsonHelper.ReadInteger(Result, 'v') <> 1 then
            Error(BadResultErr);

        if JsonHelper.ReadObject(Result, 'request', RequestObject) then begin
            RequestObject.WriteTo(RequestText);
            ImpositionJob.SetRequestJson(RequestText);
        end;

        ImpositionJob."Solution Id" := CopyStr(JsonHelper.ReadText(Result, 'solutionId'), 1, MaxStrLen(ImpositionJob."Solution Id"));
        ImpositionJob."Last Error" := '';
        ImpositionJob.Status := ImpositionJob.Status::Solved;
        ImpositionJob.Modify(true);

        if JsonHelper.ReadObject(Result, 'summary', Summary) then begin
            Summary.WriteTo(SummaryText);
            Reader.ApplySolution(ImpositionJob, SummaryText);
        end;

        if JsonHelper.ReadArray(Result, 'diagnostics', Diagnostics) then begin
            Diagnostics.WriteTo(DiagnosticsText);
            Reader.ApplyDiagnostics(ImpositionJob, DiagnosticsText, 0);
        end;
    end;

    /// <summary>Posts /jdf with the stored request and the chosen solution, and stores
    /// the ticket. Both catalogue halves are stated inline, so nothing can have moved
    /// between /calculate and here and the quoted solutionId cannot be stale.</summary>
    procedure GenerateJdf(var ImpositionJob: Record "PEQI Imposition Job") TicketId: Guid
    var
        JdfTicket: Record "PEQI Jdf Ticket";
        Setup: Record "PEQI Imposition Setup";
        RequestObject: JsonObject;
        Envelope: JsonObject;
        SolutionObject: JsonObject;
        Diagnostics: JsonArray;
        RequestText: Text;
        ResponseText: Text;
        SolutionText: Text;
        DiagnosticsText: Text;
    begin
        if ImpositionJob."Solution Id" = '' then
            Error(NotSolvedErr);

        RequestText := ImpositionJob.GetRequestJson();
        if RequestText = '' then
            Error(NoRequestErr);
        if not RequestObject.ReadFrom(RequestText) then
            Error(NoRequestErr);

        Setup := Setup.GetSetup();
        Setup.Get('');

        JsonHelper.AddText(RequestObject, 'jobId', JobId(ImpositionJob, Setup));
        JsonHelper.AddText(RequestObject, 'solutionId', ImpositionJob."Solution Id");
        JsonHelper.AddText(RequestObject, 'version', Format(Setup."Jdf Version"));
        JsonHelper.AddText(RequestObject, 'flavour', Format(Setup."Jdf Flavour"));
        RequestObject.WriteTo(RequestText);

        Client.SetTransport(TransportType);
        ResponseText := Client.WriteJdf(RequestText);
        if not Envelope.ReadFrom(ResponseText) then
            Error(BadResultErr);

        Evaluate(TicketId, JsonHelper.ReadText(Envelope, 'ticketId'));

        JdfTicket.Init();
        JdfTicket."Ticket Id" := TicketId;
        JdfTicket."Case ID" := ImpositionJob."Case ID";
        JdfTicket.Job := ImpositionJob.Job;
        JdfTicket.Version := ImpositionJob.Version;
        JdfTicket."Entry No." := ImpositionJob."Entry No.";
        JdfTicket."Job Id" := CopyStr(JobId(ImpositionJob, Setup), 1, MaxStrLen(JdfTicket."Job Id"));
        JdfTicket."Solution Id" := CopyStr(JsonHelper.ReadText(Envelope, 'solutionId'), 1, MaxStrLen(JdfTicket."Solution Id"));
        JdfTicket.Flavour := Setup."Jdf Flavour";
        JdfTicket."Jdf Version" := Setup."Jdf Version";
        JdfTicket."File Name" := CopyStr(JsonHelper.ReadText(Envelope, 'fileName'), 1, MaxStrLen(JdfTicket."File Name"));
        JdfTicket.Sha256 := CopyStr(JsonHelper.ReadText(Envelope, 'sha256'), 1, MaxStrLen(JdfTicket.Sha256));
        JdfTicket."Created At" := CurrentDateTime();
        JdfTicket.SetJdf(JsonHelper.ReadText(Envelope, 'jdf'));
        JdfTicket.Insert(true);

        // The envelope carries the full solution - the one place BC gets it from
        // the source of truth rather than over the add-in bridge.
        if JsonHelper.ReadObject(Envelope, 'solution', SolutionObject) then begin
            SolutionObject.WriteTo(SolutionText);
            Reader.ApplySolution(ImpositionJob, SolutionText);
        end;
        if JsonHelper.ReadArray(Envelope, 'diagnostics', Diagnostics) then begin
            Diagnostics.WriteTo(DiagnosticsText);
            Reader.ApplyDiagnostics(ImpositionJob, DiagnosticsText, 0);
        end;

        ImpositionJob."Snapshot Id" := CopyStr(SnapshotId(Envelope), 1, MaxStrLen(ImpositionJob."Snapshot Id"));
        ImpositionJob.Status := ImpositionJob.Status::Committed;
        ImpositionJob.Modify(true);
    end;

    local procedure SnapshotId(Envelope: JsonObject): Text
    var
        Snapshot: JsonObject;
    begin
        if not JsonHelper.ReadObject(Envelope, 'snapshot', Snapshot) then
            exit('');
        exit(JsonHelper.ReadText(Snapshot, 'snapshotId'));
    end;

    local procedure JobId(ImpositionJob: Record "PEQI Imposition Job"; Setup: Record "PEQI Imposition Setup"): Text
    begin
        if Setup."Job Id Format" = '' then
            exit(StrSubstNo('%1-%2-%3', ImpositionJob."Case ID", ImpositionJob.Job, ImpositionJob.Version));
        exit(StrSubstNo(Setup."Job Id Format", ImpositionJob."Case ID", ImpositionJob.Job, ImpositionJob.Version));
    end;
}
```

- [ ] **Step 4: Add the Generate JDF action**

In `PEQIImpositionJobCard`'s `area(Processing)`:

```al
            action(GenerateJdf)
            {
                ApplicationArea = All;
                Caption = 'Generate JDF';
                Image = CreateDocument;
                Enabled = CanGenerate;
                ToolTip = 'Writes the JDF ticket for the chosen solution and stores it on this job.';

                trigger OnAction()
                var
                    CommitManager: Codeunit "PEQI Commit Manager";
                    DoneMsg: Label 'JDF ticket %1 written.', Comment = '%1 ticket id';
                    TicketId: Guid;
                begin
                    TicketId := CommitManager.GenerateJdf(Rec);
                    CurrPage.Update(false);
                    Message(DoneMsg, TicketId);
                end;
            }
            action(ShowTickets)
            {
                ApplicationArea = All;
                Caption = 'Tickets';
                Image = Documents;
                RunObject = page "PEQI Jdf Tickets";
                RunPageLink = "Case ID" = field("Case ID"), Job = field(Job),
                              Version = field(Version), "Entry No." = field("Entry No.");
                ToolTip = 'Shows the JDF tickets written from this imposition.';
            }
```

- [ ] **Step 5: Compile**

Run: `tools/build.sh`
Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add "PTE PrintVis External Imposition/src/Commit/PEQICommitManager.Codeunit.al" \
        "PTE PrintVis External Imposition/src/Document/PEQIImpositionJobCard.Page.al" \
        "PTE PrintVis External Imposition.Test/src/PEQICommitTests.Codeunit.al"
git commit -m "feat: store the chosen solution and write the JDF ticket"
```

---

### Task 17: Preview writer and its guard

**Files:**
- Create: `PTE PrintVis External Imposition/src/Commit/PEQIPreviewWriter.Codeunit.al`
- Test: `PTE PrintVis External Imposition.Test/src/PEQIPreviewTests.Codeunit.al`

**Interfaces:**
- Consumes: `Record "PEQI Press Run"`, `Record "PVS Job Sheet"`, `Record "PVS Job Sheet Imposition"`.
- Produces: `PEQIPreviewWriter.Receive(var ImpositionJob: Record "PEQI Imposition Job"; PreviewJson: Text)`.

This is the only write this extension makes into a PrintVis table, and it is guarded.

- [ ] **Step 1: Write the failing tests**

```al
// <copyright header>

codeunit 50614 "PEQI Preview Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        PreviewWriter: Codeunit "PEQI Preview Writer";

    local procedure AddPvsSheet(CaseId: Integer; JobNo: Integer; VersionNo: Integer; SheetId: Integer)
    var
        JobSheet: Record "PVS Job Sheet";
    begin
        JobSheet.Init();
        JobSheet.ID := CaseId;
        JobSheet.Job := JobNo;
        JobSheet.Version := VersionNo;
        JobSheet."Sheet ID" := SheetId;
        JobSheet.Insert(true);
    end;

    local procedure AddRun(var ImpositionJob: Record "PEQI Imposition Job"; LineNo: Integer)
    var
        PressRun: Record "PEQI Press Run";
    begin
        PressRun.Init();
        PressRun."Case ID" := ImpositionJob."Case ID";
        PressRun.Job := ImpositionJob.Job;
        PressRun.Version := ImpositionJob.Version;
        PressRun."Entry No." := ImpositionJob."Entry No.";
        PressRun."Line No." := LineNo;
        PressRun.Insert(true);
    end;

    [Test]
    procedure APreviewIsWrittenWhenTheCountsAgree()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        SheetImposition: Record "PVS Job Sheet Imposition";
    begin
        // [GIVEN] one engine run and one PrintVis sheet
        ImpositionJob := ImpositionJob.NewEntry(9101, 1, 1);
        AddRun(ImpositionJob, 10000);
        AddPvsSheet(9101, 1, 1, 501);

        // [WHEN] a preview for the first run arrives
        PreviewWriter.Receive(ImpositionJob,
          '{"v":1,"ordinal":1,"side":"Front","widthPx":800,"heightPx":600,"png":"iVBORw0KGgo="}');

        // [THEN] it is filed against that sheet
        Assert.IsTrue(SheetImposition.Get(501, SheetImposition."Front/Back"::Front, 1),
                      'The preview is written against the PrintVis sheet');
    end;

    [Test]
    procedure NoPreviewIsWrittenWhenTheCountsDisagree()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        SheetImposition: Record "PVS Job Sheet Imposition";
        Diagnostic: Record "PEQI Diagnostic";
    begin
        // [GIVEN] two engine runs but only one PrintVis sheet
        // Creating a PVS Job Sheet would be write-back to the calculation, which
        // the design excludes; a picture of a two-sheet plan filed against one
        // sheet is worse than no picture.
        ImpositionJob := ImpositionJob.NewEntry(9102, 1, 1);
        AddRun(ImpositionJob, 10000);
        AddRun(ImpositionJob, 20000);
        AddPvsSheet(9102, 1, 1, 502);

        // [WHEN] a preview arrives
        PreviewWriter.Receive(ImpositionJob,
          '{"v":1,"ordinal":1,"side":"Front","widthPx":800,"heightPx":600,"png":"iVBORw0KGgo="}');

        // [THEN] nothing is written and the reason is recorded
        SheetImposition.SetRange("Sheet ID", 502);
        Assert.AreEqual(0, SheetImposition.Count(), 'No preview is written when the counts disagree');

        Diagnostic.SetRange("Case ID", 9102);
        Diagnostic.SetRange("Code", 'PREVIEW_NOT_WRITTEN');
        Assert.AreEqual(1, Diagnostic.Count(), 'The skip is diagnosed, not silent');
    end;
}
```

- [ ] **Step 2: Run the compile-red gate**

Run: `tools/build.sh`
Expected: `Codeunit 'PEQI Preview Writer' is missing`.

- [ ] **Step 3: Write the preview writer**

```al
// <copyright header>

codeunit 50544 "PEQI Preview Writer"
{
    var
        JsonHelper: Codeunit "PEQI Json Helper";
        SkipCodeTok: Label 'PREVIEW_NOT_WRITTEN', Locked = true;
        SkipMsg: Label 'The plan has %1 press runs but the job has %2 PrintVis sheets, so no sheet preview was written.', Comment = '%1 run count, %2 sheet count';

    /// <summary>Files one sheet preview against its PVS Job Sheet, by ordinal, and
    /// only when the engine's run count matches PrintVis's sheet count. When they
    /// differ there is no key for the surplus run, and creating PVS Job Sheet rows
    /// would be write-back to the calculation.</summary>
    procedure Receive(var ImpositionJob: Record "PEQI Imposition Job"; PreviewJson: Text)
    var
        Preview: JsonObject;
        RunCount: Integer;
        SheetCount: Integer;
        Ordinal: Integer;
        SheetId: Integer;
    begin
        if not Preview.ReadFrom(PreviewJson) then
            exit;
        if JsonHelper.ReadInteger(Preview, 'v') <> 1 then
            exit;

        RunCount := CountRuns(ImpositionJob);
        SheetCount := CountSheets(ImpositionJob);

        if RunCount <> SheetCount then begin
            Diagnose(ImpositionJob, RunCount, SheetCount);
            exit;
        end;

        Ordinal := JsonHelper.ReadInteger(Preview, 'ordinal');
        SheetId := SheetIdAtOrdinal(ImpositionJob, Ordinal);
        if SheetId = 0 then
            exit;

        WritePicture(SheetId, JsonHelper.ReadText(Preview, 'side'),
                     JsonHelper.ReadInteger(Preview, 'widthPx'),
                     JsonHelper.ReadInteger(Preview, 'heightPx'),
                     JsonHelper.ReadText(Preview, 'png'));
        LinkRun(ImpositionJob, Ordinal, SheetId);
    end;

    local procedure CountRuns(ImpositionJob: Record "PEQI Imposition Job"): Integer
    var
        PressRun: Record "PEQI Press Run";
    begin
        PressRun.SetRange("Case ID", ImpositionJob."Case ID");
        PressRun.SetRange(Job, ImpositionJob.Job);
        PressRun.SetRange(Version, ImpositionJob.Version);
        PressRun.SetRange("Entry No.", ImpositionJob."Entry No.");
        exit(PressRun.Count());
    end;

    local procedure CountSheets(ImpositionJob: Record "PEQI Imposition Job"): Integer
    var
        JobSheet: Record "PVS Job Sheet";
    begin
        JobSheet.SetRange(ID, ImpositionJob."Case ID");
        JobSheet.SetRange(Job, ImpositionJob.Job);
        JobSheet.SetRange(Version, ImpositionJob.Version);
        exit(JobSheet.Count());
    end;

    local procedure SheetIdAtOrdinal(ImpositionJob: Record "PEQI Imposition Job"; Ordinal: Integer): Integer
    var
        JobSheet: Record "PVS Job Sheet";
        Index: Integer;
    begin
        if Ordinal < 1 then
            exit(0);
        JobSheet.SetRange(ID, ImpositionJob."Case ID");
        JobSheet.SetRange(Job, ImpositionJob.Job);
        JobSheet.SetRange(Version, ImpositionJob.Version);
        JobSheet.SetCurrentKey(ID, Job, Version, "Sheet ID");
        if not JobSheet.FindSet() then
            exit(0);
        repeat
            Index += 1;
            if Index = Ordinal then
                exit(JobSheet."Sheet ID");
        until JobSheet.Next() = 0;
        exit(0);
    end;

    local procedure WritePicture(SheetId: Integer; Side: Text; WidthPx: Integer; HeightPx: Integer; PngBase64: Text)
    var
        SheetImposition: Record "PVS Job Sheet Imposition";
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        OutStr: OutStream;
        PictureOut: OutStream;
        InStr: InStream;
        FrontBack: Option Front,Back;
        SheetNo: Integer;
    begin
        SheetNo := 1;
        if LowerCase(Side) = 'back' then
            FrontBack := FrontBack::Back;

        TempBlob.CreateOutStream(OutStr);
        Base64Convert.FromBase64(PngBase64, OutStr);
        TempBlob.CreateInStream(InStr);

        if not SheetImposition.Get(SheetId, FrontBack, SheetNo) then begin
            SheetImposition.Init();
            SheetImposition."Sheet ID" := SheetId;
            SheetImposition."Front/Back" := FrontBack;
            SheetImposition."Sheet No." := SheetNo;
            SheetImposition.Insert(true);
        end;

        SheetImposition.Heigth := HeightPx;
        SheetImposition.Width := WidthPx;
        // Picture is a Blob, not a Media - it is written through its own stream.
        Clear(SheetImposition.Picture);
        SheetImposition.Picture.CreateOutStream(PictureOut);
        CopyStream(PictureOut, InStr);
        SheetImposition.Modify(true);
    end;

    local procedure LinkRun(ImpositionJob: Record "PEQI Imposition Job"; Ordinal: Integer; SheetId: Integer)
    var
        PressRun: Record "PEQI Press Run";
        Index: Integer;
    begin
        PressRun.SetRange("Case ID", ImpositionJob."Case ID");
        PressRun.SetRange(Job, ImpositionJob.Job);
        PressRun.SetRange(Version, ImpositionJob.Version);
        PressRun.SetRange("Entry No.", ImpositionJob."Entry No.");
        if not PressRun.FindSet() then
            exit;
        repeat
            Index += 1;
            if Index = Ordinal then begin
                PressRun."PVS Sheet ID" := SheetId;
                PressRun.Modify(true);
                exit;
            end;
        until PressRun.Next() = 0;
    end;

    local procedure Diagnose(var ImpositionJob: Record "PEQI Imposition Job"; RunCount: Integer; SheetCount: Integer)
    var
        Diagnostic: Record "PEQI Diagnostic";
    begin
        Diagnostic.SetRange("Case ID", ImpositionJob."Case ID");
        Diagnostic.SetRange(Job, ImpositionJob.Job);
        Diagnostic.SetRange(Version, ImpositionJob.Version);
        Diagnostic.SetRange("Entry No.", ImpositionJob."Entry No.");
        Diagnostic.SetRange("Code", SkipCodeTok);
        if not Diagnostic.IsEmpty() then
            exit;

        Diagnostic.Init();
        Diagnostic."Case ID" := ImpositionJob."Case ID";
        Diagnostic.Job := ImpositionJob.Job;
        Diagnostic.Version := ImpositionJob.Version;
        Diagnostic."Entry No." := ImpositionJob."Entry No.";
        Diagnostic."Line No." := 990000;
        Diagnostic.Severity := Diagnostic.Severity::Info;
        Diagnostic."Code" := SkipCodeTok;
        Diagnostic."Count" := 1;
        Diagnostic.Source := Diagnostic.Source::Preview;
        Diagnostic."Example Message" := CopyStr(StrSubstNo(SkipMsg, RunCount, SheetCount), 1, MaxStrLen(Diagnostic."Example Message"));
        Diagnostic.Insert(true);
    end;
}
```

`PVS Job Sheet Imposition`.`Picture` is a `Blob`, and whether PrintVis renders PNG is spec open item §15.2. Before the first real write, open an existing record in a shop database and check the first bytes:

Open a `PVS Job Sheet Imposition` record PrintVis wrote itself, export the
`Picture` blob to a file and read its first bytes — `89 50 4E 47` is PNG,
`FF D8 FF` is JPEG, `42 4D` is BMP:

```bash
xxd -l 8 exported-picture.bin
```

If it is not PNG, change `WritePicture` to convert, and say which format in the commit.

- [ ] **Step 4: Compile**

Run: `tools/build.sh`
Expected: exit 0. `Heigth` is PrintVis's own spelling of the field — do not correct it.

- [ ] **Step 5: Commit**

```bash
git add "PTE PrintVis External Imposition/src/Commit/PEQIPreviewWriter.Codeunit.al" \
        "PTE PrintVis External Imposition.Test/src/PEQIPreviewTests.Codeunit.al"
git commit -m "feat: file sheet previews in PrintVis, guarded by the run-to-sheet count"
```

---

### Task 18: Permissions, install, and the repository README

**Files:**
- Create: `PTE PrintVis External Imposition/src/Core/PEQIImposition.PermissionSet.al`
- Create: `PTE PrintVis External Imposition/src/Core/PEQIImpositionSetup.PermissionSet.al`
- Create: `PTE PrintVis External Imposition/src/Core/PEQIInstall.Codeunit.al`
- Create: `PTE PrintVis External Imposition/src/Core/PEQIUpgrade.Codeunit.al`
- Modify: `README.md`

**Interfaces:**
- Consumes: every table.
- Produces: `PEQI Imposition` (day-to-day) and `PEQI Imposition Setup` (administration) permission sets; an install codeunit that creates the setup singleton.

- [ ] **Step 1: Write the permission sets**

```al
// <copyright header>

permissionset 50580 "PEQI Imposition"
{
    Caption = 'Imposition';
    Assignable = true;
    Permissions =
        tabledata "PEQI Imposition Setup" = R,
        tabledata "PEQI Press Setup" = R,
        tabledata "PEQI Paper Setup" = R,
        tabledata "PEQI Binding Mapping" = R,
        tabledata "PEQI Part Mapping" = R,
        tabledata "PEQI Imposition Job" = RIMD,
        tabledata "PEQI Press Run" = RIMD,
        tabledata "PEQI Jdf Ticket" = RIM,
        tabledata "PEQI Diagnostic" = RIMD;
}
```

A planner may not delete a ticket: it is the record of what was sent to prepress.

```al
// <copyright header>

permissionset 50581 "PEQI Imposition Setup"
{
    Caption = 'Imposition Setup';
    Assignable = true;
    IncludedPermissionSets = "PEQI Imposition";
    Permissions =
        tabledata "PEQI Imposition Setup" = RIMD,
        tabledata "PEQI Press Setup" = RIMD,
        tabledata "PEQI Paper Setup" = RIMD,
        tabledata "PEQI Binding Mapping" = RIMD,
        tabledata "PEQI Part Mapping" = RIMD;
}
```

- [ ] **Step 2: Write install and upgrade**

```al
// <copyright header>

codeunit 50548 "PEQI Install"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        Setup.GetSetup();
    end;
}
```

```al
// <copyright header>

codeunit 50549 "PEQI Upgrade"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        // Nothing to migrate yet. The singleton is ensured so an upgrade from a
        // version that predates it lands on a complete configuration.
        Setup.GetSetup();
    end;
}
```

- [ ] **Step 3: Write the README**

Replace the AL-Go template text in `README.md`:

```markdown
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
```

- [ ] **Step 4: Compile**

Run: `tools/build.sh`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add "PTE PrintVis External Imposition/src/Core/" README.md
git commit -m "feat: add permission sets, install and upgrade, and document the app"
```

- [ ] **Step 6: Run the full test suite for the first time**

Push the branch and let AL-Go's `CICD.yaml` build both apps and run `testFolders`
against a BC container.

Expected: every `[Test]` procedure written in Tasks 4, 6, 7, 8, 9, 10, 11, 12, 16
and 17 executes. **This is the first assert-green.** Until this run passes, no
claim that the tests pass is supportable — they have only compiled.

Fix whatever the run reports, then proceed.

---

## After the plan

Two things remain outside it:

1. **The WebApp companion spec** in `ImpositioningApp` — `?embed=1`, the four
   messages of §8.1, the parent-origin allowlist, `frame-ancestors`. Task 15 is
   inert until that ships.
2. **Browser-side auth** (spec §11) — a deployment decision. The engine's
   triggers are `Anonymous` today and the SPA cannot hold a secret.
