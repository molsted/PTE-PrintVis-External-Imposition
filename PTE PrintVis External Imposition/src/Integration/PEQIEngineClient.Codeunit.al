// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Integration;

using PrintersEquity.ExternalImposition.Mapping;
using PrintersEquity.ExternalImposition.Setup;

codeunit 50541 "PEQI Engine Client"
{
    var
        TransportType: Enum "PEQI Transport Type";
        LastStatus: Integer;
        LastDetail: Text;
        JsonHelper: Codeunit "PEQI Json Helper";
        NoUrlErr: Label 'The Impositioning engine base URL is not set. Fill it in on the Imposition Setup page.';
        UnreachableErr: Label 'The Impositioning engine could not be reached at %1.', Comment = '%1 url';
        HttpErr: Label 'The Impositioning engine returned %1.\%2', Comment = '%1 status code, %2 detail';
        StaleSolutionErr: Label 'The quoted solution is no longer known to the engine. Solve the job again.';
        NotFoundErr: Label 'The engine answered 404 Not Found at %1. Check the engine base URL -- it normally ends in /api.', Comment = '%1 url';
        NotEngineErr: Label 'The address %1 answered, but not as the Impositioning engine. Check the engine base URL -- it normally ends in /api.', Comment = '%1 url';
        SingleAttempt: Boolean;

    procedure SetTransport(NewTransportType: Enum "PEQI Transport Type")
    begin
        TransportType := NewTransportType;
    end;

    procedure Calculate(RequestJson: Text): Text
    begin
        exit(Call('POST', 'imposition/calculate', RequestJson));
    end;

    procedure WriteJdf(RequestJson: Text): Text
    begin
        exit(Call('POST', 'imposition/jdf', RequestJson));
    end;

    procedure GetTicket(TicketId: Guid): Text
    begin
        exit(Call('GET', 'imposition/jdf/' + LowerCase(DelChr(Format(TicketId), '=', '{}')), ''));
    end;

    /// <summary>Whether the engine answers at the configured URL. False, with the reason in
    /// Detail, when it does not. Never raises an error.</summary>
    /// <remarks>
    /// The setup guide runs this on opening and shows the reason on its connection step, so it
    /// makes one attempt and waits at most ten seconds whatever the setup's retry count and
    /// timeout say: a guide that waits two minutes three times over before it opens is worse than
    /// one that says the engine did not answer. Part types is the cheapest route the engine has
    /// and touches no storage, but it goes through the same URL, route prefix and key as a solve.
    /// </remarks>
    procedure TestConnection(var Detail: Text): Boolean
    var
        Setup: Record "PEQI Imposition Setup";
        Answered: Boolean;
    begin
        Clear(Detail);
        // Outside the try: GetSetup inserts the singleton on first use, and a try function may not write.
        Setup.GetSetup();
        SingleAttempt := true;
        ClearLastError();
        Answered := TryPing();
        SingleAttempt := false;
        if not Answered then
            Detail := GetLastErrorText();
        exit(Answered);
    end;

    /// <remarks>
    /// A 2xx is not enough. The production Function App serves the editor at a catch-all GET
    /// route, so a base URL of the bare host answers this route with the editor's index.html and
    /// a 200. Part types is a JSON array, so only an array counts as the engine answering.
    /// </remarks>
    [TryFunction]
    local procedure TryPing()
    var
        Setup: Record "PEQI Imposition Setup";
        PartTypes: JsonArray;
        Route: Text;
        Answer: Text;
    begin
        Route := 'imposition/part-types';
        Answer := Call('GET', Route, '');
        if not PartTypes.ReadFrom(Answer) then begin
            Setup.Get('');
            Error(NotEngineErr, UrlFor(Setup, Route));
        end;
    end;

    local procedure UrlFor(Setup: Record "PEQI Imposition Setup"; Route: Text): Text
    begin
        exit(DelChr(Setup."Engine Base Url", '>', '/') + '/' + Route);
    end;

    local procedure PingTimeoutMs(): Integer
    begin
        exit(10000);
    end;

    procedure LastStatusCode(): Integer
    begin
        exit(LastStatus);
    end;

    procedure LastProblemDetail(): Text
    begin
        exit(LastDetail);
    end;

    local procedure Call(Method: Text; Route: Text; Body: Text): Text
    var
        Setup: Record "PEQI Imposition Setup";
        Transport: Interface "PEQI IEngine Transport";
        Url: Text;
        Attempt: Integer;
        MaxAttempts: Integer;
        TimeoutMs: Integer;
        StatusCode: Integer;
        ResponseBody: Text;
        Reached: Boolean;
    begin
        Setup := Setup.GetSetup();
        Setup.Get('');
        if Setup."Engine Base Url" = '' then
            Error(NoUrlErr);

        Url := UrlFor(Setup, Route);
        Transport := TransportType;
        MaxAttempts := Setup."Retry Count" + 1;
        TimeoutMs := Setup."Timeout (ms)";
        if SingleAttempt then begin
            MaxAttempts := 1;
            if TimeoutMs > PingTimeoutMs() then
                TimeoutMs := PingTimeoutMs();
        end;

        for Attempt := 1 to MaxAttempts do begin
            Reached := Transport.Send(Method, Url, Setup.GetApiKey(), TimeoutMs, Body, StatusCode, ResponseBody);
            LastStatus := StatusCode;

            if Reached and (StatusCode >= 200) and (StatusCode < 300) then begin
                LastDetail := '';
                exit(ResponseBody);
            end;

            // 429 and 5xx are the moment being wrong; everything else is the
            // request being wrong, and repeating it would only waste the operator's time.
            if Reached and not IsRetryable(StatusCode) then
                RaiseFor(Url, StatusCode, ResponseBody);

            if Attempt = MaxAttempts then begin
                if not Reached then
                    Error(UnreachableErr, Url);
                RaiseFor(Url, StatusCode, ResponseBody);
            end;

            Sleep(BackoffMs(Attempt));
        end;
    end;

    local procedure IsRetryable(StatusCode: Integer): Boolean
    begin
        exit((StatusCode = 429) or (StatusCode >= 500));
    end;

    local procedure BackoffMs(Attempt: Integer): Integer
    begin
        // Power returns a Decimal; rounding keeps this assignable to Integer.
        exit(Round(500 * Power(2, Attempt - 1), 1));
    end;

    local procedure RaiseFor(Url: Text; StatusCode: Integer; ResponseBody: Text)
    begin
        LastDetail := DescribeProblem(ResponseBody);
        if StatusCode = 404 then begin
            // On a connection test a 404 means the URL or route is wrong, not that a solution went stale.
            if SingleAttempt then
                Error(NotFoundErr, Url);
            Error(StaleSolutionErr);
        end;
        Error(HttpErr, StatusCode, LastDetail);
    end;

    /// <summary>RFC 7807. The diagnostics extension on a 409 is what actually
    /// explains why nothing fits, so it is appended rather than dropped.</summary>
    local procedure DescribeProblem(ResponseBody: Text): Text
    var
        Problem: JsonObject;
        Diagnostics: JsonArray;
        DiagnosticToken: JsonToken;
        Described: TextBuilder;
        Detail: Text;
    begin
        if ResponseBody = '' then
            exit('');
        if not Problem.ReadFrom(ResponseBody) then
            exit(CopyStr(ResponseBody, 1, 250));

        Detail := JsonHelper.ReadText(Problem, 'detail');
        if Detail = '' then
            Detail := JsonHelper.ReadText(Problem, 'title');
        Described.AppendLine(Detail);

        if JsonHelper.ReadArray(Problem, 'diagnostics', Diagnostics) then
            foreach DiagnosticToken in Diagnostics do
                Described.AppendLine(
                    JsonHelper.ReadText(DiagnosticToken.AsObject(), 'code') + ': ' +
                    JsonHelper.ReadText(DiagnosticToken.AsObject(), 'message'));

        exit(Described.ToText());
    end;
}
