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

using PrintersEquity.ExternalImposition.Mapping;

/// <summary>A cost center's configurations, with their imposition settings, one row each.</summary>
/// <remarks>
/// The configurations are PrintVis's; this part only edits the settings imposition adds, so
/// it cannot insert or delete them. Lengths are captioned with the installation's own unit.
/// </remarks>
page 50521 "PEQI Press Configurations"
{
    Caption = 'Imposition';
    PageType = ListPart;
    SourceTable = "PVS Cost Center Configuration";
    InsertAllowed = false;
    DeleteAllowed = false;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Configurations)
            {
                field(Configuration; Rec.Configuration) { Editable = false; ToolTip = 'The PrintVis configuration. Each one marked for imposition is a press.'; }
                field("PEQI Use for Imposition"; Rec."PEQI Use for Imposition") { ToolTip = 'Offer this configuration to the imposition engine as a press.'; }
                field("PEQI Gripper Edge Side"; Rec."PEQI Gripper Edge Side") { ToolTip = 'Which physical edge the gripper is on. PrintVis records the gripper as a measurement and never names its edge.'; }
                field("Pull Side"; Rec."Pull Side") { Editable = false; ToolTip = 'The side the sheet is laid to, as PrintVis records it. Left and Right are sent as the side lay; Both sends none, so the engine treats the margins symmetrically. Change it in the configuration''s own PrintVis fields.'; }
                field("PEQI Sheets Per Hour"; Rec."PEQI Sheets Per Hour") { ToolTip = 'Rated speed. Reported back to the planner; the solve does not use it.'; }
                field("PEQI Simplex"; Rec."PEQI Simplex") { ToolTip = 'This press prints one side per pass.'; }
                field("PEQI Work And Back"; Rec."PEQI Work And Back") { ToolTip = 'This press can print work-and-back.'; }
                field("PEQI Work And Turn"; Rec."PEQI Work And Turn") { ToolTip = 'This press can print work-and-turn.'; }
                field("PEQI Work And Tumble"; Rec."PEQI Work And Tumble") { ToolTip = 'This press can print work-and-tumble.'; }
                field("Perfection Printing"; Rec."Perfection Printing") { Editable = false; ToolTip = 'PrintVis''s Perfection Printing: the press prints both sides in one pass. Sent as the Perfecting work style. Change it in the configuration''s own PrintVis fields.'; }
                field("PEQI Non-Printable Top"; Rec."PEQI Non-Printable Top") { CaptionClass = Units.MarginCaptionClass('Non-Printable Top'); Visible = false; ToolTip = 'Strip at the top that cannot be printed.'; }
                field("PEQI Non-Printable Bottom"; Rec."PEQI Non-Printable Bottom") { CaptionClass = Units.MarginCaptionClass('Non-Printable Bottom'); Visible = false; ToolTip = 'Strip at the bottom that cannot be printed.'; }
                field("PEQI Non-Printable Left"; Rec."PEQI Non-Printable Left") { CaptionClass = Units.MarginCaptionClass('Non-Printable Left'); Visible = false; ToolTip = 'Strip at the left that cannot be printed.'; }
                field("PEQI Non-Printable Right"; Rec."PEQI Non-Printable Right") { CaptionClass = Units.MarginCaptionClass('Non-Printable Right'); Visible = false; ToolTip = 'Strip at the right that cannot be printed.'; }
                field("PEQI Max Image Area Width"; Rec."PEQI Max Image Area Width") { CaptionClass = Units.FormatCaptionClass('Max Image Area Width'); Visible = false; ToolTip = 'Widest image the press can print. Set with the height, or neither applies.'; }
                field("PEQI Max Image Area Height"; Rec."PEQI Max Image Area Height") { CaptionClass = Units.FormatCaptionClass('Max Image Area Height'); Visible = false; ToolTip = 'Tallest image the press can print. Set with the width, or neither applies.'; }
                field("PEQI Plate Punch"; Rec."PEQI Plate Punch") { CaptionClass = Units.MarginCaptionClass('Plate Punch'); Visible = false; ToolTip = 'Register strip at the plate''s leading edge, which no image may enter.'; }
                field("PEQI Trailing Margin"; Rec."PEQI Trailing Margin") { CaptionClass = Units.MarginCaptionClass('Trailing Margin'); Visible = false; ToolTip = 'Allowance on the edge opposite the gripper.'; }
                field("PEQI Use Press Type Override"; Rec."PEQI Use Press Type Override") { Visible = false; ToolTip = 'Use the press type below instead of the one PrintVis records.'; }
                field("PEQI Press Type Override"; Rec."PEQI Press Type Override") { Visible = false; ToolTip = 'Offset or digital, when PrintVis records it wrongly.'; }
                field("PEQI Digital Subtype"; Rec."PEQI Digital Subtype") { Visible = false; ToolTip = 'Toner or inkjet, for a digital press. Without it the engine matches any digital substrate.'; }
                field("PEQI Make"; Rec."PEQI Make") { Visible = false; ToolTip = 'Manufacturer, carried into the response and the ticket.'; }
                field("PEQI Model"; Rec."PEQI Model") { Visible = false; ToolTip = 'Model, carried into the response and the ticket.'; }
            }
        }
    }

    var
        Units: Codeunit "PEQI Unit Converter";
}
