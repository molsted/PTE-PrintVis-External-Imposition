// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Document;

using PrintersEquity.ExternalImposition.Commit;
using PrintersEquity.ExternalImposition.Setup;
using PrintersEquity.ExternalImposition.Studio;

page 50517 "PEQI Imposition Job Card"
{
    Caption = 'Imposition';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "PEQI Imposition Job";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("Case ID"; Rec."Case ID") { ApplicationArea = All; Editable = false; }
                field(Job; Rec.Job) { ApplicationArea = All; Editable = false; }
                field(Version; Rec.Version) { ApplicationArea = All; Editable = false; }
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; Editable = false; }
                field(Status; Rec.Status) { ApplicationArea = All; Editable = false; }
                field("Last Error"; Rec."Last Error")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Visible = HasError;
                    StyleExpr = 'Unfavorable';
                }
            }
            group(Chosen)
            {
                Caption = 'Chosen Solution';
                field("Solution Id"; Rec."Solution Id") { ApplicationArea = All; Editable = false; }
                field("Sheet Count"; Rec."Sheet Count") { ApplicationArea = All; Editable = false; }
                field("Total Signatures"; Rec."Total Signatures") { ApplicationArea = All; Editable = false; }
                field(Utilisation; Rec.Utilisation) { ApplicationArea = All; Editable = false; }
                field("Worst Grain Verdict"; Rec."Worst Grain Verdict") { ApplicationArea = All; Editable = false; }
                field(Runnable; Rec.Runnable) { ApplicationArea = All; Editable = false; }
            }
            group(Editor)
            {
                Caption = 'Imposition Editor';
                Visible = EditorVisible;

                usercontrol(Studio; "PEQI Imposition Studio")
                {
                    ApplicationArea = All;

                    trigger ControlReady()
                    var
                        Setup: Record "PEQI Imposition Setup";
                    begin
                        Setup := Setup.GetSetup();
                        if Setup."Spa Url" = '' then begin
                            EditorVisible := false;
                            CurrPage.Update(false);
                            exit;
                        end;
                        CurrPage.Studio.LoadEditor(Setup."Spa Url", Rec.GetRequestJson(), SeedOptions());
                    end;

                    trigger SolutionChosen(ResultJson: Text)
                    var
                        CommitManager: Codeunit "PEQI Commit Manager";
                    begin
                        CommitManager.StoreChoice(Rec, ResultJson);
                        CurrPage.Update(false);
                    end;

                    trigger PreviewReady(PreviewJson: Text)
                    var
                        PreviewWriter: Codeunit "PEQI Preview Writer";
                    begin
                        PreviewWriter.Receive(Rec, PreviewJson);
                    end;

                    trigger EditorFailed(Message: Text)
                    begin
                        EditorVisible := false;
                        Rec."Last Error" := CopyStr(Message, 1, MaxStrLen(Rec."Last Error"));
                        Rec.Modify(true);
                        CurrPage.Update(false);
                    end;
                }
            }
            part(Runs; "PEQI Press Run Part")
            {
                ApplicationArea = All;
                SubPageLink = "Case ID" = field("Case ID"), Job = field(Job),
                              Version = field(Version), "Entry No." = field("Entry No.");
            }
            part(Diagnostics; "PEQI Diagnostics Part")
            {
                ApplicationArea = All;
                SubPageLink = "Case ID" = field("Case ID"), Job = field(Job),
                              Version = field(Version), "Entry No." = field("Entry No.");
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ViewRequest)
            {
                ApplicationArea = All;
                Caption = 'View Request';
                Image = ViewDetails;
                ToolTip = 'Shows the JSON that was or will be sent to the engine.';

                trigger OnAction()
                begin
                    Message(Rec.GetRequestJson());
                end;
            }

            action(MeasureRequest)
            {
                ApplicationArea = All;
                Caption = 'Measure Request Size';
                Image = Calculate;
                ToolTip = 'Reports the size of the request that would be sent to the editor. Used to confirm the seed fits in a control add-in argument.';

                trigger OnAction()
                var
                    SizeMsg: Label 'Request: %1 characters (%2 KB).\Sheets: %3. Presses: %4.', Comment = '%1 chars, %2 KB, %3 sheet count, %4 press count';
                    PaperSetup: Record "PEQI Paper Setup";
                    PressSetup: Record "PEQI Press Setup";
                    RequestText: Text;
                begin
                    RequestText := Rec.GetRequestJson();
                    PaperSetup.SetRange("Use for Imposition", true);
                    PressSetup.SetRange("Use for Imposition", true);
                    Message(SizeMsg, StrLen(RequestText), Round(StrLen(RequestText) / 1024, 0.1),
                            PaperSetup.Count(), PressSetup.Count());
                end;
            }

            action(GenerateJdf)
            {
                ApplicationArea = All;
                Caption = 'Generate JDF';
                Image = CreateDocument;
                Enabled = CanGenerate;
                ToolTip = 'Writes the JDF ticket for the chosen solution and stores it on this job.';

                trigger OnAction()
                var
                    CommitManager: Codeunit "PEQI Commit Manager";
                    DoneMsg: Label 'JDF ticket %1 written.', Comment = '%1 ticket id';
                    TicketId: Guid;
                begin
                    TicketId := CommitManager.GenerateJdf(Rec);
                    CurrPage.Update(false);
                    Message(DoneMsg, TicketId);
                end;
            }
            action(ShowTickets)
            {
                ApplicationArea = All;
                Caption = 'Tickets';
                Image = Documents;
                RunObject = page "PEQI Jdf Tickets";
                RunPageLink = "Case ID" = field("Case ID"), Job = field(Job),
                              Version = field(Version), "Entry No." = field("Entry No.");
                ToolTip = 'Shows the JDF tickets written from this imposition.';
            }

            action(OpenEditorInBrowser)
            {
                ApplicationArea = All;
                Caption = 'Open Editor in Browser';
                Image = Web;
                ToolTip = 'Opens the imposition editor in a browser tab. Use this when the embedded editor cannot load.';

                trigger OnAction()
                var
                    Setup: Record "PEQI Imposition Setup";
                    NoUrlErr: Label 'No editor URL is configured on the Imposition Setup page.';
                begin
                    Setup := Setup.GetSetup();
                    if Setup."Spa Url" = '' then
                        Error(NoUrlErr);
                    Hyperlink(Setup."Spa Url");
                end;
            }
        }
    }

    var
        EditorVisible: Boolean;
        HasError: Boolean;
        CanGenerate: Boolean;

    trigger OnAfterGetRecord()
    begin
        EditorVisible := Rec.Status in [Rec.Status::Draft, Rec.Status::Solved];
        HasError := Rec."Last Error" <> '';
        CanGenerate := Rec.Status = Rec.Status::Solved;
    end;

    local procedure SeedOptions(): Text
    var
        Options: JsonObject;
        OptionsText: Text;
    begin
        // The product comes from the case, not from the operator typing it.
        Options.Add('readonlyProduct', true);
        Options.Add('startRoute', 'layout');
        // Echoed back on every result, and checked before anything is stored.
        Options.Add('entryKey', Rec.EntryKey());
        Options.WriteTo(OptionsText);
        exit(OptionsText);
    end;
}
