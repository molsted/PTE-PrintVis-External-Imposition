// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

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
                field("Default Trim Head (mm)"; Rec."Default Trim Head (mm)") { ApplicationArea = All; }
                field("Default Trim Foot (mm)"; Rec."Default Trim Foot (mm)") { ApplicationArea = All; }
                field("Default Trim Face (mm)"; Rec."Default Trim Face (mm)") { ApplicationArea = All; }
            }
            group(Ticket)
            {
                Caption = 'JDF';
                field("Jdf Version"; Rec."Jdf Version") { ApplicationArea = All; }
                field("Jdf Flavour"; Rec."Jdf Flavour") { ApplicationArea = All; }
                field("Job Id Format"; Rec."Job Id Format")
                {
                    ApplicationArea = All;
                    ToolTip = 'JDF JobID. %1 is the case ID, %2 the job, %3 the version.';
                }
            }
            group(Units)
            {
                Caption = 'PrintVis Units';
                field("Thickness Is Microns"; Rec."Thickness Is Microns")
                {
                    ApplicationArea = All;
                    ToolTip = 'Clear this if PVS Thickness is recorded in millimetres.';
                }
                field("Weight Is Gsm"; Rec."Weight Is Gsm") { ApplicationArea = All; }
            }
            group(Connection)
            {
                Caption = 'Connection';
                field("Timeout (ms)"; Rec."Timeout (ms)") { ApplicationArea = All; }
                field("Retry Count"; Rec."Retry Count") { ApplicationArea = All; }
            }
        }
    }

    var
        ApiKey: Text;
        KeyIsSet: Boolean;

    trigger OnOpenPage()
    begin
        Rec := Rec.GetSetup();
        Rec.Get('');
        KeyIsSet := Rec.HasApiKey();
    end;
}
