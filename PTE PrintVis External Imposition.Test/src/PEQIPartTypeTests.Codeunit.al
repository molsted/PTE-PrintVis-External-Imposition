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

codeunit 50619 "PEQI Part Type Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestData: Codeunit "PEQI Test Data";
        PartMapper: Codeunit "PEQI Part Mapper";
        Validator: Codeunit "PEQI Request Validator";
        EnumNames: Codeunit "PEQI Enum Names";
        JsonHelper: Codeunit "PEQI Json Helper";

    [Test]
    procedure TheProductTypeIsTheJdfProductTypeByName()
    var
        Parts: JsonArray;
        Token: JsonToken;
    begin
        // [GIVEN] a component type PrintVis records as a WrapAroundCover
        TestData.AddPaperItem('PAPER-A', 'Paper A');
        TestData.AddComponentType('WRAP', 'WrapAroundCover', "PEQI Component Grain Rule"::ParallelToSpine);
        TestData.AddJobItem(9001, 1, 1, 1, 'WRAP', 4, 430, 297, 'PAPER-A');

        // [WHEN] the parts are built
        Parts := PartMapper.BuildParts(9001, 1, 1);
        Parts.Get(0, Token);

        // [THEN] the name is sent as PrintVis records it -- the engine's vocabulary is CIP4's too
        Assert.AreEqual('WrapAroundCover', JsonHelper.ReadText(Token.AsObject(), 'productType'), 'The JDF Product Type is sent by name');
    end;

    [Test]
    procedure AnOptionIsReadByMemberNameNotCaption()
    var
        ComponentType: Record "PVS Component Types";
    begin
        // [GIVEN] a component type recorded as Body
        TestData.AddComponentType('BODY-N', 'Body', "PEQI Component Grain Rule"::Any);
        ComponentType.Get('BODY-N');

        // [THEN] the member name comes back, whatever language the session is in
        Assert.AreEqual('Body', EnumNames.OptionMemberName(ComponentType, ComponentType.FieldNo("JDF Product Type")), 'The member name, not a caption');
    end;

    [Test]
    procedure AnUnknownProductTypeIsRefused()
    var
        Problems: List of [Text];
    begin
        // [GIVEN] a component type with no JDF Product Type set
        TestData.AddPaperItem('PAPER-A', 'Paper A');
        TestData.AddComponentType('BLANK', 'Unknown', "PEQI Component Grain Rule"::ParallelToSpine);
        TestData.AddJobItem(9002, 1, 1, 1, 'BLANK', 16, 210, 297, 'PAPER-A');

        // [WHEN] the job is validated
        Validator.Validate(9002, 1, 1, Problems);

        // [THEN] it is refused naming the component type
        Assert.IsTrue(ProblemsMention(Problems, 'BLANK'), 'The component type is named');
    end;

    [Test]
    procedure AComponentTypeWithNoRowIsRefused()
    var
        Problems: List of [Text];
    begin
        // [GIVEN] a job item whose component type has no PVS Component Types row
        TestData.AddPaperItem('PAPER-A', 'Paper A');
        TestData.AddJobItem(9003, 1, 1, 1, 'NOWHERE', 16, 210, 297, 'PAPER-A');

        // [WHEN] the job is validated
        Validator.Validate(9003, 1, 1, Problems);

        // [THEN] it is refused like Unknown, naming it
        Assert.IsTrue(ProblemsMention(Problems, 'NOWHERE'), 'A missing component type is named');
    end;

    [Test]
    procedure AGrainRuleNotSetIsRefused()
    var
        Problems: List of [Text];
    begin
        // [GIVEN] a component type whose grain rule nobody has chosen
        TestData.AddPaperItem('PAPER-A', 'Paper A');
        TestData.AddComponentType('UNSET', 'Body', "PEQI Component Grain Rule"::NotSet);
        TestData.AddJobItem(9004, 1, 1, 1, 'UNSET', 16, 210, 297, 'PAPER-A');

        // [WHEN] the job is validated
        Validator.Validate(9004, 1, 1, Problems);

        // [THEN] it is refused rather than imposed with grain silently unenforced
        Assert.IsTrue(ProblemsMention(Problems, 'UNSET'), 'The component type is named');
    end;

    [Test]
    procedure TheGrainRuleComesFromTheComponentType()
    var
        Parts: JsonArray;
        Token: JsonToken;
    begin
        TestData.AddPaperItem('PAPER-A', 'Paper A');
        TestData.AddComponentType('FREE', 'Body', "PEQI Component Grain Rule"::Any);
        TestData.AddJobItem(9005, 1, 1, 1, 'FREE', 16, 210, 297, 'PAPER-A');

        Parts := PartMapper.BuildParts(9005, 1, 1);
        Parts.Get(0, Token);

        // [THEN] Any is the engine's Free
        Assert.AreEqual('Free', JsonHelper.ReadText(Token.AsObject(), 'grainRule'), 'Any is sent as Free');
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
