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
        Cip4BindingNotSetErr: Label 'Finishing type %1 has no CIP4 Binding set. Set it on the finishing type.', Comment = '%1 finishing code';
        Cip4BindingUnsupportedErr: Label 'Finishing type %1 is bound %2, which the engine does not impose. It imposes saddle stitch, perfect bound and unbound work.', Comment = '%1 finishing code, %2 CIP4 binding';
        BindingSideUnsupportedErr: Label 'The engine cannot bind on the %1 edge. It binds left, right or top.', Comment = '%1 the edge name';
        GrainNotSetErr: Label 'Component type %1 has no imposition grain rule. Set it on the component type card.', Comment = '%1 component type';

    /// <summary>Why a CIP4 Binding cannot be imposed; blank when it can.</summary>
    /// <remarks>
    /// Misc. is the option's default, so it means nobody set it -- refused rather than read as
    /// unbound, or a saddle-stitched job whose finishing type was never filled in would be
    /// imposed flat. Anything else the engine does not impose is refused naming it.
    /// </remarks>
    procedure Cip4BindingProblem(Cip4Binding: Text; FinishingCode: Code[20]): Text
    var
        EngineBinding: Text;
    begin
        if Cip4Binding = 'Misc.' then
            exit(StrSubstNo(Cip4BindingNotSetErr, FinishingCode));
        if not TranslateCip4Binding(Cip4Binding, EngineBinding) then
            exit(StrSubstNo(Cip4BindingUnsupportedErr, FinishingCode, Cip4Binding));
        exit('');
    end;

    /// <summary>The engine's binding for a CIP4 Binding member name.</summary>
    procedure BindingFromCip4(Cip4Binding: Text; FinishingCode: Code[20]): Text
    var
        EngineBinding: Text;
        Problem: Text;
    begin
        Problem := Cip4BindingProblem(Cip4Binding, FinishingCode);
        if Problem <> '' then
            Error(Problem);
        TranslateCip4Binding(Cip4Binding, EngineBinding);
        exit(EngineBinding);
    end;

    /// <summary>The engine's binding side for a CIP4 BindingSide member name; blank if unset.</summary>
    procedure BindingSideFromCip4(Cip4Side: Text): Text
    begin
        case Cip4Side of
            'Left', 'Right', 'Top':
                exit(Cip4Side);
            // A foot-bound product is rare enough that refusing is honest; sending Top would
            // put the spine at the wrong end and paginate the whole job upside down.
            'Bottom':
                Error(BindingSideUnsupportedErr, 'bottom');
        end;
        exit('');
    end;

    local procedure TranslateCip4Binding(Cip4Binding: Text; var EngineBinding: Text): Boolean
    begin
        case Cip4Binding of
            'SaddleStitch':
                EngineBinding := 'SaddleStitch';
            'Adhesive', 'SoftCover':
                EngineBinding := 'PerfectBound';
            'Cutting', 'Folding', 'Trimming', 'Laminating', 'ShapeCutting', 'Wrapping', 'ManualLabor':
                EngineBinding := 'None';
            else
                exit(false);
        end;
        exit(true);
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

    /// <summary>An option field's member name -- never its caption.</summary>
    /// <remarks>
    /// Format() on an option returns its caption, which follows the user's language: a Danish
    /// session would send a Danish word. OptionMembers is the declared name list, untranslated,
    /// indexed by the option's ordinal. Member names are trimmed because PrintVis declares a
    /// blank first member as a space.
    /// </remarks>
    procedure OptionMemberName(RecVariant: Variant; FieldNo: Integer): Text
    var
        RecRef: RecordRef;
        FldRef: FieldRef;
        Ordinal: Integer;
    begin
        RecRef.GetTable(RecVariant);
        FldRef := RecRef.Field(FieldNo);
        Ordinal := FldRef.Value;
        exit(DelChr(SelectStr(Ordinal + 1, FldRef.OptionMembers()), '<>', ' '));
    end;

    /// <summary>GrainRule: ParallelToSpine, Free. A rule nobody has chosen is refused by name.</summary>
    procedure ComponentGrainRule(Value: Enum "PEQI Component Grain Rule"; ComponentTypeCode: Code[20]): Text
    begin
        case Value of
            Value::Any:
                exit('Free');
            Value::ParallelToSpine:
                exit('ParallelToSpine');
        end;
        Error(GrainNotSetErr, ComponentTypeCode);
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

    /// <summary>JdfVersion, as the engine spells it.</summary>
    procedure JdfVersion(Value: Enum "PEQI Jdf Version"): Text
    begin
        case Value of
            Value::V14:
                exit('V14');
            Value::V15:
                exit('V15');
        end;
        exit('V14');
    end;

    /// <summary>The JDF writer to use.</summary>
    procedure JdfFlavour(Value: Enum "PEQI Jdf Flavour"): Text
    begin
        case Value of
            Value::Stripping:
                exit('Stripping');
            Value::PrepsTemplate:
                exit('PrepsTemplate');
        end;
        exit('Stripping');
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
