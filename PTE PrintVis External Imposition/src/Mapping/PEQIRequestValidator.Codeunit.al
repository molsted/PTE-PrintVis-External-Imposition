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
        NoPartMsg: Label 'Component type %1 has no imposition part mapping.', Comment = '%1 component type';
        OddPagesMsg: Label 'Component %1 has %2 pages. A folded part needs an even count.', Comment = '%1 component, %2 page count';
        NoPaperSetupMsg: Label 'Paper item %1 used by component %2 is not set up for imposition.', Comment = '%1 item no., %2 component';
        NoPaperFormatMsg: Label 'Paper item %1 is marked for imposition but has no sheet size (PVS Format 1 / 2).', Comment = '%1 item no.';
        NoPressMsg: Label 'No press is marked Use for Imposition.', Locked = false;
        NoPressFormatMsg: Label 'Press %1 %2 is marked for imposition but its configuration has no maximum printing format.', Comment = '%1 cost centre, %2 configuration';
        NoSheetsMsg: Label 'No paper is marked Use for Imposition.', Locked = false;

    /// <summary>Collects every problem rather than stopping at the first, so an
    /// operator fixes them in one visit. True when the request may be built.</summary>
    procedure Validate(CaseId: Integer; JobNo: Integer; VersionNo: Integer; var Problems: List of [Text]): Boolean
    begin
        Clear(Problems);
        ValidateJob(CaseId, JobNo, VersionNo, Problems);
        ValidateComponents(CaseId, JobNo, VersionNo, Problems);
        ValidatePaper(Problems);
        ValidatePresses(Problems);
        exit(Problems.Count() = 0);
    end;

    local procedure ValidateJob(CaseId: Integer; JobNo: Integer; VersionNo: Integer; var Problems: List of [Text])
    var
        PVSJob: Record "PVS Job";
        BindingMapping: Record "PEQI Binding Mapping";
    begin
        if not PVSJob.Get(CaseId, JobNo, VersionNo) then
            exit;
        if not BindingMapping.Get(PVSJob.Finishing) then
            Problems.Add(StrSubstNo(NoBindingMsg, PVSJob.Finishing));
    end;

    local procedure ValidateComponents(CaseId: Integer; JobNo: Integer; VersionNo: Integer; var Problems: List of [Text])
    var
        JobItem: Record "PVS Job Item";
        PartMapping: Record "PEQI Part Mapping";
        PaperSetup: Record "PEQI Paper Setup";
        Pages: Dictionary of [Code[20], Integer];
        ComponentType: Code[20];
        Total: Integer;
    begin
        JobItem.SetRange(ID, CaseId);
        JobItem.SetRange(Job, JobNo);
        JobItem.SetRange(Version, VersionNo);
        JobItem.SetRange(Active, true);
        if not JobItem.FindSet() then
            exit;

        repeat
            ComponentType := JobItem."Component Type";
            if Pages.ContainsKey(ComponentType) then
                Pages.Set(ComponentType, Pages.Get(ComponentType) + JobItem."No. Of Pages")
            else begin
                Pages.Add(ComponentType, JobItem."No. Of Pages");
                if not PartMapping.Get(ComponentType) then
                    Problems.Add(StrSubstNo(NoPartMsg, ComponentType));
            end;

            if JobItem."Item No." <> '' then
                if not PaperSetup.Get(JobItem."Item No.", '') then
                    Problems.Add(StrSubstNo(NoPaperSetupMsg, JobItem."Item No.", ComponentType));
        until JobItem.Next() = 0;

        foreach ComponentType in Pages.Keys() do begin
            Total := Pages.Get(ComponentType);
            if PartMapping.Get(ComponentType) then
                if IsFolded(PartMapping."Product Type") and (Total mod 2 <> 0) then
                    Problems.Add(StrSubstNo(OddPagesMsg, ComponentType, Total));
        end;
    end;

    local procedure IsFolded(ProductType: Enum "PEQI Part Product Type"): Boolean
    begin
        exit(ProductType <> ProductType::Flat);
    end;

    local procedure ValidatePaper(var Problems: List of [Text])
    var
        PaperSetup: Record "PEQI Paper Setup";
        Item: Record Item;
    begin
        PaperSetup.SetRange("Use for Imposition", true);
        if PaperSetup.IsEmpty() then begin
            Problems.Add(NoSheetsMsg);
            exit;
        end;

        PaperSetup.FindSet();
        repeat
            if Item.Get(PaperSetup."Item No.") then
                if (Item."PVS Format 1" <= 0) or (Item."PVS Format 2" <= 0) then
                    Problems.Add(StrSubstNo(NoPaperFormatMsg, PaperSetup."Item No."));
        until PaperSetup.Next() = 0;
    end;

    local procedure ValidatePresses(var Problems: List of [Text])
    var
        PressSetup: Record "PEQI Press Setup";
        Config: Record "PVS Cost Center Configuration";
    begin
        PressSetup.SetRange("Use for Imposition", true);
        if PressSetup.IsEmpty() then begin
            Problems.Add(NoPressMsg);
            exit;
        end;

        PressSetup.FindSet();
        repeat
            if Config.Get(PressSetup."Cost Center Code", PressSetup.Configuration) then
                if (Config."Max Printing Format Width" <= 0) or (Config."Max Printing Format Length" <= 0) then
                    Problems.Add(StrSubstNo(NoPressFormatMsg, PressSetup."Cost Center Code", PressSetup.Configuration));
        until PressSetup.Next() = 0;
    end;
}
