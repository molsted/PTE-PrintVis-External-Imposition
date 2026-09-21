// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

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
