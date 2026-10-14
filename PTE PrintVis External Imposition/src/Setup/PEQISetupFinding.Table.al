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

using PrintersEquity.ExternalImposition.Enums;

/// <summary>One thing the setup checks found, held only while the setup guide shows it.</summary>
/// <remarks>Temporary by definition: the checks are cheap enough to run again whenever they are
/// wanted, and a stored finding would only ever be out of date.</remarks>
table 50509 "PEQI Setup Finding"
{
    Caption = 'Setup Finding';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'Entry No.'; }
        field(2; "Setup Area"; Enum "PEQI Setup Area") { Caption = 'Area'; }
        field(3; Severity; Enum "PEQI Finding Severity") { Caption = 'Severity'; }
        field(4; Description; Text[2048]) { Caption = 'Description'; }
        field(5; "Record Id"; RecordId) { Caption = 'Record'; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(ByArea; "Setup Area", Severity) { }
    }
}
