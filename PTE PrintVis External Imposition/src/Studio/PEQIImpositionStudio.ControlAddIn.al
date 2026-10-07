// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Studio;

controladdin "PEQI Imposition Studio"
{
    RequestedHeight = 900;
    MinimumHeight = 400;
    RequestedWidth = 1400;
    MinimumWidth = 600;
    VerticalStretch = true;
    HorizontalStretch = true;

    StartupScript = 'src/Studio/Resources/PEQIStartup.js';
    Scripts = 'src/Studio/Resources/PEQIStudio.js';

    /// <summary>Frames the editor and seeds it with the request.</summary>
    procedure LoadEditor(SpaUrl: Text; RequestJson: Text; OptionsJson: Text);

    event ControlReady();
    event SolutionChosen(ResultJson: Text);
    event PreviewReady(PreviewJson: Text);
    event EditorFailed(Message: Text);
}
