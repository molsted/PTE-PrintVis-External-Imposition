// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Extensions;

using PrintersEquity.ExternalImposition.Document;

pageextension 50532 "PEQI Job Items ListPart" extends "PVS Job Items ListPart"
{
    actions
    {
        addlast(processing)
        {
            action(PEQIBookPreview)
            {
                ApplicationArea = All;
                Caption = 'Book Preview';
                Image = View;
                ToolTip = 'Shows the approved imposition of this job as a flip-book.';
                Enabled = HasApproved;

                trigger OnAction()
                var
                    JdfTicket: Record "PEQI Jdf Ticket";
                    BookPreviewMgt: Codeunit "PEQI Book Preview Mgt.";
                    BookPage: Page "PEQI Book Preview";
                    NoApprovalErr: Label 'This job has no approved imposition yet.';
                begin
                    if not BookPreviewMgt.FindApprovedTicket(Rec.ID, Rec.Job, Rec.Version, JdfTicket) then
                        Error(NoApprovalErr);
                    BookPage.SetTicket(JdfTicket);
                    BookPage.Run();
                end;
            }
        }
    }

    var
        // Computed once per row rather than in Enabled, which is evaluated on every redraw.
        HasApproved: Boolean;

    trigger OnAfterGetCurrRecord()
    var
        BookPreviewMgt: Codeunit "PEQI Book Preview Mgt.";
    begin
        HasApproved := BookPreviewMgt.HasApprovedTicket(Rec.ID, Rec.Job, Rec.Version);
    end;
}
