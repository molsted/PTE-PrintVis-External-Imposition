// ---------------------------------------------------------------------------------------------
// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// This file, and all source code contained herein, is the exclusive property of Printers Equity
// and is protected by copyright and other intellectual property laws. Except as expressly
// permitted by a written agreement with Printers Equity, no part of this code may be used,
// copied, reproduced, modified, merged, published, distributed, sublicensed, sold or disclosed
// to any third party, in whole or in part, by any means.
// ---------------------------------------------------------------------------------------------

namespace PrintersEquity.ExternalImposition.Mapping;

using PrintersEquity.ExternalImposition.Enums;

/// <summary>Spells our enums the way the engine's contract spells them.</summary>
/// <remarks>
/// <para>
/// Every one of these used to be written with <c>Format(Value, 0, 9)</c>, which puts the
/// <b>ordinal</b> on the wire as a string - "0", "1", "2". The engine's JSON reader accepts a
/// numeric string for an enum, so nothing ever errored; it simply read whichever member sat at
/// that position in <i>its</i> enum. The two sets were never written to agree:
/// </para>
/// <code>
///   grainPolicy "0"  ours Ignored          -> theirs Required      (inverted)
///   type        "0"  ours Offset           -> theirs Digital       (inverted)
///   productType "0"  ours Body             -> theirs Cover
///   grainRule   "0"  ours Any              -> theirs ParallelToSpine
///   grain       "1"  ours Short            -> theirs NotRecorded
/// </code>
/// <para>
/// So an offset press was solved as a digital one, a body as a cover, and grain checks the
/// operator had switched off came back as required. Nothing in the response said so.
/// </para>
/// <para>
/// Names, therefore, and written out by hand rather than derived. A literal per member is the
/// only form that survives either side inserting an enum value later, and the compiler forces
/// this file to be revisited when ours gains one. Where we can say something the engine has no
/// word for, it is refused by name rather than bent into the nearest neighbour: a job quietly
/// imposed as the wrong binding is worse than a job that will not impose.
/// </para>
/// </remarks>
codeunit 50546 "PEQI Enum Names"
{
    var
        BindingUnsupportedErr: Label 'The engine cannot impose %1 binding. It handles saddle stitch, perfect bound and unbound work; anything else has to be imposed by hand.', Comment = '%1 the binding name';
        BindingSideUnsupportedErr: Label 'The engine cannot bind on the %1 edge. It binds left, right or top.', Comment = '%1 the edge name';
        GrainRuleUnsupportedErr: Label 'The engine has no %1 grain rule. It offers parallel to the spine, parallel to the fold, parallel to the long edge, or none.', Comment = '%1 the grain rule name';

    /// <summary>BindingType: None, SaddleStitch, PerfectBound.</summary>
    procedure Binding(Value: Enum "PEQI Binding Type"): Text
    begin
        case Value of
            Value::None:
                exit('None');
            Value::SaddleStitch:
                exit('SaddleStitch');
            Value::PerfectBound:
                exit('PerfectBound');
            // Side stitch and Wire-O are real bindings PrintVis quotes and the engine does not
            // model. Refused by name: imposing one as saddle stitch would fold and collect a
            // book that is meant to be drilled or punched flat.
            Value::SideStitch:
                Error(BindingUnsupportedErr, 'side stitch');
            Value::WireO:
                Error(BindingUnsupportedErr, 'Wire-O');
        end;
        Error(BindingUnsupportedErr, Format(Value));
    end;

    /// <summary>BindingSide: Left, Right, Top.</summary>
    procedure BindingSide(Value: Enum "PEQI Binding Side"): Text
    begin
        case Value of
            Value::Left:
                exit('Left');
            Value::Right:
                exit('Right');
            Value::Top:
                exit('Top');
            // The engine binds on three edges. A foot-bound product is rare enough that
            // refusing is honest, where sending 'Top' would put the spine at the wrong end and
            // paginate the whole job upside down.
            Value::Bottom:
                Error(BindingSideUnsupportedErr, 'bottom');
        end;
        Error(BindingSideUnsupportedErr, Format(Value));
    end;

    /// <summary>GrainPolicy: Required, Preferred, Ignored. Ours runs the other way round.</summary>
    procedure GrainPolicy(Value: Enum "PEQI Grain Policy"): Text
    begin
        case Value of
            Value::Required:
                exit('Required');
            Value::Preferred:
                exit('Preferred');
            Value::Ignored:
                exit('Ignored');
        end;
        exit('Preferred');
    end;

    /// <summary>GrainRule: ParallelToSpine, ParallelToFold, ParallelToLongEdge, Free.</summary>
    procedure GrainRule(Value: Enum "PEQI Grain Rule"): Text
    begin
        case Value of
            Value::Any:
                exit('Free');
            Value::ParallelToSpine:
                exit('ParallelToSpine');
            // There is no perpendicular rule. Mapping it to ParallelToSpine would assert the
            // exact opposite of what the operator chose.
            Value::PerpendicularToSpine:
                Error(GrainRuleUnsupportedErr, 'perpendicular to spine');
        end;
        exit('Free');
    end;

    /// <summary>JdfProductType, as the engine's part-types endpoint lists them.</summary>
    procedure ProductType(Value: Enum "PEQI Part Product Type"): Text
    begin
        case Value of
            Value::Body:
                exit('Body');
            Value::Cover:
                exit('Cover');
            Value::Insert:
                exit('Insert');
            Value::Jacket:
                exit('Jacket');
            // Ours is called Flat; the engine's word is FlatWork.
            Value::Flat:
                exit('FlatWork');
        end;
        exit('Body');
    end;

    /// <summary>MediaGrainDirection: Unknown, NotRecorded, Long, Short.</summary>
    procedure SheetGrain(Value: Enum "PEQI Sheet Grain"): Text
    begin
        case Value of
            Value::Short:
                exit('Short');
            Value::Long:
                exit('Long');
        end;
        exit('NotRecorded');
    end;

    /// <summary>JobType: Digital, Offset.</summary>
    procedure PressType(Value: Enum "PEQI Press Type"): Text
    begin
        case Value of
            Value::Offset:
                exit('Offset');
            Value::Digital:
                exit('Digital');
        end;
        exit('Offset');
    end;

    /// <summary>The press edge, as free text the engine parses: Left, Right, Bottom, Top.</summary>
    procedure PressEdge(Value: Enum "PEQI Press Edge"): Text
    begin
        case Value of
            Value::Top:
                exit('Top');
            Value::Bottom:
                exit('Bottom');
            Value::Left:
                exit('Left');
            Value::Right:
                exit('Right');
        end;
        // Blank. The caller only writes the field when an edge is set, and the engine reports
        // an unreadable edge itself rather than guessing one.
        exit('');
    end;
}
