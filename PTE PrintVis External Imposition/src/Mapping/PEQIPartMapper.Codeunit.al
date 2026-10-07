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
        NoPaperErr: Label 'Paper item %1 on component %2 is not set up for imposition. Add it on the Imposition Paper Setup page.', Comment = '%1 item no., %2 component type';
        FormatClashErr: Label 'Component %1 spans two trim formats: job item %2 is %3 x %4 and job item %5 is %6 x %7.', Comment = '%1 component, %2 %5 job item nos, %3 %4 %6 %7 dimensions';
        NoComponentsErr: Label 'Job %1/%2/%3 has no job items, so there is nothing to impose.', Comment = '%1 case, %2 job, %3 version';
        NoActiveComponentsErr: Label 'Job %1/%2/%3 has %4 job items but none of them is active, so there is nothing to impose. Activate the components to be printed on the job.', Comment = '%1 case, %2 job, %3 version, %4 count';

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
        JobItem.SetRange(Active, true);
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

    /// <summary>Refuses a job with nothing to impose, saying which kind of nothing.</summary>
    /// <remarks>
    /// This used to return an empty array. The engine then refused the request with "the field
    /// Parts must have a minimum length of 1" -- true, and useless to a planner, who is looking
    /// at a job that plainly has components on it. Worse, it pointed at the editor rather than
    /// at PrintVis.
    /// <para>
    /// The two cases are separated because they are different jobs of work: no job items at all
    /// means the job has not been built yet, while items that are all inactive means somebody
    /// has to activate the ones that print. Counting a second time costs one query on a path
    /// that is already failing.
    /// </para>
    /// </remarks>
    local procedure NoComponents(CaseId: Integer; JobNo: Integer; VersionNo: Integer)
    var
        JobItem: Record "PVS Job Item";
        Total: Integer;
    begin
        JobItem.SetRange(ID, CaseId);
        JobItem.SetRange(Job, JobNo);
        JobItem.SetRange(Version, VersionNo);
        Total := JobItem.Count();

        if Total = 0 then
            Error(NoComponentsErr, CaseId, JobNo, VersionNo);

        Error(NoActiveComponentsErr, CaseId, JobNo, VersionNo, Total);
    end;

    local procedure BuildOnePart(CaseId: Integer; JobNo: Integer; VersionNo: Integer; ComponentType: Code[20]) Part: JsonObject
    var
        JobItem: Record "PVS Job Item";
        PartMapping: Record "PEQI Part Mapping";
        FirstItem: Record "PVS Job Item";
        TotalPages: Integer;
        FrontColors: Integer;
        BackColors: Integer;
    begin
        if not PartMapping.Get(ComponentType) then
            Error(NoMappingErr, ComponentType, CaseId, JobNo, VersionNo);

        JobItem.SetRange(ID, CaseId);
        JobItem.SetRange(Job, JobNo);
        JobItem.SetRange(Version, VersionNo);
        JobItem.SetRange(Active, true);
        JobItem.SetRange("Component Type", ComponentType);
        JobItem.FindSet();
        FirstItem := JobItem;

        repeat
            // A component spanning two formats is an invariant violation in
            // PrintVis, not something to reconcile silently.
            if (JobItem.Width <> FirstItem.Width) or (JobItem.Length <> FirstItem.Length) then
                Error(FormatClashErr, ComponentType,
                      FirstItem."Job Item No.", FirstItem.Width, FirstItem.Length,
                      JobItem."Job Item No.", JobItem.Width, JobItem.Length);
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
        JsonHelper.AddDecimal(Part, 'trimWidthMm', Units.ToMm(FirstItem.Width));
        JsonHelper.AddDecimal(Part, 'trimHeightMm', Units.ToMm(FirstItem.Length));
        JsonHelper.AddText(Part, 'grainRule', EnumNames.GrainRule(PartMapping."Grain Rule"));
        JsonHelper.AddInteger(Part, 'frontColors', FrontColors);
        JsonHelper.AddInteger(Part, 'backColors', BackColors);
        Part.Add('catalog', BuildPartCatalog(FirstItem));
    end;

    /// <summary>A part still selects its own stock even when the request states its
    /// paper - parts[].catalog.substrateIds is not among the refused filters.</summary>
    local procedure BuildPartCatalog(JobItem: Record "PVS Job Item") Catalog: JsonObject
    var
        PaperSetup: Record "PEQI Paper Setup";
        Ids: JsonArray;
    begin
        if JobItem."Item No." = '' then
            exit;
        if not PaperSetup.Get(JobItem."Item No.", '') then
            Error(NoPaperErr, JobItem."Item No.", JobItem."Component Type");
        Ids.Add(PaperSetup."Substrate Id");
        Catalog.Add('substrateIds', Ids);
    end;
}
