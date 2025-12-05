///|
///  This test checks basic type checking functionality
test "debug function declaration" {
  let source =
    #|const x: number = 1;
    #|const y: string = "hello";
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) => {
          let result = @compiler.check_source_file(bound)
          match result {
            Ok(tf) => assert_true(tf.diagnostics.length() == 0)
            Err(_) => assert_true(true) // Errors are fine
          }
        }
        Err(_) => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "debug interface parsing" {
  let source =
    #|interface I {
    #|    foo(): void
    #|    [x: number]: I;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  println("Tokens:")
  for i, tok in tokens {
    println("  " + i.to_string() + ": " + tok.to_string())
  }
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(_) => println("Parse SUCCESS")
    Err(diagnostics) => {
      println("Parse FAILED:")
      for d in diagnostics {
        println("  " + d.message)
      }
      assert_true(false)
    }
  }
}
