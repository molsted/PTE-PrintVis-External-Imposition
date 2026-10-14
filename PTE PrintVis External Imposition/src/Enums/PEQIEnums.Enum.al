// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Enums;

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

/// <summary>Where a press grips the sheet, in the press's own orientation. Bottom comes first so
/// that every configuration, including those from before this field existed, starts at Bottom.</summary>
enum 50567 "PEQI Gripper Side"
{
    Extensible = false;
    value(0; Bottom) { Caption = 'Bottom'; }
    value(1; Both) { Caption = 'Both (top and bottom)'; }
}

enum 50559 "PEQI Grain Policy"
{
    Extensible = false;
    value(0; Ignored) { Caption = 'Ignored'; }
    value(1; Preferred) { Caption = 'Preferred'; }
    value(2; Required) { Caption = 'Required'; }
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

enum 50564 "PEQI Digital Subtype"
{
    Extensible = false;
    Caption = 'Digital Subtype';

    value(0; " ") { Caption = ' '; }
    value(1; Toner) { Caption = 'Toner'; }
    value(2; Inkjet) { Caption = 'Inkjet'; }
}

/// <summary>Whether a component's grain must run parallel to the spine. "Not set" comes first on
/// purpose: an extension field on rows that already exist takes the type's first value, so the
/// first value has to mean "nobody has chosen" -- not Any, which would silently stop enforcing
/// grain on every existing component type.</summary>
enum 50554 "PEQI Component Grain Rule"
{
    Extensible = false;
    Caption = 'Imposition Grain Rule';

    value(0; NotSet) { Caption = 'Not set'; }
    value(1; Any) { Caption = 'Any'; }
    value(2; ParallelToSpine) { Caption = 'Parallel to spine'; }
}

/// <summary>How much a setup finding matters. A blocking finding breaks every job, so the setup
/// guide stays incomplete while one remains; a warning breaks only the jobs that use what it
/// names.</summary>
enum 50565 "PEQI Finding Severity"
{
    Extensible = false;
    value(0; Blocking) { Caption = 'Blocking'; }
    value(1; Warning) { Caption = 'Warning'; }
}

/// <summary>The part of the setup a finding is about, one per checking step of the setup guide.</summary>
enum 50566 "PEQI Setup Area"
{
    Extensible = false;
    value(0; Connection) { Caption = 'Connection'; }
    value(1; ComponentTypes) { Caption = 'Component types'; }
    value(2; FinishingTypes) { Caption = 'Finishing types'; }
    value(3; Presses) { Caption = 'Presses'; }
    value(4; PaperAndUnits) { Caption = 'Paper and units'; }
    value(5; Permissions) { Caption = 'Permissions'; }
}
