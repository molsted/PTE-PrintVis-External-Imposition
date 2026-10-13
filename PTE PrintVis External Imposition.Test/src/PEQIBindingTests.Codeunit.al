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

using PrintersEquity.ExternalImposition.Enums;
using PrintersEquity.ExternalImposition.Mapping;
using System.TestLibraries.Utilities;

codeunit 50620 "PEQI Binding Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestData: Codeunit "PEQI Test Data";
        RequestBuilder: Codeunit "PEQI Request Builder";
        EnumNames: Codeunit "PEQI Enum Names";
        JsonHelper: Codeunit "PEQI Json Helper";
        Validator: Codeunit "PEQI Request Validator";

    [Test]
    procedure Cip4BindingsTranslateToTheEngines()
    begin
        Assert.AreEqual('SaddleStitch', EnumNames.BindingFromCip4('SaddleStitch', 'F'), 'Saddle stitch is saddle stitch');
        Assert.AreEqual('PerfectBound', EnumNames.BindingFromCip4('Adhesive', 'F'), 'Adhesive binding is perfect bound');
        Assert.AreEqual('PerfectBound', EnumNames.BindingFromCip4('SoftCover', 'F'), 'Soft cover is perfect bound');
        Assert.AreEqual('None', EnumNames.BindingFromCip4('Folding', 'F'), 'Folding does not bind');
        Assert.AreEqual('None', EnumNames.BindingFromCip4('Trimming', 'F'), 'Trimming does not bind');
    end;

    [Test]
    procedure MiscIsRefusedBecauseItMeansNobodySetIt()
    begin
        asserterror EnumNames.BindingFromCip4('Misc.', 'FIN-MISC');
        Assert.IsTrue(StrPos(GetLastErrorText(), 'FIN-MISC') > 0, 'The finishing type is named');
    end;

    [Test]
    procedure ABindingTheEngineDoesNotImposeIsRefused()
    begin
        asserterror EnumNames.BindingFromCip4('HardCover', 'FIN-HC');
        Assert.IsTrue(StrPos(GetLastErrorText(), 'FIN-HC') > 0, 'The finishing type is named');
        Assert.IsTrue(StrPos(GetLastErrorText(), 'HardCover') > 0, 'The binding is named');
    end;

    [Test]
    procedure TheBindingComesFromTheJobsFinishingType()
    var
        RequestObject: JsonObject;
    begin
        AddBuildableJob(6201, 'SADDLE');
        TestData.AddFinishingType('SADDLE', 'SaddleStitch', '');

        RequestObject := RequestBuilder.BuildObject(6201, 1, 1);

        Assert.AreEqual('SaddleStitch', JsonHelper.ReadText(RequestObject, 'binding'), 'The finishing type names the binding');
    end;

    [Test]
    procedure TheBindingFallsBackToTheSheetsWhenTheJobHasNoFinishing()
    var
        RequestObject: JsonObject;
    begin
        // [GIVEN] a job with no finishing of its own, whose sheets both say SS
        AddBuildableJob(6202, '');
        TestData.AddFinishingType('SS', 'SaddleStitch', '');
        TestData.AddJobSheet(6202, 1, 1, 620201, 'SS');
        TestData.AddJobSheet(6202, 1, 1, 620202, 'SS');

        RequestObject := RequestBuilder.BuildObject(6202, 1, 1);

        Assert.AreEqual('SaddleStitch', JsonHelper.ReadText(RequestObject, 'binding'), 'The sheets name the binding');
    end;

    [Test]
    procedure TheJobsOwnFinishingWinsOverItsSheets()
    var
        RequestObject: JsonObject;
    begin
        // [GIVEN] a job finished SS whose sheet carries a code with no finishing type
        AddBuildableJob(6203, 'SS');
        TestData.AddFinishingType('SS', 'SaddleStitch', '');
        TestData.AddJobSheet(6203, 1, 1, 620301, 'UNMAPPED');

        RequestObject := RequestBuilder.BuildObject(6203, 1, 1);

        Assert.AreEqual('SaddleStitch', JsonHelper.ReadText(RequestObject, 'binding'), 'The job names the binding');
    end;

    [Test]
    procedure SheetsWithDifferentFinishingAreRefused()
    begin
        AddBuildableJob(6204, '');
        TestData.AddFinishingType('SS', 'SaddleStitch', '');
        TestData.AddFinishingType('PB', 'Adhesive', '');
        TestData.AddJobSheet(6204, 1, 1, 620401, 'SS');
        TestData.AddJobSheet(6204, 1, 1, 620402, 'PB');

        asserterror RequestBuilder.BuildObject(6204, 1, 1);

        Assert.IsTrue(StrPos(GetLastErrorText(), 'SS') > 0, 'The error names SS');
        Assert.IsTrue(StrPos(GetLastErrorText(), 'PB') > 0, 'The error names PB');
    end;

    [Test]
    procedure AFinishingCodeWithNoFinishingTypeIsRefused()
    begin
        // [GIVEN] a job finished with a code PrintVis has no finishing type for
        AddBuildableJob(6205, 'GHOST');

        asserterror RequestBuilder.BuildObject(6205, 1, 1);

        // [THEN] it is refused naming the code -- not given a default binding
        Assert.IsTrue(StrPos(GetLastErrorText(), 'GHOST') > 0, 'The finishing code is named');
    end;

    [Test]
    procedure TheBindingSideComesFromTheFinishingType()
    var
        RequestObject: JsonObject;
    begin
        // [GIVEN] no imposition code on the job, and a finishing type bound at the top
        AddBuildableJob(6206, 'TOPBOUND');
        TestData.AddFinishingType('TOPBOUND', 'SaddleStitch', 'Top');

        RequestObject := RequestBuilder.BuildObject(6206, 1, 1);

        Assert.AreEqual('Top', JsonHelper.ReadText(RequestObject, 'bindingSide'), 'The finishing type names the side');
    end;

    [Test]
    procedure TheBindingSideDefaultsToLeft()
    var
        RequestObject: JsonObject;
    begin
        AddBuildableJob(6207, 'NOSIDE');
        TestData.AddFinishingType('NOSIDE', 'SaddleStitch', '');

        RequestObject := RequestBuilder.BuildObject(6207, 1, 1);

        Assert.AreEqual('Left', JsonHelper.ReadText(RequestObject, 'bindingSide'), 'No side recorded anywhere is Left');
    end;

    [Test]
    procedure TheImpositionCodesSpineSideWins()
    var
        ImpositionCode: Record "PVS Imposition Code";
        JobItem: Record "PVS Job Item";
        RequestObject: JsonObject;
    begin
        // [GIVEN] a finishing type bound at the top, and the job's imposition code stating a right spine
        AddBuildableJob(6209, 'TOPBOUND2');
        TestData.AddFinishingType('TOPBOUND2', 'SaddleStitch', 'Top');
        ImpositionCode.Init();
        ImpositionCode.Code := 'IMP-RIGHT';
        ImpositionCode."Spine Side" := ImpositionCode."Spine Side"::Right;
        ImpositionCode.Insert(false);
        JobItem.SetRange(ID, 6209);
        JobItem.FindFirst();
        JobItem."Imposition Type" := 'IMP-RIGHT';
        JobItem.Modify(false);

        RequestObject := RequestBuilder.BuildObject(6209, 1, 1);

        // [THEN] the imposition code decides
        Assert.AreEqual('Right', JsonHelper.ReadText(RequestObject, 'bindingSide'), 'The imposition code''s spine side wins');
    end;

    [Test]
    procedure ABottomBindingSideIsReportedByTheValidator()
    var
        Problems: List of [Text];
    begin
        AddBuildableJob(6208, 'FOOTBOUND');
        TestData.AddFinishingType('FOOTBOUND', 'SaddleStitch', 'Bottom');

        Validator.Validate(6208, 1, 1, Problems);

        Assert.IsTrue(ProblemsMention(Problems, 'FOOTBOUND'), 'The finishing type is named');
    end;

    local procedure ProblemsMention(Problems: List of [Text]; Needle: Text): Boolean
    var
        Problem: Text;
    begin
        foreach Problem in Problems do
            if StrPos(Problem, Needle) > 0 then
                exit(true);
        exit(false);
    end;

    local procedure AddBuildableJob(CaseId: Integer; FinishingCode: Code[20])
    var
        Config: Record "PVS Cost Center Configuration";
    begin
        TestData.AddComponentType('BODY', 'Body', "PEQI Component Grain Rule"::ParallelToSpine);
        TestData.AddPaperItem('PAPER-100', 'PAPER-100');
        TestData.AddJobItem(CaseId, 1, 1, 1, 'BODY', 32, 148, 210, 'PAPER-100');
        TestData.AddJob(CaseId, 1, 1, FinishingCode, 5000);
        if not Config.Get('PRESS-A', 'STD') then
            TestData.AddPressConfig('PRESS-A', 'STD');
    end;
}
