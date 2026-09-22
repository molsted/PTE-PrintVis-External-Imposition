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

using PrintersEquity.ExternalImposition.Setup;

permissionset 50581 "PEQI Imp. Setup"
{
    Caption = 'Imposition Setup';
    Assignable = true;
    IncludedPermissionSets = "PEQI Imposition";
    Permissions =
        tabledata "PEQI Imposition Setup" = RIMD,
        tabledata "PEQI Press Setup" = RIMD,
        tabledata "PEQI Paper Setup" = RIMD,
        tabledata "PEQI Binding Mapping" = RIMD,
        tabledata "PEQI Part Mapping" = RIMD;
}
