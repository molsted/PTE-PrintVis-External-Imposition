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

pageextension 50573 "PEQI Component Types Card" extends "PVS Component Types Card"
{
    layout
    {
        addlast(General)
        {
            field("PEQI Grain Rule"; Rec."PEQI Grain Rule")
            {
                ApplicationArea = All;
                ToolTip = 'Whether this component''s grain must run parallel to the spine when imposed. A job using a component type still Not set is refused until it is chosen.';
            }
        }
    }
}
