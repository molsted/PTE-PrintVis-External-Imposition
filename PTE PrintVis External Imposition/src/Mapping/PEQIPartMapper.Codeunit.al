// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

codeunit 50536 "PEQI Part Mapper"
{
    var
        JsonHelper: Codeunit "PEQI Json Helper";
        NoMappingErr: Label 'Component type %1 on job %2/%3/%4 has no imposition part mapping. Add it on the Imposition Part Mappings page.', Comment = '%1 component type, %2 case, %3 job, %4 version';
        NoPaperErr: Label 'Paper item %1 on component %2 is not set up for imposition. Add it on the Imposition Paper Setup page.', Comment = '%1 item no., %2 component type';
        FormatClashErr: Label 'Component %1 spans two trim formats: job item %2 is %3 x %4 and job item %5 is %6 x %7.', Comment = '%1 component, %2 %5 job item nos, %3 %4 %6 %7 dimensions';

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
            exit(Parts);

        repeat
            ComponentType := JobItem."Component Type";
            if not Seen.ContainsKey(ComponentType) then begin
                Seen.Add(ComponentType, 1);
                Parts.Add(BuildOnePart(CaseId, JobNo, VersionNo, ComponentType));
            end;
        until JobItem.Next() = 0;

        exit(Parts);
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
        JsonHelper.AddText(Part, 'productType', Format(PartMapping."Product Type"));
        JsonHelper.AddInteger(Part, 'pageCount', TotalPages);
        JsonHelper.AddDecimal(Part, 'trimWidthMm', FirstItem.Width);
        JsonHelper.AddDecimal(Part, 'trimHeightMm', FirstItem.Length);
        JsonHelper.AddText(Part, 'grainRule', Format(PartMapping."Grain Rule"));
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
