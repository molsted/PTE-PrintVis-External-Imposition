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

codeunit 50549 "PEQI Upgrade"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        // Nothing to migrate yet. The singleton is ensured so an upgrade from a
        // version that predates it lands on a complete configuration.
        Setup.GetSetup();
    end;
}
