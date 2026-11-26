CLASS ltcl_csv DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_person,
        name TYPE string,
        city TYPE string,
      END OF ty_person,
      ty_people TYPE STANDARD TABLE OF ty_person WITH EMPTY KEY.

    METHODS roundtrip FOR TESTING RAISING zcx_excel_sheet.
    METHODS quoted_cells FOR TESTING RAISING zcx_excel_sheet.
    METHODS empty_file FOR TESTING.
ENDCLASS.


CLASS ltcl_csv IMPLEMENTATION.
  METHOD roundtrip.
    DATA people TYPE ty_people.
    people = VALUE #(
      ( name = `Ada` city = `Ankara` )
      ( name = `Lin, G` city = `Izmir` ) ).

    DATA(file) = zcl_excel_sheet=>write_csv( people ).
    DATA(rows) = zcl_excel_sheet=>read_csv( content = file skip_header = abap_true ).

    cl_abap_unit_assert=>assert_equals( act = lines( rows ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = rows[ 1 ]-cells[ 1 ] exp = `Ada` ).
    cl_abap_unit_assert=>assert_equals( act = rows[ 1 ]-cells[ 2 ] exp = `Ankara` ).
    cl_abap_unit_assert=>assert_equals( act = rows[ 2 ]-cells[ 1 ] exp = `Lin, G` ).
    cl_abap_unit_assert=>assert_equals( act = rows[ 2 ]-cells[ 2 ] exp = `Izmir` ).
  ENDMETHOD.

  METHOD quoted_cells.
    DATA(text) = |name;note\r\n|
              && |"Ada";"Ankara, Merkez"\r\n|
              && |"Lin, ""G""";"Multi\r\nline"\r\n|.
    DATA(file) = cl_abap_conv_codepage=>create_out( codepage = `UTF-8` )->convert( text ).

    DATA(rows) = zcl_excel_sheet=>read_csv(
      content     = file
      separator   = `;`
      skip_header = abap_true ).

    cl_abap_unit_assert=>assert_equals( act = lines( rows ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = rows[ 1 ]-cells[ 2 ] exp = `Ankara, Merkez` ).
    cl_abap_unit_assert=>assert_equals( act = rows[ 2 ]-cells[ 1 ] exp = `Lin, "G"` ).
    cl_abap_unit_assert=>assert_equals( act = rows[ 2 ]-cells[ 2 ] exp = |Multi\r\nline| ).
  ENDMETHOD.


  METHOD empty_file.
    DATA(empty) = VALUE xstring( ).
    TRY.
        zcl_excel_sheet=>read_csv( empty ).
        cl_abap_unit_assert=>fail( msg = `An empty file must raise` ).
      CATCH zcx_excel_sheet INTO DATA(error).
        cl_abap_unit_assert=>assert_not_initial( error->message ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
