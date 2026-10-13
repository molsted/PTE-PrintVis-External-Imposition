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

codeunit 50617 "PEQI Sheet Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestData: Codeunit "PEQI Test Data";
        CatalogMapper: Codeunit "PEQI Catalog Mapper";
        PartMapper: Codeunit "PEQI Part Mapper";
        JsonHelper: Codeunit "PEQI Json Helper";

    [Test]
    procedure TheSheetsAreTheJobsOwn()
    var
        Sheets: JsonArray;
    begin
        // [GIVEN] a job whose one job item sits on a sheet of PAPER-A
        TestData.AddPaperItem('PAPER-A', 'White Gloss');
        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        TestData.AddJobItem(8001, 1, 1, 1, 'BODY', 16, 210, 297, 'PAPER-A');

        // [WHEN] the sheets half is built
        Sheets := CatalogMapper.BuildSheets(8001, 1, 1);

        // [THEN] it is that sheet, identified by its Sheet ID and named by its item
        Assert.AreEqual(1, Sheets.Count(), 'One sheet is sent');
        Assert.AreEqual(TestData.SheetIdFor(8001, 1), FirstInteger(Sheets, 'id'), 'The substrate id is the Sheet ID');
        Assert.AreEqual('White Gloss', FirstText(Sheets, 'name'), 'The name is the paper item''s description');
    end;

    [Test]
    procedure ThreeSheetsOfOnePaperAreOneSubstrate()
    var
        Sheets: JsonArray;
        Parts: JsonArray;
    begin
        // [GIVEN] three job items of one component, each on its own sheet of the same paper and format
        TestData.AddPaperItem('PAPER-A', 'White Gloss');
        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        TestData.AddJobItem(8002, 1, 1, 1, 'BODY', 16, 210, 297, 'PAPER-A');
        TestData.AddJobItem(8002, 1, 1, 2, 'BODY', 16, 210, 297, 'PAPER-A');
        TestData.AddJobItem(8002, 1, 1, 3, 'BODY', 16, 210, 297, 'PAPER-A');

        // [WHEN] the request halves are built
        Sheets := CatalogMapper.BuildSheets(8002, 1, 1);
        Parts := PartMapper.BuildParts(8002, 1, 1);

        // [THEN] they are one substrate, with the lowest Sheet ID, and the part is pinned to it.
        // Three would make the engine treat them as three stocks and split one run into three.
        Assert.AreEqual(1, Sheets.Count(), 'One paper at one format is one substrate');
        Assert.AreEqual(TestData.SheetIdFor(8002, 1), FirstInteger(Sheets, 'id'), 'The lowest Sheet ID names the group');
        Assert.AreEqual(TestData.SheetIdFor(8002, 1), PinnedSubstrate(Parts, 'BODY'), 'The part is pinned to the group');
    end;

    [Test]
    procedure TheSamePaperAtTwoFormatsIsTwoSubstrates()
    var
        Sheets: JsonArray;
    begin
        // [GIVEN] two components on the same paper at two printing formats
        TestData.AddPaperItem('PAPER-A', 'White Gloss');
        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        TestData.AddPartMapping('COVER', "PEQI Part Product Type"::Cover);
        TestData.AddJobItem(8003, 1, 1, 1, 'BODY', 16, 210, 297, 'PAPER-A');
        TestData.AddJobItem(8003, 1, 1, 2, 'COVER', 4, 430, 297, 'PAPER-A');
        TestData.SetSheetFormat(8003, 2, 720, 520);

        // [WHEN] the sheets half is built
        Sheets := CatalogMapper.BuildSheets(8003, 1, 1);

        // [THEN] they stay two, because a press sheet's size is part of what it is
        Assert.AreEqual(2, Sheets.Count(), 'One paper at two formats is two substrates');
    end;

    [Test]
    procedure AnUncutSheetKeepsItsGrain()
    var
        Sheets: JsonArray;
    begin
        // [GIVEN] a sheet printed at its full purchased size, grain recorded as 1<2
        TestData.AddPaperItem('PAPER-A', 'White Gloss');
        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        TestData.AddJobItem(8004, 1, 1, 1, 'BODY', 16, 210, 297, 'PAPER-A');
        TestData.SetSheetFullFormat(8004, 1, 640, 450, false);

        // [WHEN] the sheets half is built
        Sheets := CatalogMapper.BuildSheets(8004, 1, 1);

        // [THEN] the grain is sent, mapped as an item's grain always has been: 1<2 is Long
        Assert.AreEqual('Long', FirstText(Sheets, 'grain'), 'An uncut sheet carries its grain');
    end;

    [Test]
    procedure AnUncutSheetTurnedSidewaysKeepsItsGrain()
    var
        Sheets: JsonArray;
    begin
        // [GIVEN] the full sheet recorded 450 x 640 and printed as 640 x 450 -- the same sheet
        TestData.AddPaperItem('PAPER-A', 'White Gloss');
        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        TestData.AddJobItem(8005, 1, 1, 1, 'BODY', 16, 210, 297, 'PAPER-A');
        TestData.SetSheetFullFormat(8005, 1, 450, 640, true);

        // [WHEN] the sheets half is built
        Sheets := CatalogMapper.BuildSheets(8005, 1, 1);

        // [THEN] it is still uncut, so the grain is still sent
        Assert.AreEqual('Short', FirstText(Sheets, 'grain'), 'Orientation alone does not make a sheet cut');
    end;

    [Test]
    procedure ACutSheetCarriesNoGrain()
    var
        Sheets: JsonArray;
        Sheet: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] a 640 x 450 printing format cut from a 1280 x 900 purchased sheet
        TestData.AddPaperItem('PAPER-A', 'White Gloss');
        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        TestData.AddJobItem(8006, 1, 1, 1, 'BODY', 16, 210, 297, 'PAPER-A');
        TestData.SetSheetFullFormat(8006, 1, 1280, 900, false);

        // [WHEN] the sheets half is built
        Sheets := CatalogMapper.BuildSheets(8006, 1, 1);
        Sheets.Get(0, Token);
        Sheet := Token.AsObject();

        // [THEN] no grain is claimed. Which full-sheet edge became which press-sheet edge is not
        // established yet, and a wrong grain is worse than an unverified one.
        Assert.IsFalse(Sheet.Contains('grain'), 'A cut sheet sends no grain');
    end;

    [Test]
    procedure ASheetIsSentLongestEdgeAsWidth()
    var
        Sheets: JsonArray;
        Units: Codeunit "PEQI Unit Converter";
    begin
        // [GIVEN] a printing format recorded short side first
        TestData.AddPaperItem('PAPER-A', 'White Gloss');
        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        TestData.AddJobItem(8007, 1, 1, 1, 'BODY', 16, 210, 297, 'PAPER-A');
        TestData.SetSheetFormat(8007, 1, 450, 640);

        // [WHEN] the sheets half is built
        Sheets := CatalogMapper.BuildSheets(8007, 1, 1);

        // [THEN] the longer edge is the width, always
        Assert.AreEqual(Units.FormatToMm(640), FirstDecimal(Sheets, 'widthMm'), 'The longer edge is the width');
        Assert.AreEqual(Units.FormatToMm(450), FirstDecimal(Sheets, 'heightMm'), 'The shorter edge is the height');
    end;

    local procedure FirstObject(Sheets: JsonArray): JsonObject
    var
        Token: JsonToken;
    begin
        Sheets.Get(0, Token);
        exit(Token.AsObject());
    end;

    local procedure FirstInteger(Sheets: JsonArray; Name: Text): Integer
    begin
        exit(JsonHelper.ReadInteger(FirstObject(Sheets), Name));
    end;

    local procedure FirstDecimal(Sheets: JsonArray; Name: Text): Decimal
    begin
        exit(JsonHelper.ReadDecimal(FirstObject(Sheets), Name));
    end;

    local procedure FirstText(Sheets: JsonArray; Name: Text): Text
    begin
        exit(JsonHelper.ReadText(FirstObject(Sheets), Name));
    end;

    /// <summary>The one substrate id pinned to the named part, or 0.</summary>
    local procedure PinnedSubstrate(Parts: JsonArray; PartName: Text): Integer
    var
        Part: JsonObject;
        Catalog: JsonObject;
        Ids: JsonArray;
        Token: JsonToken;
        Index: Integer;
    begin
        for Index := 0 to Parts.Count() - 1 do begin
            Parts.Get(Index, Token);
            Part := Token.AsObject();
            if JsonHelper.ReadText(Part, 'name') = PartName then begin
                if not JsonHelper.ReadObject(Part, 'catalog', Catalog) then
                    exit(0);
                if not JsonHelper.ReadArray(Catalog, 'substrateIds', Ids) then
                    exit(0);
                Ids.Get(0, Token);
                exit(Token.AsValue().AsInteger());
            end;
        end;
        exit(0);
    end;
}
