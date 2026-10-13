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
        exit(RoundLength(Value * UnitConversion.Format2Micrometer() / 1000));
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
        exit(RoundLength(Value * UnitConversion.Margin2Micrometer() / 1000));
    end;

    /// <summary>A length in millimetres, to the precision it is sent to the engine at.</summary>
    /// <remarks>
    /// 0.0001 mm, not the 0.01 mm this used to be. The engine holds lengths as points in double
    /// precision, so BC's rounding was the only lossy step: at 0.01 mm, 1/16 in (1.5875 mm) went
    /// out as 1.59. At 0.0001 mm every length an inch, centimetre or millimetre installation can
    /// state arrives exactly, since 1 in is 25.4 mm by definition.
    /// </remarks>
    procedure RoundLength(Value: Decimal): Decimal
    begin
        exit(Round(Value, 0.0001, '='));
    end;

    /// <summary>The symbol for a PrintVis unit, from its size in microns.</summary>
    /// <remarks>
    /// From the factor, not from a description: a description is text in whatever language the
    /// installation was set up in, and the factor is the same number the conversions use, so the
    /// label and the arithmetic cannot disagree. Blank for a factor that is none of the three.
    /// </remarks>
    procedure UnitSymbolForFactor(MicronsPerUnit: Decimal): Text
    begin
        case MicronsPerUnit of
            1000:
                exit('mm');
            10000:
                exit('cm');
            25400:
                exit('in');
        end;
        exit('');
    end;

    /// <summary>The unit as the editor spells it, from its size in microns.</summary>
    procedure DisplayUnitsForFactor(MicronsPerUnit: Decimal): Text
    begin
        case MicronsPerUnit of
            1000:
                exit('mm');
            10000:
                exit('cm');
            25400:
                exit('inch');
        end;
        exit('');
    end;

    /// <summary>A literal CaptionClass for a caption with its unit in brackets.</summary>
    procedure CaptionWithUnit(BaseCaption: Text; Symbol: Text): Text
    begin
        if Symbol = '' then
            exit('3,' + BaseCaption);
        exit('3,' + BaseCaption + ' (' + Symbol + ')');
    end;

    /// <summary>The installation's format unit, for labels.</summary>
    procedure FormatUnitSymbol(): Text
    var
        Symbol: Text;
    begin
        Symbol := UnitSymbolForFactor(UnitConversion.Format2Micrometer());
        if Symbol <> '' then
            exit(Symbol);
        exit(StandardUnitDescription(0));
    end;

    /// <summary>The installation's margin unit, for labels.</summary>
    procedure MarginUnitSymbol(): Text
    var
        Symbol: Text;
    begin
        Symbol := UnitSymbolForFactor(UnitConversion.Margin2Micrometer());
        if Symbol <> '' then
            exit(Symbol);
        exit(StandardUnitDescription(1));
    end;

    /// <summary>A CaptionClass for a field measured in the format unit.</summary>
    procedure FormatCaptionClass(BaseCaption: Text): Text
    begin
        exit(CaptionWithUnit(BaseCaption, FormatUnitSymbol()));
    end;

    /// <summary>A CaptionClass for a field measured in the margin unit.</summary>
    procedure MarginCaptionClass(BaseCaption: Text): Text
    begin
        exit(CaptionWithUnit(BaseCaption, MarginUnitSymbol()));
    end;

    /// <summary>The installation's format unit as the editor spells it; blank if unknown.</summary>
    procedure FormatDisplayUnits(): Text
    begin
        exit(DisplayUnitsForFactor(UnitConversion.Format2Micrometer()));
    end;

    /// <summary>PrintVis's own description of a standard unit, when the factor is unfamiliar.</summary>
    /// <remarks>Ordinal 0 is the Format row and 1 the Margins row of PVS Standard Units.Type.</remarks>
    local procedure StandardUnitDescription(TypeOrdinal: Integer): Text
    var
        StandardUnit: Record "PVS Standard Units";
    begin
        StandardUnit.SetRange(Type, TypeOrdinal);
        if StandardUnit.FindFirst() then
            exit(StandardUnit.Description);
        exit('');
    end;


    /// <summary>The thinnest caliper, in microns, that could be a sheet of paper.</summary>
    /// <remarks>
    /// Tissue is around 30. Nothing a press feeds is in single figures, so a result below this is
    /// not a thin paper, it is a misread unit.
    /// </remarks>
    local procedure MinPlausibleMicrons(): Decimal
    begin
        exit(10);
    end;

    /// <summary>Microns in one unit of stored thickness, by the book.</summary>
    /// <remarks>
    /// The conversion <see cref="ThicknessToMicrons"/> tries first, without its tolerance. Exists
    /// so the data fix can tell a row that disagrees with its unit from one that does not --
    /// asking the tolerant reading would always answer "already correct", which is the whole
    /// point of the tolerance and exactly the wrong question here.
    /// </remarks>
    procedure MicronsPerStoredUnit(Item: Record Item): Decimal
    begin
        exit(UnitConversion.Caliper2Format(Item."PVS Weight", Item."PVS Weight Unit")
             * UnitConversion.Format2Micrometer());
    end;

    /// <summary>A paper's caliper, in microns.</summary>
    /// <remarks>
    /// <para>
    /// The first reading is PrintVis's own: thickness is held in the Paper Thickness unit, and
    /// <c>Caliper2Format</c> converts it to format units — a thousandth on a US setup recording
    /// points, bulk times grammage over ten thousand on a metric one. The same composition
    /// PrintVis itself uses in <c>PVSJobCostingJournalLine</c>.
    /// </para>
    /// <para>
    /// <b>The fallback is for data that disagrees with its own unit.</b>
    /// <c>Insert_Defaults_US</c> defines Paper Thickness as Points with a factor of a thousand,
    /// so a 70 lb book paper should read 3.8. The installation this was written against holds
    /// 0.0038 — the same caliper expressed in inches, which is the format unit. Read by the book
    /// that is 0.0965 microns, which rounds to nothing and drops the field, and the engine then
    /// reports that the substrate records no caliper and cannot work out creep or a spine.
    /// </para>
    /// <para>
    /// So both readings are computed and the plausible one is taken. The two differ by exactly
    /// the unit''s own factor, and only one of them can be a sheet of paper, so there is nothing
    /// to choose between beyond arithmetic. A shop whose data matches its setup never reaches the
    /// second reading.
    /// </para>
    /// <para>
    /// This is a tolerance, not a cure: the data and the Paper Thickness unit genuinely disagree,
    /// and the clean fix is to make one of them match the other. Until then a right answer beats
    /// a dropped field.
    /// </para>
    /// </remarks>
    procedure ThicknessToMicrons(Item: Record Item): Decimal
    begin
        exit(ThicknessToMicrons(Item."PVS Thickness", Item."PVS Weight", Item."PVS Weight Unit"));
    end;

    /// <summary>The same reading, from a thickness and weight held anywhere — a job sheet's own.</summary>
    procedure ThicknessToMicrons(Thickness: Decimal; Weight: Decimal; WeightUnitCode: Code[10]): Decimal
    var
        ByUnit: Decimal;
        AsFormatUnits: Decimal;
        Caliper: Decimal;
    begin
        if Thickness = 0 then
            exit(0);

        Caliper := UnitConversion.Caliper2Format(Weight, WeightUnitCode);
        ByUnit := Thickness * Caliper * UnitConversion.Format2Micrometer();
        if ByUnit >= MinPlausibleMicrons() then
            exit(Round(ByUnit, 0.01, '='));

        // Read as though the stored value were already in format units.
        AsFormatUnits := Thickness * UnitConversion.Format2Micrometer();
        if AsFormatUnits >= MinPlausibleMicrons() then
            exit(Round(AsFormatUnits, 0.01, '='));

        // Neither is a paper. Nothing is sent, and the engine says the caliper is unrecorded --
        // which is true, and better than a number that is not one.
        exit(0);
    end;

    /// <summary>A paper's weight in grams per square metre, whatever PrintVis records it in.</summary>
    /// <remarks>
    /// <para>
    /// Computed here rather than handed to <c>Convert_PaperWeight</c>, which cannot do it:
    /// that procedure is a pure area ratio between two weight units and never converts <i>mass</i>,
    /// so pounds come out of it as pounds. On a US installation the question does not arise
    /// anyway, because <c>Insert_Defaults_US</c> creates Bond, Cover, Bristol, Tag, Book and
    /// Index and <b>no grammage row at all</b> — there is nothing to convert to.
    /// </para>
    /// <para>
    /// What the table does give is the reference area a weight is quoted over.
    /// <c>Create_US_Weight(''Book'', 25, 38)</c> sets Quantity 500 and a 25 x 38 basis size, so
    /// BOOK is the weight of a 500-sheet ream of 25 x 38 inch paper; the metric default sets
    /// Quantity 1000 over 100 x 100 cm, which is a thousand square metres. Divide the mass by
    /// that area and the answer is grammage, in any system.
    /// </para>
    /// <para>
    /// <b>The one thing the table does not record is the mass unit</b> — pounds against
    /// kilogrammes — and it does not need to, because PrintVis seeds the pair together: the
    /// procedure that writes the pound-basis rows writes the inch format row beside them, and
    /// the one that writes the kilogramme row writes centimetres. The format unit is therefore
    /// the honest tell, and it is read rather than assumed.
    /// </para>
    /// <para>
    /// Checked against the sample: 70 BOOK over 500 x 25 x 38 in is 306.45 m2 carrying
    /// 31,751 g, which is 103.6 gsm — against 70 sent raw, and a bulk that finally agrees with
    /// the caliper.
    /// </para>
    /// </remarks>
    procedure WeightToGsm(Item: Record Item): Decimal
    begin
        exit(WeightToGsm(Item."PVS Weight", Item."PVS Weight Unit", Item."PVS Format 1", Item."PVS Format 2"));
    end;

    /// <summary>The same conversion, from a weight held anywhere. Format1/Format2 are the sheet a
    /// basis-less weight unit is quoted over — the purchased sheet.</summary>
    procedure WeightToGsm(Weight: Decimal; WeightUnitCode: Code[10]; Format1: Decimal; Format2: Decimal): Decimal
    var
        WeightUnit: Record "PVS Standard Units";
        AreaSqM: Decimal;
    begin
        if Weight = 0 then
            exit(0);
        if not WeightUnit.Get(WeightUnit.Type::"Paper weight", WeightUnitCode) then
            exit(0);

        // A row with no basis size quotes the weight over the paper's own sheet.
        if WeightUnit."Format 1" = 0 then
            AreaSqM := WeightUnit.Quantity * SquareMetres(Format1, Format2)
        else
            AreaSqM := WeightUnit.Quantity * SquareMetres(WeightUnit."Format 1", WeightUnit."Format 2");

        if AreaSqM = 0 then
            exit(0);

        exit(Round(Weight * GramsPerWeightUnit() / AreaSqM, 0.01, '='));
    end;

    /// <summary>Two format measurements as an area in square metres.</summary>
    local procedure SquareMetres(Format1: Decimal; Format2: Decimal): Decimal
    var
        MicronsPerUnit: Decimal;
    begin
        MicronsPerUnit := UnitConversion.Format2Micrometer();
        exit((Format1 * MicronsPerUnit / 1000000) * (Format2 * MicronsPerUnit / 1000000));
    end;

    /// <summary>Grams in one unit of recorded paper weight.</summary>
    /// <remarks>
    /// Pounds where formats are inches, kilogrammes otherwise. See <see cref="WeightToGsm"/>:
    /// PrintVis seeds the weight rows and the format row together, so the format unit is what
    /// says which system the weights are in.
    /// </remarks>
    local procedure GramsPerWeightUnit(): Decimal
    begin
        if UnitConversion.Format2Micrometer() = 25400 then
            exit(453.59237);
        exit(1000);
    end;
}
