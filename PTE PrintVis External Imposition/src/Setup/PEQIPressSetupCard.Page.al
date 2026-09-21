// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

page 50512 "PEQI Press Setup Card"
{
    Caption = 'Imposition Press Setup';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "PEQI Press Setup";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("Cost Center Code"; Rec."Cost Center Code") { ApplicationArea = All; }
                field(Configuration; Rec.Configuration) { ApplicationArea = All; }
                field("Use for Imposition"; Rec."Use for Imposition") { ApplicationArea = All; }
                field("Press Id"; Rec."Press Id") { ApplicationArea = All; }
                field("Use Press Type Override"; Rec."Use Press Type Override") { ApplicationArea = All; }
                field("Press Type Override"; Rec."Press Type Override")
                {
                    ApplicationArea = All;
                    Enabled = Rec."Use Press Type Override";
                }
            }
            group(Edges)
            {
                Caption = 'Edges and Margins';
                field("Gripper Edge Side"; Rec."Gripper Edge Side") { ApplicationArea = All; }
                field("Side Lay Edge"; Rec."Side Lay Edge") { ApplicationArea = All; }
                field("Non-Printable Top (mm)"; Rec."Non-Printable Top (mm)") { ApplicationArea = All; }
                field("Non-Printable Bottom (mm)"; Rec."Non-Printable Bottom (mm)") { ApplicationArea = All; }
                field("Non-Printable Left (mm)"; Rec."Non-Printable Left (mm)") { ApplicationArea = All; }
                field("Non-Printable Right (mm)"; Rec."Non-Printable Right (mm)") { ApplicationArea = All; }
                field("Max Image Area Width (mm)"; Rec."Max Image Area Width (mm)") { ApplicationArea = All; }
                field("Max Image Area Height (mm)"; Rec."Max Image Area Height (mm)") { ApplicationArea = All; }
            }
            group(Plate)
            {
                Caption = 'Plate';
                field("Plate Punch (mm)"; Rec."Plate Punch (mm)") { ApplicationArea = All; }
            }
            group(WorkStyles)
            {
                Caption = 'Work Styles';
                field(Simplex; Rec.Simplex) { ApplicationArea = All; }
                field("Work And Back"; Rec."Work And Back") { ApplicationArea = All; }
                field("Work And Turn"; Rec."Work And Turn")
                {
                    ApplicationArea = All;
                    ToolTip = 'The engine never derives this one - it must be stated.';
                }
                field("Work And Tumble"; Rec."Work And Tumble")
                {
                    ApplicationArea = All;
                    ToolTip = 'The engine never derives this one - it must be stated.';
                }
                field(Perfecting; Rec.Perfecting) { ApplicationArea = All; }
            }
            group(Speed)
            {
                Caption = 'Speed';
                field("Sheets Per Hour"; Rec."Sheets Per Hour") { ApplicationArea = All; }
            }
        }
    }
}
