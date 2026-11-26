CLASS zcl_excel_sheet DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    " XLSX is handled by the released XCO API (XCO_CP_XLSX). The adapter is
    " loaded dynamically so this facade also compiles on releases without XCO.
    " CSV is pure ABAP and works everywhere.
    CONSTANTS xlsx_mime_type TYPE string VALUE `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`.
    CONSTANTS csv_mime_type  TYPE string VALUE `text/csv`.
    CONSTANTS max_columns    TYPE i VALUE 64.

    TYPES:
      BEGIN OF ty_row,
        cells TYPE string_table,
      END OF ty_row,
      ty_rows  TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY,
      ty_names TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    CLASS-METHODS is_xlsx_available
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS read
      IMPORTING
        content     TYPE xstring
        sheet       TYPE i DEFAULT 1
        sheet_name  TYPE string OPTIONAL
        skip_header TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rows) TYPE ty_rows
      RAISING
        zcx_excel_sheet.

    CLASS-METHODS read_into
      IMPORTING
        content     TYPE xstring
        sheet       TYPE i DEFAULT 1
        sheet_name  TYPE string OPTIONAL
        skip_header TYPE abap_bool DEFAULT abap_false
      CHANGING
        data        TYPE ANY TABLE
      RAISING
        zcx_excel_sheet.

    CLASS-METHODS read_dynamic
      IMPORTING
        content      TYPE xstring
        sheet        TYPE i DEFAULT 1
        sheet_name   TYPE string OPTIONAL
        header_row   TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(table) TYPE REF TO data
      RAISING
        zcx_excel_sheet.

    CLASS-METHODS write
      IMPORTING
        data           TYPE ANY TABLE
        sheet_name     TYPE string DEFAULT `Sheet1`
        header         TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(content) TYPE xstring
      RAISING
        zcx_excel_sheet.

    CLASS-METHODS read_csv
      IMPORTING
        content     TYPE xstring
        separator   TYPE string DEFAULT `,`
        skip_header TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rows) TYPE ty_rows
      RAISING
        zcx_excel_sheet.

    CLASS-METHODS write_csv
      IMPORTING
        data           TYPE ANY TABLE
        separator      TYPE string DEFAULT `,`
        header         TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(content) TYPE xstring
      RAISING
        zcx_excel_sheet.

    CLASS-METHODS get_sheet_names
      IMPORTING
        content       TYPE xstring
      RETURNING
        VALUE(names)  TYPE ty_names
      RAISING
        zcx_excel_sheet.

  PRIVATE SECTION.
    CLASS-METHODS xlsx_provider
      RETURNING
        VALUE(provider) TYPE REF TO zif_excel_xlsx
      RAISING
        zcx_excel_sheet.

    CLASS-METHODS assert_table
      IMPORTING
        data TYPE ANY TABLE
      RAISING
        zcx_excel_sheet.

    CLASS-METHODS line_components
      IMPORTING
        data          TYPE ANY TABLE
      RETURNING
        VALUE(result) TYPE cl_abap_structdescr=>component_table.

    CLASS-METHODS string_rows
      IMPORTING
        width         TYPE i
      RETURNING
        VALUE(result) TYPE REF TO data
      RAISING
        zcx_excel_sheet.

    CLASS-METHODS cells_from_line
      IMPORTING
        line       TYPE any
        components TYPE cl_abap_structdescr=>component_table
      RETURNING
        VALUE(result) TYPE string_table
      RAISING
        zcx_excel_sheet.

    CLASS-METHODS field_name
      IMPORTING
        name          TYPE string
        index         TYPE i
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS unique_name
      IMPORTING
        name          TYPE string
        used          TYPE string_table
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS assert_separator
      IMPORTING
        separator TYPE string
      RAISING
        zcx_excel_sheet.

    CLASS-METHODS parse_csv
      IMPORTING
        text          TYPE string
        separator     TYPE string
      RETURNING
        VALUE(result) TYPE ty_rows.

    CLASS-METHODS escape_csv
      IMPORTING
        cell          TYPE string
        separator     TYPE string
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS assert_sheet_name
      IMPORTING
        sheet_name TYPE string
      RAISING
        zcx_excel_sheet.
ENDCLASS.


CLASS zcl_excel_sheet IMPLEMENTATION.
  METHOD is_xlsx_available.
    TRY.
        cl_abap_typedescr=>describe_by_name( 'XCO_CP_XLSX' ).
        cl_abap_typedescr=>describe_by_name( 'ZCL_EXCEL_XLSX' ).
        result = abap_true.
      CATCH cx_root.
        result = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD xlsx_provider.
    IF is_xlsx_available( ) = abap_false.
      RAISE EXCEPTION TYPE zcx_excel_sheet
        EXPORTING
          message = `XLSX support needs XCO_CP_XLSX and the ZCL_EXCEL_XLSX adapter; use CSV on older releases.`.
    ENDIF.
    CREATE OBJECT provider TYPE ('ZCL_EXCEL_XLSX').
  ENDMETHOD.


  METHOD read.
    DATA(provider) = xlsx_provider( ).
    rows = provider->read_rows(
      content     = content
      sheet       = sheet
      sheet_name  = sheet_name
      skip_header = skip_header ).
  ENDMETHOD.


  METHOD read_into.
    assert_table( data ).
    CLEAR data.

    DATA(provider) = xlsx_provider( ).
    provider->read_into(
      EXPORTING
        content     = content
        sheet       = sheet
        sheet_name  = sheet_name
        skip_header = skip_header
      CHANGING
        data        = data ).
  ENDMETHOD.


  METHOD read_dynamic.
    DATA(rows) = read(
      content     = content
      sheet       = sheet
      sheet_name  = sheet_name
      skip_header = abap_false ).

    DATA(width) = 0.
    LOOP AT rows INTO DATA(row).
      IF lines( row-cells ) > width.
        width = lines( row-cells ).
      ENDIF.
    ENDLOOP.

    IF width = 0.
      CREATE DATA table TYPE string_table.
      RETURN.
    ENDIF.

    DATA(names) = VALUE string_table( ).

    DATA(first_data) = 1.
    IF header_row = abap_true.
      first_data = 2.
      IF lines( rows ) > 0.
        LOOP AT rows[ 1 ]-cells INTO DATA(heading).
          INSERT unique_name(
            name = field_name( name = heading index = sy-tabix )
            used = names ) INTO TABLE names.
        ENDLOOP.
      ENDIF.
      WHILE lines( names ) < width.
        INSERT unique_name(
          name = field_name( name = `` index = lines( names ) + 1 )
          used = names ) INTO TABLE names.
      ENDWHILE.
    ELSE.
      DO width TIMES.
        INSERT |C{ sy-index WIDTH = 3 ALIGN = RIGHT PAD = '0' }| INTO TABLE names.
      ENDDO.
    ENDIF.

    DATA(components) = VALUE cl_abap_structdescr=>component_table( ).
    LOOP AT names INTO DATA(component_name).
      INSERT VALUE #(
        name = component_name
        type = CAST cl_abap_datadescr( cl_abap_elemdescr=>get_string( ) ) ) INTO TABLE components.
    ENDLOOP.

    DATA(table_descr) = cl_abap_tabledescr=>create(
      p_line_type  = cl_abap_structdescr=>create( components )
      p_table_kind = cl_abap_tabledescr=>tablekind_std ).
    CREATE DATA table TYPE HANDLE table_descr.
    ASSIGN table->* TO FIELD-SYMBOL(<table>).

    LOOP AT rows INTO row FROM first_data.
      INSERT INITIAL LINE INTO TABLE <table> ASSIGNING FIELD-SYMBOL(<line>).
      LOOP AT row-cells INTO DATA(cell).
        ASSIGN COMPONENT sy-tabix OF STRUCTURE <line> TO FIELD-SYMBOL(<field>).
        IF sy-subrc = 0.
          <field> = cell.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD write.
    assert_table( data ).
    assert_sheet_name( sheet_name ).

    DATA(components) = line_components( data ).
    DATA(created) = string_rows( lines( components ) ).
    ASSIGN created->* TO FIELD-SYMBOL(<rows>).

    IF header = abap_true.
      INSERT INITIAL LINE INTO TABLE <rows> ASSIGNING FIELD-SYMBOL(<head>).
      LOOP AT components INTO DATA(component).
        ASSIGN COMPONENT sy-tabix OF STRUCTURE <head> TO FIELD-SYMBOL(<heading>).
        <heading> = component-name.
      ENDLOOP.
    ENDIF.

    LOOP AT data ASSIGNING FIELD-SYMBOL(<line>).
      DATA(cells) = cells_from_line( line = <line> components = components ).
      INSERT INITIAL LINE INTO TABLE <rows> ASSIGNING FIELD-SYMBOL(<out>).
      LOOP AT cells INTO DATA(cell).
        ASSIGN COMPONENT sy-tabix OF STRUCTURE <out> TO FIELD-SYMBOL(<column>).
        <column> = cell.
      ENDLOOP.
    ENDLOOP.

    DATA(provider) = xlsx_provider( ).
    content = provider->write( data = <rows> sheet_name = sheet_name ).
  ENDMETHOD.


  METHOD read_csv.
    assert_separator( separator ).
    IF content IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_sheet EXPORTING message = `The file is empty.`.
    ENDIF.

    TRY.
        DATA(text) = cl_abap_conv_codepage=>create_in( codepage = `UTF-8` )->convert( content ).
      CATCH cx_root INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_excel_sheet
          EXPORTING
            message  = error->get_text( )
            previous = error.
    ENDTRY.

    DATA(bom_bytes) = CONV xstring( 'EFBBBF' ).
    DATA(bom) = cl_abap_conv_codepage=>create_in( codepage = `UTF-8` )->convert( bom_bytes ).
    IF strlen( text ) >= strlen( bom ) AND substring( val = text len = strlen( bom ) ) = bom.
      text = substring( val = text off = strlen( bom ) ).
    ENDIF.

    rows = parse_csv( text = text separator = separator ).
    IF skip_header = abap_true AND lines( rows ) > 0.
      DELETE rows INDEX 1.
    ENDIF.
  ENDMETHOD.


  METHOD write_csv.
    assert_separator( separator ).
    assert_table( data ).

    DATA(components) = line_components( data ).
    DATA(text) = ``.
    DATA(line_no) = 0.

    IF header = abap_true.
      text = concat_lines_of(
        table = VALUE string_table(
          FOR component IN components ( escape_csv( cell = component-name separator = separator ) ) )
        sep = separator ).
      line_no = 1.
    ENDIF.

    LOOP AT data ASSIGNING FIELD-SYMBOL(<line>).
      DATA(cells) = cells_from_line( line = <line> components = components ).
      DATA(line) = concat_lines_of(
        table = VALUE string_table( FOR cell IN cells ( escape_csv( cell = cell separator = separator ) ) )
        sep   = separator ).
      IF line_no > 0.
        text &&= cl_abap_char_utilities=>cr_lf.
      ENDIF.
      text &&= line.
      line_no += 1.
    ENDLOOP.

    content = cl_abap_conv_codepage=>create_out( codepage = `UTF-8` )->convert( text ).
  ENDMETHOD.


  METHOD get_sheet_names.
    DATA(provider) = xlsx_provider( ).
    names = provider->sheet_names( content ).
  ENDMETHOD.


  METHOD assert_table.
    DATA(table_descr) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( data ) ).
    IF table_descr->table_kind <> cl_abap_tabledescr=>tablekind_std
        OR table_descr->get_table_line_type( )->kind <> cl_abap_typedescr=>kind_struct.
      RAISE EXCEPTION TYPE zcx_excel_sheet
        EXPORTING
          message = `The data must be a standard table of structures.`.
    ENDIF.
  ENDMETHOD.


  METHOD line_components.
    DATA(table_descr) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( data ) ).
    result = CAST cl_abap_structdescr( table_descr->get_table_line_type( ) )->get_components( ).
  ENDMETHOD.


  METHOD string_rows.
    IF width < 1.
      RAISE EXCEPTION TYPE zcx_excel_sheet EXPORTING message = `The table has no columns.`.
    ENDIF.

    DATA(components) = VALUE cl_abap_structdescr=>component_table( ).
    DO width TIMES.
      INSERT VALUE #(
        name = |C{ sy-index WIDTH = 3 ALIGN = RIGHT PAD = '0' }|
        type = CAST cl_abap_datadescr( cl_abap_elemdescr=>get_string( ) ) ) INTO TABLE components.
    ENDDO.

    DATA(table_descr) = cl_abap_tabledescr=>create(
      p_line_type  = cl_abap_structdescr=>create( components )
      p_table_kind = cl_abap_tabledescr=>tablekind_std ).
    CREATE DATA result TYPE HANDLE table_descr.
  ENDMETHOD.


  METHOD cells_from_line.
    LOOP AT components INTO DATA(component).
      ASSIGN COMPONENT component-name OF STRUCTURE line TO FIELD-SYMBOL(<value>).
      IF sy-subrc <> 0.
        INSERT `` INTO TABLE result.
        CONTINUE.
      ENDIF.

      CASE component-type->type_kind.
        WHEN cl_abap_typedescr=>typekind_date.
          INSERT |{ <value> DATE = ISO }| INTO TABLE result.
        WHEN cl_abap_typedescr=>typekind_time.
          INSERT |{ <value> TIME = ISO }| INTO TABLE result.
        WHEN cl_abap_typedescr=>typekind_oref
            OR cl_abap_typedescr=>typekind_dref
            OR cl_abap_typedescr=>typekind_struct1
            OR cl_abap_typedescr=>typekind_struct2
            OR cl_abap_typedescr=>typekind_table.
          RAISE EXCEPTION TYPE zcx_excel_sheet
            EXPORTING
              message = |Component { component-name } is not a flat field.|
              field   = component-name.
        WHEN OTHERS.
          INSERT |{ <value> }| INTO TABLE result.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD field_name.
    DATA(raw) = to_upper( name ).
    DATA(clean) = ``.
    DATA(offset) = 0.
    WHILE offset < strlen( raw ).
      DATA(char) = substring( val = raw off = offset len = 1 ).
      offset += 1.
      IF char CO `ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_`.
        clean &&= char.
      ELSE.
        clean &&= `_`.
      ENDIF.
    ENDWHILE.

    SHIFT clean LEFT DELETING LEADING `_`.
    IF clean IS INITIAL.
      clean = |C{ index WIDTH = 3 ALIGN = RIGHT PAD = '0' }|.
    ELSEIF substring( val = clean len = 1 ) CO `0123456789`.
      clean = |C{ clean }|.
    ENDIF.
    IF strlen( clean ) > 30.
      clean = substring( val = clean len = 30 ).
    ENDIF.
    result = clean.
  ENDMETHOD.


  METHOD unique_name.
    result = name.
    DATA(suffix) = 1.
    WHILE line_exists( used[ table_line = result ] ).
      suffix += 1.
      DATA(tail) = |_{ suffix }|.
      DATA(base_len) = 30 - strlen( tail ).
      IF base_len < 1.
        base_len = 1.
      ENDIF.
      IF strlen( name ) < base_len.
        base_len = strlen( name ).
      ENDIF.
      result = |{ substring( val = name len = base_len ) }{ tail }|.
    ENDWHILE.
  ENDMETHOD.


  METHOD assert_separator.
    IF strlen( separator ) <> 1.
      RAISE EXCEPTION TYPE zcx_excel_sheet
        EXPORTING
          message = `The CSV separator must be one character.`.
    ENDIF.
  ENDMETHOD.


  METHOD parse_csv.
    DATA cells TYPE string_table.
    DATA cell TYPE string.
    DATA quoted TYPE abap_bool.
    DATA offset TYPE i VALUE 0.
    DATA(length) = strlen( text ).

    WHILE offset < length.
      DATA(char) = substring( val = text off = offset len = 1 ).
      offset += 1.

      IF quoted = abap_true.
        IF char = `"`.
          IF offset < length AND substring( val = text off = offset len = 1 ) = `"`.
            cell &&= `"`.
            offset += 1.
          ELSE.
            quoted = abap_false.
          ENDIF.
        ELSE.
          cell &&= char.
        ENDIF.
        CONTINUE.
      ENDIF.

      IF char = `"`.
        quoted = abap_true.
      ELSEIF char = separator.
        INSERT cell INTO TABLE cells.
        CLEAR cell.
      ELSEIF char = |\n|.
        INSERT cell INTO TABLE cells.
        APPEND VALUE ty_row( cells = cells ) TO result.
        CLEAR cell.
        CLEAR cells.
      ELSEIF char = |\r|.
        IF offset >= length OR substring( val = text off = offset len = 1 ) <> |\n|.
          INSERT cell INTO TABLE cells.
          APPEND VALUE ty_row( cells = cells ) TO result.
          CLEAR cell.
          CLEAR cells.
        ENDIF.
      ELSE.
        cell &&= char.
      ENDIF.
    ENDWHILE.

    IF cell IS NOT INITIAL OR cells IS NOT INITIAL.
      INSERT cell INTO TABLE cells.
      APPEND VALUE ty_row( cells = cells ) TO result.
    ENDIF.
  ENDMETHOD.


  METHOD escape_csv.
    result = cell.
    IF cell CS separator OR cell CS `"` OR cell CS |\n| OR cell CS |\r|.
      REPLACE ALL OCCURRENCES OF `"` IN result WITH `""`.
      result = |"{ result }"|.
    ENDIF.
  ENDMETHOD.


  METHOD assert_sheet_name.
    IF sheet_name IS INITIAL
        OR strlen( sheet_name ) > 31
        OR find_any_of( val = sheet_name sub = `/\?*[]:` ) >= 0.
      RAISE EXCEPTION TYPE zcx_excel_sheet
        EXPORTING
          message = `The worksheet name must be 1 to 31 characters and must not contain /\?*[]:.`.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
