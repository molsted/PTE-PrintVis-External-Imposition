// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Links;

/// <summary>What the planner chooses when making a customer link. Never stored: the page that
/// asks for it works on a temporary record, and only the link the engine returns is kept.</summary>
table 50512 "PEQI Customer Link Settings"
{
    Caption = 'Customer Link Settings';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; "Primary Key"; Code[10]) { Caption = 'Primary Key'; }
        field(10; "Show Imposition"; Boolean) { Caption = 'Show Imposition'; }
        field(11; "Show Book"; Boolean) { Caption = 'Show Book'; }
        field(12; "Allow File Submission"; Boolean) { Caption = 'Allow File Submission'; }
        field(13; "Expires At"; DateTime) { Caption = 'Expires At'; }
        field(14; "Max Sessions"; Integer) { Caption = 'Max Sessions'; }
        field(15; Label; Text[100]) { Caption = 'Label'; }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }
}
