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

/// <summary>The job's own sheets, grouped into the substrates the engine is sent.</summary>
/// <remarks>
/// <para>
/// PrintVis gives every job item its own sheet, so a text block of three signatures is three job
/// sheets on the same paper at the same printing format. Sent as three substrates, the engine
/// would treat them as three stocks and split one run into three. So sheets are grouped by
/// paper item and printing format, and each group is one substrate whose id is the lowest Sheet
/// ID in it -- a globally unique integer, which is what the engine's substrate id needs.
/// </para>
/// <para>
/// Only sheets a job item points at are read. A sheet nobody points at is not being imposed.
/// </para>
/// </remarks>
codeunit 50565 "PEQI Job Sheet Reader"
{
    var
        SubstrateOfSheet: Dictionary of [Integer, Integer];
        Substrates: List of [Integer];

    /// <summary>Read the version's sheets. Replaces anything loaded before.</summary>
    procedure Load(CaseId: Integer; JobNo: Integer; VersionNo: Integer)
    var
        JobItem: Record "PVS Job Item";
        JobSheet: Record "PVS Job Sheet";
        Referenced: List of [Integer];
        LowestOfKey: Dictionary of [Text, Integer];
        KeyOfSheet: Dictionary of [Integer, Text];
        SheetId: Integer;
        GroupKey: Text;
    begin
        Clear(SubstrateOfSheet);
        Clear(Substrates);

        // "Active" is deliberately not filtered on: PrintVis leaves it false on rows that print.
        JobItem.SetRange(ID, CaseId);
        JobItem.SetRange(Job, JobNo);
        JobItem.SetRange(Version, VersionNo);
        JobItem.SetFilter("Sheet ID", '<>%1', 0);
        if JobItem.FindSet() then
            repeat
                if not Referenced.Contains(JobItem."Sheet ID") then
                    Referenced.Add(JobItem."Sheet ID");
            until JobItem.Next() = 0;

        // Ascending Sheet ID, so the lowest of each group is met first and the order the
        // substrates are sent in is the same on every build.
        JobSheet.SetCurrentKey("Sheet ID");
        JobSheet.SetRange(ID, CaseId);
        JobSheet.SetRange(Job, JobNo);
        JobSheet.SetRange(Version, VersionNo);
        if JobSheet.FindSet() then
            repeat
                if Referenced.Contains(JobSheet."Sheet ID") then begin
                    GroupKey := GroupKeyOf(JobSheet);
                    KeyOfSheet.Add(JobSheet."Sheet ID", GroupKey);
                    if not LowestOfKey.ContainsKey(GroupKey) then begin
                        LowestOfKey.Add(GroupKey, JobSheet."Sheet ID");
                        Substrates.Add(JobSheet."Sheet ID");
                    end;
                end;
            until JobSheet.Next() = 0;

        foreach SheetId in KeyOfSheet.Keys() do
            SubstrateOfSheet.Add(SheetId, LowestOfKey.Get(KeyOfSheet.Get(SheetId)));
    end;

    /// <summary>The substrate a sheet belongs to; 0 for a sheet that was not loaded.</summary>
    procedure SubstrateIdOf(SheetId: Integer): Integer
    begin
        if SubstrateOfSheet.ContainsKey(SheetId) then
            exit(SubstrateOfSheet.Get(SheetId));
        exit(0);
    end;

    /// <summary>Every substrate, ascending -- each is the Sheet ID of its group's first sheet.</summary>
    procedure SubstrateIds(): List of [Integer]
    begin
        exit(Substrates);
    end;

    /// <summary>Paper and printing format, with the format order-insensitive: a 640 x 450 and a
    /// 450 x 640 printing format are the same press sheet.</summary>
    local procedure GroupKeyOf(JobSheet: Record "PVS Job Sheet"): Text
    var
        LongEdge: Decimal;
        ShortEdge: Decimal;
    begin
        LongEdge := JobSheet.Length;
        ShortEdge := JobSheet.Width;
        if ShortEdge > LongEdge then begin
            LongEdge := JobSheet.Width;
            ShortEdge := JobSheet.Length;
        end;
        exit(JobSheet."Paper Item No." + '|' + Format(LongEdge, 0, 9) + '|' + Format(ShortEdge, 0, 9));
    end;
}
