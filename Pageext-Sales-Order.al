pageextension 50091 "Sales Order Ext" extends "Sales Order"
{
    layout
    {
        addfirst(factboxes)
        {
            part(CrossSales; "Item Cross Sale Factbox")
            {
                ApplicationArea = All;
                Caption = 'Items Others Bought';
                Provider = SalesLines;
                SubPageLink = "Document Type" = field("Document Type")
                                , "Document No." = field("Document No.")
                                , "Line No." = field("Line No.")
                                , Type = field(Type)
                                , "No." = field("No.");
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        CurrPage.CrossSales.Page.mySetSalesHeader(Rec);
    end;
}