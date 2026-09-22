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
}
