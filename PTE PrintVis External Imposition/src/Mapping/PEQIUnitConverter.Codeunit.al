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

/// <summary>Converts PrintVis's linear measurements into the millimetres the engine's
/// contract is written in.</summary>
/// <remarks>
/// PrintVis stores every format, margin and trim in whichever unit the installation is set
/// to - "PVS General Setup"."General Unit", one of Centimeter, Millimeter or Inches - and the
/// field names carry no unit. The engine's do: every dimension it takes is named `...Mm` and
/// is read as millimetres.
/// <para>
/// Nothing converted them, so an imperial installation sent a 28 x 40 inch sheet as 28 x 40
/// millimetres and a 102 x 73 cm press as 40 x 29 millimetres. Neither errors - they are
/// perfectly good numbers - and the solve simply returns nothing, because no page fits a sheet
/// the size of a postage stamp.
/// </para>
/// <para>
/// Read once per build and cached: the setup is a singleton and a request touches every paper
/// and every press.
/// </para>
/// </remarks>
codeunit 50545 "PEQI Unit Converter"
{
    SingleInstance = false;

    var
        FactorToMm: Decimal;
        Loaded: Boolean;

    /// <summary>Millimetres per unit of whatever PrintVis is storing.</summary>
    procedure MmPerUnit(): Decimal
    var
        GeneralSetup: Record "PVS General Setup";
    begin
        if Loaded then
            exit(FactorToMm);

        Loaded := true;
        // Millimetres unless the setup says otherwise. A missing setup row is a PrintVis that
        // has not been configured, and metric is both the engine's unit and the common case;
        // guessing imperial there would scale a correct request by 25.
        FactorToMm := 1;

        if GeneralSetup.Get() then
            case GeneralSetup."General Unit" of
                GeneralSetup."General Unit"::Centimeter:
                    FactorToMm := 10;
                GeneralSetup."General Unit"::Millimeter:
                    FactorToMm := 1;
                GeneralSetup."General Unit"::Inches:
                    FactorToMm := 25.4;
            end;

        exit(FactorToMm);
    end;

    /// <summary>One PrintVis micro-measurement -- paper thickness -- in microns.</summary>
    /// <remarks>
    /// <para>
    /// PrintVis keeps thickness in a <i>micro unit</i>: a thousandth of the general unit, with
    /// its own decimal setting ("Micro Unit Decimals"). So the stored number means mil on an
    /// imperial installation, microns on a millimetre one and hundredths of a millimetre on a
    /// centimetre one -- and a thousandth of the general unit, expressed in microns, is exactly
    /// the millimetres-per-unit factor. Hence the same number serves both conversions.
    /// </para>
    /// <para>
    /// Established from real data rather than assumed, because the unit is not written down
    /// anywhere. One Dull Coated EuroArt at two weights came through as 3.80228 and 4.29184:
    /// </para>
    /// <code>
    ///   reading              70 gsm      80 gsm     bulk 70   bulk 80
    ///   as stored              3.80 um     4.29 um     0.054     0.054
    ///   x1000 (as mm)       3802.28 um  4291.85 um    54.318    53.648
    ///   x25.4 (as mil)        96.58 um   109.01 um     1.380     1.363
    /// </code>
    /// <para>
    /// Paper bulk runs about 0.6 to 1.6 cm3/g, and two weights of one grade have to agree.
    /// Only the third reading is a real paper, and it agrees to within one percent across both.
    /// The other two are out by a factor of twenty-five and forty.
    /// </para>
    /// </remarks>
    procedure MicroUnitToMicrons(Value: Decimal): Decimal
    begin
        if Value = 0 then
            exit(0);
        exit(Round(Value * MmPerUnit(), 0.01, '='));
    end;

    /// <summary>One PrintVis length, in millimetres.</summary>
    /// <remarks>
    /// Rounded to two decimals. The engine works in millimetres and a press is set to a
    /// millimetre at best, so the sixth decimal of a converted inch is noise that would
    /// otherwise travel into the request and out again into a JDF ticket.
    /// </remarks>
    procedure ToMm(Value: Decimal): Decimal
    begin
        if Value = 0 then
            exit(0);
        exit(Round(Value * MmPerUnit(), 0.01, '='));
    end;
}
