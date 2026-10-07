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
using PrintersEquity.ExternalImposition.Mapping;

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
            ObsoleteState = Pending;
            ObsoleteReason = 'Superseded by PVS Unit Conversion. Caliper2Format and Format2Micrometer state the caliper unit from PrintVis''s own setup, so there is nothing left for this flag to decide.';
            ObsoleteTag = '1.0';
            Caption = 'Thickness Is Microns';
            // Escape hatch for data already held in microns. Normally false: PrintVis keeps
            // thickness in a thousandth of the general unit, which "PEQI Unit Converter"
            // converts. Was spec open item 15.1; settled against real paper, see that codeunit.
        }
        field(41; "Weight Is Gsm"; Boolean)
        {
            ObsoleteState = Pending;
            ObsoleteReason = 'Superseded by "Grammage Weight Unit". A weight is not gsm or not-gsm: PrintVis records it in a named unit, and Convert_PaperWeight converts between them.';
            ObsoleteTag = '1.0';
            Caption = 'Weight Is g/m2';
            InitValue = true;
        }
        field(42; "Grammage Weight Unit"; Code[20])
        {
            Caption = 'Grammage Weight Unit';
            TableRelation = "PVS Standard Units".Code where(Type = const("Paper weight"));
            // Which of PrintVis's paper-weight units means grams per square metre. Shop data
            // rather than a constant: a US installation records basis weights such as BOOK,
            // where "70" is 70 lb book and about 104 gsm, not 70 gsm.
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


}
