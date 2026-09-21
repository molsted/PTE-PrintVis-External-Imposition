// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

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
