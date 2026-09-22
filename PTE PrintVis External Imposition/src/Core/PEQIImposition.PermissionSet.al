// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Core;

using PrintersEquity.ExternalImposition.Document;
using PrintersEquity.ExternalImposition.Setup;

permissionset 50580 "PEQI Imposition"
{
    Caption = 'Imposition';
    Assignable = true;
    Permissions =
        tabledata "PEQI Imposition Setup" = R,
        tabledata "PEQI Press Setup" = R,
        tabledata "PEQI Paper Setup" = R,
        tabledata "PEQI Binding Mapping" = R,
        tabledata "PEQI Part Mapping" = R,
        tabledata "PEQI Imposition Job" = RIMD,
        tabledata "PEQI Press Run" = RIMD,
        tabledata "PEQI Jdf Ticket" = RIM,
        tabledata "PEQI Diagnostic" = RIMD;
}
