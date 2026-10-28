// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Tests;

using PrintersEquity.ExternalImposition.Document;
using PrintersEquity.ExternalImposition.Enums;
using PrintersEquity.ExternalImposition.Links;
using System.TestLibraries.Utilities;

codeunit 50625 "PEQI Book Preview Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure NoCommittedEntryMeansNoTicket()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        JdfTicket: Record "PEQI Jdf Ticket";
        BookPreviewMgt: Codeunit "PEQI Book Preview Mgt.";
    begin
        // [GIVEN] a Solved entry that has a ticket
        ImpositionJob := ImpositionJob.NewEntry(9101, 1, 1);
        SetStatus(ImpositionJob, ImpositionJob.Status::Solved);
        InsertTicket(ImpositionJob, '<JDF id="A"/>', CreateDateTime(DMY2Date(1, 1, 2026), 100000T));

        // [WHEN] the approved ticket is looked up
        // [THEN] there is none
        Assert.IsFalse(BookPreviewMgt.FindApprovedTicket(9101, 1, 1, JdfTicket), 'Only a Committed entry is approved');
        Assert.IsFalse(BookPreviewMgt.HasApprovedTicket(9101, 1, 1), 'HasApprovedTicket agrees');
    end;

    [Test]
    procedure TheLatestCommittedEntryWins()
    var
        First: Record "PEQI Imposition Job";
        Second: Record "PEQI Imposition Job";
        JdfTicket: Record "PEQI Jdf Ticket";
        BookPreviewMgt: Codeunit "PEQI Book Preview Mgt.";
    begin
        // [GIVEN] two Committed entries, each with a ticket
        First := First.NewEntry(9102, 1, 1);
        SetStatus(First, First.Status::Committed);
        InsertTicket(First, '<JDF id="A"/>', CreateDateTime(DMY2Date(1, 1, 2026), 100000T));
        Second := Second.NewEntry(9102, 1, 1);
        SetStatus(Second, Second.Status::Committed);
        InsertTicket(Second, '<JDF id="B"/>', CreateDateTime(DMY2Date(2, 1, 2026), 100000T));

        // [WHEN] the approved ticket is looked up
        // [THEN] it is the later entry's
        Assert.IsTrue(BookPreviewMgt.FindApprovedTicket(9102, 1, 1, JdfTicket), 'A ticket is found');
        Assert.AreEqual('<JDF id="B"/>', JdfTicket.GetJdf(), 'The latest committed entry wins');
    end;

    [Test]
    procedure ANewerDraftDoesNotHideTheCommittedOne()
    var
        First: Record "PEQI Imposition Job";
        Second: Record "PEQI Imposition Job";
        JdfTicket: Record "PEQI Jdf Ticket";
        BookPreviewMgt: Codeunit "PEQI Book Preview Mgt.";
    begin
        // [GIVEN] a Committed entry with a ticket, then a newer Draft with one too
        First := First.NewEntry(9103, 1, 1);
        SetStatus(First, First.Status::Committed);
        InsertTicket(First, '<JDF id="A"/>', CreateDateTime(DMY2Date(1, 1, 2026), 100000T));
        Second := Second.NewEntry(9103, 1, 1);
        InsertTicket(Second, '<JDF id="D"/>', CreateDateTime(DMY2Date(2, 1, 2026), 100000T));

        // [WHEN] the approved ticket is looked up
        // [THEN] the committed one is returned
        Assert.IsTrue(BookPreviewMgt.FindApprovedTicket(9103, 1, 1, JdfTicket), 'A ticket is found');
        Assert.AreEqual('<JDF id="A"/>', JdfTicket.GetJdf(), 'The draft is ignored');
    end;

    [Test]
    procedure TheNewestTicketOfTheEntryWins()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        JdfTicket: Record "PEQI Jdf Ticket";
        BookPreviewMgt: Codeunit "PEQI Book Preview Mgt.";
    begin
        // [GIVEN] a Committed entry with two tickets, the newer inserted first
        ImpositionJob := ImpositionJob.NewEntry(9104, 1, 1);
        SetStatus(ImpositionJob, ImpositionJob.Status::Committed);
        InsertTicket(ImpositionJob, '<JDF id="T2"/>', CreateDateTime(DMY2Date(2, 1, 2026), 100000T));
        InsertTicket(ImpositionJob, '<JDF id="T1"/>', CreateDateTime(DMY2Date(1, 1, 2026), 100000T));

        // [WHEN] the approved ticket is looked up
        // [THEN] it is the newer one
        Assert.IsTrue(BookPreviewMgt.FindApprovedTicket(9104, 1, 1, JdfTicket), 'A ticket is found');
        Assert.AreEqual('<JDF id="T2"/>', JdfTicket.GetJdf(), 'The newest ticket wins');
    end;

    [Test]
    procedure ACommittedEntryWithoutATicketIsNotApproved()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        JdfTicket: Record "PEQI Jdf Ticket";
        BookPreviewMgt: Codeunit "PEQI Book Preview Mgt.";
    begin
        // [GIVEN] a Committed entry with no ticket
        ImpositionJob := ImpositionJob.NewEntry(9105, 1, 1);
        SetStatus(ImpositionJob, ImpositionJob.Status::Committed);

        // [WHEN] the approved ticket is looked up
        // [THEN] there is none
        Assert.IsFalse(BookPreviewMgt.FindApprovedTicket(9105, 1, 1, JdfTicket), 'No ticket means not approved');
        Assert.IsFalse(BookPreviewMgt.HasApprovedTicket(9105, 1, 1), 'HasApprovedTicket agrees');
    end;

    [Test]
    procedure BookOptionsCarriesTheEntryKey()
    var
        BookPreviewMgt: Codeunit "PEQI Book Preview Mgt.";
        Options: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] an entry key
        // [WHEN] the book options are built
        Options.ReadFrom(BookPreviewMgt.BookOptions('9106-1-1-1', 'company:9106:1:1'));

        // [THEN] the key and the BC theme are in them, and nothing of the editor's own options
        Options.Get('entryKey', Token);
        Assert.AreEqual('9106-1-1-1', Token.AsValue().AsText(), 'The entry key is echoed');
        Options.Get('theme', Token);
        Assert.AreEqual('bc', Token.AsValue().AsText(), 'The theme is bc');
        Assert.IsFalse(Options.Contains('mode'), 'The book seed has no mode');
    end;

    [Test]
    procedure TheBookOptionsCarryTheSubject()
    var
        BookPreviewMgt: Codeunit "PEQI Book Preview Mgt.";
        LinkSubject: Codeunit "PEQI Link Subject";
        Options: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] the subject of a job
        // [WHEN] the book options are built for it
        Options.ReadFrom(BookPreviewMgt.BookOptions('9107-1-1-1', LinkSubject."For"(9107, 1, 1)));

        // [THEN] the subject is in them, so the book can show what the customer has previewed
        Assert.IsTrue(Options.Get('subject', Token), 'The options name the subject');
        Assert.AreEqual(LinkSubject."For"(9107, 1, 1), Token.AsValue().AsText(), 'The job''s subject');
    end;

    local procedure SetStatus(var ImpositionJob: Record "PEQI Imposition Job"; NewStatus: Enum "PEQI Job Status")
    begin
        ImpositionJob.Status := NewStatus;
        ImpositionJob.Modify();
    end;

    local procedure InsertTicket(ImpositionJob: Record "PEQI Imposition Job"; Jdf: Text; CreatedAt: DateTime)
    var
        JdfTicket: Record "PEQI Jdf Ticket";
    begin
        JdfTicket.Init();
        JdfTicket."Ticket Id" := CreateGuid();
        JdfTicket."Case ID" := ImpositionJob."Case ID";
        JdfTicket.Job := ImpositionJob.Job;
        JdfTicket.Version := ImpositionJob.Version;
        JdfTicket."Entry No." := ImpositionJob."Entry No.";
        JdfTicket."Created At" := CreatedAt;
        JdfTicket.SetJdf(Jdf);
        JdfTicket.Insert();
    end;
}
