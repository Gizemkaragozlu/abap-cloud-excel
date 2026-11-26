CLASS zcl_excel_import DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_alias,
        label TYPE string,
        field TYPE string,
      END OF ty_alias,
      ty_aliases TYPE STANDARD TABLE OF ty_alias WITH EMPTY KEY,

      BEGIN OF ty_message,
        row      TYPE i,
        column   TYPE i,
        field    TYPE string,
        severity TYPE string,
        text     TYPE string,
      END OF ty_message,
      ty_messages TYPE STANDARD TABLE OF ty_message WITH EMPTY KEY,

      BEGIN OF ty_report,
        rows_read     TYPE i,
        rows_imported TYPE i,
        rows_rejected TYPE i,
        messages      TYPE ty_messages,
      END OF ty_report.

    CONSTANTS:
      format_xlsx      TYPE string VALUE `xlsx`,
      format_csv       TYPE string VALUE `csv`,
      severity_error   TYPE string VALUE `E`,
      severity_warning TYPE string VALUE `W`,
      severity_info    TYPE string VALUE `I`.

    CLASS-METHODS detect_format
      IMPORTING
        content         TYPE xstring OPTIONAL
        filename        TYPE string OPTIONAL
      RETURNING
        VALUE(result)   TYPE string.

    CLASS-METHODS rows
      IMPORTING
        content     TYPE xstring
        filename    TYPE string OPTIONAL
        format      TYPE string OPTIONAL
        sheet       TYPE i DEFAULT 1
        sheet_name  TYPE string OPTIONAL
        skip_header TYPE abap_bool DEFAULT abap_false
        separator   TYPE string DEFAULT `,`
      RETURNING
        VALUE(result) TYPE zcl_excel_sheet=>ty_rows
      RAISING
        zcx_excel_sheet.

    CLASS-METHODS import
      IMPORTING
        content      TYPE xstring
        filename     TYPE string OPTIONAL
        format       TYPE string OPTIONAL
        sheet        TYPE i DEFAULT 1
        sheet_name   TYPE string OPTIONAL
        header       TYPE abap_bool DEFAULT abap_true
        aliases      TYPE ty_aliases OPTIONAL
        required     TYPE string_table OPTIONAL
        separator    TYPE string DEFAULT `,`
        keep_invalid TYPE abap_bool DEFAULT abap_false
      CHANGING
        data         TYPE ANY TABLE
      RETURNING
        VALUE(report) TYPE ty_report
      RAISING
        zcx_excel_sheet.

    CLASS-METHODS template
      IMPORTING
        headings     TYPE string_table
        sample       TYPE zcl_excel_sheet=>ty_rows OPTIONAL
        format       TYPE string DEFAULT format_xlsx
        sheet_name   TYPE string DEFAULT `Upload`
        separator    TYPE string DEFAULT `;`
      RETURNING
        VALUE(content) TYPE xstring
      RAISING
        zcx_excel_sheet.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_map,
        field     TYPE string,
        column    TYPE i,
        expected  TYPE string,
        component TYPE cl_abap_structdescr=>component,
      END OF ty_map,
      ty_maps TYPE STANDARD TABLE OF ty_map WITH EMPTY KEY.

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

    CLASS-METHODS normalize
      IMPORTING
        text          TYPE string
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS build_map
      IMPORTING
        headings   TYPE string_table
        components TYPE cl_abap_structdescr=>component_table
        aliases    TYPE ty_aliases
        required   TYPE string_table
      CHANGING
        messages   TYPE ty_messages
      RETURNING
        VALUE(map) TYPE ty_maps
      RAISING
        zcx_excel_sheet.

    CLASS-METHODS set_field
      IMPORTING
        cell      TYPE string
        component TYPE cl_abap_structdescr=>component
      CHANGING
        field     TYPE any
      RETURNING
        VALUE(ok) TYPE abap_bool.

    CLASS-METHODS to_date
      IMPORTING
        cell          TYPE string
      EXPORTING
        value         TYPE d
        ok            TYPE abap_bool.

    CLASS-METHODS to_time
      IMPORTING
        cell          TYPE string
      EXPORTING
        value         TYPE t
        ok            TYPE abap_bool.

    CLASS-METHODS to_number
      IMPORTING
        cell          TYPE string
      EXPORTING
        value         TYPE decfloat16
        ok            TYPE abap_bool.

    CLASS-METHODS is_digits
      IMPORTING
        text          TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS cell_at
      IMPORTING
        cells         TYPE string_table
        column        TYPE i
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS empty_row
      IMPORTING
        cells         TYPE string_table
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS add_message
      IMPORTING
        row         TYPE i OPTIONAL
        column      TYPE i OPTIONAL
        field       TYPE string OPTIONAL
        severity    TYPE string
        text        TYPE string
      CHANGING
        messages    TYPE ty_messages.

    CLASS-METHODS string_table_of
      IMPORTING
        width         TYPE i
      RETURNING
        VALUE(result) TYPE REF TO data
      RAISING
        zcx_excel_sheet.
ENDCLASS.


CLASS zcl_excel_import IMPLEMENTATION.
  METHOD detect_format.
    IF filename IS NOT INITIAL.
      IF filename CS `.xlsx`.
        result = format_xlsx.
        RETURN.
      ELSEIF filename CS `.csv`.
        result = format_csv.
        RETURN.
      ENDIF.
    ENDIF.

    " ZIP local file header: PK.. (50 4B 03 04)
    IF content IS NOT INITIAL AND content+0(2) = '504B'.
      result = format_xlsx.
    ELSEIF content IS NOT INITIAL.
      result = format_csv.
    ENDIF.
  ENDMETHOD.


  METHOD rows.
    DATA(file_format) = format.
    IF file_format IS INITIAL.
      file_format = detect_format( content = content filename = filename ).
    ENDIF.

    CASE file_format.
      WHEN format_xlsx.
        result = zcl_excel_sheet=>read(
          content     = content
          sheet       = sheet
          sheet_name  = sheet_name
          skip_header = skip_header ).
      WHEN format_csv.
        result = zcl_excel_sheet=>read_csv(
          content     = content
          separator   = separator
          skip_header = skip_header ).
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_excel_sheet
          EXPORTING
            message = `Unknown file format. Use 'xlsx' or 'csv'.`.
    ENDCASE.
  ENDMETHOD.


  METHOD import.
    assert_table( data ).
    CLEAR data.

    DATA(file_format) = format.
    IF file_format IS INITIAL.
      file_format = detect_format( content = content filename = filename ).
    ENDIF.
    IF file_format IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_sheet
        EXPORTING
          message = `The file is empty or the format cannot be detected.`.
    ENDIF.

    DATA(source_rows) = rows(
      content    = content
      filename   = filename
      format     = file_format
      sheet      = sheet
      sheet_name = sheet_name
      separator  = separator ).

    report-rows_read = lines( source_rows ).
    IF report-rows_read = 0.
      RETURN.
    ENDIF.

    DATA(components) = line_components( data ).
    DATA(headings) = VALUE string_table( ).
    IF header = abap_true.
      headings = VALUE string_table( FOR cell IN source_rows[ 1 ]-cells ( cell ) ).
    ENDIF.

    DATA(map) = build_map(
      headings   = headings
      components = components
      aliases    = aliases
      required   = required
      messages   = report-messages ).

    LOOP AT report-messages INTO DATA(mapping_message).
      IF mapping_message-severity = severity_error.
        report-rows_rejected = report-rows_read - 1.
        IF report-rows_rejected < 0.
          report-rows_rejected = 0.
        ENDIF.
        RETURN.
      ENDIF.
    ENDLOOP.

    DATA(first_data) = 1.
    IF header = abap_true.
      first_data = 2.
    ENDIF.

    LOOP AT source_rows INTO DATA(source_row) FROM first_data.
      DATA(excel_row) = sy-tabix.

      IF empty_row( source_row-cells ) = abap_true.
        CONTINUE.
      ENDIF.

      INSERT INITIAL LINE INTO TABLE data ASSIGNING FIELD-SYMBOL(<line>).
      DATA(inserted_at) = lines( data ).
      DATA(valid) = abap_true.

      LOOP AT map INTO DATA(mapping).
        ASSIGN COMPONENT mapping-expected OF STRUCTURE <line> TO FIELD-SYMBOL(<field>).
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.

        DATA(cell) = cell_at( cells = source_row-cells column = mapping-column ).
        IF set_field( cell = cell component = mapping-component field = <field> ) = abap_false.
          add_message(
            row      = excel_row
            column   = mapping-column
            field    = mapping-expected
            severity = severity_error
            text     = |Value '{ cell }' cannot be converted to { mapping-expected }.|
            messages = report-messages ).
          valid = abap_false.
        ENDIF.
      ENDLOOP.

      IF valid = abap_true.
        report-rows_imported += 1.
      ELSE.
        report-rows_rejected += 1.
        IF keep_invalid = abap_false.
          DELETE data INDEX inserted_at.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD template.
    DATA(width) = lines( headings ).
    LOOP AT sample INTO DATA(sample_row).
      IF lines( sample_row-cells ) > width.
        width = lines( sample_row-cells ).
      ENDIF.
    ENDLOOP.

    IF width = 0.
      RAISE EXCEPTION TYPE zcx_excel_sheet EXPORTING message = `A template needs at least one heading.`.
    ENDIF.

    DATA(container) = string_table_of( width ).
    ASSIGN container->* TO FIELD-SYMBOL(<rows>).

    INSERT INITIAL LINE INTO TABLE <rows> ASSIGNING FIELD-SYMBOL(<heading_row>).
    LOOP AT headings INTO DATA(heading).
      ASSIGN COMPONENT sy-tabix OF STRUCTURE <heading_row> TO FIELD-SYMBOL(<heading_cell>).
      IF sy-subrc = 0.
        <heading_cell> = heading.
      ENDIF.
    ENDLOOP.

    LOOP AT sample INTO sample_row.
      INSERT INITIAL LINE INTO TABLE <rows> ASSIGNING FIELD-SYMBOL(<sample_line>).
      LOOP AT sample_row-cells INTO DATA(cell).
        ASSIGN COMPONENT sy-tabix OF STRUCTURE <sample_line> TO FIELD-SYMBOL(<sample_cell>).
        IF sy-subrc = 0.
          <sample_cell> = cell.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    CASE format.
      WHEN format_xlsx.
        content = zcl_excel_sheet=>write( data = <rows> sheet_name = sheet_name header = abap_false ).
      WHEN format_csv.
        content = zcl_excel_sheet=>write_csv( data = <rows> separator = separator header = abap_false ).
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_excel_sheet
          EXPORTING
            message = `Unknown file format. Use 'xlsx' or 'csv'.`.
    ENDCASE.
  ENDMETHOD.


  METHOD assert_table.
    DATA(table_descr) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( data ) ).
    IF table_descr->table_kind <> cl_abap_tabledescr=>tablekind_std
        OR table_descr->get_table_line_type( )->kind <> cl_abap_typedescr=>kind_struct.
      RAISE EXCEPTION TYPE zcx_excel_sheet
        EXPORTING
          message = `The target must be a standard table of flat structures.`.
    ENDIF.

    DATA(line_descr) = CAST cl_abap_structdescr( table_descr->get_table_line_type( ) ).
    LOOP AT line_descr->get_components( ) INTO DATA(component).
      IF component-type->kind <> cl_abap_typedescr=>kind_elem.
        RAISE EXCEPTION TYPE zcx_excel_sheet
          EXPORTING
            message = |Component { component-name } is not a flat field.|
            field   = component-name.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD line_components.
    DATA(table_descr) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( data ) ).
    result = CAST cl_abap_structdescr( table_descr->get_table_line_type( ) )->get_components( ).
  ENDMETHOD.


  METHOD normalize.
    result = to_upper( text ).
    REPLACE ALL OCCURRENCES OF ` ` IN result WITH ``.
    REPLACE ALL OCCURRENCES OF `_` IN result WITH ``.
    REPLACE ALL OCCURRENCES OF `-` IN result WITH ``.
    REPLACE ALL OCCURRENCES OF `.` IN result WITH ``.
    REPLACE ALL OCCURRENCES OF `/` IN result WITH ``.
    REPLACE ALL OCCURRENCES OF `(` IN result WITH ``.
    REPLACE ALL OCCURRENCES OF `)` IN result WITH ``.
    REPLACE ALL OCCURRENCES OF `İ` IN result WITH `I`.
    REPLACE ALL OCCURRENCES OF `ı` IN result WITH `I`.
    REPLACE ALL OCCURRENCES OF `Ş` IN result WITH `S`.
    REPLACE ALL OCCURRENCES OF `ş` IN result WITH `S`.
    REPLACE ALL OCCURRENCES OF `Ğ` IN result WITH `G`.
    REPLACE ALL OCCURRENCES OF `ğ` IN result WITH `G`.
    REPLACE ALL OCCURRENCES OF `Ü` IN result WITH `U`.
    REPLACE ALL OCCURRENCES OF `ü` IN result WITH `U`.
    REPLACE ALL OCCURRENCES OF `Ö` IN result WITH `O`.
    REPLACE ALL OCCURRENCES OF `ö` IN result WITH `O`.
    REPLACE ALL OCCURRENCES OF `Ç` IN result WITH `C`.
    REPLACE ALL OCCURRENCES OF `ç` IN result WITH `C`.
  ENDMETHOD.


  METHOD build_map.
    DATA taken TYPE STANDARD TABLE OF i WITH EMPTY KEY.

    DATA(component_index) = 0.
    LOOP AT components INTO DATA(component).
      component_index += 1.
      DATA(normalized_field) = normalize( component-name ).
      DATA(found) = 0.

      LOOP AT aliases INTO DATA(alias).
        IF normalize( alias-field ) <> normalized_field.
          CONTINUE.
        ENDIF.
        LOOP AT headings INTO DATA(alias_heading).
          IF normalize( alias_heading ) = normalize( alias-label ).
            found = sy-tabix.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF found > 0.
          EXIT.
        ENDIF.
      ENDLOOP.

      IF found = 0.
        LOOP AT headings INTO DATA(heading).
          IF normalize( heading ) = normalized_field.
            found = sy-tabix.
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.

      IF found = 0 AND headings IS INITIAL.
        found = component_index.
      ENDIF.

      IF found = 0.
        add_message(
          field    = component-name
          severity = severity_warning
          text     = `No matching Excel column; the field stays initial.`
          messages = messages ).
      ELSEIF line_exists( taken[ table_line = found ] ).
        add_message(
          field    = component-name
          severity = severity_error
          text     = |Excel column { found } is already mapped to another field.|
          messages = messages ).
      ELSE.
        INSERT VALUE ty_map(
          field     = normalized_field
          column    = found
          expected  = component-name
          component = component ) INTO TABLE map.
        INSERT found INTO TABLE taken.
      ENDIF.
    ENDLOOP.

    LOOP AT headings INTO heading.
      DATA(column) = sy-tabix.
      IF NOT line_exists( taken[ table_line = column ] ).
        add_message(
          column   = column
          severity = severity_info
          text     = |Column '{ heading }' is ignored.|
          messages = messages ).
      ENDIF.
    ENDLOOP.

    LOOP AT required INTO DATA(required_field).
      IF NOT line_exists( map[ field = normalize( required_field ) ] ).
        add_message(
          field    = required_field
          severity = severity_error
          text     = `Required column is missing from the file.`
          messages = messages ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD set_field.
    ok = abap_true.

    CASE component-type->type_kind.
      WHEN cl_abap_typedescr=>typekind_date.
        to_date( EXPORTING cell = cell IMPORTING value = DATA(date) ok = ok ).
        IF ok = abap_true.
          field = date.
        ENDIF.

      WHEN cl_abap_typedescr=>typekind_time.
        to_time( EXPORTING cell = cell IMPORTING value = DATA(time) ok = ok ).
        IF ok = abap_true.
          field = time.
        ENDIF.

      WHEN cl_abap_typedescr=>typekind_int
           OR cl_abap_typedescr=>typekind_int1
           OR cl_abap_typedescr=>typekind_int2
           OR cl_abap_typedescr=>typekind_int8
           OR cl_abap_typedescr=>typekind_packed
           OR cl_abap_typedescr=>typekind_decfloat
           OR cl_abap_typedescr=>typekind_decfloat16
           OR cl_abap_typedescr=>typekind_decfloat34
           OR cl_abap_typedescr=>typekind_float.
        to_number( EXPORTING cell = cell IMPORTING value = DATA(number) ok = ok ).
        IF ok = abap_true.
          TRY.
              field = number.
            CATCH cx_root.
              ok = abap_false.
          ENDTRY.
        ENDIF.

      WHEN OTHERS.
        TRY.
            field = cell.
          CATCH cx_root.
            ok = abap_false.
        ENDTRY.
    ENDCASE.
  ENDMETHOD.


  METHOD to_date.
    ok = abap_false.
    DATA(text) = cell.
    CONDENSE text NO-GAPS.

    DATA(candidate) = ``.
    IF strlen( text ) = 8 AND is_digits( text ) = abap_true.
      candidate = text.
    ELSEIF strlen( text ) = 10 AND text+4(1) = `-` AND text+7(1) = `-`.
      candidate = |{ text+0(4) }{ text+5(2) }{ text+8(2) }|.
    ELSEIF strlen( text ) = 10 AND text+2(1) = `.` AND text+5(1) = `.`.
      candidate = |{ text+6(4) }{ text+3(2) }{ text+0(2) }|.
    ELSEIF strlen( text ) = 10 AND text+2(1) = `/` AND text+5(1) = `/`.
      candidate = |{ text+6(4) }{ text+0(2) }{ text+3(2) }|.
    ENDIF.

    IF is_digits( candidate ) = abap_false.
      RETURN.
    ENDIF.
    IF candidate+4(2) < `01` OR candidate+4(2) > `12`
        OR candidate+6(2) < `01` OR candidate+6(2) > `31`.
      RETURN.
    ENDIF.

    value = candidate.
    ok = abap_true.
  ENDMETHOD.


  METHOD to_time.
    ok = abap_false.
    DATA(text) = cell.
    CONDENSE text NO-GAPS.

    IF strlen( text ) = 5 AND text+2(1) = `:`.
      text = |{ text+0(2) }{ text+3(2) }00|.
    ELSEIF strlen( text ) = 8 AND text+2(1) = `:` AND text+5(1) = `:`.
      text = |{ text+0(2) }{ text+3(2) }{ text+6(2) }|.
    ELSEIF strlen( text ) = 4 AND is_digits( text ) = abap_true.
      text &&= `00`.
    ENDIF.

    IF strlen( text ) = 6 AND is_digits( text ) = abap_true
        AND text+0(2) < `24` AND text+2(2) < `60` AND text+4(2) < `60`.
      value = text.
      ok = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD to_number.
    ok = abap_false.
    DATA(text) = cell.
    CONDENSE text NO-GAPS.
    IF text IS INITIAL.
      RETURN.
    ENDIF.

    DATA has_dot TYPE abap_bool.
    DATA has_comma TYPE abap_bool.
    IF text CS `.`.
      has_dot = abap_true.
    ENDIF.
    IF text CS `,`.
      has_comma = abap_true.
    ENDIF.

    IF has_dot = abap_true AND has_comma = abap_true.
      IF find( val = text sub = `,` ) > find( val = text sub = `.` ).
        REPLACE ALL OCCURRENCES OF `.` IN text WITH ``.
        REPLACE ALL OCCURRENCES OF `,` IN text WITH `.`.
      ELSE.
        REPLACE ALL OCCURRENCES OF `,` IN text WITH ``.
      ENDIF.
    ELSEIF has_comma = abap_true.
      REPLACE ALL OCCURRENCES OF `,` IN text WITH `.`.
    ENDIF.

    TRY.
        value = CONV decfloat16( text ).
        ok = abap_true.
      CATCH cx_root.
        RETURN.
    ENDTRY.
  ENDMETHOD.


  METHOD is_digits.
    result = abap_true.
    IF text IS INITIAL.
      result = abap_false.
      RETURN.
    ENDIF.
    DO strlen( text ) TIMES.
      IF NOT substring( val = text off = sy-index - 1 len = 1 ) CO `0123456789`.
        result = abap_false.
        RETURN.
      ENDIF.
    ENDDO.
  ENDMETHOD.


  METHOD cell_at.
    IF column >= 1 AND column <= lines( cells ).
      result = cells[ column ].
    ENDIF.
  ENDMETHOD.


  METHOD empty_row.
    result = abap_true.
    LOOP AT cells INTO DATA(cell).
      IF cell IS NOT INITIAL.
        result = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_message.
    APPEND VALUE ty_message(
      row      = row
      column   = column
      field    = field
      severity = severity
      text     = text ) TO messages.
  ENDMETHOD.


  METHOD string_table_of.
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
ENDCLASS.
