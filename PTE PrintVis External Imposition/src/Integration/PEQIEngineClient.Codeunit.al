// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

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
        StatusCode: Integer;
        ResponseBody: Text;
        Reached: Boolean;
    begin
        Setup := Setup.GetSetup();
        Setup.Get('');
        if Setup."Engine Base Url" = '' then
            Error(NoUrlErr);

        Url := DelChr(Setup."Engine Base Url", '>', '/') + '/' + Route;
        Transport := TransportType;
        MaxAttempts := Setup."Retry Count" + 1;

        for Attempt := 1 to MaxAttempts do begin
            Reached := Transport.Send(Method, Url, Setup.GetApiKey(), Setup."Timeout (ms)", Body, StatusCode, ResponseBody);
            LastStatus := StatusCode;

            if Reached and (StatusCode >= 200) and (StatusCode < 300) then begin
                LastDetail := '';
                exit(ResponseBody);
            end;

            // 429 and 5xx are the moment being wrong; everything else is the
            // request being wrong, and repeating it would only waste the operator's time.
            if Reached and not IsRetryable(StatusCode) then
                RaiseFor(StatusCode, ResponseBody);

            if Attempt = MaxAttempts then begin
                if not Reached then
                    Error(UnreachableErr, Url);
                RaiseFor(StatusCode, ResponseBody);
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

    local procedure RaiseFor(StatusCode: Integer; ResponseBody: Text)
    begin
        LastDetail := DescribeProblem(ResponseBody);
        if StatusCode = 404 then
            Error(StaleSolutionErr);
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
