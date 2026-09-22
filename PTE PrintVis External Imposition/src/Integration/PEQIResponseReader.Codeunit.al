// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Integration;

using PrintersEquity.ExternalImposition.Document;
using PrintersEquity.ExternalImposition.Enums;
using PrintersEquity.ExternalImposition.Mapping;

codeunit 50542 "PEQI Response Reader"
{
    var
        JsonHelper: Codeunit "PEQI Json Helper";

    /// <summary>Fills the job's summary from a solution and rewrites its run lines.
    /// Reads runs[] rather than the convenience fields: those are null whenever a
    /// solution's sheets disagree, which a mixed-stock plan by definition does.</summary>
    procedure ApplySolution(var ImpositionJob: Record "PEQI Imposition Job"; SolutionJson: Text)
    var
        Solution: JsonObject;
        Metrics: JsonObject;
        Runs: JsonArray;
    begin
        if not Solution.ReadFrom(SolutionJson) then
            exit;

        ImpositionJob."Solution Id" := CopyStr(JsonHelper.ReadText(Solution, 'solutionId'), 1, MaxStrLen(ImpositionJob."Solution Id"));
        ImpositionJob.Runnable := JsonHelper.ReadBoolean(Solution, 'runnable');
        ImpositionJob.Score := JsonHelper.ReadDecimal(Solution, 'score');

        if JsonHelper.ReadObject(Solution, 'metrics', Metrics) then begin
            ImpositionJob."Sheet Count" := JsonHelper.ReadInteger(Metrics, 'sheetCount');
            ImpositionJob."Total Signatures" := JsonHelper.ReadInteger(Metrics, 'totalSignatures');
            ImpositionJob.Utilisation := JsonHelper.ReadDecimal(Metrics, 'utilisation');
            ImpositionJob."Wasted Area (sqmm)" := JsonHelper.ReadDecimal(Metrics, 'wastedAreaSqMm');
            ImpositionJob."Worst Grain Verdict" := CopyStr(JsonHelper.ReadText(Metrics, 'worstGrainVerdict'), 1, MaxStrLen(ImpositionJob."Worst Grain Verdict"));
        end;

        ImpositionJob.Status := ImpositionJob.Status::Solved;
        ImpositionJob.Modify(true);

        if JsonHelper.ReadArray(Solution, 'runs', Runs) then
            WriteRuns(ImpositionJob, Runs);
    end;

    local procedure WriteRuns(ImpositionJob: Record "PEQI Imposition Job"; Runs: JsonArray)
    var
        PressRun: Record "PEQI Press Run";
        RunToken: JsonToken;
        Run: JsonObject;
        SheetObject: JsonObject;
        LineNo: Integer;
    begin
        PressRun.SetRange("Case ID", ImpositionJob."Case ID");
        PressRun.SetRange(Job, ImpositionJob.Job);
        PressRun.SetRange(Version, ImpositionJob.Version);
        PressRun.SetRange("Entry No.", ImpositionJob."Entry No.");
        PressRun.DeleteAll(true);

        foreach RunToken in Runs do begin
            Run := RunToken.AsObject();
            LineNo += 10000;

            PressRun.Init();
            PressRun."Case ID" := ImpositionJob."Case ID";
            PressRun.Job := ImpositionJob.Job;
            PressRun.Version := ImpositionJob.Version;
            PressRun."Entry No." := ImpositionJob."Entry No.";
            PressRun."Line No." := LineNo;
            PressRun."Press Name" := CopyStr(JsonHelper.ReadText(Run, 'pressName'), 1, MaxStrLen(PressRun."Press Name"));
            PressRun."Work Style" := CopyStr(JsonHelper.ReadText(Run, 'workStyle'), 1, MaxStrLen(PressRun."Work Style"));
            PressRun.Passes := JsonHelper.ReadInteger(Run, 'passes');
            PressRun."Signature Ids" := CopyStr(JoinArray(Run, 'signatureIds'), 1, MaxStrLen(PressRun."Signature Ids"));
            PressRun."Sheet Count" := SignatureCount(Run);

            if JsonHelper.ReadObject(Run, 'sheet', SheetObject) then begin
                PressRun."Stock Name" := CopyStr(JsonHelper.ReadText(SheetObject, 'name'), 1, MaxStrLen(PressRun."Stock Name"));
                PressRun."Substrate Id" := JsonHelper.ReadInteger(SheetObject, 'id');
            end;

            PressRun.Insert(true);
        end;
    end;

    local procedure SignatureCount(Run: JsonObject): Integer
    var
        Ids: JsonArray;
    begin
        if not JsonHelper.ReadArray(Run, 'signatureIds', Ids) then
            exit(0);
        exit(Ids.Count());
    end;

    local procedure JoinArray(Parent: JsonObject; Name: Text): Text
    var
        Items: JsonArray;
        ItemToken: JsonToken;
        Joined: TextBuilder;
    begin
        if not JsonHelper.ReadArray(Parent, Name, Items) then
            exit('');
        foreach ItemToken in Items do begin
            if Joined.Length() > 0 then
                Joined.Append(', ');
            Joined.Append(ItemToken.AsValue().AsText());
        end;
        exit(Joined.ToText());
    end;

    procedure ApplyDiagnostics(var ImpositionJob: Record "PEQI Imposition Job"; DiagnosticsJson: Text; DiagnosticSource: Option Engine,Builder,Preview)
    var
        Diagnostic: Record "PEQI Diagnostic";
        Diagnostics: JsonArray;
        DiagnosticToken: JsonToken;
        Entry: JsonObject;
        Example: JsonObject;
    begin
        if DiagnosticsJson = '' then
            exit;
        if not Diagnostics.ReadFrom(DiagnosticsJson) then
            exit;

        Diagnostic.SetRange("Case ID", ImpositionJob."Case ID");
        Diagnostic.SetRange(Job, ImpositionJob.Job);
        Diagnostic.SetRange(Version, ImpositionJob.Version);
        Diagnostic.SetRange("Entry No.", ImpositionJob."Entry No.");
        Diagnostic.SetRange(Source, DiagnosticSource);
        Diagnostic.DeleteAll(true);
        Diagnostic.Reset();

        foreach DiagnosticToken in Diagnostics do begin
            Entry := DiagnosticToken.AsObject();

            Diagnostic.Init();
            Diagnostic."Case ID" := ImpositionJob."Case ID";
            Diagnostic.Job := ImpositionJob.Job;
            Diagnostic.Version := ImpositionJob.Version;
            Diagnostic."Entry No." := ImpositionJob."Entry No.";
            Diagnostic."Line No." := NextDiagnosticLine(ImpositionJob);
            Diagnostic.Severity := SeverityOf(JsonHelper.ReadText(Entry, 'severity'));
            Diagnostic."Code" := CopyStr(JsonHelper.ReadText(Entry, 'code'), 1, MaxStrLen(Diagnostic."Code"));
            Diagnostic."Count" := JsonHelper.ReadInteger(Entry, 'count');
            Diagnostic.Source := DiagnosticSource;
            if JsonHelper.ReadObject(Entry, 'example', Example) then
                Diagnostic."Example Message" := CopyStr(JsonHelper.ReadText(Example, 'message'), 1, MaxStrLen(Diagnostic."Example Message"))
            else
                Diagnostic."Example Message" := CopyStr(JsonHelper.ReadText(Entry, 'message'), 1, MaxStrLen(Diagnostic."Example Message"));
            Diagnostic.Insert(true);
        end;
    end;

    local procedure NextDiagnosticLine(ImpositionJob: Record "PEQI Imposition Job"): Integer
    var
        Diagnostic: Record "PEQI Diagnostic";
    begin
        Diagnostic.SetRange("Case ID", ImpositionJob."Case ID");
        Diagnostic.SetRange(Job, ImpositionJob.Job);
        Diagnostic.SetRange(Version, ImpositionJob.Version);
        Diagnostic.SetRange("Entry No.", ImpositionJob."Entry No.");
        if Diagnostic.FindLast() then
            exit(Diagnostic."Line No." + 10000);
        exit(10000);
    end;

    local procedure SeverityOf(Value: Text): Enum "PEQI Diagnostic Severity"
    begin
        case LowerCase(Value) of
            'error':
                exit("PEQI Diagnostic Severity"::Error);
            'warn', 'warning':
                exit("PEQI Diagnostic Severity"::Warn);
        end;
        exit("PEQI Diagnostic Severity"::Info);
    end;

    /// <summary>Finds one solution in a CalculateResponse by its id.</summary>
    procedure FindSolutionById(CalculateResponseJson: Text; SolutionId: Text; var Solution: JsonObject): Boolean
    var
        Response: JsonObject;
        Solutions: JsonArray;
        SolutionToken: JsonToken;
    begin
        if not Response.ReadFrom(CalculateResponseJson) then
            exit(false);
        if not JsonHelper.ReadArray(Response, 'solutions', Solutions) then
            exit(false);
        foreach SolutionToken in Solutions do
            if JsonHelper.ReadText(SolutionToken.AsObject(), 'solutionId') = SolutionId then begin
                Solution := SolutionToken.AsObject();
                exit(true);
            end;
        exit(false);
    end;
}
