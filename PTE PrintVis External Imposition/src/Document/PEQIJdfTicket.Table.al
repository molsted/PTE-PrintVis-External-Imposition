// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

table 50507 "PEQI Jdf Ticket"
{
    Caption = 'Imposition JDF Ticket';
    DataClassification = CustomerContent;
    LookupPageId = "PEQI Jdf Tickets";
    DrillDownPageId = "PEQI Jdf Tickets";

    fields
    {
        field(1; "Ticket Id"; Guid) { Caption = 'Ticket Id'; }
        field(10; "Case ID"; Integer) { Caption = 'Case ID'; }
        field(11; Job; Integer) { Caption = 'Job'; }
        field(12; Version; Integer) { Caption = 'Version'; }
        field(13; "Entry No."; Integer) { Caption = 'Entry No.'; }
        field(20; "Job Id"; Text[64]) { Caption = 'JDF Job ID'; }
        field(21; "Solution Id"; Text[100]) { Caption = 'Solution Id'; }
        field(22; Flavour; Enum "PEQI Jdf Flavour") { Caption = 'Flavour'; }
        field(23; "Jdf Version"; Enum "PEQI Jdf Version") { Caption = 'JDF Version'; }
        field(24; "File Name"; Text[250]) { Caption = 'File Name'; }
        field(25; Sha256; Text[64]) { Caption = 'SHA256'; }
        field(26; "Created At"; DateTime) { Caption = 'Created At'; }
        field(30; Jdf; Blob) { Caption = 'JDF'; }
    }

    keys
    {
        key(PK; "Ticket Id") { Clustered = true; }
        key(ByJob; "Case ID", Job, Version, "Entry No.") { }
    }

    procedure SetJdf(JdfText: Text)
    var
        OutStr: OutStream;
    begin
        Clear(Jdf);
        Jdf.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(JdfText);
    end;

    procedure GetJdf(): Text
    var
        InStr: InStream;
        JdfText: Text;
    begin
        CalcFields(Jdf);
        if not Jdf.HasValue() then
            exit('');
        Jdf.CreateInStream(InStr, TextEncoding::UTF8);
        InStr.ReadText(JdfText);
        exit(JdfText);
    end;
}
