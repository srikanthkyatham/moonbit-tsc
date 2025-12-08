// Debug tests for investigating issues

///|
/// Helper to parse, bind, and check source code
fn debug_check_source(source : String) -> Result[@compiler.TypedFile, Array[@compiler.Diagnostic]] {
  let tokens = @compiler.scan_all_v2(source, "debug.ts")
  match @compiler.parse_source_file(tokens, "debug.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) => @compiler.check_source_file(bound)
        Err(diags) => Err(diags)
      }
    Err(_) => Err([])
  }
}

///|
/// Helper to get bound source file
fn debug_bind_source(source : String) -> Result[@compiler.BoundSourceFile, Array[@compiler.Diagnostic]] {
  let tokens = @compiler.scan_all_v2(source, "debug.ts")
  match @compiler.parse_source_file(tokens, "debug.ts") {
    Ok(source_file) => @compiler.bind_source_file(source_file)
    Err(_) => Err([])
  }
}

test "debug: direct interface SymbolConstructor works" {
  let source = "interface SymbolConstructor { readonly test1: symbol }\nconst t1 = Symbol.test1"
  match debug_check_source(source) {
    Ok(_) => assert_true(true) // Should succeed
    Err(diags) => {
      println("Unexpected error: \{diags}")
      assert_true(false)
    }
  }
}

test "debug: global augmentation SymbolConstructor" {
  let source = "declare global { interface SymbolConstructor { readonly test2: symbol } }\nconst t2 = Symbol.test2"
  match debug_check_source(source) {
    Ok(_) => assert_true(true) // Should succeed
    Err(diags) => {
      println("Got errors: \{diags}")
      // This is currently failing - we want to debug why
      assert_true(false)
    }
  }
}

test "debug: check if SymbolConstructor is in global scope after global augmentation" {
  let source = "declare global { interface SymbolConstructor { readonly test2: symbol } }"
  match debug_bind_source(source) {
    Ok(bound) => {
      // Check if SymbolConstructor is in the global scope
      match bound.global_scope.symbols.get("SymbolConstructor") {
        Some(sym) => {
          println("Found SymbolConstructor in global scope, kind: \{sym.kind}")
          println("Has \{sym.declarations.length()} declaration(s)")
          assert_true(true)
        }
        None => {
          println("SymbolConstructor NOT in global scope")
          println("Global scope has \{bound.global_scope.symbols.size()} symbols")
          assert_true(false)
        }
      }
    }
    Err(diags) => {
      println("Bind error: \{diags}")
      assert_true(false)
    }
  }
}

test "debug: check global_augmentations array" {
  let source = "declare global { interface SymbolConstructor { readonly test2: symbol } }"
  match debug_bind_source(source) {
    Ok(bound) => {
      println("Found \{bound.global_augmentations.length()} global augmentation(s)")
      if bound.global_augmentations.length() > 0 {
        let aug = bound.global_augmentations[0]
        println("Augmentation has \{aug.declarations.size()} declaration(s)")
        match aug.declarations.get("SymbolConstructor") {
          Some(sym) => {
            println("SymbolConstructor in augmentation, kind: \{sym.kind}")
            assert_true(true)
          }
          None => {
            println("SymbolConstructor NOT in augmentation declarations")
            assert_true(false)
          }
        }
      } else {
        assert_true(false)
      }
    }
    Err(diags) => {
      println("Bind error: \{diags}")
      assert_true(false)
    }
  }
}
