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

using PrintersEquity.ExternalImposition.Integration;
using PrintersEquity.ExternalImposition.Setup;
using System.TestLibraries.Utilities;

codeunit 50612 "PEQI Client Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Queue: Codeunit "PEQI Test Transport Queue";

    local procedure NewClient(var Client: Codeunit "PEQI Engine Client")
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        Queue.Reset();
        Setup := Setup.GetSetup();
        Setup.Get('');
        Setup."Engine Base Url" := 'https://engine.example.com/api';
        Setup."Retry Count" := 2;
        Setup.Modify(true);
        Client.SetTransport("PEQI Transport Type"::Test);
    end;

    [Test]
    procedure ASuccessfulCalculateReturnsItsBody()
    var
        Client: Codeunit "PEQI Engine Client";
        Body: Text;
    begin
        // [GIVEN] the engine answers 200
        NewClient(Client);
        Queue.QueueResponse(200, '{"solutionCount":3}');

        // [WHEN] calculate is called
        Body := Client.Calculate('{"parts":[]}');

        // [THEN] the body comes back and one call was made
        Assert.AreEqual('{"solutionCount":3}', Body, 'The response body is returned');
        Assert.AreEqual(1, Queue.CallCount(), 'One call is made for a 200');
        Assert.IsTrue(StrPos(Queue.CallUrl(1), '/imposition/calculate') > 0, 'Calculate posts to the calculate route');
    end;

    [Test]
    procedure A400IsNotRetriedAndCarriesItsDetail()
    var
        Client: Codeunit "PEQI Engine Client";
    begin
        // [GIVEN] the engine answers 400 with ProblemDetails
        NewClient(Client);
        Queue.QueueResponse(400, '{"title":"Validation Error","detail":"Part ''Cover'' has 3 pages but Cover is folded and needs an even count.","status":400}');

        // [WHEN] calculate is called
        // [THEN] it errors, does not retry, and the detail reaches the operator
        asserterror Client.Calculate('{"parts":[]}');
        Assert.ExpectedError('even count');
        Assert.AreEqual(1, Queue.CallCount(), 'A 400 is never retried - the body is wrong, not the moment');
    end;

    [Test]
    procedure A500IsRetriedUpToTheConfiguredCount()
    var
        Client: Codeunit "PEQI Engine Client";
        Body: Text;
    begin
        // [GIVEN] two failures then a success
        NewClient(Client);
        Queue.QueueResponse(500, '');
        Queue.QueueResponse(500, '');
        Queue.QueueResponse(200, '{"solutionCount":1}');

        // [WHEN] calculate is called
        Body := Client.Calculate('{"parts":[]}');

        // [THEN] it succeeded on the third attempt
        Assert.AreEqual('{"solutionCount":1}', Body, 'The eventual success is returned');
        Assert.AreEqual(3, Queue.CallCount(), 'Two retries follow the initial attempt');
    end;

    [Test]
    procedure A409SaysWhyNothingFits()
    var
        Client: Codeunit "PEQI Engine Client";
    begin
        // [GIVEN] the engine cannot impose the product
        NewClient(Client);
        Queue.QueueResponse(409, '{"title":"No solution","detail":"No imposition fits","status":409,"diagnostics":[{"severity":"Error","code":"PRESS_SHEET_BOUNDS_MISSING","message":"Press KBA has no maximum sheet size"}]}');

        // [WHEN] calculate is called
        // [THEN] the diagnostic, not just the title, reaches the operator
        asserterror Client.Calculate('{"parts":[]}');
        Assert.ExpectedError('PRESS_SHEET_BOUNDS_MISSING');
    end;

    [Test]
    procedure TestConnectionMakesOneShortGet()
    var
        Setup: Record "PEQI Imposition Setup";
        Client: Codeunit "PEQI Engine Client";
        Detail: Text;
    begin
        // [GIVEN] the engine answers, and the setup allows a two-minute timeout
        NewClient(Client);
        Setup.Get('');
        Setup."Timeout (ms)" := 120000;
        Setup.Modify(true);
        Queue.QueueResponse(200, '[]');

        // [WHEN] the connection is tested
        // [THEN] it succeeds with one short GET of the part types
        Assert.IsTrue(Client.TestConnection(Detail), 'A 200 is a working connection');
        Assert.AreEqual('', Detail, 'A working connection has no reason to give');
        Assert.AreEqual(1, Queue.CallCount(), 'One call is made');
        Assert.AreEqual('GET', Queue.CallMethod(1), 'The test is a GET');
        Assert.IsTrue(StrPos(Queue.CallUrl(1), '/imposition/part-types') > 0, 'The test reads the part types');
        Assert.IsTrue(Queue.CallTimeout(1) <= 10000, 'The test waits at most ten seconds, whatever the setup says');
    end;

    [Test]
    procedure TestConnectionDoesNotRetryAndSaysWhy()
    var
        Client: Codeunit "PEQI Engine Client";
        Detail: Text;
    begin
        // [GIVEN] a failing engine, and two retries configured
        NewClient(Client);
        Queue.QueueResponse(500, '');
        Queue.QueueResponse(200, '[]');

        // [WHEN] the connection is tested
        // [THEN] it fails after one attempt, without an error, naming the status
        Assert.IsFalse(Client.TestConnection(Detail), 'A 500 is not a working connection');
        Assert.AreEqual(1, Queue.CallCount(), 'A connection test is never retried');
        Assert.IsTrue(StrPos(Detail, '500') > 0, 'The reason names the status code');
    end;

    [Test]
    procedure TestConnectionReportsAnUnreachableEngine()
    var
        Client: Codeunit "PEQI Engine Client";
        Detail: Text;
    begin
        // [GIVEN] nothing answers at all
        NewClient(Client);
        Queue.QueueTransportFailure();

        // [THEN] the test fails and says the engine could not be reached
        Assert.IsFalse(Client.TestConnection(Detail), 'No answer is not a working connection');
        Assert.IsTrue(StrPos(Detail, 'could not be reached') > 0, 'The reason says the engine was not reached');
    end;

    [Test]
    procedure TestConnectionWithoutAUrlSaysSo()
    var
        Setup: Record "PEQI Imposition Setup";
        Client: Codeunit "PEQI Engine Client";
        Detail: Text;
    begin
        // [GIVEN] no engine URL
        NewClient(Client);
        Setup.Get('');
        Setup."Engine Base Url" := '';
        Setup.Modify(true);

        // [THEN] the test fails without calling anything, saying the URL is missing
        Assert.IsFalse(Client.TestConnection(Detail), 'No URL is not a working connection');
        Assert.AreEqual(0, Queue.CallCount(), 'Nothing is called without a URL');
        Assert.IsTrue(StrPos(Detail, 'base URL is not set') > 0, 'The reason says the URL is missing');
    end;

    [Test]
    procedure TestConnectionNamesTheUrlOnA404()
    var
        Client: Codeunit "PEQI Engine Client";
        Detail: Text;
    begin
        // [GIVEN] an engine URL at which the route does not exist
        NewClient(Client);
        Queue.QueueResponse(404, '');

        // [THEN] the test fails pointing at the URL, not at a stale solution
        Assert.IsFalse(Client.TestConnection(Detail), 'A 404 is not a working connection');
        Assert.IsTrue(StrPos(Detail, 'base URL') > 0, 'The reason points at the engine base URL');
        Assert.IsTrue(StrPos(Detail, '/imposition/part-types') > 0, 'The reason names the URL called');
        Assert.IsFalse(StrPos(Detail, 'no longer known') > 0, 'A connection test never says a solution is stale');
    end;

    [Test]
    procedure RetriesResumeAfterAConnectionTest()
    var
        Client: Codeunit "PEQI Engine Client";
        Detail: Text;
    begin
        // [GIVEN] a failed connection test on the same client
        NewClient(Client);
        Queue.QueueResponse(500, '');
        Client.TestConnection(Detail);

        // [WHEN] a solve follows on the same client, failing twice then succeeding
        Queue.QueueResponse(500, '');
        Queue.QueueResponse(500, '');
        Queue.QueueResponse(200, '{"solutionCount":1}');
        Client.Calculate('{"parts":[]}');

        // [THEN] the solve retried as configured -- the test's single attempt did not stick
        Assert.AreEqual(4, Queue.CallCount(), 'One test call, then three solve attempts');
    end;
}
