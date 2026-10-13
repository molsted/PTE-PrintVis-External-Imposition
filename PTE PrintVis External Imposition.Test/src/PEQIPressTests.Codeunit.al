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

codeunit 50618 "PEQI Press Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestData: Codeunit "PEQI Test Data";
        CatalogMapper: Codeunit "PEQI Catalog Mapper";
        JsonHelper: Codeunit "PEQI Json Helper";

    [Test]
    procedure AConfigurationMarkedForImpositionIsAPress()
    var
        Presses: JsonArray;
    begin
        // [GIVEN] one configuration marked for imposition
        TestData.AddPressConfig('PRESS-A', 'STD');

        // [WHEN] the presses half is built
        Presses := CatalogMapper.BuildPresses();

        // [THEN] it is sent
        Assert.AreEqual(1, Presses.Count(), 'A marked configuration is a press');
    end;

    [Test]
    procedure APressIdIsAssignedWhenMarkedAndNeverChanges()
    var
        Config: Record "PVS Cost Center Configuration";
        Original: Guid;
    begin
        // [GIVEN] a configuration marked for imposition
        TestData.AddPressConfig('PRESS-ID', 'STD');
        Config.Get('PRESS-ID', 'STD');
        Original := Config."PEQI Press Id";

        // [THEN] it has an id
        Assert.IsFalse(IsNullGuid(Original), 'Marking a configuration assigns a press id');

        // [WHEN] it is unmarked and marked again
        Config.Validate("PEQI Use for Imposition", false);
        Config.Validate("PEQI Use for Imposition", true);

        // [THEN] the id is the same. The engine's solutionId hashes it, so a changed id makes
        // every quoted solution unknown at /jdf.
        Assert.AreEqual(Original, Config."PEQI Press Id", 'The press id never changes');
    end;

    [Test]
    procedure APressCarriesItsStoredId()
    var
        Config: Record "PVS Cost Center Configuration";
        Presses: JsonArray;
        Token: JsonToken;
    begin
        TestData.AddPressConfig('PRESS-ID2', 'STD');
        Config.Get('PRESS-ID2', 'STD');

        Presses := CatalogMapper.BuildPresses();
        Presses.Get(0, Token);

        Assert.AreEqual(
            LowerCase(DelChr(Format(Config."PEQI Press Id"), '=', '{}')),
            LowerCase(JsonHelper.ReadText(Token.AsObject(), 'id')),
            'The press carries its stored id');
    end;

    [Test]
    procedure APressCarriesItsWorkStylesExplicitly()
    var
        Config: Record "PVS Cost Center Configuration";
        Presses: JsonArray;
        Token: JsonToken;
        Styles: JsonArray;
    begin
        // [GIVEN] a press that can also work-and-turn
        TestData.AddPressConfig('PRESS-WT', 'STD');
        Config.Get('PRESS-WT', 'STD');
        Config."PEQI Work And Turn" := true;
        Config.Modify(false);

        // [WHEN] the presses half is built
        Presses := CatalogMapper.BuildPresses();
        Presses.Get(0, Token);
        JsonHelper.ReadArray(Token.AsObject(), 'workStyles', Styles);

        // [THEN] all three are stated, because the engine never derives WorkAndTurn
        Assert.AreEqual(3, Styles.Count(), 'All three declared work styles are sent');
    end;

    [Test]
    procedure OptionalPressFieldsAreSentOnlyWhenSet()
    var
        Config: Record "PVS Cost Center Configuration";
        Presses: JsonArray;
        Token: JsonToken;
        Press: JsonObject;
    begin
        // [GIVEN] a press with make and model but no trailing margin and no digital subtype
        TestData.AddPressConfig('PRESS-OPT', 'STD');
        Config.Get('PRESS-OPT', 'STD');
        Config."PEQI Make" := 'Heidelberg';
        Config."PEQI Model" := 'Speedmaster XL 106';
        Config.Modify(false);

        // [WHEN] the presses half is built
        Presses := CatalogMapper.BuildPresses();
        Presses.Get(0, Token);
        Press := Token.AsObject();

        // [THEN] what is set is sent, and what is not is absent rather than zero
        Assert.AreEqual('Heidelberg', JsonHelper.ReadText(Press, 'make'), 'Make is sent');
        Assert.AreEqual('Speedmaster XL 106', JsonHelper.ReadText(Press, 'model'), 'Model is sent');
        Assert.IsFalse(Press.Contains('trailingMarginMm'), 'An unset trailing margin is not sent');
        Assert.IsFalse(Press.Contains('digitalType'), 'An offset press sends no digital subtype');
        Assert.IsFalse(Press.Contains('minGrammageGsm'), 'An unset weight limit is not sent');
    end;

    [Test]
    procedure AnUnmarkedConfigurationIsNotAPress()
    var
        Config: Record "PVS Cost Center Configuration";
        Presses: JsonArray;
    begin
        TestData.AddPressConfig('PRESS-OFF', 'STD');
        Config.Get('PRESS-OFF', 'STD');
        Config.Validate("PEQI Use for Imposition", false);
        Config.Modify(false);

        Presses := CatalogMapper.BuildPresses();

        Assert.AreEqual(0, Presses.Count(), 'An unmarked configuration is not sent');
    end;
}
