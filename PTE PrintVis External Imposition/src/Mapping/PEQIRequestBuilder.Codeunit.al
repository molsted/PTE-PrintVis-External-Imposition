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

using PrintersEquity.ExternalImposition.Enums;
using PrintersEquity.ExternalImposition.Setup;

codeunit 50535 "PEQI Request Builder"
{
    var
        PartMapper: Codeunit "PEQI Part Mapper";
        CatalogMapper: Codeunit "PEQI Catalog Mapper";
        JsonHelper: Codeunit "PEQI Json Helper";
        EnumNames: Codeunit "PEQI Enum Names";
        Validator: Codeunit "PEQI Request Validator";
        NoFinishingTypeErr: Label 'Finishing code %1 on job %2/%3/%4 has no finishing type in PrintVis.', Comment = '%1 finishing code, %2 case, %3 job, %4 version';
        NoJobErr: Label 'Job %1/%2/%3 does not exist.', Comment = '%1 case, %2 job, %3 version';
        ValidationErr: Label 'This job cannot be sent for imposition yet:\%1', Comment = '%1 newline-separated list of problems';

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
        FinishingType: Record "PVS Finishing Types";
        Setup: Record "PEQI Imposition Setup";
        FinishingCode: Code[20];
        Problem: Text;
    begin
        if not PVSJob.Get(CaseId, JobNo, VersionNo) then
            Error(NoJobErr, CaseId, JobNo, VersionNo);
        if not Validator.ResolveFinishing(CaseId, JobNo, VersionNo, FinishingCode, Problem) then
            Error(ValidationErr, Problem);
        if not FinishingType.Get(FinishingCode) then
            Error(NoFinishingTypeErr, FinishingCode, CaseId, JobNo, VersionNo);
        Setup := Setup.GetSetup();
        ValidateOrError(CaseId, JobNo, VersionNo);

        RequestObject.Add('parts', PartMapper.BuildParts(CaseId, JobNo, VersionNo));
        JsonHelper.AddText(RequestObject, 'binding',
            EnumNames.BindingFromCip4(EnumNames.OptionMemberName(FinishingType, FinishingType.FieldNo("CIP4 Binding")), FinishingCode));
        JsonHelper.AddText(RequestObject, 'bindingSide', BindingSide(CaseId, JobNo, VersionNo, FinishingType));
        JsonHelper.AddIntegerIfSet(RequestObject, 'amount', PVSJob.Quantity);
        JsonHelper.AddText(RequestObject, 'grainPolicy', EnumNames.GrainPolicy(Setup."Grain Policy"));
        JsonHelper.AddInteger(RequestObject, 'maxSolutions', Setup."Max Solutions");

        // The self-contained set. Stating a half replaces its catalogue, so the
        // matching catalog filters are omitted by construction rather than
        // discovered as a 400.
        RequestObject.Add('sheets', CatalogMapper.BuildSheets(CaseId, JobNo, VersionNo));
        RequestObject.Add('presses', CatalogMapper.BuildPresses());
        RequestObject.Add('foldPatterns', CatalogMapper.BuildFoldPatterns());

        // impositionRules is deliberately absent - see the design, section 6.5.
    end;

    /// <summary>What the editor is told about the session it is being handed.</summary>
    /// <remarks>
    /// <para>
    /// Lives here rather than on the page because a page's local procedure cannot be tested, and
    /// this one decides whether the operator is offered the full editor beside the simple view
    /// every session starts on. It is not a security boundary on what Business Central accepts back:
    /// "PEQI Commit Manager".StoreChoice stores whatever request comes back regardless of mode.
    /// </para>
    /// <para>
    /// <b>Do not give this codeunit a <c>Permissions</c> property that covers "PEQI Imposition
    /// Setup".</b> Inherent permissions would make <c>WritePermission()</c> report true for every
    /// user, and every user would be offered the full editor - the check would fail open.
    /// </para>
    /// <para>
    /// <b>Who may switch is read off the permission sets themselves.</b> "PEQI Imposition Setup" is R in
    /// "PEQI Imposition" and RIMD in "PEQI Imp. Setup", so write access to it is exactly the
    /// difference between the two, and this cannot drift from them the way a separate flag or a
    /// third permission set would.
    /// </para>
    /// </remarks>
    procedure SeedOptions(EntryKey: Text): Text
    var
        ImpositionSetup: Record "PEQI Imposition Setup";
        Options: JsonObject;
        OptionsText: Text;
    begin
        // The product comes from the case, not from the operator typing it.
        Options.Add('readonlyProduct', true);
        Options.Add('startRoute', 'layout');
        // Echoed back on every result, and checked before anything is stored.
        Options.Add('entryKey', EntryKey);

        // Everyone starts on the simple view. Write access to "PEQI Imposition Setup" -- which only
        // "PEQI Imp. Setup" grants -- decides whether the editor also offers the full one.
        Options.Add('mode', 'approve');
        Options.Add('fullEditorAllowed', ImpositionSetup.WritePermission());

        Options.WriteTo(OptionsText);
        exit(OptionsText);
    end;

    local procedure ValidateOrError(CaseId: Integer; JobNo: Integer; VersionNo: Integer)
    var
        Problems: List of [Text];
        Problem: Text;
        Combined: TextBuilder;
    begin
        if Validator.Validate(CaseId, JobNo, VersionNo, Problems) then
            exit;
        foreach Problem in Problems do begin
            Combined.AppendLine('- ' + Problem);
        end;
        Error(ValidationErr, Combined.ToText());
    end;

    /// <summary>The spine side: the job's own imposition code first, then the finishing type's
    /// CIP4 BindingSide, then Left.</summary>
    local procedure BindingSide(CaseId: Integer; JobNo: Integer; VersionNo: Integer; FinishingType: Record "PVS Finishing Types"): Text
    var
        JobItem: Record "PVS Job Item";
        ImpositionCode: Record "PVS Imposition Code";
        FromFinishing: Text;
    begin
        JobItem.SetRange(ID, CaseId);
        JobItem.SetRange(Job, JobNo);
        JobItem.SetRange(Version, VersionNo);
        // "Active" is deliberately not filtered on: PrintVis leaves it false on rows that print.
        JobItem.SetFilter("Imposition Type", '<>%1', '');
        if JobItem.FindFirst() then
            if ImpositionCode.Get(JobItem."Imposition Type") then
                // PVS Imposition Code."Spine Side" is Left,Right only.
                case ImpositionCode."Spine Side" of
                    ImpositionCode."Spine Side"::Left:
                        exit('Left');
                    ImpositionCode."Spine Side"::Right:
                        exit('Right');
                end;

        FromFinishing := EnumNames.BindingSideFromCip4(EnumNames.OptionMemberName(FinishingType, FinishingType.FieldNo("CIP4 BindingSide")));
        if FromFinishing <> '' then
            exit(FromFinishing);
        exit('Left');
    end;
}
