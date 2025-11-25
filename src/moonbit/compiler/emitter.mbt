// JavaScript Code Emitter
// Converts transformed AST to JavaScript source code

///|
/// Emitter context for controlling output format and source map generation
pub struct EmitterContext {
  indent_level : Int
  indent_string : String
  newline_at_rules : Bool
  source_map_builder : SourceMapBuilder?  // Optional source map builder
  source_file : String?                    // Source file name for mappings
  mut generated_line : Int                 // Current generated line (0-based)
  mut generated_column : Int               // Current generated column (0-based)
}

///|
/// Create default emitter context (without source maps)
pub fn EmitterContext::default() -> EmitterContext {
  {
    indent_level: 0,
    indent_string: "  ",
    newline_at_rules: true,
    source_map_builder: None,
    source_file: None,
    generated_line: 0,
    generated_column: 0
  }
}

///|
/// Create emitter context with source map support
pub fn EmitterContext::with_source_map(
  builder : SourceMapBuilder,
  source_file : String
) -> EmitterContext {
  {
    indent_level: 0,
    indent_string: "  ",
    newline_at_rules: true,
    source_map_builder: Some(builder),
    source_file: Some(source_file),
    generated_line: 0,
    generated_column: 0
  }
}

///|
/// Increase indentation level
pub fn EmitterContext::indent(self : EmitterContext) -> EmitterContext {
  {
    indent_level: self.indent_level + 1,
    indent_string: self.indent_string,
    newline_at_rules: self.newline_at_rules,
    source_map_builder: self.source_map_builder,
    source_file: self.source_file,
    generated_line: self.generated_line,
    generated_column: self.generated_column
  }
}

///|
/// Get current indentation string
fn EmitterContext::get_indent(self : EmitterContext) -> String {
  let mut result = ""
  for i = 0; i < self.indent_level; i = i + 1 {
    result = result + self.indent_string
  }
  result
}

///|
/// Emit text and track position for source maps
pub fn EmitterContext::emit_text(self : EmitterContext, text : String) -> Unit {
  // Update column position
  self.generated_column = self.generated_column + text.length()
}

///|
/// Emit newline and track position for source maps
pub fn EmitterContext::emit_newline(self : EmitterContext) -> Unit {
  self.generated_line = self.generated_line + 1
  self.generated_column = 0
}

///|
/// Add a source mapping if source map builder is enabled
pub fn EmitterContext::add_mapping(
  self : EmitterContext,
  original_line : Int,
  original_column : Int,
  name : String?
) -> Unit {
  match (self.source_map_builder, self.source_file) {
    (Some(builder), Some(source)) => {
      builder.add_mapping(
        self.generated_line,
        self.generated_column,
        source,
        original_line,
        original_column,
        name
      )
    }
    _ => ()
  }
}

///|
/// Main emit function - converts AST node to JavaScript string
pub fn emit(node : Node, ctx : EmitterContext) -> String {
  match node {
    // Source File
    SourceFile(sf) => emit_source_file(sf, ctx)

    // Statements
    VariableStatement(vs) => emit_variable_statement(vs, ctx)
    FunctionDeclaration(fd) => emit_function_declaration(fd, ctx)
    ClassDeclaration(cd) => emit_class_declaration(cd, ctx)
    InterfaceDeclaration(_) => ""  // Removed by transformer
    TypeAliasDeclaration(_) => ""  // Removed by transformer
    EnumDeclaration(_) => ""  // Transformed to VariableStatement
    ImportDeclaration(id) => emit_import_declaration(id, ctx)
    ExportDeclaration(ed) => emit_export_declaration(ed, ctx)
    ExportAssignment(ea) => emit_export_assignment(ea, ctx)

    // Control Flow Statements
    IfStatement(if_stmt) => emit_if_statement(if_stmt, ctx)
    SwitchStatement(ss) => emit_switch_statement(ss, ctx)
    ForStatement(fs) => emit_for_statement(fs, ctx)
    ForInStatement(fis) => emit_for_in_statement(fis, ctx)
    ForOfStatement(fos) => emit_for_of_statement(fos, ctx)
    WhileStatement(ws) => emit_while_statement(ws, ctx)
    DoWhileStatement(dws) => emit_do_while_statement(dws, ctx)
    BreakStatement(bs) => emit_break_statement(bs, ctx)
    ContinueStatement(cs) => emit_continue_statement(cs, ctx)
    ReturnStatement(rs) => emit_return_statement(rs, ctx)
    ThrowStatement(ts) => emit_throw_statement(ts, ctx)
    TryStatement(try_s) => emit_try_statement(try_s, ctx)

    // Other Statements
    BlockStatement(bs) => emit_block_statement(bs, ctx)
    ExpressionStatement(es) => emit_expression_statement(es, ctx)
    EmptyStatement(_) => ""
    DebuggerStatement(_) => "debugger;"
    LabeledStatement(ls) => emit_labeled_statement(ls, ctx)
    WithStatement(ws) => emit_with_statement(ws, ctx)

    // Expressions
    BinaryExpression(be) => emit_binary_expression(be, ctx)
    UnaryExpression(ue) => emit_unary_expression(ue, ctx)
    ConditionalExpression(ce) => emit_conditional_expression(ce, ctx)
    CallExpression(ce) => emit_call_expression(ce, ctx)
    NewExpression(ne) => emit_new_expression(ne, ctx)
    PropertyAccessExpression(pae) => emit_property_access_expression(pae, ctx)
    ElementAccessExpression(eae) => emit_element_access_expression(eae, ctx)
    ArrowFunction(af) => emit_arrow_function(af, ctx)
    FunctionExpression(fe) => emit_function_expression(fe, ctx)
    ArrayLiteralExpression(ale) => emit_array_literal_expression(ale, ctx)
    ObjectLiteralExpression(ole) => emit_object_literal_expression(ole, ctx)
    ParenthesizedExpression(pe) => emit_parenthesized_expression(pe, ctx)
    TemplateExpression(te) => emit_template_expression(te, ctx)
    AsExpression(ae) => emit(ae.expression, ctx)  // Unwrap type assertion
    TypeAssertionExpression(tae) => emit(tae.expression, ctx)  // Unwrap
    NonNullExpression(nne) => emit(nne.expression, ctx)  // Unwrap
    SatisfiesExpression(se) => emit(se.expression, ctx)  // Unwrap satisfies
    SpreadExpression(se) => emit_spread_expression(se, ctx)
    OptionalChain(oc) => emit_optional_chain(oc, ctx)
    AwaitExpression(ae) => emit_await_expression(ae, ctx)
    YieldExpression(ye) => emit_yield_expression(ye, ctx)

    // Binding Patterns
    ArrayBindingPattern(abp) => emit_array_binding_pattern(abp, ctx)
    ObjectBindingPattern(obp) => emit_object_binding_pattern(obp, ctx)

    // Primary Expressions
    Identifier(id) => {
      // Add mapping for identifier reference
      ctx.add_mapping(id.location.start.line, id.location.start.column, Some(id.name))
      id.name
    }
    NumericLiteral(nl) => nl.value
    BigIntLiteral(bi) => bi.value + "n"
    StringLiteral(sl) => "\"" + escape_string(sl.value) + "\""
    BooleanLiteral(bl) => if bl.value { "true" } else { "false" }
    NullLiteral(_) => "null"
    RegExpLiteral(rl) => rl.pattern
    ThisExpression(_) => "this"
    SuperExpression(_) => "super"

    // Type Nodes (should be removed by transformer)
    TypeReference(_) => ""
    UnionType(_) => ""
    IntersectionType(_) => ""
    FunctionType(_) => ""
    ArrayType(_) => ""
    TupleType(_) => ""
    LiteralType(_) => ""
    KeywordType(_) => ""
    MappedType(_) => ""
    ConditionalType(_) => ""
    IndexedAccessType(_) => ""
    OptionalType(_) => ""
    RestType(_) => ""
    TypePredicate(_) => ""
    TypeOperator(_) => ""
    InferType(_) => ""
    TemplateLiteralType(_) => ""

    // Other
    Parameter(p) => emit_parameter(p, ctx)
    PropertyDeclaration(pd) => emit_property_declaration(pd, ctx)
    IndexSignatureDeclaration(_) => ""  // Type-only, no JS emission
    MethodDeclaration(md) => emit_method_declaration(md, ctx)
    ConstructorDeclaration(cd) => emit_constructor_declaration(cd, ctx)
    GetAccessor(ga) => emit_get_accessor(ga, ctx)
    SetAccessor(sa) => emit_set_accessor(sa, ctx)
    Decorator(_) => ""  // Decorators are handled separately
    ModuleDeclaration(_) => ""  // TODO: Implement if needed

    // JSX - emit as-is (actual JSX transformation typically done by framework-specific transformer)
    JsxElement(_) => ""  // TODO: Implement JSX to JS transformation
    JsxSelfClosingElement(_) => ""  // TODO: Implement JSX to JS transformation
    JsxFragment(_) => ""  // TODO: Implement JSX to JS transformation
    JsxOpeningElement(_) => ""  // TODO: Implement JSX to JS transformation
    JsxClosingElement(_) => ""  // TODO: Implement JSX to JS transformation
    JsxExpression(_) => ""  // TODO: Implement JSX to JS transformation
    JsxText(_) => ""  // TODO: Implement JSX to JS transformation
  }
}

///|
/// Emit source file
fn emit_source_file(sf : SourceFile, ctx : EmitterContext) -> String {
  let mut result = ""
  for i = 0; i < sf.statements.length(); i = i + 1 {
    let stmt_str = emit(sf.statements[i], ctx)
    if stmt_str.length() > 0 {
      result = result + stmt_str
      ctx.emit_text(stmt_str)
      if i < sf.statements.length() - 1 {
        result = result + "\n"
        ctx.emit_newline()
      }
    }
  }
  result
}

///|
/// Emit variable statement
///|
/// Check if modifiers array has Export modifier
fn has_export_modifier(modifiers : Array[Modifier]) -> Bool {
  for modifier in modifiers {
    if modifier == Modifier::Export {
      return true
    }
  }
  false
}

///|
/// Check if modifiers array has Default modifier
fn has_default_modifier(modifiers : Array[Modifier]) -> Bool {
  for modifier in modifiers {
    if modifier == Modifier::Default {
      return true
    }
  }
  false
}

///|
/// Check if modifiers array has Declare modifier
fn has_declare_modifier(modifiers : Array[Modifier]) -> Bool {
  for modifier in modifiers {
    if modifier == Modifier::Declare {
      return true
    }
  }
  false
}

///|
/// Get export prefix based on modifiers (export, export default, or empty)
fn get_export_prefix(modifiers : Array[Modifier]) -> String {
  if has_export_modifier(modifiers) {
    if has_default_modifier(modifiers) {
      "export default "
    } else {
      "export "
    }
  } else {
    ""
  }
}

fn emit_variable_statement(vs : VariableStatement, ctx : EmitterContext) -> String {
  // Skip declare statements - they don't produce JavaScript output
  if has_declare_modifier(vs.modifiers) {
    return ""
  }

  // Add source mapping at the start of the statement
  ctx.add_mapping(vs.location.start.line, vs.location.start.column, None)

  let export_prefix = get_export_prefix(vs.modifiers)

  let keyword = if vs.is_const {
    "const"
  } else if vs.is_let {
    "let"
  } else {
    "var"
  }

  let mut decls = ""
  for i = 0; i < vs.declarations.length(); i = i + 1 {
    let decl = vs.declarations[i]
    let name = match decl.name {
      Identifier(id) => {
        // Add mapping for identifier
        ctx.add_mapping(id.location.start.line, id.location.start.column, Some(id.name))
        id.name
      }
      _ => emit(decl.name, ctx)  // For binding patterns
    }

    decls = decls + name

    match decl.initializer {
      Some(init) => decls = decls + " = " + emit(init, ctx)
      None => ()
    }

    if i < vs.declarations.length() - 1 {
      decls = decls + ", "
    }
  }

  ctx.get_indent() + export_prefix + keyword + " " + decls + ";"
}

///|
/// Emit function declaration
fn emit_function_declaration(fd : FunctionDeclaration, ctx : EmitterContext) -> String {
  // Skip declare statements - they don't produce JavaScript output
  if has_declare_modifier(fd.modifiers) {
    return ""
  }

  // Add source mapping at the start of the function declaration
  ctx.add_mapping(fd.location.start.line, fd.location.start.column, None)

  let mut result = ctx.get_indent()

  result = result + get_export_prefix(fd.modifiers)

  if fd.is_async {
    result = result + "async "
  }

  result = result + "function"

  if fd.is_generator {
    result = result + "*"
  }

  match fd.name {
    Some(Identifier(id)) => {
      // Add mapping for function name
      ctx.add_mapping(id.location.start.line, id.location.start.column, Some(id.name))
      result = result + " " + id.name
    }
    _ => ()
  }

  result = result + "("
  result = result + emit_parameters(fd.parameters, ctx)
  result = result + ")"

  match fd.body {
    Some(body) => {
      result = result + " "
      result = result + emit(body, ctx)    }
    None => result = result + ";"
  }

  result
}

///|
/// Emit parameters
fn emit_parameters(params : Array[Node], ctx : EmitterContext) -> String {
  let mut result = ""
  for i = 0; i < params.length(); i = i + 1 {
    match params[i] {
      Parameter(p) => {
        match p.name {
          Identifier(id) => result = result + id.name
          _ => result = result + emit(p.name, ctx)
        }

        match p.initializer {
          Some(init) => result = result + " = " + emit(init, ctx)
          None => ()
        }
      }
      _ => result = result + emit(params[i], ctx)
    }

    if i < params.length() - 1 {
      result = result + ", "
    }
  }
  result
}

///|
/// Emit parameter
fn emit_parameter(p : Parameter, ctx : EmitterContext) -> String {
  let mut result = match p.name {
    Identifier(id) => id.name
    _ => emit(p.name, ctx)
  }

  match p.initializer {
    Some(init) => result = result + " = " + emit(init, ctx)
    None => ()
  }

  result
}

///|
/// Emit class declaration
fn emit_class_declaration(cd : ClassDeclaration, ctx : EmitterContext) -> String {
  // Skip declare statements - they don't produce JavaScript output
  if has_declare_modifier(cd.modifiers) {
    return ""
  }

  // Add source mapping at the start of the class declaration
  ctx.add_mapping(cd.location.start.line, cd.location.start.column, None)

  let export_prefix = get_export_prefix(cd.modifiers)
  let mut result = ctx.get_indent() + export_prefix + "class "

  match cd.name {
    Some(Identifier(id)) => {
      // Add mapping for class name
      ctx.add_mapping(id.location.start.line, id.location.start.column, Some(id.name))
      result = result + id.name
    }
    _ => ()
  }

  // Emit heritage (extends only, implements removed by transformer)
  for clause in cd.heritage_clauses {
    if clause.kind == Extends {
      result = result + " extends "
      for i = 0; i < clause.types.length(); i = i + 1 {
        result = result + emit(clause.types[i], ctx)
        if i < clause.types.length() - 1 {
          result = result + ", "
        }
      }
    }
  }

  result = result + " {\n"

  let inner_ctx = ctx.indent()
  for class_member in cd.members {
    let member_str = emit(class_member, inner_ctx)
    if member_str.length() > 0 {
      result = result + member_str + "\n"
    }
  }

  result = result + ctx.get_indent() + "}"
  result
}

///|
/// Emit property declaration
fn emit_property_declaration(pd : PropertyDeclaration, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent()

  // Check if Static modifier is present
  let mut is_static = false
  for modifier in pd.modifiers {
    if modifier == Static {
      is_static = true
    }
  }

  if is_static {
    result = result + "static "
  }

  result = result + pd.name

  match pd.initializer {
    Some(init) => result = result + " = " + emit(init, ctx)
    None => ()
  }

  result = result + ";"
  result
}

///|
/// Emit method declaration
fn emit_method_declaration(md : MethodDeclaration, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent()

  // Check if Static modifier is present
  let mut is_static = false
  for modifier in md.modifiers {
    if modifier == Static {
      is_static = true
    }
  }

  if is_static {
    result = result + "static "
  }

  if md.is_async {
    result = result + "async "
  }

  if md.is_generator {
    result = result + "*"
  }

  result = result + md.name

  result = result + "("
  result = result + emit_parameters(md.parameters, ctx)
  result = result + ")"

  match md.body {
    Some(body) => {
      result = result + " "
      result = result + emit(body, ctx)    }
    None => result = result + ";"
  }

  result
}

///|
/// Emit constructor declaration
fn emit_constructor_declaration(cd : ConstructorDeclaration, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent() + "constructor("
  result = result + emit_parameters(cd.parameters, ctx)
  result = result + ")"

  match cd.body {
    Some(body) => {
      result = result + " "
      result = result + emit(body, ctx)    }
    None => result = result + ";"
  }

  result
}

///|
/// Emit get accessor
fn emit_get_accessor(ga : GetAccessor, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent()

  // Check if Static modifier is present
  let mut is_static = false
  for modifier in ga.modifiers {
    if modifier == Static {
      is_static = true
    }
  }

  if is_static {
    result = result + "static "
  }

  result = result + "get "
  result = result + ga.name
  result = result + "()"

  match ga.body {
    Some(body) => {
      result = result + " "
      result = result + emit(body, ctx)    }
    None => result = result + ";"
  }

  result
}

///|
/// Emit set accessor
fn emit_set_accessor(sa : SetAccessor, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent()

  // Check if Static modifier is present
  let mut is_static = false
  for modifier in sa.modifiers {
    if modifier == Static {
      is_static = true
    }
  }

  if is_static {
    result = result + "static "
  }

  result = result + "set "
  result = result + sa.name
  result = result + "("
  result = result + emit(sa.parameter, ctx)
  result = result + ")"

  match sa.body {
    Some(body) => {
      result = result + " "
      result = result + emit(body, ctx)    }
    None => result = result + ";"
  }

  result
}

///|
/// Emit import declaration
fn emit_import_declaration(id : ImportDeclaration, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent() + "import "

  match id.import_clause {
    Some(clause) => {
      let mut has_bindings = false

      // Default import
      match clause.name {
        Some(name) => {
          result = result + name
          has_bindings = true
        }
        None => ()
      }

      // Named bindings (TODO: implement proper named bindings emission)
      match clause.named_bindings {
        Some(_bindings) => {
          if has_bindings {
            result = result + ", "
          }
          result = result + "{ /* named imports */ }"
          has_bindings = true
        }
        None => ()
      }

      if has_bindings {
        result = result + " from "
      }
    }
    None => ()
  }

  result = result + "\"" + id.module_specifier + "\""
  result = result + ";"
  result
}

///|
/// Emit export declaration
fn emit_export_declaration(ed : ExportDeclaration, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent() + "export "

  match ed.export_clause {
    Some(_clause) => result = result + "{ /* named exports */ }"
    None => result = result + "*"
  }

  match ed.module_specifier {
    Some(ms) => result = result + " from \"" + ms + "\""
    None => ()
  }

  result = result + ";"
  result
}

///|
/// Emit export assignment
fn emit_export_assignment(ea : ExportAssignment, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent() + "export "

  if ea.is_export_equals {
    result = result + "= "
  } else {
    result = result + "default "
  }

  result = result + emit(ea.expression, ctx) + ";"
  result
}

///|
/// Emit if statement
fn emit_if_statement(if_stmt : IfStatement, ctx : EmitterContext) -> String {
  // Add source mapping at the start of the if statement
  ctx.add_mapping(if_stmt.location.start.line, if_stmt.location.start.column, None)

  let mut result = ctx.get_indent() + "if ("
  result = result + emit(if_stmt.condition, ctx)
  result = result + ") "

  let then_str = emit(if_stmt.then_statement, ctx)
  result = result + then_str
  match if_stmt.else_statement {
    Some(else_stmt) => {
      result = result + " else "
      let else_str = emit(else_stmt, ctx)
      result = result + else_str    }
    None => ()
  }

  result
}

///|
/// Emit switch statement
fn emit_switch_statement(ss : SwitchStatement, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent() + "switch ("
  result = result + emit(ss.expression, ctx)
  result = result + ") {\n"

  let inner_ctx = ctx.indent()
  for case_clause in ss.cases {
    match case_clause.expression {
      Some(expr) => {
        // Regular case
        result = result + inner_ctx.get_indent() + "case "
        result = result + emit(expr, ctx)
        result = result + ":\n"

        let stmt_ctx = inner_ctx.indent()
        for stmt in case_clause.statements {
          result = result + emit(stmt, stmt_ctx) + "\n"
        }
      }
      None => {
        // Default case
        result = result + inner_ctx.get_indent() + "default:\n"

        let stmt_ctx = inner_ctx.indent()
        for stmt in case_clause.statements {
          result = result + emit(stmt, stmt_ctx) + "\n"
        }
      }
    }
  }

  result = result + ctx.get_indent() + "}"
  result
}

///|
/// Emit for statement
fn emit_for_statement(fs : ForStatement, ctx : EmitterContext) -> String {
  // Add source mapping at the start of the for statement
  ctx.add_mapping(fs.location.start.line, fs.location.start.column, None)

  let mut result = ctx.get_indent() + "for ("

  // Emit initializer (without trailing semicolon if it's a variable statement)
  match fs.initializer {
    Some(VariableStatement(vs)) => {
      let keyword = if vs.is_const {
        "const"
      } else if vs.is_let {
        "let"
      } else {
        "var"
      }

      let mut decls = ""
      for i = 0; i < vs.declarations.length(); i = i + 1 {
        let decl = vs.declarations[i]
        let name = match decl.name {
          Identifier(id) => id.name
          _ => emit(decl.name, ctx)
        }
        decls = decls + name
        match decl.initializer {
          Some(init) => decls = decls + " = " + emit(init, ctx)
          None => ()
        }
        if i < vs.declarations.length() - 1 {
          decls = decls + ", "
        }
      }
      result = result + keyword + " " + decls
    }
    Some(init) => result = result + emit(init, ctx)
    None => ()
  }

  result = result + "; "

  match fs.condition {
    Some(cond) => result = result + emit(cond, ctx)
    None => ()
  }

  result = result + "; "

  match fs.incrementor {
    Some(inc) => result = result + emit(inc, ctx)
    None => ()
  }

  result = result + ") "

  let body_str = emit(fs.statement, ctx)
  result = result + body_str
  result
}

///|
/// Emit for-in statement
fn emit_for_in_statement(fis : ForInStatement, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent() + "for ("

  // Emit variable declaration without semicolon
  match fis.initializer {
    VariableStatement(vs) => {
      let keyword = if vs.is_const {
        "const"
      } else if vs.is_let {
        "let"
      } else {
        "var"
      }
      let decl = vs.declarations[0]
      let name = match decl.name {
        Identifier(id) => id.name
        _ => emit(decl.name, ctx)
      }
      result = result + keyword + " " + name
    }
    _ => result = result + emit(fis.initializer, ctx)
  }

  result = result + " in "
  result = result + emit(fis.expression, ctx)
  result = result + ") "

  let body_str = emit(fis.statement, ctx)
  result = result + body_str

  result
}

///|
/// Emit for-of statement
fn emit_for_of_statement(fos : ForOfStatement, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent() + "for ("

  // Emit variable declaration without semicolon
  match fos.initializer {
    VariableStatement(vs) => {
      let keyword = if vs.is_const {
        "const"
      } else if vs.is_let {
        "let"
      } else {
        "var"
      }
      let decl = vs.declarations[0]
      let name = match decl.name {
        Identifier(id) => id.name
        _ => emit(decl.name, ctx)
      }
      result = result + keyword + " " + name
    }
    _ => result = result + emit(fos.initializer, ctx)
  }

  result = result + " of "
  result = result + emit(fos.expression, ctx)
  result = result + ") "

  let body_str = emit(fos.statement, ctx)
  result = result + body_str
  result
}

///|
/// Emit while statement
fn emit_while_statement(ws : WhileStatement, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent() + "while ("
  result = result + emit(ws.condition, ctx)
  result = result + ") "

  let body_str = emit(ws.statement, ctx)
  result = result + body_str
  result
}

///|
/// Emit do-while statement
fn emit_do_while_statement(dws : DoWhileStatement, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent() + "do "

  let body_str = emit(dws.statement, ctx)
  result = result + body_str
  result = result + " while ("
  result = result + emit(dws.condition, ctx)
  result = result + ");"

  result
}

///|
/// Emit break statement
fn emit_break_statement(bs : BreakStatement, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent() + "break"

  match bs.label {
    Some(label) => result = result + " " + label
    None => ()
  }

  result = result + ";"
  result
}

///|
/// Emit continue statement
fn emit_continue_statement(cs : ContinueStatement, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent() + "continue"

  match cs.label {
    Some(label) => result = result + " " + label
    None => ()
  }

  result = result + ";"
  result
}

///|
/// Emit return statement
fn emit_return_statement(rs : ReturnStatement, ctx : EmitterContext) -> String {
  // Add source mapping at the start of the return statement
  ctx.add_mapping(rs.location.start.line, rs.location.start.column, None)

  let mut result = ctx.get_indent() + "return"

  match rs.expression {
    Some(expr) => result = result + " " + emit(expr, ctx)
    None => ()
  }

  result = result + ";"
  result
}

///|
/// Emit throw statement
fn emit_throw_statement(ts : ThrowStatement, ctx : EmitterContext) -> String {
  ctx.get_indent() + "throw " + emit(ts.expression, ctx) + ";"
}

///|
/// Emit try statement
fn emit_try_statement(ts : TryStatement, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent() + "try "
  result = result + emit(ts.try_block, ctx)
  match ts.catch_clause {
    Some(catch_clause) => {
      result = result + " catch"

      match catch_clause.variable_declaration {
        Some(vd) => result = result + " (" + emit(vd, ctx) + ")"
        None => ()
      }

      result = result + " "
      result = result + emit(catch_clause.block, ctx)
    }
    None => ()
  }

  match ts.finally_block {
    Some(finally_block) => {
      result = result + " finally "
      result = result + emit(finally_block, ctx)
    }
    None => ()
  }

  result
}

///|
/// Emit block statement
fn emit_block_statement(bs : BlockStatement, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent() + "{\n"

  let inner_ctx = ctx.indent()
  for stmt in bs.statements {
    let stmt_str = emit(stmt, inner_ctx)
    if stmt_str.length() > 0 {
      result = result + stmt_str + "\n"
    }
  }

  result = result + ctx.get_indent() + "}"
  result
}

///|
/// Emit expression statement
fn emit_expression_statement(es : ExpressionStatement, ctx : EmitterContext) -> String {
  ctx.get_indent() + emit(es.expression, ctx) + ";"
}

///|
/// Emit labeled statement
fn emit_labeled_statement(ls : LabeledStatement, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent()
  result = result + ls.label
  result = result + ": "
  result = result + emit(ls.statement, ctx)
  result
}

///|
/// Emit with statement
fn emit_with_statement(ws : WithStatement, ctx : EmitterContext) -> String {
  let mut result = ctx.get_indent() + "with ("
  result = result + emit(ws.expression, ctx)
  result = result + ") "

  let body_str = emit(ws.statement, ctx)
  result = result + body_str
  result
}

///|
/// Emit binary expression
fn emit_binary_expression(be : BinaryExpression, ctx : EmitterContext) -> String {
  let left = emit(be.left, ctx)
  let right = emit(be.right, ctx)
  let op = operator_to_string(be.operator)
  left + " " + op + " " + right
}

///|
/// Emit unary expression
fn emit_unary_expression(ue : UnaryExpression, ctx : EmitterContext) -> String {
  let operand = emit(ue.operand, ctx)
  let op = unary_operator_to_string(ue.operator)

  if ue.is_prefix {
    op + operand
  } else {
    operand + op
  }
}

///|
/// Emit conditional expression
fn emit_conditional_expression(ce : ConditionalExpression, ctx : EmitterContext) -> String {
  let cond = emit(ce.condition, ctx)
  let when_true = emit(ce.when_true, ctx)
  let when_false = emit(ce.when_false, ctx)
  cond + " ? " + when_true + " : " + when_false
}

///|
/// Emit call expression
fn emit_call_expression(ce : CallExpression, ctx : EmitterContext) -> String {
  // Add source mapping at the start of the call expression
  ctx.add_mapping(ce.location.start.line, ce.location.start.column, None)

  let mut result = emit(ce.expression, ctx)
  result = result + "("

  for i = 0; i < ce.arguments.length(); i = i + 1 {
    result = result + emit(ce.arguments[i], ctx)
    if i < ce.arguments.length() - 1 {
      result = result + ", "
    }
  }

  result = result + ")"
  result
}

///|
/// Emit new expression
fn emit_new_expression(ne : NewExpression, ctx : EmitterContext) -> String {
  let mut result = "new " + emit(ne.expression, ctx)

  match ne.arguments {
    Some(args) => {
      result = result + "("
      for i = 0; i < args.length(); i = i + 1 {
        result = result + emit(args[i], ctx)
        if i < args.length() - 1 {
          result = result + ", "
        }
      }
      result = result + ")"
    }
    None => ()
  }

  result
}

///|
/// Emit property access expression
fn emit_property_access_expression(pae : PropertyAccessExpression, ctx : EmitterContext) -> String {
  // Add source mapping at the property access
  ctx.add_mapping(pae.location.start.line, pae.location.start.column, Some(pae.name))
  emit(pae.expression, ctx) + "." + pae.name
}

///|
/// Emit element access expression
fn emit_element_access_expression(eae : ElementAccessExpression, ctx : EmitterContext) -> String {
  emit(eae.expression, ctx) + "[" + emit(eae.argument_expression, ctx) + "]"
}

///|
/// Emit arrow function
fn emit_arrow_function(af : ArrowFunction, ctx : EmitterContext) -> String {
  let mut result = "("
  result = result + emit_parameters(af.parameters, ctx)
  result = result + ") => "

  match af.body {
    BlockStatement(_) => result = result + emit(af.body, ctx)
    _ => result = result + emit(af.body, ctx)
  }

  result
}

///|
/// Emit function expression
fn emit_function_expression(fe : FunctionExpression, ctx : EmitterContext) -> String {
  let mut result = ""

  if fe.is_async {
    result = result + "async "
  }

  result = result + "function"

  if fe.is_generator {
    result = result + "*"
  }

  match fe.name {
    Some(name) => result = result + " " + name
    None => ()
  }

  result = result + "("
  result = result + emit_parameters(fe.parameters, ctx)
  result = result + ") "

  result = result + emit(fe.body, ctx)
  result
}

///|
/// Emit array literal expression
fn emit_array_literal_expression(ale : ArrayLiteralExpression, ctx : EmitterContext) -> String {
  let mut result = "["

  for i = 0; i < ale.elements.length(); i = i + 1 {
    match ale.elements[i] {
      Some(elem) => result = result + emit(elem, ctx)
      None => ()  // Array hole
    }
    if i < ale.elements.length() - 1 {
      result = result + ", "
    }
  }

  result = result + "]"
  result
}

///|
/// Emit object literal expression
fn emit_object_literal_expression(ole : ObjectLiteralExpression, ctx : EmitterContext) -> String {
  if ole.properties.length() == 0 {
    return "{}"
  }

  let mut result = "{ "

  for i = 0; i < ole.properties.length(); i = i + 1 {
    match ole.properties[i] {
      PropertyAssignment(name, value, _) => {
        result = result + name + ": " + emit(value, ctx)
      }
      ShorthandProperty(name, _) => {
        result = result + name
      }
      SpreadAssignment(expr, _) => {
        result = result + "..." + emit(expr, ctx)
      }
      MethodDeclaration(name, func_expr, _) => {
        result = result + name + emit_function_expression(func_expr, ctx)
      }
      GetAccessor(name, func_expr, _) => {
        result = result + "get " + name + emit_function_expression(func_expr, ctx)
      }
      SetAccessor(name, func_expr, _) => {
        result = result + "set " + name + emit_function_expression(func_expr, ctx)
      }
      ComputedPropertyAssignment(name_expr, value, _) => {
        result = result + "[" + emit(name_expr, ctx) + "]: " + emit(value, ctx)
      }
    }

    if i < ole.properties.length() - 1 {
      result = result + ", "
    }
  }

  result = result + " }"
  result
}

///|
/// Emit parenthesized expression
fn emit_parenthesized_expression(pe : ParenthesizedExpression, ctx : EmitterContext) -> String {
  "(" + emit(pe.expression, ctx) + ")"
}

///|
/// Emit template expression
fn emit_template_expression(te : TemplateExpression, ctx : EmitterContext) -> String {
  let mut result = "`" + te.head

  // Build ${ as separate strings to avoid MoonBit->JS compilation issues
  let dollar = "$"
  let open_brace = "{"
  let close_brace = "}"
  for span in te.template_spans {
    result = result + dollar + open_brace
    result = result + emit(span.expression, ctx)
    result = result + close_brace
    result = result + span.literal
  }

  result = result + "`"
  result
}

///|
/// Emit spread expression
fn emit_spread_expression(se : SpreadExpression, ctx : EmitterContext) -> String {
  "..." + emit(se.expression, ctx)
}

///|
/// Emit optional chain expression
fn emit_optional_chain(oc : OptionalChain, ctx : EmitterContext) -> String {
  let base = emit(oc.expression, ctx)
  match oc.chain {
    OptionalChainKind::Property(prop) => base + "?." + prop
    OptionalChainKind::Call(args) => {
      let mut result = base + "?.("
      for i = 0; i < args.length(); i = i + 1 {
        result = result + emit(args[i], ctx)
        if i < args.length() - 1 {
          result = result + ", "
        }
      }
      result + ")"
    }
    OptionalChainKind::Element(index) => base + "?.[" + emit(index, ctx) + "]"
  }
}

///|
/// Emit await expression
fn emit_await_expression(ae : AwaitExpression, ctx : EmitterContext) -> String {
  "await " + emit(ae.expression, ctx)
}

///|
/// Emit yield expression
fn emit_yield_expression(ye : YieldExpression, ctx : EmitterContext) -> String {
  let yield_kw = if ye.is_delegate { "yield*" } else { "yield" }
  match ye.expression {
    Some(expr) => yield_kw + " " + emit(expr, ctx)
    None => yield_kw
  }
}

///|
/// Emit array binding pattern
fn emit_array_binding_pattern(abp : ArrayBindingPattern, ctx : EmitterContext) -> String {
  let mut result = "["

  for i = 0; i < abp.elements.length(); i = i + 1 {
    match abp.elements[i] {
      Some(elem) => result = result + emit(elem, ctx)
      None => ()  // Array hole
    }
    if i < abp.elements.length() - 1 {
      result = result + ", "
    }
  }

  result = result + "]"
  result
}

///|
/// Emit object binding pattern
fn emit_object_binding_pattern(obp : ObjectBindingPattern, ctx : EmitterContext) -> String {
  let mut result = "{ "

  for i = 0; i < obp.properties.length(); i = i + 1 {
    let prop = obp.properties[i]
    result = result + prop.property_name + ": " + emit(prop.name, ctx)
    if i < obp.properties.length() - 1 {
      result = result + ", "
    }
  }

  result = result + " }"
  result
}

///|
/// Convert binary operator to string
fn operator_to_string(op : BinaryOperator) -> String {
  match op {
    Add => "+"
    Subtract => "-"
    Multiply => "*"
    Divide => "/"
    Remainder => "%"
    Exponentiate => "**"
    BitwiseAnd => "&"
    BitwiseOr => "|"
    BitwiseXor => "^"
    LeftShift => "<<"
    RightShift => ">>"
    UnsignedRightShift => ">>>"
    LogicalAnd => "&&"
    LogicalOr => "||"
    NullishCoalescing => "??"
    Equals => "=="
    NotEquals => "!="
    StrictEquals => "==="
    StrictNotEquals => "!=="
    LessThan => "<"
    LessThanEquals => "<="
    GreaterThan => ">"
    GreaterThanEquals => ">="
    In => "in"
    InstanceOf => "instanceof"
    Assign => "="
    AddAssign => "+="
    SubtractAssign => "-="
    MultiplyAssign => "*="
    DivideAssign => "/="
    RemainderAssign => "%="
    BitwiseAndAssign => "&="
    BitwiseOrAssign => "|="
    BitwiseXorAssign => "^="
    ExponentiateAssign => "**="
    LeftShiftAssign => "<<="
    RightShiftAssign => ">>="
    UnsignedRightShiftAssign => ">>>="
    LogicalAndAssign => "&&="
    LogicalOrAssign => "||="
    NullishCoalescingAssign => "??="
    Comma => ","
  }
}

///|
/// Convert unary operator to string
fn unary_operator_to_string(op : UnaryOperator) -> String {
  match op {
    Plus => "+"
    Minus => "-"
    BitwiseNot => "~"
    LogicalNot => "!"
    TypeOf => "typeof "
    Void => "void "
    Delete => "delete "
    Increment => "++"
    Decrement => "--"
  }
}

///|
/// Escape string for JavaScript string literal
fn escape_string(s : String) -> String {
  // Re-escape special characters for JavaScript output
  s
    .replace(old="\\", new="\\\\")
    .replace(old="\"", new="\\\"")
    .replace(old="\n", new="\\n")
    .replace(old="\r", new="\\r")
    .replace(old="\t", new="\\t")
}
