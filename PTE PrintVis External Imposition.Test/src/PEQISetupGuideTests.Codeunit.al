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

using PrintersEquity.ExternalImposition.Enums;
using PrintersEquity.ExternalImposition.Setup;
using System.Environment;
using System.TestLibraries.Utilities;

codeunit 50624 "PEQI Setup Guide Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Checks: Codeunit "PEQI Setup Checks";
        GuideMgt: Codeunit "PEQI Setup Guide Mgt.";

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure WarningsAloneCompleteTheGuide()
    var
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        Checks.AddFinding(Findings, "PEQI Setup Area"::ComponentTypes, "PEQI Finding Severity"::Warning, 'A component type is not set up.');

        Assert.IsTrue(GuideMgt.UpdateCompletion(Findings), 'Only warnings: the guide is complete');
        Assert.IsTrue(GuideMgt.IsComplete(), 'And Assisted Setup says so');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ABlockingFindingKeepsTheGuideIncomplete()
    var
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        Checks.AddFinding(Findings, "PEQI Setup Area"::Presses, "PEQI Finding Severity"::Blocking, 'No press is marked.');

        Assert.IsFalse(GuideMgt.UpdateCompletion(Findings), 'A blocking finding: not complete');
        Assert.IsFalse(GuideMgt.IsComplete(), 'And Assisted Setup says so');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ABlockingFindingThatReappearsResetsTheGuide()
    var
        Findings: Record "PEQI Setup Finding" temporary;
    begin
        // [GIVEN] a guide completed with nothing open
        Assert.IsTrue(GuideMgt.UpdateCompletion(Findings), 'Nothing open: complete');

        // [WHEN] a blocking problem appears and the checks run again
        Checks.AddFinding(Findings, "PEQI Setup Area"::Connection, "PEQI Finding Severity"::Blocking, 'The engine did not answer.');
        GuideMgt.UpdateCompletion(Findings);

        // [THEN] it is not complete any more
        Assert.IsFalse(GuideMgt.IsComplete(), 'A blocking problem that reappears resets the guide');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    [HandlerFunctions('BlockingRemainsMessageHandler')]
    procedure TheGuideWalksFromWelcomeToFinish()
    var
        Setup: Record "PEQI Imposition Setup";
        Guide: TestPage "PEQI Setup Guide";
        Step: Integer;
    begin
        // [GIVEN] no engine URL -- blocking, and it keeps the guide off the network
        Setup := Setup.GetSetup();
        Setup.Get('');
        Setup."Engine Base Url" := '';
        Setup.Modify(false);

        // [WHEN] the guide is walked from the first step to the last and finished
        Guide.OpenEdit();
        Assert.IsFalse(Guide.ActionBack.Enabled(), 'There is no step before the first');
        Assert.IsTrue(Guide.ActionFinish.Enabled(), 'Finish is available on the first step');
        for Step := 1 to 8 do
            Guide.ActionNext.Invoke();
        Assert.IsFalse(Guide.ActionNext.Enabled(), 'There is no step after the last');
        Guide.ActionFinish.Invoke();

        // [THEN] the missing URL keeps it incomplete, and the handler saw the message saying so
        Assert.IsFalse(GuideMgt.IsComplete(), 'A missing engine URL keeps the guide incomplete');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OpeningTheGuideResetsACompletionThatNoLongerHolds()
    var
        Setup: Record "PEQI Imposition Setup";
        Findings: Record "PEQI Setup Finding" temporary;
        Guide: TestPage "PEQI Setup Guide";
    begin
        // [GIVEN] a completed guide, and then the engine URL is cleared
        GuideMgt.UpdateCompletion(Findings);
        Setup := Setup.GetSetup();
        Setup.Get('');
        Setup."Engine Base Url" := '';
        Setup.Modify(false);

        // [WHEN] the guide is opened and closed without finishing
        Guide.OpenEdit();
        Guide.Close();

        // [THEN] opening it ran the checks and reset the completion
        Assert.IsFalse(GuideMgt.IsComplete(), 'Opening the guide resets a completion that no longer holds');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure TheGuideCarriesTheBanner()
    var
        MediaResources: Record "Media Resources";
    begin
        // [WHEN] the banner is asked for, the first time or any later one
        // [THEN] it is found, stored from the image the extension ships, with an image in it
        Assert.IsTrue(GuideMgt.GetBanner(MediaResources), 'The banner is stored and found');
        Assert.IsTrue(MediaResources."Media Reference".HasValue(), 'The banner holds an image');
        Assert.IsTrue(GuideMgt.GetBanner(MediaResources), 'Asking again finds the stored banner');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ABannerRowWithoutAnImageIsReplaced()
    var
        MediaResources: Record "Media Resources";
        Stored: Record "Media Resources";
    begin
        // [GIVEN] the banner's row exists but holds no image, as a failed first store would leave it
        Assert.IsTrue(GuideMgt.GetBanner(Stored), 'The banner is stored');
        Stored.Delete();
        MediaResources.Init();
        MediaResources.Code := Stored.Code;
        MediaResources.Insert();

        // [THEN] asking for the banner stores the image again rather than hiding it for good
        Assert.IsTrue(GuideMgt.GetBanner(MediaResources), 'An empty banner row is replaced');
        Assert.IsTrue(MediaResources."Media Reference".HasValue(), 'The replacement holds an image');
    end;

    [MessageHandler]
    procedure BlockingRemainsMessageHandler(Message: Text[1024])
    begin
        Assert.IsTrue(StrPos(Message, 'blocking') > 0, 'Finish says blocking problems remain');
    end;
}
