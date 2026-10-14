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

/// <summary>Component types in the setup guide, with what stops each being imposed.</summary>
/// <remarks>Edits PrintVis's own JDF Product Type and this extension's grain rule in place. Opens
/// on the rows that need attention; Show All lists every component type.</remarks>
page 50523 "PEQI Guide Component Types"
{
    Caption = 'Component Types';
    PageType = ListPart;
    SourceTable = "PVS Component Types";
    InsertAllowed = false;
    DeleteAllowed = false;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Types)
            {
                field(Code; Rec.Code) { Editable = false; ToolTip = 'The PrintVis component type.'; }
                field(Description; Rec.Description) { Editable = false; ToolTip = 'The component type''s description in PrintVis.'; }
                field("JDF Product Type"; Rec."JDF Product Type") { ToolTip = 'What the part is, as JDF names it. Sent to the engine as the part''s product type; Unknown is refused.'; }
                field("PEQI Grain Rule"; Rec."PEQI Grain Rule") { ToolTip = 'Whether this component''s grain must run parallel to the spine. Not set is refused.'; }
                field(ProblemText; ProblemText)
                {
                    Caption = 'Needs Attention';
                    Editable = false;
                    StyleExpr = ProblemStyle;
                    ToolTip = 'What stops a job using this component type being imposed. Blank when nothing does.';
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
                Visible = ProblemsOnly;
                ToolTip = 'Lists every component type.';

                trigger OnAction()
                begin
                    MarkProblems(false);
                    CurrPage.Update(false);
                end;
            }
            action(ShowProblems)
            {
                Caption = 'Show Needing Attention';
                Image = FilterLines;
                Visible = not ProblemsOnly;
                ToolTip = 'Lists only the component types that stop a job being imposed.';

                trigger OnAction()
                begin
                    MarkProblems(true);
                    CurrPage.Update(false);
                end;
            }
            action(OpenCard)
            {
                Caption = 'Open Component Type';
                Image = Card;
                RunObject = page "PVS Component Types Card";
                RunPageLink = Code = field(Code);
                ToolTip = 'Opens the PrintVis component type card, for anything beyond these columns.';
            }
        }
    }

    var
        Checks: Codeunit "PEQI Setup Checks";
        ProblemText: Text;
        ProblemStyle: Text;
        ProblemsOnly: Boolean;

    trigger OnOpenPage()
    begin
        MarkProblems(true);
    end;

    trigger OnAfterGetRecord()
    var
        Problems: List of [Text];
    begin
        Checks.ComponentTypeProblems(Rec, Problems);
        ProblemText := Checks.JoinProblems(Problems);
        if ProblemText = '' then
            ProblemStyle := 'Standard'
        else
            ProblemStyle := 'Unfavorable';
    end;

    local procedure MarkProblems(Only: Boolean)
    var
        Problems: List of [Text];
    begin
        ProblemsOnly := Only;
        Rec.MarkedOnly(false);
        Rec.ClearMarks();
        if Only then begin
            if Rec.FindSet() then
                repeat
                    Clear(Problems);
                    Checks.ComponentTypeProblems(Rec, Problems);
                    if Problems.Count() > 0 then
                        Rec.Mark(true);
                until Rec.Next() = 0;
            Rec.MarkedOnly(true);
        end;
        if Rec.FindFirst() then;
    end;
}
