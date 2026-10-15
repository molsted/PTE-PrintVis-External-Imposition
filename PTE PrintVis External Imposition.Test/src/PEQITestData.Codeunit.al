// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Tests;

using Microsoft.CRM.Contact;
using Microsoft.Inventory.Item;
using PrintersEquity.ExternalImposition.Enums;
using PrintersEquity.ExternalImposition.Setup;

codeunit 50602 "PEQI Test Data"
{
    /// <summary>Inserts a PVS Job Item for a component, and the sheet behind it that
    /// carries its paper. Only the fields the mapper reads are set - the rest of
    /// PrintVis's model is irrelevant here.</summary>
    /// <remarks>
    /// The paper goes on the sheet, not on the job item, because that is where PrintVis keeps
    /// it: "PVS Job Item"."Paper Item No." is a FlowField over "PVS Job Sheet" and cannot be
    /// written at all. Test data that set the job item's own "Item No." instead let a mapper
    /// reading a FlowField look correct here and return blank against a real database.
    /// </remarks>
    procedure AddJobItem(CaseId: Integer; JobNo: Integer; VersionNo: Integer; JobItemNo: Integer; ComponentType: Code[20]; Pages: Integer; WidthMm: Decimal; LengthMm: Decimal; PaperItemNo: Code[20])
    var
        JobItem: Record "PVS Job Item";
        SheetId: Integer;
    begin
        SheetId := SheetIdFor(CaseId, JobItemNo);
        SetSheetPaper(CaseId, JobNo, VersionNo, SheetId, PaperItemNo);

        JobItem.Init();
        JobItem.ID := CaseId;
        JobItem.Job := JobNo;
        JobItem.Version := VersionNo;
        JobItem."Job Item No." := JobItemNo;
        JobItem."Entry No." := JobItemNo;
        JobItem.Active := true;
        JobItem."Component Type" := ComponentType;
        JobItem."No. Of Pages" := Pages;
        JobItem.Width := WidthMm;
        JobItem.Length := LengthMm;
        JobItem."Sheet ID" := SheetId;
        JobItem."Colors Front" := 4;
        JobItem."Colors Back" := 4;
        JobItem.Insert(true);
    end;

    /// <summary>The sheet id a job item of this case gets, matching the CaseId * 100 + n
    /// the finishing tests already write by hand so the two meet on the same row.</summary>
    procedure SheetIdFor(CaseId: Integer; JobItemNo: Integer): Integer
    begin
        exit((CaseId * 100) + JobItemNo);
    end;

    /// <summary>Inserts the PVS Case the commit reads its order numbers from. Without PrintVis's
    /// triggers, which would number it.</summary>
    procedure AddCase(CaseId: Integer; OrderNo: Code[20]; CopyFromOrderNo: Code[20])
    var
        PVSCase: Record "PVS Case";
    begin
        PVSCase.Init();
        PVSCase.ID := CaseId;
        PVSCase."Order No." := OrderNo;
        PVSCase."Copy From Order No." := CopyFromOrderNo;
        PVSCase.Insert(false);
    end;

    /// <summary>Gives a test case a sell-to customer, as the commit's customer mapper reads it.</summary>
    procedure SetCaseCustomer(CaseId: Integer; CustomerNo: Code[20]; CustomerName: Text[100]; YourReference: Text[35]; JobName: Text[250]; ContactNo: Code[20]; ApproverNo: Code[20])
    var
        PVSCase: Record "PVS Case";
    begin
        PVSCase.Get(CaseId);
        PVSCase."Sell-To No." := CustomerNo;
        PVSCase."Sell-To Name" := CustomerName;
        PVSCase."Sell-To Address" := 'Main Street 1';
        PVSCase."Sell-To Postal Code" := '1000';
        PVSCase."Sell-To City" := 'Copenhagen';
        PVSCase."Sell-to Country/Region Code" := 'DK';
        PVSCase."Sell-To Phone" := '+4500000000';
        PVSCase."Your Reference" := YourReference;
        PVSCase."Job Name" := JobName;
        PVSCase."Sell-To Contact No." := ContactNo;
        PVSCase."Sell-To Contact No. Approver" := ApproverNo;
        PVSCase.Modify(false);
    end;

    /// <summary>A person contact card. Without the CRM triggers, which would number it and
    /// rebuild its name.</summary>
    procedure AddContact(ContactNo: Code[20]; FirstName: Text[30]; Surname: Text[30]; Email: Text[80]; Phone: Text[30])
    var
        PersonContact: Record Contact;
    begin
        PersonContact.Init();
        PersonContact."No." := ContactNo;
        PersonContact."First Name" := FirstName;
        PersonContact.Surname := Surname;
        PersonContact.Name := CopyStr(FirstName + ' ' + Surname, 1, MaxStrLen(PersonContact.Name));
        PersonContact."E-Mail" := Email;
        PersonContact."Phone No." := Phone;
        PersonContact.Insert(false);
    end;

    /// <summary>Inserts the PVS Job that BuildObject reads for binding and quantity.</summary>
    procedure AddJob(CaseId: Integer; JobNo: Integer; VersionNo: Integer; FinishingCode: Code[20]; Quantity: Integer)
    var
        PVSJob: Record "PVS Job";
    begin
        PVSJob.Init();
        PVSJob.ID := CaseId;
        PVSJob.Job := JobNo;
        PVSJob.Version := VersionNo;
        PVSJob.Active := true;
        PVSJob.Finishing := FinishingCode;
        PVSJob.Quantity := Quantity;
        PVSJob.Insert(true);
    end;

    /// <summary>A PrintVis component type with a JDF Product Type, given by member name, and an
    /// imposition grain rule. Inserted without PrintVis's triggers.</summary>
    procedure AddComponentType(TypeCode: Code[20]; JdfProductType: Text; GrainRule: Enum "PEQI Component Grain Rule")
    var
        ComponentType: Record "PVS Component Types";
        RecRef: RecordRef;
    begin
        if ComponentType.Get(TypeCode) then
            exit;
        ComponentType.Init();
        ComponentType.Code := TypeCode;
        ComponentType."PEQI Grain Rule" := GrainRule;
        ComponentType.Insert(false);
        RecRef.GetTable(ComponentType);
        SetOptionByName(RecRef, ComponentType.FieldNo("JDF Product Type"), JdfProductType);
        RecRef.Modify(false);
    end;

    /// <summary>Set an option field by its member name, the way the code under test reads it.</summary>
    procedure SetOptionByName(var RecRef: RecordRef; FieldNo: Integer; MemberName: Text)
    var
        FldRef: FieldRef;
        Members: Text;
        Count: Integer;
        Index: Integer;
    begin
        FldRef := RecRef.Field(FieldNo);
        Members := FldRef.OptionMembers();
        Count := StrLen(Members) - StrLen(DelChr(Members, '=', ',')) + 1;
        for Index := 1 to Count do
            if DelChr(SelectStr(Index, Members), '<>', ' ') = DelChr(MemberName, '<>', ' ') then begin
                FldRef.Value := Index - 1;
                exit;
            end;
        Error('No option member %1 on field %2.', MemberName, FldRef.Name());
    end;

    /// <summary>Inserts a PVS Job Sheet carrying a finishing code. PrintVis lets a
    /// shop state finishing per sheet instead of on the job.</summary>
    procedure AddJobSheet(CaseId: Integer; JobNo: Integer; VersionNo: Integer; SheetId: Integer; FinishingCode: Code[20])
    var
        JobSheet: Record "PVS Job Sheet";
    begin
        Sheet(CaseId, JobNo, VersionNo, SheetId, JobSheet);
        JobSheet.Finishing := FinishingCode;
        Save(JobSheet);
    end;

    /// <summary>Puts the paper on the sheet, leaving any finishing already stated there. A new
    /// sheet gets a 640 x 450 printing format and the same full sheet, so it is uncut unless a
    /// test says otherwise.</summary>
    local procedure SetSheetPaper(CaseId: Integer; JobNo: Integer; VersionNo: Integer; SheetId: Integer; PaperItemNo: Code[20])
    var
        JobSheet: Record "PVS Job Sheet";
    begin
        Sheet(CaseId, JobNo, VersionNo, SheetId, JobSheet);
        JobSheet."Paper Item No." := PaperItemNo;
        if (JobSheet.Length = 0) and (JobSheet.Width = 0) then begin
            JobSheet.Length := 640;
            JobSheet.Width := 450;
            JobSheet."Full Sheet Format 1" := 640;
            JobSheet."Full Sheet Format 2" := 450;
        end;
        Save(JobSheet);
    end;

    /// <summary>The printing format of the sheet behind a job item.</summary>
    procedure SetSheetFormat(CaseId: Integer; JobItemNo: Integer; Length: Decimal; Width: Decimal)
    var
        JobSheet: Record "PVS Job Sheet";
    begin
        JobSheet.Get(SheetIdFor(CaseId, JobItemNo));
        JobSheet.Length := Length;
        JobSheet.Width := Width;
        JobSheet.Modify(false);
    end;

    /// <summary>The purchased sheet behind a job item, and its grain. Grain1Gt2 sets "1&gt;2",
    /// otherwise "1&lt;2".</summary>
    procedure SetSheetFullFormat(CaseId: Integer; JobItemNo: Integer; Format1: Decimal; Format2: Decimal; Grain1Gt2: Boolean)
    var
        JobSheet: Record "PVS Job Sheet";
    begin
        JobSheet.Get(SheetIdFor(CaseId, JobItemNo));
        JobSheet."Full Sheet Format 1" := Format1;
        JobSheet."Full Sheet Format 2" := Format2;
        if Grain1Gt2 then
            JobSheet."Full Sheet Grain Direction" := JobSheet."Full Sheet Grain Direction"::"1>2"
        else
            JobSheet."Full Sheet Grain Direction" := JobSheet."Full Sheet Grain Direction"::"1<2";
        JobSheet.Modify(false);
    end;

    /// <summary>An Item for a paper, so a sheet's paper resolves to a name.</summary>
    procedure AddPaperItem(ItemNo: Code[20]; Description: Text[100])
    var
        Item: Record Item;
    begin
        if Item.Get(ItemNo) then
            exit;
        Item.Init();
        Item."No." := ItemNo;
        Item.Description := Description;
        Item.Insert(false);
    end;

    /// <summary>The sheet row, existing or new. A job item and a finishing code reach the same
    /// sheet from opposite directions, and whichever arrives second must not erase the first.
    /// </summary>
    local procedure Sheet(CaseId: Integer; JobNo: Integer; VersionNo: Integer; SheetId: Integer; var JobSheet: Record "PVS Job Sheet")
    begin
        if JobSheet.Get(SheetId) then
            exit;
        JobSheet.Init();
        JobSheet.ID := CaseId;
        JobSheet.Job := JobNo;
        JobSheet.Version := VersionNo;
        JobSheet."Sheet ID" := SheetId;
    end;

    local procedure Save(var JobSheet: Record "PVS Job Sheet")
    begin
        if JobSheet.Insert(false) then
            exit;
        JobSheet.Modify(false);
    end;

    /// <summary>A cost center configuration marked for imposition, with a format and the two
    /// work styles most presses run. Inserted without PrintVis's triggers. Calling it twice for
    /// the same configuration is safe.</summary>
    procedure AddPressConfig(CostCenterCode: Code[20]; ConfigCode: Code[20])
    var
        CostCenter: Record "PVS Cost Center";
        Config: Record "PVS Cost Center Configuration";
    begin
        if not CostCenter.Get(CostCenterCode) then begin
            CostCenter.Init();
            CostCenter.Code := CostCenterCode;
            CostCenter.Insert(false);
        end;
        if Config.Get(CostCenterCode, ConfigCode) then
            exit;
        Config.Init();
        Config."Cost Center Code" := CostCenterCode;
        Config.Configuration := ConfigCode;
        Config."Max Printing Format Width" := 1000;
        Config."Max Printing Format Length" := 700;
        Config."PEQI Simplex" := true;
        Config."PEQI Work And Back" := true;
        Config.Insert(false);
        Config.Validate("PEQI Use for Imposition", true);
        Config.Modify(false);
    end;

    /// <summary>A PrintVis finishing type with a CIP4 Binding and binding side, by member name.</summary>
    procedure AddFinishingType(FinishingCode: Code[20]; Cip4Binding: Text; Cip4Side: Text)
    var
        FinishingType: Record "PVS Finishing Types";
        RecRef: RecordRef;
    begin
        if FinishingType.Get(FinishingCode) then
            exit;
        FinishingType.Init();
        FinishingType.Code := FinishingCode;
        FinishingType.Insert(false);
        RecRef.GetTable(FinishingType);
        SetOptionByName(RecRef, FinishingType.FieldNo("CIP4 Binding"), Cip4Binding);
        SetOptionByName(RecRef, FinishingType.FieldNo("CIP4 BindingSide"), Cip4Side);
        RecRef.Modify(false);
    end;
}
