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
using System.TestLibraries.Utilities;

codeunit 50614 "PEQI Preview Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        PreviewWriter: Codeunit "PEQI Preview Writer";

    local procedure AddPvsSheet(CaseId: Integer; JobNo: Integer; VersionNo: Integer; SheetId: Integer)
    var
        JobSheet: Record "PVS Job Sheet";
    begin
        JobSheet.Init();
        JobSheet.ID := CaseId;
        JobSheet.Job := JobNo;
        JobSheet.Version := VersionNo;
        JobSheet."Sheet ID" := SheetId;
        JobSheet.Insert(true);
    end;

    local procedure AddRun(var ImpositionJob: Record "PEQI Imposition Job"; LineNo: Integer)
    var
        PressRun: Record "PEQI Press Run";
    begin
        PressRun.Init();
        PressRun."Case ID" := ImpositionJob."Case ID";
        PressRun.Job := ImpositionJob.Job;
        PressRun.Version := ImpositionJob.Version;
        PressRun."Entry No." := ImpositionJob."Entry No.";
        PressRun."Line No." := LineNo;
        PressRun.Insert(true);
    end;

    [Test]
    procedure APreviewIsWrittenWhenTheCountsAgree()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        SheetImposition: Record "PVS Job Sheet Imposition";
    begin
        // [GIVEN] one engine run and one PrintVis sheet
        ImpositionJob := ImpositionJob.NewEntry(9101, 1, 1);
        AddRun(ImpositionJob, 10000);
        AddPvsSheet(9101, 1, 1, 501);

        // [WHEN] a preview for the first run arrives
        PreviewWriter.Receive(ImpositionJob,
          '{"v":1,"ordinal":1,"side":"Front","widthPx":800,"heightPx":600,"png":"iVBORw0KGgo="}');

        // [THEN] it is filed against that sheet
        Assert.IsTrue(SheetImposition.Get(501, SheetImposition."Front/Back"::Front, 1),
                      'The preview is written against the PrintVis sheet');
    end;

    [Test]
    procedure NoPreviewIsWrittenWhenTheCountsDisagree()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        SheetImposition: Record "PVS Job Sheet Imposition";
        Diagnostic: Record "PEQI Diagnostic";
    begin
        // [GIVEN] two engine runs but only one PrintVis sheet
        // Creating a PVS Job Sheet would be write-back to the calculation, which
        // the design excludes; a picture of a two-sheet plan filed against one
        // sheet is worse than no picture.
        ImpositionJob := ImpositionJob.NewEntry(9102, 1, 1);
        AddRun(ImpositionJob, 10000);
        AddRun(ImpositionJob, 20000);
        AddPvsSheet(9102, 1, 1, 502);

        // [WHEN] a preview arrives
        PreviewWriter.Receive(ImpositionJob,
          '{"v":1,"ordinal":1,"side":"Front","widthPx":800,"heightPx":600,"png":"iVBORw0KGgo="}');

        // [THEN] nothing is written and the reason is recorded
        SheetImposition.SetRange("Sheet ID", 502);
        Assert.AreEqual(0, SheetImposition.Count(), 'No preview is written when the counts disagree');

        Diagnostic.SetRange("Case ID", 9102);
        Diagnostic.SetRange("Code", 'PREVIEW_NOT_WRITTEN');
        Assert.AreEqual(1, Diagnostic.Count(), 'The skip is diagnosed, not silent');
    end;
}
