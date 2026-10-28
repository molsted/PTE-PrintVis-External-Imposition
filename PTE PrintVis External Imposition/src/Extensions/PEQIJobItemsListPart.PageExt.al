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
using PrintersEquity.ExternalImposition.Links;

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
                Visible = CanPreview;

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
            action(PEQIGenerateCustomerLink)
            {
                ApplicationArea = All;
                Caption = 'Generate Customer Link';
                Image = Link;
                ToolTip = 'Makes a link the customer can open to see the approved imposition, with the defaults from Imposition Setup.';
                Enabled = HasApproved;
                Visible = CanPreview;

                trigger OnAction()
                var
                    CustomerLink: Record "PEQI Customer Link";
                    LinkMgt: Codeunit "PEQI Customer Link Mgt.";
                    Url: Text;
                begin
                    Url := LinkMgt.CreateLinkWithDefaults(Rec.ID, Rec.Job, Rec.Version, CustomerLink);
                    ShowLink(Url, CustomerLink);
                end;
            }
            action(PEQIGenerateCustomerLinkWithSettings)
            {
                ApplicationArea = All;
                Caption = 'Generate Customer Link with Settings...';
                Image = LinkWeb;
                ToolTip = 'Makes a customer link after letting you choose its features, expiry and number of sessions.';
                Enabled = HasApproved;
                Visible = CanPreview;

                trigger OnAction()
                var
                    CustomerLink: Record "PEQI Customer Link";
                    Settings: Record "PEQI Customer Link Settings" temporary;
                    LinkMgt: Codeunit "PEQI Customer Link Mgt.";
                    Dialog: Page "PEQI Customer Link Settings";
                    Url: Text;
                begin
                    LinkMgt.DefaultSettings(Settings);
                    // DefaultSettings may have created the setup row, and RunModal refuses to start
                    // inside a write transaction.
                    Commit();
                    Dialog.SetSettings(Settings);
                    if Dialog.RunModal() <> Action::OK then
                        exit;
                    Dialog.GetSettings(Settings);
                    Url := LinkMgt.CreateLink(Rec.ID, Rec.Job, Rec.Version, Settings, CustomerLink);
                    ShowLink(Url, CustomerLink);
                end;
            }
            action(PEQICustomerLinks)
            {
                ApplicationArea = All;
                Caption = 'Customer Links';
                Image = Links;
                ToolTip = 'Shows the customer links made for this job, and what the customers have done with them.';
                Visible = CanPreview;

                trigger OnAction()
                var
                    CustomerLink: Record "PEQI Customer Link";
                begin
                    CustomerLink.SetRange("Case ID", Rec.ID);
                    CustomerLink.SetRange(Job, Rec.Job);
                    CustomerLink.SetRange(Version, Rec.Version);
                    Page.Run(Page::"PEQI Customer Links", CustomerLink);
                end;
            }
        }
    }

    var
        // Computed once per row rather than in Enabled, which is evaluated on every redraw.
        HasApproved: Boolean;
        // Users without the imposition permissions never see the action.
        CanPreview: Boolean;

    local procedure ShowLink(Url: Text; CustomerLink: Record "PEQI Customer Link")
    var
        Created: Page "PEQI Customer Link Created";
    begin
        // The link is stored by now, and RunModal refuses to start inside a write transaction.
        Commit();
        Created.SetLink(Url, CustomerLink);
        Created.RunModal();
    end;

    trigger OnOpenPage()
    var
        BookPreviewMgt: Codeunit "PEQI Book Preview Mgt.";
    begin
        CanPreview := BookPreviewMgt.CanReadTickets();
    end;

    trigger OnAfterGetCurrRecord()
    var
        BookPreviewMgt: Codeunit "PEQI Book Preview Mgt.";
    begin
        HasApproved := BookPreviewMgt.HasApprovedTicket(Rec.ID, Rec.Job, Rec.Version);
    end;
}
