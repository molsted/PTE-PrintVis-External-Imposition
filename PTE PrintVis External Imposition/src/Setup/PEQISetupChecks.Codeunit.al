// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Setup;

using PrintersEquity.ExternalImposition.Enums;
using PrintersEquity.ExternalImposition.Integration;
using PrintersEquity.ExternalImposition.Mapping;
using System.Security.AccessControl;

/// <summary>Every question about whether imposition is set up, asked in one place.</summary>
/// <remarks>
/// <para>
/// The setup guide asks them of every row; the per-job validator asks the single-record ones of
/// the rows a job uses. Both go through the procedures here, so the guide and a job never
/// disagree about the same component type, finishing type or press.
/// </para>
/// <para>
/// <see cref="PressSetupGaps"/> is the exception, and on purpose: the engine solves a press with
/// no gripper side and derives work styles when none are sent, so a job is not refused for
/// either -- that would refuse jobs that solve today. The guide still counts them as blocking,
/// because a press without them is not set up.
/// </para>
/// </remarks>
codeunit 50566 "PEQI Setup Checks"
{
    var
        EnumNames: Codeunit "PEQI Enum Names";
        NoProductTypeMsg: Label 'Component type %1 has no JDF Product Type.', Comment = '%1 component type';
        GrainNotSetMsg: Label 'Component type %1 has no imposition grain rule.', Comment = '%1 component type';
        BottomBindingMsg: Label 'Finishing type %1 is bound at the bottom edge, which the engine does not impose. It binds left, right or top.', Comment = '%1 finishing code';
        NoPressMsg: Label 'No cost center configuration is marked Use for Imposition.';
        NoPressFormatMsg: Label 'Press %1 (configuration %2) is marked for imposition but has no maximum printing format in PrintVis.', Comment = '%1 cost centre, %2 configuration';
        NoPressIdMsg: Label 'Press %1 (configuration %2) is marked for imposition but has no press id. Untick and tick Use for Imposition to assign one.', Comment = '%1 cost centre, %2 configuration';
        SharedPressIdMsg: Label 'Press %1 (configuration %2) shares its press id with another configuration, probably because it was copied. Untick and tick Use for Imposition to give it its own.', Comment = '%1 cost centre, %2 configuration';
        NoGripperSideMsg: Label 'Press %1 (configuration %2) is marked for imposition but has no gripper edge side.', Comment = '%1 cost centre, %2 configuration';
        NoWorkStyleMsg: Label 'Press %1 (configuration %2) is marked for imposition but allows no work style.', Comment = '%1 cost centre, %2 configuration';
        TransportType: Enum "PEQI Transport Type";
        NoEngineUrlMsg: Label 'The engine base URL is not set, so no job can be solved.';
        NoEditorUrlMsg: Label 'The editor URL is not set, so no job can show the editor.';
        UnreachableMsg: Label 'The connection test failed. %1', Comment = '%1 the reason';
        NoStandardUnitMsg: Label 'PrintVis has no Format row with a blank code in Standard Units, so no length can be converted.';
        ThicknessMsg: Label '%1 paper items record a thickness in a different unit from the one PrintVis states. Check and restate them on the Paper and Units step.', Comment = '%1 count';
        NoAdminMsg: Label 'Nobody holds the PEQI Imp. Setup permission set, so nobody can open the full editor or change the imposition setup. Users with SUPER are not counted.';
        CannotReadPermissionsMsg: Label 'You cannot read who holds which permission sets, so whether anyone holds PEQI Imp. Setup could not be checked.';
        AdminRoleTok: Label 'PEQI IMP. SETUP', Locked = true;
        ThicknessCount: Integer;
        ThicknessCountKnown: Boolean;

    /// <summary>What stops a component type being imposed; nothing added when nothing does.</summary>
    procedure ComponentTypeProblems(ComponentType: Record "PVS Component Types"; var Problems: List of [Text])
    begin
        if EnumNames.OptionMemberName(ComponentType, ComponentType.FieldNo("JDF Product Type")) = 'Unknown' then
            Problems.Add(StrSubstNo(NoProductTypeMsg, ComponentType.Code));
        if ComponentType."PEQI Grain Rule" = ComponentType."PEQI Grain Rule"::NotSet then
            Problems.Add(StrSubstNo(GrainNotSetMsg, ComponentType.Code));
    end;

    /// <summary>What stops a finishing type binding a job; nothing added when nothing does.</summary>
    /// <remarks>
    /// A bottom side is a problem only where nothing overrides it. A job whose imposition code
    /// states a spine side never reads the finishing type's, so the validator passes
    /// SideOverridden for such a job; the guide, which asks of no job in particular, passes false.
    /// </remarks>
    procedure FinishingTypeProblems(FinishingType: Record "PVS Finishing Types"; SideOverridden: Boolean; var Problems: List of [Text])
    var
        Cip4Problem: Text;
    begin
        Cip4Problem := EnumNames.Cip4BindingProblem(
            EnumNames.OptionMemberName(FinishingType, FinishingType.FieldNo("CIP4 Binding")), FinishingType.Code);
        if Cip4Problem <> '' then
            Problems.Add(Cip4Problem);
        if not SideOverridden then
            if EnumNames.OptionMemberName(FinishingType, FinishingType.FieldNo("CIP4 BindingSide")) = 'Bottom' then
                Problems.Add(StrSubstNo(BottomBindingMsg, FinishingType.Code));
    end;

    /// <summary>What stops a marked configuration being sent as a press.</summary>
    procedure PressProblems(Config: Record "PVS Cost Center Configuration"; var Problems: List of [Text])
    begin
        if (Config."Max Printing Format Width" <= 0) or (Config."Max Printing Format Length" <= 0) then
            Problems.Add(StrSubstNo(NoPressFormatMsg, Config."Cost Center Code", Config.Configuration));
        if IsNullGuid(Config."PEQI Press Id") then
            Problems.Add(StrSubstNo(NoPressIdMsg, Config."Cost Center Code", Config.Configuration))
        else
            if Config.PEQIPressIdHeldByAnother(true) then
                Problems.Add(StrSubstNo(SharedPressIdMsg, Config."Cost Center Code", Config.Configuration));
    end;

    /// <summary>What a marked press lacks that the engine tolerates but the guide does not accept
    /// as set up. Not asked by the validator -- see the codeunit's remarks.</summary>
    procedure PressSetupGaps(Config: Record "PVS Cost Center Configuration"; var Problems: List of [Text])
    begin
        if Config."PEQI Gripper Edge Side" = Config."PEQI Gripper Edge Side"::" " then
            Problems.Add(StrSubstNo(NoGripperSideMsg, Config."Cost Center Code", Config.Configuration));
        if Config.PEQIWorkStyleList().Count() = 0 then
            Problems.Add(StrSubstNo(NoWorkStyleMsg, Config."Cost Center Code", Config.Configuration));
    end;

    /// <summary>Every problem that stops the marked presses being sent: none marked, or each
    /// marked press's own.</summary>
    procedure MarkedPressProblems(var Problems: List of [Text])
    var
        Config: Record "PVS Cost Center Configuration";
    begin
        Config.SetRange("PEQI Use for Imposition", true);
        if not Config.FindSet() then begin
            Problems.Add(NoPressMsg);
            exit;
        end;
        repeat
            PressProblems(Config, Problems);
        until Config.Next() = 0;
    end;

    /// <summary>Every finding, in place of whatever Findings held. Live adds the engine
    /// connection test; without it nothing is sent over the network.</summary>
    procedure Collect(var Findings: Record "PEQI Setup Finding" temporary; Live: Boolean)
    begin
        Findings.Reset();
        Findings.DeleteAll();
        CheckConnection(Findings, Live);
        CheckComponentTypes(Findings);
        CheckFinishingTypes(Findings);
        CheckPresses(Findings);
        CheckPaperAndUnits(Findings);
        CheckPermissions(Findings);
    end;

    /// <summary>The finding for an engine that did not answer. Public so a guide that tested the
    /// connection once can keep the result without testing it on every step.</summary>
    procedure AddUnreachable(var Findings: Record "PEQI Setup Finding" temporary; Detail: Text)
    begin
        AddFinding(Findings, "PEQI Setup Area"::Connection, "PEQI Finding Severity"::Blocking, StrSubstNo(UnreachableMsg, Detail));
    end;

    procedure SetTransport(NewTransportType: Enum "PEQI Transport Type")
    begin
        TransportType := NewTransportType;
    end;

    /// <summary>Keeps a count of paper items with a wrongly stated thickness, so Collect does not
    /// scan the item master again on every call.</summary>
    /// <remarks>
    /// The guide collects on opening and on every step, and counting reads every paper item. The
    /// caller that wants it cached counts once, sets the count here, and sets it again after it
    /// changes the items. Without it Collect counts afresh, as before.
    /// </remarks>
    procedure SetThicknessCount(Wrong: Integer)
    begin
        ThicknessCount := Wrong;
        ThicknessCountKnown := true;
    end;

    local procedure CheckConnection(var Findings: Record "PEQI Setup Finding" temporary; Live: Boolean)
    var
        Setup: Record "PEQI Imposition Setup";
        Client: Codeunit "PEQI Engine Client";
        Detail: Text;
    begin
        Setup := Setup.GetSetup();
        if Setup."Engine Base Url" = '' then
            AddFinding(Findings, "PEQI Setup Area"::Connection, "PEQI Finding Severity"::Blocking, NoEngineUrlMsg)
        else
            if Live then begin
                Client.SetTransport(TransportType);
                if not Client.TestConnection(Detail) then
                    AddUnreachable(Findings, Detail);
            end;
        if Setup."Spa Url" = '' then
            AddFinding(Findings, "PEQI Setup Area"::Connection, "PEQI Finding Severity"::Blocking, NoEditorUrlMsg);
    end;

    local procedure CheckComponentTypes(var Findings: Record "PEQI Setup Finding" temporary)
    var
        ComponentType: Record "PVS Component Types";
        Problems: List of [Text];
        Problem: Text;
    begin
        if ComponentType.FindSet() then
            repeat
                Clear(Problems);
                ComponentTypeProblems(ComponentType, Problems);
                foreach Problem in Problems do
                    AddFinding(Findings, "PEQI Setup Area"::ComponentTypes, "PEQI Finding Severity"::Warning, Problem, ComponentType.RecordId());
            until ComponentType.Next() = 0;
    end;

    local procedure CheckFinishingTypes(var Findings: Record "PEQI Setup Finding" temporary)
    var
        FinishingType: Record "PVS Finishing Types";
        Problems: List of [Text];
        Problem: Text;
    begin
        if FinishingType.FindSet() then
            repeat
                Clear(Problems);
                FinishingTypeProblems(FinishingType, false, Problems);
                foreach Problem in Problems do
                    AddFinding(Findings, "PEQI Setup Area"::FinishingTypes, "PEQI Finding Severity"::Warning, Problem, FinishingType.RecordId());
            until FinishingType.Next() = 0;
    end;

    local procedure CheckPresses(var Findings: Record "PEQI Setup Finding" temporary)
    var
        Config: Record "PVS Cost Center Configuration";
        Problems: List of [Text];
        Problem: Text;
    begin
        Config.SetRange("PEQI Use for Imposition", true);
        if not Config.FindSet() then begin
            AddFinding(Findings, "PEQI Setup Area"::Presses, "PEQI Finding Severity"::Blocking, NoPressMsg);
            exit;
        end;
        repeat
            Clear(Problems);
            PressProblems(Config, Problems);
            PressSetupGaps(Config, Problems);
            foreach Problem in Problems do
                AddFinding(Findings, "PEQI Setup Area"::Presses, "PEQI Finding Severity"::Blocking, Problem, Config.RecordId());
        until Config.Next() = 0;
    end;

    local procedure CheckPaperAndUnits(var Findings: Record "PEQI Setup Finding" temporary)
    var
        StandardUnit: Record "PVS Standard Units";
        ThicknessFix: Codeunit "PEQI Thickness Data Fix";
        Wrong: Integer;
    begin
        // PrintVis converts formats, and margins too, through the Format row with a blank code.
        if not StandardUnit.Get(StandardUnit.Type::Format, '') then
            AddFinding(Findings, "PEQI Setup Area"::PaperAndUnits, "PEQI Finding Severity"::Blocking, NoStandardUnitMsg);

        if ThicknessCountKnown then
            Wrong := ThicknessCount
        else
            Wrong := ThicknessFix.CountNeedingRestatement();
        if Wrong > 0 then
            AddFinding(Findings, "PEQI Setup Area"::PaperAndUnits, "PEQI Finding Severity"::Warning, StrSubstNo(ThicknessMsg, Wrong));
    end;

    /// <summary>Whether anyone holds PEQI Imp. Setup. An admin who may not read Access Control gets
    /// a warning saying so, not a pass: the guide must not fail on a question it cannot ask, and
    /// must not say "all set" for one it did not.</summary>
    local procedure CheckPermissions(var Findings: Record "PEQI Setup Finding" temporary)
    var
        AccessControl: Record "Access Control";
    begin
        if not AccessControl.ReadPermission() then begin
            AddFinding(Findings, "PEQI Setup Area"::Permissions, "PEQI Finding Severity"::Warning, CannotReadPermissionsMsg);
            exit;
        end;
        AccessControl.SetRange("Role ID", AdminRoleTok);
        if AccessControl.IsEmpty() then
            AddFinding(Findings, "PEQI Setup Area"::Permissions, "PEQI Finding Severity"::Warning, NoAdminMsg);
    end;

    /// <summary>The problems as one line, for a column; blank when there are none.</summary>
    procedure JoinProblems(Problems: List of [Text]) Joined: Text
    var
        Problem: Text;
    begin
        foreach Problem in Problems do
            if Joined = '' then
                Joined := Problem
            else
                Joined += ' ' + Problem;
    end;

    procedure AddFinding(var Findings: Record "PEQI Setup Finding" temporary; SetupArea: Enum "PEQI Setup Area"; Severity: Enum "PEQI Finding Severity"; Description: Text)
    var
        NoRecord: RecordId;
    begin
        AddFinding(Findings, SetupArea, Severity, Description, NoRecord);
    end;

    procedure AddFinding(var Findings: Record "PEQI Setup Finding" temporary; SetupArea: Enum "PEQI Setup Area"; Severity: Enum "PEQI Finding Severity"; Description: Text; RecId: RecordId)
    var
        Last: Record "PEQI Setup Finding" temporary;
        EntryNo: Integer;
    begin
        Last.Copy(Findings, true);
        Last.Reset();
        if Last.FindLast() then
            EntryNo := Last."Entry No.";
        Findings.Init();
        Findings."Entry No." := EntryNo + 1;
        Findings."Setup Area" := SetupArea;
        Findings.Severity := Severity;
        Findings.Description := CopyStr(Description, 1, MaxStrLen(Findings.Description));
        Findings."Record Id" := RecId;
        Findings.Insert();
    end;

    procedure HasBlocking(var Findings: Record "PEQI Setup Finding" temporary): Boolean
    begin
        exit(SeverityCount(Findings, "PEQI Finding Severity"::Blocking) > 0);
    end;

    procedure AreaCount(var Findings: Record "PEQI Setup Finding" temporary; SetupArea: Enum "PEQI Setup Area"): Integer
    var
        Probe: Record "PEQI Setup Finding" temporary;
    begin
        Probe.Copy(Findings, true);
        Probe.Reset();
        Probe.SetRange("Setup Area", SetupArea);
        exit(Probe.Count());
    end;

    procedure SeverityCount(var Findings: Record "PEQI Setup Finding" temporary; Severity: Enum "PEQI Finding Severity"): Integer
    var
        Probe: Record "PEQI Setup Finding" temporary;
    begin
        Probe.Copy(Findings, true);
        Probe.Reset();
        Probe.SetRange(Severity, Severity);
        exit(Probe.Count());
    end;
}
