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
using PrintersEquity.ExternalImposition.Setup;
using System.TestLibraries.Utilities;

codeunit 50613 "PEQI Commit Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Queue: Codeunit "PEQI Test Transport Queue";

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
}
