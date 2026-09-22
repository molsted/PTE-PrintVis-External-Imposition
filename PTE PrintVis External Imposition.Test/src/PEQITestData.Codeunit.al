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

codeunit 50602 "PEQI Test Data"
{
    /// <summary>Inserts a PVS Job Item for a component. Only the fields the mapper
    /// reads are set - the rest of PrintVis's model is irrelevant here.</summary>
    procedure AddJobItem(CaseId: Integer; JobNo: Integer; VersionNo: Integer; JobItemNo: Integer; ComponentType: Code[20]; Pages: Integer; WidthMm: Decimal; LengthMm: Decimal; PaperItemNo: Code[20])
    var
        JobItem: Record "PVS Job Item";
    begin
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
        JobItem."Item No." := PaperItemNo;
        JobItem."Colors Front" := 4;
        JobItem."Colors Back" := 4;
        JobItem.Insert(true);
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

    procedure AddPaper(ItemNo: Code[20]): Integer
    var
        PaperSetup: Record "PEQI Paper Setup";
    begin
        PaperSetup.Init();
        PaperSetup."Item No." := ItemNo;
        PaperSetup."Use for Imposition" := true;
        PaperSetup.Insert(true);
        exit(PaperSetup."Substrate Id");
    end;
}
