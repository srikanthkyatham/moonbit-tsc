// Enum type registry (T19 enum assignability support).
//
// The checker's core assignability relation (`is_assignable`) is a pure
// function without access to the TypeChecker, but enum assignability is
// nominal and value-based: `enum E { A }` accepts `E.A` and `number`, but
// not another enum's members or numeric literals that match no member.
// To keep the relation pure, enum declarations are registered here (per
// checked file) and the relation consults the registry by type name.
//
// The registry is cleared at the start of every `check_source_file_*` run,
// so entries never leak across files within one process.

///|
/// What is known about a declared enum type
priv struct EnumRegistryEntry {
  numeric_values : Array[Double] // values of numeric members (auto or literal)
  has_string_member : Bool // has at least one string-initialized member
  has_unknown_value : Bool // has a member whose value cannot be computed
}

///|
/// Global per-file registry of enum declarations, keyed by enum name
let enum_type_registry : Map[String, EnumRegistryEntry] = Map([])

///|
/// Clear the registry (called at the start of each file check)
fn clear_enum_registry() -> Unit {
  enum_type_registry.clear()
}

///|
/// Numeric value of an enum member initializer, when statically known
fn enum_initializer_numeric_value(init : Node) -> Double? {
  match init {
    NumericLiteral(lit) => {
      let v = @string.parse_double(lit.value) catch { _ => return None }
      Some(v)
    }
    UnaryExpression(un) =>
      if un.operator == UnaryOperator::Minus {
        match un.operand {
          NumericLiteral(lit) => {
            let v = @string.parse_double(lit.value) catch { _ => return None }
            Some(-v)
          }
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
/// Register an enum declaration's member values. Merges with an existing
/// entry of the same name (declaration merging)
fn register_enum_declaration(enum_decl : EnumDeclaration) -> Unit {
  let existing = enum_type_registry.get(enum_decl.name)
  let numeric_values : Array[Double] = match existing {
    Some(e) => e.numeric_values
    None => []
  }
  let mut has_string = match existing {
    Some(e) => e.has_string_member
    None => false
  }
  let mut has_unknown = match existing {
    Some(e) => e.has_unknown_value
    None => false
  }
  let mut next_auto : Double? = Some(0)
  for mem in enum_decl.members {
    match mem.initializer {
      None =>
        match next_auto {
          Some(v) => {
            numeric_values.push(v)
            next_auto = Some(v + 1)
          }
          None => has_unknown = true
        }
      Some(init) =>
        match enum_initializer_numeric_value(init) {
          Some(v) => {
            numeric_values.push(v)
            next_auto = Some(v + 1)
          }
          None => {
            match init {
              StringLiteral(_) => has_string = true
              _ => has_unknown = true
            }
            next_auto = None
          }
        }
    }
  }
  enum_type_registry.set(enum_decl.name, {
    numeric_values,
    has_string_member: has_string,
    has_unknown_value: has_unknown,
  })
}

///|
/// Register every enum declared in a list of statements (including inside
/// namespace bodies)
fn register_enums_in_statements(statements : Array[Node]) -> Unit {
  for stmt in statements {
    register_enums_in_node(stmt)
  }
}

///|
fn register_enums_in_node(node : Node) -> Unit {
  match node {
    EnumDeclaration(ed) => register_enum_declaration(ed)
    ModuleDeclaration(md) =>
      match md.body {
        Some(body) => register_enums_in_node(body)
        None => ()
      }
    BlockStatement(block) => register_enums_in_statements(block.statements)
    _ => ()
  }
}

///|
/// Registry entry for a TypeReference, when it names a declared enum
fn enum_entry_of_ref(r : TypeReferenceType) -> EnumRegistryEntry? {
  if r.type_arguments.length() == 0 {
    enum_type_registry.get(r.name)
  } else {
    None
  }
}

///|
/// Check if a type name refers to a declared enum
fn is_enum_type_name(name : String) -> Bool {
  enum_type_registry.contains(name)
}

///|
/// A numeric enum accepts plain `number` sources
fn enum_accepts_number_type(r : TypeReferenceType) -> Bool {
  match enum_entry_of_ref(r) {
    Some(entry) => !entry.has_string_member
    None => false
  }
}

///|
/// A numeric literal is assignable to an enum only when it matches one of
/// the member values (or the enum has members whose values are unknown)
fn enum_accepts_number_literal(r : TypeReferenceType, v : Double) -> Bool {
  match enum_entry_of_ref(r) {
    Some(entry) =>
      entry.has_unknown_value ||
      !entry.has_string_member && entry.numeric_values.contains(v)
    None => false
  }
}

///|
/// An enum consisting solely of string members is assignable to `string`
fn enum_is_pure_string(r : TypeReferenceType) -> Bool {
  match enum_entry_of_ref(r) {
    Some(entry) => entry.has_string_member && entry.numeric_values.is_empty()
    None => false
  }
}

///|
/// Check if an enum symbol declares a member with the given name
fn enum_symbol_has_member(sym : Symbol, member_name : String) -> Bool {
  match sym.value_declaration {
    Some(EnumDeclaration(ed)) => {
      for m in ed.members {
        if m.name == member_name {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
/// When assigning to a nominal enum type, keep the numeric literal value
/// of the source expression instead of the widened `number`: a numeric
/// literal is only assignable to an enum when it matches a member value
fn refine_numeric_literal_source(
  checker : TypeChecker,
  source_expr : Node,
  source_type : Type,
  target_type : Type,
) -> (Type, TypeChecker) {
  match (source_type, target_type) {
    (Number(_), TypeReference(target_ref)) =>
      if enum_entry_of_ref(target_ref) is Some(_) {
        match enum_initializer_numeric_value(source_expr) {
          Some(v) => number_literal_type(checker, v)
          None => (source_type, checker)
        }
      } else {
        (source_type, checker)
      }
    _ => (source_type, checker)
  }
}

///|
/// For a qualified type name like `Choice.Yes` that names an enum member,
/// return the enum name (`Choice`) when the member exists. Enum member
/// types are approximated by their enum type.
fn qualified_enum_member_enum_name(
  checker : TypeChecker,
  qualified_name : String,
) -> String? {
  let parts = qualified_name.split(".").collect()
  if parts.length() != 2 {
    return None
  }
  let enum_name = parts[0].to_owned()
  let member_name = parts[1].to_owned()
  match lookup_symbol(checker, enum_name) {
    Some(sym) =>
      if sym.kind == SymbolKind::Enum &&
        enum_symbol_has_member(sym, member_name) {
        Some(enum_name)
      } else {
        None
      }
    None => None
  }
}

///|
/// Per-file strict flags consulted by the pure assignability relation
/// (set at the start of each `check_source_file_*` run, like the enum
/// registry above)
priv struct GlobalStrictFlags {
  mut strict_null_checks : Bool
}

///|
let global_strict_flags : GlobalStrictFlags = { strict_null_checks: false }

///|
fn set_strict_null_assignability(enabled : Bool) -> Unit {
  global_strict_flags.strict_null_checks = enabled
}

///|
/// Under strictNullChecks, `undefined`/`null` are not assignable to
/// non-nullable types
fn nullish_assignable_to_non_nullable() -> Bool {
  !global_strict_flags.strict_null_checks
}

///|
/// Check if a type is exactly `undefined` (optional parameters and
/// properties accept it implicitly)
fn type_is_nullish_undefined(t : Type) -> Bool {
  match t {
    Undefined(_) => true
    _ => false
  }
}
