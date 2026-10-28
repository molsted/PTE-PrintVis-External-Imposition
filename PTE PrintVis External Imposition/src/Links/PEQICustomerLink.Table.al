// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Links;

/// <summary>A customer link BC has made at the engine. The token is shown once and never kept
/// here. The engine owns the link; the counts below are what BC last read from it, and
/// "Last Refreshed" says when.</summary>
table 50511 "PEQI Customer Link"
{
    Caption = 'Customer Link';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Link Id"; Guid) { Caption = 'Link Id'; }
        field(10; "Case ID"; Integer) { Caption = 'Case ID'; }
        field(11; Job; Integer) { Caption = 'Job'; }
        field(12; Version; Integer) { Caption = 'Version'; }
        field(13; Subject; Text[128]) { Caption = 'Subject'; }
        field(20; URL; Text[2048]) { Caption = 'URL'; ExtendedDatatype = URL; }
        field(21; Label; Text[100]) { Caption = 'Label'; }
        field(30; "Show Imposition"; Boolean) { Caption = 'Show Imposition'; }
        field(31; "Show Book"; Boolean) { Caption = 'Show Book'; }
        field(32; "Allow File Submission"; Boolean) { Caption = 'Allow File Submission'; }
        field(40; "Expires At"; DateTime) { Caption = 'Expires At'; }
        field(41; "Max Sessions"; Integer) { Caption = 'Max Sessions'; }
        field(42; "Created At"; DateTime) { Caption = 'Created At'; }
        field(43; "Created By"; Code[50]) { Caption = 'Created By'; DataClassification = EndUserIdentifiableInformation; }
        field(44; Revoked; Boolean) { Caption = 'Revoked'; }
        // As last refreshed from the engine.
        field(50; "Sessions Used"; Integer) { Caption = 'Sessions Used'; }
        field(51; "Assigned Pages"; Integer) { Caption = 'Assigned Pages'; }
        field(52; "Total Pages"; Integer) { Caption = 'Total Pages'; }
        field(53; "Needs Redo"; Boolean) { Caption = 'Needs Redo'; }
        field(54; "In Sync"; Boolean) { Caption = 'In Sync'; }
        field(55; "Last Refreshed"; DateTime) { Caption = 'Last Refreshed'; }
    }

    keys
    {
        key(PK; "Link Id") { Clustered = true; }
        key(ByJob; "Case ID", Job, Version, "Created At") { }
    }
}
