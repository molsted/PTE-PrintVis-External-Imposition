// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

codeunit 50535 "PEQI Request Builder"
{
    var
        PartMapper: Codeunit "PEQI Part Mapper";
        CatalogMapper: Codeunit "PEQI Catalog Mapper";
        JsonHelper: Codeunit "PEQI Json Helper";
        NoBindingErr: Label 'Finishing code %1 on job %2/%3/%4 has no imposition binding mapping. Add it on the Imposition Binding Mappings page.', Comment = '%1 finishing code, %2 case, %3 job, %4 version';
        NoJobErr: Label 'Job %1/%2/%3 does not exist.', Comment = '%1 case, %2 job, %3 version';

    procedure Build(CaseId: Integer; JobNo: Integer; VersionNo: Integer): Text
    var
        RequestObject: JsonObject;
        RequestText: Text;
    begin
        RequestObject := BuildObject(CaseId, JobNo, VersionNo);
        RequestObject.WriteTo(RequestText);
        exit(RequestText);
    end;

    procedure BuildObject(CaseId: Integer; JobNo: Integer; VersionNo: Integer) RequestObject: JsonObject
    var
        PVSJob: Record "PVS Job";
        BindingMapping: Record "PEQI Binding Mapping";
        Setup: Record "PEQI Imposition Setup";
    begin
        if not PVSJob.Get(CaseId, JobNo, VersionNo) then
            Error(NoJobErr, CaseId, JobNo, VersionNo);
        if not BindingMapping.Get(PVSJob.Finishing) then
            Error(NoBindingErr, PVSJob.Finishing, CaseId, JobNo, VersionNo);
        Setup := Setup.GetSetup();

        RequestObject.Add('parts', PartMapper.BuildParts(CaseId, JobNo, VersionNo));
        JsonHelper.AddText(RequestObject, 'binding', Format(BindingMapping.Binding, 0, 9));
        JsonHelper.AddText(RequestObject, 'bindingSide', Format(BindingSide(CaseId, JobNo, VersionNo, BindingMapping), 0, 9));
        JsonHelper.AddIntegerIfSet(RequestObject, 'amount', PVSJob.Quantity);
        JsonHelper.AddText(RequestObject, 'grainPolicy', Format(Setup."Grain Policy", 0, 9));
        JsonHelper.AddInteger(RequestObject, 'maxSolutions', Setup."Max Solutions");

        // The self-contained set. Stating a half replaces its catalogue, so the
        // matching catalog filters are omitted by construction rather than
        // discovered as a 400.
        RequestObject.Add('sheets', CatalogMapper.BuildSheets());
        RequestObject.Add('presses', CatalogMapper.BuildPresses());
        RequestObject.Add('foldPatterns', CatalogMapper.BuildFoldPatterns());

        // impositionRules is deliberately absent - see the design, section 6.5.
    end;

    /// <summary>The spine side the job's own imposition code states, falling back to
    /// the binding mapping's default.</summary>
    local procedure BindingSide(CaseId: Integer; JobNo: Integer; VersionNo: Integer; BindingMapping: Record "PEQI Binding Mapping"): Enum "PEQI Binding Side"
    var
        JobItem: Record "PVS Job Item";
        ImpositionCode: Record "PVS Imposition Code";
    begin
        JobItem.SetRange(ID, CaseId);
        JobItem.SetRange(Job, JobNo);
        JobItem.SetRange(Version, VersionNo);
        JobItem.SetRange(Active, true);
        JobItem.SetFilter("Imposition Type", '<>%1', '');
        if JobItem.FindFirst() then
            if ImpositionCode.Get(JobItem."Imposition Type") then
                // PVS Imposition Code."Spine Side" is Left,Right only. Top and
                // Bottom binding remain reachable through the binding mapping's
                // default, which is the only place they can come from.
                case ImpositionCode."Spine Side" of
                    ImpositionCode."Spine Side"::Left:
                        exit("PEQI Binding Side"::Left);
                    ImpositionCode."Spine Side"::Right:
                        exit("PEQI Binding Side"::Right);
                end;
        exit(BindingMapping."Default Binding Side");
    end;
}
