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
using PrintersEquity.ExternalImposition.Setup;
using System.TestLibraries.Utilities;

codeunit 50623 "PEQI Setup Check Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestData: Codeunit "PEQI Test Data";
        Checks: Codeunit "PEQI Setup Checks";

    [Test]
    procedure AnUnknownProductTypeIsAProblem()
    var
        ComponentType: Record "PVS Component Types";
        Problems: List of [Text];
    begin
        TestData.AddComponentType('SC-NOTYPE', 'Unknown', "PEQI Component Grain Rule"::Any);
        ComponentType.Get('SC-NOTYPE');

        Checks.ComponentTypeProblems(ComponentType, Problems);

        Assert.AreEqual(1, Problems.Count(), 'One problem: the product type');
        Assert.IsTrue(StrPos(Problems.Get(1), 'SC-NOTYPE') > 0, 'The component type is named');
        Assert.IsTrue(StrPos(Problems.Get(1), 'JDF Product Type') > 0, 'The field is named');
    end;

    [Test]
    procedure AGrainRuleNotSetIsAProblem()
    var
        ComponentType: Record "PVS Component Types";
        Problems: List of [Text];
    begin
        TestData.AddComponentType('SC-NOGRAIN', 'Body', "PEQI Component Grain Rule"::NotSet);
        ComponentType.Get('SC-NOGRAIN');

        Checks.ComponentTypeProblems(ComponentType, Problems);

        Assert.AreEqual(1, Problems.Count(), 'One problem: the grain rule');
        Assert.IsTrue(StrPos(Problems.Get(1), 'grain rule') > 0, 'The grain rule is named');
    end;

    [Test]
    procedure ASetUpComponentTypeHasNoProblems()
    var
        ComponentType: Record "PVS Component Types";
        Problems: List of [Text];
    begin
        TestData.AddComponentType('SC-READY', 'Body', "PEQI Component Grain Rule"::ParallelToSpine);
        ComponentType.Get('SC-READY');

        Checks.ComponentTypeProblems(ComponentType, Problems);

        Assert.AreEqual(0, Problems.Count(), 'A component type with both fields set has no problems');
    end;

    [Test]
    procedure AnUnsetCip4BindingIsAProblem()
    var
        FinishingType: Record "PVS Finishing Types";
        Problems: List of [Text];
    begin
        TestData.AddFinishingType('SC-MISC', 'Misc.', 'Left');
        FinishingType.Get('SC-MISC');

        Checks.FinishingTypeProblems(FinishingType, false, Problems);

        Assert.AreEqual(1, Problems.Count(), 'Misc. is a problem');
        Assert.IsTrue(StrPos(Problems.Get(1), 'SC-MISC') > 0, 'The finishing type is named');
    end;

    [Test]
    procedure ABottomSideIsAProblemUnlessSomethingOverridesIt()
    var
        FinishingType: Record "PVS Finishing Types";
        Problems: List of [Text];
    begin
        TestData.AddFinishingType('SC-FOOT', 'SaddleStitch', 'Bottom');
        FinishingType.Get('SC-FOOT');

        Checks.FinishingTypeProblems(FinishingType, false, Problems);
        Assert.AreEqual(1, Problems.Count(), 'A bottom side is a problem on its own');
        Assert.IsTrue(StrPos(Problems.Get(1), 'bottom') > 0, 'The problem says bottom');

        Clear(Problems);
        Checks.FinishingTypeProblems(FinishingType, true, Problems);
        Assert.AreEqual(0, Problems.Count(), 'A bottom side that is overridden is no problem');
    end;

    [Test]
    procedure ASetUpFinishingTypeHasNoProblems()
    var
        FinishingType: Record "PVS Finishing Types";
        Problems: List of [Text];
    begin
        TestData.AddFinishingType('SC-SADDLE', 'SaddleStitch', 'Left');
        FinishingType.Get('SC-SADDLE');

        Checks.FinishingTypeProblems(FinishingType, false, Problems);

        Assert.AreEqual(0, Problems.Count(), 'Saddle stitch on the left is set up');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PressSetupGapsNameTheGripperSideAndTheWorkStyles()
    var
        Config: Record "PVS Cost Center Configuration";
        Problems: List of [Text];
    begin
        // [GIVEN] a marked press with no gripper side and no work style
        TestData.AddPressConfig('SC-GAPS', 'STD');
        Config.Get('SC-GAPS', 'STD');
        Config."PEQI Simplex" := false;
        Config."PEQI Work And Back" := false;
        Config.Modify(false);

        Checks.PressSetupGaps(Config, Problems);
        Assert.AreEqual(2, Problems.Count(), 'Both gaps are reported');
        Assert.IsTrue(StrPos(Checks.JoinProblems(Problems), 'gripper') > 0, 'The gripper side is named');
        Assert.IsTrue(StrPos(Checks.JoinProblems(Problems), 'work style') > 0, 'The work styles are named');

        // [WHEN] both are filled in
        Config."PEQI Gripper Edge Side" := Config."PEQI Gripper Edge Side"::Left;
        Config."PEQI Simplex" := true;
        Clear(Problems);
        Checks.PressSetupGaps(Config, Problems);

        // [THEN] nothing is left
        Assert.AreEqual(0, Problems.Count(), 'A press with a gripper side and a work style has no gaps');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PressProblemsNameAMissingFormat()
    var
        Config: Record "PVS Cost Center Configuration";
        Problems: List of [Text];
    begin
        TestData.AddPressConfig('SC-NOFMT', 'STD');
        Config.Get('SC-NOFMT', 'STD');
        Config."Max Printing Format Width" := 0;
        Config.Modify(false);

        Checks.PressProblems(Config, Problems);

        Assert.AreEqual(1, Problems.Count(), 'The missing format is the one problem');
        Assert.IsTrue(StrPos(Problems.Get(1), 'SC-NOFMT') > 0, 'The press is named');
    end;

    [Test]
    procedure FindingsAreCountedBySeverityAndArea()
    var
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        Checks.AddFinding(Findings, "PEQI Setup Area"::ComponentTypes, "PEQI Finding Severity"::Warning, 'A');
        Assert.IsFalse(Checks.HasBlocking(Findings), 'A warning is not blocking');

        Checks.AddFinding(Findings, "PEQI Setup Area"::Presses, "PEQI Finding Severity"::Blocking, 'B');
        Checks.AddFinding(Findings, "PEQI Setup Area"::Presses, "PEQI Finding Severity"::Blocking, 'C');

        Assert.IsTrue(Checks.HasBlocking(Findings), 'A blocking finding is blocking');
        Assert.AreEqual(2, Checks.AreaCount(Findings, "PEQI Setup Area"::Presses), 'Two findings on presses');
        Assert.AreEqual(1, Checks.SeverityCount(Findings, "PEQI Finding Severity"::Warning), 'One warning');
        Assert.AreEqual(3, Findings.Count(), 'Each finding is its own row');
    end;

    [Test]
    procedure JoinProblemsIsBlankForNone()
    var
        Problems: List of [Text];
    begin
        Assert.AreEqual('', Checks.JoinProblems(Problems), 'No problems join to blank');
        Problems.Add('One.');
        Problems.Add('Two.');
        Assert.AreEqual('One. Two.', Checks.JoinProblems(Problems), 'Problems are joined with a space');
    end;
}
