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

page 50519 "PEQI Diagnostics Part"
{
    Caption = 'Diagnostics';
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = "PEQI Diagnostic";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Rows)
            {
                field(Severity; Rec.Severity)
                {
                    ApplicationArea = All;
                    StyleExpr = SeverityStyle;
                }
                field("Code"; Rec."Code") { ApplicationArea = All; }
                field("Count"; Rec."Count") { ApplicationArea = All; }
                field("Example Message"; Rec."Example Message") { ApplicationArea = All; }
                field(Source; Rec.Source) { ApplicationArea = All; }
            }
        }
    }

    var
        SeverityStyle: Text;

    trigger OnAfterGetRecord()
    begin
        case Rec.Severity of
            Rec.Severity::Error:
                SeverityStyle := 'Unfavorable';
            Rec.Severity::Warn:
                SeverityStyle := 'Ambiguous';
            else
                SeverityStyle := 'Standard';
        end;
    end;
}
