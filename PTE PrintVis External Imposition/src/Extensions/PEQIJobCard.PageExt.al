// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Extensions;

using PrintersEquity.ExternalImposition.Document;
using PrintersEquity.ExternalImposition.Mapping;

pageextension 50531 "PEQI Job Card" extends "PVS Job Card"
{
    actions
    {
        addlast(Processing)
        {
            group(PEQIImposition)
            {
                Caption = 'External Imposition';
                Image = Planning;

                action(PEQISolveImposition)
                {
                    ApplicationArea = All;
                    Caption = 'Solve Imposition';
                    Image = Planning;
                    ToolTip = 'Builds an imposition request from this job and opens the imposition editor.';

                    trigger OnAction()
                    var
                        ImpositionJob: Record "PEQI Imposition Job";
                        RequestBuilder: Codeunit "PEQI Request Builder";
                        JobCard: Page "PEQI Imposition Job Card";
                    begin
                        ImpositionJob := ImpositionJob.NewEntry(Rec.ID, Rec.Job, Rec.Version);
                        ImpositionJob.SetRequestJson(RequestBuilder.Build(Rec.ID, Rec.Job, Rec.Version));
                        ImpositionJob.Modify(true);

                        JobCard.SetRecord(ImpositionJob);
                        JobCard.Run();
                    end;
                }

                action(PEQIShowImpositions)
                {
                    ApplicationArea = All;
                    Caption = 'Imposition History';
                    Image = History;
                    RunObject = page "PEQI Imposition Jobs";
                    RunPageLink = "Case ID" = field(ID), Job = field(Job), Version = field(Version);
                    ToolTip = 'Shows every imposition solved for this job version.';
                }
            }
        }
    }
}
