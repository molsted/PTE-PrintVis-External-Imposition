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
using PrintersEquity.ExternalImposition.Mapping;

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
        NoPressFormatMsg: Label 'Press %1 %2 is marked for imposition but its configuration has no maximum printing format.', Comment = '%1 cost centre, %2 configuration';
        NoPressIdMsg: Label 'Press %1 %2 is marked for imposition but has no press id. Untick and tick Use for Imposition to assign one.', Comment = '%1 cost centre, %2 configuration';
        SharedPressIdMsg: Label 'Press %1 %2 shares its press id with another configuration, probably because it was copied. Untick and tick Use for Imposition to give it its own.', Comment = '%1 cost centre, %2 configuration';
        NoGripperSideMsg: Label 'Press %1 %2 is marked for imposition but has no gripper edge side.', Comment = '%1 cost centre, %2 configuration';
        NoWorkStyleMsg: Label 'Press %1 %2 is marked for imposition but allows no work style.', Comment = '%1 cost centre, %2 configuration';

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

    procedure NoPressMessage(): Text
    begin
        exit(NoPressMsg);
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
