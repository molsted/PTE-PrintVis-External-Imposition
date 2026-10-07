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

using PrintersEquity.ExternalImposition.Setup;

codeunit 50536 "PEQI Part Mapper"
{
    var
        JsonHelper: Codeunit "PEQI Json Helper";
        Units: Codeunit "PEQI Unit Converter";
        EnumNames: Codeunit "PEQI Enum Names";
        NoMappingErr: Label 'Component type %1 on job %2/%3/%4 has no imposition part mapping. Add it on the Imposition Part Mappings page.', Comment = '%1 component type, %2 case, %3 job, %4 version';
        NoPaperErr: Label 'Paper item %1 on component %2 is not set up for imposition. Add it on the Imposition Paper Setup page.', Comment = '%1 paper item no., %2 component type';
        PaperClashErr: Label 'Component %1 spans two papers: job item %2 runs on %3 and job item %4 runs on %5. A part is imposed on one stock.', Comment = '%1 component, %2 %4 job item nos, %3 %5 paper item nos';
        FormatClashErr: Label 'Component %1 spans two trim formats: job item %2 is %3 x %4 and job item %5 is %6 x %7.', Comment = '%1 component, %2 %5 job item nos, %3 %4 %6 %7 dimensions';
        NoComponentsErr: Label 'Job %1/%2/%3 has no job items, so there is nothing to impose.', Comment = '%1 case, %2 job, %3 version';

    /// <summary>One engine part per component type, pages summed across its job items.</summary>
    procedure BuildParts(CaseId: Integer; JobNo: Integer; VersionNo: Integer): JsonArray
    var
        JobItem: Record "PVS Job Item";
        Parts: JsonArray;
        Seen: Dictionary of [Code[20], Integer];
        ComponentType: Code[20];
    begin
        JobItem.SetRange(ID, CaseId);
        JobItem.SetRange(Job, JobNo);
        JobItem.SetRange(Version, VersionNo);
        // "Active" is deliberately not filtered on. PrintVis leaves it false on job items that
        // are plainly going to print, so filtering on it returned nothing at all and the job
        // looked empty. Every job item of the version is taken instead.
        JobItem.SetCurrentKey(ID, Job, Version, "Job Item No.");
        if not JobItem.FindSet() then
            NoComponents(CaseId, JobNo, VersionNo);

        repeat
            ComponentType := JobItem."Component Type";
            if not Seen.ContainsKey(ComponentType) then begin
                Seen.Add(ComponentType, 1);
                Parts.Add(BuildOnePart(CaseId, JobNo, VersionNo, ComponentType));
            end;
        until JobItem.Next() = 0;

        exit(Parts);
    end;

    /// <summary>Refuses a job with nothing to impose, rather than sending no parts.</summary>
    /// <remarks>
    /// This used to return an empty array. The engine then refused the request with "the field
    /// Parts must have a minimum length of 1" -- true, and useless to a planner, who is looking
    /// at a job that plainly has components on it. Worse, it pointed at the editor rather than
    /// at PrintVis, which is where the missing thing was.
    /// </remarks>
    local procedure NoComponents(CaseId: Integer; JobNo: Integer; VersionNo: Integer)
    begin
        Error(NoComponentsErr, CaseId, JobNo, VersionNo);
    end;

    local procedure BuildOnePart(CaseId: Integer; JobNo: Integer; VersionNo: Integer; ComponentType: Code[20]) Part: JsonObject
    var
        JobItem: Record "PVS Job Item";
        PartMapping: Record "PEQI Part Mapping";
        FirstItem: Record "PVS Job Item";
        FirstPaper: Code[20];
        ItemPaper: Code[20];
        TotalPages: Integer;
        FrontColors: Integer;
        BackColors: Integer;
    begin
        if not PartMapping.Get(ComponentType) then
            Error(NoMappingErr, ComponentType, CaseId, JobNo, VersionNo);

        JobItem.SetRange(ID, CaseId);
        JobItem.SetRange(Job, JobNo);
        JobItem.SetRange(Version, VersionNo);
        JobItem.SetRange("Component Type", ComponentType);
        JobItem.FindSet();
        FirstItem := JobItem;
        FirstPaper := PaperItemNo(FirstItem);

        repeat
            // A component spanning two formats is an invariant violation in
            // PrintVis, not something to reconcile silently.
            if (JobItem.Width <> FirstItem.Width) or (JobItem.Length <> FirstItem.Length) then
                Error(FormatClashErr, ComponentType,
                      FirstItem."Job Item No.", FirstItem.Width, FirstItem.Length,
                      JobItem."Job Item No.", JobItem.Width, JobItem.Length);
            // And one paper, for the same reason: the part is pinned to the stock its first job
            // item names, so a sibling on different stock would be imposed on paper nobody chose
            // for it.
            ItemPaper := PaperItemNo(JobItem);
            if ItemPaper <> FirstPaper then
                Error(PaperClashErr, ComponentType,
                      FirstItem."Job Item No.", FirstPaper,
                      JobItem."Job Item No.", ItemPaper);
            TotalPages += JobItem."No. Of Pages";
            if JobItem."Colors Front" > FrontColors then
                FrontColors := JobItem."Colors Front";
            if JobItem."Colors Back" > BackColors then
                BackColors := JobItem."Colors Back";
        until JobItem.Next() = 0;

        JsonHelper.AddText(Part, 'name', ComponentType);
        JsonHelper.AddText(Part, 'productType', EnumNames.ProductType(PartMapping."Product Type"));
        JsonHelper.AddInteger(Part, 'pageCount', TotalPages);
        // The finished page, in the installation's unit. Same conversion as the sheets:
        // a trim and a sheet have to be in the same unit or nothing fits anything.
        JsonHelper.AddDecimal(Part, 'trimWidthMm', Units.FormatToMm(FirstItem.Width));
        JsonHelper.AddDecimal(Part, 'trimHeightMm', Units.FormatToMm(FirstItem.Length));
        JsonHelper.AddText(Part, 'grainRule', EnumNames.GrainRule(PartMapping."Grain Rule"));
        JsonHelper.AddInteger(Part, 'frontColors', FrontColors);
        JsonHelper.AddInteger(Part, 'backColors', BackColors);
        Part.Add('catalog', BuildPartCatalog(FirstPaper, ComponentType));
    end;

    /// <summary>The paper the component runs on, read from the sheet that records it.</summary>
    /// <remarks>
    /// <para>
    /// <b>"PVS Job Item"."Paper Item No." cannot be read directly.</b> It is a FlowField --
    /// <c>lookup("PVS Job Sheet"."Paper Item No." where("Sheet ID" = field("Sheet ID")))</c> --
    /// and a FlowField holds nothing until CalcFields runs. Read without calculating it, it
    /// returns '' for every job item on every job, which is why pinning the part to it still
    /// sent catalog:{} and left the engine to pick one stock for the whole product.
    /// </para>
    /// <para>
    /// The sheet record is read instead of the lookup being calculated. It is where PrintVis
    /// actually keeps the paper, "Sheet ID" is its primary key so this is a single keyed read,
    /// and the same row carries the full sheet format, grain direction and thickness should any
    /// of those be wanted here later.
    /// </para>
    /// </remarks>
    procedure PaperItemNo(JobItem: Record "PVS Job Item"): Code[20]
    var
        JobSheet: Record "PVS Job Sheet";
    begin
        if JobItem."Sheet ID" = 0 then
            exit('');
        if not JobSheet.Get(JobItem."Sheet ID") then
            exit('');
        exit(JobSheet."Paper Item No.");
    end;

    /// <summary>A part still selects its own stock even when the request states its
    /// paper - parts[].catalog.substrateIds is not among the refused filters.</summary>
    local procedure BuildPartCatalog(PaperItemNumber: Code[20]; ComponentType: Code[20]) Catalog: JsonObject
    var
        PaperSetup: Record "PEQI Paper Setup";
        Ids: JsonArray;
    begin
        // A job item with no sheet behind it names no paper, and that is not an error: the
        // engine then chooses for that part from the job-wide list, as it did for every part
        // before this was pinned at all.
        if PaperItemNumber = '' then
            exit;
        if not PaperSetup.Get(PaperItemNumber, '') then
            Error(NoPaperErr, PaperItemNumber, ComponentType);
        Ids.Add(PaperSetup."Substrate Id");
        Catalog.Add('substrateIds', Ids);
    end;
}
