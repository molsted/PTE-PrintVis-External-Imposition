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

using PrintersEquity.ExternalImposition.Enums;
using PrintersEquity.ExternalImposition.Mapping;

codeunit 50552 "PEQI Book Preview Mgt."
{
    /// <summary>
    /// Finds the JDF ticket the book preview should show for a job version.
    /// </summary>
    /// <remarks>
    /// Only a Committed entry is approved, so a newer Draft or Solved entry never hides what was
    /// actually sent to PrintVis. Within the latest Committed entry the newest ticket wins, since
    /// an entry can be regenerated. False when there is no Committed entry or it has no ticket.
    /// </remarks>
    procedure FindApprovedTicket(CaseId: Integer; JobNo: Integer; VersionNo: Integer; var JdfTicket: Record "PEQI Jdf Ticket"): Boolean
    var
        ImpositionJob: Record "PEQI Imposition Job";
        Newest: Record "PEQI Jdf Ticket";
    begin
        ImpositionJob.SetRange("Case ID", CaseId);
        ImpositionJob.SetRange(Job, JobNo);
        ImpositionJob.SetRange(Version, VersionNo);
        ImpositionJob.SetRange(Status, ImpositionJob.Status::Committed);
        if not ImpositionJob.FindLast() then
            exit(false);

        JdfTicket.Reset();
        JdfTicket.SetCurrentKey("Case ID", Job, Version, "Entry No.");
        JdfTicket.SetRange("Case ID", CaseId);
        JdfTicket.SetRange(Job, JobNo);
        JdfTicket.SetRange(Version, VersionNo);
        JdfTicket.SetRange("Entry No.", ImpositionJob."Entry No.");
        // The key does not carry "Created At", so the newest is picked by scanning; an entry has few.
        if not JdfTicket.FindSet() then
            exit(false);
        Newest := JdfTicket;
        while JdfTicket.Next() <> 0 do
            if JdfTicket."Created At" > Newest."Created At" then
                Newest := JdfTicket;
        JdfTicket := Newest;
        exit(true);
    end;

    procedure HasApprovedTicket(CaseId: Integer; JobNo: Integer; VersionNo: Integer): Boolean
    var
        JdfTicket: Record "PEQI Jdf Ticket";
    begin
        // Shown on every Job Card: a user without the imposition permissions simply has no book.
        if not CanReadTickets() then
            exit(false);
        exit(FindApprovedTicket(CaseId, JobNo, VersionNo, JdfTicket));
    end;

    /// <summary>
    /// Whether the current user may read the imposition jobs and JDF tickets a book preview is built from.
    /// </summary>
    procedure CanReadTickets(): Boolean
    var
        ImpositionJob: Record "PEQI Imposition Job";
        JdfTicket: Record "PEQI Jdf Ticket";
    begin
        exit(ImpositionJob.ReadPermission() and JdfTicket.ReadPermission());
    end;

    /// <summary>
    /// The options the book preview is seeded with: the entry key (echoed back so the result can
    /// be matched to its entry), the planner's display units, and the BC theme.
    /// </summary>
    /// <remarks>
    /// Mirrors "PEQI Request Builder".SeedOptions for entryKey and units but, unlike it, carries
    /// none of the editor's own options -- a book preview is read-only.
    /// </remarks>
    procedure BookOptions(EntryKey: Text): Text
    var
        Units: Codeunit "PEQI Unit Converter";
        Options: JsonObject;
        OptionsText: Text;
        DisplayUnits: Text;
    begin
        Options.Add('entryKey', EntryKey);
        DisplayUnits := Units.FormatDisplayUnits();
        if DisplayUnits <> '' then
            Options.Add('units', DisplayUnits);
        Options.Add('theme', 'bc');
        Options.WriteTo(OptionsText);
        exit(OptionsText);
    end;
}
