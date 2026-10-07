// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Setup;

using PrintersEquity.ExternalImposition.Mapping;
using Microsoft.Inventory.Item;

/// <summary>Restates paper thickness in the unit PrintVis says it is in.</summary>
/// <remarks>
/// <para>
/// <c>Insert_Defaults_US</c> defines Paper Thickness as Points with a factor of a thousand, so a
/// 70 lb book paper should read 3.8. This database holds 0.0038 -- the same caliper written in
/// inches, which is the format unit. Everything that reads the field through PrintVis's own
/// arithmetic therefore reads it a thousand times too thin, this module included until it was
/// taught to tolerate it.
/// </para>
/// <para>
/// <b>Not PrintVis's own converter.</b> "PVS Upgrade Convert Std Units" exists and does more than
/// is wanted: it restates formats, reel lengths and weights as well, for a database changing
/// between metric and US. Here the formats and the weights are already right -- a 28 x 40 inch
/// sheet at 70 lb book is exactly what it should be -- and only the thickness is in the wrong
/// unit. Running the full conversion would break the two that work to fix the one that does not.
/// </para>
/// <para>
/// <b>Only rows that are wrong.</b> Each item is read both ways and converted only where the
/// stored value cannot be a sheet of paper and the converted one can. So it is safe to run twice:
/// the second pass finds every row already plausible and changes nothing. A database that was
/// always right is left alone entirely.
/// </para>
/// </remarks>
codeunit 50547 "PEQI Thickness Data Fix"
{
    var
        Units: Codeunit "PEQI Unit Converter";
        PreviewMsg: Label '%1 of %2 paper items record a thickness that cannot be a sheet of paper.\\\nExample: %3 reads %4 and would become %5, which is %6 microns.\\\nNothing has been changed.', Comment = '%1 wrong, %2 total, %3 item, %4 stored, %5 corrected, %6 microns';
        NothingToDoMsg: Label 'All %1 paper items already record a thickness in the unit PrintVis states. Nothing to change.', Comment = '%1 count';
        ConfirmQst: Label 'Restate the thickness of %1 paper items, multiplying each by %2 so it reads in the unit PrintVis states?\\\nThis changes the item master and cannot be undone from here.', Comment = '%1 count, %2 factor';
        DoneMsg: Label 'Restated %1 paper items.', Comment = '%1 count';
        NoFactorMsg: Label 'The Paper Thickness unit records no factor, or expresses caliper per unit weight. There is nothing to restate.';

    /// <summary>Reports what would change, and changes nothing.</summary>
    procedure Preview()
    var
        Item: Record Item;
        Wrong: Integer;
        Total: Integer;
        FirstName: Text;
        FirstStored: Decimal;
        FirstFixed: Decimal;
    begin
        if Factor() <= 1 then begin
            Message(NoFactorMsg);
            exit;
        end;

        Item.SetFilter("PVS Thickness", '<>%1', 0);
        if Item.FindSet() then
            repeat
                Total += 1;
                if NeedsRestating(Item) then begin
                    Wrong += 1;
                    if Wrong = 1 then begin
                        FirstName := Item.Description;
                        FirstStored := Item."PVS Thickness";
                        FirstFixed := Item."PVS Thickness" * Factor();
                    end;
                end;
            until Item.Next() = 0;

        if Wrong = 0 then begin
            Message(NothingToDoMsg, Total);
            exit;
        end;

        Message(PreviewMsg, Wrong, Total, FirstName, FirstStored, FirstFixed,
                Round(FirstFixed * Units.MicronsPerStoredUnit(Item), 0.1, '='));
    end;

    /// <summary>Restates the rows that are wrong, after confirmation.</summary>
    procedure Apply()
    var
        Item: Record Item;
        Changed: Integer;
        Wrong: Integer;
    begin
        if Factor() <= 1 then begin
            Message(NoFactorMsg);
            exit;
        end;

        Item.SetFilter("PVS Thickness", '<>%1', 0);
        if Item.FindSet() then
            repeat
                if NeedsRestating(Item) then
                    Wrong += 1;
            until Item.Next() = 0;

        if Wrong = 0 then begin
            Message(NothingToDoMsg, 0);
            exit;
        end;

        if not Confirm(ConfirmQst, false, Wrong, Factor()) then
            exit;

        if Item.FindSet() then
            repeat
                if NeedsRestating(Item) then begin
                    Item."PVS Thickness" := Item."PVS Thickness" * Factor();
                    Item.Modify(true);
                    Changed += 1;
                end;
            until Item.Next() = 0;

        Message(DoneMsg, Changed);
    end;

    /// <summary>Thickness units in one format unit, from the Paper Thickness row.</summary>
    /// <remarks>
    /// One where caliper is expressed per unit weight -- the metric Bulk scheme -- because the
    /// stored number is then a bulk rather than a length and no multiplication restates it.
    /// </remarks>
    local procedure Factor(): Decimal
    var
        ThicknessUnit: Record "PVS Standard Units";
    begin
        if not ThicknessUnit.Get(ThicknessUnit.Type::"Paper Thickness", '') then
            exit(1);
        if ThicknessUnit."Per Paper Weight" then
            exit(1);
        exit(ThicknessUnit."Format Factor");
    end;

    /// <summary>
    /// Whether this item's thickness reads as something other than paper, and would read as paper
    /// once restated.
    /// </summary>
    local procedure NeedsRestating(Item: Record Item): Boolean
    var
        Stored: Decimal;
        Restated: Decimal;
    begin
        Stored := Item."PVS Thickness" * Units.MicronsPerStoredUnit(Item);
        Restated := Item."PVS Thickness" * Factor() * Units.MicronsPerStoredUnit(Item);
        exit((Stored < 10) and (Restated >= 10) and (Restated <= 2000));
    end;

}
