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

codeunit 50551 "PEQI Link Subject"
{
    /// <summary>The subject a customer link is made for, and a ticket is filed under:
    /// &lt;company id&gt;:&lt;case&gt;:&lt;job&gt;:&lt;version&gt;. The engine keeps it opaque and takes it in a URL
    /// path segment, so the company id is the lowercase hyphenated GUID without braces, and
    /// integers are written plainly (Format()'s default would put a thousands separator into a
    /// case ID). The company id is what keeps two companies of one tenant, which can share a case
    /// number, apart.</summary>
    procedure "For"(CaseId: Integer; JobNo: Integer; VersionNo: Integer): Text
    begin
        exit(StrSubstNo('%1:%2:%3:%4', CompanyId(), Format(CaseId, 0, 9), Format(JobNo, 0, 9), Format(VersionNo, 0, 9)));
    end;

    local procedure CompanyId(): Text
    begin
        exit(DelChr(Format(CompanyProperty.ID()), '=', '{}').ToLower());
    end;
}
