// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

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
