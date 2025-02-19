page 50090 "Item Cross Sale Factbox"
{
    PageType = ListPart;
    SourceTable = "Sales Line";
    Caption = 'Items bought by others';
    SourceTableTemporary = true;
    Editable = false;

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of the item that others have bought.';
                    StyleExpr = CountStyle;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the description of the item.';
                }
                field(PurchaseFrequency; Rec.Quantity)
                {
                    ApplicationArea = All;
                    Caption = 'Times Bought Together';
                    ToolTip = 'Shows how many times this item was purchased together';
                }

                field("Unit Price"; Rec."Unit Price")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the price per unit of the item.';
                }
                field(Availability; GetAvailabilityText())
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the current availability of the item.';

                    trigger OnDrillDown()
                    begin
                        ShowItemAvailability();
                        RestoreFilters();
                        CurrPage.Update(false);
                    end;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AddToOrder)
            {
                ApplicationArea = All;
                Caption = 'Add Selected to Order';
                Image = Add;
                ToolTip = 'Adds the selected items to the current order.';

                trigger OnAction()
                begin
                    AddSelectedItemsToOrder();
                    RestoreFilters();
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        RestoreFilters();
    end;

    trigger OnAfterGetRecord()
    begin
        RestoreFilters();
    end;

    trigger OnFindRecord(Which: Text): Boolean
    var
        Found: Boolean;
    begin
        if IsNullGuid(SalesHeader.SystemId) then
            exit(false);

        RestoreFilters();
        FillTempTable();
        Found := Rec.Find(Which);
        RestoreFilters();
        exit(Found);
    end;

    local procedure RestoreFilters()
    begin
        if IsNullGuid(SalesHeader.SystemId) then
            exit;

        Rec.FilterGroup(2);
        Rec.SetRange("Document Type", SalesHeader."Document Type");
        Rec.SetRange("Document No.", SalesHeader."No.");
        Rec.FilterGroup(0);
    end;

    local procedure FillTempTable()
    var
        ItemCrossSales: Query "Item Cross Sales";
        SalesLine3: Record "Sales Line";
        TempItemRanking: Record "Sales Line" temporary;
        LineNo: Integer;
        TempLineNo: Integer;
    begin
        if not GetSourceSalesLine(SalesLine3) then
            exit;

        // Filter and Run the Query
        SetQueryFilters(ItemCrossSales, SalesLine3);
        ItemCrossSales.Open();

        // Reset and prepare temp tables
        Rec.Reset();
        Rec.DeleteAll();
        TempItemRanking.Reset();
        TempItemRanking.DeleteAll();

        // First, collect all results in temporary table with count
        TempLineNo := 0;
        while ItemCrossSales.Read() do begin
            TempLineNo += 1;
            TempItemRanking.Init();
            TempItemRanking."Document Type" := SalesLine3."Document Type";
            TempItemRanking."Document No." := SalesLine3."Document No.";
            TempItemRanking."Line No." := TempLineNo;  // Unique line number for temp storage
            TempItemRanking.Quantity := ItemCrossSales.CountOfItem; // Store count in Quantity
            TempItemRanking."No." := ItemCrossSales.ItemNumber;
            TempItemRanking.Description := ItemCrossSales.Description;
            TempItemRanking."Unit Price" := ItemCrossSales.UnitPrice;
            TempItemRanking.Insert();
        end;

        // Now insert in sorted order
        LineNo := 10000;
        TempItemRanking.SetCurrentKey(Quantity); // Sort by count
        TempItemRanking.Ascending(false); // Highest count first

        if TempItemRanking.FindSet() then
            repeat
                InsertTempRecord(SalesLine3, TempItemRanking, LineNo);
                LineNo += 10000;
            until TempItemRanking.Next() = 0;

        ItemCrossSales.Close();
    end;

    local procedure GetSourceSalesLine(var SalesLine3: Record "Sales Line"): Boolean
    var
        EmptyDocType: Enum "Sales Document Type";
    begin
        if (Rec.GetRangeMin("Document Type") = EmptyDocType) or (Rec.GetRangeMin("Line No.") = 0) then
            exit(false);

        exit(SalesLine3.Get(
            Rec.GetRangeMin("Document Type"),
            Rec.GetRangeMin("Document No."),
            Rec.GetRangeMin("Line No.")));
    end;

    local procedure SetQueryFilters(var ItemCrossSales: Query "Item Cross Sales"; SalesLine: Record "Sales Line")
    begin
        ItemCrossSales.SetRange(DocumentType, SalesLine."Document Type");
        ItemCrossSales.SetRange(DocumentNo, SalesLine."Document No.");
        ItemCrossSales.SetRange(LineNo, SalesLine."Line No.");
        ItemCrossSales.SetFilter(ItemNumber, '<>%1', SalesLine."No.");
    end;

    local procedure InsertTempRecord(SalesLine: Record "Sales Line"; var TempItemRanking: Record "Sales Line" temporary; LineNo: Integer)
    begin
        Rec.Init();
        Rec."Document Type" := SalesLine."Document Type";
        Rec."Document No." := SalesLine."Document No.";
        Rec."Line No." := LineNo;
        Rec.Type := Rec.Type::Item;
        Rec."No." := TempItemRanking."No.";
        Rec.Description := TempItemRanking.Description;
        Rec."Unit Price" := TempItemRanking."Unit Price";
        Rec.Quantity := TempItemRanking.Quantity; // Use Quantity for the count
        Rec.Insert();
    end;

    local procedure GetAvailabilityText(): Text
    var
        Item: Record Item;
        ItemAvailFormsMgt: Codeunit "Item Availability Forms Mgt";
        GrossReq: Decimal;
        PlannedOrderRcpt: Decimal;
        SchedRcpt: Decimal;
        PlannedOrderRel: Decimal;
        ProjAvailBal: Decimal;
        ScheduledRcpt: Decimal;
        QtyOnHand: Decimal;
        QtyOnPurchOrder: Decimal;
        QtyOnSalesOrder: Decimal;
    begin
        if not Item.Get(Rec."No.") then
            exit('');

        Item.SetRange("Date Filter", 0D, WorkDate());

        ItemAvailFormsMgt.CalcAvailQuantities(
            Item, false, GrossReq, PlannedOrderRcpt,
            SchedRcpt, PlannedOrderRel, ProjAvailBal,
            ScheduledRcpt, QtyOnHand, QtyOnPurchOrder);

        exit(StrSubstNo('Qty. on Hand: %1', QtyOnHand));
    end;

    local procedure ShowItemAvailability()
    var
        Item: Record Item;
        ItemAvailFormsMgt: Codeunit "Item Availability Forms Mgt";
        OldDate: Date;
    begin
        if not Item.Get(Rec."No.") then
            exit;

        Clear(ItemAvailFormsMgt);
        Item.SetRange("Date Filter", CalcDate('<-1Y>', WorkDate()), CalcDate('<1Y>', WorkDate()));
        OldDate := 0D;
        ItemAvailFormsMgt.ShowItemAvailabilityByPeriod(Item, '', WorkDate(), OldDate);
    end;

    local procedure AddSelectedItemsToOrder()
    var
        SalesLine: Record "Sales Line";
        LastLineNo: Integer;
    begin
        if SalesHeader."No." = '' then begin
            Message('Sales order not found.');
            exit;
        end;

        // Find the last line number
        SalesLine.Reset();
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindLast() then
            LastLineNo := SalesLine."Line No."
        else
            LastLineNo := 0;

        // Add new line
        Clear(SalesLine);
        SalesLine.Init();
        SalesLine.Validate("Document Type", SalesHeader."Document Type");
        SalesLine.Validate("Document No.", SalesHeader."No.");
        SalesLine.Validate("Line No.", LastLineNo + 10000);
        SalesLine.Validate(Type, SalesLine.Type::Item);
        SalesLine.Validate("No.", Rec."No.");
        SalesLine.Validate(Quantity, 1);
        if SalesLine.Insert(true) then
            Message('Item %1 added to order.', Rec."No.")
        else
            Message('Failed to add item to order.');
    end;

    procedure mySetSalesHeader(NewSalesHeader: Record "Sales Header")
    begin
        SalesHeader := NewSalesHeader;
        RestoreFilters();
        CurrPage.Update(false);
    end;

    var
        SalesHeader: Record "Sales Header";
        CountStyle: Text;
        LastRefreshTime: DateTime;
}