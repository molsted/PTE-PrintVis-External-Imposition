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

using Microsoft.Inventory.Item;
using PrintersEquity.ExternalImposition.Enums;
using PrintersEquity.ExternalImposition.Setup;

codeunit 50602 "PEQI Test Data"
{
    /// <summary>Inserts a PVS Job Item for a component, and the sheet behind it that
    /// carries its paper. Only the fields the mapper reads are set - the rest of
    /// PrintVis's model is irrelevant here.</summary>
    /// <remarks>
    /// The paper goes on the sheet, not on the job item, because that is where PrintVis keeps
    /// it: "PVS Job Item"."Paper Item No." is a FlowField over "PVS Job Sheet" and cannot be
    /// written at all. Test data that set the job item's own "Item No." instead let a mapper
    /// reading a FlowField look correct here and return blank against a real database.
    /// </remarks>
    procedure AddJobItem(CaseId: Integer; JobNo: Integer; VersionNo: Integer; JobItemNo: Integer; ComponentType: Code[20]; Pages: Integer; WidthMm: Decimal; LengthMm: Decimal; PaperItemNo: Code[20])
    var
        JobItem: Record "PVS Job Item";
        SheetId: Integer;
    begin
        SheetId := SheetIdFor(CaseId, JobItemNo);
        SetSheetPaper(CaseId, JobNo, VersionNo, SheetId, PaperItemNo);

        JobItem.Init();
        JobItem.ID := CaseId;
        JobItem.Job := JobNo;
        JobItem.Version := VersionNo;
        JobItem."Job Item No." := JobItemNo;
        JobItem."Entry No." := JobItemNo;
        JobItem.Active := true;
        JobItem."Component Type" := ComponentType;
        JobItem."No. Of Pages" := Pages;
        JobItem.Width := WidthMm;
        JobItem.Length := LengthMm;
        JobItem."Sheet ID" := SheetId;
        JobItem."Colors Front" := 4;
        JobItem."Colors Back" := 4;
        JobItem.Insert(true);
    end;

    /// <summary>The sheet id a job item of this case gets, matching the CaseId * 100 + n
    /// the finishing tests already write by hand so the two meet on the same row.</summary>
    procedure SheetIdFor(CaseId: Integer; JobItemNo: Integer): Integer
    begin
        exit((CaseId * 100) + JobItemNo);
    end;

    /// <summary>Inserts the PVS Job that BuildObject reads for binding and quantity.</summary>
    procedure AddJob(CaseId: Integer; JobNo: Integer; VersionNo: Integer; FinishingCode: Code[20]; Quantity: Integer)
    var
        PVSJob: Record "PVS Job";
    begin
        PVSJob.Init();
        PVSJob.ID := CaseId;
        PVSJob.Job := JobNo;
        PVSJob.Version := VersionNo;
        PVSJob.Active := true;
        PVSJob.Finishing := FinishingCode;
        PVSJob.Quantity := Quantity;
        PVSJob.Insert(true);
    end;

    procedure AddPartMapping(ComponentType: Code[20]; ProductType: Enum "PEQI Part Product Type")
    var
        PartMapping: Record "PEQI Part Mapping";
    begin
        PartMapping.Init();
        PartMapping."Component Type" := ComponentType;
        PartMapping."Product Type" := ProductType;
        PartMapping."Grain Rule" := PartMapping."Grain Rule"::ParallelToSpine;
        PartMapping.Insert(true);
    end;

    /// <summary>Inserts a PVS Job Sheet carrying a finishing code. PrintVis lets a
    /// shop state finishing per sheet instead of on the job.</summary>
    procedure AddJobSheet(CaseId: Integer; JobNo: Integer; VersionNo: Integer; SheetId: Integer; FinishingCode: Code[20])
    var
        JobSheet: Record "PVS Job Sheet";
    begin
        Sheet(CaseId, JobNo, VersionNo, SheetId, JobSheet);
        JobSheet.Finishing := FinishingCode;
        Save(JobSheet);
    end;

    /// <summary>Puts the paper on the sheet, leaving any finishing already stated there. A new
    /// sheet gets a 640 x 450 printing format and the same full sheet, so it is uncut unless a
    /// test says otherwise.</summary>
    local procedure SetSheetPaper(CaseId: Integer; JobNo: Integer; VersionNo: Integer; SheetId: Integer; PaperItemNo: Code[20])
    var
        JobSheet: Record "PVS Job Sheet";
    begin
        Sheet(CaseId, JobNo, VersionNo, SheetId, JobSheet);
        JobSheet."Paper Item No." := PaperItemNo;
        if (JobSheet.Length = 0) and (JobSheet.Width = 0) then begin
            JobSheet.Length := 640;
            JobSheet.Width := 450;
            JobSheet."Full Sheet Format 1" := 640;
            JobSheet."Full Sheet Format 2" := 450;
        end;
        Save(JobSheet);
    end;

    /// <summary>The printing format of the sheet behind a job item.</summary>
    procedure SetSheetFormat(CaseId: Integer; JobItemNo: Integer; Length: Decimal; Width: Decimal)
    var
        JobSheet: Record "PVS Job Sheet";
    begin
        JobSheet.Get(SheetIdFor(CaseId, JobItemNo));
        JobSheet.Length := Length;
        JobSheet.Width := Width;
        JobSheet.Modify(false);
    end;

    /// <summary>The purchased sheet behind a job item, and its grain. Grain1Gt2 sets "1&gt;2",
    /// otherwise "1&lt;2".</summary>
    procedure SetSheetFullFormat(CaseId: Integer; JobItemNo: Integer; Format1: Decimal; Format2: Decimal; Grain1Gt2: Boolean)
    var
        JobSheet: Record "PVS Job Sheet";
    begin
        JobSheet.Get(SheetIdFor(CaseId, JobItemNo));
        JobSheet."Full Sheet Format 1" := Format1;
        JobSheet."Full Sheet Format 2" := Format2;
        if Grain1Gt2 then
            JobSheet."Full Sheet Grain Direction" := JobSheet."Full Sheet Grain Direction"::"1>2"
        else
            JobSheet."Full Sheet Grain Direction" := JobSheet."Full Sheet Grain Direction"::"1<2";
        JobSheet.Modify(false);
    end;

    /// <summary>An Item for a paper, so a sheet's paper resolves to a name.</summary>
    procedure AddPaperItem(ItemNo: Code[20]; Description: Text[100])
    var
        Item: Record Item;
    begin
        if Item.Get(ItemNo) then
            exit;
        Item.Init();
        Item."No." := ItemNo;
        Item.Description := Description;
        Item.Insert(false);
    end;

    /// <summary>The sheet row, existing or new. A job item and a finishing code reach the same
    /// sheet from opposite directions, and whichever arrives second must not erase the first.
    /// </summary>
    local procedure Sheet(CaseId: Integer; JobNo: Integer; VersionNo: Integer; SheetId: Integer; var JobSheet: Record "PVS Job Sheet")
    begin
        if JobSheet.Get(SheetId) then
            exit;
        JobSheet.Init();
        JobSheet.ID := CaseId;
        JobSheet.Job := JobNo;
        JobSheet.Version := VersionNo;
        JobSheet."Sheet ID" := SheetId;
    end;

    local procedure Save(var JobSheet: Record "PVS Job Sheet")
    begin
        if JobSheet.Insert(false) then
            exit;
        JobSheet.Modify(false);
    end;

    /// <summary>A cost center configuration marked for imposition, with a format and the two
    /// work styles most presses run. Inserted without PrintVis's triggers.</summary>
    procedure AddPressConfig(CostCenterCode: Code[20]; ConfigCode: Code[20])
    var
        CostCenter: Record "PVS Cost Center";
        Config: Record "PVS Cost Center Configuration";
    begin
        if not CostCenter.Get(CostCenterCode) then begin
            CostCenter.Init();
            CostCenter.Code := CostCenterCode;
            CostCenter.Insert(false);
        end;
        Config.Init();
        Config."Cost Center Code" := CostCenterCode;
        Config.Configuration := ConfigCode;
        Config."Max Printing Format Width" := 1000;
        Config."Max Printing Format Length" := 700;
        Config."PEQI Simplex" := true;
        Config."PEQI Work And Back" := true;
        Config.Insert(false);
        Config.Validate("PEQI Use for Imposition", true);
        Config.Modify(false);
    end;
}
