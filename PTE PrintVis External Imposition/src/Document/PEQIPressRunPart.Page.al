// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

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
