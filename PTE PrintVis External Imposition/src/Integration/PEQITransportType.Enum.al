// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

enum 50563 "PEQI Transport Type" implements "PEQI IEngine Transport"
{
    Extensible = true;

    value(0; Http)
    {
        Caption = 'HTTP';
        Implementation = "PEQI IEngine Transport" = "PEQI Http Transport";
    }
}
