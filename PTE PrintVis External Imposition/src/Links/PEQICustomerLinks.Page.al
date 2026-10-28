// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Links;

/// <summary>The customer links of one job. The caller filters it by Case ID, Job and Version,
/// and the job actions work on the job of the selected link.</summary>
page 50529 "PEQI Customer Links"
{
    Caption = 'Customer Links';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "PEQI Customer Link";
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Rows)
            {
                field(URL; Rec.URL) { ApplicationArea = All; }
                field(Label; Rec.Label) { ApplicationArea = All; }
                field("Show Book"; Rec."Show Book") { ApplicationArea = All; }
                field("Show Imposition"; Rec."Show Imposition") { ApplicationArea = All; }
                field("Allow File Submission"; Rec."Allow File Submission") { ApplicationArea = All; }
                field("Expires At"; Rec."Expires At") { ApplicationArea = All; }
                field(Sessions; SessionsText)
                {
                    ApplicationArea = All;
                    Caption = 'Sessions Used';
                    ToolTip = 'Browsers that have opened the link, of the most it allows. As of the last refresh.';
                }
                field(State; StateText)
                {
                    ApplicationArea = All;
                    Caption = 'State';
                    ToolTip = 'Active, Used up, Expired or Revoked.';
                }
                field(Pages; PagesText)
                {
                    ApplicationArea = All;
                    Caption = 'Assigned Pages';
                    ToolTip = 'Pages the customer has assigned to a position, of the pages the job has. As of the last refresh.';
                }
                field("Needs Redo"; Rec."Needs Redo")
                {
                    ApplicationArea = All;
                    ToolTip = 'The imposition changed after the customer assigned their pages, so they have to do it again.';
                }
                field(Sync; SyncText)
                {
                    ApplicationArea = All;
                    Caption = 'In Sync';
                    StyleExpr = SyncStyle;
                    ToolTip = 'Out of sync means the customer is looking at another imposition than the approved one. Use Re-sync to put them on the approved one.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Refresh)
            {
                ApplicationArea = All;
                Caption = 'Refresh';
                Image = Refresh;
                ToolTip = 'Fetches sessions used, assigned pages and state of this job''s links from the engine.';

                trigger OnAction()
                var
                    CustomerLink: Record "PEQI Customer Link";
                    LinkMgt: Codeunit "PEQI Customer Link Mgt.";
                begin
                    CustomerLink := Rec;
                    LinkMgt.Refresh(CustomerLink);
                    CurrPage.Update(false);
                end;
            }
            action(Revoke)
            {
                ApplicationArea = All;
                Caption = 'Revoke';
                Image = Cancel;
                Enabled = HasLink;
                ToolTip = 'Switches the link off. Anyone who opens it afterwards is told it is no longer valid.';

                trigger OnAction()
                var
                    CustomerLink: Record "PEQI Customer Link";
                    LinkMgt: Codeunit "PEQI Customer Link Mgt.";
                begin
                    CustomerLink := Rec;
                    LinkMgt.Revoke(CustomerLink);
                    CurrPage.Update(false);
                end;
            }
            action(Resync)
            {
                ApplicationArea = All;
                Caption = 'Re-sync';
                Image = ReOpen;
                Enabled = HasLink;
                ToolTip = 'Makes the approved imposition the one this job''s customer links show.';

                trigger OnAction()
                var
                    LinkMgt: Codeunit "PEQI Customer Link Mgt.";
                begin
                    LinkMgt.Resync(Rec."Case ID", Rec.Job, Rec.Version);
                    CurrPage.Update(false);
                end;
            }
            action(ClearSubmission)
            {
                ApplicationArea = All;
                Caption = 'Clear Customer Submission';
                Image = ClearLog;
                Enabled = HasLink;
                ToolTip = 'Throws away the pages the customer has assigned and previewed for this job, so they start over.';

                trigger OnAction()
                var
                    LinkMgt: Codeunit "PEQI Customer Link Mgt.";
                begin
                    // It cannot be undone, and the customer may be part way through.
                    if not Confirm(ClearQst, false) then
                        exit;
                    LinkMgt.ClearSubmission(Rec."Case ID", Rec.Job, Rec.Version);
                end;
            }
            action(CopyLink)
            {
                ApplicationArea = All;
                Caption = 'Copy Link';
                Image = Copy;
                Enabled = HasLink;
                ToolTip = 'Shows the link so you can select it and copy it.';

                trigger OnAction()
                var
                    Created: Page "PEQI Customer Link Created";
                begin
                    Created.SetLink(Rec.URL, Rec);
                    Created.RunModal();
                end;
            }
        }
    }

    var
        SessionsText: Text;
        StateText: Text;
        PagesText: Text;
        SyncText: Text;
        SyncStyle: Text;
        HasLink: Boolean;
        ClearQst: Label 'Clear everything the customer has assigned and previewed for this job? They will have to start over.';
        OfTxt: Label '%1 of %2', Comment = '%1 a count, %2 the most it can be';

    trigger OnOpenPage()
    begin
        // The newest first: the link the planner has just made is the one they want.
        Rec.SetCurrentKey("Case ID", Job, Version, "Created At");
        Rec.Ascending(false);
    end;

    trigger OnAfterGetCurrRecord()
    begin
        HasLink := not IsNullGuid(Rec."Link Id");
    end;

    trigger OnAfterGetRecord()
    var
        LinkMgt: Codeunit "PEQI Customer Link Mgt.";
    begin
        SessionsText := StrSubstNo(OfTxt, Rec."Sessions Used", Rec."Max Sessions");
        // The page count is the ticket's and only known from a submission.
        if Rec."Total Pages" > 0 then
            PagesText := StrSubstNo(OfTxt, Rec."Assigned Pages", Rec."Total Pages")
        else
            PagesText := '';
        StateText := LinkMgt.StateOf(Rec);
        SyncText := LinkMgt.SyncOf(Rec);
        if (SyncText <> '') and not Rec."In Sync" then
            SyncStyle := 'Unfavorable'
        else
            SyncStyle := 'Standard';
    end;
}
