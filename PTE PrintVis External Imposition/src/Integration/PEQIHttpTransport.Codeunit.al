// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

codeunit 50540 "PEQI Http Transport" implements "PEQI IEngine Transport"
{
    Access = Internal;

    procedure Send(Method: Text; Url: Text; ApiKey: Text; TimeoutMs: Integer; Body: Text; var StatusCode: Integer; var ResponseBody: Text): Boolean
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Content: HttpContent;
        ContentHeaders: HttpHeaders;
        RequestHeaders: HttpHeaders;
    begin
        Client.Timeout := TimeoutMs;

        Request.Method := Method;
        Request.SetRequestUri(Url);

        if Body <> '' then begin
            Content.WriteFrom(Body);
            Content.GetHeaders(ContentHeaders);
            ContentHeaders.Clear();
            ContentHeaders.Add('Content-Type', 'application/json');
            Request.Content := Content;
        end;

        Request.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Accept', 'application/json');
        if ApiKey <> '' then
            RequestHeaders.Add('x-functions-key', ApiKey);

        if not Client.Send(Request, Response) then begin
            StatusCode := 0;
            ResponseBody := '';
            exit(false);
        end;

        StatusCode := Response.HttpStatusCode();
        Response.Content().ReadAs(ResponseBody);
        exit(true);
    end;
}
