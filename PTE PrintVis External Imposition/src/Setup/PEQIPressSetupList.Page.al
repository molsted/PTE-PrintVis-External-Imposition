// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Setup;

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
