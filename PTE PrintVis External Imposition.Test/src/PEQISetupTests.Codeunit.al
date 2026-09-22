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

using PrintersEquity.ExternalImposition.Setup;
using System.TestLibraries.Utilities;

codeunit 50609 "PEQI Setup Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure PressIdIsAssignedOnInsert()
    var
        PressSetup: Record "PEQI Press Setup";
    begin
        // [GIVEN] a press setup row with no press id
        PressSetup.Init();
        PressSetup."Cost Center Code" := 'PRESS01';
        PressSetup.Configuration := 'STD';
        Clear(PressSetup."Press Id");

        // [WHEN] it is inserted
        PressSetup.Insert(true);

        // [THEN] a press id has been assigned
        Assert.IsFalse(IsNullGuid(PressSetup."Press Id"), 'Press Id should be assigned on insert');
    end;

    [Test]
    procedure PressIdSurvivesModify()
    var
        PressSetup: Record "PEQI Press Setup";
        Original: Guid;
    begin
        // [GIVEN] an inserted press setup row
        PressSetup.Init();
        PressSetup."Cost Center Code" := 'PRESS02';
        PressSetup.Configuration := 'STD';
        PressSetup.Insert(true);
        Original := PressSetup."Press Id";

        // [WHEN] the row is cleared of its id and modified
        Clear(PressSetup."Press Id");
        PressSetup.Modify(true);

        // [THEN] the original id is restored, not regenerated
        // A regenerated id makes every quoted solutionId stale at /jdf.
        PressSetup.Get('PRESS02', 'STD');
        Assert.AreEqual(Original, PressSetup."Press Id", 'Press Id must never change');
    end;

    [Test]
    procedure SubstrateIdIsSequentialAndNeverReused()
    var
        PaperSetup: Record "PEQI Paper Setup";
        First: Integer;
        Second: Integer;
    begin
        // [GIVEN] two paper setup rows
        PaperSetup.Init();
        PaperSetup."Item No." := 'PAPER-A';
        PaperSetup.Insert(true);
        First := PaperSetup."Substrate Id";

        PaperSetup.Init();
        PaperSetup."Item No." := 'PAPER-B';
        PaperSetup.Insert(true);
        Second := PaperSetup."Substrate Id";

        // [THEN] they differ and ascend
        Assert.AreNotEqual(First, Second, 'Substrate Ids must be distinct');
        Assert.IsTrue(Second > First, 'Substrate Ids ascend');

        // [WHEN] the later row is deleted and a third is inserted
        PaperSetup.Get('PAPER-B', '');
        PaperSetup.Delete(true);
        PaperSetup.Init();
        PaperSetup."Item No." := 'PAPER-C';
        PaperSetup.Insert(true);

        // [THEN] the deleted id is not handed out again
        Assert.IsTrue(PaperSetup."Substrate Id" > Second, 'Substrate Ids are never reused');
    end;
}
