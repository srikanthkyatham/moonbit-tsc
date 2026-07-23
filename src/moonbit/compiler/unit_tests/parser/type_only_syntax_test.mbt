// Unit tests for type-only import/export parsing:
// - `import type` vs a default import binding named 'type'
// - `export type * [as ns] from` star re-exports
// - tsc's `{ type ... as ... }` specifier disambiguation

///|
fn parse_first_statement(source : String) -> @compiler.Node? {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => if sf.statements.length() > 0 { Some(sf.statements[0]) } else { None }
    Err(_) => None
  }
}

///|
test "import type { A } parses as type-only import" {
  match parse_first_statement("import type { A } from './a';") {
    Some(@compiler.ImportDeclaration(id)) => assert_true(id.is_type_only)
    _ => @test.fail("expected an import declaration")
  }
}

///|
test "import type from './a' binds default import named 'type'" {
  match parse_first_statement("import type from './a';") {
    Some(@compiler.ImportDeclaration(id)) => {
      assert_false(id.is_type_only)
      match id.import_clause {
        Some(clause) => assert_eq(clause.name, Some("type"))
        None => @test.fail("expected an import clause")
      }
    }
    _ => @test.fail("expected an import declaration")
  }
}

///|
test "import type from from './a' is a type-only default import named 'from'" {
  match parse_first_statement("import type from from './a';") {
    Some(@compiler.ImportDeclaration(id)) => {
      assert_true(id.is_type_only)
      match id.import_clause {
        Some(clause) => assert_eq(clause.name, Some("from"))
        None => @test.fail("expected an import clause")
      }
    }
    _ => @test.fail("expected an import declaration")
  }
}

///|
test "import type A = require(...) keeps the type-only flag" {
  match parse_first_statement("import type A = require('./a');") {
    Some(@compiler.ImportEqualsDeclaration(ied)) => {
      assert_true(ied.is_type_only)
      assert_eq(ied.name, "A")
    }
    _ => @test.fail("expected an import equals declaration")
  }
}

///|
test "export type * from './a' parses as type-only star re-export" {
  match parse_first_statement("export type * from './a';") {
    Some(@compiler.ExportDeclaration(ed)) => {
      assert_true(ed.is_type_only)
      assert_true(ed.export_clause is None)
      assert_eq(ed.module_specifier, Some("./a"))
    }
    _ => @test.fail("expected an export declaration")
  }
}

///|
test "export type * as ns from './a' parses as type-only namespace re-export" {
  match parse_first_statement("export type * as ns from './a';") {
    Some(@compiler.ExportDeclaration(ed)) => {
      assert_true(ed.is_type_only)
      match ed.export_clause {
        Some(@compiler.NamedExports::NamespaceExport(name, _)) =>
          assert_eq(name, "ns")
        _ => @test.fail("expected a namespace export clause")
      }
    }
    _ => @test.fail("expected an export declaration")
  }
}

///|
fn parse_export_specifier_list(
  source : String,
) -> Array[@compiler.ExportSpecifier] {
  match parse_first_statement(source) {
    Some(@compiler.ExportDeclaration(ed)) =>
      match ed.export_clause {
        Some(@compiler.NamedExports::NamedExports(specifiers, _)) => specifiers
        _ => []
      }
    _ => []
  }
}

///|
test "export { type } is a value export named 'type'" {
  let specs = parse_export_specifier_list("export { type };")
  assert_eq(specs.length(), 1)
  assert_eq(specs[0].name, "type")
  assert_false(specs[0].is_type_only)
}

///|
test "export { type as } is a type-only export named 'as'" {
  let specs = parse_export_specifier_list("export { type as };")
  assert_eq(specs.length(), 1)
  assert_eq(specs[0].name, "as")
  assert_true(specs[0].is_type_only)
  assert_true(specs[0].property_name is None)
}

///|
test "export { type as as } is a value export of 'type' renamed to 'as'" {
  let specs = parse_export_specifier_list("export { type as as };")
  assert_eq(specs.length(), 1)
  assert_eq(specs[0].property_name, Some("type"))
  assert_eq(specs[0].name, "as")
  assert_false(specs[0].is_type_only)
}

///|
test "export { type as as bar } is a type-only export of 'as' renamed to 'bar'" {
  let specs = parse_export_specifier_list("export { type as as bar };")
  assert_eq(specs.length(), 1)
  assert_eq(specs[0].property_name, Some("as"))
  assert_eq(specs[0].name, "bar")
  assert_true(specs[0].is_type_only)
}

///|
test "export { type type as foo } is a type-only export of 'type' renamed to 'foo'" {
  let specs = parse_export_specifier_list("export { type type as foo };")
  assert_eq(specs.length(), 1)
  assert_eq(specs[0].property_name, Some("type"))
  assert_eq(specs[0].name, "foo")
  assert_true(specs[0].is_type_only)
}

///|
test "bare 'type;' statement parses as an expression statement" {
  match parse_first_statement("type;") {
    Some(@compiler.ExpressionStatement(_)) => ()
    _ => @test.fail("expected an expression statement")
  }
}

///|
test "type alias declarations still parse" {
  match parse_first_statement("type X = string;") {
    Some(@compiler.TypeAliasDeclaration(tad)) => assert_eq(tad.name, "X")
    _ => @test.fail("expected a type alias declaration")
  }
}
