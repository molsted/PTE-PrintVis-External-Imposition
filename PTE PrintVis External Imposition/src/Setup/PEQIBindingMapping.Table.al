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

table 50503 "PEQI Binding Mapping"
{
    Caption = 'Imposition Binding Mapping';
    DataClassification = CustomerContent;
    LookupPageId = "PEQI Binding Mappings";
    DrillDownPageId = "PEQI Binding Mappings";

    fields
    {
        field(1; "Finishing Code"; Code[20])
        {
            Caption = 'Finishing Code';
            TableRelation = "PVS Finishing Types" where("Process Type" = const(Finishing));
            NotBlank = true;
        }
        field(10; Binding; Enum "PEQI Binding Type") { Caption = 'Binding'; }
        field(11; "Default Binding Side"; Enum "PEQI Binding Side")
        {
            Caption = 'Default Binding Side';
            ToolTip = 'Used only when the job item''s imposition code states no spine side.';
        }
        field(20; "Trim Head (mm)"; Decimal) { Caption = 'Trim Head (mm)'; DecimalPlaces = 0 : 3; }
        field(21; "Trim Foot (mm)"; Decimal) { Caption = 'Trim Foot (mm)'; DecimalPlaces = 0 : 3; }
        field(22; "Trim Face (mm)"; Decimal) { Caption = 'Trim Face (mm)'; DecimalPlaces = 0 : 3; }
        field(23; "Trim Spine (mm)"; Decimal) { Caption = 'Trim Spine (mm)'; DecimalPlaces = 0 : 3; }
        field(24; "Milling Depth (mm)"; Decimal)
        {
            Caption = 'Milling Depth (mm)';
            DecimalPlaces = 0 : 3;
            ToolTip = 'Perfect binding only.';
        }
        field(30; "Use Setup Trim Defaults"; Boolean)
        {
            Caption = 'Use Setup Trim Defaults';
            InitValue = true;
        }
    }

    keys
    {
        key(PK; "Finishing Code") { Clustered = true; }
    }
}
