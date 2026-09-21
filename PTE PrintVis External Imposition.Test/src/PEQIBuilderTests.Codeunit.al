// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

codeunit 50610 "PEQI Builder Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestData: Codeunit "PEQI Test Data";
        PartMapper: Codeunit "PEQI Part Mapper";
        CatalogMapper: Codeunit "PEQI Catalog Mapper";

    [Test]
    procedure JobItemsOfOneComponentBecomeOnePartWithSummedPages()
    var
        Parts: JsonArray;
        PartToken: JsonToken;
        Part: JsonObject;
        JsonHelper: Codeunit "PEQI Json Helper";
    begin
        // [GIVEN] a body split across two job items, 16 pages each
        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        TestData.AddPaper('PAPER-100');
        TestData.AddJobItem(5001, 1, 1, 1, 'BODY', 16, 210, 297, 'PAPER-100');
        TestData.AddJobItem(5001, 1, 1, 2, 'BODY', 16, 210, 297, 'PAPER-100');

        // [WHEN] the parts are built
        Parts := PartMapper.BuildParts(5001, 1, 1);

        // [THEN] there is one part of 32 pages, not two of 16
        // The engine decides the sheet breakdown; feeding it PrintVis's would
        // ask it to confirm its own input.
        Assert.AreEqual(1, Parts.Count(), 'One component is one part');
        Parts.Get(0, PartToken);
        Part := PartToken.AsObject();
        Assert.AreEqual(32, JsonHelper.ReadInteger(Part, 'pageCount'), 'Pages are summed');
        Assert.AreEqual(210.0, JsonHelper.ReadDecimal(Part, 'trimWidthMm'), 'Width is the trim width');
        Assert.AreEqual(297.0, JsonHelper.ReadDecimal(Part, 'trimHeightMm'), 'Length is the trim height');
        Assert.AreEqual('Body', JsonHelper.ReadText(Part, 'productType'), 'Product type comes from the part mapping');
        Assert.AreEqual('ParallelToSpine', JsonHelper.ReadText(Part, 'grainRule'), 'Grain rule is the engine spelling, not the caption');
    end;

    [Test]
    procedure EachComponentBecomesItsOwnPart()
    var
        Parts: JsonArray;
    begin
        // [GIVEN] a cover and a body
        TestData.AddPartMapping('COVER', "PEQI Part Product Type"::Cover);
        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        TestData.AddPaper('PAPER-240');
        TestData.AddPaper('PAPER-100');
        TestData.AddJobItem(5002, 1, 1, 1, 'COVER', 4, 148, 210, 'PAPER-240');
        TestData.AddJobItem(5002, 1, 1, 2, 'BODY', 28, 148, 210, 'PAPER-100');

        // [WHEN] the parts are built
        Parts := PartMapper.BuildParts(5002, 1, 1);

        // [THEN] there are two parts
        Assert.AreEqual(2, Parts.Count(), 'Two components are two parts');
    end;

    [Test]
    procedure APartSelectsItsOwnStockBySurrogateId()
    var
        Parts: JsonArray;
        PartToken: JsonToken;
        Part: JsonObject;
        CatalogToken: JsonToken;
        Ids: JsonArray;
        IdToken: JsonToken;
        SubstrateId: Integer;
    begin
        // [GIVEN] a body on a known paper
        TestData.AddPartMapping('BODY', "PEQI Part Product Type"::Body);
        SubstrateId := TestData.AddPaper('PAPER-115');
        TestData.AddJobItem(5003, 1, 1, 1, 'BODY', 32, 210, 297, 'PAPER-115');

        // [WHEN] the parts are built
        Parts := PartMapper.BuildParts(5003, 1, 1);
        Parts.Get(0, PartToken);
        Part := PartToken.AsObject();
        Part.Get('catalog', CatalogToken);
        CatalogToken.AsObject().Get('substrateIds', IdToken);
        Ids := IdToken.AsArray();
        Ids.Get(0, IdToken);

        // [THEN] it names the paper by its integer surrogate, not its item number
        Assert.AreEqual(SubstrateId, IdToken.AsValue().AsInteger(), 'A part selects on the substrate surrogate id');
    end;

    [Test]
    procedure OnlyPaperMarkedForImpositionIsSent()
    var
        Sheets: JsonArray;
        PaperSetup: Record "PEQI Paper Setup";
    begin
        // [GIVEN] one paper marked for imposition and one not
        TestData.AddPaper('PAPER-USED');
        PaperSetup.Init();
        PaperSetup."Item No." := 'PAPER-UNUSED';
        PaperSetup."Use for Imposition" := false;
        PaperSetup.Insert(true);

        // [WHEN] the sheets half is built
        Sheets := CatalogMapper.BuildSheets();

        // [THEN] only the marked one is present
        Assert.AreEqual(1, Sheets.Count(), 'Unmarked paper is not sent');
    end;

    [Test]
    procedure APressCarriesItsWorkStylesExplicitly()
    var
        Presses: JsonArray;
        PressToken: JsonToken;
        Press: JsonObject;
        StylesToken: JsonToken;
        Styles: JsonArray;
        PressSetup: Record "PEQI Press Setup";
    begin
        // [GIVEN] a press that can work-and-turn
        PressSetup.Init();
        PressSetup."Cost Center Code" := 'PRESS-WT';
        PressSetup.Configuration := 'STD';
        PressSetup."Use for Imposition" := true;
        PressSetup.Simplex := true;
        PressSetup."Work And Back" := true;
        PressSetup."Work And Turn" := true;
        PressSetup.Insert(true);

        // [WHEN] the presses half is built
        Presses := CatalogMapper.BuildPresses();
        Presses.Get(0, PressToken);
        Press := PressToken.AsObject();
        Press.Get('workStyles', StylesToken);
        Styles := StylesToken.AsArray();

        // [THEN] WorkAndTurn is stated, because the engine never derives it
        Assert.AreEqual(3, Styles.Count(), 'All three declared work styles are sent');
    end;

    [Test]
    procedure APressCarriesItsStoredIdNotAFreshOne()
    var
        Presses: JsonArray;
        PressToken: JsonToken;
        PressSetup: Record "PEQI Press Setup";
        JsonHelper: Codeunit "PEQI Json Helper";
    begin
        // [GIVEN] a press with an assigned id
        PressSetup.Init();
        PressSetup."Cost Center Code" := 'PRESS-ID';
        PressSetup.Configuration := 'STD';
        PressSetup."Use for Imposition" := true;
        PressSetup.Insert(true);

        // [WHEN] the presses half is built twice
        Presses := CatalogMapper.BuildPresses();
        Presses.Get(0, PressToken);

        // [THEN] the id is the stored one
        // A fresh GUID per call makes every quoted solutionId stale at /jdf.
        Assert.AreEqual(
            LowerCase(DelChr(Format(PressSetup."Press Id"), '=', '{}')),
            LowerCase(JsonHelper.ReadText(PressToken.AsObject(), 'id')),
            'The press carries its stored id');
    end;
}
