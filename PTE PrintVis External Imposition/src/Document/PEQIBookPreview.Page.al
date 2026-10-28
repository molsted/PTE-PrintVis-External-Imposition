// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Document;

using PrintersEquity.ExternalImposition.Setup;
using PrintersEquity.ExternalImposition.Studio;

/// <summary>Shows the approved imposition of a job as a flip-book. It has no source table: the
/// ticket is handed in by the caller, so the page can be opened from any list that knows a job.</summary>
page 50527 "PEQI Book Preview"
{
    Caption = 'Book Preview';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    Editable = false;

    layout
    {
        area(Content)
        {
            // Shown instead of the control, never beside it: a blank control gives the user no clue
            // whether the editor is slow, misconfigured or broken.
            group(Problem)
            {
                ShowCaption = false;
                Visible = ProblemVisible;

                field(ProblemText; ProblemText)
                {
                    ApplicationArea = All;
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                    StyleExpr = 'Unfavorable';
                }
            }
            group(Viewer)
            {
                ShowCaption = false;
                Visible = EditorVisible;

                usercontrol(Book; "PEQI Imposition Studio")
                {
                    ApplicationArea = All;

                    trigger ControlReady()
                    var
                        Setup: Record "PEQI Imposition Setup";
                        ImpositionJob: Record "PEQI Imposition Job";
                        BookPreviewMgt: Codeunit "PEQI Book Preview Mgt.";
                        NoUrlErr: Label 'No editor URL is configured on the Imposition Setup page.';
                        NoJobErr: Label 'The imposition this ticket belongs to no longer exists.';
                    begin
                        Setup := Setup.GetSetup();
                        if Setup."Spa Url" = '' then begin
                            ShowProblem(NoUrlErr);
                            exit;
                        end;
                        // The options are keyed by the job entry the ticket was written from, so the
                        // editor can tell this book from any other it has been shown.
                        if not ImpositionJob.Get(Ticket."Case ID", Ticket.Job, Ticket.Version, Ticket."Entry No.") then begin
                            ShowProblem(NoJobErr);
                            exit;
                        end;
                        CurrPage.Book.LoadBook(Setup."Spa Url", Ticket.GetJdf(), BookPreviewMgt.BookOptions(ImpositionJob.EntryKey()));
                    end;

                    trigger SolutionChosen(ResultJson: Text)
                    begin
                    end;

                    trigger PreviewReady(PreviewJson: Text)
                    begin
                    end;

                    trigger EditorFailed(Message: Text)
                    begin
                        ShowProblem(Message);
                    end;
                }
            }
        }
    }

    var
        Ticket: Record "PEQI Jdf Ticket";
        EditorVisible: Boolean;
        ProblemVisible: Boolean;
        ProblemText: Text;

    trigger OnInit()
    begin
        EditorVisible := true;
    end;

    procedure SetTicket(JdfTicket: Record "PEQI Jdf Ticket")
    begin
        Ticket := JdfTicket;
    end;

    local procedure ShowProblem(Message: Text)
    begin
        ProblemText := Message;
        ProblemVisible := true;
        EditorVisible := false;
        CurrPage.Update(false);
    end;
}
