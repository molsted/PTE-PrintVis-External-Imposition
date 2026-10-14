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
using PrintersEquity.ExternalImposition.Integration;
using PrintersEquity.ExternalImposition.Mapping;
using System.Environment;
using System.Security.User;

/// <summary>The imposition setup guide: nine steps that check what imposition reads and fix it in place.</summary>
/// <remarks>
/// Each checking step shows what the checks found for its area and, where there are rows to fix,
/// an editable list of them, so routine fixes never leave the guide. The checks are
/// "PEQI Setup Checks", the same ones the per-job validator asks, so a step that says a
/// component type is set up cannot be contradicted by a job that uses it.
/// </remarks>
page 50522 "PEQI Setup Guide"
{
    Caption = 'Set Up Imposition';
    PageType = NavigatePage;
    SourceTable = "PEQI Imposition Setup";
    InsertAllowed = false;
    DeleteAllowed = false;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(Banner)
            {
                ShowCaption = false;
                Editable = false;
                Visible = BannerVisible;

                field(BannerImage; BannerResources."Media Reference")
                {
                    ShowCaption = false;
                    Editable = false;
                    ToolTip = 'Printer''s Equity';
                }
            }

            group(WelcomeStep)
            {
                ShowCaption = false;
                Visible = CurrentStep = 1;

                group(WelcomeIntro)
                {
                    Caption = 'Set up imposition';
                    InstructionalText = 'This guide checks the setup imposition reads -- the engine connection, the defaults, component types, finishing types, presses, units and who may administer imposition -- and lets you fix what needs attention without leaving it. Nothing here changes a job. You can finish at any step; the guide counts as complete once nothing that would stop every job remains.';
                }
                field(WelcomeSummary; SummaryTxt)
                {
                    Caption = 'Where things stand';
                    Editable = false;
                    MultiLine = true;
                    StyleExpr = SummaryStyle;
                    ToolTip = 'Everything the checks found, counted.';
                }
            }

            group(ConnectionStep)
            {
                ShowCaption = false;
                Visible = CurrentStep = 2;

                group(ConnectionIntro)
                {
                    Caption = 'Connect to the engine';
                    InstructionalText = 'Business Central sends each job to the Impositioning engine to be solved, and shows the engine''s editor on the imposition card. Both addresses are needed for any job.';
                }
                field(Enabled; Rec.Enabled) { ToolTip = 'Whether imposition is switched on for this company.'; }
                field("Engine Base Url"; Rec."Engine Base Url")
                {
                    ToolTip = 'The Impositioning API base URL, for example https://impose.example.com/api';

                    trigger OnValidate()
                    begin
                        // A result for another address says nothing about this one.
                        ConnectionTested := false;
                    end;
                }
                field("Spa Url"; Rec."Spa Url") { ToolTip = 'The Impositioning editor URL. It is opened in a frame inside Business Central.'; }
                field(ApiKey; ApiKey)
                {
                    Caption = 'API Key';
                    ExtendedDatatype = Masked;
                    ToolTip = 'Stored encrypted. It is never displayed again after saving.';

                    trigger OnValidate()
                    begin
                        Rec.SetApiKey(ApiKey);
                        ApiKey := '';
                        KeyIsSet := Rec.HasApiKey();
                        ConnectionTested := false;
                    end;
                }
                field(KeyIsSet; KeyIsSet) { Caption = 'API Key Is Set'; Editable = false; ToolTip = 'Whether an API key is stored.'; }
                field("Timeout (ms)"; Rec."Timeout (ms)") { ToolTip = 'How long a solve may take before it is abandoned.'; }
                field("Retry Count"; Rec."Retry Count") { ToolTip = 'How many times a solve is retried when the engine is busy or failing.'; }
                field(ConnectionStatus; ConnectionStatusTxt)
                {
                    Caption = 'Status';
                    Editable = false;
                    MultiLine = true;
                    StyleExpr = ConnectionStyle;
                    ToolTip = 'What the checks found about the connection.';
                }
                field(TestConnectionLink; TestConnectionLbl)
                {
                    ShowCaption = false;
                    Editable = false;
                    ToolTip = 'Calls the engine once, waiting at most ten seconds.';

                    trigger OnDrillDown()
                    begin
                        CurrPage.SaveRecord();
                        TestConnectionNow();
                        Recheck();
                        CurrPage.Update(false);
                    end;
                }
            }

            group(DefaultsStep)
            {
                ShowCaption = false;
                Visible = CurrentStep = 3;

                group(DefaultsIntro)
                {
                    Caption = 'Defaults';
                    InstructionalText = 'How the engine solves, what the JDF ticket looks like, and the trims for a part whose job item states none. Trims are in this installation''s margin unit.';
                }
                field("Grain Policy"; Rec."Grain Policy") { ToolTip = 'How strictly the engine holds a part''s grain rule.'; }
                field("Max Solutions"; Rec."Max Solutions") { ToolTip = 'How many solutions the engine returns for the planner to choose from.'; }
                field("Jdf Version"; Rec."Jdf Version") { ToolTip = 'The JDF version the ticket is written in.'; }
                field("Jdf Flavour"; Rec."Jdf Flavour") { ToolTip = 'Whether the ticket is a stripping ticket or a Preps template.'; }
                field("Job Id Format"; Rec."Job Id Format") { ToolTip = 'JDF JobID. %1 is the case ID, %2 the job, %3 the version.'; }
                field("Default Trim Head"; Rec."Default Trim Head") { CaptionClass = Units.MarginCaptionClass('Default Trim Head'); ToolTip = 'Head trim for a part whose job item states none.'; }
                field("Default Trim Foot"; Rec."Default Trim Foot") { CaptionClass = Units.MarginCaptionClass('Default Trim Foot'); ToolTip = 'Foot trim for a part whose job item states none.'; }
                field("Default Trim Face"; Rec."Default Trim Face") { CaptionClass = Units.MarginCaptionClass('Default Trim Face'); ToolTip = 'Face trim for a part whose job item states none.'; }
            }

            group(ComponentTypesStep)
            {
                ShowCaption = false;
                Visible = CurrentStep = 4;

                group(ComponentTypesIntro)
                {
                    Caption = 'Component types';
                    InstructionalText = 'Each component type needs a JDF Product Type, which the engine imposes it as, and an Imposition Grain Rule. A job using a component type that has neither is refused, naming it; jobs that do not use it are not affected.';
                }
                field(ComponentTypesStatus; ComponentTypesStatusTxt)
                {
                    Caption = 'Status';
                    Editable = false;
                    MultiLine = true;
                    StyleExpr = ComponentTypesStyle;
                    ToolTip = 'What the checks found about component types.';
                }
                part(ComponentTypes; "PEQI Guide Component Types") { ApplicationArea = All; }
            }

            group(FinishingTypesStep)
            {
                ShowCaption = false;
                Visible = CurrentStep = 5;

                group(FinishingTypesIntro)
                {
                    Caption = 'Finishing types';
                    InstructionalText = 'A job''s binding is its finishing type''s CIP4 Binding, and its spine side the CIP4 BindingSide unless the job''s imposition code says. Misc. means nobody set it and is refused, as is a bottom spine.';
                }
                field(FinishingTypesStatus; FinishingTypesStatusTxt)
                {
                    Caption = 'Status';
                    Editable = false;
                    MultiLine = true;
                    StyleExpr = FinishingTypesStyle;
                    ToolTip = 'What the checks found about finishing types.';
                }
                part(FinishingTypes; "PEQI Guide Finishing Types") { ApplicationArea = All; }
            }

            group(PressesStep)
            {
                ShowCaption = false;
                Visible = CurrentStep = 6;

                group(PressesIntro)
                {
                    Caption = 'Presses';
                    InstructionalText = 'Every cost center configuration marked Use for Imposition is a press. Each needs a gripper edge side, at least one work style and a maximum printing format in PrintVis. Every other press setting is in the Imposition section of the Cost Center Card.';
                }
                field(PressesStatus; PressesStatusTxt)
                {
                    Caption = 'Status';
                    Editable = false;
                    MultiLine = true;
                    StyleExpr = PressesStyle;
                    ToolTip = 'What the checks found about presses.';
                }
                part(Presses; "PEQI Guide Presses") { ApplicationArea = All; }
            }

            group(PaperStep)
            {
                ShowCaption = false;
                Visible = CurrentStep = 7;

                group(PaperIntro)
                {
                    Caption = 'Paper and units';
                    InstructionalText = 'Imposition reads every length in the units PrintVis''s Standard Units state, and each paper''s thickness in the unit the Paper Thickness row states. Paper itself is what the CSR put on each job''s sheets; nothing about it is set up here.';
                }
                field(UnitsInfo; UnitsTxt) { Caption = 'Lengths'; Editable = false; ToolTip = 'The units this installation measures formats and margins in.'; }
                field(PaperStatus; PaperStatusTxt)
                {
                    Caption = 'Status';
                    Editable = false;
                    MultiLine = true;
                    StyleExpr = PaperStyle;
                    ToolTip = 'What the checks found about units and paper thickness.';
                }
                field(CheckThicknessLink; CheckThicknessLbl)
                {
                    ShowCaption = false;
                    Editable = false;
                    ToolTip = 'Reports how many paper items record a thickness that cannot be a sheet of paper, and what each would become. Changes nothing.';

                    trigger OnDrillDown()
                    begin
                        ThicknessFix.Preview();
                    end;
                }
                field(RestateThicknessLink; RestateThicknessLbl)
                {
                    ShowCaption = false;
                    Editable = false;
                    ToolTip = 'Restates the thickness of paper items recorded in the wrong unit, after asking. Changes the item master.';

                    trigger OnDrillDown()
                    begin
                        ThicknessFix.Apply();
                        Checks.SetThicknessCount(ThicknessFix.CountNeedingRestatement());
                        Recheck();
                        CurrPage.Update(false);
                    end;
                }
                field(StandardUnitsLink; StandardUnitsLbl)
                {
                    ShowCaption = false;
                    Editable = false;
                    ToolTip = 'Opens PrintVis''s Standard Units.';

                    trigger OnDrillDown()
                    begin
                        Page.Run(Page::"PVS Standard Units");
                        Recheck();
                        CurrPage.Update(false);
                    end;
                }
            }

            group(PermissionsStep)
            {
                ShowCaption = false;
                Visible = CurrentStep = 8;

                group(PermissionsIntro)
                {
                    Caption = 'Permissions';
                    InstructionalText = 'PEQI Imposition lets a planner impose jobs. PEQI Imp. Setup also lets a user change this setup, open the full editor and see the request sent to the engine. Press settings follow PrintVis''s own permissions on cost center configurations.';
                }
                field(PermissionsStatus; PermissionsStatusTxt)
                {
                    Caption = 'Status';
                    Editable = false;
                    MultiLine = true;
                    StyleExpr = PermissionsStyle;
                    ToolTip = 'What the checks found about permissions.';
                }
                field(UsersLink; UsersLbl)
                {
                    ShowCaption = false;
                    Editable = false;
                    ToolTip = 'Opens the Users page, where permission sets are assigned.';

                    trigger OnDrillDown()
                    begin
                        Page.Run(Page::Users);
                        Recheck();
                        CurrPage.Update(false);
                    end;
                }
            }

            group(FinishStep)
            {
                ShowCaption = false;
                Visible = CurrentStep = 9;

                group(FinishIntro)
                {
                    Caption = 'Finish';
                    InstructionalText = 'Everything still open is listed below. Blocking problems stop every job; warnings stop only the jobs that use what they name. Choose Finish to close the guide -- it counts as complete when nothing blocking remains.';
                }
                field(FinishSummary; SummaryTxt)
                {
                    Caption = 'Where things stand';
                    Editable = false;
                    MultiLine = true;
                    StyleExpr = SummaryStyle;
                    ToolTip = 'Everything the checks found, counted.';
                }
                part(Findings; "PEQI Setup Findings") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ActionBack)
            {
                Caption = 'Back';
                Image = PreviousRecord;
                InFooterBar = true;
                Enabled = BackEnabled;
                ToolTip = 'Goes to the previous step.';

                trigger OnAction()
                begin
                    GoTo(CurrentStep - 1);
                end;
            }
            action(ActionNext)
            {
                Caption = 'Next';
                Image = NextRecord;
                InFooterBar = true;
                Enabled = NextEnabled;
                ToolTip = 'Goes to the next step.';

                trigger OnAction()
                begin
                    GoTo(CurrentStep + 1);
                end;
            }
            action(ActionFinish)
            {
                Caption = 'Finish';
                Image = Approve;
                InFooterBar = true;
                ToolTip = 'Checks everything once more and closes the guide. Available on every step.';

                trigger OnAction()
                begin
                    FinishGuide();
                end;
            }
        }
    }

    var
        TempFindings: Record "PEQI Setup Finding" temporary;
        BannerResources: Record "Media Resources";
        Checks: Codeunit "PEQI Setup Checks";
        GuideMgt: Codeunit "PEQI Setup Guide Mgt.";
        Units: Codeunit "PEQI Unit Converter";
        ThicknessFix: Codeunit "PEQI Thickness Data Fix";
        CurrentStep: Integer;
        BannerVisible: Boolean;
        BackEnabled: Boolean;
        NextEnabled: Boolean;
        ApiKey: Text;
        KeyIsSet: Boolean;
        ConnectionTested: Boolean;
        ConnectionOk: Boolean;
        ConnectionDetail: Text;
        SummaryTxt: Text;
        ConnectionStatusTxt: Text;
        ComponentTypesStatusTxt: Text;
        FinishingTypesStatusTxt: Text;
        PressesStatusTxt: Text;
        PaperStatusTxt: Text;
        PermissionsStatusTxt: Text;
        UnitsTxt: Text;
        SummaryStyle: Text;
        ConnectionStyle: Text;
        ComponentTypesStyle: Text;
        FinishingTypesStyle: Text;
        PressesStyle: Text;
        PaperStyle: Text;
        PermissionsStyle: Text;
        TestConnectionLbl: Label 'Test connection';
        CheckThicknessLbl: Label 'Check paper thickness units';
        RestateThicknessLbl: Label 'Restate paper thickness units';
        StandardUnitsLbl: Label 'Open Standard Units';
        UsersLbl: Label 'Assign permission sets to users';
        AllSetTxt: Label 'Nothing here needs attention.';
        ConnectedTxt: Label 'The engine answered.';
        NotTestedTxt: Label 'Not tested since the address or key changed. Choose Test connection.';
        ComponentTypesAttentionTxt: Label 'Problems on component types: %1, listed below. A job using one of them is refused until it is fixed; other jobs are not affected.', Comment = '%1 count';
        FinishingTypesAttentionTxt: Label 'Problems on finishing types: %1, listed below. A job with one of them is refused until it is fixed; other jobs are not affected.', Comment = '%1 count';
        NothingOpenTxt: Label 'Everything imposition reads is set up.';
        BlockingSummaryTxt: Label 'Blocking problems: %1. Warnings: %2. A blocking problem stops every job, so the guide stays incomplete until they are fixed.', Comment = '%1 blocking count, %2 warning count';
        WarningSummaryTxt: Label 'Warnings: %1, and nothing blocking. Each warning stops only the jobs that use what it names; the guide counts as complete.', Comment = '%1 warning count';
        UnitsLbl: Label 'Formats in %1, margins in %2.', Comment = '%1 format unit, %2 margin unit';
        IncompleteMsg: Label 'The setup is saved. Blocking problems remaining: %1. Imposition stays unfinished on the Assisted Setup page until the blocking problems are fixed. Run this guide again to see them.', Comment = '%1 count';

    trigger OnOpenPage()
    begin
        Rec := Rec.GetSetup();
        Rec.Get('');
        KeyIsSet := Rec.HasApiKey();
        BannerVisible := GuideMgt.GetBanner(BannerResources);
        UnitsTxt := StrSubstNo(UnitsLbl, Units.FormatUnitSymbol(), Units.MarginUnitSymbol());
        TestConnectionNow();
        // Counted once per visit: the item master is read in full, and only Restate changes it.
        Checks.SetThicknessCount(ThicknessFix.CountNeedingRestatement());
        ShowStep(1);
        GuideMgt.UpdateCompletion(TempFindings);
    end;

    /// <summary>Saves what was typed, moves to a step, and checks again.</summary>
    local procedure GoTo(Step: Integer)
    begin
        CurrPage.SaveRecord();
        ShowStep(Step);
        if CurrentStep = 9 then
            CurrPage.Findings.Page.Load(TempFindings);
        CurrPage.Update(false);
    end;

    /// <summary>The step's state alone, with no page calls, so OnOpenPage can use it.</summary>
    local procedure ShowStep(Step: Integer)
    begin
        if Step < 1 then
            Step := 1;
        if Step > 9 then
            Step := 9;
        CurrentStep := Step;
        Recheck();
        BackEnabled := CurrentStep > 1;
        NextEnabled := CurrentStep < 9;
    end;

    /// <summary>Every check except the live call, with the last connection result kept.</summary>
    local procedure Recheck()
    begin
        Checks.Collect(TempFindings, false);
        if ConnectionTested and not ConnectionOk then
            Checks.AddUnreachable(TempFindings, ConnectionDetail);
        RefreshStatus();
    end;

    local procedure TestConnectionNow()
    var
        Client: Codeunit "PEQI Engine Client";
    begin
        // Without a URL there is nothing to call, and the checks already say the URL is missing.
        ConnectionTested := Rec."Engine Base Url" <> '';
        ConnectionOk := false;
        Clear(ConnectionDetail);
        if ConnectionTested then
            ConnectionOk := Client.TestConnection(ConnectionDetail);
    end;

    local procedure FinishGuide()
    begin
        CurrPage.SaveRecord();
        Checks.Collect(TempFindings, true);
        if not GuideMgt.UpdateCompletion(TempFindings) then
            Message(IncompleteMsg, Checks.SeverityCount(TempFindings, "PEQI Finding Severity"::Blocking));
        CurrPage.Close();
    end;

    local procedure RefreshStatus()
    begin
        ConnectionStatusTxt := AreaStatus("PEQI Setup Area"::Connection, ConnectionStyle);
        if ConnectionStatusTxt = AllSetTxt then
            if ConnectionTested and ConnectionOk then
                ConnectionStatusTxt := ConnectedTxt
            else
                if (Rec."Engine Base Url" <> '') and not ConnectionTested then begin
                    // An edit cleared the last result: nothing has said the engine answers.
                    ConnectionStatusTxt := NotTestedTxt;
                    ConnectionStyle := 'Ambiguous';
                end;
        ComponentTypesStatusTxt := CountStatus("PEQI Setup Area"::ComponentTypes, ComponentTypesAttentionTxt, ComponentTypesStyle);
        FinishingTypesStatusTxt := CountStatus("PEQI Setup Area"::FinishingTypes, FinishingTypesAttentionTxt, FinishingTypesStyle);
        PressesStatusTxt := AreaStatus("PEQI Setup Area"::Presses, PressesStyle);
        PaperStatusTxt := AreaStatus("PEQI Setup Area"::PaperAndUnits, PaperStyle);
        PermissionsStatusTxt := AreaStatus("PEQI Setup Area"::Permissions, PermissionsStyle);
        SummaryTxt := Summary(SummaryStyle);
    end;

    /// <summary>Every finding in the area, one per line -- for the areas with few.</summary>
    local procedure AreaStatus(SetupArea: Enum "PEQI Setup Area"; var Style: Text): Text
    var
        Probe: Record "PEQI Setup Finding" temporary;
        Lines: TextBuilder;
    begin
        Probe.Copy(TempFindings, true);
        Probe.Reset();
        Probe.SetRange("Setup Area", SetupArea);
        if not Probe.FindSet() then begin
            Style := 'Favorable';
            exit(AllSetTxt);
        end;
        Style := 'Ambiguous';
        repeat
            if Probe.Severity = Probe.Severity::Blocking then
                Style := 'Unfavorable';
            Lines.AppendLine(Format(Probe.Severity) + ': ' + Probe.Description);
        until Probe.Next() = 0;
        exit(Lines.ToText().TrimEnd());
    end;

    /// <summary>A count -- for the areas whose rows are listed in a part below.</summary>
    local procedure CountStatus(SetupArea: Enum "PEQI Setup Area"; AttentionTxt: Text; var Style: Text): Text
    var
        Found: Integer;
    begin
        Found := Checks.AreaCount(TempFindings, SetupArea);
        if Found = 0 then begin
            Style := 'Favorable';
            exit(AllSetTxt);
        end;
        Style := 'Ambiguous';
        exit(StrSubstNo(AttentionTxt, Found));
    end;

    local procedure Summary(var Style: Text): Text
    var
        Blocking: Integer;
        Warnings: Integer;
    begin
        Blocking := Checks.SeverityCount(TempFindings, "PEQI Finding Severity"::Blocking);
        Warnings := Checks.SeverityCount(TempFindings, "PEQI Finding Severity"::Warning);
        if Blocking > 0 then begin
            Style := 'Unfavorable';
            exit(StrSubstNo(BlockingSummaryTxt, Blocking, Warnings));
        end;
        if Warnings > 0 then begin
            Style := 'Ambiguous';
            exit(StrSubstNo(WarningSummaryTxt, Warnings));
        end;
        Style := 'Favorable';
        exit(NothingOpenTxt);
    end;
}
