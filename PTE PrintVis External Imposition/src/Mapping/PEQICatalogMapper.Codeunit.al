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

    /// <summary>The paper half. Dimensions, grammage, caliper and grain are read
    /// live from the item so they cannot drift from PrintVis; the setup row
    /// contributes the surrogate id, the mark, and overrides where PrintVis is silent.</summary>
    procedure BuildSheets() Sheets: JsonArray
    var
        PaperSetup: Record "PEQI Paper Setup";
        Item: Record Item;
        Setup: Record "PEQI Imposition Setup";
        Sheet: JsonObject;
        Grain: Enum "PEQI Sheet Grain";
    begin
        Setup := Setup.GetSetup();
        PaperSetup.SetRange("Use for Imposition", true);
        if not PaperSetup.FindSet() then
            exit;

        repeat
            if Item.Get(PaperSetup."Item No.") then begin
                Clear(Sheet);
                JsonHelper.AddInteger(Sheet, 'id', PaperSetup."Substrate Id");
                JsonHelper.AddText(Sheet, 'name', ItemName(Item));
                JsonHelper.AddText(Sheet, 'vendorSku', VendorSku(PaperSetup, Item));
                JsonHelper.AddDecimal(Sheet, 'widthMm', Item."PVS Format 1");
                JsonHelper.AddDecimal(Sheet, 'heightMm', Item."PVS Format 2");

                Grain := PaperSetup.EffectiveGrain();
                if Grain <> Grain::" " then
                    JsonHelper.AddText(Sheet, 'grain', Format(Grain, 0, 9));

                JsonHelper.AddDecimalIfSet(Sheet, 'grammageGsm', Grammage(PaperSetup, Item, Setup));
                JsonHelper.AddDecimalIfSet(Sheet, 'caliperMicrons', Caliper(PaperSetup, Item, Setup));
                Sheets.Add(Sheet);
            end;
        until PaperSetup.Next() = 0;
    end;

    local procedure ItemName(Item: Record Item): Text
    begin
        if Item."PVS Paper Description" <> '' then
            exit(Item."PVS Paper Description");
        exit(Item.Description);
    end;

    local procedure VendorSku(PaperSetup: Record "PEQI Paper Setup"; Item: Record Item): Text
    begin
        if PaperSetup."Vendor Sku Override" <> '' then
            exit(PaperSetup."Vendor Sku Override");
        exit(Item."PVS Paper No.");
    end;

    local procedure Grammage(PaperSetup: Record "PEQI Paper Setup"; Item: Record Item; Setup: Record "PEQI Imposition Setup"): Decimal
    begin
        if PaperSetup."Grammage Override (gsm)" <> 0 then
            exit(PaperSetup."Grammage Override (gsm)");
        exit(Setup.WeightToGsm(Item."PVS Weight"));
    end;

    local procedure Caliper(PaperSetup: Record "PEQI Paper Setup"; Item: Record Item; Setup: Record "PEQI Imposition Setup"): Decimal
    begin
        if PaperSetup."Caliper Override (microns)" <> 0 then
            exit(PaperSetup."Caliper Override (microns)");
        exit(Setup.ThicknessToMicrons(Item."PVS Thickness"));
    end;

    /// <summary>The press half. The measurements come from PrintVis's cost centre
    /// configuration; the edges, the image area and the work styles come from our
    /// setup, because PrintVis does not record them.</summary>
    procedure BuildPresses() Presses: JsonArray
    var
        PressSetup: Record "PEQI Press Setup";
        Config: Record "PVS Cost Center Configuration";
        Press: JsonObject;
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
            JsonHelper.AddText(Press, 'type', Format(PressType(PressSetup, Config), 0, 9));

            JsonHelper.AddDecimal(Press, 'maxSheetWidthMm', Config."Max Printing Format Width");
            JsonHelper.AddDecimal(Press, 'maxSheetHeightMm', Config."Max Printing Format Length");
            JsonHelper.AddDecimalIfSet(Press, 'minSheetWidthMm', Config."Min Print Format Width");
            JsonHelper.AddDecimalIfSet(Press, 'minSheetHeightMm', Config."Min Print Format Length");

            JsonHelper.AddDecimalIfSet(Press, 'nonPrintableMarginTopMm', PressSetup."Non-Printable Top (mm)");
            JsonHelper.AddDecimalIfSet(Press, 'nonPrintableMarginBottomMm', PressSetup."Non-Printable Bottom (mm)");
            JsonHelper.AddDecimalIfSet(Press, 'nonPrintableMarginLeftMm', PressSetup."Non-Printable Left (mm)");
            JsonHelper.AddDecimalIfSet(Press, 'nonPrintableMarginRightMm', PressSetup."Non-Printable Right (mm)");

            JsonHelper.AddDecimalIfSet(Press, 'gripperMarginMm', Config."Gripper Edge");
            if PressSetup."Gripper Edge Side" <> PressSetup."Gripper Edge Side"::" " then
                JsonHelper.AddText(Press, 'gripperEdge', Format(PressSetup."Gripper Edge Side", 0, 9));
            JsonHelper.AddDecimalIfSet(Press, 'sideLayMarginMm', Config.Pull);
            if PressSetup."Side Lay Edge" <> PressSetup."Side Lay Edge"::" " then
                JsonHelper.AddText(Press, 'sideLayEdge', Format(PressSetup."Side Lay Edge", 0, 9));

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
            JsonHelper.AddDecimalIfSet(Press, 'plateWidthMm', Config."Plate Width");
            JsonHelper.AddDecimalIfSet(Press, 'plateHeightMm', Config."Plate Length");
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
