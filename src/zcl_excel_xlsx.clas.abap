CLASS zcl_excel_xlsx DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_excel_xlsx.

  PRIVATE SECTION.
    " XCO needs a statically typed target table for row streams. 64 columns
    " cover columns A..BL; read_into() can use any flat structure instead.
    TYPES:
      BEGIN OF ty_wide,
        c01 TYPE string,
        c02 TYPE string,
        c03 TYPE string,
        c04 TYPE string,
        c05 TYPE string,
        c06 TYPE string,
        c07 TYPE string,
        c08 TYPE string,
        c09 TYPE string,
        c10 TYPE string,
        c11 TYPE string,
        c12 TYPE string,
        c13 TYPE string,
        c14 TYPE string,
        c15 TYPE string,
        c16 TYPE string,
        c17 TYPE string,
        c18 TYPE string,
        c19 TYPE string,
        c20 TYPE string,
        c21 TYPE string,
        c22 TYPE string,
        c23 TYPE string,
        c24 TYPE string,
        c25 TYPE string,
        c26 TYPE string,
        c27 TYPE string,
        c28 TYPE string,
        c29 TYPE string,
        c30 TYPE string,
        c31 TYPE string,
        c32 TYPE string,
        c33 TYPE string,
        c34 TYPE string,
        c35 TYPE string,
        c36 TYPE string,
        c37 TYPE string,
        c38 TYPE string,
        c39 TYPE string,
        c40 TYPE string,
        c41 TYPE string,
        c42 TYPE string,
        c43 TYPE string,
        c44 TYPE string,
        c45 TYPE string,
        c46 TYPE string,
        c47 TYPE string,
        c48 TYPE string,
        c49 TYPE string,
        c50 TYPE string,
        c51 TYPE string,
        c52 TYPE string,
        c53 TYPE string,
        c54 TYPE string,
        c55 TYPE string,
        c56 TYPE string,
        c57 TYPE string,
        c58 TYPE string,
        c59 TYPE string,
        c60 TYPE string,
        c61 TYPE string,
        c62 TYPE string,
        c63 TYPE string,
        c64 TYPE string,
      END OF ty_wide,
      ty_wide_table TYPE STANDARD TABLE OF ty_wide WITH EMPTY KEY.

    METHODS transfer
      IMPORTING
        content     TYPE xstring
        sheet       TYPE i
        sheet_name  TYPE string
        skip_header TYPE abap_bool
        as_string   TYPE abap_bool
      CHANGING
        data        TYPE ANY TABLE
      RAISING
        zcx_excel_sheet.

    METHODS row_width
      IMPORTING
        row           TYPE ty_wide
      RETURNING
        VALUE(result) TYPE i.

    METHODS cells_from_wide
      IMPORTING
        row           TYPE ty_wide
        width         TYPE i
      RETURNING
        VALUE(result) TYPE string_table.
ENDCLASS.


CLASS zcl_excel_xlsx IMPLEMENTATION.
  METHOD zif_excel_xlsx~read_rows.
    DATA wide TYPE ty_wide_table.

    transfer(
      EXPORTING
        content     = content
        sheet       = sheet
        sheet_name  = sheet_name
        skip_header = skip_header
        as_string   = abap_true
      CHANGING
        data        = wide ).

    DATA(width) = 0.
    LOOP AT wide INTO DATA(wide_row).
      DATA(used) = row_width( wide_row ).
      IF used > width.
        width = used.
      ENDIF.
    ENDLOOP.

    LOOP AT wide INTO wide_row.
      APPEND VALUE zif_excel_xlsx=>ty_row(
        cells = cells_from_wide( row = wide_row width = width ) ) TO rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_excel_xlsx~read_into.
    transfer(
      EXPORTING
        content     = content
        sheet       = sheet
        sheet_name  = sheet_name
        skip_header = skip_header
        as_string   = abap_false
      CHANGING
        data        = data ).
  ENDMETHOD.


  METHOD zif_excel_xlsx~write.
    TRY.
        DATA(document) = xco_cp_xlsx=>document->empty( )->write_access( ).
        DATA(grid)     = document->get_workbook( )->worksheet->at_position( 1 ).
        grid->set_name( sheet_name ).

        DATA(pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).
        DATA(result)  = grid->select( pattern
                        )->row_stream(
                        )->operation->write_from( REF #( data )
                        )->execute( ).

        IF result->succeeded = abap_false.
          RAISE EXCEPTION TYPE zcx_excel_sheet
            EXPORTING
              message = |XLSX write failed with { lines( result->messages ) } message(s).|.
        ENDIF.

        content = document->get_file_content( ).
      CATCH zcx_excel_sheet INTO DATA(sheet_error).
        RAISE EXCEPTION TYPE zcx_excel_sheet
          EXPORTING
            message  = sheet_error->message
            previous = sheet_error.
      CATCH cx_root INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_excel_sheet
          EXPORTING
            message  = |XLSX could not be created. { error->get_text( ) }|
            previous = error.
    ENDTRY.
  ENDMETHOD.


  METHOD zif_excel_xlsx~sheet_names.
    IF content IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_sheet EXPORTING message = `The file is empty.`.
    ENDIF.

    TRY.
        DATA(document) = xco_cp_xlsx=>document->for_file_content( content )->read_access( ).
        LOOP AT document->get_workbook( )->worksheet->all->get( ) INTO DATA(sheet).
          INSERT sheet->get_name( ) INTO TABLE names.
        ENDLOOP.
      CATCH cx_root INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_excel_sheet
          EXPORTING
            message  = |The file is not a valid XLSX document. { error->get_text( ) }|
            previous = error.
    ENDTRY.
  ENDMETHOD.


  METHOD transfer.
    IF content IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_sheet EXPORTING message = `The file is empty.`.
    ENDIF.
    IF sheet < 1.
      RAISE EXCEPTION TYPE zcx_excel_sheet
        EXPORTING message = `The worksheet position starts at 1.`.
    ENDIF.

    DATA(location) = |position { sheet }|.

    TRY.
        DATA(document) = xco_cp_xlsx=>document->for_file_content( content )->read_access( ).
        DATA(grid)     = document->get_workbook( )->worksheet->at_position( sheet ).

        IF sheet_name IS NOT INITIAL.
          grid = document->get_workbook( )->worksheet->for_name( sheet_name ).
          location = |name '{ sheet_name }'|.
        ENDIF.

        IF grid->exists( ) = abap_false.
          RAISE EXCEPTION TYPE zcx_excel_sheet
            EXPORTING message = |The worksheet { location } was not found.|.
        ENDIF.

        IF skip_header = abap_true.
          DATA(pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
                          )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 2 )
                          )->get_pattern( ).
        ELSE.
          pattern = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).
        ENDIF.

        DATA(operation) = grid->select( pattern )->row_stream( )->operation->write_to( REF #( data ) ).
        IF as_string = abap_true.
          DATA(result) = operation
            ->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
            )->execute( ).
        ELSE.
          result = operation
            ->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->best_effort
            )->execute( ).
        ENDIF.

        IF result->succeeded = abap_false.
          RAISE EXCEPTION TYPE zcx_excel_sheet
            EXPORTING
              message = |XLSX read failed with { lines( result->messages ) } message(s).|.
        ENDIF.
      CATCH zcx_excel_sheet INTO DATA(sheet_error).
        RAISE EXCEPTION TYPE zcx_excel_sheet
          EXPORTING
            message  = sheet_error->message
            previous = sheet_error.
      CATCH cx_root INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_excel_sheet
          EXPORTING
            message  = |Only .xlsx files can be read here. { error->get_text( ) }|
            previous = error.
    ENDTRY.
  ENDMETHOD.


  METHOD row_width.
    DATA(descr) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( row ) ).
    LOOP AT descr->components INTO DATA(component).
      ASSIGN COMPONENT component-name OF STRUCTURE row TO FIELD-SYMBOL(<cell>).
      IF <cell> IS NOT INITIAL.
        result = sy-tabix.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD cells_from_wide.
    DO width TIMES.
      ASSIGN COMPONENT sy-index OF STRUCTURE row TO FIELD-SYMBOL(<cell>).
      INSERT <cell> INTO TABLE result.
    ENDDO.
  ENDMETHOD.
ENDCLASS.
