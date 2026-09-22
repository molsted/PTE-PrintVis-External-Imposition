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
        SkipMsg: Label 'The plan has %1 press runs but the job has %2 PrintVis sheets, so no sheet preview was written.', Comment = '%1 run count, %2 sheet count';

    /// <summary>Files one sheet preview against its PVS Job Sheet, by ordinal, and
    /// only when the engine's run count matches PrintVis's sheet count. When they
    /// differ there is no key for the surplus run, and creating PVS Job Sheet rows
    /// would be write-back to the calculation.</summary>
    procedure Receive(var ImpositionJob: Record "PEQI Imposition Job"; PreviewJson: Text)
    var
        Preview: JsonObject;
        RunCount: Integer;
        SheetCount: Integer;
        Ordinal: Integer;
        SheetId: Integer;
    begin
        if not Preview.ReadFrom(PreviewJson) then
            exit;
        if JsonHelper.ReadInteger(Preview, 'v') <> 1 then
            exit;

        RunCount := CountRuns(ImpositionJob);
        SheetCount := CountSheets(ImpositionJob);

        if RunCount <> SheetCount then begin
            Diagnose(ImpositionJob, RunCount, SheetCount);
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

    local procedure LinkRun(ImpositionJob: Record "PEQI Imposition Job"; Ordinal: Integer; SheetId: Integer)
    var
        PressRun: Record "PEQI Press Run";
        Index: Integer;
    begin
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

    local procedure Diagnose(var ImpositionJob: Record "PEQI Imposition Job"; RunCount: Integer; SheetCount: Integer)
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
        Diagnostic."Example Message" := CopyStr(StrSubstNo(SkipMsg, RunCount, SheetCount), 1, MaxStrLen(Diagnostic."Example Message"));
        Diagnostic.Insert(true);
    end;
}
