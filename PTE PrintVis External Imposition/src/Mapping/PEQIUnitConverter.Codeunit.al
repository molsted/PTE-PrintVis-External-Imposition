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
using Microsoft.Inventory.Item;

/// <summary>Converts PrintVis's measurements into the units the engine's contract states.</summary>
/// <remarks>
/// <para>
/// Every factor here comes from PrintVis's own <c>PVS Unit Conversion</c> codeunit. An earlier
/// version of this file derived them from <c>"PVS General Setup"."General Unit"</c>, which looked
/// authoritative and is not: <c>Format2Micrometer</c> keys off <c>StdFormatUnit()</c> -- the
/// Description of the <i>Format</i> row in <c>PVS Standard Units</c> -- and the two can disagree.
/// On the installation this was written against they did: General Unit read Centimeter while the
/// papers were plainly 28 x 40 inch US book sheets, so every dimension went out 2.54 times too
/// small and the editor drew a 280 x 400 mm sheet nobody stocks.
/// </para>
/// <para>
/// <b>Formats and margins are not the same unit.</b> PrintVis keeps sheet and page formats in the
/// format unit, and gripper, pull, trims and overfolds in the margin unit -- and on a centimetre
/// installation those are centimetres and <i>millimetres</i> respectively.
/// <c>Margin2Micrometer</c> returns 1000 where <c>Format2Micrometer</c> returns 10000. One factor
/// for both is wrong by ten on exactly the measurements a gripper edge is made of.
/// </para>
/// <para>
/// Nothing is derived here that PrintVis already answers. That is the whole point of the file.
/// </para>
/// </remarks>
codeunit 50545 "PEQI Unit Converter"
{
    var
        UnitConversion: Codeunit "PVS Unit Conversion";
        NoGrammageUnitErr: Label 'No grammage weight unit is set on Imposition Setup, so paper weights cannot be converted. Choose the PrintVis weight unit that means grams per square metre.';

    /// <summary>A sheet or page format, in millimetres.</summary>
    procedure FormatToMm(Value: Decimal): Decimal
    begin
        if Value = 0 then
            exit(0);
        exit(Round(Value * UnitConversion.Format2Micrometer() / 1000, 0.01, '='));
    end;

    /// <summary>A gripper, pull, trim or overfold, in millimetres.</summary>
    /// <remarks>
    /// Separate from <see cref="FormatToMm"/> on purpose. See the remarks on this codeunit: a
    /// centimetre installation states formats in centimetres and margins in millimetres.
    /// </remarks>
    procedure MarginToMm(Value: Decimal): Decimal
    begin
        if Value = 0 then
            exit(0);
        exit(Round(Value * UnitConversion.Margin2Micrometer() / 1000, 0.01, '='));
    end;

    /// <summary>A paper's caliper, in microns.</summary>
    /// <remarks>
    /// Two conversions, because caliper has a unit of its own: <c>Caliper2Format</c> takes it into
    /// format units -- a tenth of a thousandth on a US setup entering mil, the grammage over ten
    /// thousand on a metric one -- and <c>Format2Micrometer</c> takes format units into microns.
    /// It depends on the paper's weight because some installations express caliper per unit
    /// weight, which is why the item is passed rather than a bare number.
    /// </remarks>
    procedure ThicknessToMicrons(Item: Record Item): Decimal
    var
        Caliper: Decimal;
    begin
        if Item."PVS Thickness" = 0 then
            exit(0);

        Caliper := UnitConversion.Caliper2Format(Item."PVS Weight", Item."PVS Weight Unit");
        if Caliper = 0 then
            Caliper := 1;

        exit(Round(Item."PVS Thickness" * Caliper * UnitConversion.Format2Micrometer(), 0.01, '='));
    end;

    /// <summary>A paper's weight in grams per square metre, whatever PrintVis records it in.</summary>
    /// <remarks>
    /// <b>Not a passthrough.</b> PrintVis records weight in a unit of the paper's own, and a US
    /// installation uses basis weights: the sample paper read "70" with unit BOOK, which is 70 lb
    /// book -- about 104 gsm, not 70. Sent raw it understated every paper by half, which the
    /// engine then measured press grammage limits and spines against.
    /// <para>
    /// The conversion needs a target unit, and the code for "grams per square metre" is the
    /// shop's own data rather than a constant, so it is named once on Imposition Setup. Basis
    /// weights also depend on the sheet size, which is why the formats are passed through.
    /// </para>
    /// </remarks>
    procedure WeightToGsm(Item: Record Item): Decimal
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        if Item."PVS Weight" = 0 then
            exit(0);

        Setup := Setup.GetSetup();
        if Setup."Grammage Weight Unit" = '' then
            Error(NoGrammageUnitErr);

        if Item."PVS Weight Unit" = Setup."Grammage Weight Unit" then
            exit(Item."PVS Weight");

        exit(Round(UnitConversion.Convert_PaperWeight(
            Item."PVS Weight", Item."PVS Weight Unit",
            Item."PVS Format 1", Item."PVS Format 2",
            Setup."Grammage Weight Unit"), 0.01, '='));
    end;
}
