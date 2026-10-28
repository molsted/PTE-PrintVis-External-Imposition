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

/// <summary>Stands in for another extension that listens to the customer link events. Manual, so
/// it only hears them in the test that binds it.</summary>
codeunit 50627 "PEQI Link Subscriber"
{
    EventSubscriberInstance = Manual;

    var
        ForcedMaxSessions: Integer;
        TakeOver: Boolean;
        TakenOverUrl: Text;
        SeenLinkId: Guid;
        SeenUrl: Text;
        AfterRaised: Boolean;

    procedure ForceMaxSessions(MaxSessions: Integer)
    begin
        ForcedMaxSessions := MaxSessions;
    end;

    /// <summary>Handle the creation itself, answering with this URL.</summary>
    procedure HandleCreationWith(Url: Text)
    begin
        TakeOver := true;
        TakenOverUrl := Url;
    end;

    procedure AfterWasRaised(): Boolean
    begin
        exit(AfterRaised);
    end;

    procedure LinkIdSeen(): Guid
    begin
        exit(SeenLinkId);
    end;

    procedure UrlSeen(): Text
    begin
        exit(SeenUrl);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"PEQI Customer Link Mgt.", 'OnBeforeCreateCustomerLink', '', false, false)]
    local procedure OnBeforeCreateCustomerLink(CaseId: Integer; JobNo: Integer; VersionNo: Integer; var Settings: Record "PEQI Customer Link Settings" temporary; var Url: Text; var IsHandled: Boolean)
    begin
        if ForcedMaxSessions <> 0 then
            Settings."Max Sessions" := ForcedMaxSessions;
        if TakeOver then begin
            Url := TakenOverUrl;
            IsHandled := true;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"PEQI Customer Link Mgt.", 'OnAfterCreateCustomerLink', '', false, false)]
    local procedure OnAfterCreateCustomerLink(var CustomerLink: Record "PEQI Customer Link"; Url: Text)
    begin
        AfterRaised := true;
        SeenLinkId := CustomerLink."Link Id";
        SeenUrl := Url;
    end;
}
