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
using PrintersEquity.ExternalImposition.Links;
using PrintersEquity.ExternalImposition.Mapping;
using PrintersEquity.ExternalImposition.Setup;

codeunit 50543 "PEQI Commit Manager"
{
    var
        Client: Codeunit "PEQI Engine Client";
        Reader: Codeunit "PEQI Response Reader";
        JsonHelper: Codeunit "PEQI Json Helper";
        EnumNames: Codeunit "PEQI Enum Names";
        CustomerMapper: Codeunit "PEQI Customer Mapper";
        LinkSubject: Codeunit "PEQI Link Subject";
        TransportType: Enum "PEQI Transport Type";
        NotSolvedErr: Label 'This imposition has no chosen solution yet.';
        NoRequestErr: Label 'This imposition has no stored request.';
        BadResultErr: Label 'The imposition editor sent a result this version does not understand.';
        NoOrderNoErr: Label 'Case %1 has no order number yet, and the Job ID Format in Imposition Setup is built from it. Make the case an order, or change the Job ID Format.', Comment = '%1 the case ID';
        WrongEntryErr: Label 'This result belongs to a different imposition entry (%1), so it was not stored. Re-open the editor on this entry and approve again.', Comment = '%1 the entry key the editor sent';

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

        // Before anything is written. An absent key counts as a mismatch: the editor echoes
        // whatever the seed carried, so a result with none did not come from the seed this
        // record sent - and storing it would overwrite a good plan with a stranger's.
        if JsonHelper.ReadText(Result, 'entryKey') <> ImpositionJob.EntryKey() then
            Error(WrongEntryErr, JsonHelper.ReadText(Result, 'entryKey'));

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
        PVSCase: Record "PVS Case";
        Customer: JsonObject;
        Envelope: JsonObject;
        SolutionObject: JsonObject;
        Diagnostics: JsonArray;
        RequestText: Text;
        ResponseText: Text;
        SolutionText: Text;
        DiagnosticsText: Text;
        JobIdText: Text;
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

        if not PVSCase.Get(ImpositionJob."Case ID") then
            Clear(PVSCase);
        JobIdText := JobId(ImpositionJob, Setup, PVSCase);
        JsonHelper.AddText(RequestObject, 'jobId', JobIdText);
        JsonHelper.AddText(RequestObject, 'relatedJobId', RelatedJobId(ImpositionJob, Setup, PVSCase));
        // What a customer link is made for, and which solve this ticket came from: the entry number
        // only grows, so the engine can tell a newer ticket from an older one for the same subject.
        JsonHelper.AddText(RequestObject, 'subject', LinkSubject."For"(ImpositionJob."Case ID", ImpositionJob.Job, ImpositionJob.Version));
        JsonHelper.AddInteger(RequestObject, 'subjectRevision', ImpositionJob."Entry No.");
        // The project case this case belongs to. Zero is "none", and sends nothing.
        if PVSCase."Belongs To Project ID" <> 0 then
            JsonHelper.AddText(RequestObject, 'projectId', Format(PVSCase."Belongs To Project ID", 0, 9));
        // Replaced rather than added to: the stored request is the editor's, and a key it already
        // carries would make JsonObject.Add fail.
        if CustomerMapper.Build(PVSCase, Customer) then begin
            if RequestObject.Contains('customer') then
                RequestObject.Remove('customer');
            RequestObject.Add('customer', Customer);
        end;
        JsonHelper.AddText(RequestObject, 'solutionId', ImpositionJob."Solution Id");
        // A name, not an ordinal: Format(x, 0, 9) once put enum positions on the wire. No flavour is
        // sent -- the engine writes the stripping ticket by default, and the Preps template is not
        // offered from Business Central.
        JsonHelper.AddText(RequestObject, 'version', EnumNames.JdfVersion(Setup."Jdf Version"));
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
        JdfTicket."Job Id" := CopyStr(JobIdText, 1, MaxStrLen(JdfTicket."Job Id"));
        JdfTicket."Solution Id" := CopyStr(JsonHelper.ReadText(Envelope, 'solutionId'), 1, MaxStrLen(JdfTicket."Solution Id"));
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

    local procedure JobId(ImpositionJob: Record "PEQI Imposition Job"; Setup: Record "PEQI Imposition Setup"; PVSCase: Record "PVS Case"): Text
    var
        JobIdFormat: Text;
    begin
        JobIdFormat := Setup.EffectiveJobIdFormat();
        if Setup.UsesPlaceholder(JobIdFormat, 4) and (PVSCase."Order No." = '') then
            Error(NoOrderNoErr, ImpositionJob."Case ID");
        exit(Setup.FormatJobId(JobIdFormat, ImpositionJob."Case ID", ImpositionJob.Job, ImpositionJob.Version, PVSCase."Order No."));
    end;

    /// <summary>The job ID the case this one was copied from has, written with the same format, so
    /// a receiver can find it among the tickets it holds. Blank when the case was not copied, or
    /// when the format needs the earlier case and it cannot be found: the field is optional, and a
    /// missing relation is not worth refusing the ticket for.</summary>
    local procedure RelatedJobId(ImpositionJob: Record "PEQI Imposition Job"; Setup: Record "PEQI Imposition Setup"; PVSCase: Record "PVS Case"): Text
    var
        RelatedCase: Record "PVS Case";
        RelatedJob: Record "PVS Job";
        JobIdFormat: Text;
        RelatedVersion: Integer;
    begin
        if PVSCase."Copy From Order No." = '' then
            exit('');
        JobIdFormat := Setup.EffectiveJobIdFormat();
        if not Setup.UsesPlaceholder(JobIdFormat, 1) then
            exit(Setup.FormatJobId(JobIdFormat, 0, 0, 0, PVSCase."Copy From Order No."));

        RelatedCase.SetRange("Order No.", PVSCase."Copy From Order No.");
        if not RelatedCase.FindFirst() then
            exit('');

        // The same job in the earlier case, at the version that case went to order with.
        if Setup.UsesPlaceholder(JobIdFormat, 3) then begin
            RelatedJob.SetRange(ID, RelatedCase.ID);
            RelatedJob.SetRange(Job, ImpositionJob.Job);
            RelatedJob.SetRange(Active, true);
            if not RelatedJob.FindFirst() then
                exit('');
            RelatedVersion := RelatedJob.Version;
        end;
        exit(Setup.FormatJobId(JobIdFormat, RelatedCase.ID, ImpositionJob.Job, RelatedVersion, PVSCase."Copy From Order No."));
    end;
}
