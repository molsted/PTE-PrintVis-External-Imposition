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

using Microsoft.Inventory.Item;
using PrintersEquity.ExternalImposition.Enums;
using PrintersEquity.ExternalImposition.Mapping;
using PrintersEquity.ExternalImposition.Setup;
using System.TestLibraries.Utilities;

codeunit 50611 "PEQI Validator Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestData: Codeunit "PEQI Test Data";
        Validator: Codeunit "PEQI Request Validator";

    [Test]
    procedure AFoldedPartWithAnOddPageCountIsRefused()
    var
        Problems: List of [Text];
    begin
        // [GIVEN] a body with three pages
        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        TestData.AddPaper('PAPER-100');
        TestData.AddJobItem(7001, 1, 1, 1, 'BODY', 3, 210, 297, 'PAPER-100');

        // [WHEN] the job is validated
        // [THEN] it is refused and the message names the component
        Assert.IsFalse(Validator.Validate(7001, 1, 1, Problems), 'An odd page count on a folded part is refused');
        Assert.IsTrue(Problems.Count() > 0, 'A problem is reported');
        Assert.IsTrue(ProblemsMention(Problems, 'BODY'), 'The problem names the component');
    end;

    [Test]
    procedure EveryProblemIsReportedNotJustTheFirst()
    var
        Problems: List of [Text];
    begin
        // [GIVEN] a job with two unmapped component types
        TestData.AddPaper('PAPER-100');
        TestData.AddJobItem(7002, 1, 1, 1, 'UNMAPPED-A', 4, 210, 297, 'PAPER-100');
        TestData.AddJobItem(7002, 1, 1, 2, 'UNMAPPED-B', 8, 210, 297, 'PAPER-100');

        // [WHEN] the job is validated
        Validator.Validate(7002, 1, 1, Problems);

        // [THEN] both are reported, so the operator fixes both in one visit.
        // The count is not asserted: the catalogue checks contribute problems of
        // their own, and pinning the total would make this test fail for reasons
        // that have nothing to do with what it is about.
        Assert.IsTrue(ProblemsMention(Problems, 'UNMAPPED-A'), 'The first unmapped component is reported');
        Assert.IsTrue(ProblemsMention(Problems, 'UNMAPPED-B'), 'The second unmapped component is reported too');
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

    [Test]
    procedure PaperWithNoSheetFormatIsRefused()
    var
        Problems: List of [Text];
        PaperSetup: Record "PEQI Paper Setup";
        Item: Record Item;
    begin
        // [GIVEN] a paper marked for imposition whose item has no sheet size
        Item.Init();
        Item."No." := 'PAPER-NOSIZE';
        Item."PVS Format 1" := 0;
        Item."PVS Format 2" := 0;
        Item.Insert(true);
        PaperSetup.Init();
        PaperSetup."Item No." := 'PAPER-NOSIZE';
        PaperSetup."Use for Imposition" := true;
        PaperSetup.Insert(true);

        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        TestData.AddJobItem(7003, 1, 1, 1, 'BODY', 32, 210, 297, 'PAPER-NOSIZE');

        // [WHEN] the job is validated
        Validator.Validate(7003, 1, 1, Problems);

        // [THEN] the paper is named
        Assert.IsTrue(ProblemsMention(Problems, 'PAPER-NOSIZE'), 'The problem names the item');
    end;

    [Test]
    procedure AJobWhoseSheetsCarryAMappedFinishingPasses()
    var
        Problems: List of [Text];
        BindingMapping: Record "PEQI Binding Mapping";
    begin
        // [GIVEN] a job with no finishing of its own, whose sheet says SS, and SS is mapped
        BindingMapping.Init();
        BindingMapping."Finishing Code" := 'SS';
        BindingMapping.Insert(true);
        TestData.AddJob(7101, 1, 1, '', 1000);
        TestData.AddJobSheet(7101, 1, 1, 710101, 'SS');

        // [WHEN] the job is validated
        Validator.Validate(7101, 1, 1, Problems);

        // [THEN] no finishing problem is reported
        Assert.IsFalse(ProblemsMention(Problems, 'inishing'), 'The sheets supply the finishing');
    end;

    [Test]
    procedure AJobWithNoFinishingAnywhereIsRefused()
    var
        Problems: List of [Text];
    begin
        // [GIVEN] a job with no finishing on it or on any sheet
        TestData.AddJob(7102, 1, 1, '', 1000);
        TestData.AddJobSheet(7102, 1, 1, 710201, '');

        // [WHEN] the job is validated
        Validator.Validate(7102, 1, 1, Problems);

        // [THEN] the missing finishing is reported as missing, not as an unmapped blank code
        Assert.IsTrue(ProblemsMention(Problems, 'no finishing code'), 'The problem says no finishing is set');
    end;
}
