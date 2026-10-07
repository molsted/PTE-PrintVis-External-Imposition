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
