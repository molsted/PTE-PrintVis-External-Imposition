// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

table 50500 "PEQI Imposition Setup"
{
    Caption = 'Imposition Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10]) { Caption = 'Primary Key'; }
        field(10; Enabled; Boolean) { Caption = 'Enabled'; }
        field(11; "Engine Base Url"; Text[250]) { Caption = 'Engine Base URL'; }
        field(12; "Spa Url"; Text[250]) { Caption = 'Editor URL'; }
        field(13; "Timeout (ms)"; Integer)
        {
            Caption = 'Timeout (ms)';
            InitValue = 120000;
            MinValue = 1000;
        }
        field(14; "Retry Count"; Integer)
        {
            Caption = 'Retry Count';
            InitValue = 3;
            MinValue = 0;
            MaxValue = 10;
        }
        field(20; "Grain Policy"; Enum "PEQI Grain Policy") { Caption = 'Grain Policy'; }
        field(21; "Max Solutions"; Integer)
        {
            Caption = 'Max Solutions';
            InitValue = 10;
            MinValue = 1;
            MaxValue = 50;
        }
        field(22; "Jdf Version"; Enum "PEQI Jdf Version") { Caption = 'JDF Version'; }
        field(23; "Jdf Flavour"; Enum "PEQI Jdf Flavour") { Caption = 'JDF Flavour'; }
        field(24; "Job Id Format"; Text[50])
        {
            Caption = 'Job ID Format';
            InitValue = '%1-%2-%3';
        }
        field(30; "Default Trim Head (mm)"; Decimal) { Caption = 'Default Trim Head (mm)'; DecimalPlaces = 0 : 3; }
        field(31; "Default Trim Foot (mm)"; Decimal) { Caption = 'Default Trim Foot (mm)'; DecimalPlaces = 0 : 3; }
        field(32; "Default Trim Face (mm)"; Decimal) { Caption = 'Default Trim Face (mm)'; DecimalPlaces = 0 : 3; }
        field(40; "Thickness Is Microns"; Boolean)
        {
            Caption = 'Thickness Is Microns';
            // PVS Thickness unit is spec open item 15.1. False means millimetres.
        }
        field(41; "Weight Is Gsm"; Boolean)
        {
            Caption = 'Weight Is g/m2';
            InitValue = true;
        }
        field(50; "Last Substrate Id"; Integer)
        {
            Caption = 'Last Substrate Id';
            Editable = false;
            ToolTip = 'High-water mark for substrate ids. It only ever rises, so a deleted paper''s id is never handed to a different paper.';
        }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }

    var
        ApiKeyTok: Label 'PEQI_ENGINE_API_KEY', Locked = true;

    /// <summary>Reads the singleton, inserting it with its InitValues on first call.</summary>
    procedure GetSetup(): Record "PEQI Imposition Setup"
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        if not Setup.Get('') then begin
            Setup.Init();
            Setup."Primary Key" := '';
            if not Setup.Insert(true) then
                Setup.Get('');
        end;
        exit(Setup);
    end;

    /// <summary>Stores the engine API key. Never a table field - a field would be
    /// readable by anyone with table read permission and would land in backups.</summary>
    procedure SetApiKey(NewKey: Text)
    begin
        if NewKey = '' then begin
            if IsolatedStorage.Contains(ApiKeyTok, DataScope::Company) then
                IsolatedStorage.Delete(ApiKeyTok, DataScope::Company);
            exit;
        end;
        IsolatedStorage.Set(ApiKeyTok, NewKey, DataScope::Company);
    end;

    procedure GetApiKey(): Text
    var
        ValueTxt: Text;
    begin
        if not IsolatedStorage.Get(ApiKeyTok, DataScope::Company, ValueTxt) then
            exit('');
        exit(ValueTxt);
    end;

    procedure HasApiKey(): Boolean
    begin
        exit(IsolatedStorage.Contains(ApiKeyTok, DataScope::Company));
    end;

    /// <summary>Issues the next substrate id and records it. A high-water mark
    /// rather than max-plus-one over the rows: deleting the highest paper must not
    /// release its id, because a stored request or a written ticket may still name it.
    /// Lock is taken before the read to prevent concurrent id allocation.</summary>
    procedure NextSubstrateId(): Integer
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        Setup.LockTable();
        if not Setup.Get('') then begin
            Setup.Init();
            Setup."Primary Key" := '';
            Setup.Insert(true);
        end;
        Setup."Last Substrate Id" += 1;
        Setup.Modify(true);
        exit(Setup."Last Substrate Id");
    end;

    /// <summary>PVS Thickness to the engine's caliperMicrons.</summary>
    procedure ThicknessToMicrons(Value: Decimal): Decimal
    begin
        if "Thickness Is Microns" then
            exit(Value);
        exit(Value * 1000);
    end;

    /// <summary>PVS Weight to the engine's grammageGsm.</summary>
    procedure WeightToGsm(Value: Decimal): Decimal
    begin
        exit(Value);
    end;
}
