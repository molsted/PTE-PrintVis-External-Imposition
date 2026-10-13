// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Setup;

/// <summary>A press is configured where its cost center is.</summary>
pageextension 50572 "PEQI Cost Center Card" extends "PVS Cost Center Card"
{
    layout
    {
        addlast(content)
        {
            part(PEQIPressConfigurations; "PEQI Press Configurations")
            {
                ApplicationArea = All;
                Caption = 'Imposition';
                SubPageLink = "Cost Center Code" = field(Code);
            }
        }
    }
}
