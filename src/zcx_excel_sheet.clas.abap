CLASS zcx_excel_sheet DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        message  TYPE string
        previous TYPE REF TO cx_root OPTIONAL
        row      TYPE i OPTIONAL
        column   TYPE i OPTIONAL
        field    TYPE string OPTIONAL.

    METHODS get_text REDEFINITION.
    METHODS get_longtext REDEFINITION.

    DATA message TYPE string READ-ONLY.
    DATA row     TYPE i READ-ONLY.
    DATA column  TYPE i READ-ONLY.
    DATA field   TYPE string READ-ONLY.
ENDCLASS.


CLASS zcx_excel_sheet IMPLEMENTATION.
  METHOD constructor.
    super->constructor( previous = previous ).
    me->message = message.
    me->row     = row.
    me->column  = column.
    me->field   = field.
  ENDMETHOD.


  METHOD get_text.
    result = message.
  ENDMETHOD.


  METHOD get_longtext.
    DATA(location) = ``.

    IF field IS NOT INITIAL.
      location = |field '{ field }'|.
      IF row > 0.
        location &&= |, row { row }|.
      ENDIF.
    ELSEIF row > 0.
      location = |row { row }|.
    ENDIF.

    IF column > 0.
      IF location IS NOT INITIAL.
        location &&= `, `.
      ENDIF.
      location &&= |column { column }|.
    ENDIF.

    IF location IS NOT INITIAL.
      result = |{ message } ({ location })|.
    ELSE.
      result = message.
    ENDIF.

    IF previous IS BOUND.
      result &&= | Previous exception: { previous->get_text( ) }|.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
