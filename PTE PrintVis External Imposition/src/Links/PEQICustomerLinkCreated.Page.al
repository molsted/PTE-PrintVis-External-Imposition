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

/// <summary>Shows a link's URL so the planner can send it on. AL cannot reach the clipboard, so
/// the URL is in a read-only field whose text can be selected and copied. It has no source
/// table: when another extension makes the link itself there may be no stored row to show.</summary>
page 50511 "PEQI Customer Link Created"
{
    Caption = 'Customer Link';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            group(OutOfSync)
            {
                ShowCaption = false;
                Visible = IsOutOfSync;
                field(OutOfSyncWarning; OutOfSyncWarning)
                {
                    ApplicationArea = All;
                    Caption = 'Warning';
                    Editable = false;
                    MultiLine = true;
                    Style = Unfavorable;
                    StyleExpr = true;
                    ToolTip = 'The engine is not showing the approved imposition.';
                }
            }
            group(Link)
            {
                ShowCaption = false;
                field(LinkUrl; LinkUrl)
                {
                    ApplicationArea = All;
                    Caption = 'Link';
                    Editable = false;
                    MultiLine = true;
                    ToolTip = 'Select the link and copy it, then send it to the customer.';
                }
            }
            group(Details)
            {
                ShowCaption = false;
                Visible = HasDetails;
                field(ExpiresAt; ExpiresAt)
                {
                    ApplicationArea = All;
                    Caption = 'Expires At';
                    Editable = false;
                }
                field(MaxSessions; MaxSessions)
                {
                    ApplicationArea = All;
                    Caption = 'Max Sessions';
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            // Not named Close: a TestPage has a Close method of its own.
            action(CloseDialog)
            {
                ApplicationArea = All;
                Caption = 'Close';
                Image = Close;
                ToolTip = 'Closes this page.';

                trigger OnAction()
                begin
                    CurrPage.Close();
                end;
            }
        }
    }

    var
        LinkUrl: Text;
        ExpiresAt: DateTime;
        MaxSessions: Integer;
        HasDetails: Boolean;
        IsOutOfSync: Boolean;
        OutOfSyncWarning: Text;
        OutOfSyncTxt: Label 'The engine is not showing the approved imposition, so this link will show an imposition that is not the approved one. Re-sync the job, then create a new link.';

    /// <summary>The URL to show, and the stored link it belongs to when there is one.</summary>
    procedure SetLink(Url: Text; CustomerLink: Record "PEQI Customer Link")
    begin
        LinkUrl := Url;
        HasDetails := not IsNullGuid(CustomerLink."Link Id");
        IsOutOfSync := false;
        OutOfSyncWarning := '';
        if HasDetails then begin
            ExpiresAt := CustomerLink."Expires At";
            MaxSessions := CustomerLink."Max Sessions";
            // Only once the engine has been asked: a row never refreshed knows nothing about it.
            IsOutOfSync := (CustomerLink."Last Refreshed" <> 0DT) and not CustomerLink."In Sync";
            if IsOutOfSync then
                OutOfSyncWarning := OutOfSyncTxt;
        end;
    end;
}
