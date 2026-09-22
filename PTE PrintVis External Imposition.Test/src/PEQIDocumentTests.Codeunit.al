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

using PrintersEquity.ExternalImposition.Document;
using System.TestLibraries.Utilities;

codeunit 50615 "PEQI Document Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure ResolvingOpensANewEntryAndLeavesTheOldOne()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        First: Record "PEQI Imposition Job";
        Second: Record "PEQI Imposition Job";
    begin
        // [GIVEN] a solved entry for a job version
        First := ImpositionJob.NewEntry(4711, 1, 1);
        First.Status := First.Status::Committed;
        First.Modify(true);

        // [WHEN] the job is re-solved
        Second := ImpositionJob.NewEntry(4711, 1, 1);

        // [THEN] a new entry is opened and the committed one is untouched
        Assert.AreEqual(First."Entry No." + 1, Second."Entry No.", 'Re-solve opens the next entry');
        First.Get(4711, 1, 1, First."Entry No.");
        Assert.AreEqual(First.Status::Committed, First.Status, 'The previous entry keeps its status');
        Assert.AreEqual(Second.Status::Draft, Second.Status, 'A new entry starts as Draft');
    end;

    [Test]
    procedure RequestJsonSurvivesARoundTrip()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        Written: Text;
    begin
        // [GIVEN] an entry
        ImpositionJob := ImpositionJob.NewEntry(4712, 1, 1);
        Written := '{"parts":[{"name":"Body","pageCount":32}]}';

        // [WHEN] a request is stored and read back
        ImpositionJob.SetRequestJson(Written);
        ImpositionJob.Modify(true);
        ImpositionJob.Get(4712, 1, 1, ImpositionJob."Entry No.");

        // [THEN] it is byte-identical
        Assert.AreEqual(Written, ImpositionJob.GetRequestJson(), 'Request JSON round-trips');
    end;
}
