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

/// <summary>Lets the planner change what a customer link is made with. It works on a temporary
/// copy handed in by the caller and checks it before OK closes the page, so a setting the
/// engine would refuse is caught here with a message the planner can act on.</summary>
page 50528 "PEQI Customer Link Settings"
{
    Caption = 'Customer Link Settings';
    PageType = StandardDialog;
    SourceTable = "PEQI Customer Link Settings";
    SourceTableTemporary = true;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            group(Features)
            {
                Caption = 'What the customer can use';
                field("Show Imposition"; Rec."Show Imposition")
                {
                    ApplicationArea = All;
                    ToolTip = 'Lets the customer see and choose among the imposition proposals.';
                }
                field("Show Book"; Rec."Show Book")
                {
                    ApplicationArea = All;
                    ToolTip = 'Shows the approved imposition to the customer as a flip-book.';
                }
                field("Allow File Submission"; Rec."Allow File Submission")
                {
                    ApplicationArea = All;
                    ToolTip = 'Lets the customer upload their pages and assign them to the positions of the imposition.';
                }
            }
            group(Validity)
            {
                Caption = 'How long and how often';
                field(Label; Rec.Label)
                {
                    ApplicationArea = All;
                    ToolTip = 'A name for the link, so you can tell links for the same job apart.';
                }
                field("Expires At"; Rec."Expires At")
                {
                    ApplicationArea = All;
                    ToolTip = 'After this the link stops working. It can be at most 366 days from now.';
                }
                field("Max Sessions"; Rec."Max Sessions")
                {
                    ApplicationArea = All;
                    ToolTip = 'How many browsers can open the link, from 1 to 1000. A customer who comes back in the same browser is not counted again.';
                }
            }
        }
    }

    var
        Seed: Record "PEQI Customer Link Settings" temporary;

    trigger OnOpenPage()
    begin
        Rec := Seed;
        Rec.Insert();
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if CloseAction = Action::OK then
            Rec.Check();
    end;

    /// <summary>The settings the dialog opens with.</summary>
    procedure SetSettings(var Settings: Record "PEQI Customer Link Settings" temporary)
    begin
        Seed := Settings;
    end;

    /// <summary>The settings as the planner left them. Only meaningful after OK.</summary>
    procedure GetSettings(var Settings: Record "PEQI Customer Link Settings" temporary)
    begin
        Settings := Rec;
    end;
}
