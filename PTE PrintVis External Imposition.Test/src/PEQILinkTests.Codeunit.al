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

using PrintersEquity.ExternalImposition.Links;
using PrintersEquity.ExternalImposition.Setup;
using System.TestLibraries.Utilities;

codeunit 50626 "PEQI Link Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure TheSubjectNamesCompanyCaseJobAndVersion()
    var
        LinkSubject: Codeunit "PEQI Link Subject";
        Subject: Text;
        Parts: List of [Text];
        Company: Text;
        Position: Integer;
    begin
        // [WHEN] the subject of case 9040, job 1, version 2 is built
        Subject := LinkSubject."For"(9040, 1, 2);

        // [THEN] it is <company id>:9040:1:2, with no thousands separator in the case ID
        Parts := Subject.Split(':');
        Assert.AreEqual(4, Parts.Count(), 'Company id, case, job and version');
        Assert.AreEqual('9040', Parts.Get(2), 'The case ID is written plainly');
        Assert.AreEqual('1', Parts.Get(3), 'The job');
        Assert.AreEqual('2', Parts.Get(4), 'The version');

        // [THEN] the company id is a lowercase GUID in its hyphenated form, without braces: the
        // engine takes a subject in a URL path segment, where braces and capitals would be mangled
        Company := Parts.Get(1);
        Assert.AreEqual(36, StrLen(Company), 'A GUID in the standard hyphenated form');
        Assert.AreEqual(Company.ToLower(), Company, 'Lowercase hex');
        Assert.AreEqual(0, StrPos(Company, '{'), 'No opening brace');
        Assert.AreEqual(0, StrPos(Company, '}'), 'No closing brace');
        for Position := 1 to StrLen(Company) do
            if Position in [9, 14, 19, 24] then
                Assert.AreEqual('-', Format(Company[Position]), 'The standard GUID hyphens stay')
            else
                Assert.IsTrue(Company[Position] in ['0' .. '9', 'a' .. 'f'], 'Hex digits only');
    end;

    [Test]
    procedure SetupDefaults()
    var
        Setup: Record "PEQI Imposition Setup";
        Expected: DateFormula;
    begin
        // [GIVEN] no setup row yet
        if Setup.Get('') then
            Setup.Delete();
        Clear(Setup);

        // [WHEN] the singleton is created
        Setup := Setup.GetSetup();
        Setup.Get('');

        // [THEN] a link shows the book and takes files, but not the imposition, for 14 days
        Assert.IsFalse(Setup."Link Show Imposition", 'The imposition is off by default');
        Assert.IsTrue(Setup."Link Show Book", 'The book is on by default');
        Assert.IsTrue(Setup."Link Allow File Submission", 'File submission is on by default');
        Evaluate(Expected, '<14D>');
        Assert.AreEqual(Format(Expected), Format(Setup."Link Validity"), 'Fourteen days');
        Assert.AreEqual(10, Setup."Link Max Sessions", 'Ten sessions');
    end;

    [Test]
    procedure MaxSessionsStaysWithinOneAndAThousand()
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        asserterror Setup.Validate("Link Max Sessions", 0);
        asserterror Setup.Validate("Link Max Sessions", 1001);
        Setup.Validate("Link Max Sessions", 1);
        Setup.Validate("Link Max Sessions", 1000);
    end;
}
