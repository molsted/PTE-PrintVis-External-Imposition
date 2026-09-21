// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

table 50504 "PEQI Part Mapping"
{
    Caption = 'Imposition Part Mapping';
    DataClassification = CustomerContent;
    LookupPageId = "PEQI Part Mappings";
    DrillDownPageId = "PEQI Part Mappings";

    fields
    {
        field(1; "Component Type"; Code[20])
        {
            Caption = 'Component Type';
            TableRelation = "PVS Component Types";
            NotBlank = true;
        }
        field(10; "Product Type"; Enum "PEQI Part Product Type") { Caption = 'Product Type'; }
        field(11; "Grain Rule"; Enum "PEQI Grain Rule")
        {
            Caption = 'Grain Rule';
            InitValue = ParallelToSpine;
        }
    }

    keys
    {
        key(PK; "Component Type") { Clustered = true; }
    }
}
