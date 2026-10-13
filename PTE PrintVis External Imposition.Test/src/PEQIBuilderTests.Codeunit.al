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

codeunit 50610 "PEQI Builder Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestData: Codeunit "PEQI Test Data";
        PartMapper: Codeunit "PEQI Part Mapper";
        RequestBuilder: Codeunit "PEQI Request Builder";

    [Test]
    procedure JobItemsOfOneComponentBecomeOnePartWithSummedPages()
    var
        Parts: JsonArray;
        PartToken: JsonToken;
        Part: JsonObject;
        JsonHelper: Codeunit "PEQI Json Helper";
    begin
        // [GIVEN] a body split across two job items, 16 pages each
        TestData.AddComponentType('BODY', 'Body', "PEQI Component Grain Rule"::ParallelToSpine);
        TestData.AddPaperItem('PAPER-100', 'PAPER-100');
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
        TestData.AddComponentType('COVER', 'Cover', "PEQI Component Grain Rule"::ParallelToSpine);
        TestData.AddComponentType('BODY', 'Body', "PEQI Component Grain Rule"::ParallelToSpine);
        TestData.AddPaperItem('PAPER-240', 'PAPER-240');
        TestData.AddPaperItem('PAPER-100', 'PAPER-100');
        TestData.AddJobItem(5002, 1, 1, 1, 'COVER', 4, 148, 210, 'PAPER-240');
        TestData.AddJobItem(5002, 1, 1, 2, 'BODY', 28, 148, 210, 'PAPER-100');

        // [WHEN] the parts are built
        Parts := PartMapper.BuildParts(5002, 1, 1);

        // [THEN] there are two parts
        Assert.AreEqual(2, Parts.Count(), 'Two components are two parts');
    end;

    [Test]
    procedure TwoComponentsOnTwoPapersPinTwoStocks()
    var
        Parts: JsonArray;
        CoverId: Integer;
        BodyId: Integer;
    begin
        // [GIVEN] a cover and a body PrintVis has put on different paper
        TestData.AddComponentType('COVER', 'Cover', "PEQI Component Grain Rule"::ParallelToSpine);
        TestData.AddComponentType('BODY', 'Body', "PEQI Component Grain Rule"::ParallelToSpine);
        TestData.AddPaperItem('PAPER-240', 'PAPER-240');
        TestData.AddPaperItem('PAPER-100', 'PAPER-100');
        TestData.AddJobItem(5004, 1, 1, 1, 'COVER', 4, 148, 210, 'PAPER-240');
        TestData.AddJobItem(5004, 1, 1, 2, 'BODY', 28, 148, 210, 'PAPER-100');
        CoverId := TestData.SheetIdFor(5004, 1);
        BodyId := TestData.SheetIdFor(5004, 2);

        // [WHEN] the parts are built
        Parts := PartMapper.BuildParts(5004, 1, 1);

        // [THEN] each part is pinned to the stock its own sheet names, and neither is blank.
        // This is the whole defect: reading the job item's FlowField gave '' for both, every
        // part went out as catalog:{}, and the engine ran the cover on the body's paper.
        Assert.AreEqual(CoverId, OnlySubstrateId(Parts, 'COVER'), 'The cover keeps its own stock');
        Assert.AreEqual(BodyId, OnlySubstrateId(Parts, 'BODY'), 'The body keeps its own stock');
    end;

    [Test]
    procedure AComponentSpanningTwoPapersIsRefused()
    begin
        // [GIVEN] one component whose two job items sit on different paper
        TestData.AddComponentType('BODY', 'Body', "PEQI Component Grain Rule"::ParallelToSpine);
        TestData.AddPaperItem('PAPER-100', 'PAPER-100');
        TestData.AddPaperItem('PAPER-240', 'PAPER-240');
        TestData.AddJobItem(5005, 1, 1, 1, 'BODY', 16, 210, 297, 'PAPER-100');
        TestData.AddJobItem(5005, 1, 1, 2, 'BODY', 16, 210, 297, 'PAPER-240');

        // [WHEN] the parts are built
        asserterror PartMapper.BuildParts(5005, 1, 1);

        // [THEN] both papers are named, because a part is imposed on one stock
        Assert.IsTrue(StrPos(GetLastErrorText(), 'PAPER-100') > 0, 'The error names the first paper');
        Assert.IsTrue(StrPos(GetLastErrorText(), 'PAPER-240') > 0, 'The error names the second paper');
    end;

    /// <summary>The one substrate id pinned to the named part.</summary>
    local procedure OnlySubstrateId(Parts: JsonArray; PartName: Text): Integer
    var
        Part: JsonObject;
        PartToken: JsonToken;
        Token: JsonToken;
        Index: Integer;
    begin
        for Index := 0 to Parts.Count() - 1 do begin
            Parts.Get(Index, PartToken);
            Part := PartToken.AsObject();
            Part.Get('name', Token);
            if Token.AsValue().AsText() = PartName then begin
                Part.Get('catalog', Token);
                if not Token.AsObject().Get('substrateIds', Token) then
                    exit(0);
                Token.AsArray().Get(0, Token);
                exit(Token.AsValue().AsInteger());
            end;
        end;
        exit(0);
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
        TestData.AddComponentType('BODY', 'Body', "PEQI Component Grain Rule"::ParallelToSpine);
        TestData.AddPaperItem('PAPER-115', 'PAPER-115');
        TestData.AddJobItem(5003, 1, 1, 1, 'BODY', 32, 210, 297, 'PAPER-115');
        SubstrateId := TestData.SheetIdFor(5003, 1);

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
    procedure TheRequestStatesBothCatalogueHalvesAndNoCatalogFilter()
    var
        RequestObject: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] a saddle-stitched job with a cover and a body, one paper, one press
        TestData.AddComponentType('COVER', 'Cover', "PEQI Component Grain Rule"::ParallelToSpine);
        TestData.AddComponentType('BODY', 'Body', "PEQI Component Grain Rule"::ParallelToSpine);
        TestData.AddPaperItem('PAPER-240', 'PAPER-240');
        TestData.AddPaperItem('PAPER-100', 'PAPER-100');
        TestData.AddJobItem(6001, 1, 1, 1, 'COVER', 4, 148, 210, 'PAPER-240');
        TestData.AddJobItem(6001, 1, 1, 2, 'BODY', 28, 148, 210, 'PAPER-100');

        TestData.AddFinishingType('SADDLE', 'SaddleStitch', '');
        TestData.AddJob(6001, 1, 1, 'SADDLE', 5000);

        TestData.AddPressConfig('PRESS-A', 'STD');

        // [WHEN] the request is built
        RequestObject := RequestBuilder.BuildObject(6001, 1, 1);

        // [THEN] both halves are stated
        Assert.IsTrue(RequestObject.Get('sheets', Token), 'The request states its paper');
        Assert.IsTrue(RequestObject.Get('presses', Token), 'The request states its presses');
        Assert.IsTrue(RequestObject.Get('foldPatterns', Token), 'The request states its fold patterns');

        // [THEN] no catalog filter accompanies them - a stated half replaces its
        // catalogue and the engine refuses the matching filters outright
        Assert.IsFalse(RequestObject.Get('catalog', Token), 'A self-contained request sends no catalog filter');

        // [THEN] no imposition rules are sent - they are measurements of another building
        Assert.IsFalse(RequestObject.Get('impositionRules', Token), 'Imposition rules are never sent');
    end;

    [Test]
    procedure TheRequestIsStableAcrossTwoBuilds()
    var
        First: Text;
        Second: Text;
    begin
        // [GIVEN] a job
        TestData.AddComponentType('BODY', 'Body', "PEQI Component Grain Rule"::ParallelToSpine);
        TestData.AddPaperItem('PAPER-90', 'PAPER-90');
        TestData.AddJobItem(6002, 1, 1, 1, 'BODY', 32, 210, 297, 'PAPER-90');
        TestData.AddFinishingType('SADDLE', 'SaddleStitch', '');
        TestData.AddJob(6002, 1, 1, 'SADDLE', 1000);
        TestData.AddPressConfig('PRESS-A', 'STD');

        // [WHEN] the request is built twice
        First := RequestBuilder.Build(6002, 1, 1);
        Second := RequestBuilder.Build(6002, 1, 1);

        // [THEN] the two are identical
        // /calculate and /jdf must agree, and the engine's snapshotId hashes the
        // rows we sent. A request that differs between builds cannot quote a
        // solution back.
        Assert.AreEqual(First, Second, 'The same job builds the same request');
    end;
}
