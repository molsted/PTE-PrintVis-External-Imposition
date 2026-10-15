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
using PrintersEquity.ExternalImposition.Mapping;
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
    procedure AStoredTicketReadsBackWhole()
    var
        JdfTicket: Record "PEQI Jdf Ticket";
        TicketId: Guid;
        Written: Text;
    begin
        // [GIVEN] a ticket the way the engine writes it: indented, one element per line
        Written := Lines('<?xml version="1.0" encoding="utf-8"?>', '<JDF ID="ID_Node_1">', '  <AuditPool />', '</JDF>');
        TicketId := CreateGuid();
        JdfTicket.Init();
        JdfTicket."Ticket Id" := TicketId;
        JdfTicket.SetJdf(Written);
        JdfTicket.Insert(true);

        // [WHEN] it is read back
        JdfTicket.Get(TicketId);

        // [THEN] every line comes back, not only the XML declaration
        Assert.AreEqual(Written, JdfTicket.GetJdf(), 'A multi-line ticket reads back whole');
    end;

    [Test]
    procedure AMultiLineRequestSurvivesARoundTrip()
    var
        ImpositionJob: Record "PEQI Imposition Job";
        Written: Text;
    begin
        // [GIVEN] an entry, and a request with line breaks in it
        ImpositionJob := ImpositionJob.NewEntry(4713, 1, 1);
        Written := Lines('{', '  "parts": [ { "name": "Body", "pageCount": 32 } ]', '}', '');

        // [WHEN] it is stored and read back
        ImpositionJob.SetRequestJson(Written);
        ImpositionJob.Modify(true);
        ImpositionJob.Get(4713, 1, 1, ImpositionJob."Entry No.");

        // [THEN] all of it comes back
        Assert.AreEqual(Written, ImpositionJob.GetRequestJson(), 'A multi-line request reads back whole');
    end;

    /// <summary>Joins up to four lines with line feeds. A blank last line ends the text with one.</summary>
    local procedure Lines(First: Text; Second: Text; Third: Text; Fourth: Text): Text
    var
        LineFeed: Char;
        Separator: Text;
    begin
        LineFeed := 10;
        Separator := Format(LineFeed);
        if Fourth = '' then
            exit(First + Separator + Second + Separator + Third + Separator);
        exit(First + Separator + Second + Separator + Third + Separator + Fourth);
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

    [Test]
    procedure TheSeedStatesWhatTheOperatorMayDo()
    var
        RequestBuilder: Codeunit "PEQI Request Builder";
        Options: JsonObject;
        Token: JsonToken;
        Allowed: Boolean;
        DisplayUnits: Text;
    begin
        // [WHEN] the seed options are built for an entry
        Options.ReadFrom(RequestBuilder.SeedOptions('4711-1-1-1'));

        // [THEN] every operator starts on the simple view, whatever their permissions
        Assert.IsTrue(Options.Get('mode', Token), 'The seed states a mode');
        Assert.AreEqual('approve', Token.AsValue().AsText(), 'Everyone starts on the simple view');

        // [THEN] and the seed says, as a boolean, whether the full editor may be offered. Its value
        // is the running user's own write access, which a test codeunit cannot vary, so only its
        // presence and type are pinned here; AsBoolean errors on anything that is not one.
        Assert.IsTrue(Options.Get('fullEditorAllowed', Token), 'The seed says whether the full editor is allowed');
        Allowed := Token.AsValue().AsBoolean();

        // [THEN] and the entry key still rides along, because the editor echoes it back
        Assert.IsTrue(Options.Get('entryKey', Token), 'The seed carries the entry key');
        Assert.AreEqual('4711-1-1-1', Token.AsValue().AsText(), 'The entry key is unchanged');

        // [THEN] and, when the installation's format unit is one the editor knows, it is named
        if Options.Get('units', Token) then begin
            DisplayUnits := Token.AsValue().AsText();
            Assert.IsTrue((DisplayUnits = 'mm') or (DisplayUnits = 'cm') or (DisplayUnits = 'inch'),
                          'The display unit is one the editor knows, not ' + DisplayUnits);
        end;
    end;
}
