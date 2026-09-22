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

using System.Utilities;

page 50520 "PEQI Jdf Tickets"
{
    Caption = 'Imposition JDF Tickets';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "PEQI Jdf Ticket";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Rows)
            {
                field("Job Id"; Rec."Job Id") { ApplicationArea = All; }
                field("Case ID"; Rec."Case ID") { ApplicationArea = All; }
                field(Job; Rec.Job) { ApplicationArea = All; }
                field(Version; Rec.Version) { ApplicationArea = All; }
                field("File Name"; Rec."File Name") { ApplicationArea = All; }
                field(Flavour; Rec.Flavour) { ApplicationArea = All; }
                field("Jdf Version"; Rec."Jdf Version") { ApplicationArea = All; }
                field(Sha256; Rec.Sha256) { ApplicationArea = All; }
                field("Created At"; Rec."Created At") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Download)
            {
                ApplicationArea = All;
                Caption = 'Download';
                Image = Download;
                ToolTip = 'Downloads the stored JDF ticket.';

                trigger OnAction()
                var
                    TempBlob: Codeunit "Temp Blob";
                    OutStr: OutStream;
                    InStr: InStream;
                    FileName: Text;
                begin
                    TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
                    OutStr.WriteText(Rec.GetJdf());
                    TempBlob.CreateInStream(InStr, TextEncoding::UTF8);
                    FileName := Rec."File Name";
                    DownloadFromStream(InStr, '', '', '', FileName);
                end;
            }
        }
    }
}
