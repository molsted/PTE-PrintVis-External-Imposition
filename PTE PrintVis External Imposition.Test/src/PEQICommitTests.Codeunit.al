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

using PrintersEquity.ExternalImposition.Commit;
using PrintersEquity.ExternalImposition.Document;
using PrintersEquity.ExternalImposition.Integration;
using PrintersEquity.ExternalImposition.Links;
using PrintersEquity.ExternalImposition.Setup;
using System.TestLibraries.Utilities;

codeunit 50613 "PEQI Commit Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Queue: Codeunit "PEQI Test Transport Queue";
        TestData: Codeunit "PEQI Test Data";

    [Test]
    procedure StoringAChoiceMovesTheJobToSolved()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        CommitManager: Codeunit "PEQI Commit Manager";
    begin
        // [GIVEN] a draft job
        ImpositionJob := ImpositionJob.NewEntry(9001, 1, 1);

        // [WHEN] the editor reports a choice
        CommitManager.StoreChoice(ImpositionJob,
          '{"v":1,"solutionId":"sol-1","request":{"parts":[]},' +
          '"summary":{"solutionId":"sol-1","runnable":true,"score":1.0,' +
          '"metrics":{"sheetCount":2,"totalSignatures":2,"utilisation":0.8},' +
          '"runs":[{"sheet":{"name":"Munken 240"},"pressName":"KBA","workStyle":"WorkAndBack","signatureIds":["S1"]}]},' +
          '"diagnostics":[]}');

        // [THEN] the job is Solved and carries the chosen id
        ImpositionJob.Get(9001, 1, 1, ImpositionJob."Entry No.");
        Assert.AreEqual(ImpositionJob.Status::Solved, ImpositionJob.Status, 'A stored choice is Solved');
        Assert.AreEqual('sol-1', ImpositionJob."Solution Id", 'The chosen solution id is stored');
    end;

    [Test]
    procedure TheEffectiveRequestReplacesTheBuiltOne()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        CommitManager: Codeunit "PEQI Commit Manager";
    begin
        // [GIVEN] a job whose request was built by AL
        ImpositionJob := ImpositionJob.NewEntry(9002, 1, 1);
        ImpositionJob.SetRequestJson('{"parts":[],"maxSolutions":10}');
        ImpositionJob.Modify(true);

        // [WHEN] the operator re-tuned it in the editor
        CommitManager.StoreChoice(ImpositionJob,
          '{"v":1,"solutionId":"sol-2","request":{"parts":[],"maxSolutions":25},"summary":{},"diagnostics":[]}');

        // [THEN] the tuned request is what is stored, because it is what /jdf must be given
        ImpositionJob.Get(9002, 1, 1, ImpositionJob."Entry No.");
        Assert.IsTrue(StrPos(ImpositionJob.GetRequestJson(), '"maxSolutions":25') > 0, 'The effective request replaces the built one');
    end;

    [Test]
    procedure GeneratingAJdfStoresTheTicketAndCommitsTheJob()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        JdfTicket: Record "PEQI Jdf Ticket";
        Setup: Record "PEQI Imposition Setup";
        CommitManager: Codeunit "PEQI Commit Manager";
        TicketId: Guid;
    begin
        // [GIVEN] a solved job and an engine that writes a ticket
        Queue.Reset();
        Setup := Setup.GetSetup();
        Setup.Get('');
        Setup."Engine Base Url" := 'https://engine.example.com/api';
        Setup.Modify(true);

        TestData.AddCase(9003, 'O-9003', '');
        ImpositionJob := ImpositionJob.NewEntry(9003, 1, 1);
        ImpositionJob.SetRequestJson('{"parts":[]}');
        ImpositionJob."Solution Id" := 'sol-3';
        ImpositionJob.Status := ImpositionJob.Status::Solved;
        ImpositionJob.Modify(true);

        Queue.QueueResponse(200,
          '{"ticketId":"7c9e6679-7425-40de-944b-e07fc1f90ae7","solutionId":"sol-3",' +
          '"contentType":"application/vnd.cip4-jdf+xml","fileName":"9003-1-1-sol-3.jdf",' +
          '"jdf":"<?xml version=\"1.0\"?><JDF/>","sha256":"e3b0c442",' +
          '"solution":{"solutionId":"sol-3","metrics":{"sheetCount":2}},"diagnostics":[]}');

        CommitManager.SetTransport("PEQI Transport Type"::Test);

        // [WHEN] the ticket is generated
        TicketId := CommitManager.GenerateJdf(ImpositionJob);

        // [THEN] the ticket is stored and the job is Committed
        Assert.IsTrue(JdfTicket.Get(TicketId), 'The ticket is stored under the id the engine returned');
        Assert.AreEqual('e3b0c442', JdfTicket.Sha256, 'The checksum is stored for deduplication');
        Assert.IsTrue(StrPos(JdfTicket.GetJdf(), '<JDF/>') > 0, 'The XML is stored');
        ImpositionJob.Get(9003, 1, 1, ImpositionJob."Entry No.");
        Assert.AreEqual(ImpositionJob.Status::Committed, ImpositionJob.Status, 'The job is Committed');
    end;

    [Test]
    procedure AnEarlierTicketSurvivesAReSolve()
    var
        First: Record "PEQI Imposition Job";
        Second: Record "PEQI Imposition Job";
        JdfTicket: Record "PEQI Jdf Ticket";
    begin
        // [GIVEN] a committed entry with a ticket
        First := First.NewEntry(9004, 1, 1);
        First.Status := First.Status::Committed;
        First.Modify(true);
        JdfTicket.Init();
        JdfTicket."Ticket Id" := CreateGuid();
        JdfTicket."Case ID" := 9004;
        JdfTicket.Job := 1;
        JdfTicket.Version := 1;
        JdfTicket."Entry No." := First."Entry No.";
        JdfTicket.Insert(true);

        // [WHEN] the job is re-solved
        Second := Second.NewEntry(9004, 1, 1);

        // [THEN] the old ticket still points at the entry it was written from
        JdfTicket.SetRange("Case ID", 9004);
        JdfTicket.SetRange("Entry No.", First."Entry No.");
        Assert.AreEqual(1, JdfTicket.Count(), 'A re-solve leaves the earlier ticket intact');
        Assert.AreNotEqual(First."Entry No.", Second."Entry No.", 'The re-solve is a new entry');
    end;
    [Test]
    procedure TheJobIdIsTheOrderNumberByDefault()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        Body: Text;
    begin
        // [GIVEN] the default format, and a case that was not copied
        GivenAnEngine('');
        TestData.AddCase(9010, 'O-9010', '');
        ImpositionJob := SolvedEntry(9010);

        // [WHEN] the ticket is generated
        Body := GenerateAndReadBody(ImpositionJob);

        // [THEN] the job ID is the order number, and there is no related job
        Assert.IsTrue(StrPos(Body, '"jobId":"O-9010"') > 0, 'Blank reads as %4, the order number');
        Assert.AreEqual(0, StrPos(Body, 'relatedJobId'), 'A case that was not copied relates to no job');
    end;

    [Test]
    procedure ACopiedCaseNamesTheOrderItWasCopiedFrom()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        Body: Text;
    begin
        // [GIVEN] %4, and a case copied from another order
        GivenAnEngine('%4');
        TestData.AddCase(9011, 'O-9011', 'O-9001');
        ImpositionJob := SolvedEntry(9011);

        // [WHEN] the ticket is generated
        Body := GenerateAndReadBody(ImpositionJob);

        // [THEN] the related job ID is written the way the job ID is
        Assert.IsTrue(StrPos(Body, '"relatedJobId":"O-9001"') > 0, 'The earlier order number is the related job ID');
    end;

    [Test]
    procedure WithACaseFormatTheRelatedIdIsTheEarlierCases()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        Body: Text;
    begin
        // [GIVEN] a format built from the case, and an earlier case whose job went to order at version 2
        GivenAnEngine('%1-%2-%3');
        TestData.AddCase(9012, 'O-9012', '');
        TestData.AddJob(9012, 1, 2, '', 1000);
        TestData.AddCase(9013, 'O-9013', 'O-9012');
        ImpositionJob := SolvedEntry(9013);

        // [WHEN] the ticket is generated
        Body := GenerateAndReadBody(ImpositionJob);

        // [THEN] both IDs come from the same format, each from its own case
        Assert.IsTrue(StrPos(Body, '"jobId":"9013-1-1"') > 0, 'The job ID is this case''s');
        Assert.IsTrue(StrPos(Body, '"relatedJobId":"9012-1-2"') > 0, 'The related job ID is the earlier case''s, at its active version');
    end;

    [Test]
    procedure AnEarlierCaseThatCannotBeFoundRelatesToNothing()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        Body: Text;
    begin
        // [GIVEN] a format built from the case, and a case copied from an order no case carries
        GivenAnEngine('%1-%2-%3');
        TestData.AddCase(9014, 'O-9014', 'O-GONE');
        ImpositionJob := SolvedEntry(9014);

        // [WHEN] the ticket is generated
        Body := GenerateAndReadBody(ImpositionJob);

        // [THEN] the ticket is still written, without the optional relation
        Assert.AreEqual(0, StrPos(Body, 'relatedJobId'), 'No related job ID can be built, so none is sent');
    end;

    [Test]
    procedure ACaseWithoutAnOrderNumberIsRefusedWhenTheFormatNeedsOne()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        CommitManager: Codeunit "PEQI Commit Manager";
    begin
        // [GIVEN] %4, and a case that is still a quote
        GivenAnEngine('%4');
        TestData.AddCase(9015, '', '');
        ImpositionJob := SolvedEntry(9015);
        CommitManager.SetTransport("PEQI Transport Type"::Test);

        // [WHEN] the ticket is generated
        asserterror CommitManager.GenerateJdf(ImpositionJob);

        // [THEN] it is refused, saying why, and nothing is sent
        Assert.ExpectedError('has no order number yet');
        Assert.AreEqual(0, Queue.CallCount(), 'A ticket with no job ID is not requested');
    end;

    [Test]
    procedure AFormatMustNameOneJob()
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        // [THEN] %2 and %3 need %1, and a format needs %1 or %4 at all
        asserterror Setup.Validate("Job Id Format", '%2-%3');
        Assert.ExpectedError('without %1');
        asserterror Setup.Validate("Job Id Format", 'JOB');
        Assert.ExpectedError('the same ID');
        asserterror Setup.Validate("Job Id Format", '%4-%5');
        Assert.ExpectedError('placeholder other than');
        asserterror Setup.Validate("Job Id Format", '%4%');
        Assert.ExpectedError('placeholder other than');

        // [THEN] these are accepted
        Setup.Validate("Job Id Format", '%1-%2-%3');
        Setup.Validate("Job Id Format", 'PV-%4');
        Setup.Validate("Job Id Format", '%4-%1');
        Setup.Validate("Job Id Format", '');
    end;

    [Test]
    procedure TheCaseCustomerIsSentWithItsContactAndApprover()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        Body: Text;
    begin
        // [GIVEN] a case for a customer, with a sell-to contact and an approver
        GivenAnEngine('%4');
        TestData.AddCase(9020, 'O-9020', '');
        TestData.AddContact('CT-9020', 'Ada', 'Lovelace', 'ada@example.com', '');
        TestData.AddContact('AP-9020', 'Grace', 'Hopper', 'grace@example.com', '+4511111111');
        TestData.SetCaseCustomer(9020, 'C-1001', 'Acme', 'PO4711', 'Spring catalogue', 'CT-9020', 'AP-9020');
        ImpositionJob := SolvedEntry(9020);

        // [WHEN] the ticket is generated
        Body := GenerateAndReadBody(ImpositionJob);

        // [THEN] the customer is identified, with the case's names and references
        Assert.IsTrue(StrPos(Body, '"customerId":"C-1001"') > 0, 'The sell-to customer is the customer id');
        Assert.IsTrue(StrPos(Body, '"customerOrderId":"PO4711"') > 0, 'Your Reference is the customer''s order id');
        Assert.IsTrue(StrPos(Body, '"customerJobName":"Springcatalogue"') > 0, 'The job name is the customer''s job name');
        // [THEN] the Customer contact carries the company, the person, the address and the person's own email
        Assert.IsTrue(StrPos(Body, '"contactTypes":["Customer"],"company":"Acme"') > 0, 'The Customer contact names the company');
        Assert.IsTrue(StrPos(Body, '"firstName":"Ada","familyName":"Lovelace"') > 0, 'The sell-to contact is the person');
        Assert.IsTrue(StrPos(Body, '"countryCode":"DK"') > 0, 'The address is the sell-to address');
        Assert.IsTrue(StrPos(Body, '"locator":"ada@example.com"') > 0, 'The contact''s own email wins');
        Assert.IsTrue(StrPos(Body, '"locator":"+4500000000"') > 0, 'The case''s phone stands in for a contact with none');
        // [THEN] the approver is a contact of its own
        Assert.IsTrue(StrPos(Body, '"contactTypes":["Approver"]') > 0, 'The approver is sent as an Approver contact');
        Assert.IsTrue(StrPos(Body, '"locator":"grace@example.com"') > 0, 'The approver''s email is sent');
    end;

    [Test]
    procedure ACaseWithOnlyTheNumbersFallsBackToTheCustomerCard()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        Body: Text;
    begin
        // [GIVEN] a case with Sell-To No. and a contact number but no name or address copied onto it,
        // and a contact number with no card behind it
        GivenAnEngine('%4');
        TestData.AddCase(9022, 'O-9022', '');
        TestData.AddCustomer('C-9022', 'Verdant City', 'Aarhus', 'orders@verdant.example', '+4522222222');
        TestData.SetCaseCustomerNumbersOnly(9022, 'C-9022', 'CT-NONE', 'Anita Langers');
        ImpositionJob := SolvedEntry(9022);

        // [WHEN] the ticket is generated
        Body := GenerateAndReadBody(ImpositionJob);

        // [THEN] the company, address and channels come from the customer card
        Assert.IsTrue(StrPos(Body, '"company":"VerdantCity"') > 0, 'The card''s name stands in for a blank Sell-To Name');
        Assert.IsTrue(StrPos(Body, '"city":"Aarhus"') > 0, 'The card''s address stands in for a blank one');
        Assert.IsTrue(StrPos(Body, '"locator":"orders@verdant.example"') > 0, 'The card''s email is sent');
        Assert.IsTrue(StrPos(Body, '"locator":"+4522222222"') > 0, 'The card''s phone is sent');
        // [THEN] the person is the name the case shows, since no card can be found for it
        Assert.IsTrue(StrPos(Body, '"person":{"familyName":"AnitaLangers"}') > 0, 'The case''s contact name is the person');
    end;

    [Test]
    procedure ACaseWithoutACustomerSendsNone()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        Body: Text;
    begin
        // [GIVEN] a case with no sell-to customer
        GivenAnEngine('%4');
        TestData.AddCase(9021, 'O-9021', '');
        ImpositionJob := SolvedEntry(9021);

        // [WHEN] the ticket is generated
        Body := GenerateAndReadBody(ImpositionJob);

        // [THEN] no customer is sent
        Assert.AreEqual(0, StrPos(Body, '"customer"'), 'A case without a customer sends none');
    end;

    [Test]
    procedure TheProjectACaseBelongsToIsItsProjectId()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        Body: Text;
    begin
        // [GIVEN] a case that belongs to project case 12345
        GivenAnEngine('%4');
        TestData.AddCase(9030, 'O-9030', '');
        TestData.SetCaseProject(9030, 12345);
        ImpositionJob := SolvedEntry(9030);

        // [WHEN] the ticket is generated
        Body := GenerateAndReadBody(ImpositionJob);

        // [THEN] the project is the project id, written without a thousands separator
        Assert.IsTrue(StrPos(Body, '"projectId":"12345"') > 0, 'Belongs To Project ID is the project id');
    end;

    [Test]
    procedure ACaseInNoProjectSendsNoProjectId()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        Body: Text;
    begin
        // [GIVEN] a case that belongs to no project
        GivenAnEngine('%4');
        TestData.AddCase(9031, 'O-9031', '');
        ImpositionJob := SolvedEntry(9031);

        // [WHEN] the ticket is generated
        Body := GenerateAndReadBody(ImpositionJob);

        // [THEN] no project id is sent
        Assert.AreEqual(0, StrPos(Body, 'projectId'), 'A case in no project sends no project id');
    end;

    [Test]
    procedure TheTicketCarriesItsSubjectAndRevision()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        LinkSubject: Codeunit "PEQI Link Subject";
        Body: Text;
    begin
        // [GIVEN] a solved job that has been re-solved once, so its entry number is not 1
        GivenAnEngine('%4');
        TestData.AddCase(9040, 'O-9040', '');
        ImpositionJob := ImpositionJob.NewEntry(9040, 1, 1);
        ImpositionJob := SolvedEntry(9040);

        // [WHEN] the ticket is generated
        Body := GenerateAndReadBody(ImpositionJob);

        // [THEN] the body names the subject a customer link is made for, and the revision that
        // lets the engine tell a newer ticket from an older one
        Assert.IsTrue(StrPos(Body, '"subject":"' + LinkSubject."For"(9040, 1, 1) + '"') > 0, 'The subject is company, case, job and version');
        Assert.AreEqual(2, ImpositionJob."Entry No.", 'The re-solve is entry 2');
        Assert.IsTrue(StrPos(Body, '"subjectRevision":2') > 0, 'The revision is the entry number');
    end;

    local procedure GivenAnEngine(JobIdFormat: Text[50])
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        Queue.Reset();
        Setup := Setup.GetSetup();
        Setup.Get('');
        Setup."Engine Base Url" := 'https://engine.example.com/api';
        Setup."Job Id Format" := JobIdFormat;
        Setup.Modify(true);
    end;

    local procedure SolvedEntry(CaseId: Integer) ImpositionJob: Record "PEQI Imposition Job"
    begin
        ImpositionJob := ImpositionJob.NewEntry(CaseId, 1, 1);
        ImpositionJob.SetRequestJson('{"parts":[]}');
        ImpositionJob."Solution Id" := 'sol-x';
        ImpositionJob.Status := ImpositionJob.Status::Solved;
        ImpositionJob.Modify(true);
    end;

    /// <summary>Generates the ticket against a canned engine and returns the body that was posted.</summary>
    local procedure GenerateAndReadBody(var ImpositionJob: Record "PEQI Imposition Job"): Text
    var
        CommitManager: Codeunit "PEQI Commit Manager";
    begin
        Queue.QueueResponse(200,
          '{"ticketId":"' + DelChr(Format(CreateGuid()), '=', '{}') + '","solutionId":"sol-x",' +
          '"fileName":"x.jdf","jdf":"<JDF/>","sha256":"00","diagnostics":[]}');
        CommitManager.SetTransport("PEQI Transport Type"::Test);
        CommitManager.GenerateJdf(ImpositionJob);
        exit(DelChr(Queue.CallBody(1), '=', ' '));
    end;
}
