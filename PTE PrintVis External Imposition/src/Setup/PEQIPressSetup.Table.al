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

table 50501 "PEQI Press Setup"
{
    Caption = 'Imposition Press Setup';
    DataClassification = CustomerContent;
    LookupPageId = "PEQI Press Setup List";
    DrillDownPageId = "PEQI Press Setup List";

    fields
    {
        field(1; "Cost Center Code"; Code[20])
        {
            Caption = 'Cost Center Code';
            TableRelation = "PVS Cost Center";
            NotBlank = true;
        }
        field(2; Configuration; Code[20])
        {
            Caption = 'Configuration';
            TableRelation = "PVS Cost Center Configuration".Configuration
                where("Cost Center Code" = field("Cost Center Code"));
        }
        field(10; "Use for Imposition"; Boolean) { Caption = 'Use for Imposition'; }
        field(11; "Press Id"; Guid)
        {
            Caption = 'Press Id';
            Editable = false;
            ToolTip = 'Identifies this press to the engine. It is assigned once and never changes.';
        }
        field(12; "Press Type Override"; Enum "PEQI Press Type") { Caption = 'Press Type Override'; }
        field(13; "Use Press Type Override"; Boolean) { Caption = 'Use Press Type Override'; }
        field(20; "Gripper Edge Side"; Enum "PEQI Press Edge")
        {
            Caption = 'Gripper Edge Side';
            ToolTip = 'Which physical edge the gripper is on. PrintVis records the gripper as a measurement and never names its edge.';
        }
        field(21; "Side Lay Edge"; Enum "PEQI Press Edge") { Caption = 'Side Lay Edge'; }
        field(30; "Non-Printable Top (mm)"; Decimal) { Caption = 'Non-Printable Top (mm)'; DecimalPlaces = 0 : 3; }
        field(31; "Non-Printable Bottom (mm)"; Decimal) { Caption = 'Non-Printable Bottom (mm)'; DecimalPlaces = 0 : 3; }
        field(32; "Non-Printable Left (mm)"; Decimal) { Caption = 'Non-Printable Left (mm)'; DecimalPlaces = 0 : 3; }
        field(33; "Non-Printable Right (mm)"; Decimal) { Caption = 'Non-Printable Right (mm)'; DecimalPlaces = 0 : 3; }
        field(40; "Max Image Area Width (mm)"; Decimal) { Caption = 'Max Image Area Width (mm)'; DecimalPlaces = 0 : 3; }
        field(41; "Max Image Area Height (mm)"; Decimal) { Caption = 'Max Image Area Height (mm)'; DecimalPlaces = 0 : 3; }
        field(42; "Plate Punch (mm)"; Decimal) { Caption = 'Plate Punch (mm)'; DecimalPlaces = 0 : 3; }
        field(43; "Sheets Per Hour"; Integer) { Caption = 'Sheets Per Hour'; MinValue = 0; }
        field(50; Simplex; Boolean) { Caption = 'Simplex'; InitValue = true; }
        field(51; "Work And Back"; Boolean) { Caption = 'Work and Back'; InitValue = true; }
        field(52; "Work And Turn"; Boolean) { Caption = 'Work and Turn'; }
        field(53; "Work And Tumble"; Boolean) { Caption = 'Work and Tumble'; }
        field(54; Perfecting; Boolean) { Caption = 'Perfecting'; }
    }

    keys
    {
        key(PK; "Cost Center Code", Configuration) { Clustered = true; }
        key(Used; "Use for Imposition") { }
    }

    trigger OnInsert()
    begin
        if IsNullGuid("Press Id") then
            "Press Id" := CreateGuid();
    end;

    trigger OnModify()
    var
        Existing: Record "PEQI Press Setup";
    begin
        // The engine's solutionId hashes the press id. Restoring it rather than
        // regenerating keeps a quoted solution valid at /jdf.
        if Existing.Get("Cost Center Code", Configuration) then
            "Press Id" := Existing."Press Id";
        if IsNullGuid("Press Id") then
            "Press Id" := CreateGuid();
    end;

    /// <summary>The work styles this press declares, as engine spellings.</summary>
    procedure WorkStyleList(): List of [Text]
    var
        Styles: List of [Text];
    begin
        if Simplex then Styles.Add('Simplex');
        if "Work And Back" then Styles.Add('WorkAndBack');
        if "Work And Turn" then Styles.Add('WorkAndTurn');
        if "Work And Tumble" then Styles.Add('WorkAndTumble');
        if Perfecting then Styles.Add('Perfecting');
        exit(Styles);
    end;
}
