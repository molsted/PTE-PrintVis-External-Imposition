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

using Microsoft.CRM.Contact;
using Microsoft.Sales.Customer;

/// <summary>The case's customer, as the engine's /jdf "customer": a JDF CustomerInfo with a
/// Customer contact and, when the case names one, an Approver.</summary>
/// <remarks>Everything comes from the PVS Case, the customer card behind it and the contacts they
/// point at. A field that is blank is left out rather than sent empty, and a contact with nothing
/// to say is not sent at all. Phones and emails are sent as Phone and Email only: Mobile is a JDF 1.5 channel type,
/// and a 1.4 ticket refuses it.</remarks>
codeunit 50550 "PEQI Customer Mapper"
{
    var
        JsonHelper: Codeunit "PEQI Json Helper";

    /// <summary>The "customer" object for a case. False when the case has no sell-to customer,
    /// in which case nothing should be sent.</summary>
    procedure Build(var PVSCase: Record "PVS Case"; var Customer: JsonObject): Boolean
    var
        Contacts: JsonArray;
        Contact: JsonObject;
    begin
        Clear(Customer);
        if PVSCase."Sell-To No." = '' then
            exit(false);

        JsonHelper.AddText(Customer, 'customerId', PVSCase."Sell-To No.");
        JsonHelper.AddText(Customer, 'customerOrderId', PVSCase."Your Reference");
        JsonHelper.AddText(Customer, 'customerJobName', PVSCase."Job Name");

        if CustomerContact(PVSCase, Contact) then
            Contacts.Add(Contact);
        if ApproverContact(PVSCase, Contact) then
            Contacts.Add(Contact);
        if Contacts.Count() > 0 then
            Customer.Add('contacts', Contacts);
        exit(true);
    end;

    /// <summary>The sell-to customer. Each value comes from the case, and from the customer card
    /// when the case leaves it blank: PrintVis does not always copy the customer onto the case, and
    /// a case with only Sell-To No. filled in otherwise sends a contact with nothing in it.</summary>
    /// <remarks>The address is taken whole from one place - the case when it states any of it,
    /// else the card - so a street from one is never paired with a city from the other. The
    /// person is the case's sell-to contact, else the customer's primary contact. That contact's
    /// own email and phone win, because they reach the person rather than the switchboard.</remarks>
    local procedure CustomerContact(var PVSCase: Record "PVS Case"; var Result: JsonObject): Boolean
    var
        SellTo: Record Customer;
        PersonContact: Record Contact;
        Address: JsonObject;
        Channels: JsonArray;
        ContactNo: Code[20];
        Email: Text;
        Phone: Text;
    begin
        Clear(Result);
        if not SellTo.Get(PVSCase."Sell-To No.") then
            Clear(SellTo);

        AddContactType(Result, 'Customer');
        JsonHelper.AddText(Result, 'company', Prefer(
            Join(PVSCase."Sell-To Name", PVSCase."Sell-To Name 2", ' '),
            Join(SellTo.Name, SellTo."Name 2", ' ')));

        PVSCase.CalcFields("Sell-To Customer E-Mail");
        Email := Prefer(PVSCase."Sell-To Customer E-Mail", SellTo."E-Mail");
        Phone := Prefer(PVSCase."Sell-To Phone", SellTo."Phone No.");

        ContactNo := PVSCase."Sell-To Contact No.";
        if ContactNo = '' then
            ContactNo := SellTo."Primary Contact No.";
        if (ContactNo <> '') and PersonContact.Get(ContactNo) then begin
            AddPerson(Result, PersonContact, Prefer(PVSCase."Sell-To Contact", SellTo.Contact));
            if PersonContact."E-Mail" <> '' then
                Email := PersonContact."E-Mail";
            if PersonContact."Phone No." <> '' then
                Phone := PersonContact."Phone No.";
        end else
            AddNamedPerson(Result, Prefer(PVSCase."Sell-To Contact", SellTo.Contact));

        if (PVSCase."Sell-To Address" <> '') or (PVSCase."Sell-To City" <> '') or (PVSCase."Sell-To Postal Code" <> '') then begin
            JsonHelper.AddText(Address, 'street', Join(PVSCase."Sell-To Address", PVSCase."Sell-To Address 2", ', '));
            JsonHelper.AddText(Address, 'postalCode', PVSCase."Sell-To Postal Code");
            JsonHelper.AddText(Address, 'city', PVSCase."Sell-To City");
            JsonHelper.AddText(Address, 'region', PVSCase."Sell-To County");
            JsonHelper.AddText(Address, 'countryCode', PVSCase."Sell-to Country/Region Code");
        end else begin
            JsonHelper.AddText(Address, 'street', Join(SellTo.Address, SellTo."Address 2", ', '));
            JsonHelper.AddText(Address, 'postalCode', SellTo."Post Code");
            JsonHelper.AddText(Address, 'city', SellTo.City);
            JsonHelper.AddText(Address, 'region', SellTo.County);
            JsonHelper.AddText(Address, 'countryCode', SellTo."Country/Region Code");
        end;
        if Address.Keys().Count() > 0 then
            Result.Add('address', Address);

        AddChannel(Channels, 'Email', Email);
        AddChannel(Channels, 'Phone', Phone);
        if Channels.Count() > 0 then
            Result.Add('channels', Channels);
        exit(true);
    end;

    /// <summary>The case's approver, when it names one that exists.</summary>
    local procedure ApproverContact(var PVSCase: Record "PVS Case"; var Result: JsonObject): Boolean
    var
        ApproverRecord: Record Contact;
        Channels: JsonArray;
    begin
        Clear(Result);
        if PVSCase."Sell-To Contact No. Approver" = '' then
            exit(false);
        if not ApproverRecord.Get(PVSCase."Sell-To Contact No. Approver") then
            exit(false);

        AddContactType(Result, 'Approver');
        JsonHelper.AddText(Result, 'company', ApproverRecord."Company Name");
        PVSCase.CalcFields("Sell-To Contact Name Approver");
        AddPerson(Result, ApproverRecord, PVSCase."Sell-To Contact Name Approver");
        AddChannel(Channels, 'Email', ApproverRecord."E-Mail");
        AddChannel(Channels, 'Phone', ApproverRecord."Phone No.");
        if Channels.Count() > 0 then
            Result.Add('channels', Channels);
        exit(true);
    end;

    /// <summary>A person from a contact card. JDF has no single name field, so a card with no
    /// first name or surname sends its Name - or, failing that, the name the case shows - as the
    /// family name rather than losing it.</summary>
    local procedure AddPerson(var Result: JsonObject; PersonContact: Record Contact; FallbackName: Text)
    var
        Person: JsonObject;
    begin
        JsonHelper.AddText(Person, 'firstName', PersonContact."First Name");
        JsonHelper.AddText(Person, 'familyName', PersonContact.Surname);
        if (PersonContact."First Name" = '') and (PersonContact.Surname = '') then
            JsonHelper.AddText(Person, 'familyName', Prefer(PersonContact.Name, FallbackName));
        JsonHelper.AddText(Person, 'jobTitle', PersonContact."Job Title");
        if Person.Keys().Count() > 0 then
            Result.Add('person', Person);
    end;

    /// <summary>A person known only by a name, when no contact card can be found for them.</summary>
    local procedure AddNamedPerson(var Result: JsonObject; FullName: Text)
    var
        Person: JsonObject;
    begin
        if FullName = '' then
            exit;
        JsonHelper.AddText(Person, 'familyName', FullName);
        Result.Add('person', Person);
    end;

    local procedure AddContactType(var Result: JsonObject; ContactType: Text)
    var
        Types: JsonArray;
    begin
        Types.Add(ContactType);
        Result.Add('contactTypes', Types);
    end;

    local procedure AddChannel(var Channels: JsonArray; ChannelType: Text; Locator: Text)
    var
        Channel: JsonObject;
    begin
        if Locator = '' then
            exit;
        Channel.Add('channelType', ChannelType);
        Channel.Add('locator', Locator);
        Channels.Add(Channel);
    end;

    local procedure Prefer(First: Text; Second: Text): Text
    begin
        if First <> '' then
            exit(First);
        exit(Second);
    end;

    local procedure Join(First: Text; Second: Text; Separator: Text): Text
    begin
        if Second = '' then
            exit(First);
        if First = '' then
            exit(Second);
        exit(First + Separator + Second);
    end;
}
