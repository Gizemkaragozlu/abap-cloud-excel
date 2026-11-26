CLASS ltcl_import DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_order,
        material      TYPE string,
        quantity      TYPE i,
        delivery_date TYPE d,
      END OF ty_order,
      tt_orders TYPE STANDARD TABLE OF ty_order WITH EMPTY KEY.

    METHODS header_aliases_and_dates FOR TESTING RAISING zcx_excel_sheet.
    METHODS positional_without_header FOR TESTING RAISING zcx_excel_sheet.
    METHODS invalid_value_is_rejected FOR TESTING RAISING zcx_excel_sheet.
    METHODS required_column_missing FOR TESTING RAISING zcx_excel_sheet.
    METHODS template_roundtrip FOR TESTING RAISING zcx_excel_sheet.
    METHODS format_detection FOR TESTING.

    METHODS aliases RETURNING VALUE(result) TYPE zcl_excel_import=>ty_aliases.
    METHODS utf8 IMPORTING text TYPE string RETURNING VALUE(result) TYPE xstring.
ENDCLASS.


CLASS ltcl_import IMPLEMENTATION.
  METHOD header_aliases_and_dates.
    DATA(text) = |Malzeme;Miktar;Teslim Tarihi\r\n|
              && |M-100;12;26.11.2026\r\n|
              && |M-200;3;2026-12-01\r\n|.

    DATA(orders) = VALUE tt_orders( ).
    DATA report TYPE zcl_excel_import=>ty_report.
    CALL METHOD zcl_excel_import=>import
      EXPORTING
        content   = utf8( text )
        format    = zcl_excel_import=>format_csv
        header    = abap_true
        aliases   = aliases( )
        required  = VALUE string_table( ( `MATERIAL` ) ( `QUANTITY` ) )
        separator = `;`
      CHANGING
        data      = orders
      RECEIVING
        report    = report.

    cl_abap_unit_assert=>assert_equals( act = report-rows_read exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = report-rows_imported exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lines( orders ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = orders[ 1 ]-material exp = `M-100` ).
    cl_abap_unit_assert=>assert_equals( act = orders[ 1 ]-quantity exp = 12 ).
    cl_abap_unit_assert=>assert_equals( act = orders[ 1 ]-delivery_date exp = `20261126` ).
    cl_abap_unit_assert=>assert_equals( act = orders[ 2 ]-delivery_date exp = `20261201` ).
  ENDMETHOD.


  METHOD positional_without_header.
    DATA(orders) = VALUE tt_orders( ).
    DATA report TYPE zcl_excel_import=>ty_report.
    CALL METHOD zcl_excel_import=>import
      EXPORTING
        content   = utf8( |M-300;7;20261202\r\n| )
        format    = zcl_excel_import=>format_csv
        header    = abap_false
        separator = `;`
      CHANGING
        data      = orders
      RECEIVING
        report    = report.

    cl_abap_unit_assert=>assert_equals( act = lines( orders ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = orders[ 1 ]-material exp = `M-300` ).
    cl_abap_unit_assert=>assert_equals( act = orders[ 1 ]-quantity exp = 7 ).
  ENDMETHOD.


  METHOD invalid_value_is_rejected.
    DATA(orders) = VALUE tt_orders( ).
    DATA report TYPE zcl_excel_import=>ty_report.
    CALL METHOD zcl_excel_import=>import
      EXPORTING
        content   = utf8( |M-400;abc;20261203\r\nM-500;5;20261204\r\n| )
        format    = zcl_excel_import=>format_csv
        header    = abap_false
        separator = `;`
      CHANGING
        data      = orders
      RECEIVING
        report    = report.

    cl_abap_unit_assert=>assert_equals( act = report-rows_imported exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = report-rows_rejected exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( orders ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = orders[ 1 ]-material exp = `M-500` ).
    cl_abap_unit_assert=>assert_equals( act = lines( report-messages ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = report-messages[ 1 ]-severity
      exp = zcl_excel_import=>severity_error ).
  ENDMETHOD.


  METHOD required_column_missing.
    DATA(orders) = VALUE tt_orders( ).
    DATA report TYPE zcl_excel_import=>ty_report.
    CALL METHOD zcl_excel_import=>import
      EXPORTING
        content   = utf8( |Malzeme\r\nM-600\r\n| )
        format    = zcl_excel_import=>format_csv
        header    = abap_true
        aliases   = aliases( )
        required  = VALUE string_table( ( `QUANTITY` ) )
        separator = `;`
      CHANGING
        data      = orders
      RECEIVING
        report    = report.

    DATA(error_count) = 0.
    LOOP AT report-messages INTO DATA(message).
      IF message-severity = zcl_excel_import=>severity_error.
        error_count += 1.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_equals( act = lines( orders ) exp = 0 ).
    cl_abap_unit_assert=>assert_initial( act = report-rows_imported ).
    cl_abap_unit_assert=>assert_equals( act = error_count exp = 1 ).
  ENDMETHOD.


  METHOD template_roundtrip.
    DATA(headings) = VALUE string_table( ( `Malzeme` ) ( `Miktar` ) ( `Teslim Tarihi` ) ).
    DATA(sample) = VALUE zcl_excel_sheet=>ty_rows(
      ( cells = VALUE string_table( ( `M-700` ) ( `9` ) ( `26.11.2026` ) ) ) ).

    DATA(file) = zcl_excel_import=>template(
      headings   = headings
      sample     = sample
      format     = zcl_excel_import=>format_csv
      separator  = `;` ).

    DATA(orders) = VALUE tt_orders( ).
    DATA report TYPE zcl_excel_import=>ty_report.
    CALL METHOD zcl_excel_import=>import
      EXPORTING
        content   = file
        format    = zcl_excel_import=>format_csv
        header    = abap_true
        aliases   = aliases( )
        separator = `;`
      CHANGING
        data      = orders
      RECEIVING
        report    = report.

    cl_abap_unit_assert=>assert_equals( act = report-rows_imported exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = orders[ 1 ]-material exp = `M-700` ).
    cl_abap_unit_assert=>assert_equals( act = orders[ 1 ]-quantity exp = 9 ).
    cl_abap_unit_assert=>assert_equals( act = orders[ 1 ]-delivery_date exp = `20261126` ).
  ENDMETHOD.


  METHOD format_detection.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_excel_import=>detect_format( filename = `orders.XLSX` )
      exp = zcl_excel_import=>format_xlsx ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_excel_import=>detect_format( filename = `orders.csv` )
      exp = zcl_excel_import=>format_csv ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_excel_import=>detect_format( content = CONV xstring( '504B0304' ) )
      exp = zcl_excel_import=>format_xlsx ).
  ENDMETHOD.


  METHOD aliases.
    result = VALUE #(
      ( label = `Malzeme`       field = `MATERIAL` )
      ( label = `Miktar`        field = `QUANTITY` )
      ( label = `Teslim Tarihi` field = `DELIVERY_DATE` ) ).
  ENDMETHOD.


  METHOD utf8.
    result = cl_abap_conv_codepage=>create_out( codepage = `UTF-8` )->convert( text ).
  ENDMETHOD.
ENDCLASS.
