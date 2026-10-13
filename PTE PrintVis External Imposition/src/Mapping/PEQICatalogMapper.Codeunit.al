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

codeunit 50537 "PEQI Catalog Mapper"
{
    var
        JsonHelper: Codeunit "PEQI Json Helper";
        Units: Codeunit "PEQI Unit Converter";
        EnumNames: Codeunit "PEQI Enum Names";

    /// <summary>The paper half: the job's own sheets, as the CSR decided them.</summary>
    /// <remarks>
    /// No shop-wide list and no overrides. Each substrate is a group of the job's sheets with one
    /// paper at one printing format (see "PEQI Job Sheet Reader"); its id is the group's lowest
    /// Sheet ID. Sizes are the printing format -- the sheet that goes on the press, after any cut
    /// from the purchased sheet.
    /// </remarks>
    procedure BuildSheets(CaseId: Integer; JobNo: Integer; VersionNo: Integer) Sheets: JsonArray
    var
        Reader: Codeunit "PEQI Job Sheet Reader";
        JobSheet: Record "PVS Job Sheet";
        Item: Record Item;
        Sheet: JsonObject;
        SubstrateId: Integer;
        Grain: Text;
    begin
        Reader.Load(CaseId, JobNo, VersionNo);
        foreach SubstrateId in Reader.SubstrateIds() do
            if JobSheet.Get(SubstrateId) then begin
                Clear(Sheet);
                if not Item.Get(JobSheet."Paper Item No.") then
                    Clear(Item);
                JsonHelper.AddInteger(Sheet, 'id', SubstrateId);
                JsonHelper.AddText(Sheet, 'name', Item.Description);
                JsonHelper.AddText(Sheet, 'vendorSku', Item."PVS Paper No.");
                // Larger into width, smaller into height, always: a press sheet is never
                // expressed or run the other way up.
                JsonHelper.AddDecimal(Sheet, 'widthMm', Units.FormatToMm(LongerOf(JobSheet.Length, JobSheet.Width)));
                JsonHelper.AddDecimal(Sheet, 'heightMm', Units.FormatToMm(ShorterOf(JobSheet.Length, JobSheet.Width)));

                Grain := SheetGrain(JobSheet);
                if Grain <> '' then
                    JsonHelper.AddText(Sheet, 'grain', Grain);

                // Whole numbers: the engine declares both as int and refuses a fractional token.
                // A basis-less weight unit is quoted over the purchased sheet.
                JsonHelper.AddIntegerIfSet(Sheet, 'grammageGsm', Round(Units.WeightToGsm(JobSheet.Weight, JobSheet."Weight Unit",
                    JobSheet."Full Sheet Format 1", JobSheet."Full Sheet Format 2"), 1, '='));
                JsonHelper.AddIntegerIfSet(Sheet, 'caliperMicrons', Round(Units.ThicknessToMicrons(JobSheet.Thickness,
                    JobSheet.Weight, JobSheet."Weight Unit"), 1, '='));
                Sheets.Add(Sheet);
            end;
    end;

    /// <summary>The grain of the sheet that goes on the press, or blank when it is not known.</summary>
    /// <remarks>
    /// "Full Sheet Grain Direction" is stated against the purchased sheet. When the printing
    /// format is that sheet -- in either orientation -- it maps as an item's grain always has:
    /// 1&gt;2 is Short, 1&lt;2 is Long. When the printing format is cut from it, which full-sheet
    /// edge became which press-sheet edge is not established yet, so no grain is claimed and the
    /// engine reports it unverified. A wrong grain is worse than none.
    /// </remarks>
    local procedure SheetGrain(JobSheet: Record "PVS Job Sheet"): Text
    begin
        if not IsUncut(JobSheet) then
            exit('');
        case JobSheet."Full Sheet Grain Direction" of
            JobSheet."Full Sheet Grain Direction"::"1>2":
                exit('Short');
            JobSheet."Full Sheet Grain Direction"::"1<2":
                exit('Long');
        end;
        exit('');
    end;

    local procedure IsUncut(JobSheet: Record "PVS Job Sheet"): Boolean
    begin
        if (JobSheet."Full Sheet Format 1" = 0) or (JobSheet."Full Sheet Format 2" = 0) then
            exit(false);
        exit(((JobSheet.Length = JobSheet."Full Sheet Format 1") and (JobSheet.Width = JobSheet."Full Sheet Format 2")) or
             ((JobSheet.Length = JobSheet."Full Sheet Format 2") and (JobSheet.Width = JobSheet."Full Sheet Format 1")));
    end;

    local procedure LongerOf(A: Decimal; B: Decimal): Decimal
    begin
        if A >= B then
            exit(A);
        exit(B);
    end;

    local procedure ShorterOf(A: Decimal; B: Decimal): Decimal
    begin
        if A >= B then
            exit(B);
        exit(A);
    end;

    /// <summary>Which edge the sheet is laid to, as the engine names edges.</summary>
    /// <remarks>
    /// <para>
    /// From PrintVis, not from our own setup. "PVS Cost Center Configuration"."Pull Side" records
    /// it -- Left, Right or Both -- beside the Pull measurement itself, and reading one without
    /// the other is what left every press stating a side lay of 5.08 mm against an edge of
    /// nothing. The engine cannot place a margin it has no edge for and says so:
    /// PRESS_MARGIN_EDGE_UNREADABLE.
    /// </para>
    /// <para>
    /// Our own "Side Lay Edge" stays as an override, for a press whose configuration is wrong or
    /// silent. It is checked first for that reason, and is blank by default.
    /// </para>
    /// <para>
    /// <b>Both is not an edge.</b> A press that lays to either side has no single one, and
    /// guessing would put the margin on a side the sheet may not be registered against. Blank is
    /// returned and the field is omitted, which is the honest statement and leaves the engine to
    /// treat the margins symmetrically.
    /// </para>
    /// </remarks>
    local procedure SideLayEdge(PressSetup: Record "PEQI Press Setup"; Config: Record "PVS Cost Center Configuration"): Text
    begin
        if PressSetup."Side Lay Edge" <> PressSetup."Side Lay Edge"::" " then
            exit(EnumNames.PressEdge(PressSetup."Side Lay Edge"));

        case Config."Pull Side" of
            Config."Pull Side"::Left:
                exit('Left');
            Config."Pull Side"::Right:
                exit('Right');
        end;

        exit('');
    end;

    /// <summary>The press half. The measurements come from PrintVis's cost centre
    /// configuration; the edges, the image area and the work styles come from our
    /// setup, because PrintVis does not record them.</summary>
    procedure BuildPresses() Presses: JsonArray
    var
        PressSetup: Record "PEQI Press Setup";
        Config: Record "PVS Cost Center Configuration";
        Press: JsonObject;
        SideLay: Text;
    begin
        PressSetup.SetRange("Use for Imposition", true);
        if not PressSetup.FindSet() then
            exit;

        repeat
            Clear(Press);
            if not Config.Get(PressSetup."Cost Center Code", PressSetup.Configuration) then
                Clear(Config);

            JsonHelper.AddText(Press, 'id', GuidText(PressSetup."Press Id"));
            JsonHelper.AddText(Press, 'name', PressName(PressSetup, Config));
            JsonHelper.AddText(Press, 'type', EnumNames.PressType(PressType(PressSetup, Config)));

            JsonHelper.AddDecimal(Press, 'maxSheetWidthMm', Units.FormatToMm(Config."Max Printing Format Width"));
            JsonHelper.AddDecimal(Press, 'maxSheetHeightMm', Units.FormatToMm(Config."Max Printing Format Length"));
            JsonHelper.AddDecimalIfSet(Press, 'minSheetWidthMm', Units.FormatToMm(Config."Min Print Format Width"));
            JsonHelper.AddDecimalIfSet(Press, 'minSheetHeightMm', Units.FormatToMm(Config."Min Print Format Length"));

            JsonHelper.AddDecimalIfSet(Press, 'nonPrintableMarginTopMm', PressSetup."Non-Printable Top (mm)");
            JsonHelper.AddDecimalIfSet(Press, 'nonPrintableMarginBottomMm', PressSetup."Non-Printable Bottom (mm)");
            JsonHelper.AddDecimalIfSet(Press, 'nonPrintableMarginLeftMm', PressSetup."Non-Printable Left (mm)");
            JsonHelper.AddDecimalIfSet(Press, 'nonPrintableMarginRightMm', PressSetup."Non-Printable Right (mm)");

            JsonHelper.AddDecimalIfSet(Press, 'gripperMarginMm', Units.MarginToMm(Config."Gripper Edge"));
            if PressSetup."Gripper Edge Side" <> PressSetup."Gripper Edge Side"::" " then
                JsonHelper.AddText(Press, 'gripperEdge', EnumNames.PressEdge(PressSetup."Gripper Edge Side"));
            JsonHelper.AddDecimalIfSet(Press, 'sideLayMarginMm', Units.MarginToMm(Config.Pull));
            SideLay := SideLayEdge(PressSetup, Config);
            if SideLay <> '' then
                JsonHelper.AddText(Press, 'sideLayEdge', SideLay);

            // Both image-area bounds are needed for either to apply.
            if (PressSetup."Max Image Area Width (mm)" <> 0) and (PressSetup."Max Image Area Height (mm)" <> 0) then begin
                JsonHelper.AddDecimal(Press, 'maxImageAreaWidthMm', PressSetup."Max Image Area Width (mm)");
                JsonHelper.AddDecimal(Press, 'maxImageAreaHeightMm', PressSetup."Max Image Area Height (mm)");
            end;

            JsonHelper.AddIntegerIfSet(Press, 'maxColorCount', Config."Max No. Of Colors");
            JsonHelper.AddBoolean(Press, 'supportsDoubleSided', Config."Perfection Printing");
            if Config."Perfection Printing" then
                JsonHelper.AddText(Press, 'printingType', 'Perfector');
            JsonHelper.AddIntegerIfSet(Press, 'sheetsPerHour', PressSetup."Sheets Per Hour");

            JsonHelper.AddText(Press, 'plateName', Config."Plate No.");
            JsonHelper.AddDecimalIfSet(Press, 'plateWidthMm', Units.FormatToMm(Config."Plate Width"));
            JsonHelper.AddDecimalIfSet(Press, 'plateHeightMm', Units.FormatToMm(Config."Plate Length"));
            JsonHelper.AddDecimalIfSet(Press, 'platePunchMm', PressSetup."Plate Punch (mm)");

            Press.Add('workStyles', WorkStyles(PressSetup));
            Presses.Add(Press);
        until PressSetup.Next() = 0;
    end;

    local procedure WorkStyles(PressSetup: Record "PEQI Press Setup") Styles: JsonArray
    var
        Style: Text;
    begin
        foreach Style in PressSetup.WorkStyleList() do
            Styles.Add(Style);
    end;

    local procedure PressName(PressSetup: Record "PEQI Press Setup"; Config: Record "PVS Cost Center Configuration"): Text
    begin
        if Config.Name <> '' then
            exit(Config.Name);
        exit(PressSetup."Cost Center Code");
    end;

    local procedure PressType(PressSetup: Record "PEQI Press Setup"; Config: Record "PVS Cost Center Configuration"): Enum "PEQI Press Type"
    begin
        if PressSetup."Use Press Type Override" then
            exit(PressSetup."Press Type Override");
        // Printing Machine is the field that names the press technology and has
        // an explicit Digital member. Imaging describes proofing and platesetting,
        // so a platesetter-driven offset press reads as Digital there.
        if Config."Printing Machine" = Config."Printing Machine"::Digital then
            exit("PEQI Press Type"::Digital);
        exit("PEQI Press Type"::Offset);
    end;

    local procedure GuidText(Value: Guid): Text
    begin
        exit(LowerCase(DelChr(Format(Value), '=', '{}')));
    end;

    /// <summary>Which fold patterns this shop runs, from PrintVis's own imposition
    /// catalogue. Without this the request inherits whatever the host has marked,
    /// and two hosts answer the same body differently.</summary>
    procedure BuildFoldPatterns() Patterns: JsonArray
    var
        ImpositionCode: Record "PVS Imposition Code";
        Seen: Dictionary of [Code[20], Integer];
        Pattern: JsonObject;
    begin
        ImpositionCode.SetFilter("Folding Catalog Code (CIP4)", '<>%1', '');
        if not ImpositionCode.FindSet() then
            exit;

        repeat
            if not Seen.ContainsKey(ImpositionCode."Folding Catalog Code (CIP4)") then begin
                Seen.Add(ImpositionCode."Folding Catalog Code (CIP4)", 1);
                Clear(Pattern);
                JsonHelper.AddText(Pattern, 'patternId', ImpositionCode."Folding Catalog Code (CIP4)");
                JsonHelper.AddInteger(Pattern, 'preference', 0);
                Patterns.Add(Pattern);
            end;
        until ImpositionCode.Next() = 0;
    end;
}
