// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Tests;

using PrintersEquity.ExternalImposition.Mapping;
using System.TestLibraries.Utilities;

codeunit 50621 "PEQI Unit Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Units: Codeunit "PEQI Unit Converter";

    [Test]
    procedure TheUnitIsReadFromThePrintVisFactor()
    begin
        // [THEN] the three units PrintVis installations use are recognised by their factor
        Assert.AreEqual('mm', Units.UnitSymbolForFactor(1000), '1 000 microns is a millimetre');
        Assert.AreEqual('cm', Units.UnitSymbolForFactor(10000), '10 000 microns is a centimetre');
        Assert.AreEqual('in', Units.UnitSymbolForFactor(25400), '25 400 microns is an inch');
        // [THEN] and anything else is not guessed at
        Assert.AreEqual('', Units.UnitSymbolForFactor(12345), 'An unknown factor gives no symbol');
    end;

    [Test]
    procedure TheEditorIsToldTheUnitInItsOwnSpelling()
    begin
        Assert.AreEqual('mm', Units.DisplayUnitsForFactor(1000), 'Millimetres');
        Assert.AreEqual('cm', Units.DisplayUnitsForFactor(10000), 'Centimetres');
        Assert.AreEqual('inch', Units.DisplayUnitsForFactor(25400), 'The editor spells inches inch');
        Assert.AreEqual('', Units.DisplayUnitsForFactor(12345), 'An unknown factor is not sent');
    end;

    [Test]
    procedure ACaptionCarriesItsUnit()
    begin
        Assert.AreEqual('3,Plate Punch (in)', Units.CaptionWithUnit('Plate Punch', 'in'), 'The unit follows the caption');
        Assert.AreEqual('3,Plate Punch', Units.CaptionWithUnit('Plate Punch', ''), 'No symbol, no empty brackets');
    end;

    [Test]
    procedure AFractionalInchSurvivesTheRounding()
    begin
        // [THEN] 1/16 in is 1.5875 mm and arrives as exactly that, not 1.59
        Assert.AreEqual(1.5875, Units.RoundLength(1.5875), 'Four decimals are kept');
        Assert.AreEqual(1.5875, Units.RoundLength(1.58754), 'A fifth is rounded away');
    end;
}
