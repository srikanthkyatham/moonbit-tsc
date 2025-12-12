// Debug test to understand type compatibility checking

test "Simple number vs string array spread" {
  let source =
    #|function foo<T>(...s: T[]) { return s[0]; }
    #|let nums: number[] = [1, 2];
    #|let strs: string[] = ["a", "b"];
    #|foo(...nums, ...strs);
  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("DEBUG: No errors detected")
    }
    Err(diagnostics) => {
      println("DEBUG: Got \{diagnostics.length()} diagnostics:")
      diagnostics.iter().each(fn(d) {
        println("  - TS\{d.code}: \{d.message}")
      })
    }
  }
}

test "Explicit type arguments" {
  let source =
    #|function foo<T>(...s: T[]) { return s[0]; }
    #|foo<number>(1, 2);
  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("DEBUG: Explicit type args - no errors")
    }
    Err(diagnostics) => {
      println("DEBUG: Explicit type args - \{diagnostics.length()} diagnostics:")
      diagnostics.iter().each(fn(d) {
        println("  - TS\{d.code}: \{d.message}")
      })
    }
  }
}
