INTERFACE zif_excel_xlsx PUBLIC.

  TYPES:
    BEGIN OF ty_row,
      cells TYPE string_table,
    END OF ty_row,
    ty_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY,
    ty_names TYPE STANDARD TABLE OF string WITH EMPTY KEY.

  METHODS read_rows
    IMPORTING
      content     TYPE xstring
      sheet       TYPE i
      sheet_name  TYPE string
      skip_header TYPE abap_bool
    RETURNING
      VALUE(rows) TYPE ty_rows
    RAISING
      zcx_excel_sheet.

  METHODS read_into
    IMPORTING
      content     TYPE xstring
      sheet       TYPE i
      sheet_name  TYPE string
      skip_header TYPE abap_bool
    CHANGING
      target      TYPE ANY TABLE
    RAISING
      zcx_excel_sheet.

  METHODS write
    IMPORTING
      source     TYPE ANY TABLE
      sheet_name TYPE string
    RETURNING
      VALUE(content) TYPE xstring
    RAISING
      zcx_excel_sheet.

  METHODS sheet_names
    IMPORTING
      content TYPE xstring
    RETURNING
      VALUE(names) TYPE ty_names
    RAISING
      zcx_excel_sheet.
ENDINTERFACE.
