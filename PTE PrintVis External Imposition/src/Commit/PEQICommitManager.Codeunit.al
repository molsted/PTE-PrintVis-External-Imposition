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
using PrintersEquity.ExternalImposition.Integration;
using PrintersEquity.ExternalImposition.Mapping;
using PrintersEquity.ExternalImposition.Setup;

codeunit 50543 "PEQI Commit Manager"
{
    var
        Client: Codeunit "PEQI Engine Client";
        Reader: Codeunit "PEQI Response Reader";
        JsonHelper: Codeunit "PEQI Json Helper";
        TransportType: Enum "PEQI Transport Type";
        NotSolvedErr: Label 'This imposition has no chosen solution yet.';
        NoRequestErr: Label 'This imposition has no stored request.';
        BadResultErr: Label 'The imposition editor sent a result this version does not understand.';

    procedure SetTransport(NewTransportType: Enum "PEQI Transport Type")
    begin
        TransportType := NewTransportType;
        Client.SetTransport(NewTransportType);
    end;

    /// <summary>Records what the operator chose in the editor. The effective request
    /// replaces the one AL built: the operator may have re-tuned it, and /jdf must be
    /// given the body the solution was actually solved from.</summary>
    procedure StoreChoice(var ImpositionJob: Record "PEQI Imposition Job"; ResultJson: Text)
    var
        Result: JsonObject;
        RequestObject: JsonObject;
        Summary: JsonObject;
        Diagnostics: JsonArray;
        RequestText: Text;
        SummaryText: Text;
        DiagnosticsText: Text;
    begin
        if not Result.ReadFrom(ResultJson) then
            Error(BadResultErr);
        if JsonHelper.ReadInteger(Result, 'v') <> 1 then
            Error(BadResultErr);

        if JsonHelper.ReadObject(Result, 'request', RequestObject) then begin
            RequestObject.WriteTo(RequestText);
            ImpositionJob.SetRequestJson(RequestText);
        end;

        ImpositionJob."Solution Id" := CopyStr(JsonHelper.ReadText(Result, 'solutionId'), 1, MaxStrLen(ImpositionJob."Solution Id"));
        ImpositionJob."Last Error" := '';
        ImpositionJob.Status := ImpositionJob.Status::Solved;
        ImpositionJob.Modify(true);

        if JsonHelper.ReadObject(Result, 'summary', Summary) then begin
            Summary.WriteTo(SummaryText);
            Reader.ApplySolution(ImpositionJob, SummaryText);
        end;

        if JsonHelper.ReadArray(Result, 'diagnostics', Diagnostics) then begin
            Diagnostics.WriteTo(DiagnosticsText);
            Reader.ApplyDiagnostics(ImpositionJob, DiagnosticsText, 0);
        end;
    end;

    /// <summary>Posts /jdf with the stored request and the chosen solution, and stores
    /// the ticket. Both catalogue halves are stated inline, so nothing can have moved
    /// between /calculate and here and the quoted solutionId cannot be stale.</summary>
    procedure GenerateJdf(var ImpositionJob: Record "PEQI Imposition Job") TicketId: Guid
    var
        JdfTicket: Record "PEQI Jdf Ticket";
        Setup: Record "PEQI Imposition Setup";
        RequestObject: JsonObject;
        Envelope: JsonObject;
        SolutionObject: JsonObject;
        Diagnostics: JsonArray;
        RequestText: Text;
        ResponseText: Text;
        SolutionText: Text;
        DiagnosticsText: Text;
    begin
        if ImpositionJob."Solution Id" = '' then
            Error(NotSolvedErr);

        RequestText := ImpositionJob.GetRequestJson();
        if RequestText = '' then
            Error(NoRequestErr);
        if not RequestObject.ReadFrom(RequestText) then
            Error(NoRequestErr);

        Setup := Setup.GetSetup();
        Setup.Get('');

        JsonHelper.AddText(RequestObject, 'jobId', JobId(ImpositionJob, Setup));
        JsonHelper.AddText(RequestObject, 'solutionId', ImpositionJob."Solution Id");
        JsonHelper.AddText(RequestObject, 'version', Format(Setup."Jdf Version", 0, 9));
        JsonHelper.AddText(RequestObject, 'flavour', Format(Setup."Jdf Flavour", 0, 9));
        RequestObject.WriteTo(RequestText);

        Client.SetTransport(TransportType);
        ResponseText := Client.WriteJdf(RequestText);
        if not Envelope.ReadFrom(ResponseText) then
            Error(BadResultErr);

        Evaluate(TicketId, JsonHelper.ReadText(Envelope, 'ticketId'));

        JdfTicket.Init();
        JdfTicket."Ticket Id" := TicketId;
        JdfTicket."Case ID" := ImpositionJob."Case ID";
        JdfTicket.Job := ImpositionJob.Job;
        JdfTicket.Version := ImpositionJob.Version;
        JdfTicket."Entry No." := ImpositionJob."Entry No.";
        JdfTicket."Job Id" := CopyStr(JobId(ImpositionJob, Setup), 1, MaxStrLen(JdfTicket."Job Id"));
        JdfTicket."Solution Id" := CopyStr(JsonHelper.ReadText(Envelope, 'solutionId'), 1, MaxStrLen(JdfTicket."Solution Id"));
        JdfTicket.Flavour := Setup."Jdf Flavour";
        JdfTicket."Jdf Version" := Setup."Jdf Version";
        JdfTicket."File Name" := CopyStr(JsonHelper.ReadText(Envelope, 'fileName'), 1, MaxStrLen(JdfTicket."File Name"));
        JdfTicket.Sha256 := CopyStr(JsonHelper.ReadText(Envelope, 'sha256'), 1, MaxStrLen(JdfTicket.Sha256));
        JdfTicket."Created At" := CurrentDateTime();
        JdfTicket.SetJdf(JsonHelper.ReadText(Envelope, 'jdf'));
        JdfTicket.Insert(true);

        // The envelope carries the full solution - the one place BC gets it from
        // the source of truth rather than over the add-in bridge.
        if JsonHelper.ReadObject(Envelope, 'solution', SolutionObject) then begin
            SolutionObject.WriteTo(SolutionText);
            Reader.ApplySolution(ImpositionJob, SolutionText);
        end;
        if JsonHelper.ReadArray(Envelope, 'diagnostics', Diagnostics) then begin
            Diagnostics.WriteTo(DiagnosticsText);
            Reader.ApplyDiagnostics(ImpositionJob, DiagnosticsText, 0);
        end;

        ImpositionJob."Snapshot Id" := CopyStr(SnapshotId(Envelope), 1, MaxStrLen(ImpositionJob."Snapshot Id"));
        ImpositionJob.Status := ImpositionJob.Status::Committed;
        ImpositionJob.Modify(true);
    end;

    local procedure SnapshotId(Envelope: JsonObject): Text
    var
        Snapshot: JsonObject;
    begin
        if not JsonHelper.ReadObject(Envelope, 'snapshot', Snapshot) then
            exit('');
        exit(JsonHelper.ReadText(Snapshot, 'snapshotId'));
    end;

    local procedure JobId(ImpositionJob: Record "PEQI Imposition Job"; Setup: Record "PEQI Imposition Setup"): Text
    begin
        if Setup."Job Id Format" = '' then
            exit(StrSubstNo('%1-%2-%3', ImpositionJob."Case ID", ImpositionJob.Job, ImpositionJob.Version));
        exit(StrSubstNo(Setup."Job Id Format", ImpositionJob."Case ID", ImpositionJob.Job, ImpositionJob.Version));
    end;
}
