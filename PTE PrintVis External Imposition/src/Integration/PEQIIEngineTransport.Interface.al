// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

/// <summary>The one seam between this extension and the network. Implemented by
/// PEQI Http Transport in production and by a double in the test app, which is
/// what makes every status-code path testable without a server.</summary>
interface "PEQI IEngine Transport"
{
    /// <summary>Returns true when a response was received at all - not when the
    /// status code indicates success. Transport failure and HTTP failure are
    /// different things and the client treats them differently.</summary>
    procedure Send(Method: Text; Url: Text; ApiKey: Text; TimeoutMs: Integer; Body: Text; var StatusCode: Integer; var ResponseBody: Text): Boolean
}
