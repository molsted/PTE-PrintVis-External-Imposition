// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

table 50505 "PEQI Imposition Job"
{
    Caption = 'Imposition Job';
    DataClassification = CustomerContent;
    LookupPageId = "PEQI Imposition Jobs";
    DrillDownPageId = "PEQI Imposition Jobs";

    fields
    {
        field(1; "Case ID"; Integer) { Caption = 'Case ID'; TableRelation = "PVS Case".ID; }
        field(2; Job; Integer) { Caption = 'Job'; }
        field(3; Version; Integer) { Caption = 'Version'; }
        field(4; "Entry No."; Integer) { Caption = 'Entry No.'; }
        field(10; Status; Enum "PEQI Job Status") { Caption = 'Status'; }
        field(11; "Built At"; DateTime) { Caption = 'Built At'; }
        field(12; "Built By"; Code[50]) { Caption = 'Built By'; TableRelation = User."User Name"; }
        field(13; "Last Error"; Text[250]) { Caption = 'Last Error'; }
        field(20; "Request Json"; Blob) { Caption = 'Request JSON'; }
        field(21; "Snapshot Id"; Text[100]) { Caption = 'Snapshot Id'; }
        field(22; "Solution Id"; Text[100]) { Caption = 'Solution Id'; }
        field(30; "Sheet Count"; Integer) { Caption = 'Sheet Count'; }
        field(31; "Total Signatures"; Integer) { Caption = 'Total Signatures'; }
        field(32; Utilisation; Decimal)
        {
            Caption = 'Utilisation';
            DecimalPlaces = 0 : 4;
            ToolTip = 'Fraction of the press sheet carrying product, 0 to 1.';
        }
        field(33; "Wasted Area (sqmm)"; Decimal) { Caption = 'Wasted Area (mm2)'; DecimalPlaces = 0 : 2; }
        field(34; "Worst Grain Verdict"; Text[30]) { Caption = 'Worst Grain Verdict'; }
        field(35; Score; Decimal) { Caption = 'Score'; DecimalPlaces = 0 : 6; }
        field(36; Runnable; Boolean) { Caption = 'Runnable'; }
    }

    keys
    {
        key(PK; "Case ID", Job, Version, "Entry No.") { Clustered = true; }
        key(ByStatus; Status) { }
    }

    /// <summary>Opens the next entry for a job version. Re-solving never overwrites
    /// an earlier entry: a committed ticket must keep pointing at the request it
    /// was written from.</summary>
    procedure NewEntry(CaseId: Integer; JobNo: Integer; VersionNo: Integer): Record "PEQI Imposition Job"
    var
        ImpositionJob: Record "PEQI Imposition Job";
        Existing: Record "PEQI Imposition Job";
        NextEntry: Integer;
    begin
        NextEntry := 1;
        Existing.SetRange("Case ID", CaseId);
        Existing.SetRange(Job, JobNo);
        Existing.SetRange(Version, VersionNo);
        // Lock before reading so the read-modify-write is serialised; without it,
        // concurrent re-solves can both read the same last entry and compute the same NextEntry.
        Existing.LockTable();
        if Existing.FindLast() then
            NextEntry := Existing."Entry No." + 1;

        ImpositionJob.Init();
        ImpositionJob."Case ID" := CaseId;
        ImpositionJob.Job := JobNo;
        ImpositionJob.Version := VersionNo;
        ImpositionJob."Entry No." := NextEntry;
        ImpositionJob.Status := ImpositionJob.Status::Draft;
        ImpositionJob."Built At" := CurrentDateTime();
        ImpositionJob."Built By" := CopyStr(UserId(), 1, MaxStrLen(ImpositionJob."Built By"));
        ImpositionJob.Insert(true);
        exit(ImpositionJob);
    end;

    procedure SetRequestJson(RequestText: Text)
    var
        OutStr: OutStream;
    begin
        Clear("Request Json");
        "Request Json".CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(RequestText);
    end;

    procedure GetRequestJson(): Text
    var
        InStr: InStream;
        RequestText: Text;
    begin
        CalcFields("Request Json");
        if not "Request Json".HasValue() then
            exit('');
        "Request Json".CreateInStream(InStr, TextEncoding::UTF8);
        InStr.ReadText(RequestText);
        exit(RequestText);
    end;
}
