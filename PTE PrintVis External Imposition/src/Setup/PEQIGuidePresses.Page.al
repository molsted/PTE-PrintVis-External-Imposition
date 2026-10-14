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

using PrintersEquity.ExternalImposition.Mapping;

/// <summary>Cost center configurations in the setup guide: the ones marked for imposition, or all
/// of them, with what stops each being a press.</summary>
/// <remarks>
/// Not the Cost Center Card's part: that one is linked to a single cost center and has no cost
/// center column, so across every cost center its rows could not be told apart. This one carries
/// the cost center, the fields the guide checks, and PrintVis's maximum printing format read-only,
/// and opens the Cost Center Card for the rest. Both edit the same rows.
/// </remarks>
page 50525 "PEQI Guide Presses"
{
    Caption = 'Presses';
    PageType = ListPart;
    SourceTable = "PVS Cost Center Configuration";
    InsertAllowed = false;
    DeleteAllowed = false;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Configurations)
            {
                field("Cost Center Code"; Rec."Cost Center Code") { Editable = false; ToolTip = 'The PrintVis cost center.'; }
                field(Configuration; Rec.Configuration) { Editable = false; ToolTip = 'The PrintVis configuration. Each one marked for imposition is a press.'; }
                field(Name; Rec.Name) { Editable = false; ToolTip = 'The configuration''s name in PrintVis, sent as the press name.'; }
                field("PEQI Use for Imposition"; Rec."PEQI Use for Imposition") { ToolTip = 'Offer this configuration to the imposition engine as a press.'; }
                field("PEQI Gripper Edge Side"; Rec."PEQI Gripper Edge Side") { ToolTip = 'Which physical edge the gripper is on. PrintVis records the gripper as a measurement and never names its edge.'; }
                field("PEQI Simplex"; Rec."PEQI Simplex") { ToolTip = 'This press prints one side per pass.'; }
                field("PEQI Work And Back"; Rec."PEQI Work And Back") { ToolTip = 'This press can print work-and-back.'; }
                field("PEQI Work And Turn"; Rec."PEQI Work And Turn") { ToolTip = 'This press can print work-and-turn.'; }
                field("PEQI Work And Tumble"; Rec."PEQI Work And Tumble") { ToolTip = 'This press can print work-and-tumble.'; }
                field("PEQI Perfecting"; Rec."PEQI Perfecting") { ToolTip = 'This press perfects both sides in one pass.'; }
                field("Max Printing Format Length"; Rec."Max Printing Format Length") { Editable = false; CaptionClass = Units.FormatCaptionClass('Max Printing Format Length'); ToolTip = 'PrintVis''s maximum printing format. Change it on the Cost Center Card.'; }
                field("Max Printing Format Width"; Rec."Max Printing Format Width") { Editable = false; CaptionClass = Units.FormatCaptionClass('Max Printing Format Width'); ToolTip = 'PrintVis''s maximum printing format. Change it on the Cost Center Card.'; }
                field(ProblemText; ProblemText)
                {
                    Caption = 'Needs Attention';
                    Editable = false;
                    StyleExpr = ProblemStyle;
                    ToolTip = 'What stops this configuration being a press. Blank when nothing does, or when it is not marked.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ShowAll)
            {
                Caption = 'Show All';
                Image = AllLines;
                Visible = MarkedView;
                ToolTip = 'Lists every cost center configuration, so one can be marked for imposition.';

                trigger OnAction()
                begin
                    ShowMarked(false);
                    CurrPage.Update(false);
                end;
            }
            action(ShowMarkedOnly)
            {
                Caption = 'Show Marked for Imposition';
                Image = FilterLines;
                Visible = not MarkedView;
                ToolTip = 'Lists only the configurations marked for imposition.';

                trigger OnAction()
                begin
                    ShowMarked(true);
                    CurrPage.Update(false);
                end;
            }
            action(OpenCostCenter)
            {
                Caption = 'Open Cost Center';
                Image = Card;
                RunObject = page "PVS Cost Center Card";
                RunPageLink = Code = field("Cost Center Code");
                ToolTip = 'Opens the PrintVis Cost Center Card, whose Imposition section holds every press setting.';
            }
        }
    }

    var
        Checks: Codeunit "PEQI Setup Checks";
        Units: Codeunit "PEQI Unit Converter";
        ProblemText: Text;
        ProblemStyle: Text;
        MarkedView: Boolean;

    trigger OnOpenPage()
    begin
        ShowMarked(true);
    end;

    trigger OnAfterGetRecord()
    var
        Problems: List of [Text];
    begin
        if Rec."PEQI Use for Imposition" then begin
            Checks.PressProblems(Rec, Problems);
            Checks.PressSetupGaps(Rec, Problems);
        end;
        ProblemText := Checks.JoinProblems(Problems);
        if ProblemText = '' then
            ProblemStyle := 'Standard'
        else
            ProblemStyle := 'Unfavorable';
    end;

    local procedure ShowMarked(Marked: Boolean)
    begin
        MarkedView := Marked;
        if Marked then
            Rec.SetRange("PEQI Use for Imposition", true)
        else
            Rec.SetRange("PEQI Use for Imposition");
        if Rec.FindFirst() then;
    end;
}
