// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Mapping;

using Microsoft.Inventory.Item;
using PrintersEquity.ExternalImposition.Enums;
using PrintersEquity.ExternalImposition.Setup;

codeunit 50538 "PEQI Request Validator"
{
    var
        NoBindingMsg: Label 'Finishing code %1 has no imposition binding mapping.', Comment = '%1 finishing code';
        NoFinishingMsg: Label 'Job %1/%2/%3 has no finishing code on the job or on any of its sheets.', Comment = '%1 case, %2 job, %3 version';
        MixedFinishingMsg: Label 'The sheets of job %1/%2/%3 have different finishing codes (%4). Set the finishing on the job to choose one binding.', Comment = '%1 case, %2 job, %3 version, %4 comma-separated finishing codes';
        NoComponentTypeMsg: Label 'Component type %1 does not exist in PrintVis.', Comment = '%1 component type';
        NoProductTypeMsg: Label 'Component type %1 has no JDF Product Type.', Comment = '%1 component type';
        GrainNotSetMsg: Label 'Component type %1 has no imposition grain rule.', Comment = '%1 component type';
        NoSheetMsg: Label 'Job item %1 of component %2 has no sheet in PrintVis.', Comment = '%1 job item no., %2 component';
        NoSheetPaperMsg: Label 'Sheet %1 of component %2 has no paper item.', Comment = '%1 sheet id, %2 component';
        MissingPaperItemMsg: Label 'Sheet %1 of component %2 names paper item %3, which does not exist.', Comment = '%1 sheet id, %2 component, %3 item no.';
        NoSheetFormatMsg: Label 'Sheet %1 of component %2 has no printing format (Length x Width).', Comment = '%1 sheet id, %2 component';
        NoPressMsg: Label 'No cost center configuration is marked Use for Imposition.', Locked = false;
        NoPressFormatMsg: Label 'Press %1 %2 is marked for imposition but its configuration has no maximum printing format.', Comment = '%1 cost centre, %2 configuration';
        NoPressIdMsg: Label 'Press %1 %2 is marked for imposition but has no press id. Untick and tick Use for Imposition to assign one.', Comment = '%1 cost centre, %2 configuration';
        SharedPressIdMsg: Label 'Press %1 %2 shares its press id with another configuration, probably because it was copied. Untick and tick Use for Imposition to give it its own.', Comment = '%1 cost centre, %2 configuration';

    /// <summary>Collects every problem rather than stopping at the first, so an
    /// operator fixes them in one visit. True when the request may be built.</summary>
    procedure Validate(CaseId: Integer; JobNo: Integer; VersionNo: Integer; var Problems: List of [Text]): Boolean
    begin
        Clear(Problems);
        ValidateJob(CaseId, JobNo, VersionNo, Problems);
        ValidateComponents(CaseId, JobNo, VersionNo, Problems);
        ValidatePresses(Problems);
        exit(Problems.Count() = 0);
    end;

    local procedure ValidateJob(CaseId: Integer; JobNo: Integer; VersionNo: Integer; var Problems: List of [Text])
    var
        PVSJob: Record "PVS Job";
        BindingMapping: Record "PEQI Binding Mapping";
        FinishingCode: Code[20];
        Problem: Text;
    begin
        if not PVSJob.Get(CaseId, JobNo, VersionNo) then
            exit;
        if not ResolveFinishing(CaseId, JobNo, VersionNo, FinishingCode, Problem) then
            Problems.Add(Problem)
        else
            if not BindingMapping.Get(FinishingCode) then
                Problems.Add(StrSubstNo(NoBindingMsg, FinishingCode));
    end;

    /// <summary>The finishing code that decides the binding. PrintVis holds it on the
    /// job, or, when the job leaves it blank, on each of the job's sheets. False, with
    /// the reason in Problem, when no sheet names one or the sheets disagree.</summary>
    procedure ResolveFinishing(CaseId: Integer; JobNo: Integer; VersionNo: Integer; var FinishingCode: Code[20]; var Problem: Text): Boolean
    var
        PVSJob: Record "PVS Job";
        JobSheet: Record "PVS Job Sheet";
        Codes: List of [Code[20]];
    begin
        Clear(FinishingCode);
        Clear(Problem);
        if PVSJob.Get(CaseId, JobNo, VersionNo) and (PVSJob.Finishing <> '') then begin
            FinishingCode := PVSJob.Finishing;
            exit(true);
        end;

        JobSheet.SetRange(ID, CaseId);
        JobSheet.SetRange(Job, JobNo);
        JobSheet.SetRange(Version, VersionNo);
        JobSheet.SetFilter(Finishing, '<>%1', '');
        if JobSheet.FindSet() then
            repeat
                if not Codes.Contains(JobSheet.Finishing) then
                    Codes.Add(JobSheet.Finishing);
            until JobSheet.Next() = 0;

        case Codes.Count() of
            0:
                Problem := StrSubstNo(NoFinishingMsg, CaseId, JobNo, VersionNo);
            1:
                FinishingCode := Codes.Get(1);
            else
                Problem := StrSubstNo(MixedFinishingMsg, CaseId, JobNo, VersionNo, JoinCodes(Codes));
        end;
        exit(Problem = '');
    end;

    local procedure JoinCodes(Codes: List of [Code[20]]) Joined: Text
    var
        FinishingCode: Code[20];
    begin
        foreach FinishingCode in Codes do
            if Joined = '' then
                Joined := FinishingCode
            else
                Joined += ', ' + FinishingCode;
    end;

    local procedure ValidateComponents(CaseId: Integer; JobNo: Integer; VersionNo: Integer; var Problems: List of [Text])
    var
        JobItem: Record "PVS Job Item";
        ComponentTypeRec: Record "PVS Component Types";
        JobSheet: Record "PVS Job Sheet";
        Item: Record Item;
        EnumNames: Codeunit "PEQI Enum Names";
        Seen: List of [Code[20]];
        ComponentType: Code[20];
    begin
        JobItem.SetRange(ID, CaseId);
        JobItem.SetRange(Job, JobNo);
        JobItem.SetRange(Version, VersionNo);
        // "Active" is deliberately not filtered on. PrintVis leaves it false on job items that
        // are plainly going to print, so filtering on it returned nothing at all and the job
        // looked empty. Every job item of the version is taken instead.
        if not JobItem.FindSet() then
            exit;

        repeat
            ComponentType := JobItem."Component Type";
            if not Seen.Contains(ComponentType) then begin
                Seen.Add(ComponentType);
                if not ComponentTypeRec.Get(ComponentType) then
                    Problems.Add(StrSubstNo(NoComponentTypeMsg, ComponentType))
                else begin
                    if EnumNames.OptionMemberName(ComponentTypeRec, ComponentTypeRec.FieldNo("JDF Product Type")) = 'Unknown' then
                        Problems.Add(StrSubstNo(NoProductTypeMsg, ComponentType));
                    if ComponentTypeRec."PEQI Grain Rule" = ComponentTypeRec."PEQI Grain Rule"::NotSet then
                        Problems.Add(StrSubstNo(GrainNotSetMsg, ComponentType));
                end;
            end;

            // The sheet the CSR put the job item on. Each failure names the sheet, because the fix
            // is on that sheet in PrintVis and the planner has to know which one.
            if (JobItem."Sheet ID" = 0) or not JobSheet.Get(JobItem."Sheet ID") then
                Problems.Add(StrSubstNo(NoSheetMsg, JobItem."Job Item No.", ComponentType))
            else begin
                if JobSheet."Paper Item No." = '' then
                    Problems.Add(StrSubstNo(NoSheetPaperMsg, JobSheet."Sheet ID", ComponentType))
                else
                    if not Item.Get(JobSheet."Paper Item No.") then
                        Problems.Add(StrSubstNo(MissingPaperItemMsg, JobSheet."Sheet ID", ComponentType, JobSheet."Paper Item No."));
                if (JobSheet.Length = 0) or (JobSheet.Width = 0) then
                    Problems.Add(StrSubstNo(NoSheetFormatMsg, JobSheet."Sheet ID", ComponentType));
            end;
        until JobItem.Next() = 0;
    end;

    local procedure ValidatePresses(var Problems: List of [Text])
    var
        Config: Record "PVS Cost Center Configuration";
    begin
        Config.SetRange("PEQI Use for Imposition", true);
        if not Config.FindSet() then begin
            Problems.Add(NoPressMsg);
            exit;
        end;
        repeat
            if (Config."Max Printing Format Width" <= 0) or (Config."Max Printing Format Length" <= 0) then
                Problems.Add(StrSubstNo(NoPressFormatMsg, Config."Cost Center Code", Config.Configuration));
            if IsNullGuid(Config."PEQI Press Id") then
                Problems.Add(StrSubstNo(NoPressIdMsg, Config."Cost Center Code", Config.Configuration))
            else
                if Config.PEQIPressIdHeldByAnother() then
                    Problems.Add(StrSubstNo(SharedPressIdMsg, Config."Cost Center Code", Config.Configuration));
        until Config.Next() = 0;
    end;
}
