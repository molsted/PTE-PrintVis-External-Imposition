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

using Microsoft.Utilities;

/// <summary>Everything the setup checks found, for the setup guide's summary.</summary>
page 50526 "PEQI Setup Findings"
{
    Caption = 'Still Open';
    PageType = ListPart;
    SourceTable = "PEQI Setup Finding";
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Findings)
            {
                field(Severity; Rec.Severity) { StyleExpr = SeverityStyle; ToolTip = 'Blocking stops every job; a warning stops only the jobs that use what it names.'; }
                field("Setup Area"; Rec."Setup Area") { ToolTip = 'The step of this guide that covers it.'; }
                field(Description; Rec.Description) { ToolTip = 'What was found.'; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenRecord)
            {
                Caption = 'Open';
                Image = View;
                Scope = Repeater;
                ToolTip = 'Opens the PrintVis record this finding is about.';

                trigger OnAction()
                var
                    PageManagement: Codeunit "Page Management";
                    RecRef: RecordRef;
                begin
                    if Rec."Record Id".TableNo() = 0 then begin
                        Message(NoRecordMsg, Rec."Setup Area");
                        exit;
                    end;
                    RecRef.Open(Rec."Record Id".TableNo());
                    if not RecRef.Get(Rec."Record Id") then
                        exit;
                    if not PageManagement.PageRun(RecRef) then
                        Message(NoPageMsg);
                end;
            }
        }
    }

    var
        SeverityStyle: Text;
        NoRecordMsg: Label 'This finding is about the setup as a whole, not one record. Fix it on the %1 step.', Comment = '%1 step';
        NoPageMsg: Label 'Business Central has no page to open this record on.';

    trigger OnAfterGetRecord()
    begin
        if Rec.Severity = Rec.Severity::Blocking then
            SeverityStyle := 'Unfavorable'
        else
            SeverityStyle := 'Ambiguous';
    end;

    /// <summary>Shows these findings in place of whatever was shown.</summary>
    procedure Load(var Findings: Record "PEQI Setup Finding" temporary)
    var
        Source: Record "PEQI Setup Finding" temporary;
    begin
        Rec.Reset();
        Rec.DeleteAll();
        Source.Copy(Findings, true);
        Source.Reset();
        if Source.FindSet() then
            repeat
                Rec := Source;
                Rec.Insert();
            until Source.Next() = 0;
        // Blocking sorts first, so what stops every job is what the summary lists first.
        Rec.SetCurrentKey(Severity, "Entry No.");
        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;
}
