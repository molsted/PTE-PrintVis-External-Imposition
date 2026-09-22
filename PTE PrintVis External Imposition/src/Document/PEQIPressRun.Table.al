// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Document;

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
