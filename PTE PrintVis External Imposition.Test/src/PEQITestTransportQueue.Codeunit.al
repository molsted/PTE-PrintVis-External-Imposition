// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

/// <summary>Single-instance so a test can queue responses before the client runs
/// and inspect the calls afterwards.</summary>
codeunit 50603 "PEQI Test Transport Queue"
{
    SingleInstance = true;

    var
        StatusCodes: List of [Integer];
        Bodies: List of [Text];
        Transported: List of [Boolean];
        CallMethods: List of [Text];
        CallUrls: List of [Text];
        CallBodies: List of [Text];

    procedure Reset()
    begin
        Clear(StatusCodes);
        Clear(Bodies);
        Clear(Transported);
        Clear(CallMethods);
        Clear(CallUrls);
        Clear(CallBodies);
    end;

    procedure QueueResponse(StatusCode: Integer; ResponseBody: Text)
    begin
        StatusCodes.Add(StatusCode);
        Bodies.Add(ResponseBody);
        Transported.Add(true);
    end;

    /// <summary>Queues a failure to reach the server at all, as against an HTTP error.</summary>
    procedure QueueTransportFailure()
    begin
        StatusCodes.Add(0);
        Bodies.Add('');
        Transported.Add(false);
    end;

    procedure NextResponse(var StatusCode: Integer; var ResponseBody: Text): Boolean
    var
        Reached: Boolean;
    begin
        if StatusCodes.Count() = 0 then begin
            StatusCode := 200;
            ResponseBody := '{}';
            exit(true);
        end;
        StatusCode := StatusCodes.Get(1);
        ResponseBody := Bodies.Get(1);
        Reached := Transported.Get(1);
        StatusCodes.RemoveAt(1);
        Bodies.RemoveAt(1);
        Transported.RemoveAt(1);
        exit(Reached);
    end;

    procedure RecordCall(Method: Text; Url: Text; Body: Text)
    begin
        CallMethods.Add(Method);
        CallUrls.Add(Url);
        CallBodies.Add(Body);
    end;

    procedure CallCount(): Integer
    begin
        exit(CallMethods.Count());
    end;

    procedure CallUrl(Index: Integer): Text
    begin
        exit(CallUrls.Get(Index));
    end;
}
