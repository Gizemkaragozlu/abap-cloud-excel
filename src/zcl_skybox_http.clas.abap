CLASS zcl_skybox_http DEFINITION PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_http_service_extension.
ENDCLASS.

CLASS zcl_skybox_http IMPLEMENTATION.
  METHOD if_http_service_extension~handle_request.
    response->set_status( 200 ).
    response->set_text( 'Hello from skybox' ).
  ENDMETHOD.
ENDCLASS.
