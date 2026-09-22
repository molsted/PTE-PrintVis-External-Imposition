// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

page 50516 "PEQI Imposition Jobs"
{
    Caption = 'Imposition Jobs';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "PEQI Imposition Job";
    CardPageId = "PEQI Imposition Job Card";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Rows)
            {
                field("Case ID"; Rec."Case ID") { ApplicationArea = All; }
                field(Job; Rec.Job) { ApplicationArea = All; }
                field(Version; Rec.Version) { ApplicationArea = All; }
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field("Sheet Count"; Rec."Sheet Count") { ApplicationArea = All; }
                field(Utilisation; Rec.Utilisation) { ApplicationArea = All; }
                field("Built At"; Rec."Built At") { ApplicationArea = All; }
            }
        }
    }
}
