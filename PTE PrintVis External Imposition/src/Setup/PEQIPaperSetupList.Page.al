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

using PrintersEquity.ExternalImposition.Enums;

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
