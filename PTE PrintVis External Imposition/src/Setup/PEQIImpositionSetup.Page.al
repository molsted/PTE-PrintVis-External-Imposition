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

page 50510 "PEQI Imposition Setup"
{
    Caption = 'Imposition Setup';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "PEQI Imposition Setup";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field(Enabled; Rec.Enabled) { ApplicationArea = All; }
                field("Engine Base Url"; Rec."Engine Base Url")
                {
                    ApplicationArea = All;
                    ToolTip = 'The Impositioning API base URL, for example https://impose.example.com/api';
                }
                field("Spa Url"; Rec."Spa Url")
                {
                    ApplicationArea = All;
                    ToolTip = 'The Impositioning editor URL. It is opened in a frame inside Business Central.';
                }
                field(ApiKey; ApiKey)
                {
                    ApplicationArea = All;
                    Caption = 'API Key';
                    ExtendedDatatype = Masked;
                    ToolTip = 'Stored encrypted. It is never displayed again after saving.';

                    trigger OnValidate()
                    begin
                        Rec.SetApiKey(ApiKey);
                        ApiKey := '';
                        KeyIsSet := Rec.HasApiKey();
                    end;
                }
                field(KeyIsSet; KeyIsSet)
                {
                    ApplicationArea = All;
                    Caption = 'API Key Is Set';
                    Editable = false;
                }
            }
            group(Solving)
            {
                Caption = 'Solving';
                field("Grain Policy"; Rec."Grain Policy") { ApplicationArea = All; }
                field("Max Solutions"; Rec."Max Solutions") { ApplicationArea = All; }
                field("Default Trim Head"; Rec."Default Trim Head") { ApplicationArea = All; CaptionClass = Units.MarginCaptionClass('Default Trim Head'); ToolTip = 'Head trim for a part whose job item states none.'; }
                field("Default Trim Foot"; Rec."Default Trim Foot") { ApplicationArea = All; CaptionClass = Units.MarginCaptionClass('Default Trim Foot'); ToolTip = 'Foot trim for a part whose job item states none.'; }
                field("Default Trim Face"; Rec."Default Trim Face") { ApplicationArea = All; CaptionClass = Units.MarginCaptionClass('Default Trim Face'); ToolTip = 'Face trim for a part whose job item states none.'; }
            }
            group(Ticket)
            {
                Caption = 'JDF';
                field("Jdf Version"; Rec."Jdf Version") { ApplicationArea = All; }
                field("Job Id Format"; Rec."Job Id Format")
                {
                    ApplicationArea = All;
                    ToolTip = 'JDF JobID, and RelatedJobID for a case copied from another order. %1 is the case ID, %2 the job, %3 the version, %4 the order number. %2 and %3 need %1. Blank is %4.';
                }
            }
            group(CustomerLinks)
            {
                Caption = 'Customer Links';
                field("Link Show Imposition"; Rec."Link Show Imposition") { ApplicationArea = All; ToolTip = 'Whether a new customer link shows the customer the imposition. The planner can change it per link.'; }
                field("Link Show Book"; Rec."Link Show Book") { ApplicationArea = All; ToolTip = 'Whether a new customer link shows the customer the book. The planner can change it per link.'; }
                field("Link Allow File Submission"; Rec."Link Allow File Submission") { ApplicationArea = All; ToolTip = 'Whether a new customer link lets the customer send in files. The planner can change it per link.'; }
                field("Link Validity"; Rec."Link Validity") { ApplicationArea = All; ToolTip = 'How long a new customer link works, for example 14D. The engine accepts at most 366 days.'; }
                field("Link Max Sessions"; Rec."Link Max Sessions") { ApplicationArea = All; ToolTip = 'How many browsers can open a new customer link, from 1 to 1000.'; }
            }

            group(Connection)
            {
                Caption = 'Connection';
                field("Timeout (ms)"; Rec."Timeout (ms)") { ApplicationArea = All; }
                field("Retry Count"; Rec."Retry Count") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(PEQISetupGuide)
            {
                ApplicationArea = All;
                Caption = 'Setup Guide';
                Image = Setup;
                RunObject = page "PEQI Setup Guide";
                ToolTip = 'Checks the PrintVis setup imposition reads -- component types, finishing types, presses and units -- and fixes what needs attention in place. Also on the Assisted Setup page.';
            }
        }
    }

    var
        Units: Codeunit "PEQI Unit Converter";
        ApiKey: Text;
        KeyIsSet: Boolean;

    trigger OnOpenPage()
    begin
        Rec := Rec.GetSetup();
        Rec.Get('');
        KeyIsSet := Rec.HasApiKey();
    end;
}
