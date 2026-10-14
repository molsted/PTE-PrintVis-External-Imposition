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

/// <summary>Finishing types in the setup guide, with what stops each binding a job.</summary>
/// <remarks>Edits PrintVis's own CIP4 Binding and CIP4 BindingSide in place. Opens on the rows
/// that need attention; Show All lists every finishing type. A bottom side is shown as a problem
/// here even though a job whose imposition code states the spine never reads it: the guide asks
/// of no job in particular.</remarks>
page 50524 "PEQI Guide Finishing Types"
{
    Caption = 'Finishing Types';
    PageType = ListPart;
    SourceTable = "PVS Finishing Types";
    InsertAllowed = false;
    DeleteAllowed = false;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Types)
            {
                field(Code; Rec.Code) { Editable = false; ToolTip = 'The PrintVis finishing type.'; }
                field(Description; Rec.Description) { Editable = false; ToolTip = 'The finishing type''s description in PrintVis.'; }
                field("CIP4 Binding"; Rec."CIP4 Binding") { ToolTip = 'How a job with this finishing is bound. Saddle stitch is saddle-stitched, Adhesive and Soft Cover are perfect bound, Cutting, Folding and the like are unbound. Misc. means not set, and is refused.'; }
                field("CIP4 BindingSide"; Rec."CIP4 BindingSide") { ToolTip = 'Which edge the spine is on, unless the job''s imposition code says. Bottom is refused.'; }
                field(ProblemText; ProblemText)
                {
                    Caption = 'Needs Attention';
                    Editable = false;
                    StyleExpr = ProblemStyle;
                    ToolTip = 'What stops a job with this finishing being imposed. Blank when nothing does.';
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
                ToolTip = 'Lists every finishing type.';

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
                ToolTip = 'Lists only the finishing types that stop a job being imposed.';

                trigger OnAction()
                begin
                    MarkProblems(true);
                    CurrPage.Update(false);
                end;
            }
            action(OpenList)
            {
                Caption = 'Open Finishing Types';
                Image = List;
                RunObject = page "PVS Finishing Types";
                RunPageLink = Code = field(Code);
                ToolTip = 'Opens the PrintVis finishing types, for anything beyond these columns.';
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
        Checks.FinishingTypeProblems(Rec, false, Problems);
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
                    Checks.FinishingTypeProblems(Rec, false, Problems);
                    if Problems.Count() > 0 then
                        Rec.Mark(true);
                until Rec.Next() = 0;
            Rec.MarkedOnly(true);
        end;
        if Rec.FindFirst() then;
    end;
}
