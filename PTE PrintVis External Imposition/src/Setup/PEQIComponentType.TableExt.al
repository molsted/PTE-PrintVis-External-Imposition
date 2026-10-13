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

/// <summary>The grain rule a component type is imposed under.</summary>
/// <remarks>
/// On the component type rather than chosen in the imposition preview: the engine applies grain
/// during the solve, so the preview is too late; the simple view cannot edit at all; and it is a
/// property of what is being made, not of a job. The full editor still overrides it per part.
/// </remarks>
tableextension 50571 "PEQI Component Type" extends "PVS Component Types"
{
    fields
    {
        field(50500; "PEQI Grain Rule"; Enum "PEQI Component Grain Rule")
        {
            Caption = 'Imposition Grain Rule';
            DataClassification = CustomerContent;
        }
    }
}
