// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Links;

using PrintersEquity.ExternalImposition.Document;
using PrintersEquity.ExternalImposition.Integration;
using PrintersEquity.ExternalImposition.Mapping;
using PrintersEquity.ExternalImposition.Setup;

/// <summary>Makes and manages customer links, by calling the engine. The engine owns a link; the
/// "PEQI Customer Link" rows here are what BC last read from it. Public, with events, so that
/// another extension can make a link of its own or react to one being made.</summary>
codeunit 50553 "PEQI Customer Link Mgt."
{
    Access = Public;

    var
        Client: Codeunit "PEQI Engine Client";
        JsonHelper: Codeunit "PEQI Json Helper";
        LinkSubject: Codeunit "PEQI Link Subject";
        BookPreviewMgt: Codeunit "PEQI Book Preview Mgt.";
        NoApprovedErr: Label 'This job has no approved imposition yet.';
        BadAnswerErr: Label 'The Impositioning engine answered, but not with a customer link.';
        RevokedTxt: Label 'Revoked';
        ExpiredTxt: Label 'Expired';
        UsedUpTxt: Label 'Used up';
        ActiveTxt: Label 'Active';
        InSyncTxt: Label 'In sync';
        OutOfSyncTxt: Label 'Out of sync';

    procedure SetTransport(NewTransportType: Enum "PEQI Transport Type")
    begin
        Client.SetTransport(NewTransportType);
    end;

    /// <summary>What a new link is offered with: the features, validity and session count from
    /// setup. The planner may change them before the link is made.</summary>
    procedure DefaultSettings(var Settings: Record "PEQI Customer Link Settings" temporary)
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        Setup := Setup.GetSetup();
        Setup.Get('');

        Settings.Reset();
        Settings.DeleteAll();
        Settings.Init();
        Settings."Show Imposition" := Setup."Link Show Imposition";
        Settings."Show Book" := Setup."Link Show Book";
        Settings."Allow File Submission" := Setup."Link Allow File Submission";
        // The time of day is kept, so "14 days" means 14 days from this moment, not from midnight.
        Settings."Expires At" := CreateDateTime(CalcDate(Setup."Link Validity", Today()), Time());
        Settings."Max Sessions" := Setup."Link Max Sessions";
        Settings.Insert();
    end;

    /// <summary>Makes a link with the defaults from setup. Returns its URL.</summary>
    procedure CreateLinkWithDefaults(CaseId: Integer; JobNo: Integer; VersionNo: Integer; var CustomerLink: Record "PEQI Customer Link"): Text
    var
        Settings: Record "PEQI Customer Link Settings" temporary;
    begin
        DefaultSettings(Settings);
        exit(CreateLink(CaseId, JobNo, VersionNo, Settings, CustomerLink));
    end;

    /// <summary>Makes a link for the job's approved imposition and keeps it in CustomerLink.
    /// Returns its URL, or what OnBeforeCreateCustomerLink put in the URL when it handled the
    /// creation itself (a subscriber that does not set one gives '').</summary>
    /// <remarks>
    /// The engine only knows a subject once a ticket has been written for it, and a job committed
    /// before subjects existed has none. A 409 is therefore answered by attaching the approved
    /// ticket and asking once more. A second 409 is a real failure and raises.
    /// </remarks>
    procedure CreateLink(CaseId: Integer; JobNo: Integer; VersionNo: Integer; var Settings: Record "PEQI Customer Link Settings" temporary; var CustomerLink: Record "PEQI Customer Link"): Text
    var
        JdfTicket: Record "PEQI Jdf Ticket";
        Url: Text;
        IsHandled: Boolean;
        Body: Text;
        Answer: Text;
    begin
        if not BookPreviewMgt.FindApprovedTicket(CaseId, JobNo, VersionNo, JdfTicket) then
            Error(NoApprovedErr);

        OnBeforeCreateCustomerLink(CaseId, JobNo, VersionNo, Settings, Url, IsHandled);
        if IsHandled then
            exit(Url);

        Body := CreateBody(LinkSubject."For"(CaseId, JobNo, VersionNo), Settings, JdfTicket."Ticket Id");
        if not Client.TryCreateLink(Body, Answer) then begin
            Client.AttachTicket(LinkSubject."For"(CaseId, JobNo, VersionNo), JdfTicket."Ticket Id", JdfTicket."Entry No.");
            Answer := Client.CreateLink(Body);
        end;

        Url := StoreLink(CaseId, JobNo, VersionNo, Settings, Answer, CustomerLink);
        OnAfterCreateCustomerLink(CustomerLink, Url);
        exit(Url);
    end;

    /// <summary>Brings the counts, state and submission summary of all of a job's links up to
    /// date from the engine, and whether the engine's current ticket is the approved one. One call
    /// serves them all, so CustomerLink only says which job.</summary>
    procedure Refresh(var CustomerLink: Record "PEQI Customer Link")
    var
        JdfTicket: Record "PEQI Jdf Ticket";
        JobLinks: Record "PEQI Customer Link";
        Listing: JsonObject;
        Links: JsonArray;
        LinkToken: JsonToken;
        Summary: JsonObject;
        Submission: JsonObject;
        SubmissionToken: JsonToken;
        ExpectedTicketId: Guid;
        LinkId: Guid;
        InSync: Boolean;
        Answer: Text;
    begin
        if BookPreviewMgt.FindApprovedTicket(CustomerLink."Case ID", CustomerLink.Job, CustomerLink.Version, JdfTicket) then
            ExpectedTicketId := JdfTicket."Ticket Id";

        Answer := Client.ListLinks(CustomerLink.Subject, ExpectedTicketId);
        if not Listing.ReadFrom(Answer) then
            Error(BadAnswerErr);
        InSync := JsonHelper.ReadBoolean(Listing, 'inSync');
        JsonHelper.ReadArray(Listing, 'links', Links);

        JobLinks.SetRange("Case ID", CustomerLink."Case ID");
        JobLinks.SetRange(Job, CustomerLink.Job);
        JobLinks.SetRange(Version, CustomerLink.Version);
        if JobLinks.FindSet() then
            repeat
                // A link the engine no longer lists keeps what it had; the sync flag still moves.
                JobLinks."In Sync" := InSync;
                foreach LinkToken in Links do begin
                    Summary := LinkToken.AsObject();
                    if Evaluate(LinkId, JsonHelper.ReadText(Summary, 'linkId')) then
                        if LinkId = JobLinks."Link Id" then
                            ApplySummary(Summary, JobLinks);
                end;
                JobLinks."Last Refreshed" := CurrentDateTime();
                JobLinks.Modify();
            until JobLinks.Next() = 0;

        if CustomerLink.Get(CustomerLink."Link Id") then;
    end;

    /// <summary>Switches the link off at the engine. BC marks it revoked only once the engine
    /// has said so, so the list never shows a link as off that still opens.</summary>
    /// <remarks>The row is read again before it is marked: the caller's copy may be older than a
    /// refresh, and modifying it would write its old counts back over the new ones. The caller's
    /// record is left holding the fresh row.</remarks>
    procedure Revoke(var CustomerLink: Record "PEQI Customer Link")
    var
        Stored: Record "PEQI Customer Link";
    begin
        Client.RevokeLink(CustomerLink."Link Id");
        Stored.Get(CustomerLink."Link Id");
        Stored.Revoked := true;
        Stored.Modify();
        CustomerLink := Stored;
    end;

    /// <summary>Tells the engine that the approved ticket is the job's current one, for when a
    /// re-solve has left the engine pointing at another.</summary>
    procedure Resync(CaseId: Integer; JobNo: Integer; VersionNo: Integer)
    var
        JdfTicket: Record "PEQI Jdf Ticket";
    begin
        if not BookPreviewMgt.FindApprovedTicket(CaseId, JobNo, VersionNo, JdfTicket) then
            Error(NoApprovedErr);
        Client.AttachTicket(LinkSubject."For"(CaseId, JobNo, VersionNo), JdfTicket."Ticket Id", JdfTicket."Entry No.");
    end;

    /// <summary>Throws away what the customer has assigned and previewed, so they start over.</summary>
    procedure ClearSubmission(CaseId: Integer; JobNo: Integer; VersionNo: Integer)
    begin
        Client.ClearSubmission(LinkSubject."For"(CaseId, JobNo, VersionNo));
    end;

    /// <summary>What state a link is in, for a list. It is worked out rather than stored, so
    /// it never goes stale: Revoked, else Expired once the expiry has passed, else Used up when
    /// every session is taken, else Active.</summary>
    procedure StateOf(CustomerLink: Record "PEQI Customer Link"): Text
    begin
        if CustomerLink.Revoked then
            exit(RevokedTxt);
        if (CustomerLink."Expires At" <> 0DT) and (CustomerLink."Expires At" <= CurrentDateTime()) then
            exit(ExpiredTxt);
        if CustomerLink."Sessions Used" >= CustomerLink."Max Sessions" then
            exit(UsedUpTxt);
        exit(ActiveTxt);
    end;

    /// <summary>Whether the engine's current ticket is the approved one, as of the last refresh.
    /// Blank before the first refresh, when nothing is known.</summary>
    procedure SyncOf(CustomerLink: Record "PEQI Customer Link"): Text
    begin
        if CustomerLink."Last Refreshed" = 0DT then
            exit('');
        if CustomerLink."In Sync" then
            exit(InSyncTxt);
        exit(OutOfSyncTxt);
    end;

    /// <summary>The body of the engine's create route. The wire carries four feature flags, and
    /// approval is always false: BC has no approval step to offer yet. The expiry is ISO 8601 in
    /// UTC, which is what Format with the XML format gives.</summary>
    local procedure CreateBody(Subject: Text; Settings: Record "PEQI Customer Link Settings" temporary; ExpectedTicketId: Guid): Text
    var
        Body: JsonObject;
        Features: JsonObject;
        BodyText: Text;
    begin
        JsonHelper.AddBoolean(Features, 'imposition', Settings."Show Imposition");
        JsonHelper.AddBoolean(Features, 'book', Settings."Show Book");
        JsonHelper.AddBoolean(Features, 'fileSubmission', Settings."Allow File Submission");
        JsonHelper.AddBoolean(Features, 'approval', false);

        Body.Add('subject', Subject);
        JsonHelper.AddText(Body, 'label', Settings.Label);
        Body.Add('features', Features);
        Body.Add('expiresAt', Format(Settings."Expires At", 0, 9));
        JsonHelper.AddInteger(Body, 'maxSessions', Settings."Max Sessions");
        JsonHelper.AddText(Body, 'createdBy', UserId());
        Body.Add('expectedTicketId', LowerCase(DelChr(Format(ExpectedTicketId), '=', '{}')));
        Body.WriteTo(BodyText);
        exit(BodyText);
    end;

    local procedure StoreLink(CaseId: Integer; JobNo: Integer; VersionNo: Integer; Settings: Record "PEQI Customer Link Settings" temporary; Answer: Text; var CustomerLink: Record "PEQI Customer Link"): Text
    var
        Created: JsonObject;
        LinkId: Guid;
        Url: Text;
    begin
        if not Created.ReadFrom(Answer) then
            Error(BadAnswerErr);
        Url := JsonHelper.ReadText(Created, 'url');
        if not Evaluate(LinkId, JsonHelper.ReadText(Created, 'linkId')) or (Url = '') then
            Error(BadAnswerErr);

        Clear(CustomerLink);
        CustomerLink.Init();
        CustomerLink."Link Id" := LinkId;
        CustomerLink."Case ID" := CaseId;
        CustomerLink.Job := JobNo;
        CustomerLink.Version := VersionNo;
        CustomerLink.Subject := CopyStr(LinkSubject."For"(CaseId, JobNo, VersionNo), 1, MaxStrLen(CustomerLink.Subject));
        // The engine hands the token out once, inside this URL. BC keeps the URL, by design: it is
        // where the planner finds the link again to send it on.
        CustomerLink.URL := CopyStr(Url, 1, MaxStrLen(CustomerLink.URL));
        CustomerLink.Label := Settings.Label;
        CustomerLink."Show Imposition" := Settings."Show Imposition";
        CustomerLink."Show Book" := Settings."Show Book";
        CustomerLink."Allow File Submission" := Settings."Allow File Submission";
        CustomerLink."Expires At" := Settings."Expires At";
        CustomerLink."Max Sessions" := Settings."Max Sessions";
        CustomerLink."Created At" := CurrentDateTime();
        CustomerLink."Created By" := CopyStr(UserId(), 1, MaxStrLen(CustomerLink."Created By"));
        CustomerLink."In Sync" := JsonHelper.ReadBoolean(Created, 'inSync');
        CustomerLink."Last Refreshed" := CurrentDateTime();
        CustomerLink.Insert(true);
        exit(Url);
    end;

    local procedure ApplySummary(Summary: JsonObject; var CustomerLink: Record "PEQI Customer Link")
    var
        Submission: JsonObject;
    begin
        CustomerLink."Sessions Used" := JsonHelper.ReadInteger(Summary, 'sessionsUsed');
        CustomerLink.Revoked := JsonHelper.ReadText(Summary, 'state') = 'Revoked';

        // No submission yet means nothing assigned. The page count stays as last known: it is the
        // ticket's, and only a submission carries it.
        CustomerLink."Assigned Pages" := 0;
        CustomerLink."Needs Redo" := false;
        if JsonHelper.ReadObject(Summary, 'submission', Submission) then begin
            CustomerLink."Assigned Pages" := JsonHelper.ReadInteger(Submission, 'assigned');
            CustomerLink."Total Pages" := JsonHelper.ReadInteger(Submission, 'pageCount');
            CustomerLink."Needs Redo" := JsonHelper.ReadBoolean(Submission, 'needsRedo');
        end;
    end;

    /// <summary>Raised before a link is made, so another extension can change what it is made
    /// with, or make it itself: set IsHandled, and Url to what it made, and nothing is sent to the
    /// engine or stored here.</summary>
    [IntegrationEvent(false, false)]
    procedure OnBeforeCreateCustomerLink(CaseId: Integer; JobNo: Integer; VersionNo: Integer; var Settings: Record "PEQI Customer Link Settings" temporary; var Url: Text; var IsHandled: Boolean)
    begin
    end;

    /// <summary>Raised once the link is stored, with the URL the customer is given.</summary>
    [IntegrationEvent(false, false)]
    procedure OnAfterCreateCustomerLink(var CustomerLink: Record "PEQI Customer Link"; Url: Text)
    begin
    end;
}
