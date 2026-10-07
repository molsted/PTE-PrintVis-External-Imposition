// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Commit;

using PrintersEquity.ExternalImposition.Document;
using PrintersEquity.ExternalImposition.Mapping;
using System.Text;
using System.Utilities;

codeunit 50544 "PEQI Preview Writer"
{
    var
        JsonHelper: Codeunit "PEQI Json Helper";
        SkipCodeTok: Label 'PREVIEW_NOT_WRITTEN', Locked = true;
        WrongEntryCodeTok: Label 'PREVIEW_WRONG_ENTRY', Locked = true;
        WrongEntryMsg: Label 'A preview arrived for imposition entry %1, which is not this one, so it was not filed.', Comment = '%1 the entry key the editor sent';
        SkipMsg: Label 'The plan has %1 press sheets but the job has %2 PrintVis sheets, so no sheet preview was written.', Comment = '%1 plan sheet count, %2 PrintVis sheet count';

    /// <summary>Files one sheet preview against its PVS Job Sheet, by ordinal, and only when the
    /// plan has as many press sheets as the job has PrintVis sheets. When they differ there is no
    /// key for the surplus sheet, and creating PVS Job Sheet rows would be write-back to the
    /// calculation.</summary>
    /// <remarks>
    /// Counted in press sheets, not press runs. A run is several sheets coalesced by stock, feed,
    /// press and work style, so a four-signature job on one paper is one run and four things on a
    /// press -- and one picture cannot be filed against four PrintVis sheets. Comparing runs meant
    /// that job was skipped entirely with a diagnostic about a mismatch that was really a
    /// difference of units.
    /// </remarks>
    procedure Receive(var ImpositionJob: Record "PEQI Imposition Job"; PreviewJson: Text)
    var
        Preview: JsonObject;
        PlanSheetCount: Integer;
        SheetCount: Integer;
        Ordinal: Integer;
        SheetId: Integer;
    begin
        if not Preview.ReadFrom(PreviewJson) then
            exit;
        if JsonHelper.ReadInteger(Preview, 'v') <> 1 then
            exit;

        // Reported rather than thrown, unlike the chosen solution. Previews arrive as a burst
        // and an error would abandon the rest mid-stream; the picture is also the one thing
        // here that can be missing without the plan being wrong. Writing it against the wrong
        // sheet, on the other hand, is silent and permanent - hence the check.
        if JsonHelper.ReadText(Preview, 'entryKey') <> ImpositionJob.EntryKey() then begin
            DiagnoseWrongEntry(ImpositionJob, JsonHelper.ReadText(Preview, 'entryKey'));
            exit;
        end;

        // The engine's own sheet count, as stored from the chosen solution's metrics. Chosen
        // always arrives before any preview, so it is set by the time this runs.
        PlanSheetCount := ImpositionJob."Sheet Count";
        SheetCount := CountSheets(ImpositionJob);

        if PlanSheetCount <> SheetCount then begin
            Diagnose(ImpositionJob, PlanSheetCount, SheetCount);
            exit;
        end;

        Ordinal := JsonHelper.ReadInteger(Preview, 'ordinal');
        SheetId := SheetIdAtOrdinal(ImpositionJob, Ordinal);
        if SheetId = 0 then
            exit;

        WritePicture(SheetId, JsonHelper.ReadText(Preview, 'side'),
                     JsonHelper.ReadInteger(Preview, 'widthPx'),
                     JsonHelper.ReadInteger(Preview, 'heightPx'),
                     JsonHelper.ReadText(Preview, 'png'));
        LinkRun(ImpositionJob, Ordinal, SheetId);
    end;

    local procedure CountRuns(ImpositionJob: Record "PEQI Imposition Job"): Integer
    var
        PressRun: Record "PEQI Press Run";
    begin
        PressRun.SetRange("Case ID", ImpositionJob."Case ID");
        PressRun.SetRange(Job, ImpositionJob.Job);
        PressRun.SetRange(Version, ImpositionJob.Version);
        PressRun.SetRange("Entry No.", ImpositionJob."Entry No.");
        exit(PressRun.Count());
    end;

    local procedure CountSheets(ImpositionJob: Record "PEQI Imposition Job"): Integer
    var
        JobSheet: Record "PVS Job Sheet";
    begin
        JobSheet.SetRange(ID, ImpositionJob."Case ID");
        JobSheet.SetRange(Job, ImpositionJob.Job);
        JobSheet.SetRange(Version, ImpositionJob.Version);
        exit(JobSheet.Count());
    end;

    local procedure SheetIdAtOrdinal(ImpositionJob: Record "PEQI Imposition Job"; Ordinal: Integer): Integer
    var
        JobSheet: Record "PVS Job Sheet";
        Index: Integer;
    begin
        if Ordinal < 1 then
            exit(0);
        JobSheet.SetRange(ID, ImpositionJob."Case ID");
        JobSheet.SetRange(Job, ImpositionJob.Job);
        JobSheet.SetRange(Version, ImpositionJob.Version);
        JobSheet.SetCurrentKey(ID, Job, Version, "Sheet ID");
        if not JobSheet.FindSet() then
            exit(0);
        repeat
            Index += 1;
            if Index = Ordinal then
                exit(JobSheet."Sheet ID");
        until JobSheet.Next() = 0;
        exit(0);
    end;

    local procedure WritePicture(SheetId: Integer; Side: Text; WidthPx: Integer; HeightPx: Integer; PngBase64: Text)
    var
        SheetImposition: Record "PVS Job Sheet Imposition";
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        OutStr: OutStream;
        PictureOut: OutStream;
        InStr: InStream;
        FrontBack: Option Front,Back;
        SheetNo: Integer;
    begin
        SheetNo := 1;
        if LowerCase(Side) = 'back' then
            FrontBack := FrontBack::Back;

        TempBlob.CreateOutStream(OutStr);
        Base64Convert.FromBase64(PngBase64, OutStr);
        TempBlob.CreateInStream(InStr);

        if not SheetImposition.Get(SheetId, FrontBack, SheetNo) then begin
            SheetImposition.Init();
            SheetImposition."Sheet ID" := SheetId;
            SheetImposition."Front/Back" := FrontBack;
            SheetImposition."Sheet No." := SheetNo;
            SheetImposition.Insert(true);
        end;

        SheetImposition.Heigth := HeightPx;
        SheetImposition.Width := WidthPx;
        // Picture is a Blob, not a Media - it is written through its own stream.
        Clear(SheetImposition.Picture);
        SheetImposition.Picture.CreateOutStream(PictureOut);
        CopyStream(PictureOut, InStr);
        SheetImposition.Modify(true);
    end;

    /// <summary>Points a press run at the PrintVis sheet it runs on, where that is one thing.</summary>
    /// <remarks>
    /// Only when every run is a single sheet. The ordinal counts press sheets, so using it to
    /// index runs is only meaningful while the two lists are the same length; on a job whose
    /// signatures share a feeder load, one run covers several PrintVis sheets and no single id
    /// describes it. The previews are still filed -- it is the run's own sheet pointer that
    /// cannot be stated, and leaving it empty says that honestly.
    /// </remarks>
    local procedure LinkRun(ImpositionJob: Record "PEQI Imposition Job"; Ordinal: Integer; SheetId: Integer)
    var
        PressRun: Record "PEQI Press Run";
        Index: Integer;
    begin
        if CountRuns(ImpositionJob) <> ImpositionJob."Sheet Count" then
            exit;

        PressRun.SetRange("Case ID", ImpositionJob."Case ID");
        PressRun.SetRange(Job, ImpositionJob.Job);
        PressRun.SetRange(Version, ImpositionJob.Version);
        PressRun.SetRange("Entry No.", ImpositionJob."Entry No.");
        if not PressRun.FindSet() then
            exit;
        repeat
            Index += 1;
            if Index = Ordinal then begin
                PressRun."PVS Sheet ID" := SheetId;
                PressRun.Modify(true);
                exit;
            end;
        until PressRun.Next() = 0;
    end;

    local procedure DiagnoseWrongEntry(var ImpositionJob: Record "PEQI Imposition Job"; SentKey: Text)
    var
        Diagnostic: Record "PEQI Diagnostic";
    begin
        Diagnostic.SetRange("Case ID", ImpositionJob."Case ID");
        Diagnostic.SetRange(Job, ImpositionJob.Job);
        Diagnostic.SetRange(Version, ImpositionJob.Version);
        Diagnostic.SetRange("Entry No.", ImpositionJob."Entry No.");
        Diagnostic.SetRange("Code", WrongEntryCodeTok);
        if not Diagnostic.IsEmpty() then
            exit;

        Diagnostic.Init();
        Diagnostic."Case ID" := ImpositionJob."Case ID";
        Diagnostic.Job := ImpositionJob.Job;
        Diagnostic.Version := ImpositionJob.Version;
        Diagnostic."Entry No." := ImpositionJob."Entry No.";
        Diagnostic."Line No." := 990100;
        Diagnostic.Severity := Diagnostic.Severity::Warn;
        Diagnostic."Code" := WrongEntryCodeTok;
        Diagnostic."Count" := 1;
        Diagnostic.Source := Diagnostic.Source::Preview;
        Diagnostic."Example Message" := CopyStr(StrSubstNo(WrongEntryMsg, SentKey), 1, MaxStrLen(Diagnostic."Example Message"));
        Diagnostic.Insert(true);
    end;

    local procedure Diagnose(var ImpositionJob: Record "PEQI Imposition Job"; PlanSheetCount: Integer; SheetCount: Integer)
    var
        Diagnostic: Record "PEQI Diagnostic";
    begin
        Diagnostic.SetRange("Case ID", ImpositionJob."Case ID");
        Diagnostic.SetRange(Job, ImpositionJob.Job);
        Diagnostic.SetRange(Version, ImpositionJob.Version);
        Diagnostic.SetRange("Entry No.", ImpositionJob."Entry No.");
        Diagnostic.SetRange("Code", SkipCodeTok);
        if not Diagnostic.IsEmpty() then
            exit;

        Diagnostic.Init();
        Diagnostic."Case ID" := ImpositionJob."Case ID";
        Diagnostic.Job := ImpositionJob.Job;
        Diagnostic.Version := ImpositionJob.Version;
        Diagnostic."Entry No." := ImpositionJob."Entry No.";
        Diagnostic."Line No." := 990000;
        Diagnostic.Severity := Diagnostic.Severity::Info;
        Diagnostic."Code" := SkipCodeTok;
        Diagnostic."Count" := 1;
        Diagnostic.Source := Diagnostic.Source::Preview;
        Diagnostic."Example Message" := CopyStr(StrSubstNo(SkipMsg, PlanSheetCount, SheetCount), 1, MaxStrLen(Diagnostic."Example Message"));
        Diagnostic.Insert(true);
    end;
}
