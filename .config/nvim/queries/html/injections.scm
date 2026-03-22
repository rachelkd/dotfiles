; extends

((script_element
  (start_tag) @_type_babel
  (raw_text) @injection.content)
 (#lua-match? @_type_babel "text/babel")
 (#set! injection.language "jsx"))
