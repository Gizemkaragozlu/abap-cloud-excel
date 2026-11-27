CLASS zcl_excel_order_demo DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    CLASS-METHODS run
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_order,
        material      TYPE string,
        quantity      TYPE i,
        delivery_date TYPE d,
        vendor        TYPE string,
        note          TYPE string,
      END OF ty_order,
      tt_orders TYPE STANDARD TABLE OF ty_order WITH EMPTY KEY.

    CLASS-METHODS aliases
      RETURNING
        VALUE(result) TYPE zcl_excel_import=>ty_aliases.

    CLASS-METHODS validate
      IMPORTING
        orders          TYPE tt_orders
      CHANGING
        messages        TYPE zcl_excel_import=>ty_messages.

    CLASS-METHODS create_orders
      IMPORTING
        orders TYPE tt_orders.
ENDCLASS.


CLASS zcl_excel_order_demo IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    run( out ).
  ENDMETHOD.


  METHOD run.
    DATA(file_format) = COND string(
      WHEN zcl_excel_sheet=>is_xlsx_available( ) = abap_true
        THEN zcl_excel_import=>format_xlsx
      ELSE zcl_excel_import=>format_csv ).

    DATA(headings) = VALUE string_table(
      ( `Malzeme` )
      ( `Miktar` )
      ( `Teslim Tarihi` )
      ( `Tedarikçi` )
      ( `Not` ) ).

    DATA(sample) = VALUE zcl_excel_sheet=>ty_rows(
      ( cells = VALUE string_table(
          ( `M-100` ) ( `12` ) ( `26.11.2026` ) ( `Tedarikci A` ) ( `Hizli` ) ) )
      ( cells = VALUE string_table(
          ( `M-200` ) ( `3` ) ( `2026-12-01` ) ( `Tedarikci B` ) ( `` ) ) ) ).

    TRY.
        DATA(file) = zcl_excel_import=>template(
          headings   = headings
          sample     = sample
          format     = file_format
          sheet_name = `Siparisler`
          separator  = `;` ).
        out->write( |Template created: { file_format }| ).

        DATA(orders) = VALUE tt_orders( ).
        DATA report TYPE zcl_excel_import=>ty_report.
        CALL METHOD zcl_excel_import=>import
          EXPORTING
            content   = file
            format    = file_format
            header    = abap_true
            aliases   = aliases( )
            required  = VALUE string_table(
              ( `MATERIAL` ) ( `QUANTITY` ) ( `DELIVERY_DATE` ) )
            separator = `;`
          CHANGING
            target    = orders
          RECEIVING
            report    = report.

        out->write( |Read { report-rows_read }, imported { report-rows_imported }, rejected { report-rows_rejected }| ).

        DATA(messages) = report-messages.
        validate( EXPORTING orders = orders CHANGING messages = messages ).

        LOOP AT messages INTO DATA(message).
          out->write( |[{ message-severity }] row { message-row } { message-field }: { message-text }| ).
        ENDLOOP.

        create_orders( orders ).
      CATCH zcx_excel_sheet INTO DATA(error).
        out->write( |Excel error: { error->get_longtext( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD aliases.
    result = VALUE #(
      ( label = `Malzeme`       field = `MATERIAL` )
      ( label = `Miktar`        field = `QUANTITY` )
      ( label = `Teslim Tarihi` field = `DELIVERY_DATE` )
      ( label = `Tedarikçi`     field = `VENDOR` )
      ( label = `Not`           field = `NOTE` ) ).
  ENDMETHOD.


  METHOD validate.
    LOOP AT orders INTO DATA(order).
      DATA(row) = sy-tabix.

      IF order-material IS INITIAL.
        APPEND VALUE zcl_excel_import=>ty_message(
          row      = row
          field    = `MATERIAL`
          severity = zcl_excel_import=>severity_error
          text     = `Material is required.` ) TO messages.
      ENDIF.

      IF order-quantity <= 0.
        APPEND VALUE zcl_excel_import=>ty_message(
          row      = row
          field    = `QUANTITY`
          severity = zcl_excel_import=>severity_error
          text     = `Quantity must be greater than zero.` ) TO messages.
      ENDIF.

      IF order-delivery_date < sy-datum.
        APPEND VALUE zcl_excel_import=>ty_message(
          row      = row
          field    = `DELIVERY_DATE`
          severity = zcl_excel_import=>severity_error
          text     = `Delivery date is in the past.` ) TO messages.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD create_orders.
    " Integration point for your public cloud program:
    "   - RAP action: call your create action / MODIFY draft entity with orders
    "   - no GUI_UPLOAD, no abap2xlsx, no classic BAPI required
    " The table is already typed, mapped and converted at this point.
  ENDMETHOD.
ENDCLASS.
