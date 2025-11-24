// Binder for TypeScript
// Responsible for:
// - Building symbol tables
// - Name resolution
// - Scope management
// - Detecting duplicate declarations

///|
/// Binder state
pub struct Binder {
  scopes : Array[Scope] // Stack of scopes
  current_scope_id : Int
  next_symbol_id : Int
  next_scope_id : Int
  next_flow_id : Int
  file_path : String
  diagnostics : Array[Diagnostic]
  current_flow : FlowNode?
} derive(Show)

///|
/// Binder result
pub type BindResult = Result[BoundSourceFile, Array[Diagnostic]]

///|
/// Bound source file (AST with symbol information)
pub struct BoundSourceFile {
  file_path : String
  global_scope : Scope
  statements : Array[Node]
  symbol_count : Int
  diagnostics : Array[Diagnostic]
} derive(Show)

///|
/// Create a new binder
fn Binder::new(file_path : String) -> Binder {
  let global_scope = Scope::new(None, 0)
  {
    scopes: [global_scope],
    current_scope_id: 0,
    next_symbol_id: 0,
    next_scope_id: 1,
    next_flow_id: 0,
    file_path,
    diagnostics: [],
    current_flow: Some(FlowNode::Start(FlowStart::{ id: 0 })),
  }
}

///|
/// Main entry point: bind a source file
pub fn bind_source_file(
  source_file : SourceFile,
) -> BindResult {
  let binder = Binder::new(source_file.file_path)
  let binder = bind_statements(binder, source_file.statements)

  // Get global scope
  let global_scope = match binder.scopes[0] {
    scope => scope
  }

  if binder.diagnostics.length() > 0 {
    Err(binder.diagnostics)
  } else {
    Ok(BoundSourceFile::{
      file_path: source_file.file_path,
      global_scope,
      statements: source_file.statements,
      symbol_count: binder.next_symbol_id,
      diagnostics: binder.diagnostics,
    })
  }
}

///|
/// Bind a list of statements
fn bind_statements(binder : Binder, statements : Array[Node]) -> Binder {
  bind_statements_aux(binder, statements, 0)
}

///|
/// Tail-recursive helper for binding statements
fn bind_statements_aux(
  binder : Binder,
  statements : Array[Node],
  index : Int,
) -> Binder {
  if index >= statements.length() {
    binder
  } else {
    let stmt = statements[index]
    let binder = bind_statement(binder, stmt)
    bind_statements_aux(binder, statements, index + 1)
  }
}

///|
/// Bind a single statement
fn bind_statement(binder : Binder, node : Node) -> Binder {
  match node {
    // Variable declarations
    VariableStatement(var_stmt) => {
      bind_variable_declarations(binder, var_stmt.declarations, var_stmt.is_const)
    }

    // Function declaration
    FunctionDeclaration(func) => {
      bind_function_declaration(binder, func)
    }

    // Class declaration
    ClassDeclaration(class_decl) => {
      bind_class_declaration(binder, class_decl)
    }

    // Interface declaration
    InterfaceDeclaration(interface) => {
      bind_interface_declaration(binder, interface)
    }

    // Enum declaration
    EnumDeclaration(enum_decl) => {
      bind_enum_declaration(binder, enum_decl)
    }

    // Type alias
    TypeAliasDeclaration(type_alias) => {
      bind_type_alias_declaration(binder, type_alias)
    }

    // Import declaration
    ImportDeclaration(import_decl) => {
      bind_import_declaration(binder, import_decl)
    }

    // Export declaration
    ExportDeclaration(export_decl) => {
      bind_export_declaration(binder, export_decl)
    }

    // Export assignment
    ExportAssignment(export_assign) => {
      bind_export_assignment(binder, export_assign)
    }

    // Block statement
    BlockStatement(block) => {
      let binder = push_scope(binder)
      let binder = bind_statements(binder, block.statements)
      pop_scope(binder)
    }

    // If statement
    IfStatement(if_stmt) => {
      let binder = bind_expression(binder, if_stmt.condition)
      let binder = bind_statement(binder, if_stmt.then_statement)
      match if_stmt.else_statement {
        Some(else_stmt) => bind_statement(binder, else_stmt)
        None => binder
      }
    }

    // For statement
    ForStatement(for_stmt) => {
      let binder = push_scope(binder)
      let binder = match for_stmt.initializer {
        Some(init) => bind_statement(binder, init)
        None => binder
      }
      let binder = match for_stmt.condition {
        Some(cond) => bind_expression(binder, cond)
        None => binder
      }
      let binder = match for_stmt.incrementor {
        Some(inc) => bind_expression(binder, inc)
        None => binder
      }
      let binder = bind_statement(binder, for_stmt.statement)
      pop_scope(binder)
    }

    // While statement
    WhileStatement(while_stmt) => {
      let binder = bind_expression(binder, while_stmt.condition)
      bind_statement(binder, while_stmt.statement)
    }

    // Do-while statement
    DoWhileStatement(do_stmt) => {
      let binder = bind_statement(binder, do_stmt.statement)
      bind_expression(binder, do_stmt.condition)
    }

    // Switch statement
    SwitchStatement(switch_stmt) => {
      let binder = bind_expression(binder, switch_stmt.expression)
      bind_case_clauses(binder, switch_stmt.cases)
    }

    // Return statement
    ReturnStatement(ret_stmt) => {
      match ret_stmt.expression {
        Some(expr) => bind_expression(binder, expr)
        None => binder
      }
    }

    // Throw statement
    ThrowStatement(throw_stmt) => {
      bind_expression(binder, throw_stmt.expression)
    }

    // Try statement
    TryStatement(try_stmt) => {
      let binder = bind_statement(binder, try_stmt.try_block)
      let binder = match try_stmt.catch_clause {
        Some(catch_info) => {
          let binder = push_scope(binder)
          // Bind catch variable if present
          let binder = match catch_info.variable_declaration {
            Some(_) => binder // TODO: bind catch variable
            None => binder
          }
          let binder = bind_statement(binder, catch_info.block)
          pop_scope(binder)
        }
        None => binder
      }
      match try_stmt.finally_block {
        Some(finally_block) => bind_statement(binder, finally_block)
        None => binder
      }
    }

    // Expression statement
    ExpressionStatement(expr_stmt) => {
      bind_expression(binder, expr_stmt.expression)
    }

    // Other statements - no binding needed
    _ => binder
  }
}

///|
/// Bind variable declarations
fn bind_variable_declarations(
  binder : Binder,
  declarations : Array[VariableDeclaration],
  is_const : Bool,
) -> Binder {
  bind_variable_declarations_aux(binder, declarations, is_const, 0)
}

///|
fn bind_variable_declarations_aux(
  binder : Binder,
  declarations : Array[VariableDeclaration],
  is_const : Bool,
  index : Int,
) -> Binder {
  if index >= declarations.length() {
    binder
  } else {
    let decl = declarations[index]
    let binder = bind_variable_declaration(binder, decl, is_const)
    bind_variable_declarations_aux(binder, declarations, is_const, index + 1)
  }
}

///|
fn bind_variable_declaration(
  binder : Binder,
  decl : VariableDeclaration,
  is_const : Bool,
) -> Binder {
  // Extract name from identifier node
  let name = match decl.name {
    Identifier(id) => id.name
    _ => return binder // Binding patterns not yet supported
  }

  let mut symbol = Symbol::new(name, SymbolKind::Variable, binder.next_symbol_id)

  // Set const flag on symbol
  if is_const {
    symbol = { ..symbol, flags: { ..symbol.flags, is_const: true } }
  }

  let binder = declare_symbol(binder, name, symbol)

  // Bind initializer expression if present
  match decl.initializer {
    Some(init) => bind_expression(binder, init)
    None => binder
  }
}

///|
/// Bind function declaration
fn bind_function_declaration(
  binder : Binder,
  func : FunctionDeclaration,
) -> Binder {
  // Extract name from identifier node
  let name = match func.name {
    Some(Identifier(id)) => id.name
    _ => return binder // Anonymous function
  }

  let symbol = Symbol::new(name, SymbolKind::Function, binder.next_symbol_id)

  let binder = declare_symbol(binder, name, symbol)

  // Create new scope for function body
  let binder = push_scope(binder)

  // Bind parameters
  let binder = bind_parameters(binder, func.parameters)

  // Bind body
  let binder = match func.body {
    Some(body) => bind_statement(binder, body)
    None => binder
  }

  pop_scope(binder)
}

///|
/// Bind class declaration
fn bind_class_declaration(binder : Binder, class_decl : ClassDeclaration) -> Binder {
  let name = match class_decl.name {
    Some(Node::Identifier(id)) => id.name
    _ => return binder // Anonymous class
  }

  let symbol = Symbol::new(name, SymbolKind::Class, binder.next_symbol_id)
  let symbol = symbol.add_declaration(Node::ClassDeclaration(class_decl))

  let binder = declare_symbol(binder, name, symbol)

  // Create new scope for class body
  let binder = push_scope(binder)

  // Bind class members
  let binder = bind_class_members(binder, class_decl.members)

  pop_scope(binder)
}

///|
/// Bind class members
fn bind_class_members(binder : Binder, members : Array[Node]) -> Binder {
  bind_class_members_aux(binder, members, 0)
}

///|
fn bind_class_members_aux(
  binder : Binder,
  members : Array[Node],
  index : Int,
) -> Binder {
  if index >= members.length() {
    binder
  } else {
    let mem = members[index]
    let binder = match mem {
      PropertyDeclaration(prop) => {
        let symbol = Symbol::new(prop.name, SymbolKind::Property, binder.next_symbol_id)
        declare_symbol(binder, prop.name, symbol)
      }
      MethodDeclaration(meth) => {
        let symbol = Symbol::new(meth.name, SymbolKind::Method, binder.next_symbol_id)
        let binder = declare_symbol(binder, meth.name, symbol)
        // Bind method body
        match meth.body {
          Some(body) => {
            let binder = push_scope(binder)
            let binder = bind_parameters(binder, meth.parameters)
            let binder = bind_statement(binder, body)
            pop_scope(binder)
          }
          None => binder
        }
      }
      ConstructorDeclaration(ctor) => {
        let symbol = Symbol::new("constructor", SymbolKind::Method, binder.next_symbol_id)
        let binder = declare_symbol(binder, "constructor", symbol)
        // Bind constructor body
        match ctor.body {
          Some(body) => {
            let binder = push_scope(binder)
            let binder = bind_parameters(binder, ctor.parameters)
            let binder = bind_statement(binder, body)
            pop_scope(binder)
          }
          None => binder
        }
      }
      _ => binder
    }
    bind_class_members_aux(binder, members, index + 1)
  }
}

///|
/// Bind interface declaration
fn bind_interface_declaration(
  binder : Binder,
  interface : InterfaceDeclaration,
) -> Binder {
  let symbol = Symbol::new(interface.name, SymbolKind::Interface, binder.next_symbol_id)
  let symbol = symbol.add_declaration(Node::InterfaceDeclaration(interface))
  declare_symbol(binder, interface.name, symbol)
}

///|
/// Bind enum declaration
fn bind_enum_declaration(binder : Binder, enum_decl : EnumDeclaration) -> Binder {
  let symbol = Symbol::new(enum_decl.name, SymbolKind::Enum, binder.next_symbol_id)
  let symbol = symbol.add_declaration(Node::EnumDeclaration(enum_decl))

  let binder = declare_symbol(binder, enum_decl.name, symbol)

  // Bind enum members
  bind_enum_members(binder, enum_decl.members)
}

///|
fn bind_enum_members(binder : Binder, members : Array[EnumMember]) -> Binder {
  bind_enum_members_aux(binder, members, 0)
}

///|
fn bind_enum_members_aux(
  binder : Binder,
  members : Array[EnumMember],
  index : Int,
) -> Binder {
  if index >= members.length() {
    binder
  } else {
    let mem = members[index]
    let symbol = Symbol::new(mem.name, SymbolKind::EnumMember, binder.next_symbol_id)
    let binder = declare_symbol(binder, mem.name, symbol)

    // Bind initializer if present
    let binder = match mem.initializer {
      Some(init) => bind_expression(binder, init)
      None => binder
    }

    bind_enum_members_aux(binder, members, index + 1)
  }
}

///|
/// Bind type alias declaration
fn bind_type_alias_declaration(
  binder : Binder,
  type_alias : TypeAliasDeclaration,
) -> Binder {
  let symbol = Symbol::new(type_alias.name, SymbolKind::Type, binder.next_symbol_id)
  let symbol = symbol.add_declaration(Node::TypeAliasDeclaration(type_alias))
  declare_symbol(binder, type_alias.name, symbol)
}

///|
/// Bind import declaration
fn bind_import_declaration(
  binder : Binder,
  import_decl : ImportDeclaration,
) -> Binder {
  match import_decl.import_clause {
    Some(clause) => {
      // Bind default import
      let binder = match clause.name {
        Some(name) => {
          let symbol = Symbol::new(name, SymbolKind::Alias, binder.next_symbol_id)
          declare_symbol(binder, name, symbol)
        }
        None => binder
      }

      // Bind named imports
      match clause.named_bindings {
        Some(NamedImports::NamespaceImport(name, _)) => {
          let symbol = Symbol::new(name, SymbolKind::Module, binder.next_symbol_id)
          declare_symbol(binder, name, symbol)
        }
        Some(NamedImports::NamedImports(specifiers, _)) => {
          bind_import_specifiers(binder, specifiers)
        }
        None => binder
      }
    }
    None => binder // Side-effect import
  }
}

///|
fn bind_import_specifiers(
  binder : Binder,
  specifiers : Array[ImportSpecifier],
) -> Binder {
  bind_import_specifiers_aux(binder, specifiers, 0)
}

///|
fn bind_import_specifiers_aux(
  binder : Binder,
  specifiers : Array[ImportSpecifier],
  index : Int,
) -> Binder {
  if index >= specifiers.length() {
    binder
  } else {
    let spec = specifiers[index]
    let local_name = spec.name
    let symbol = Symbol::new(local_name, SymbolKind::Alias, binder.next_symbol_id)
    let binder = declare_symbol(binder, local_name, symbol)
    bind_import_specifiers_aux(binder, specifiers, index + 1)
  }
}

///|
/// Bind export declaration
fn bind_export_declaration(
  binder : Binder,
  _export_decl : ExportDeclaration,
) -> Binder {
  // Exports don't create bindings, they reference existing ones
  binder
}

///|
/// Bind export assignment
fn bind_export_assignment(
  binder : Binder,
  export_assign : ExportAssignment,
) -> Binder {
  bind_expression(binder, export_assign.expression)
}

///|
/// Bind case clauses
fn bind_case_clauses(binder : Binder, cases : Array[CaseClause]) -> Binder {
  bind_case_clauses_aux(binder, cases, 0)
}

///|
fn bind_case_clauses_aux(
  binder : Binder,
  cases : Array[CaseClause],
  index : Int,
) -> Binder {
  if index >= cases.length() {
    binder
  } else {
    let case_clause = cases[index]

    // Bind case expression if present
    let binder = match case_clause.expression {
      Some(expr) => bind_expression(binder, expr)
      None => binder
    }

    // Bind case statements
    let binder = bind_statements(binder, case_clause.statements)

    bind_case_clauses_aux(binder, cases, index + 1)
  }
}

///|
/// Bind parameters
fn bind_parameters(binder : Binder, parameters : Array[Node]) -> Binder {
  bind_parameters_aux(binder, parameters, 0)
}

///|
fn bind_parameters_aux(
  binder : Binder,
  parameters : Array[Node],
  index : Int,
) -> Binder {
  if index >= parameters.length() {
    binder
  } else {
    let param = parameters[index]
    let binder = match param {
      Parameter(p) => {
        // Extract name from identifier node
        let param_name = match p.name {
          Identifier(id) => id.name
          _ => return binder // Binding pattern not supported
        }
        let symbol = Symbol::new(param_name, SymbolKind::Parameter, binder.next_symbol_id)
        declare_symbol(binder, param_name, symbol)
      }
      _ => binder
    }
    bind_parameters_aux(binder, parameters, index + 1)
  }
}

///|
/// Bind an expression (simplified - just walks the tree)
fn bind_expression(binder : Binder, node : Node) -> Binder {
  match node {
    // Literal expressions - no binding needed
    NumericLiteral(_) | StringLiteral(_) | BooleanLiteral(_) | NullLiteral(_) => binder

    // Identifier - would need to resolve, but that's for the checker
    Identifier(_) => binder

    // Binary expression
    BinaryExpression(bin_expr) => {
      let binder = bind_expression(binder, bin_expr.left)
      bind_expression(binder, bin_expr.right)
    }

    // Unary expression
    UnaryExpression(unary_expr) => {
      bind_expression(binder, unary_expr.operand)
    }

    // Call expression
    CallExpression(call_expr) => {
      let binder = bind_expression(binder, call_expr.expression)
      bind_expressions(binder, call_expr.arguments)
    }

    // Property access
    PropertyAccessExpression(prop_access) => {
      bind_expression(binder, prop_access.expression)
    }

    // Element access
    ElementAccessExpression(elem_access) => {
      let binder = bind_expression(binder, elem_access.expression)
      bind_expression(binder, elem_access.argument_expression)
    }

    // Array literal (elements can be None for holes)
    ArrayLiteralExpression(array_lit) => {
      bind_array_elements(binder, array_lit.elements)
    }

    // Object literal
    ObjectLiteralExpression(obj_lit) => {
      bind_object_properties(binder, obj_lit.properties)
    }

    // Arrow function
    ArrowFunction(arrow) => {
      let binder = push_scope(binder)
      let binder = bind_parameters(binder, arrow.parameters)
      let binder = bind_statement(binder, arrow.body)
      pop_scope(binder)
    }

    // Conditional expression
    ConditionalExpression(cond_expr) => {
      let binder = bind_expression(binder, cond_expr.condition)
      let binder = bind_expression(binder, cond_expr.when_true)
      bind_expression(binder, cond_expr.when_false)
    }

    // Other expressions
    _ => binder
  }
}

///|
/// Bind multiple expressions
fn bind_expressions(binder : Binder, expressions : Array[Node]) -> Binder {
  bind_expressions_aux(binder, expressions, 0)
}

///|
fn bind_expressions_aux(
  binder : Binder,
  expressions : Array[Node],
  index : Int,
) -> Binder {
  if index >= expressions.length() {
    binder
  } else {
    let binder = bind_expression(binder, expressions[index])
    bind_expressions_aux(binder, expressions, index + 1)
  }
}

///|
/// Bind array elements (handling optional elements for holes)
fn bind_array_elements(binder : Binder, elements : Array[Node?]) -> Binder {
  bind_array_elements_aux(binder, elements, 0)
}

///|
fn bind_array_elements_aux(
  binder : Binder,
  elements : Array[Node?],
  index : Int,
) -> Binder {
  if index >= elements.length() {
    binder
  } else {
    let binder = match elements[index] {
      Some(element) => bind_expression(binder, element)
      None => binder // Hole in array
    }
    bind_array_elements_aux(binder, elements, index + 1)
  }
}

///|
/// Bind object properties
fn bind_object_properties(binder : Binder, properties : Array[ObjectProperty]) -> Binder {
  bind_object_properties_aux(binder, properties, 0)
}

///|
fn bind_object_properties_aux(
  binder : Binder,
  properties : Array[ObjectProperty],
  index : Int,
) -> Binder {
  if index >= properties.length() {
    binder
  } else {
    let prop = properties[index]
    let binder = match prop {
      PropertyAssignment(_, value, _) => bind_expression(binder, value)
      SpreadAssignment(expr, _) => bind_expression(binder, expr)
      _ => binder
    }
    bind_object_properties_aux(binder, properties, index + 1)
  }
}

// ============================================================================
// Scope management
// ============================================================================

///|
/// Push a new scope onto the scope stack
fn push_scope(binder : Binder) -> Binder {
  let new_scope = Scope::new(Some(binder.current_scope_id), binder.next_scope_id)
  let new_scopes = binder.scopes
  new_scopes.push(new_scope)
  {
    ..binder,
    scopes: new_scopes,
    current_scope_id: binder.next_scope_id,
    next_scope_id: binder.next_scope_id + 1,
  }
}

///|
/// Pop the current scope from the scope stack
fn pop_scope(binder : Binder) -> Binder {
  let current_scope = binder.scopes[binder.scopes.length() - 1]
  let parent_id = match current_scope.parent {
    Some(id) => id
    None => 0 // Should not happen
  }

  let new_scopes = binder.scopes
  let _ = new_scopes.pop()

  { ..binder, scopes: new_scopes, current_scope_id: parent_id }
}

///|
/// Get current scope
fn current_scope(binder : Binder) -> Scope {
  binder.scopes[binder.scopes.length() - 1]
}

///|
/// Declare a symbol in the current scope
fn declare_symbol(binder : Binder, name : String, symbol : Symbol) -> Binder {
  let scope = current_scope(binder)

  // Check for duplicate declaration
  let existing = scope.symbols.get(name)
  match existing {
    Some(_) => {
      // Duplicate declaration - add diagnostic
      let diagnostic = Diagnostic::error(
        "Duplicate identifier '" + name + "'",
        SourceLocation::new(binder.file_path, Position::{ line: 0, column: 0, offset: 0 }, Position::{ line: 0, column: 0, offset: 0 }),
        2300,
      )
      let new_diagnostics = binder.diagnostics
      new_diagnostics.push(diagnostic)
      { ..binder, diagnostics: new_diagnostics }
    }
    None => {
      // Add symbol to current scope
      let new_symbols = scope.symbols
      new_symbols.set(name, symbol)
      let updated_scope = { ..scope, symbols: new_symbols }

      // Update scope in binder
      let scope_index = binder.scopes.length() - 1
      let new_scopes = binder.scopes
      new_scopes[scope_index] = updated_scope

      {
        ..binder,
        scopes: new_scopes,
        next_symbol_id: binder.next_symbol_id + 1,
      }
    }
  }
}
