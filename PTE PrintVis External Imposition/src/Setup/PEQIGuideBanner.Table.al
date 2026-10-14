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

/// <summary>The setup guide's banner image, held in memory while the guide is open.</summary>
/// <remarks>
/// Temporary on purpose: the image is read from the extension each time the guide opens, so
/// nothing is stored, nothing needs permission to store it, and a new image in a new build is
/// simply the image shown.
/// </remarks>
table 50510 "PEQI Guide Banner"
{
    Caption = 'Guide Banner';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10]) { Caption = 'Primary Key'; }
        field(2; Picture; Blob) { Caption = 'Picture'; SubType = Bitmap; }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }
}
