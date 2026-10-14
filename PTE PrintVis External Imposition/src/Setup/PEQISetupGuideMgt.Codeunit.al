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

using System.Environment.Configuration;
using System.Media;

/// <summary>Puts the imposition guide on Business Central's Assisted Setup page, and keeps its
/// completed mark true to the setup.</summary>
/// <remarks>
/// Completed means nothing blocking remains -- not that the admin pressed Finish. Finish is
/// always allowed, so a shop can stop half way; the guide then stays visibly unfinished on
/// Assisted Setup until what breaks every job is fixed, and goes back to unfinished if something
/// blocking reappears the next time it is opened.
/// </remarks>
codeunit 50567 "PEQI Setup Guide Mgt."
{
    var
        TitleTxt: Label 'Set up imposition';
        ShortTitleTxt: Label 'Imposition';
        DescriptionTxt: Label 'Connect to the Impositioning engine and check the PrintVis setup imposition reads -- component types, finishing types, presses and units -- fixing what needs attention in place.';
        BannerResourceTok: Label 'PEQIGuideBanner.png', Locked = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Guided Experience", 'OnRegisterAssistedSetup', '', false, false)]
    local procedure OnRegisterAssistedSetup()
    begin
        Register();
    end;

    procedure Register()
    var
        GuidedExperience: Codeunit "Guided Experience";
    begin
        GuidedExperience.InsertAssistedSetup(TitleTxt, ShortTitleTxt, DescriptionTxt, 15,
            ObjectType::Page, Page::"PEQI Setup Guide", Enum::"Assisted Setup Group"::"PEQI Printers Equity",
            '', Enum::"Video Category"::Uncategorized, '');
    end;

    /// <summary>Marks the guide complete when no finding is blocking, and not complete otherwise.
    /// True when it is now complete.</summary>
    procedure UpdateCompletion(var Findings: Record "PEQI Setup Finding" temporary): Boolean
    var
        GuidedExperience: Codeunit "Guided Experience";
        Checks: Codeunit "PEQI Setup Checks";
    begin
        // Registered first: completing a guide Assisted Setup does not yet list does nothing.
        Register();
        if Checks.HasBlocking(Findings) then begin
            GuidedExperience.ResetAssistedSetup(ObjectType::Page, Page::"PEQI Setup Guide");
            exit(false);
        end;
        GuidedExperience.CompleteAssistedSetup(ObjectType::Page, Page::"PEQI Setup Guide");
        exit(true);
    end;

    /// <summary>The Printer's Equity banner shown at the top of the guide, read from the image the
    /// extension ships. False when there is none, which leaves the guide without it.</summary>
    procedure GetBanner(var Banner: Record "PEQI Guide Banner" temporary): Boolean
    var
        Image: InStream;
        Picture: OutStream;
    begin
        Banner.Reset();
        Banner.DeleteAll();
        Banner.Init();
        NavApp.GetResource(BannerResourceTok, Image);
        Banner.Picture.CreateOutStream(Picture);
        CopyStream(Picture, Image);
        Banner.Insert();
        exit(Banner.Picture.HasValue());
    end;

    procedure IsComplete(): Boolean
    var
        GuidedExperience: Codeunit "Guided Experience";
    begin
        exit(GuidedExperience.IsAssistedSetupComplete(ObjectType::Page, Page::"PEQI Setup Guide"));
    end;
}
