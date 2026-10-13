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
using PrintersEquity.ExternalImposition.Setup;
using System.TestLibraries.Utilities;

codeunit 50622 "PEQI Trim Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestData: Codeunit "PEQI Test Data";
        PartMapper: Codeunit "PEQI Part Mapper";
        Units: Codeunit "PEQI Unit Converter";
        JsonHelper: Codeunit "PEQI Json Helper";

    [Test]
    procedure TheJobItemsOwnTrimWins()
    var
        Part: JsonObject;
    begin
        AddJob(9101);
        SetTrims(9101, 5, 0, 0, 2);
        SetSetupDefaults(4, 4, 4);

        Part := OnlyPart(9101);

        Assert.AreEqual(Units.MarginToMm(5), JsonHelper.ReadDecimal(Part, 'trimHeadMm'), 'The job item''s own head trim wins');
    end;

    [Test]
    procedure TheAllRoundTrimFillsAnUnsetEdge()
    var
        Part: JsonObject;
    begin
        AddJob(9102);
        SetTrims(9102, 5, 0, 0, 2);
        SetSetupDefaults(4, 4, 4);

        Part := OnlyPart(9102);

        Assert.AreEqual(Units.MarginToMm(2), JsonHelper.ReadDecimal(Part, 'trimFootMm'), 'The all-round trim fills the foot');
    end;

    [Test]
    procedure TheSetupDefaultFillsWhatTheJobItemDoesNotState()
    var
        Part: JsonObject;
    begin
        AddJob(9103);
        SetTrims(9103, 0, 0, 0, 0);
        SetSetupDefaults(4, 6, 8);

        Part := OnlyPart(9103);

        Assert.AreEqual(Units.MarginToMm(8), JsonHelper.ReadDecimal(Part, 'trimFaceMm'), 'The setup default fills the face');
    end;

    [Test]
    procedure NothingStatedLeavesTheEngineDefault()
    var
        Part: JsonObject;
    begin
        AddJob(9104);
        SetTrims(9104, 0, 0, 0, 0);
        SetSetupDefaults(0, 0, 0);

        Part := OnlyPart(9104);

        Assert.IsFalse(Part.Contains('trimHeadMm'), 'No trim stated anywhere is not sent, and the engine applies its own');
    end;

    local procedure AddJob(CaseId: Integer)
    begin
        TestData.AddPaperItem('PAPER-A', 'Paper A');
        TestData.AddComponentType('BODY', 'Body', "PEQI Component Grain Rule"::ParallelToSpine);
        TestData.AddJobItem(CaseId, 1, 1, 1, 'BODY', 16, 210, 297, 'PAPER-A');
    end;

    local procedure SetTrims(CaseId: Integer; Head: Decimal; Foot: Decimal; Face: Decimal; AllRound: Decimal)
    var
        JobItem: Record "PVS Job Item";
    begin
        JobItem.SetRange(ID, CaseId);
        JobItem.FindFirst();
        JobItem."Trim Head" := Head;
        JobItem."Trim Foot" := Foot;
        JobItem."Trim Face" := Face;
        JobItem.Trim := AllRound;
        JobItem.Modify(false);
    end;

    local procedure SetSetupDefaults(Head: Decimal; Foot: Decimal; Face: Decimal)
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        Setup := Setup.GetSetup();
        Setup."Default Trim Head" := Head;
        Setup."Default Trim Foot" := Foot;
        Setup."Default Trim Face" := Face;
        Setup.Modify(false);
    end;

    local procedure OnlyPart(CaseId: Integer): JsonObject
    var
        Parts: JsonArray;
        Token: JsonToken;
    begin
        Parts := PartMapper.BuildParts(CaseId, 1, 1);
        Parts.Get(0, Token);
        exit(Token.AsObject());
    end;
}
