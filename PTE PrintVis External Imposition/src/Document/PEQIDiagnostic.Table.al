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

using PrintersEquity.ExternalImposition.Enums;

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
