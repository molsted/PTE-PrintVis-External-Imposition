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
using PrintersEquity.ExternalImposition.Integration;
using PrintersEquity.ExternalImposition.Links;
using PrintersEquity.ExternalImposition.Setup;
using System.TestLibraries.Utilities;

codeunit 50626 "PEQI Link Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Queue: Codeunit "PEQI Test Transport Queue";

    [Test]
    procedure TheSubjectNamesCompanyCaseJobAndVersion()
    var
        LinkSubject: Codeunit "PEQI Link Subject";
        Subject: Text;
        Parts: List of [Text];
        Company: Text;
        Position: Integer;
    begin
        // [WHEN] the subject of case 9040, job 1, version 2 is built
        Subject := LinkSubject."For"(9040, 1, 2);

        // [THEN] it is <company id>:9040:1:2, with no thousands separator in the case ID
        Parts := Subject.Split(':');
        Assert.AreEqual(4, Parts.Count(), 'Company id, case, job and version');
        Assert.AreEqual('9040', Parts.Get(2), 'The case ID is written plainly');
        Assert.AreEqual('1', Parts.Get(3), 'The job');
        Assert.AreEqual('2', Parts.Get(4), 'The version');

        // [THEN] the company id is a lowercase GUID in its hyphenated form, without braces: the
        // engine takes a subject in a URL path segment, where braces and capitals would be mangled
        Company := Parts.Get(1);
        Assert.AreEqual(36, StrLen(Company), 'A GUID in the standard hyphenated form');
        Assert.AreEqual(Company.ToLower(), Company, 'Lowercase hex');
        Assert.AreEqual(0, StrPos(Company, '{'), 'No opening brace');
        Assert.AreEqual(0, StrPos(Company, '}'), 'No closing brace');
        for Position := 1 to StrLen(Company) do
            if Position in [9, 14, 19, 24] then
                Assert.AreEqual('-', Format(Company[Position]), 'The standard GUID hyphens stay')
            else
                Assert.IsTrue(Company[Position] in ['0' .. '9', 'a' .. 'f'], 'Hex digits only');
    end;

    [Test]
    procedure SetupDefaults()
    var
        Setup: Record "PEQI Imposition Setup";
        Expected: DateFormula;
    begin
        // [GIVEN] no setup row yet
        if Setup.Get('') then
            Setup.Delete();
        Clear(Setup);

        // [WHEN] the singleton is created
        Setup := Setup.GetSetup();
        Setup.Get('');

        // [THEN] a link shows the book and takes files, but not the imposition, for 14 days
        Assert.IsFalse(Setup."Link Show Imposition", 'The imposition is off by default');
        Assert.IsTrue(Setup."Link Show Book", 'The book is on by default');
        Assert.IsTrue(Setup."Link Allow File Submission", 'File submission is on by default');
        Evaluate(Expected, '<14D>');
        Assert.AreEqual(Format(Expected), Format(Setup."Link Validity"), 'Fourteen days');
        Assert.AreEqual(10, Setup."Link Max Sessions", 'Ten sessions');
    end;

    [Test]
    procedure MaxSessionsStaysWithinOneAndAThousand()
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        asserterror Setup.Validate("Link Max Sessions", 0);
        asserterror Setup.Validate("Link Max Sessions", 1001);
        Setup.Validate("Link Max Sessions", 1);
        Setup.Validate("Link Max Sessions", 1000);
    end;

    [Test]
    procedure CreatingALinkPostsTheSubjectAndExpectedTicket()
    var
        CustomerLink: Record "PEQI Customer Link";
        LinkMgt: Codeunit "PEQI Customer Link Mgt.";
        LinkSubject: Codeunit "PEQI Link Subject";
        Body: JsonObject;
        Features: JsonObject;
        Token: JsonToken;
        TicketId: Guid;
        Sent: Text;
    begin
        // [GIVEN] an approved job, defaults of Book and File Submission for ten sessions, and an engine that makes the link
        ArrangeEngine();
        TicketId := ApprovedTicket(9301, 1, 1);
        Queue.QueueResponse(201, CreatedResponse(CreateGuid(), 'https://engine.example.com/l/T1', TicketId));

        // [WHEN] a link is made with the defaults
        LinkMgt.SetTransport("PEQI Transport Type"::Test);
        LinkMgt.CreateLinkWithDefaults(9301, 1, 1, CustomerLink);

        // [THEN] one POST goes to /links, carrying the subject, the ticket BC approved and the features
        Assert.AreEqual(1, Queue.CallCount(), 'One call');
        Assert.AreEqual('POST', Queue.CallMethod(1), 'A create is a POST');
        Assert.IsTrue(Queue.CallUrl(1).EndsWith('/api/imposition/links'), 'The links route');
        Sent := Queue.CallBody(1);
        Body.ReadFrom(Sent);
        Assert.AreEqual(LinkSubject."For"(9301, 1, 1), Member(Body, 'subject'), 'The subject');
        Assert.AreEqual(Lower(TicketId), Member(Body, 'expectedTicketId'), 'The engine is told which ticket BC approved');
        Body.Get('features', Token);
        Features := Token.AsObject();
        Assert.IsFalse(Flag(Features, 'imposition'), 'The imposition is off by default');
        Assert.IsTrue(Flag(Features, 'book'), 'The book is on by default');
        Assert.IsTrue(Flag(Features, 'fileSubmission'), 'File submission is on by default');
        Assert.IsTrue(Features.Contains('approval'), 'Approval is always sent');
        Assert.IsFalse(Flag(Features, 'approval'), 'and is false');
        Assert.IsTrue(StrPos(Sent, '"maxSessions":10') > 0, 'The default session count');
        // [THEN] the expiry is an ISO 8601 UTC time
        Assert.IsTrue(Member(Body, 'expiresAt').EndsWith('Z'), 'UTC, so it ends in Z');
        Assert.AreEqual(11, StrPos(Member(Body, 'expiresAt'), 'T'), 'Date, then T, then the time');
    end;

    [Test]
    procedure TheUrlIsStored()
    var
        CustomerLink: Record "PEQI Customer Link";
        Stored: Record "PEQI Customer Link";
        LinkMgt: Codeunit "PEQI Customer Link Mgt.";
        LinkSubject: Codeunit "PEQI Link Subject";
        LinkId: Guid;
        Url: Text;
    begin
        // [GIVEN] an approved job and an engine that answers with a link
        ArrangeEngine();
        LinkId := CreateGuid();
        Queue.QueueResponse(201, CreatedResponse(LinkId, 'https://engine.example.com/l/SECRET-TOKEN', ApprovedTicket(9302, 2, 3)));

        // [WHEN] the link is made
        LinkMgt.SetTransport("PEQI Transport Type"::Test);
        Url := LinkMgt.CreateLinkWithDefaults(9302, 2, 3, CustomerLink);

        // [THEN] the full URL is returned and kept, by design: BC is where the planner finds it again
        Assert.AreEqual('https://engine.example.com/l/SECRET-TOKEN', Url, 'The URL is returned');
        Assert.IsTrue(Stored.Get(LinkId), 'The link is stored under the engine''s id');
        Assert.AreEqual(Url, Stored.URL, 'The full URL is stored');
        Assert.AreEqual(9302, Stored."Case ID", 'Case');
        Assert.AreEqual(2, Stored.Job, 'Job');
        Assert.AreEqual(3, Stored.Version, 'Version');
        Assert.AreEqual(LinkSubject."For"(9302, 2, 3), Stored.Subject, 'Subject');
        Assert.IsFalse(Stored."Show Imposition", 'Imposition off');
        Assert.IsTrue(Stored."Show Book", 'Book on');
        Assert.IsTrue(Stored."Allow File Submission", 'File submission on');
        Assert.AreEqual(10, Stored."Max Sessions", 'Max sessions');
        Assert.IsTrue(Stored."Expires At" > CurrentDateTime(), 'Expires in the future');
        Assert.AreEqual(CopyStr(UserId(), 1, MaxStrLen(Stored."Created By")), Stored."Created By", 'Made by the user, cut to fit');
        Assert.IsTrue(Stored."Created At" <> 0DT, 'Created At');
        Assert.IsTrue(Stored."In Sync", 'The engine said the link is in sync');
        Assert.IsFalse(Stored.Revoked, 'Not revoked');
        Assert.AreEqual(Stored."Link Id", CustomerLink."Link Id", 'The caller''s record is the stored one');
    end;

    [Test]
    procedure AMissingCurrentTicketIsBackfilled()
    var
        CustomerLink: Record "PEQI Customer Link";
        ImpositionJob: Record "PEQI Imposition Job";
        LinkMgt: Codeunit "PEQI Customer Link Mgt.";
        LinkSubject: Codeunit "PEQI Link Subject";
        TicketId: Guid;
        Subject: Text;
    begin
        // [GIVEN] an approved job the engine has no current ticket for (it was committed before subjects existed)
        ArrangeEngine();
        TicketId := ApprovedTicket(9303, 1, 1);
        Queue.QueueResponse(409, '{"title":"Conflict","detail":"Subject has no current ticket."}');
        Queue.QueueResponse(204, '');
        Queue.QueueResponse(201, CreatedResponse(CreateGuid(), 'https://engine.example.com/l/T3', TicketId));

        // [WHEN] a link is made
        LinkMgt.SetTransport("PEQI Transport Type"::Test);
        LinkMgt.CreateLinkWithDefaults(9303, 1, 1, CustomerLink);

        // [THEN] the create is refused, the approved ticket is attached, and the create is asked again
        Assert.AreEqual(3, Queue.CallCount(), 'Create, attach, create');
        Assert.IsTrue(Queue.CallUrl(1).EndsWith('/api/imposition/links'), 'First the create');
        Assert.IsTrue(Queue.CallUrl(3).EndsWith('/api/imposition/links'), 'Then the create again');
        Subject := LinkSubject."For"(9303, 1, 1);
        Assert.AreEqual('POST', Queue.CallMethod(2), 'The attach is a POST');
        Assert.IsTrue(StrPos(Queue.CallUrl(2), '/api/imposition/subjects/' + Subject.Replace(':', '%3A') + '/tickets/' + Lower(TicketId)) > 0,
          'The attach names the encoded subject and the approved ticket: ' + Queue.CallUrl(2));
        Assert.AreEqual(0, StrPos(Queue.CallUrl(2), Subject), 'The subject is never put in the path unescaped');
        // [THEN] the revision is the ticket's entry number, the same one /jdf would have sent
        ImpositionJob.SetRange("Case ID", 9303);
        ImpositionJob.FindLast();
        Assert.AreEqual('{"subjectRevision":' + Format(ImpositionJob."Entry No.", 0, 9) + '}', Queue.CallBody(2), 'The revision');
        Assert.IsFalse(IsNullGuid(CustomerLink."Link Id"), 'The link was made');
    end;

    [Test]
    procedure ASecondConflictIsAnError()
    var
        CustomerLink: Record "PEQI Customer Link";
        LinkMgt: Codeunit "PEQI Customer Link Mgt.";
    begin
        // [GIVEN] an engine that still has no current ticket after the attach
        ArrangeEngine();
        ApprovedTicket(9304, 1, 1);
        Queue.QueueResponse(409, '{"detail":"no current ticket"}');
        Queue.QueueResponse(204, '');
        Queue.QueueResponse(409, '{"detail":"no current ticket"}');

        // [WHEN] a link is made
        LinkMgt.SetTransport("PEQI Transport Type"::Test);
        asserterror LinkMgt.CreateLinkWithDefaults(9304, 1, 1, CustomerLink);

        // [THEN] it asks once more and then says so, rather than looping
        Assert.AreEqual(3, Queue.CallCount(), 'Create, attach, create, and no more');
        Assert.ExpectedError('409');
        Assert.AreEqual(0, CountLinks(9304), 'Nothing is stored');
    end;

    [Test]
    procedure NoApprovedImpositionIsAnError()
    var
        CustomerLink: Record "PEQI Customer Link";
        ImpositionJob: Record "PEQI Imposition Job";
        LinkMgt: Codeunit "PEQI Customer Link Mgt.";
    begin
        // [GIVEN] a job whose imposition is only Solved
        ArrangeEngine();
        ImpositionJob := ImpositionJob.NewEntry(9305, 1, 1);

        // [WHEN] a link is made
        LinkMgt.SetTransport("PEQI Transport Type"::Test);
        asserterror LinkMgt.CreateLinkWithDefaults(9305, 1, 1, CustomerLink);

        // [THEN] it says why, and the engine is not asked
        Assert.ExpectedError('This job has no approved imposition yet.');
        Assert.AreEqual(0, Queue.CallCount(), 'The engine is not called');
    end;

    [Test]
    procedure TheBeforeEventCanChangeTheSettings()
    var
        CustomerLink: Record "PEQI Customer Link";
        LinkMgt: Codeunit "PEQI Customer Link Mgt.";
        Subscriber: Codeunit "PEQI Link Subscriber";
    begin
        // [GIVEN] another extension that caps every link at three sessions
        ArrangeEngine();
        Queue.QueueResponse(201, CreatedResponse(CreateGuid(), 'https://engine.example.com/l/T6', ApprovedTicket(9306, 1, 1)));
        Subscriber.ForceMaxSessions(3);
        BindSubscription(Subscriber);

        // [WHEN] a link is made with the defaults, which say ten
        LinkMgt.SetTransport("PEQI Transport Type"::Test);
        LinkMgt.CreateLinkWithDefaults(9306, 1, 1, CustomerLink);
        UnbindSubscription(Subscriber);

        // [THEN] the engine is asked for three, and the link stores three
        Assert.IsTrue(StrPos(Queue.CallBody(1), '"maxSessions":3') > 0, 'The posted body carries the subscriber''s value');
        Assert.AreEqual(3, CustomerLink."Max Sessions", 'and so does the stored link');
    end;

    [Test]
    procedure TheBeforeEventCanTakeOverTheCreation()
    var
        CustomerLink: Record "PEQI Customer Link";
        LinkMgt: Codeunit "PEQI Customer Link Mgt.";
        Subscriber: Codeunit "PEQI Link Subscriber";
        Url: Text;
    begin
        // [GIVEN] another extension that makes the link itself
        ArrangeEngine();
        ApprovedTicket(9307, 1, 1);
        Subscriber.HandleCreationWith('https://other.example.com/l/X');
        BindSubscription(Subscriber);

        // [WHEN] a link is made
        LinkMgt.SetTransport("PEQI Transport Type"::Test);
        Url := LinkMgt.CreateLinkWithDefaults(9307, 1, 1, CustomerLink);
        UnbindSubscription(Subscriber);

        // [THEN] the engine is not called, nothing is stored and the after event does not fire
        Assert.AreEqual(0, Queue.CallCount(), 'The engine is not called');
        Assert.AreEqual('https://other.example.com/l/X', Url, 'The subscriber''s URL comes back');
        Assert.AreEqual(0, CountLinks(9307), 'Nothing is stored');
        Assert.IsFalse(Subscriber.AfterWasRaised(), 'There is no link to announce');
    end;

    [Test]
    procedure TheAfterEventSeesTheLink()
    var
        CustomerLink: Record "PEQI Customer Link";
        LinkMgt: Codeunit "PEQI Customer Link Mgt.";
        Subscriber: Codeunit "PEQI Link Subscriber";
        LinkId: Guid;
    begin
        // [GIVEN] a listener, and an engine that makes the link
        ArrangeEngine();
        LinkId := CreateGuid();
        Queue.QueueResponse(201, CreatedResponse(LinkId, 'https://engine.example.com/l/T8', ApprovedTicket(9308, 1, 1)));
        BindSubscription(Subscriber);

        // [WHEN] a link is made
        LinkMgt.SetTransport("PEQI Transport Type"::Test);
        LinkMgt.CreateLinkWithDefaults(9308, 1, 1, CustomerLink);
        UnbindSubscription(Subscriber);

        // [THEN] the listener saw the stored link and its URL
        Assert.IsTrue(Subscriber.AfterWasRaised(), 'The after event was raised');
        Assert.AreEqual(LinkId, Subscriber.LinkIdSeen(), 'It saw the stored link');
        Assert.AreEqual('https://engine.example.com/l/T8', Subscriber.UrlSeen(), 'and its URL');
    end;

    [Test]
    procedure RefreshStoresCountsAndSync()
    var
        First: Record "PEQI Customer Link";
        Second: Record "PEQI Customer Link";
        Other: Record "PEQI Customer Link";
        LinkMgt: Codeunit "PEQI Customer Link Mgt.";
        LinkSubject: Codeunit "PEQI Link Subject";
        TicketId: Guid;
        FirstId: Guid;
        SecondId: Guid;
    begin
        // [GIVEN] two links for a job, and a third for another job
        ArrangeEngine();
        TicketId := ApprovedTicket(9309, 1, 1);
        FirstId := CreateGuid();
        SecondId := CreateGuid();
        LinkMgt.SetTransport("PEQI Transport Type"::Test);
        Queue.QueueResponse(201, CreatedResponse(FirstId, 'https://engine.example.com/l/A', TicketId));
        LinkMgt.CreateLinkWithDefaults(9309, 1, 1, First);
        Queue.QueueResponse(201, CreatedResponse(SecondId, 'https://engine.example.com/l/B', TicketId));
        LinkMgt.CreateLinkWithDefaults(9309, 1, 1, Second);
        Other.Init();
        Other."Link Id" := CreateGuid();
        Other."Case ID" := 9399;
        Other.Job := 1;
        Other.Version := 1;
        Other.Insert();
        Queue.Reset();

        // [GIVEN] an engine that says the first link has had two sessions and half a submission, the second is revoked, and the ticket has moved on
        Queue.QueueResponse(200,
          '{"currentTicketId":"' + Lower(CreateGuid()) + '","inSync":false,"links":[' +
          '{"linkId":"' + Lower(FirstId) + '","state":"Active","sessionsUsed":2,"submission":{"pageCount":32,"assigned":20,"needsRedo":true,"previewPositions":[1,2]}},' +
          '{"linkId":"' + Lower(SecondId) + '","state":"Revoked","revokedAt":"2026-10-28T10:00:00Z","sessionsUsed":1,"submission":null}]}');

        // [WHEN] one of them is refreshed
        LinkMgt.Refresh(First);

        // [THEN] the engine was asked for the job's subject, measured against the approved ticket
        Assert.AreEqual(1, Queue.CallCount(), 'One call for all of the job''s links');
        Assert.AreEqual('GET', Queue.CallMethod(1), 'A list is a GET');
        Assert.IsTrue(StrPos(Queue.CallUrl(1), '/api/imposition/links?subject=' + LinkSubject."For"(9309, 1, 1).Replace(':', '%3A') + '&expectedTicketId=' + Lower(TicketId)) > 0,
          'The subject escaped, and the expected ticket: ' + Queue.CallUrl(1));

        // [THEN] the caller's record and the sibling both hold what the engine said
        Assert.AreEqual(2, First."Sessions Used", 'The caller''s record is current');
        Second.Get(SecondId);
        First.Get(FirstId);
        Assert.AreEqual(2, First."Sessions Used", 'Sessions used');
        Assert.AreEqual(20, First."Assigned Pages", 'Assigned pages');
        Assert.AreEqual(32, First."Total Pages", 'Total pages');
        Assert.IsTrue(First."Needs Redo", 'Needs redo');
        Assert.IsFalse(First."In Sync", 'The ticket has moved on');
        Assert.IsFalse(First.Revoked, 'Still active');
        Assert.IsTrue(First."Last Refreshed" <> 0DT, 'Stamped');
        Assert.AreEqual(1, Second."Sessions Used", 'The sibling is refreshed too');
        Assert.AreEqual(0, Second."Assigned Pages", 'No submission, nothing assigned');
        Assert.IsTrue(Second.Revoked, 'A revoked link is marked');
        Assert.IsFalse(Second."In Sync", 'The sibling is out of sync as well');

        // [THEN] another job's link is left alone
        Other.Get(Other."Link Id");
        Assert.IsTrue(Other."Last Refreshed" = 0DT, 'Another job''s link is not touched');
    end;

    [Test]
    procedure RevokeCallsTheEngine()
    var
        CustomerLink: Record "PEQI Customer Link";
        Stored: Record "PEQI Customer Link";
        LinkMgt: Codeunit "PEQI Customer Link Mgt.";
        LinkId: Guid;
    begin
        // [GIVEN] a link
        ArrangeEngine();
        LinkId := CreateGuid();
        Queue.QueueResponse(201, CreatedResponse(LinkId, 'https://engine.example.com/l/R', ApprovedTicket(9310, 1, 1)));
        LinkMgt.SetTransport("PEQI Transport Type"::Test);
        LinkMgt.CreateLinkWithDefaults(9310, 1, 1, CustomerLink);
        Queue.Reset();
        Queue.QueueResponse(204, '');

        // [WHEN] it is revoked
        LinkMgt.Revoke(CustomerLink);

        // [THEN] the engine is asked to, and the link is marked
        Assert.AreEqual(1, Queue.CallCount(), 'One call');
        Assert.AreEqual('POST', Queue.CallMethod(1), 'A revoke is a POST');
        Assert.IsTrue(Queue.CallUrl(1).EndsWith('/api/imposition/links/' + Lower(LinkId) + '/revoke'), 'The revoke route');
        Stored.Get(LinkId);
        Assert.IsTrue(Stored.Revoked, 'Revoked in BC too');
    end;

    [Test]
    procedure ARevokeTheEngineRefusesLeavesTheLinkLive()
    var
        CustomerLink: Record "PEQI Customer Link";
        Stored: Record "PEQI Customer Link";
        LinkMgt: Codeunit "PEQI Customer Link Mgt.";
        LinkId: Guid;
    begin
        // [GIVEN] a link, and an engine that cannot find it
        ArrangeEngine();
        LinkId := CreateGuid();
        Queue.QueueResponse(201, CreatedResponse(LinkId, 'https://engine.example.com/l/R2', ApprovedTicket(9311, 1, 1)));
        LinkMgt.SetTransport("PEQI Transport Type"::Test);
        LinkMgt.CreateLinkWithDefaults(9311, 1, 1, CustomerLink);
        Queue.Reset();
        Queue.QueueResponse(500, '{"detail":"down"}');
        Queue.QueueResponse(500, '{"detail":"down"}');
        Queue.QueueResponse(500, '{"detail":"down"}');
        Queue.QueueResponse(500, '{"detail":"down"}');

        // [WHEN] it is revoked
        asserterror LinkMgt.Revoke(CustomerLink);

        // [THEN] BC does not claim the link is off when the engine has not said so
        Stored.Get(LinkId);
        Assert.IsFalse(Stored.Revoked, 'Not marked revoked');
    end;

    [Test]
    procedure ResyncAttachesTheApprovedTicket()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        LinkMgt: Codeunit "PEQI Customer Link Mgt.";
        LinkSubject: Codeunit "PEQI Link Subject";
        TicketId: Guid;
    begin
        // [GIVEN] an approved job
        ArrangeEngine();
        TicketId := ApprovedTicket(9312, 1, 1);
        Queue.QueueResponse(204, '');

        // [WHEN] it is re-synced
        LinkMgt.SetTransport("PEQI Transport Type"::Test);
        LinkMgt.Resync(9312, 1, 1);

        // [THEN] the approved ticket is attached under the job's subject
        Assert.AreEqual(1, Queue.CallCount(), 'One call');
        Assert.IsTrue(Queue.CallUrl(1).EndsWith('/subjects/' + LinkSubject."For"(9312, 1, 1).Replace(':', '%3A') + '/tickets/' + Lower(TicketId)), 'The attach route');
        ImpositionJob.SetRange("Case ID", 9312);
        ImpositionJob.FindLast();
        Assert.AreEqual('{"subjectRevision":' + Format(ImpositionJob."Entry No.", 0, 9) + '}', Queue.CallBody(1), 'The entry number is the revision');
    end;

    [Test]
    procedure ResyncWithoutAnApprovedImpositionIsAnError()
    var
        LinkMgt: Codeunit "PEQI Customer Link Mgt.";
    begin
        ArrangeEngine();
        LinkMgt.SetTransport("PEQI Transport Type"::Test);
        asserterror LinkMgt.Resync(9313, 1, 1);
        Assert.ExpectedError('This job has no approved imposition yet.');
        Assert.AreEqual(0, Queue.CallCount(), 'The engine is not called');
    end;

    [Test]
    procedure ClearingASubmissionDeletesItAtTheEngine()
    var
        LinkMgt: Codeunit "PEQI Customer Link Mgt.";
        LinkSubject: Codeunit "PEQI Link Subject";
    begin
        // [GIVEN] an engine that clears
        ArrangeEngine();
        Queue.QueueResponse(204, '');

        // [WHEN] the planner clears a job's submission
        LinkMgt.SetTransport("PEQI Transport Type"::Test);
        LinkMgt.ClearSubmission(9314, 1, 1);

        // [THEN] it is a DELETE on the job's subject
        Assert.AreEqual(1, Queue.CallCount(), 'One call');
        Assert.AreEqual('DELETE', Queue.CallMethod(1), 'A DELETE');
        Assert.IsTrue(Queue.CallUrl(1).EndsWith('/subjects/' + LinkSubject."For"(9314, 1, 1).Replace(':', '%3A') + '/submission'), 'The submission route');
    end;

    [Test]
    procedure TheDefaultsComeFromSetup()
    var
        Setup: Record "PEQI Imposition Setup";
        Settings: Record "PEQI Customer Link Settings" temporary;
        LinkMgt: Codeunit "PEQI Customer Link Mgt.";
        Validity: DateFormula;
    begin
        // [GIVEN] a setup that shows the imposition only, for 30 days, to two sessions
        Setup := Setup.GetSetup();
        Setup.Get('');
        Setup."Link Show Imposition" := true;
        Setup."Link Show Book" := false;
        Setup."Link Allow File Submission" := false;
        Evaluate(Validity, '<30D>');
        Setup."Link Validity" := Validity;
        Setup."Link Max Sessions" := 2;
        Setup.Modify();

        // [WHEN] the defaults are asked for
        LinkMgt.DefaultSettings(Settings);

        // [THEN] they are those, and the link expires 30 days from now
        Assert.IsTrue(Settings."Show Imposition", 'Imposition');
        Assert.IsFalse(Settings."Show Book", 'Book');
        Assert.IsFalse(Settings."Allow File Submission", 'File submission');
        Assert.AreEqual(2, Settings."Max Sessions", 'Sessions');
        Assert.AreEqual(CalcDate('<30D>', Today()), DT2Date(Settings."Expires At"), 'Thirty days out');
    end;

    local procedure ArrangeEngine()
    var
        Setup: Record "PEQI Imposition Setup";
        Validity: DateFormula;
    begin
        Queue.Reset();
        Setup := Setup.GetSetup();
        Setup.Get('');
        Setup."Engine Base Url" := 'https://engine.example.com/api';
        Setup."Retry Count" := 0;
        Setup."Link Show Imposition" := false;
        Setup."Link Show Book" := true;
        Setup."Link Allow File Submission" := true;
        Evaluate(Validity, '<14D>');
        Setup."Link Validity" := Validity;
        Setup."Link Max Sessions" := 10;
        Setup.Modify();
    end;

    /// <summary>A Committed entry with a ticket: what the book preview, and so a link, treats as approved.</summary>
    local procedure ApprovedTicket(CaseId: Integer; JobNo: Integer; VersionNo: Integer): Guid
    var
        ImpositionJob: Record "PEQI Imposition Job";
        JdfTicket: Record "PEQI Jdf Ticket";
    begin
        ImpositionJob := ImpositionJob.NewEntry(CaseId, JobNo, VersionNo);
        ImpositionJob.Status := ImpositionJob.Status::Committed;
        ImpositionJob.Modify();
        JdfTicket.Init();
        JdfTicket."Ticket Id" := CreateGuid();
        JdfTicket."Case ID" := CaseId;
        JdfTicket.Job := JobNo;
        JdfTicket.Version := VersionNo;
        JdfTicket."Entry No." := ImpositionJob."Entry No.";
        JdfTicket."Created At" := CurrentDateTime();
        JdfTicket.SetJdf('<JDF/>');
        JdfTicket.Insert();
        exit(JdfTicket."Ticket Id");
    end;

    local procedure CreatedResponse(LinkId: Guid; Url: Text; TicketId: Guid): Text
    begin
        exit('{"linkId":"' + Lower(LinkId) + '","url":"' + Url + '","token":"TOKEN","currentTicketId":"' + Lower(TicketId) + '","inSync":true}');
    end;

    local procedure CountLinks(CaseId: Integer): Integer
    var
        CustomerLink: Record "PEQI Customer Link";
    begin
        CustomerLink.SetRange("Case ID", CaseId);
        exit(CustomerLink.Count());
    end;

    local procedure Lower(Id: Guid): Text
    begin
        exit(DelChr(Format(Id), '=', '{}').ToLower());
    end;

    local procedure Member(Obj: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        Obj.Get(Name, Token);
        exit(Token.AsValue().AsText());
    end;

    local procedure Flag(Obj: JsonObject; Name: Text): Boolean
    var
        Token: JsonToken;
    begin
        Obj.Get(Name, Token);
        exit(Token.AsValue().AsBoolean());
    end;
}
