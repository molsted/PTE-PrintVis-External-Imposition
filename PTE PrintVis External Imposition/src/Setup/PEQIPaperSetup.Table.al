// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

table 50502 "PEQI Paper Setup"
{
    Caption = 'Imposition Paper Setup';
    DataClassification = CustomerContent;
    LookupPageId = "PEQI Paper Setup List";
    DrillDownPageId = "PEQI Paper Setup List";

    fields
    {
        field(1; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item;
            NotBlank = true;
        }
        field(2; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
            TableRelation = "Item Variant".Code where("Item No." = field("Item No."));
        }
        field(10; "Use for Imposition"; Boolean) { Caption = 'Use for Imposition'; }
        field(11; "Substrate Id"; Integer)
        {
            Caption = 'Substrate Id';
            Editable = false;
            ToolTip = 'Identifies this stock to the engine. The engine types substrate ids as integers and item numbers are codes, so this surrogate stands in for the item number. It is assigned once and never reused.';
        }
        field(20; "Grain Override"; Enum "PEQI Sheet Grain") { Caption = 'Grain Override'; }
        field(21; "Caliper Override (microns)"; Decimal) { Caption = 'Caliper Override (microns)'; DecimalPlaces = 0 : 3; MinValue = 0; }
        field(22; "Grammage Override (gsm)"; Decimal) { Caption = 'Grammage Override (g/m2)'; DecimalPlaces = 0 : 3; MinValue = 0; }
        field(23; "Vendor Sku Override"; Text[50]) { Caption = 'Vendor SKU Override'; }
    }

    keys
    {
        key(PK; "Item No.", "Variant Code") { Clustered = true; }
        key(Surrogate; "Substrate Id") { }
        key(Used; "Use for Imposition") { }
    }

    trigger OnInsert()
    begin
        if "Substrate Id" = 0 then
            "Substrate Id" := NextSubstrateId();
    end;

    trigger OnModify()
    var
        Existing: Record "PEQI Paper Setup";
    begin
        if Existing.Get("Item No.", "Variant Code") then
            "Substrate Id" := Existing."Substrate Id";
        if "Substrate Id" = 0 then
            "Substrate Id" := NextSubstrateId();
    end;

    /// <summary>Delegates to the setup singleton's high-water mark. Max-plus-one
    /// over the rows would release a deleted paper's id to the next one inserted,
    /// which is exactly what this table must never do.</summary>
    local procedure NextSubstrateId(): Integer
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        exit(Setup.NextSubstrateId());
    end;

    /// <summary>The override if set, otherwise the item's own PVS Grain Direction.</summary>
    procedure EffectiveGrain(): Enum "PEQI Sheet Grain"
    var
        Item: Record Item;
    begin
        if "Grain Override" <> "Grain Override"::" " then
            exit("Grain Override");
        if not Item.Get("Item No.") then
            exit("PEQI Sheet Grain"::" ");
        case Item."PVS Grain Direction" of
            Item."PVS Grain Direction"::"1>2":
                exit("PEQI Sheet Grain"::Short);
            Item."PVS Grain Direction"::"1<2":
                exit("PEQI Sheet Grain"::Long);
        end;
        exit("PEQI Sheet Grain"::" ");
    end;
}
