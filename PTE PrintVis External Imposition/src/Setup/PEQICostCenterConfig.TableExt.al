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

/// <summary>What imposition needs to know about a press that PrintVis does not record.</summary>
/// <remarks>
/// <para>
/// On the configuration, not the cost center, because that is the granularity a press has always
/// had here: each cost center configuration marked for imposition is one press. The press mapping
/// to the engine is unchanged; only where these settings are stored has moved.
/// </para>
/// <para>
/// Lengths are in the installation's own units -- sizes in the format unit, margins in the margin
/// unit -- exactly as PrintVis's own fields on this table are, and are converted to millimetres
/// only when a request is built.
/// </para>
/// </remarks>
tableextension 50570 "PEQI Cost Center Config." extends "PVS Cost Center Configuration"
{
    fields
    {
        field(50500; "PEQI Use for Imposition"; Boolean)
        {
            Caption = 'Use for Imposition';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                // Assigned once and never regenerated -- the engine's solutionId hashes it -- unless
                // it is missing, or this row was copied from another and so carries that press's id.
                if "PEQI Use for Imposition" and (IsNullGuid("PEQI Press Id") or PEQIPressIdHeldByAnother()) then
                    "PEQI Press Id" := CreateGuid();
            end;
        }
        field(50501; "PEQI Press Id"; Guid)
        {
            Caption = 'Press Id';
            Editable = false;
            DataClassification = SystemMetadata;
        }
        field(50502; "PEQI Press Type Override"; Enum "PEQI Press Type") { Caption = 'Press Type Override'; DataClassification = CustomerContent; }
        field(50503; "PEQI Use Press Type Override"; Boolean) { Caption = 'Use Press Type Override'; DataClassification = CustomerContent; }
        field(50504; "PEQI Gripper Edge Side"; Enum "PEQI Press Edge") { Caption = 'Gripper Edge Side'; DataClassification = CustomerContent; }
        field(50505; "PEQI Side Lay Edge"; Enum "PEQI Press Edge") { Caption = 'Side Lay Edge'; DataClassification = CustomerContent; }
        field(50506; "PEQI Non-Printable Top"; Decimal) { Caption = 'Non-Printable Top'; DecimalPlaces = 0 : 5; DataClassification = CustomerContent; }
        field(50507; "PEQI Non-Printable Bottom"; Decimal) { Caption = 'Non-Printable Bottom'; DecimalPlaces = 0 : 5; DataClassification = CustomerContent; }
        field(50508; "PEQI Non-Printable Left"; Decimal) { Caption = 'Non-Printable Left'; DecimalPlaces = 0 : 5; DataClassification = CustomerContent; }
        field(50509; "PEQI Non-Printable Right"; Decimal) { Caption = 'Non-Printable Right'; DecimalPlaces = 0 : 5; DataClassification = CustomerContent; }
        field(50510; "PEQI Max Image Area Width"; Decimal) { Caption = 'Max Image Area Width'; DecimalPlaces = 0 : 5; DataClassification = CustomerContent; }
        field(50511; "PEQI Max Image Area Height"; Decimal) { Caption = 'Max Image Area Height'; DecimalPlaces = 0 : 5; DataClassification = CustomerContent; }
        field(50512; "PEQI Plate Punch"; Decimal) { Caption = 'Plate Punch'; DecimalPlaces = 0 : 5; DataClassification = CustomerContent; }
        field(50513; "PEQI Trailing Margin"; Decimal) { Caption = 'Trailing Margin'; DecimalPlaces = 0 : 5; DataClassification = CustomerContent; }
        field(50514; "PEQI Sheets Per Hour"; Integer) { Caption = 'Sheets Per Hour'; MinValue = 0; DataClassification = CustomerContent; }
        field(50515; "PEQI Simplex"; Boolean) { InitValue = true; Caption = 'Simplex'; DataClassification = CustomerContent; }
        field(50516; "PEQI Work And Back"; Boolean) { InitValue = true; Caption = 'Work and Back'; DataClassification = CustomerContent; }
        field(50517; "PEQI Work And Turn"; Boolean) { Caption = 'Work and Turn'; DataClassification = CustomerContent; }
        field(50518; "PEQI Work And Tumble"; Boolean) { Caption = 'Work and Tumble'; DataClassification = CustomerContent; }
        field(50519; "PEQI Perfecting"; Boolean) { Caption = 'Perfecting'; DataClassification = CustomerContent; }
        field(50520; "PEQI Digital Subtype"; Enum "PEQI Digital Subtype") { Caption = 'Digital Subtype'; DataClassification = CustomerContent; }
        field(50521; "PEQI Make"; Text[100]) { Caption = 'Make'; DataClassification = CustomerContent; }
        field(50522; "PEQI Model"; Text[100]) { Caption = 'Model'; DataClassification = CustomerContent; }
    }

    /// <summary>Whether another configuration already carries this row's press id.</summary>
    procedure PEQIPressIdHeldByAnother(): Boolean
    var
        Other: Record "PVS Cost Center Configuration";
    begin
        if IsNullGuid("PEQI Press Id") then
            exit(false);
        Other.SetRange("PEQI Press Id", "PEQI Press Id");
        Other.SetFilter("Cost Center Code", '<>%1', "Cost Center Code");
        if not Other.IsEmpty() then
            exit(true);
        Other.SetRange("Cost Center Code", "Cost Center Code");
        Other.SetFilter(Configuration, '<>%1', Configuration);
        exit(not Other.IsEmpty());
    end;

    /// <summary>The work styles this press declares, as engine spellings.</summary>
    procedure PEQIWorkStyleList(): List of [Text]
    var
        Styles: List of [Text];
    begin
        if "PEQI Simplex" then Styles.Add('Simplex');
        if "PEQI Work And Back" then Styles.Add('WorkAndBack');
        if "PEQI Work And Turn" then Styles.Add('WorkAndTurn');
        if "PEQI Work And Tumble" then Styles.Add('WorkAndTumble');
        if "PEQI Perfecting" then Styles.Add('Perfecting');
        exit(Styles);
    end;
}
