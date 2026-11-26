CLASS zcl_skybox_console DEFINITION PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_skybox_console IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    zcl_excel_order_demo=>run( out ).
  ENDMETHOD.
ENDCLASS.
