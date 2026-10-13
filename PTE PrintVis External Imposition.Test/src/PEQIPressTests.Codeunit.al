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
        Validator: Codeunit "PEQI Request Validator";

    [Test]
    procedure AConfigurationMarkedForImpositionIsAPress()
    var
        Presses: JsonArray;
        Press: JsonObject;
    begin
        // [GIVEN] one configuration marked for imposition
        TestData.AddPressConfig('PRESS-A', 'STD');

        // [WHEN] the presses half is built
        Presses := CatalogMapper.BuildPresses();

        // [THEN] it is sent
        Assert.IsTrue(PressNamed(Presses, 'PRESS-A', Press), 'A marked configuration is a press');
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
        Press: JsonObject;
    begin
        TestData.AddPressConfig('PRESS-ID2', 'STD');
        Config.Get('PRESS-ID2', 'STD');

        Presses := CatalogMapper.BuildPresses();
        Assert.IsTrue(PressNamed(Presses, 'PRESS-ID2', Press), 'The press is built');

        Assert.AreEqual(
            LowerCase(DelChr(Format(Config."PEQI Press Id"), '=', '{}')),
            LowerCase(JsonHelper.ReadText(Press, 'id')),
            'The press carries its stored id');
    end;

    [Test]
    procedure APressCarriesItsWorkStylesExplicitly()
    var
        Config: Record "PVS Cost Center Configuration";
        Presses: JsonArray;
        Press: JsonObject;
        Styles: JsonArray;
    begin
        // [GIVEN] a press that can also work-and-turn
        TestData.AddPressConfig('PRESS-WT', 'STD');
        Config.Get('PRESS-WT', 'STD');
        Config."PEQI Work And Turn" := true;
        Config.Modify(false);

        // [WHEN] the presses half is built
        Presses := CatalogMapper.BuildPresses();
        Assert.IsTrue(PressNamed(Presses, 'PRESS-WT', Press), 'The press is built');
        JsonHelper.ReadArray(Press, 'workStyles', Styles);

        // [THEN] all three are stated, because the engine never derives WorkAndTurn
        Assert.AreEqual(3, Styles.Count(), 'All three declared work styles are sent');
    end;

    [Test]
    procedure OptionalPressFieldsAreSentOnlyWhenSet()
    var
        Config: Record "PVS Cost Center Configuration";
        Presses: JsonArray;
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
        Assert.IsTrue(PressNamed(Presses, 'PRESS-OPT', Press), 'The press is built');

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
        Press: JsonObject;
    begin
        TestData.AddPressConfig('PRESS-OFF', 'STD');
        Config.Get('PRESS-OFF', 'STD');
        Config.Validate("PEQI Use for Imposition", false);
        Config.Modify(false);

        Presses := CatalogMapper.BuildPresses();

        Assert.IsFalse(PressNamed(Presses, 'PRESS-OFF', Press), 'An unmarked configuration is not sent');
    end;

    [Test]
    procedure APressMarkedWithoutValidateIsRefused()
    var
        Config: Record "PVS Cost Center Configuration";
        Problems: List of [Text];
    begin
        // [GIVEN] a configuration marked by direct assignment, so no id was assigned
        TestData.AddPressConfig('PRESS-RAW', 'STD');
        Config.Get('PRESS-RAW', 'STD');
        Clear(Config."PEQI Press Id");
        Config.Modify(false);

        // [WHEN] the job is validated
        Validator.Validate(9901, 1, 1, Problems);

        // [THEN] it is refused rather than sent with an all-zero id
        Assert.IsTrue(ProblemsMention(Problems, 'PRESS-RAW'), 'A press with no id is named');

        // Deliberately invalid, so it must not outlive the test: it would fail every later validation.
        Config.Get('PRESS-RAW', 'STD');
        Config."PEQI Use for Imposition" := false;
        Config.Modify(false);
    end;

    [Test]
    procedure ACopiedPressIdIsRefusedAndReplacedWhenRemarked()
    var
        Original: Record "PVS Cost Center Configuration";
        Copy: Record "PVS Cost Center Configuration";
        Problems: List of [Text];
    begin
        // [GIVEN] a second configuration carrying the first one's id, as a copy would
        TestData.AddPressConfig('PRESS-ORIG', 'STD');
        TestData.AddPressConfig('PRESS-COPY', 'STD');
        Original.Get('PRESS-ORIG', 'STD');
        Copy.Get('PRESS-COPY', 'STD');
        Copy."PEQI Press Id" := Original."PEQI Press Id";
        Copy.Modify(false);

        // [WHEN] the job is validated
        Validator.Validate(9902, 1, 1, Problems);

        // [THEN] the shared id is refused
        Assert.IsTrue(ProblemsMention(Problems, 'PRESS-COPY'), 'A copied press id is named');

        // [WHEN] the copy is unmarked and marked again
        Copy.Validate("PEQI Use for Imposition", false);
        Copy.Validate("PEQI Use for Imposition", true);

        // [THEN] it has its own id, and the original's is untouched
        Assert.AreNotEqual(Original."PEQI Press Id", Copy."PEQI Press Id", 'Re-marking gives the copy its own id');

        // Deliberately invalid (the re-mark above is in memory only), so it must not outlive the test.
        Copy.Get('PRESS-COPY', 'STD');
        Copy."PEQI Use for Imposition" := false;
        Copy.Modify(false);
    end;

    [Test]
    procedure AnUnmarkedCopyDoesNotBlockTheOriginal()
    var
        Original: Record "PVS Cost Center Configuration";
        Copy: Record "PVS Cost Center Configuration";
        Problems: List of [Text];
    begin
        // [GIVEN] an unmarked configuration carrying a marked press's id
        TestData.AddPressConfig('PRESS-LIVE', 'STD');
        TestData.AddPressConfig('PRESS-STALE', 'STD');
        Original.Get('PRESS-LIVE', 'STD');
        Copy.Get('PRESS-STALE', 'STD');
        Copy."PEQI Press Id" := Original."PEQI Press Id";
        Copy."PEQI Use for Imposition" := false;
        Copy.Modify(false);

        // [WHEN] the job is validated
        Validator.Validate(9903, 1, 1, Problems);

        // [THEN] the live press is not reported -- an unmarked row is not sent, so it cannot clash
        Assert.IsFalse(ProblemsMention(Problems, 'PRESS-LIVE'), 'An unmarked copy does not block the press it was copied from');
    end;

    /// <summary>The press built for a cost center. PressName falls back to the cost-center code
    /// when the configuration has no Name, which is the case for every test configuration.</summary>
    local procedure PressNamed(Presses: JsonArray; CostCenterCode: Text; var Press: JsonObject): Boolean
    var
        Token: JsonToken;
        Index: Integer;
    begin
        for Index := 0 to Presses.Count() - 1 do begin
            Presses.Get(Index, Token);
            if JsonHelper.ReadText(Token.AsObject(), 'name') = CostCenterCode then begin
                Press := Token.AsObject();
                exit(true);
            end;
        end;
        exit(false);
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
}
