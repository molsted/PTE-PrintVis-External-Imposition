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

using System.Environment.Configuration;

/// <summary>Files the imposition guide under its own heading on the Assisted Setup page.</summary>
enumextension 50574 "PEQI Assisted Setup Group" extends "Assisted Setup Group"
{
    value(50500; "PEQI Imposition") { Caption = 'Imposition'; }
}
