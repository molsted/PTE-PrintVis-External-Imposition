// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

codeunit 50601 "PEQI Test Transport" implements "PEQI IEngine Transport"
{
    procedure Send(Method: Text; Url: Text; ApiKey: Text; TimeoutMs: Integer; Body: Text; var StatusCode: Integer; var ResponseBody: Text): Boolean
    var
        Queue: Codeunit "PEQI Test Transport Queue";
    begin
        Queue.RecordCall(Method, Url, Body);
        exit(Queue.NextResponse(StatusCode, ResponseBody));
    end;
}
