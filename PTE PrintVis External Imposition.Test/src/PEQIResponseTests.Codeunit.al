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
using PrintersEquity.ExternalImposition.Integration;
using System.TestLibraries.Utilities;

codeunit 50616 "PEQI Response Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Reader: Codeunit "PEQI Response Reader";

    [Test]
    procedure AMixedStockSolutionStillYieldsItsRuns()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        PressRun: Record "PEQI Press Run";
        SolutionJson: Text;
    begin
        // [GIVEN] a solution whose sheets disagree, so the convenience fields are null
        // The API nulls sheet/pressName/workStyle whenever a plan is mixed-stock;
        // runs[] is the view that is always populated.
        ImpositionJob := ImpositionJob.NewEntry(8001, 1, 1);
        SolutionJson :=
          '{"solutionId":"abc123","runnable":true,"score":0.87,' +
          '"sheet":null,"pressId":null,"pressName":null,"workStyle":null,' +
          '"metrics":{"sheetCount":4,"totalSignatures":5,"utilisation":0.91,' +
          '"wastedAreaSqMm":12345.6,"worstGrainVerdict":"Correct"},' +
          '"runs":[' +
          '{"sheet":{"name":"Munken 240"},"pressName":"KBA Rapida 75","workStyle":"WorkAndBack",' +
          '"passes":1,"signatureIds":["S1"]},' +
          '{"sheet":{"name":"Amber 100"},"pressName":"KBA Rapida 75","workStyle":"WorkAndTurn",' +
          '"passes":2,"signatureIds":["S2","S3"]}]}';

        // [WHEN] the solution is applied
        Reader.ApplySolution(ImpositionJob, SolutionJson);

        // [THEN] the summary is filled from metrics
        Assert.AreEqual('abc123', ImpositionJob."Solution Id", 'The solution id is stored');
        Assert.AreEqual(4, ImpositionJob."Sheet Count", 'Sheet count comes from metrics');
        Assert.AreEqual('Correct', ImpositionJob."Worst Grain Verdict", 'Grain verdict comes from metrics');

        // [THEN] both runs are written even though the convenience fields were null
        PressRun.SetRange("Case ID", 8001);
        PressRun.SetRange(Job, 1);
        PressRun.SetRange(Version, 1);
        PressRun.SetRange("Entry No.", ImpositionJob."Entry No.");
        Assert.AreEqual(2, PressRun.Count(), 'Every run is recorded');
    end;

    [Test]
    procedure DiagnosticsAreStoredNotSuppressed()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        Diagnostic: Record "PEQI Diagnostic";
    begin
        // [GIVEN] the diagnostics a self-contained request always raises
        ImpositionJob := ImpositionJob.NewEntry(8002, 1, 1);

        // [WHEN] they are applied
        Reader.ApplyDiagnostics(ImpositionJob,
          '[{"severity":"Info","code":"IMPOSITION_RULES_NOT_APPLIED","count":1,' +
          '"example":{"message":"This shop''s rule table was not applied."}}]', 0);

        // [THEN] the rules diagnostic is on the record where an operator can see it
        Diagnostic.SetRange("Case ID", 8002);
        Diagnostic.SetRange("Code", 'IMPOSITION_RULES_NOT_APPLIED');
        Assert.AreEqual(1, Diagnostic.Count(), 'The rules diagnostic is stored, not hidden');
    end;
}
