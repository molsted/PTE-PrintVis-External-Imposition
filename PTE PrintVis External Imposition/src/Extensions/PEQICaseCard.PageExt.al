// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Extensions;

using PrintersEquity.ExternalImposition.Document;

pageextension 50530 "PEQI Case Card" extends "PVS Case Card"
{
    actions
    {
        addlast(Processing)
        {
            action(PEQICaseImpositions)
            {
                ApplicationArea = All;
                Caption = 'External Impositions';
                Image = Planning;
                RunObject = page "PEQI Imposition Jobs";
                RunPageLink = "Case ID" = field(ID);
                ToolTip = 'Shows every imposition solved for any job on this case.';
            }
        }
    }
}
