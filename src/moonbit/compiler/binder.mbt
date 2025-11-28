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
  containers : Array[Container] // Stack of containers
  current_container_id : Int
  cfg_builder : CFGBuilder // Control flow graph builder
  next_symbol_id : Int
  next_scope_id : Int
  next_container_id : Int
  file_path : String
  diagnostics : Array[Diagnostic]
  ambient_modules : AmbientModuleRegistry // Registry for ambient module declarations
  module_augmentations : Array[ModuleAugmentation] // Module augmentations (for module files)
  global_augmentations : Array[GlobalAugmentation] // Global augmentations (declare global)
  triple_slash_directives : Array[TripleSlashDirective] // Triple-slash directives
  is_external_module : Bool // Track if this file is a module (has imports/exports)
} derive(Show)

///|
/// Binder result
pub type BindResult = Result[BoundSourceFile, Array[Diagnostic]]

///|
/// Create a new binder
fn Binder::new(file_path : String) -> Binder {
  let global_scope = Scope::new(None, 0)
  let source_file_container = Container::new(ContainerKind::SourceFile, None, 0)
  {
    scopes: [global_scope],
    current_scope_id: 0,
    containers: [source_file_container],
    current_container_id: 0,
    cfg_builder: CFGBuilder::new(),
    next_symbol_id: 0,
    next_scope_id: 1,
    next_container_id: 1,
    file_path,
    diagnostics: [],
    ambient_modules: AmbientModuleRegistry::new(),
    module_augmentations: [],
    global_augmentations: [],
    triple_slash_directives: [],
    is_external_module: false,
  }
}

///|
/// Pre-scan to check if file is a module (has imports/exports)
fn is_module_file(statements : Array[Node]) -> Bool {
  for i = 0; i < statements.length(); i = i + 1 {
    match statements[i] {
      ImportDeclaration(_) => return true
      ExportDeclaration(_) => return true
      ExportAssignment(_) => return true
      FunctionDeclaration(f) =>
        if binder_has_export_modifier(f.modifiers) {
          return true
        }
      ClassDeclaration(c) =>
        if binder_has_export_modifier(c.modifiers) {
          return true
        }
      VariableStatement(v) =>
        if binder_has_export_modifier(v.modifiers) {
          return true
        }
      InterfaceDeclaration(i) =>
        if binder_has_export_modifier(i.modifiers) {
          return true
        }
      TypeAliasDeclaration(t) =>
        if binder_has_export_modifier(t.modifiers) {
          return true
        }
      EnumDeclaration(e) =>
        if binder_has_export_modifier(e.modifiers) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
/// Main entry point: bind a source file
pub fn bind_source_file(source_file : SourceFile) -> BindResult {
  let binder = Binder::new(source_file.file_path)
  // Pre-scan to detect if this is a module file (affects ambient module handling)
  let binder = { ..binder, is_external_module: is_module_file(source_file.statements) }

  // Parse triple-slash directives from raw tokens
  for i = 0; i < source_file.directive_tokens.length(); i = i + 1 {
    let (content, location) = source_file.directive_tokens[i]
    match parse_triple_slash_directive(content, location) {
      Some(directive) => binder.triple_slash_directives.push(directive)
      None => ()
    }
  }

  let binder = bind_statements(binder, source_file.statements)

  // Get global scope
  let global_scope = match binder.scopes[0] {
    scope => scope
  }

  // Detect module status
  let module_info = detect_module_status(source_file)

  // Build the control flow graph
  let control_flow_graph = binder.cfg_builder.build()
  if binder.diagnostics.length() > 0 {
    Err(binder.diagnostics)
  } else {
    Ok(BoundSourceFile::{
      file_path: source_file.file_path,
      global_scope,
      statements: source_file.statements,
      symbol_count: binder.next_symbol_id,
      diagnostics: binder.diagnostics,
      module_info,
      control_flow_graph,
      ambient_modules: binder.ambient_modules,
      module_augmentations: binder.module_augmentations,
      global_augmentations: binder.global_augmentations,
      triple_slash_directives: binder.triple_slash_directives,
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
    VariableStatement(var_stmt) =>
      bind_variable_declarations(
        binder,
        var_stmt.declarations,
        var_stmt.is_const,
      )

    // Function declaration
    FunctionDeclaration(func) => bind_function_declaration(binder, func)

    // Class declaration
    ClassDeclaration(class_decl) => bind_class_declaration(binder, class_decl)

    // Interface declaration
    InterfaceDeclaration(interface) =>
      bind_interface_declaration(binder, interface)

    // Enum declaration
    EnumDeclaration(enum_decl) => bind_enum_declaration(binder, enum_decl)

    // Type alias
    TypeAliasDeclaration(type_alias) =>
      bind_type_alias_declaration(binder, type_alias)

    // Module/namespace declaration
    ModuleDeclaration(mod_decl) => bind_module_declaration(binder, mod_decl)

    // Import declaration
    ImportDeclaration(import_decl) =>
      bind_import_declaration(binder, import_decl)

    // Export declaration
    ExportDeclaration(export_decl) =>
      bind_export_declaration(binder, export_decl)

    // Export assignment
    ExportAssignment(export_assign) =>
      bind_export_assignment(binder, export_assign)

    // Block statement
    BlockStatement(block) => {
      let binder = push_scope(binder)
      let binder = push_container(binder, ContainerKind::Block)
      let binder = bind_statements(binder, block.statements)
      let binder = pop_container(binder)
      pop_scope(binder)
    }

    // If statement
    IfStatement(if_stmt) => {
      let binder = bind_expression(binder, if_stmt.condition)
      // Create condition flow node for the if condition
      let binder = create_condition_flow(binder, if_stmt.condition)
      let condition_id = get_current_flow_id(binder)

      // Create true branch flow and bind then statement
      let binder = create_true_condition_flow(binder, condition_id)
      let binder = bind_statement(binder, if_stmt.then_statement)
      let then_flow_id = get_current_flow_id(binder)

      // Handle else branch if present
      match if_stmt.else_statement {
        Some(else_stmt) => {
          // Create false branch flow and bind else statement
          let binder = create_false_condition_flow(binder, condition_id)
          let binder = bind_statement(binder, else_stmt)
          let else_flow_id = get_current_flow_id(binder)
          // Merge both branches
          create_reducer_flow(binder, [then_flow_id, else_flow_id])
        }
        None => {
          // No else branch - merge then branch with false condition
          let binder = create_false_condition_flow(binder, condition_id)
          let false_flow_id = get_current_flow_id(binder)
          create_reducer_flow(binder, [then_flow_id, false_flow_id])
        }
      }
    }

    // For statement
    ForStatement(for_stmt) => {
      let binder = push_scope(binder)
      let binder = push_container(binder, ContainerKind::ForStatement)

      // Bind initializer
      let binder = match for_stmt.initializer {
        Some(init) => bind_statement(binder, init)
        None => binder
      }

      // Create loop label for break/continue targets
      let break_label_id = binder.cfg_builder.next_id
      let continue_label_id = break_label_id + 1
      let binder = create_loop_label_flow(
        binder,
        Some(break_label_id),
        Some(continue_label_id),
      )

      // Push loop context for break/continue handling
      let cfg_builder = binder.cfg_builder.push_loop(
        break_label_id,
        continue_label_id,
        None,
      )
      let binder = { ..binder, cfg_builder, }

      // Bind condition
      let (binder, condition_id) = match for_stmt.condition {
        Some(cond) => {
          let binder = bind_expression(binder, cond)
          let binder = create_condition_flow(binder, cond)
          (binder, Some(get_current_flow_id(binder)))
        }
        None => (binder, None)
      }

      // Create true branch for loop body
      let binder = match condition_id {
        Some(cid) => create_true_condition_flow(binder, cid)
        None => binder
      }

      // Bind loop body
      let binder = bind_statement(binder, for_stmt.statement)

      // Create branch label for continue target
      let binder = create_branch_label_flow(binder, None)

      // Bind incrementor
      let binder = match for_stmt.incrementor {
        Some(inc) => bind_expression(binder, inc)
        None => binder
      }

      // Pop loop context
      let cfg_builder = binder.cfg_builder.pop_loop()
      let binder = { ..binder, cfg_builder, }

      // Create false branch for loop exit (when condition is false)
      let binder = match condition_id {
        Some(cid) => {
          let body_end_flow = get_current_flow_id(binder)
          let binder = create_false_condition_flow(binder, cid)
          let exit_flow = get_current_flow_id(binder)
          // Merge body continuation with exit
          create_reducer_flow(binder, [body_end_flow, exit_flow])
        }
        None => binder
      }
      let binder = pop_container(binder)
      pop_scope(binder)
    }

    // While statement
    WhileStatement(while_stmt) => {
      // Create loop label for break/continue targets
      let break_label_id = binder.cfg_builder.next_id
      let continue_label_id = break_label_id + 1
      let binder = create_loop_label_flow(
        binder,
        Some(break_label_id),
        Some(continue_label_id),
      )

      // Push loop context for break/continue handling
      let cfg_builder = binder.cfg_builder.push_loop(
        break_label_id,
        continue_label_id,
        None,
      )
      let binder = { ..binder, cfg_builder, }

      // Bind and create condition flow
      let binder = bind_expression(binder, while_stmt.condition)
      let binder = create_condition_flow(binder, while_stmt.condition)
      let condition_id = get_current_flow_id(binder)

      // Create true branch for loop body
      let binder = create_true_condition_flow(binder, condition_id)

      // Bind loop body
      let binder = bind_statement(binder, while_stmt.statement)
      let body_end_flow = get_current_flow_id(binder)

      // Pop loop context
      let cfg_builder = binder.cfg_builder.pop_loop()
      let binder = { ..binder, cfg_builder, }

      // Create false branch for loop exit
      let binder = create_false_condition_flow(binder, condition_id)
      let exit_flow = get_current_flow_id(binder)

      // Merge body continuation with exit
      create_reducer_flow(binder, [body_end_flow, exit_flow])
    }

    // Do-while statement
    DoWhileStatement(do_stmt) => {
      // Create loop label for break/continue targets
      let break_label_id = binder.cfg_builder.next_id
      let continue_label_id = break_label_id + 1
      let binder = create_loop_label_flow(
        binder,
        Some(break_label_id),
        Some(continue_label_id),
      )

      // Push loop context for break/continue handling
      let cfg_builder = binder.cfg_builder.push_loop(
        break_label_id,
        continue_label_id,
        None,
      )
      let binder = { ..binder, cfg_builder, }

      // Bind loop body first (do-while executes body before checking condition)
      let binder = bind_statement(binder, do_stmt.statement)

      // Create branch label for continue target
      let binder = create_branch_label_flow(binder, None)

      // Bind and create condition flow
      let binder = bind_expression(binder, do_stmt.condition)
      let binder = create_condition_flow(binder, do_stmt.condition)
      let condition_id = get_current_flow_id(binder)

      // Pop loop context
      let cfg_builder = binder.cfg_builder.pop_loop()
      let binder = { ..binder, cfg_builder, }

      // Create true branch (loops back) and false branch (exits)
      let binder = create_true_condition_flow(binder, condition_id)
      let loop_back_flow = get_current_flow_id(binder)
      let binder = create_false_condition_flow(binder, condition_id)
      let exit_flow = get_current_flow_id(binder)

      // Merge loop back with exit
      create_reducer_flow(binder, [loop_back_flow, exit_flow])
    }

    // Switch statement
    SwitchStatement(switch_stmt) => {
      let binder = bind_expression(binder, switch_stmt.expression)
      // Create a break label for the switch
      let break_label_id = binder.cfg_builder.next_id
      // Push switch context
      let cfg_builder = binder.cfg_builder.push_switch(break_label_id)
      let binder = { ..binder, cfg_builder, }
      // Bind case clauses
      let binder = bind_case_clauses(binder, node, switch_stmt.cases)
      // Pop switch context
      let cfg_builder = binder.cfg_builder.pop_switch()
      { ..binder, cfg_builder, }
    }

    // Return statement
    ReturnStatement(ret_stmt) => {
      let binder = match ret_stmt.expression {
        Some(expr) => bind_expression(binder, expr)
        None => binder
      }
      // Create return flow node, then mark as unreachable
      let binder = create_return_flow(binder, node)
      create_unreachable_flow(binder)
    }

    // Throw statement
    ThrowStatement(throw_stmt) => {
      let binder = bind_expression(binder, throw_stmt.expression)
      // Create throw flow node, then mark as unreachable
      let binder = create_throw_flow(binder, node)
      create_unreachable_flow(binder)
    }

    // Try statement
    TryStatement(try_stmt) => {
      let binder = bind_statement(binder, try_stmt.try_block)
      let binder = match try_stmt.catch_clause {
        Some(catch_info) => {
          let binder = push_scope(binder)
          let binder = push_container(binder, ContainerKind::CatchBlock)
          // Bind catch variable if present
          let binder = match catch_info.variable_declaration {
            Some(var_decl) => bind_catch_variable(binder, var_decl)
            None => binder
          }
          let binder = bind_statement(binder, catch_info.block)
          let binder = pop_container(binder)
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
    ExpressionStatement(expr_stmt) =>
      bind_expression(binder, expr_stmt.expression)

    // Labeled statement
    LabeledStatement(labeled) => {
      // Create label flow node for the labeled statement
      let binder = create_label_flow(binder)
      bind_statement(binder, labeled.statement)
    }

    // Break statement
    BreakStatement(break_stmt) => {
      // Create branch label flow for the break target
      let binder = create_branch_label_flow(binder, break_stmt.label)
      // After break, code is unreachable
      create_unreachable_flow(binder)
    }

    // Continue statement
    ContinueStatement(continue_stmt) => {
      // Create branch label flow for the continue target
      let binder = create_branch_label_flow(binder, continue_stmt.label)
      // After continue, code is unreachable
      create_unreachable_flow(binder)
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
  // Bind the pattern (identifier, array pattern, or object pattern)
  let binder = bind_binding_pattern(binder, decl.name, is_const)

  // Bind initializer expression if present
  match decl.initializer {
    Some(init) => bind_expression(binder, init)
    None => binder
  }
}

///|
/// Bind a binding pattern (recursively binds all identifiers)
fn bind_binding_pattern(
  binder : Binder,
  pattern : Node,
  is_const : Bool,
) -> Binder {
  match pattern {
    Identifier(id) => {
      let mut symbol = Symbol::new(
        id.name,
        SymbolKind::Variable,
        binder.next_symbol_id,
      )

      // Set const flag on symbol
      if is_const {
        symbol = { ..symbol, flags: { ..symbol.flags, is_const: true } }
      }
      declare_symbol(binder, id.name, symbol)
    }
    ArrayBindingPattern(array_pattern) => {
      let mut binder = binder
      for i = 0; i < array_pattern.elements.length(); i = i + 1 {
        match array_pattern.elements[i] {
          Some(element) =>
            binder = bind_binding_pattern(binder, element, is_const)
          None => () // Hole in pattern
        }
      }
      binder
    }
    ObjectBindingPattern(obj_pattern) => {
      let mut binder = binder
      for i = 0; i < obj_pattern.properties.length(); i = i + 1 {
        let prop = obj_pattern.properties[i]
        binder = bind_binding_pattern(binder, prop.name, is_const)
      }
      binder
    }
    _ => binder // Unknown pattern type
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

  // Create new scope and container for function body
  let binder = push_scope(binder)
  let binder = push_container(binder, ContainerKind::Function)

  // Bind type parameters (generics)
  let binder = bind_type_parameters(binder, func.type_parameters)

  // Bind parameters
  let binder = bind_parameters(binder, func.parameters)

  // Bind body
  let binder = match func.body {
    Some(body) => bind_statement(binder, body)
    None => binder
  }
  let binder = pop_container(binder)
  pop_scope(binder)
}

///|
/// Bind class declaration
fn bind_class_declaration(
  binder : Binder,
  class_decl : ClassDeclaration,
) -> Binder {
  let name = match class_decl.name {
    Some(Node::Identifier(id)) => id.name
    _ => return binder // Anonymous class
  }
  let symbol = Symbol::new(name, SymbolKind::Class, binder.next_symbol_id)
  let symbol = symbol.add_declaration(Node::ClassDeclaration(class_decl))
  let binder = declare_symbol(binder, name, symbol)

  // Create new scope and container for class body
  let binder = push_scope(binder)
  let binder = push_container(binder, ContainerKind::Class)

  // Bind type parameters (generics)
  let binder = bind_type_parameters(binder, class_decl.type_parameters)

  // Bind class members
  let binder = bind_class_members(binder, class_decl.members)
  let binder = pop_container(binder)
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
        let symbol = Symbol::new(
          prop.name,
          SymbolKind::Property,
          binder.next_symbol_id,
        )
        declare_symbol(binder, prop.name, symbol)
      }
      MethodDeclaration(meth) => {
        let symbol = Symbol::new(
          meth.name,
          SymbolKind::Method,
          binder.next_symbol_id,
        )
        let binder = declare_symbol(binder, meth.name, symbol)
        // Bind method body
        match meth.body {
          Some(body) => {
            let binder = push_scope(binder)
            let binder = push_container(binder, ContainerKind::Function)
            let binder = bind_parameters(binder, meth.parameters)
            let binder = bind_statement(binder, body)
            let binder = pop_container(binder)
            pop_scope(binder)
          }
          None => binder
        }
      }
      ConstructorDeclaration(ctor) => {
        let symbol = Symbol::new(
          "constructor",
          SymbolKind::Method,
          binder.next_symbol_id,
        )
        let binder = declare_symbol(binder, "constructor", symbol)
        // Bind constructor body
        match ctor.body {
          Some(body) => {
            let binder = push_scope(binder)
            let binder = push_container(binder, ContainerKind::Function)
            let binder = bind_parameters(binder, ctor.parameters)
            let binder = bind_statement(binder, body)
            let binder = pop_container(binder)
            pop_scope(binder)
          }
          None => binder
        }
      }
      GetAccessor(getter) => {
        let symbol = Symbol::new(
          getter.name,
          SymbolKind::GetAccessor,
          binder.next_symbol_id,
        )
        let binder = declare_symbol(binder, getter.name, symbol)
        // Bind getter body
        match getter.body {
          Some(body) => {
            let binder = push_scope(binder)
            let binder = push_container(binder, ContainerKind::Function)
            let binder = bind_statement(binder, body)
            let binder = pop_container(binder)
            pop_scope(binder)
          }
          None => binder
        }
      }
      SetAccessor(setter) => {
        let symbol = Symbol::new(
          setter.name,
          SymbolKind::SetAccessor,
          binder.next_symbol_id,
        )
        let binder = declare_symbol(binder, setter.name, symbol)
        // Bind setter body
        match setter.body {
          Some(body) => {
            let binder = push_scope(binder)
            let binder = push_container(binder, ContainerKind::Function)
            // Bind setter parameter
            let binder = bind_parameters(binder, [setter.parameter])
            let binder = bind_statement(binder, body)
            let binder = pop_container(binder)
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
  // Create members symbol table for interface properties
  let members : SymbolTable = Map::new()

  // Create scope and container for interface to bind type parameters
  let binder = push_scope(binder)
  let binder = push_container(binder, ContainerKind::Interface)

  // Bind type parameters (generics)
  let binder = bind_type_parameters(binder, interface.type_parameters)

  // Bind each interface member (property signature, index signature)
  for i = 0; i < interface.members.length(); i = i + 1 {
    match interface.members[i] {
      PropertyDeclaration(prop) => {
        let prop_symbol = Symbol::new(
          prop.name,
          SymbolKind::Property,
          binder.next_symbol_id,
        )
        members.set(prop.name, prop_symbol)
      }
      IndexSignatureDeclaration(idx_sig) => {
        // Index signatures don't have a name per se, but we bind them with their parameter name
        // This helps with type checking when accessing properties dynamically
        let idx_symbol = Symbol::new(
          idx_sig.parameter_name,
          SymbolKind::Property,
          binder.next_symbol_id,
        )
        members.set("__index_" + idx_sig.parameter_name, idx_symbol)
      }
      _ => () // Skip other member types for now
    }
  }
  let binder = pop_container(binder)
  let binder = pop_scope(binder)
  let mut symbol = Symbol::new(
    interface.name,
    SymbolKind::Interface,
    binder.next_symbol_id,
  )
  let interface_node = Node::InterfaceDeclaration(interface)
  symbol = symbol.add_declaration(interface_node)
  symbol = {
    ..symbol,
    members: Some(members),
    value_declaration: Some(interface_node),
  }
  declare_symbol(binder, interface.name, symbol)
}

///|
/// Bind enum declaration
fn bind_enum_declaration(
  binder : Binder,
  enum_decl : EnumDeclaration,
) -> Binder {
  let symbol = Symbol::new(
    enum_decl.name,
    SymbolKind::Enum,
    binder.next_symbol_id,
  )
  let symbol = symbol.add_declaration(Node::EnumDeclaration(enum_decl))
  let binder = declare_symbol(binder, enum_decl.name, symbol)

  // Push container for enum body
  let binder = push_container(binder, ContainerKind::EnumDeclaration)

  // Bind enum members
  let binder = bind_enum_members(binder, enum_decl.members)

  // Pop container
  pop_container(binder)
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
    let symbol = Symbol::new(
      mem.name,
      SymbolKind::EnumMember,
      binder.next_symbol_id,
    )
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
  let symbol = Symbol::new(
    type_alias.name,
    SymbolKind::Type,
    binder.next_symbol_id,
  )
  let symbol = symbol.add_declaration(Node::TypeAliasDeclaration(type_alias))
  let binder = declare_symbol(binder, type_alias.name, symbol)

  // Push scope for type parameters
  let binder = push_scope(binder)

  // Bind type parameters (generics)
  let binder = bind_type_parameters(binder, type_alias.type_parameters)

  // Pop scope
  pop_scope(binder)
}

///|
/// Bind module/namespace declaration
fn bind_module_declaration(
  binder : Binder,
  mod_decl : ModuleDeclaration,
) -> Binder {
  // Check for global augmentation (declare global { })
  if mod_decl.is_global_augmentation {
    // Global augmentation - declarations are added to global scope
    // Bind the body in a new scope to collect declarations
    let binder = push_scope(binder)
    let binder = push_container(binder, ContainerKind::Module)

    // Bind module body if present
    let binder = match mod_decl.body {
      Some(body) => bind_statement(binder, body)
      None => binder
    }

    // Get the declarations from the scope
    let augmentation_scope = current_scope(binder)
    let declarations = augmentation_scope.symbols

    // Create global augmentation record
    let augmentation = GlobalAugmentation::{
      declarations,
      body: mod_decl.body,
      location: mod_decl.location,
    }
    binder.global_augmentations.push(augmentation)

    // Pop container and scope
    let binder = pop_container(binder)
    pop_scope(binder)
  } else if mod_decl.is_ambient {
    // Check if this is an ambient module declaration (declare module "pattern" { })
    // The parser sets is_ambient=true when the name was a string literal
    // Bind the body in a new scope
    let binder = push_scope(binder)
    let binder = push_container(binder, ContainerKind::Module)

    // Bind module body if present
    let binder = match mod_decl.body {
      Some(body) => bind_statement(binder, body)
      None => binder
    }

    // Get the declarations from the module scope
    let module_scope = current_scope(binder)
    let declarations = module_scope.symbols

    // Determine if this is a module augmentation or ambient module declaration
    // In a module file (has imports/exports), declare module is an augmentation
    // In a script file (no imports/exports), declare module creates an ambient module
    if binder.is_external_module {
      // Module augmentation - extends an existing module
      let augmentation = ModuleAugmentation::{
        module_name: mod_decl.name,
        declarations,
        body: mod_decl.body,
        location: mod_decl.location,
      }
      binder.module_augmentations.push(augmentation)
    } else {
      // Ambient module declaration - creates a new module type
      binder.ambient_modules.register(
        mod_decl.name,
        declarations,
        mod_decl.body,
        mod_decl.location,
      )
    }

    // Pop container and scope
    let binder = pop_container(binder)
    pop_scope(binder)
  } else {
    // Regular namespace declaration
    let symbol = Symbol::new(
      mod_decl.name,
      SymbolKind::Module,
      binder.next_symbol_id,
    )
    let symbol = symbol.add_declaration(Node::ModuleDeclaration(mod_decl))
    let binder = declare_symbol(binder, mod_decl.name, symbol)

    // Push scope and container for module body
    let binder = push_scope(binder)
    let binder = push_container(binder, ContainerKind::Module)

    // Bind module body if present
    let binder = match mod_decl.body {
      Some(body) => bind_statement(binder, body)
      None => binder
    }

    // Pop container and scope
    let binder = pop_container(binder)
    pop_scope(binder)
  }
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
          let symbol = Symbol::new(
            name,
            SymbolKind::Alias,
            binder.next_symbol_id,
          )
          declare_symbol(binder, name, symbol)
        }
        None => binder
      }

      // Bind named imports
      match clause.named_bindings {
        Some(NamedImports::NamespaceImport(name, _)) => {
          let symbol = Symbol::new(
            name,
            SymbolKind::Module,
            binder.next_symbol_id,
          )
          declare_symbol(binder, name, symbol)
        }
        Some(NamedImports::NamedImports(specifiers, _)) =>
          bind_import_specifiers(binder, specifiers)
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
    let symbol = Symbol::new(
      local_name,
      SymbolKind::Alias,
      binder.next_symbol_id,
    )
    let binder = declare_symbol(binder, local_name, symbol)
    bind_import_specifiers_aux(binder, specifiers, index + 1)
  }
}

///|
/// Bind export declaration
fn bind_export_declaration(
  binder : Binder,
  export_decl : ExportDeclaration,
) -> Binder {
  // Only create export symbols for re-exports (when there's a module specifier)
  // e.g., `export { foo } from 'module'` creates ExportValue for 'foo'
  // e.g., `export type { Foo } from 'module'` creates ExportType for 'Foo'
  // Local exports (`export { foo }` or `export type { Foo }`) just reference existing bindings
  match export_decl.module_specifier {
    Some(_) =>
      // Re-export from another module - create export symbols
      match export_decl.export_clause {
        Some(NamedExports::NamedExports(specifiers, _)) =>
          bind_export_specifiers(binder, specifiers, export_decl.is_type_only)
        Some(NamedExports::NamespaceExport(ns_name, _)) => {
          // export * as ns from 'mod' - create a symbol for the namespace
          let symbol = Symbol::new(
            ns_name,
            SymbolKind::ExportValue,
            binder.next_symbol_id,
          )
          declare_symbol(binder, ns_name, symbol)
        }
        None => binder
      }
    None => binder // Local export - no new bindings needed
  }
}

///|
/// Bind export specifiers
fn bind_export_specifiers(
  binder : Binder,
  specifiers : Array[ExportSpecifier],
  is_type_only : Bool,
) -> Binder {
  bind_export_specifiers_aux(binder, specifiers, is_type_only, 0)
}

///|
fn bind_export_specifiers_aux(
  binder : Binder,
  specifiers : Array[ExportSpecifier],
  is_type_only : Bool,
  index : Int,
) -> Binder {
  if index >= specifiers.length() {
    binder
  } else {
    let spec = specifiers[index]
    // Use ExportType for type-only exports, ExportValue otherwise
    let kind = if is_type_only {
      SymbolKind::ExportType
    } else {
      SymbolKind::ExportValue
    }
    let symbol = Symbol::new(spec.name, kind, binder.next_symbol_id)
    let binder = declare_symbol(binder, spec.name, symbol)
    bind_export_specifiers_aux(binder, specifiers, is_type_only, index + 1)
  }
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
fn bind_case_clauses(
  binder : Binder,
  switch_statement : Node,
  cases : Array[CaseClause],
) -> Binder {
  bind_case_clauses_aux(binder, switch_statement, cases, 0)
}

///|
fn bind_case_clauses_aux(
  binder : Binder,
  switch_statement : Node,
  cases : Array[CaseClause],
  index : Int,
) -> Binder {
  if index >= cases.length() {
    binder
  } else {
    let case_clause = cases[index]

    // Create switch clause flow node for this case
    let binder = create_switch_clause_flow(
      binder,
      switch_statement,
      index,
      cases.length(),
    )

    // Add this clause's flow ID to the switch context
    let clause_flow_id = binder.cfg_builder.current_flow
    let cfg_builder = binder.cfg_builder.add_clause_flow(clause_flow_id)
    let binder = { ..binder, cfg_builder, }

    // Bind case expression if present
    let binder = match case_clause.expression {
      Some(expr) => bind_expression(binder, expr)
      None => binder
    }

    // Bind case statements
    let binder = bind_statements(binder, case_clause.statements)
    bind_case_clauses_aux(binder, switch_statement, cases, index + 1)
  }
}

///|
/// Bind catch variable (e.g., `catch (e)` or `catch (e: Error)`)
fn bind_catch_variable(binder : Binder, var_decl : Node) -> Binder {
  match var_decl {
    Identifier(id) => {
      let symbol = Symbol::new(
        id.name,
        SymbolKind::Variable,
        binder.next_symbol_id,
      )
      declare_symbol(binder, id.name, symbol)
    }
    // Handle binding patterns like `catch ({ message })` or `catch ([first, second])`
    ArrayBindingPattern(_) | ObjectBindingPattern(_) =>
      bind_binding_pattern(binder, var_decl, false)
    _ => binder
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
        let symbol = Symbol::new(
          param_name,
          SymbolKind::Parameter,
          binder.next_symbol_id,
        )
        declare_symbol(binder, param_name, symbol)
      }
      _ => binder
    }
    bind_parameters_aux(binder, parameters, index + 1)
  }
}

///|
/// Bind type parameters (generics like <T, U extends V>)
fn bind_type_parameters(
  binder : Binder,
  type_params : Array[TypeParameter],
) -> Binder {
  bind_type_parameters_aux(binder, type_params, 0)
}

///|
fn bind_type_parameters_aux(
  binder : Binder,
  type_params : Array[TypeParameter],
  index : Int,
) -> Binder {
  if index >= type_params.length() {
    binder
  } else {
    let tp = type_params[index]
    let symbol = Symbol::new(
      tp.name,
      SymbolKind::TypeParameter,
      binder.next_symbol_id,
    )
    let binder = declare_symbol(binder, tp.name, symbol)
    bind_type_parameters_aux(binder, type_params, index + 1)
  }
}

///|
/// Check if a binary operator is an assignment operator
fn is_assignment_operator(op : BinaryOperator) -> Bool {
  match op {
    Assign
    | AddAssign
    | SubtractAssign
    | MultiplyAssign
    | DivideAssign
    | RemainderAssign
    | BitwiseAndAssign
    | BitwiseOrAssign
    | BitwiseXorAssign
    | ExponentiateAssign
    | LeftShiftAssign
    | RightShiftAssign
    | UnsignedRightShiftAssign
    | LogicalAndAssign
    | LogicalOrAssign
    | NullishCoalescingAssign => true
    _ => false
  }
}

///|
/// Get the ID of the current flow node
fn get_current_flow_id(binder : Binder) -> Int {
  binder.cfg_builder.current_flow
}

///|
/// Create a FlowAssignment node and update the binder's current flow
fn create_assignment_flow(binder : Binder, node : Node) -> Binder {
  let cfg_builder = binder.cfg_builder.add_assignment(node)
  { ..binder, cfg_builder, }
}

///|
/// Create a FlowCall node and update the binder's current flow
fn create_call_flow(binder : Binder, node : Node) -> Binder {
  let cfg_builder = binder.cfg_builder.add_call(node)
  { ..binder, cfg_builder, }
}

///|
/// Create a FlowCondition node and update the binder's current flow
fn create_condition_flow(binder : Binder, expression : Node) -> Binder {
  let cfg_builder = binder.cfg_builder.add_condition(expression)
  { ..binder, cfg_builder, }
}

///|
fn create_switch_clause_flow(
  binder : Binder,
  switch_statement : Node,
  clause_start : Int,
  clause_end : Int,
) -> Binder {
  let cfg_builder = binder.cfg_builder.add_switch_clause(
    switch_statement, clause_start, clause_end,
  )
  { ..binder, cfg_builder, }
}

///|
fn create_label_flow(binder : Binder) -> Binder {
  let id = binder.cfg_builder.next_id
  let antecedent = binder.cfg_builder.current_flow
  let flow_label = FlowLabel::{ antecedents: [antecedent], id }
  let nodes = binder.cfg_builder.nodes
  nodes.push(FlowNode::Label(flow_label))
  let cfg_builder = { ..binder.cfg_builder, next_id: id + 1, current_flow: id }
  { ..binder, cfg_builder, }
}

///|
fn create_array_mutation_flow(binder : Binder, node : Node) -> Binder {
  let cfg_builder = binder.cfg_builder.add_array_mutation(node)
  { ..binder, cfg_builder, }
}

///|
fn create_return_flow(binder : Binder, node : Node) -> Binder {
  let cfg_builder = binder.cfg_builder.add_return(node)
  { ..binder, cfg_builder, }
}

///|
fn create_unreachable_flow(binder : Binder) -> Binder {
  let cfg_builder = binder.cfg_builder.add_unreachable()
  { ..binder, cfg_builder, }
}

///|
/// Create a FlowEnd node and update the binder's current flow.
/// This can be used for creating intermediate end nodes in complex control flow.
/// Note: CFGBuilder::build() automatically creates the final end node.
pub fn create_end_flow(binder : Binder) -> Binder {
  let id = binder.cfg_builder.next_id
  let antecedent = binder.cfg_builder.current_flow
  let flow_end = FlowEnd::{ antecedent, id }
  let nodes = binder.cfg_builder.nodes
  nodes.push(FlowNode::End(flow_end))
  let cfg_builder = { ..binder.cfg_builder, next_id: id + 1, current_flow: id }
  { ..binder, cfg_builder, }
}

///|
/// Create a FlowBranchCondition node for true branch
fn create_true_condition_flow(binder : Binder, condition_id : Int) -> Binder {
  let id = binder.cfg_builder.next_id
  let flow_branch = FlowBranchCondition::{
    antecedent: condition_id,
    is_true_branch: true,
    id,
  }
  let nodes = binder.cfg_builder.nodes
  nodes.push(FlowNode::TrueCondition(flow_branch))
  let cfg_builder = { ..binder.cfg_builder, next_id: id + 1, current_flow: id }
  { ..binder, cfg_builder, }
}

///|
/// Create a FlowBranchCondition node for false branch
fn create_false_condition_flow(binder : Binder, condition_id : Int) -> Binder {
  let id = binder.cfg_builder.next_id
  let flow_branch = FlowBranchCondition::{
    antecedent: condition_id,
    is_true_branch: false,
    id,
  }
  let nodes = binder.cfg_builder.nodes
  nodes.push(FlowNode::FalseCondition(flow_branch))
  let cfg_builder = { ..binder.cfg_builder, next_id: id + 1, current_flow: id }
  { ..binder, cfg_builder, }
}

///|
/// Create a FlowLoopLabel node for loop tracking
fn create_loop_label_flow(
  binder : Binder,
  break_target : Int?,
  continue_target : Int?,
) -> Binder {
  let id = binder.cfg_builder.next_id
  let antecedent = binder.cfg_builder.current_flow
  let flow_loop = FlowLoopLabel::{
    antecedents: [antecedent],
    break_target,
    continue_target,
    id,
  }
  let nodes = binder.cfg_builder.nodes
  nodes.push(FlowNode::LoopLabel(flow_loop))
  let cfg_builder = { ..binder.cfg_builder, next_id: id + 1, current_flow: id }
  { ..binder, cfg_builder, }
}

///|
/// Create a FlowBranchLabel node for break/continue targets
fn create_branch_label_flow(binder : Binder, name : String?) -> Binder {
  let id = binder.cfg_builder.next_id
  let antecedent = binder.cfg_builder.current_flow
  let flow_branch_label = FlowBranchLabel::{
    name,
    antecedents: [antecedent],
    id,
  }
  let nodes = binder.cfg_builder.nodes
  nodes.push(FlowNode::BranchLabel(flow_branch_label))
  let cfg_builder = { ..binder.cfg_builder, next_id: id + 1, current_flow: id }
  { ..binder, cfg_builder, }
}

///|
/// Create a FlowThrow node and update the binder's current flow
fn create_throw_flow(binder : Binder, node : Node) -> Binder {
  let cfg_builder = binder.cfg_builder.add_throw(node)
  { ..binder, cfg_builder, }
}

///|
/// Create a FlowNarrowing node for type narrowing.
/// This is used during type checking to record type narrowing at specific
/// control flow points (e.g., after typeof checks, instanceof checks, etc.).
/// The checker should call this when it determines a type guard narrows a type.
pub fn create_narrowing_flow(
  binder : Binder,
  expression : Node,
  narrowed_symbol : Int,
  narrowed_type : Node,
) -> Binder {
  let id = binder.cfg_builder.next_id
  let antecedent = binder.cfg_builder.current_flow
  let flow_narrowing = FlowNarrowing::{
    expression,
    narrowed_symbol,
    narrowed_type,
    antecedent,
    id,
  }
  let nodes = binder.cfg_builder.nodes
  nodes.push(FlowNode::Narrowing(flow_narrowing))
  let cfg_builder = { ..binder.cfg_builder, next_id: id + 1, current_flow: id }
  { ..binder, cfg_builder, }
}

///|
/// Create a FlowReducer node for merging multiple flows
fn create_reducer_flow(binder : Binder, antecedents : Array[Int]) -> Binder {
  let id = binder.cfg_builder.next_id
  let flow_reducer = FlowReducer::{ antecedents, id }
  let nodes = binder.cfg_builder.nodes
  nodes.push(FlowNode::Reducer(flow_reducer))
  let cfg_builder = { ..binder.cfg_builder, next_id: id + 1, current_flow: id }
  { ..binder, cfg_builder, }
}

///|
/// Bind an expression (simplified - just walks the tree)
fn bind_expression(binder : Binder, node : Node) -> Binder {
  match node {
    // Literal expressions - no binding needed
    NumericLiteral(_) | StringLiteral(_) | BooleanLiteral(_) | NullLiteral(_) =>
      binder

    // Identifier - would need to resolve, but that's for the checker
    Identifier(_) => binder

    // Binary expression
    BinaryExpression(bin_expr) => {
      let binder = bind_expression(binder, bin_expr.left)
      let binder = bind_expression(binder, bin_expr.right)
      // Create flow node for assignment operators
      if is_assignment_operator(bin_expr.operator) {
        // Check if this is an array element assignment (array mutation)
        match bin_expr.left {
          ElementAccessExpression(_) => create_array_mutation_flow(binder, node)
          _ => create_assignment_flow(binder, node)
        }
      } else {
        binder
      }
    }

    // Unary expression
    UnaryExpression(unary_expr) => bind_expression(binder, unary_expr.operand)

    // Call expression
    CallExpression(call_expr) => {
      let binder = bind_expression(binder, call_expr.expression)
      let binder = bind_expressions(binder, call_expr.arguments)
      // Create flow call node for control flow analysis
      create_call_flow(binder, node)
    }

    // Property access
    PropertyAccessExpression(prop_access) =>
      bind_expression(binder, prop_access.expression)

    // Element access
    ElementAccessExpression(elem_access) => {
      let binder = bind_expression(binder, elem_access.expression)
      bind_expression(binder, elem_access.argument_expression)
    }

    // Array literal (elements can be None for holes)
    ArrayLiteralExpression(array_lit) =>
      bind_array_elements(binder, array_lit.elements)

    // Object literal
    ObjectLiteralExpression(obj_lit) =>
      bind_object_properties(binder, obj_lit.properties)

    // Arrow function
    ArrowFunction(arrow) => {
      let binder = push_scope(binder)
      let binder = push_container(binder, ContainerKind::Function)
      let binder = bind_parameters(binder, arrow.parameters)
      let binder = bind_statement(binder, arrow.body)
      let binder = pop_container(binder)
      pop_scope(binder)
    }

    // Conditional expression
    ConditionalExpression(cond_expr) => {
      let binder = bind_expression(binder, cond_expr.condition)
      // Create condition flow node for the ternary condition
      let binder = create_condition_flow(binder, cond_expr.condition)
      let binder = bind_expression(binder, cond_expr.when_true)
      bind_expression(binder, cond_expr.when_false)
    }

    // Optional chain expression
    OptionalChain(oc) => {
      let binder = bind_expression(binder, oc.expression)
      match oc.chain {
        OptionalChainKind::Call(args) => bind_expressions(binder, args)
        OptionalChainKind::Element(index) => bind_expression(binder, index)
        OptionalChainKind::Property(_) => binder
      }
    }

    // Await expression
    AwaitExpression(ae) => bind_expression(binder, ae.expression)

    // Yield expression
    YieldExpression(ye) =>
      match ye.expression {
        Some(expr) => bind_expression(binder, expr)
        None => binder
      }

    // As expression (type assertion)
    AsExpression(as_expr) => bind_expression(binder, as_expr.expression)

    // Non-null expression
    NonNullExpression(nne) => bind_expression(binder, nne.expression)

    // Type assertion expression
    TypeAssertionExpression(tae) => bind_expression(binder, tae.expression)

    // Parenthesized expression
    ParenthesizedExpression(pe) => bind_expression(binder, pe.expression)

    // Function expression
    FunctionExpression(fe) => {
      let binder = push_scope(binder)
      let binder = push_container(binder, ContainerKind::Function)
      let binder = bind_parameters(binder, fe.parameters)
      let binder = bind_statement(binder, fe.body)
      let binder = pop_container(binder)
      pop_scope(binder)
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
fn bind_object_properties(
  binder : Binder,
  properties : Array[ObjectProperty],
) -> Binder {
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
      ComputedPropertyAssignment(name_expr, value, _) => {
        let binder = bind_expression(binder, name_expr)
        bind_expression(binder, value)
      }
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
  let new_scope = Scope::new(
    Some(binder.current_scope_id),
    binder.next_scope_id,
  )
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

// ============================================================================
// Container management
// ============================================================================

///|
/// Push a new container onto the container stack
fn push_container(binder : Binder, kind : ContainerKind) -> Binder {
  let new_container = Container::new(
    kind,
    Some(binder.current_container_id),
    binder.next_container_id,
  )
  let new_containers = binder.containers
  new_containers.push(new_container)
  {
    ..binder,
    containers: new_containers,
    current_container_id: binder.next_container_id,
    next_container_id: binder.next_container_id + 1,
  }
}

///|
/// Pop the current container from the container stack
fn pop_container(binder : Binder) -> Binder {
  let current_container = binder.containers[binder.containers.length() - 1]
  let parent_id = match current_container.parent {
    Some(id) => id
    None => 0 // Should not happen (SourceFile is always at the bottom)
  }
  let new_containers = binder.containers
  let _ = new_containers.pop()
  { ..binder, containers: new_containers, current_container_id: parent_id }
}

///|
/// Get current container
pub fn current_container(binder : Binder) -> Container {
  binder.containers[binder.containers.length() - 1]
}

///|
/// Get the enclosing function container (for var hoisting)
pub fn get_enclosing_function_container(binder : Binder) -> Container? {
  let mut i = binder.containers.length() - 1
  while i >= 0 {
    let container = binder.containers[i]
    match container.kind {
      ContainerKind::Function | ContainerKind::SourceFile =>
        return Some(container)
      _ => i = i - 1
    }
  }
  None
}

///|
/// Get the enclosing block container (for let/const scoping)
pub fn get_enclosing_block_container(binder : Binder) -> Container? {
  let mut i = binder.containers.length() - 1
  while i >= 0 {
    let container = binder.containers[i]
    match container.kind {
      ContainerKind::Block
      | ContainerKind::ForStatement
      | ContainerKind::CatchBlock
      | ContainerKind::Function
      | ContainerKind::SourceFile => return Some(container)
      _ => i = i - 1
    }
  }
  None
}

///|
/// Check if we're inside a class container
pub fn is_in_class(binder : Binder) -> Bool {
  let mut i = binder.containers.length() - 1
  while i >= 0 {
    let container = binder.containers[i]
    match container.kind {
      ContainerKind::Class => return true
      ContainerKind::Function | ContainerKind::SourceFile => return false
      _ => i = i - 1
    }
  }
  false
}

///|
/// Check if we're at the top level of a source file
pub fn is_top_level(binder : Binder) -> Bool {
  binder.containers.length() == 1 &&
  binder.containers[0].kind == ContainerKind::SourceFile
}

///|
/// Declare a symbol in the current scope
fn declare_symbol(binder : Binder, name : String, symbol : Symbol) -> Binder {
  let scope = current_scope(binder)

  // Check for duplicate declaration
  let existing = scope.symbols.get(name)
  match existing {
    Some(existing_symbol) => {
      // Allow function/method overloads (multiple declarations with same name)
      let is_function_overload = existing_symbol.kind == SymbolKind::Function &&
        symbol.kind == SymbolKind::Function
      let is_method_overload = existing_symbol.kind == SymbolKind::Method &&
        symbol.kind == SymbolKind::Method
      // Allow getter/setter pairs with the same name
      let is_getter_setter_pair = (
          existing_symbol.kind == SymbolKind::GetAccessor &&
          symbol.kind == SymbolKind::SetAccessor
        ) ||
        (
          existing_symbol.kind == SymbolKind::SetAccessor &&
          symbol.kind == SymbolKind::GetAccessor
        )
      // Allow interface merging
      let is_interface_merge = existing_symbol.kind == SymbolKind::Interface &&
        symbol.kind == SymbolKind::Interface
      // Allow namespace merging
      let is_namespace_merge = existing_symbol.kind == SymbolKind::Module &&
        symbol.kind == SymbolKind::Module
      // Allow interface + namespace merging
      let is_interface_namespace_merge = (
          existing_symbol.kind == SymbolKind::Interface &&
          symbol.kind == SymbolKind::Module
        ) ||
        (
          existing_symbol.kind == SymbolKind::Module &&
          symbol.kind == SymbolKind::Interface
        )
      if is_function_overload ||
        is_method_overload ||
        is_getter_setter_pair ||
        is_interface_merge ||
        is_namespace_merge ||
        is_interface_namespace_merge {
        // Overload, getter/setter pair, or mergeable declaration - allow it
        // For interface/namespace merging, merge the symbols
        if is_interface_merge ||
          is_namespace_merge ||
          is_interface_namespace_merge {
          let merged_symbol = merge_symbols(existing_symbol, symbol)
          let new_symbols = scope.symbols
          new_symbols.set(name, merged_symbol)
          let updated_scope = { ..scope, symbols: new_symbols }
          let scope_index = binder.scopes.length() - 1
          let new_scopes = binder.scopes
          new_scopes[scope_index] = updated_scope
          { ..binder, scopes: new_scopes }
        } else {
          binder
        }
      } else {
        // Duplicate declaration - add diagnostic
        let diagnostic = Diagnostic::error(
          "Duplicate identifier '" + name + "'",
          SourceLocation::new(
            binder.file_path,
            Position::{ line: 0, column: 0, offset: 0 },
            Position::{ line: 0, column: 0, offset: 0 },
          ),
          2300,
        )
        let new_diagnostics = binder.diagnostics
        new_diagnostics.push(diagnostic)
        { ..binder, diagnostics: new_diagnostics }
      }
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

// ============================================================================
// Module Detection
// ============================================================================

///|
/// Detect module status from source file
pub fn detect_module_status(source_file : SourceFile) -> ModuleInfo {
  let mut is_external_module = false
  let mut is_commonjs_module = false
  let mut is_strict_mode = false
  let imports : Array[ImportInfo] = []
  let exports : Array[ExportInfo] = []
  for i = 0; i < source_file.statements.length(); i = i + 1 {
    let stmt = source_file.statements[i]
    match stmt {
      // Import declaration makes it an ES module
      ImportDeclaration(import_decl) => {
        is_external_module = true
        imports.push(extract_import_info(import_decl))
      }

      // Export declaration makes it an ES module
      ExportDeclaration(export_decl) => {
        is_external_module = true
        exports.push(extract_export_decl_info(export_decl))
      }

      // Export assignment could be CommonJS
      ExportAssignment(export_assign) =>
        if export_assign.is_export_equals {
          is_commonjs_module = true
          exports.push(ExportInfo::{
            kind: ExportKind::Equals,
            name: None,
            is_type_only: false,
            module_specifier: None,
            location: export_assign.location,
          })
        } else {
          is_external_module = true
          exports.push(ExportInfo::{
            kind: ExportKind::Default,
            name: None,
            is_type_only: false,
            module_specifier: None,
            location: export_assign.location,
          })
        }

      // Check for "use strict"
      ExpressionStatement(expr_stmt) =>
        match expr_stmt.expression {
          StringLiteral(s) =>
            if s.value == "use strict" {
              is_strict_mode = true
            }
          _ => ()
        }

      // Export modifiers on declarations
      FunctionDeclaration(func) =>
        if binder_has_export_modifier(func.modifiers) {
          is_external_module = true
          let is_default = binder_has_default_modifier(func.modifiers)
          let name = match func.name {
            Some(Identifier(id)) => Some(id.name)
            _ => None
          }
          exports.push(ExportInfo::{
            kind: if is_default {
              ExportKind::Default
            } else {
              ExportKind::Declaration
            },
            name,
            is_type_only: false,
            module_specifier: None,
            location: func.location,
          })
        }
      ClassDeclaration(class_decl) =>
        if binder_has_export_modifier(class_decl.modifiers) {
          is_external_module = true
          let is_default = binder_has_default_modifier(class_decl.modifiers)
          let name = match class_decl.name {
            Some(Identifier(id)) => Some(id.name)
            _ => None
          }
          exports.push(ExportInfo::{
            kind: if is_default {
              ExportKind::Default
            } else {
              ExportKind::Declaration
            },
            name,
            is_type_only: false,
            module_specifier: None,
            location: class_decl.location,
          })
        }
      VariableStatement(var_stmt) =>
        if binder_has_export_modifier(var_stmt.modifiers) {
          is_external_module = true
          for j = 0; j < var_stmt.declarations.length(); j = j + 1 {
            let decl = var_stmt.declarations[j]
            let name = get_binding_name(decl.name)
            exports.push(ExportInfo::{
              kind: ExportKind::Declaration,
              name,
              is_type_only: false,
              module_specifier: None,
              location: decl.location,
            })
          }
        }
      InterfaceDeclaration(interface) =>
        if binder_has_export_modifier(interface.modifiers) {
          is_external_module = true
          exports.push(ExportInfo::{
            kind: ExportKind::Declaration,
            name: Some(interface.name),
            is_type_only: true,
            module_specifier: None,
            location: interface.location,
          })
        }
      TypeAliasDeclaration(type_alias) =>
        if binder_has_export_modifier(type_alias.modifiers) {
          is_external_module = true
          exports.push(ExportInfo::{
            kind: ExportKind::Declaration,
            name: Some(type_alias.name),
            is_type_only: true,
            module_specifier: None,
            location: type_alias.location,
          })
        }
      EnumDeclaration(enum_decl) =>
        if binder_has_export_modifier(enum_decl.modifiers) {
          is_external_module = true
          exports.push(ExportInfo::{
            kind: ExportKind::Declaration,
            name: Some(enum_decl.name),
            is_type_only: false,
            module_specifier: None,
            location: enum_decl.location,
          })
        }
      _ => ()
    }
  }
  {
    is_external_module,
    is_commonjs_module,
    is_ambient_module: false,
    is_strict_mode,
    module_name: None,
    imports,
    exports,
  }
}

///|
/// Extract import info from import declaration
fn extract_import_info(import_decl : ImportDeclaration) -> ImportInfo {
  let mut default_import : String? = None
  let mut namespace_import : String? = None
  let named_imports : Array[(String, String)] = []
  match import_decl.import_clause {
    Some(clause) => {
      // Default import
      default_import = clause.name

      // Named bindings
      match clause.named_bindings {
        Some(NamedImports::NamespaceImport(name, _)) =>
          namespace_import = Some(name)
        Some(NamedImports::NamedImports(specifiers, _)) =>
          for i = 0; i < specifiers.length(); i = i + 1 {
            let spec = specifiers[i]
            let property_name = match spec.property_name {
              Some(p) => p
              None => spec.name
            }
            named_imports.push((property_name, spec.name))
          }
        None => ()
      }
    }
    None => ()
  }
  {
    module_specifier: import_decl.module_specifier,
    is_type_only: false, // ImportDeclaration doesn't have this field yet
    default_import,
    namespace_import,
    named_imports,
    location: import_decl.location,
  }
}

///|
/// Extract export info from export declaration
fn extract_export_decl_info(export_decl : ExportDeclaration) -> ExportInfo {
  let (kind, name) = match export_decl.export_clause {
    Some(NamedExports::NamedExports(_, _)) => (ExportKind::Named, None)
    Some(NamedExports::NamespaceExport(ns_name, _)) =>
      (ExportKind::NamespaceAs, Some(ns_name))
    None => (ExportKind::Namespace, None)
  }
  {
    kind,
    name,
    is_type_only: export_decl.is_type_only,
    module_specifier: export_decl.module_specifier,
    location: export_decl.location,
  }
}

///|
/// Check for export modifier (binder version)
fn binder_has_export_modifier(modifiers : Array[Modifier]) -> Bool {
  for i = 0; i < modifiers.length(); i = i + 1 {
    match modifiers[i] {
      Export => return true
      _ => ()
    }
  }
  false
}

///|
/// Check for default modifier (binder version)
fn binder_has_default_modifier(modifiers : Array[Modifier]) -> Bool {
  for i = 0; i < modifiers.length(); i = i + 1 {
    match modifiers[i] {
      Default => return true
      _ => ()
    }
  }
  false
}

///|
/// Get binding name from pattern
fn get_binding_name(pattern : Node) -> String? {
  match pattern {
    Identifier(id) => Some(id.name)
    _ => None
  }
}

// ============================================================================
// Declaration Merging
// ============================================================================

///|
/// Check if two symbols can be merged
pub fn can_merge_symbols(a : Symbol, b : Symbol) -> Bool {
  match (a.kind, b.kind) {
    // Interface + Interface = merged interface
    (Interface, Interface) => true

    // Namespace + Namespace = merged namespace
    (Module, Module) => true

    // Class + Interface = class implements interface
    (Class, Interface) | (Interface, Class) => true

    // Function + Namespace = callable namespace
    (Function, Module) | (Module, Function) => true

    // Enum + Namespace = enum with static members
    (Enum, Module) | (Module, Enum) => true

    // Interface + Namespace = interface with static members
    (Interface, Module) | (Module, Interface) => true

    // Type alias can't merge with anything (except itself)
    (Type, Type) => false

    // Variables can't merge
    (Variable, _) | (_, Variable) => false
    _ => false
  }
}

///|
/// Merge two symbols
pub fn merge_symbols(a : Symbol, b : Symbol) -> Symbol {
  // Combine declarations
  let declarations = a.declarations.copy()
  for i = 0; i < b.declarations.length(); i = i + 1 {
    declarations.push(b.declarations[i])
  }

  // Merge members
  let members : SymbolTable? = match (a.members, b.members) {
    (Some(a_members), Some(b_members)) => {
      let merged : SymbolTable = Map::new()
      // Copy a_members to merged
      a_members.each(fn(name, symbol) { merged.set(name, symbol) })
      // Add b_members, merging if necessary
      b_members.each(fn(name, symbol) {
        match merged.get(name) {
          Some(existing) =>
            if can_merge_symbols(existing, symbol) {
              merged.set(name, merge_symbols(existing, symbol))
            }
          // Otherwise skip (error already reported)
          None => merged.set(name, symbol)
        }
      })
      Some(merged)
    }
    (Some(m), None) => Some(m)
    (None, Some(m)) => Some(m)
    (None, None) => None
  }

  // Merge exports
  let exports : SymbolTable? = match (a.exports, b.exports) {
    (Some(a_exports), Some(b_exports)) => {
      let merged : SymbolTable = Map::new()
      a_exports.each(fn(name, symbol) { merged.set(name, symbol) })
      b_exports.each(fn(name, symbol) { merged.set(name, symbol) })
      Some(merged)
    }
    (Some(e), None) => Some(e)
    (None, Some(e)) => Some(e)
    (None, None) => None
  }

  // Merge flags
  let flags = SymbolFlags::{
    is_export: a.flags.is_export || b.flags.is_export,
    is_ambient: a.flags.is_ambient || b.flags.is_ambient,
    is_merged: true,
    is_instantiated: a.flags.is_instantiated,
    is_transient: a.flags.is_transient,
    is_assignment: a.flags.is_assignment,
    is_optional: a.flags.is_optional,
    is_readonly: a.flags.is_readonly,
    is_const: a.flags.is_const,
    is_static: a.flags.is_static,
    is_private: a.flags.is_private,
    is_protected: a.flags.is_protected,
    is_public: a.flags.is_public,
    is_abstract: a.flags.is_abstract,
    is_async: a.flags.is_async,
  }
  { ..a, declarations, members, exports, flags }
}

///|
/// Merge global declarations across files
pub fn merge_global_declarations(
  files : Array[BoundSourceFile],
) -> (SymbolTable, Array[Diagnostic]) {
  let global_symbols : SymbolTable = Map::new()
  let diagnostics : Array[Diagnostic] = []
  for i = 0; i < files.length(); i = i + 1 {
    let file = files[i]
    file.global_scope.symbols.each(fn(name, symbol) {
      match global_symbols.get(name) {
        Some(existing) =>
          if can_merge_symbols(existing, symbol) {
            global_symbols.set(name, merge_symbols(existing, symbol))
          } else {
            // Can't merge - report duplicate
            diagnostics.push(
              Diagnostic::error(
                "Duplicate identifier '" + name + "'",
                get_symbol_location(symbol),
                2300,
              ),
            )
          }
        None => global_symbols.set(name, symbol)
      }
    })
  }
  (global_symbols, diagnostics)
}

///|
/// Get location from symbol's first declaration
fn get_symbol_location(symbol : Symbol) -> SourceLocation {
  match symbol.value_declaration {
    Some(node) => binder_get_node_location(node)
    None =>
      if symbol.declarations.length() > 0 {
        binder_get_node_location(symbol.declarations[0])
      } else {
        SourceLocation::new("", Position::{ line: 0, column: 0, offset: 0 }, Position::{
          line: 0,
          column: 0,
          offset: 0,
        })
      }
  }
}

///|
/// Get location from a node (simplified - returns a default location)
fn binder_get_node_location(node : Node) -> SourceLocation {
  match node {
    FunctionDeclaration(f) => f.location
    ClassDeclaration(c) => c.location
    InterfaceDeclaration(i) => i.location
    VariableStatement(v) => v.location
    TypeAliasDeclaration(t) => t.location
    EnumDeclaration(e) => e.location
    _ =>
      SourceLocation::new("", Position::{ line: 0, column: 0, offset: 0 }, Position::{
        line: 0,
        column: 0,
        offset: 0,
      })
  }
}

// ============================================================================
// Cross-File Linking
// ============================================================================

///|
/// Bind entire program (multiple files)
pub fn bind_program(
  source_files : Array[SourceFile],
) -> Result[Program, Array[Diagnostic]] {
  let bound_files : Array[BoundSourceFile] = []
  let all_diagnostics : Array[Diagnostic] = []
  let module_map : Map[String, BoundSourceFile] = Map::new()

  // First pass: bind each file individually
  for i = 0; i < source_files.length(); i = i + 1 {
    let source_file = source_files[i]
    match bind_source_file(source_file) {
      Ok(bound_file) => {
        bound_files.push(bound_file)
        module_map.set(source_file.file_path, bound_file)
      }
      Err(diagnostics) =>
        for j = 0; j < diagnostics.length(); j = j + 1 {
          all_diagnostics.push(diagnostics[j])
        }
    }
  }

  // Second pass: merge declarations
  let (global_symbols, merge_diagnostics) = merge_global_declarations(
    bound_files,
  )
  for i = 0; i < merge_diagnostics.length(); i = i + 1 {
    all_diagnostics.push(merge_diagnostics[i])
  }
  if all_diagnostics.is_empty() {
    Ok({ source_files: bound_files, global_symbols, module_map })
  } else {
    Err(all_diagnostics)
  }
}

// ============================================================================
// Symbol Table Queries
// ============================================================================

///|
/// Find symbol in scope chain
pub fn find_symbol_in_scope_chain(binder : Binder, name : String) -> Symbol? {
  let mut scope_id = binder.current_scope_id
  while scope_id >= 0 {
    let scope = binder.scopes[scope_id]
    match scope.symbols.get(name) {
      Some(symbol) => return Some(symbol)
      None =>
        match scope.parent {
          Some(parent_id) => scope_id = parent_id
          None => return None
        }
    }
  }
  None
}

///|
/// Get all symbols of a specific kind from a scope
pub fn get_symbols_of_kind(scope : Scope, kind : SymbolKind) -> Array[Symbol] {
  let result : Array[Symbol] = []
  scope.symbols.each(fn(_name, symbol) {
    if symbol.kind == kind {
      result.push(symbol)
    }
  })
  result
}

///|
/// Get exported symbols from a scope
pub fn get_exports(scope : Scope) -> Array[Symbol] {
  let result : Array[Symbol] = []
  scope.symbols.each(fn(_name, symbol) {
    if symbol.flags.is_export {
      result.push(symbol)
    }
  })
  result
}
