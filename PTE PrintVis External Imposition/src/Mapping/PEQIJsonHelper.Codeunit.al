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

codeunit 50539 "PEQI Json Helper"
{
    /// <summary>Adds a string member, omitting it when blank. The engine treats an
    /// absent optional member and a blank one differently - several optional fields
    /// raise a diagnostic when blank but are simply unused when absent.</summary>
    procedure AddText(var Obj: JsonObject; Name: Text; Value: Text)
    begin
        if Value = '' then
            exit;
        Obj.Add(Name, Value);
    end;

    procedure AddDecimal(var Obj: JsonObject; Name: Text; Value: Decimal)
    begin
        Obj.Add(Name, Value);
    end;

    /// <summary>Adds a numeric member only when non-zero. Used for optional
    /// measurements where zero means "not recorded" rather than "zero millimetres".</summary>
    procedure AddDecimalIfSet(var Obj: JsonObject; Name: Text; Value: Decimal)
    begin
        if Value = 0 then
            exit;
        Obj.Add(Name, Value);
    end;

    procedure AddInteger(var Obj: JsonObject; Name: Text; Value: Integer)
    begin
        Obj.Add(Name, Value);
    end;

    procedure AddIntegerIfSet(var Obj: JsonObject; Name: Text; Value: Integer)
    begin
        if Value = 0 then
            exit;
        Obj.Add(Name, Value);
    end;

    procedure AddBoolean(var Obj: JsonObject; Name: Text; Value: Boolean)
    begin
        Obj.Add(Name, Value);
    end;

    procedure ReadText(Obj: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if not Obj.Get(Name, Token) then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    procedure ReadDecimal(Obj: JsonObject; Name: Text): Decimal
    var
        Token: JsonToken;
    begin
        if not Obj.Get(Name, Token) then
            exit(0);
        if Token.AsValue().IsNull() then
            exit(0);
        exit(Token.AsValue().AsDecimal());
    end;

    procedure ReadInteger(Obj: JsonObject; Name: Text): Integer
    var
        Token: JsonToken;
    begin
        if not Obj.Get(Name, Token) then
            exit(0);
        if Token.AsValue().IsNull() then
            exit(0);
        exit(Token.AsValue().AsInteger());
    end;

    procedure ReadBoolean(Obj: JsonObject; Name: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not Obj.Get(Name, Token) then
            exit(false);
        if Token.AsValue().IsNull() then
            exit(false);
        exit(Token.AsValue().AsBoolean());
    end;

    procedure ReadObject(Obj: JsonObject; Name: Text; var Result: JsonObject): Boolean
    var
        Token: JsonToken;
    begin
        if not Obj.Get(Name, Token) then
            exit(false);
        if not Token.IsObject() then
            exit(false);
        Result := Token.AsObject();
        exit(true);
    end;

    procedure ReadArray(Obj: JsonObject; Name: Text; var Result: JsonArray): Boolean
    var
        Token: JsonToken;
    begin
        if not Obj.Get(Name, Token) then
            exit(false);
        if not Token.IsArray() then
            exit(false);
        Result := Token.AsArray();
        exit(true);
    end;
}
