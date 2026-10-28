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
        // %1 case ID, %2 job, %3 version, %4 the case's order number. Blank reads as %4.
        field(24; "Job Id Format"; Text[50])
        {
            Caption = 'Job ID Format';
            InitValue = '%4';

            trigger OnValidate()
            begin
                CheckJobIdFormat("Job Id Format");
            end;
        }
        // In the installation's margin unit, as PrintVis's own trims are. Used when a job item states none.
        field(30; "Default Trim Head"; Decimal) { Caption = 'Default Trim Head'; DecimalPlaces = 0 : 5; }
        field(31; "Default Trim Foot"; Decimal) { Caption = 'Default Trim Foot'; DecimalPlaces = 0 : 5; }
        field(32; "Default Trim Face"; Decimal) { Caption = 'Default Trim Face'; DecimalPlaces = 0 : 5; }
        // What a new customer link starts with. The planner can change each per link when making one.
        field(40; "Link Show Imposition"; Boolean) { Caption = 'Show Imposition'; }
        field(41; "Link Show Book"; Boolean)
        {
            Caption = 'Show Book';
            InitValue = true;
        }
        field(42; "Link Allow File Submission"; Boolean)
        {
            Caption = 'Allow File Submission';
            InitValue = true;
        }
        // A DateFormula has no InitValue, so GetSetup and the upgrade set <14D>.
        field(43; "Link Validity"; DateFormula) { Caption = 'Link Validity'; }
        field(44; "Link Max Sessions"; Integer)
        {
            Caption = 'Max Sessions';
            InitValue = 10;
            MinValue = 1;
            MaxValue = 1000;
        }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }

    var
        ApiKeyTok: Label 'PEQI_ENGINE_API_KEY', Locked = true;
        DefaultLinkValidityTok: Label '<14D>', Locked = true;
        // The placeholders a message names are passed as arguments, because StrSubstNo does not
        // substitute into its arguments: a literal %1 in the text itself would be replaced.
        UnknownPlaceholderErr: Label 'The Job ID Format "%1" has a placeholder other than %2 (case ID), %3 (job), %4 (version) and %5 (order number).', Comment = '%1 the format entered, %2..%5 the placeholder names';
        NoJobPlaceholderErr: Label 'The Job ID Format "%1" would give every job the same ID. Use %2 (order number) or %3 (case ID).', Comment = '%1 the format entered, %2 and %3 the placeholder names';
        JobWithoutCaseErr: Label 'The Job ID Format "%1" uses %2 or %3 without %4. A job and a version are only numbered within their case, so add %4 (case ID).', Comment = '%1 the format entered, %2..%4 the placeholder names';

    /// <summary>Reads the singleton, inserting it with its InitValues on first call.</summary>
    procedure GetSetup(): Record "PEQI Imposition Setup"
    var
        Setup: Record "PEQI Imposition Setup";
    begin
        if not Setup.Get('') then begin
            Setup.Init();
            Setup."Primary Key" := '';
            Evaluate(Setup."Link Validity", DefaultLinkValidityTok);
            if not Setup.Insert(true) then
                Setup.Get('');
        end;
        exit(Setup);
    end;

    /// <summary>Gives a setup that predates the customer-link fields their defaults. A new field
    /// reads as the type's zero on an existing row, not as its InitValue. A Max Sessions of zero
    /// cannot be entered (MinValue is 1), so it marks a row nobody has set yet, and a user's own
    /// choices are never overwritten.</summary>
    procedure ApplyLinkDefaults()
    begin
        if "Link Max Sessions" = 0 then begin
            "Link Show Imposition" := false;
            "Link Show Book" := true;
            "Link Allow File Submission" := true;
            "Link Max Sessions" := 10;
        end;
        if Format("Link Validity") = '' then
            Evaluate("Link Validity", DefaultLinkValidityTok);
    end;

    /// <summary>The Job ID Format in force: the field, or %4 when it is blank.</summary>
    procedure EffectiveJobIdFormat(): Text
    begin
        if "Job Id Format" = '' then
            exit('%4');
        exit("Job Id Format");
    end;

    /// <summary>Refuses a format that would not name one job. %2 and %3 count jobs and versions
    /// within a case, so neither identifies anything without %1; and a format with neither %1 nor
    /// %4 gives every job the same ID.</summary>
    procedure CheckJobIdFormat(JobIdFormat: Text)
    var
        Position: Integer;
    begin
        if JobIdFormat = '' then
            exit;
        // Nested rather than "or": AL evaluates both sides, and the second would read past the end.
        for Position := 1 to StrLen(JobIdFormat) do
            if JobIdFormat[Position] = '%' then begin
                if Position = StrLen(JobIdFormat) then
                    Error(UnknownPlaceholderErr, JobIdFormat, '%1', '%2', '%3', '%4');
                if not (JobIdFormat[Position + 1] in ['1' .. '4']) then
                    Error(UnknownPlaceholderErr, JobIdFormat, '%1', '%2', '%3', '%4');
            end;
        if not (UsesPlaceholder(JobIdFormat, 1) or UsesPlaceholder(JobIdFormat, 4)) then
            Error(NoJobPlaceholderErr, JobIdFormat, '%4', '%1');
        if (UsesPlaceholder(JobIdFormat, 2) or UsesPlaceholder(JobIdFormat, 3)) and not UsesPlaceholder(JobIdFormat, 1) then
            Error(JobWithoutCaseErr, JobIdFormat, '%2', '%3', '%1');
    end;

    /// <summary>Whether a format uses %N.</summary>
    procedure UsesPlaceholder(JobIdFormat: Text; Placeholder: Integer): Boolean
    begin
        exit(StrPos(JobIdFormat, '%' + Format(Placeholder)) > 0);
    end;

    /// <summary>A job ID from the format. Integers are written plainly: Format()'s default would
    /// put a thousands separator into a case ID.</summary>
    procedure FormatJobId(JobIdFormat: Text; CaseId: Integer; JobNo: Integer; VersionNo: Integer; OrderNo: Code[20]): Text
    begin
        exit(StrSubstNo(JobIdFormat, Format(CaseId, 0, 9), Format(JobNo, 0, 9), Format(VersionNo, 0, 9), OrderNo));
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
}
