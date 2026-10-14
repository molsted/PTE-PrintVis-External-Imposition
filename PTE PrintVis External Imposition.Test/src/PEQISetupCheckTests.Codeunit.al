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
using PrintersEquity.ExternalImposition.Integration;
using PrintersEquity.ExternalImposition.Setup;
using System.Security.AccessControl;
using System.TestLibraries.Utilities;

codeunit 50623 "PEQI Setup Check Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestData: Codeunit "PEQI Test Data";
        Checks: Codeunit "PEQI Setup Checks";
        Queue: Codeunit "PEQI Test Transport Queue";

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

    [Test]
    procedure AComponentTypeNotSetUpIsAWarningThatOpensIt()
    var
        ComponentType: Record "PVS Component Types";
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        TestData.AddComponentType('SC-WARN', 'Unknown', "PEQI Component Grain Rule"::Any);
        ComponentType.Get('SC-WARN');

        Checks.Collect(Findings, false);

        Assert.IsTrue(FindFinding(Findings, "PEQI Setup Area"::ComponentTypes, "PEQI Finding Severity"::Warning, 'SC-WARN', ''), 'A component type not set up is a warning');
        Assert.AreEqual(Format(ComponentType.RecordId()), Format(Findings."Record Id"), 'The finding opens the component type');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AFixedComponentTypeDropsOutOnRecheck()
    var
        ComponentType: Record "PVS Component Types";
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        // [GIVEN] a component type with no grain rule, reported
        TestData.AddComponentType('SC-FIXME', 'Body', "PEQI Component Grain Rule"::NotSet);
        Checks.Collect(Findings, false);
        Assert.IsTrue(FindFinding(Findings, "PEQI Setup Area"::ComponentTypes, "PEQI Finding Severity"::Warning, 'SC-FIXME', ''), 'Reported before the fix');

        // [WHEN] the admin sets it, and the checks run again
        ComponentType.Get('SC-FIXME');
        ComponentType."PEQI Grain Rule" := ComponentType."PEQI Grain Rule"::Any;
        ComponentType.Modify(false);
        Checks.Collect(Findings, false);

        // [THEN] it is gone
        Assert.IsFalse(FindFinding(Findings, "PEQI Setup Area"::ComponentTypes, "PEQI Finding Severity"::Warning, 'SC-FIXME', ''), 'Gone after the fix');
    end;

    [Test]
    procedure AFinishingTypeNotSetUpIsAWarning()
    var
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        TestData.AddFinishingType('SC-FMISC', 'Misc.', 'Left');

        Checks.Collect(Findings, false);

        Assert.IsTrue(FindFinding(Findings, "PEQI Setup Area"::FinishingTypes, "PEQI Finding Severity"::Warning, 'SC-FMISC', ''), 'A finishing type not set up is a warning');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure NoMarkedPressIsBlocking()
    var
        Config: Record "PVS Cost Center Configuration";
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        Config.SetRange("PEQI Use for Imposition", true);
        Config.ModifyAll("PEQI Use for Imposition", false, false);

        Checks.Collect(Findings, false);

        Assert.IsTrue(FindFinding(Findings, "PEQI Setup Area"::Presses, "PEQI Finding Severity"::Blocking, 'Use for Imposition', ''), 'No marked press is blocking');
        Assert.IsTrue(Checks.HasBlocking(Findings), 'And so the findings block');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AMarkedPressWithoutAGripperSideIsBlocking()
    var
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        // AddPressConfig leaves the gripper side blank
        TestData.AddPressConfig('SC-NOGRIP', 'STD');

        Checks.Collect(Findings, false);

        Assert.IsTrue(FindFinding(Findings, "PEQI Setup Area"::Presses, "PEQI Finding Severity"::Blocking, 'SC-NOGRIP', 'gripper'), 'A missing gripper side is blocking');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AMarkedPressWithoutAWorkStyleIsBlocking()
    var
        Config: Record "PVS Cost Center Configuration";
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        TestData.AddPressConfig('SC-NOSTYLE', 'STD');
        Config.Get('SC-NOSTYLE', 'STD');
        Config."PEQI Gripper Edge Side" := Config."PEQI Gripper Edge Side"::Left;
        Config."PEQI Simplex" := false;
        Config."PEQI Work And Back" := false;
        Config.Modify(false);

        Checks.Collect(Findings, false);

        Assert.IsTrue(FindFinding(Findings, "PEQI Setup Area"::Presses, "PEQI Finding Severity"::Blocking, 'SC-NOSTYLE', 'work style'), 'No work style is blocking');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AMarkedPressWithoutAFormatIsBlocking()
    var
        Config: Record "PVS Cost Center Configuration";
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        TestData.AddPressConfig('SC-NOFMT2', 'STD');
        Config.Get('SC-NOFMT2', 'STD');
        Config."Max Printing Format Length" := 0;
        Config.Modify(false);

        Checks.Collect(Findings, false);

        Assert.IsTrue(FindFinding(Findings, "PEQI Setup Area"::Presses, "PEQI Finding Severity"::Blocking, 'SC-NOFMT2', 'printing format'), 'No PrintVis format is blocking');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ACopiedPressIdIsBlocking()
    var
        Original: Record "PVS Cost Center Configuration";
        Copy: Record "PVS Cost Center Configuration";
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        // [GIVEN] a marked configuration carrying another marked one's id, as a copy would
        TestData.AddPressConfig('SC-ORIG', 'STD');
        TestData.AddPressConfig('SC-COPY', 'STD');
        Original.Get('SC-ORIG', 'STD');
        Copy.Get('SC-COPY', 'STD');
        Copy."PEQI Press Id" := Original."PEQI Press Id";
        Copy.Modify(false);

        Checks.Collect(Findings, false);

        // [THEN] blocking in the guide, exactly as it is refused on a job
        Assert.IsTrue(FindFinding(Findings, "PEQI Setup Area"::Presses, "PEQI Finding Severity"::Blocking, 'SC-COPY', 'shares'), 'A copied press id is blocking');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ASetUpPressHasNoFinding()
    var
        Config: Record "PVS Cost Center Configuration";
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        TestData.AddPressConfig('SC-PRESSOK', 'STD');
        Config.Get('SC-PRESSOK', 'STD');
        Config."PEQI Gripper Edge Side" := Config."PEQI Gripper Edge Side"::Bottom;
        Config.Modify(false);

        Checks.Collect(Findings, false);

        Assert.IsFalse(FindFinding(Findings, "PEQI Setup Area"::Presses, "PEQI Finding Severity"::Blocking, 'SC-PRESSOK', ''), 'A press with format, id, gripper side and work styles is set up');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AMissingFormatUnitIsBlocking()
    var
        StandardUnit: Record "PVS Standard Units";
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        StandardUnit.SetRange(Type, StandardUnit.Type::Format);
        StandardUnit.DeleteAll(false);

        Checks.Collect(Findings, false);

        Assert.IsTrue(FindFinding(Findings, "PEQI Setup Area"::PaperAndUnits, "PEQI Finding Severity"::Blocking, 'Standard Units', ''), 'No format unit is blocking');
    end;

    [Test]
    procedure TheThicknessFindingFollowsTheDataFix()
    var
        Findings: Record "PEQI Setup Finding" temporary;
        ThicknessFix: Codeunit "PEQI Thickness Data Fix";
    begin
        // The fix decides which rows are wrong; the checks only report its count, as a warning.
        Checks.Collect(Findings, false);

        Assert.AreEqual(ThicknessFix.CountNeedingRestatement() > 0,
            FindFinding(Findings, "PEQI Setup Area"::PaperAndUnits, "PEQI Finding Severity"::Warning, 'thickness', ''),
            'A thickness warning appears exactly when the data fix has rows to restate');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure NobodyHoldingTheSetupPermissionIsAWarning()
    var
        AccessControl: Record "Access Control";
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        AccessControl.SetRange("Role ID", 'PEQI IMP. SETUP');
        AccessControl.DeleteAll(false);

        Checks.Collect(Findings, false);

        Assert.IsTrue(FindFinding(Findings, "PEQI Setup Area"::Permissions, "PEQI Finding Severity"::Warning, 'PEQI Imp. Setup', ''), 'Nobody holding the setup permission set is a warning');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AMissingEngineUrlIsBlocking()
    var
        Setup: Record "PEQI Imposition Setup";
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        Setup := Setup.GetSetup();
        Setup.Get('');
        Setup."Engine Base Url" := '';
        Setup.Modify(false);

        Checks.Collect(Findings, false);

        Assert.IsTrue(FindFinding(Findings, "PEQI Setup Area"::Connection, "PEQI Finding Severity"::Blocking, 'base URL', ''), 'No engine URL is blocking');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AMissingEditorUrlIsBlocking()
    var
        Setup: Record "PEQI Imposition Setup";
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        Setup := Setup.GetSetup();
        Setup.Get('');
        Setup."Spa Url" := '';
        Setup.Modify(false);

        Checks.Collect(Findings, false);

        Assert.IsTrue(FindFinding(Findings, "PEQI Setup Area"::Connection, "PEQI Finding Severity"::Blocking, 'editor URL', ''), 'No editor URL is blocking');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AnUnreachableEngineIsBlocking()
    var
        Setup: Record "PEQI Imposition Setup";
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        // [GIVEN] an engine URL at which nothing answers
        Setup := Setup.GetSetup();
        Setup.Get('');
        Setup."Engine Base Url" := 'https://engine.example.com/api';
        Setup.Modify(false);
        Queue.Reset();
        Queue.QueueTransportFailure();
        Checks.SetTransport("PEQI Transport Type"::Test);

        // [WHEN] the checks run live
        Checks.Collect(Findings, true);

        // [THEN] one call was made, and the failure is blocking with its reason
        Assert.AreEqual(1, Queue.CallCount(), 'One connection test');
        Assert.IsTrue(FindFinding(Findings, "PEQI Setup Area"::Connection, "PEQI Finding Severity"::Blocking, 'could not be reached', ''), 'An unreachable engine is blocking, with the reason');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ChecksThatAreNotLiveCallNothing()
    var
        Setup: Record "PEQI Imposition Setup";
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        Setup := Setup.GetSetup();
        Setup.Get('');
        Setup."Engine Base Url" := 'https://engine.example.com/api';
        Setup.Modify(false);
        Queue.Reset();
        Checks.SetTransport("PEQI Transport Type"::Test);

        Checks.Collect(Findings, false);

        Assert.AreEqual(0, Queue.CallCount(), 'Nothing is sent when the checks are not live');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AnAnsweringEngineHasNoConnectionFinding()
    var
        Setup: Record "PEQI Imposition Setup";
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        // [GIVEN] both URLs set, and an engine that answers with a list of part types
        Setup := Setup.GetSetup();
        Setup.Get('');
        Setup."Engine Base Url" := 'https://engine.example.com/api';
        Setup."Spa Url" := 'https://engine.example.com';
        Setup.Modify(false);
        Queue.Reset();
        Queue.QueueResponse(200, '[]');
        Checks.SetTransport("PEQI Transport Type"::Test);

        // [WHEN] the checks run live
        Checks.Collect(Findings, true);

        // [THEN] the connection has nothing to report
        Assert.AreEqual(0, Checks.AreaCount(Findings, "PEQI Setup Area"::Connection), 'An answering engine is no finding');
    end;

    [Test]
    procedure AThicknessCountSetByTheCallerIsUsedInPlaceOfAScan()
    var
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        // [GIVEN] a caller that has counted the paper once and says seven are wrong
        Checks.SetThicknessCount(7);

        // [WHEN] the checks run
        Checks.Collect(Findings, false);

        // [THEN] the warning carries that count, not a fresh scan's
        Assert.IsTrue(FindFinding(Findings, "PEQI Setup Area"::PaperAndUnits, "PEQI Finding Severity"::Warning, '7 paper items', ''), 'The stored count is reported');
    end;

    /// <summary>Positions Findings on the first finding in that area and severity whose text holds
    /// both needles (the second may be blank). True when there is one.</summary>
    local procedure FindFinding(var Findings: Record "PEQI Setup Finding" temporary; SetupArea: Enum "PEQI Setup Area"; Severity: Enum "PEQI Finding Severity"; Needle: Text; Needle2: Text): Boolean
    begin
        Findings.Reset();
        Findings.SetRange("Setup Area", SetupArea);
        Findings.SetRange(Severity, Severity);
        if Findings.FindSet() then
            repeat
                if (StrPos(Findings.Description, Needle) > 0) and ((Needle2 = '') or (StrPos(Findings.Description, Needle2) > 0)) then
                    exit(true);
            until Findings.Next() = 0;
        exit(false);
    end;
}
