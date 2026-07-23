// Unit tests for string utility helpers

///|
test "substr basic" {
  assert_eq(@utils.substr("hello", start=1, end=3), "el")
  assert_eq(@utils.substr("hello", start=0), "hello")
  assert_eq(@utils.substr("hello", end=2), "he")
}

///|
test "substr out of bounds" {
  assert_eq(@utils.substr("hi", start=5), "")
  assert_eq(@utils.substr("hi", start=-1, end=1), "")
  assert_eq(@utils.substr("hi", start=0, end=10), "")
}

///|
test "code_unit in bounds" {
  assert_eq(@utils.code_unit("abc", 0), Some(97))
  assert_eq(@utils.code_unit("abc", 2), Some(99))
}

///|
test "code_unit out of bounds" {
  assert_eq(@utils.code_unit("abc", -1), None)
  assert_eq(@utils.code_unit("abc", 3), None)
  assert_eq(@utils.code_unit("", 0), None)
}

///|
test "int_to_char" {
  assert_eq(@utils.int_to_char(65), 'A')
  assert_eq(@utils.int_to_char(10), '\n')
}
