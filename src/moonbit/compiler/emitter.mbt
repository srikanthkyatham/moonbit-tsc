// JavaScript Code Emitter
// Converts transformed AST to JavaScript source code

///|
/// Emitter context for controlling output format and source map generation
pub struct EmitterContext {
  indent_level : Int
  indent_string : String
  newline_at_rules : Bool
  source_map_builder : SourceMapBuilder? // Optional source map builder
  source_file : String? // Source file name for mappings
  mut generated_line : Int // Current generated line (0-based)
  mut generated_column : Int // Current generated column (0-based)
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
    generated_column: 0,
  }
}

///|
/// Create emitter context with source map support
pub fn EmitterContext::with_source_map(
  builder : SourceMapBuilder,
  source_file : String,
) -> EmitterContext {
  {
    indent_level: 0,
    indent_string: "  ",
    newline_at_rules: true,
    source_map_builder: Some(builder),
    source_file: Some(source_file),
    generated_line: 0,
    generated_column: 0,
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
    generated_column: self.generated_column,
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
  name : String?,
) -> Unit {
  match (self.source_map_builder, self.source_file) {
    (Some(builder), Some(source)) =>
      builder.add_mapping(
        self.generated_line,
        self.generated_column,
        source,
        original_line,
        original_column,
        name,
      )
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
    InterfaceDeclaration(_) => "" // Removed by transformer
    TypeAliasDeclaration(_) => "" // Removed by transformer
    EnumDeclaration(_) => "" // Transformed to VariableStatement
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
    AsExpression(ae) => emit(ae.expression, ctx) // Unwrap type assertion
    TypeAssertionExpression(tae) => emit(tae.expression, ctx) // Unwrap
    NonNullExpression(nne) => emit(nne.expression, ctx) // Unwrap
    SatisfiesExpression(se) => emit(se.expression, ctx) // Unwrap satisfies
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
      ctx.add_mapping(
        id.location.start.line,
        id.location.start.column,
        Some(id.name),
      )
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
    IndexSignatureDeclaration(_) => "" // Type-only, no JS emission
    MethodDeclaration(md) => emit_method_declaration(md, ctx)
    ConstructorDeclaration(cd) => emit_constructor_declaration(cd, ctx)
    GetAccessor(ga) => emit_get_accessor(ga, ctx)
    SetAccessor(sa) => emit_set_accessor(sa, ctx)
    Decorator(_) => "" // Decorators are handled separately
    ModuleDeclaration(md) => emit_module_declaration(md, ctx)

    // JSX - transform to React.createElement calls
    JsxElement(je) => emit_jsx_element(je, ctx)
    JsxSelfClosingElement(jsce) => emit_jsx_self_closing_element(jsce, ctx)
    JsxFragment(jf) => emit_jsx_fragment(jf, ctx)
    JsxOpeningElement(joe) => emit_jsx_opening_element(joe, ctx)
    JsxClosingElement(_) => "" // Closing elements are handled by JsxElement
    JsxExpression(je) => emit_jsx_expression(je, ctx)

    // JSDoc - preserved as comments or stripped
    JSDocComment(jsdoc) => emit_jsdoc_comment(jsdoc)
  }
}

///|
/// Public function to compile a parsed SourceFile to JavaScript
/// This function transforms and emits the source file with helper functions
pub fn compile_source_file(
  sf : SourceFile,
  ctx : TransformerContext,
  emit_ctx : EmitterContext,
) -> String {
  // Create SourceFile node
  let sf_node : Node = SourceFile({
    file_path: sf.file_path,
    statements: sf.statements,
    end_of_file_token: sf.end_of_file_token,
    has_no_default_lib: sf.has_no_default_lib,
  })
  // Transform and emit
  let transformed = transform(sf_node, ctx)
  emit(transformed, emit_ctx)
}

///|
/// Emit source file
fn emit_source_file(sf : SourceFile, ctx : EmitterContext) -> String {
  let mut result = ""

  // Emit helper functions if decorators are used
  let uses_decorators = source_file_uses_decorators(sf)
  let uses_param_decorators = source_file_uses_param_decorators(sf)

  if uses_decorators {
    result = result + get_decorate_helper() + "\n"
    ctx.emit_newline()
    if uses_param_decorators {
      result = result + get_param_helper() + "\n"
      ctx.emit_newline()
    }
    // Emit metadata helper for design-time type information
    result = result + get_metadata_helper() + "\n"
    ctx.emit_newline()
  }

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

///|
fn emit_variable_statement(
  vs : VariableStatement,
  ctx : EmitterContext,
) -> String {
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
        ctx.add_mapping(
          id.location.start.line,
          id.location.start.column,
          Some(id.name),
        )
        id.name
      }
      _ => emit(decl.name, ctx) // For binding patterns
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
fn emit_function_declaration(
  fd : FunctionDeclaration,
  ctx : EmitterContext,
) -> String {
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
      ctx.add_mapping(
        id.location.start.line,
        id.location.start.column,
        Some(id.name),
      )
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
      result = result + emit(body, ctx)
    }
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
/// Emit a single decorator expression
fn emit_decorator_expression(decorator : Node, ctx : EmitterContext) -> String {
  match decorator {
    Decorator(d) => emit(d.expression, ctx)
    _ => ""
  }
}

///|
/// Check if a class has any decorators
fn has_decorators(decorators : Array[Node]) -> Bool {
  decorators.length() > 0
}

///|
/// Get the __decorate helper function definition
fn get_decorate_helper() -> String {
  "var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {\n" +
    "    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;\n" +
    "    if (typeof Reflect === \"object\" && typeof Reflect.decorate === \"function\") r = Reflect.decorate(decorators, target, key, desc);\n" +
    "    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;\n" +
    "    return c > 3 && r && Object.defineProperty(target, key, r), r;\n" +
    "};"
}

///|
/// Get the __param helper function definition
fn get_param_helper() -> String {
  "var __param = (this && this.__param) || function (paramIndex, decorator) {\n" +
    "    return function (target, key) { decorator(target, key, paramIndex); }\n" +
    "};"
}

///|
/// Get the __metadata helper function definition
fn get_metadata_helper() -> String {
  "var __metadata = (this && this.__metadata) || function (k, v) {\n" +
    "    if (typeof Reflect === \"object\" && typeof Reflect.metadata === \"function\") return Reflect.metadata(k, v);\n" +
    "};"
}

///|
/// Convert a TypeScript type node to its runtime representation
/// e.g., string -> String, number -> Number, etc.
fn type_to_runtime(type_node : Node?) -> String {
  match type_node {
    None => "Object"
    Some(node) =>
      match node {
        // Type reference with type_name string
        TypeReference(tr) =>
          match tr.type_name {
            "string" => "String"
            "number" => "Number"
            "boolean" => "Boolean"
            "symbol" => "Symbol"
            "bigint" => "BigInt"
            "void" => "void 0"
            "undefined" => "void 0"
            "null" => "void 0"
            "never" => "void 0"
            "any" => "Object"
            "unknown" => "Object"
            "object" => "Object"
            // For class types, use the class name
            name => name
          }
        // Array types
        ArrayType(_) => "Array"
        // Tuple types
        TupleType(_) => "Array"
        // Function types
        FunctionType(_) => "Function"
        // Union and intersection types serialize as Object
        UnionType(_) => "Object"
        IntersectionType(_) => "Object"
        // Literal types
        LiteralType(lt) =>
          match lt.literal {
            StringLiteral(_) => "String"
            NumericLiteral(_) => "Number"
            BooleanLiteral(_) => "Boolean"
            _ => "Object"
          }
        // Keywords that might appear as type nodes
        Identifier(id) =>
          match id.name {
            "string" => "String"
            "number" => "Number"
            "boolean" => "Boolean"
            "symbol" => "Symbol"
            "bigint" => "BigInt"
            "void" => "void 0"
            "undefined" => "void 0"
            "null" => "void 0"
            "never" => "void 0"
            "any" => "Object"
            "unknown" => "Object"
            "object" => "Object"
            name => name
          }
        // Default to Object for complex types
        _ => "Object"
      }
  }
}

///|
/// Get parameter types as runtime values for design:paramtypes
fn get_param_types_runtime(params : Array[Node]) -> String {
  if params.length() == 0 {
    return "[]"
  }
  let mut result = "["
  for i = 0; i < params.length(); i = i + 1 {
    match params[i] {
      Parameter(p) => {
        result = result + type_to_runtime(p.type_annotation)
      }
      _ => {
        result = result + "Object"
      }
    }
    if i < params.length() - 1 {
      result = result + ", "
    }
  }
  result + "]"
}

///|
/// Check if a class uses any decorators (class, member, or parameter)
fn class_uses_decorators(cd : ClassDeclaration) -> Bool {
  // Check class decorators
  if cd.decorators.length() > 0 {
    return true
  }
  // Check member decorators and parameter decorators
  for member in cd.members {
    if get_member_decorators(member).length() > 0 {
      return true
    }
    if has_parameter_decorators(member) {
      return true
    }
  }
  false
}

///|
/// Check if a source file uses any decorators
fn source_file_uses_decorators(sf : SourceFile) -> Bool {
  for stmt in sf.statements {
    match stmt {
      ClassDeclaration(cd) =>
        if class_uses_decorators(cd) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
/// Check if a source file uses parameter decorators
fn source_file_uses_param_decorators(sf : SourceFile) -> Bool {
  for stmt in sf.statements {
    match stmt {
      ClassDeclaration(cd) =>
        for member in cd.members {
          if has_parameter_decorators(member) {
            return true
          }
        }
      _ => ()
    }
  }
  false
}

///|
/// Get the name of a class member for decorator emission
fn get_member_name(member : Node) -> String? {
  match member {
    MethodDeclaration(md) => Some(md.name)
    PropertyDeclaration(pd) => Some(pd.name)
    GetAccessor(ga) => Some(ga.name)
    SetAccessor(sa) => Some(sa.name)
    _ => None
  }
}

///|
/// Get the design:type for a class member
/// Methods and accessors are Function, properties use their type annotation
fn get_member_design_type(member : Node) -> String {
  match member {
    MethodDeclaration(_) => "Function"
    GetAccessor(_) => "Function"
    SetAccessor(_) => "Function"
    PropertyDeclaration(pd) => type_to_runtime(pd.type_annotation)
    _ => "Object"
  }
}

///|
/// Get the return type for a class member (for design:returntype)
fn get_member_return_type(member : Node) -> String {
  match member {
    MethodDeclaration(md) => type_to_runtime(md.return_type)
    GetAccessor(ga) => type_to_runtime(ga.return_type)
    SetAccessor(_) => "void 0" // Setters return void
    PropertyDeclaration(_) => "void 0" // Properties don't have return type
    _ => "void 0"
  }
}

///|
/// Get decorators from a class member
fn get_member_decorators(member : Node) -> Array[Node] {
  match member {
    MethodDeclaration(md) => md.decorators
    PropertyDeclaration(pd) => pd.decorators
    GetAccessor(ga) => ga.decorators
    SetAccessor(sa) => sa.decorators
    ConstructorDeclaration(cd) => cd.decorators
    _ => []
  }
}

///|
/// Get parameters from a class member
fn get_member_parameters(member : Node) -> Array[Node] {
  match member {
    MethodDeclaration(md) => md.parameters
    ConstructorDeclaration(cd) => cd.parameters
    SetAccessor(sa) => [sa.parameter]
    _ => []
  }
}

///|
/// Check if a member has any parameter decorators
fn has_parameter_decorators(member : Node) -> Bool {
  let params = get_member_parameters(member)
  for param in params {
    match param {
      Parameter(p) =>
        if p.decorators.length() > 0 {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
/// Check if a member is static
fn is_static_member(member : Node) -> Bool {
  match member {
    MethodDeclaration(md) =>
      md.modifiers.iter().any(fn(m) { m == Modifier::Static })
    PropertyDeclaration(pd) =>
      pd.modifiers.iter().any(fn(m) { m == Modifier::Static })
    GetAccessor(ga) =>
      ga.modifiers.iter().any(fn(m) { m == Modifier::Static })
    SetAccessor(sa) =>
      sa.modifiers.iter().any(fn(m) { m == Modifier::Static })
    _ => false
  }
}

///|
/// Emit class declaration
fn emit_class_declaration(
  cd : ClassDeclaration,
  ctx : EmitterContext,
) -> String {
  // Skip declare statements - they don't produce JavaScript output
  if has_declare_modifier(cd.modifiers) {
    return ""
  }

  let class_name = match cd.name {
    Some(Identifier(id)) => id.name
    _ => ""
  }
  let has_class_decorators = has_decorators(cd.decorators)
  let export_prefix = get_export_prefix(cd.modifiers)

  // Add source mapping at the start of the class declaration
  ctx.add_mapping(cd.location.start.line, cd.location.start.column, None)

  let mut result = ctx.get_indent()

  // If class has decorators, use let ClassName = class ClassName {...} pattern
  if has_class_decorators && class_name.length() > 0 {
    result = result + export_prefix + "let " + class_name + " = class " + class_name
  } else {
    result = result + export_prefix + "class "
    match cd.name {
      Some(Identifier(id)) => {
        // Add mapping for class name
        ctx.add_mapping(
          id.location.start.line,
          id.location.start.column,
          Some(id.name),
        )
        result = result + id.name
      }
      _ => ()
    }
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

  // Check for constructor parameter decorators
  let mut has_ctor_param_decorators = false
  for class_member in cd.members {
    match class_member {
      ConstructorDeclaration(_) =>
        if has_parameter_decorators(class_member) {
          has_ctor_param_decorators = true
          break
        }
      _ => ()
    }
  }

  // If class has decorators or constructor param decorators, emit decorator application
  if (has_class_decorators || has_ctor_param_decorators) && class_name.length() > 0 {
    result = result + ";\n"
    result = result + ctx.get_indent() + class_name + " = __decorate([\n"
    let decorator_ctx = ctx.indent()

    // Emit class decorators
    for i = 0; i < cd.decorators.length(); i = i + 1 {
      result = result +
        decorator_ctx.get_indent() +
        emit_decorator_expression(cd.decorators[i], ctx)
      if i < cd.decorators.length() - 1 || has_ctor_param_decorators {
        result = result + ","
      }
      result = result + "\n"
    }

    // Emit constructor parameter decorators and metadata
    let mut ctor_params : Array[Node] = []
    for class_member in cd.members {
      match class_member {
        ConstructorDeclaration(ctor) => {
          ctor_params = ctor.parameters
          let params = ctor.parameters
          let mut param_decorator_emitted = false
          for param_index = 0; param_index < params.length(); param_index = param_index +
            1 {
            match params[param_index] {
              Parameter(p) =>
                for dec_index = 0; dec_index < p.decorators.length(); dec_index = dec_index +
                  1 {
                  if param_decorator_emitted {
                    result = result + ",\n"
                  }
                  result = result +
                    decorator_ctx.get_indent() +
                    "__param(" +
                    param_index.to_string() +
                    ", " +
                    emit_decorator_expression(p.decorators[dec_index], ctx) +
                    ")"
                  param_decorator_emitted = true
                }
              _ => ()
            }
          }
          if param_decorator_emitted {
            result = result + ","
          }
        }
        _ => ()
      }
    }

    // Emit design:paramtypes metadata for constructor parameters
    result = result + "\n" +
      decorator_ctx.get_indent() +
      "__metadata(\"design:paramtypes\", " +
      get_param_types_runtime(ctor_params) +
      ")\n"

    result = result + ctx.get_indent() + "], " + class_name + ")"
  }

  // Emit member decorators and parameter decorators
  for class_member in cd.members {
    let member_decorators = get_member_decorators(class_member)
    let has_param_decorators = has_parameter_decorators(class_member)

    // Only emit if we have member decorators or parameter decorators
    if member_decorators.length() > 0 || has_param_decorators {
      match get_member_name(class_member) {
        Some(member_name) => {
          let target = if is_static_member(class_member) {
            class_name
          } else {
            class_name + ".prototype"
          }
          result = result + ";\n"
          result = result + ctx.get_indent() + "__decorate([\n"
          let decorator_ctx = ctx.indent()

          // First emit member decorators
          let mut decorator_index = 0
          for i = 0; i < member_decorators.length(); i = i + 1 {
            result = result +
              decorator_ctx.get_indent() +
              emit_decorator_expression(member_decorators[i], ctx)
            decorator_index = decorator_index + 1
            // Always add comma since we have more items (param decorators or metadata)
            result = result + ","
            result = result + "\n"
          }

          // Then emit parameter decorators with __param
          let params = get_member_parameters(class_member)
          let mut param_decorator_emitted = false
          for param_index = 0; param_index < params.length(); param_index = param_index +
            1 {
            match params[param_index] {
              Parameter(p) =>
                for dec_index = 0; dec_index < p.decorators.length(); dec_index = dec_index +
                  1 {
                  if param_decorator_emitted {
                    result = result + ",\n"
                  }
                  result = result +
                    decorator_ctx.get_indent() +
                    "__param(" +
                    param_index.to_string() +
                    ", " +
                    emit_decorator_expression(p.decorators[dec_index], ctx) +
                    ")"
                  param_decorator_emitted = true
                }
              _ => ()
            }
          }
          if param_decorator_emitted {
            result = result + ","
          }

          // Emit design-time type metadata
          // design:type - the type of the member
          let design_type = get_member_design_type(class_member)
          result = result + "\n" +
            decorator_ctx.get_indent() +
            "__metadata(\"design:type\", " +
            design_type +
            ")"

          // design:paramtypes - for methods/accessors with parameters
          match class_member {
            MethodDeclaration(md) => {
              result = result + ",\n" +
                decorator_ctx.get_indent() +
                "__metadata(\"design:paramtypes\", " +
                get_param_types_runtime(md.parameters) +
                ")"
            }
            SetAccessor(sa) => {
              result = result + ",\n" +
                decorator_ctx.get_indent() +
                "__metadata(\"design:paramtypes\", " +
                get_param_types_runtime([sa.parameter]) +
                ")"
            }
            _ => ()
          }

          // design:returntype - for methods and getters
          match class_member {
            MethodDeclaration(_) | GetAccessor(_) => {
              let return_type = get_member_return_type(class_member)
              result = result + ",\n" +
                decorator_ctx.get_indent() +
                "__metadata(\"design:returntype\", " +
                return_type +
                ")"
            }
            _ => ()
          }

          result = result + "\n"

          result = result +
            ctx.get_indent() +
            "], " +
            target +
            ", \"" +
            member_name +
            "\", null)"
        }
        None => ()
      }
    }
  }

  result
}

///|
/// Emit module declaration (namespace)
/// TypeScript modules/namespaces compile to IIFEs:
/// module Foo { export const x = 1; }
/// -> var Foo; (function(Foo) { Foo.x = 1; })(Foo || (Foo = {}));
fn emit_module_declaration(
  md : ModuleDeclaration,
  ctx : EmitterContext,
) -> String {
  let name = md.name
  let mut result = ctx.get_indent()

  // Declare the variable if it doesn't exist
  result = result + "var " + name + ";\n"

  // Start the IIFE
  result = result + ctx.get_indent() + "(function (" + name + ") {\n"

  // Emit the body
  match md.body {
    Some(body) => {
      let inner_ctx = ctx.indent()
      match body {
        BlockStatement(bs) =>
          for stmt in bs.statements {
            let stmt_str = emit_module_member(stmt, name, inner_ctx)
            if stmt_str.length() > 0 {
              result = result + stmt_str + "\n"
            }
          }
        ModuleDeclaration(nested) =>
          // Nested module declaration
          result = result + emit_module_declaration(nested, inner_ctx) + "\n"
        _ => result = result + emit(body, inner_ctx) + "\n"
      }
    }
    None => ()
  }

  // Close the IIFE
  result = result +
    ctx.get_indent() +
    "})(" +
    name +
    " || (" +
    name +
    " = {}));"
  result
}

///|
/// Emit module member with namespace prefix for exports
fn emit_module_member(
  node : Node,
  ns_name : String,
  ctx : EmitterContext,
) -> String {
  match node {
    VariableStatement(vs) =>
      if has_export_modifier(vs.modifiers) {
        // Exported variable: add to namespace
        let mut result = ""
        for decl in vs.declarations {
          let decl_name = match decl.name {
            Identifier(id) => id.name
            _ => emit(decl.name, ctx)
          }
          result = result + ctx.get_indent() + ns_name + "." + decl_name
          match decl.initializer {
            Some(init) => result = result + " = " + emit(init, ctx)
            None => ()
          }
          result = result + ";\n"
        }
        result
      } else {
        emit_variable_statement(vs, ctx)
      }
    FunctionDeclaration(fd) =>
      if has_export_modifier(fd.modifiers) {
        // Exported function: assign to namespace
        let func_name = match fd.name {
          Some(Identifier(id)) => id.name
          _ => ""
        }
        let mut result = ctx.get_indent() + ns_name + "." + func_name + " = "
        result = result + "function"
        if fd.is_generator {
          result = result + "*"
        }
        result = result + "("
        result = result + emit_parameters(fd.parameters, ctx)
        result = result + ")"
        match fd.body {
          Some(body) => {
            result = result + " "
            result = result + emit(body, ctx)
          }
          None => result = result + ";"
        }
        result
      } else {
        emit_function_declaration(fd, ctx)
      }
    ClassDeclaration(cd) =>
      if has_export_modifier(cd.modifiers) {
        // Exported class: assign to namespace
        let class_name = match cd.name {
          Some(Identifier(id)) => id.name
          _ => ""
        }
        // First emit the class without export prefix
        let class_str = emit_class_declaration_inner(cd, ctx)
        ctx.get_indent() + ns_name + "." + class_name + " = " + class_str
      } else {
        emit_class_declaration(cd, ctx)
      }
    _ => emit(node, ctx)
  }
}

///|
/// Emit class declaration without export prefix (for module members)
fn emit_class_declaration_inner(
  cd : ClassDeclaration,
  ctx : EmitterContext,
) -> String {
  let mut result = "class "
  match cd.name {
    Some(Identifier(id)) => result = result + id.name
    _ => ()
  }

  // Emit heritage (extends only)
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
fn emit_property_declaration(
  pd : PropertyDeclaration,
  ctx : EmitterContext,
) -> String {
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
fn emit_method_declaration(
  md : MethodDeclaration,
  ctx : EmitterContext,
) -> String {
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
      result = result + emit(body, ctx)
    }
    None => result = result + ";"
  }
  result
}

///|
/// Emit constructor declaration
fn emit_constructor_declaration(
  cd : ConstructorDeclaration,
  ctx : EmitterContext,
) -> String {
  let mut result = ctx.get_indent() + "constructor("
  result = result + emit_parameters(cd.parameters, ctx)
  result = result + ")"
  match cd.body {
    Some(body) => {
      result = result + " "
      result = result + emit(body, ctx)
    }
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
      result = result + emit(body, ctx)
    }
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
      result = result + emit(body, ctx)
    }
    None => result = result + ";"
  }
  result
}

///|
/// Emit import declaration
fn emit_import_declaration(
  id : ImportDeclaration,
  ctx : EmitterContext,
) -> String {
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

      // Named bindings
      match clause.named_bindings {
        Some(bindings) => {
          if has_bindings {
            result = result + ", "
          }
          match bindings {
            NamespaceImport(name, _) =>
              // import * as name from 'mod'
              result = result + "* as " + name
            NamedImports(specifiers, _) => {
              // import { a, b, c as d } from 'mod'
              result = result + "{ "
              for i = 0; i < specifiers.length(); i = i + 1 {
                let spec = specifiers[i]
                match spec.property_name {
                  Some(prop_name) =>
                    // import { foo as bar } from 'mod'
                    result = result + prop_name + " as " + spec.name
                  None =>
                    // import { foo } from 'mod'
                    result = result + spec.name
                }
                if i < specifiers.length() - 1 {
                  result = result + ", "
                }
              }
              result = result + " }"
            }
          }
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
fn emit_export_declaration(
  ed : ExportDeclaration,
  ctx : EmitterContext,
) -> String {
  let mut result = ctx.get_indent() + "export "
  match ed.export_clause {
    Some(clause) =>
      match clause {
        NamedExports(specifiers, _) => {
          // export { a, b, c as d }
          result = result + "{ "
          for i = 0; i < specifiers.length(); i = i + 1 {
            let spec = specifiers[i]
            match spec.property_name {
              Some(prop_name) =>
                // export { foo as bar }
                result = result + prop_name + " as " + spec.name
              None =>
                // export { foo }
                result = result + spec.name
            }
            if i < specifiers.length() - 1 {
              result = result + ", "
            }
          }
          result = result + " }"
        }
        NamespaceExport(name, _) =>
          // export * as ns from 'mod'
          result = result + "* as " + name
      }
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
fn emit_export_assignment(
  ea : ExportAssignment,
  ctx : EmitterContext,
) -> String {
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
  ctx.add_mapping(
    if_stmt.location.start.line,
    if_stmt.location.start.column,
    None,
  )
  let mut result = ctx.get_indent() + "if ("
  result = result + emit(if_stmt.condition, ctx)
  result = result + ") "
  let then_str = emit(if_stmt.then_statement, ctx)
  result = result + then_str
  match if_stmt.else_statement {
    Some(else_stmt) => {
      result = result + " else "
      let else_str = emit(else_stmt, ctx)
      result = result + else_str
    }
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
fn emit_do_while_statement(
  dws : DoWhileStatement,
  ctx : EmitterContext,
) -> String {
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
fn emit_continue_statement(
  cs : ContinueStatement,
  ctx : EmitterContext,
) -> String {
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
fn emit_expression_statement(
  es : ExpressionStatement,
  ctx : EmitterContext,
) -> String {
  ctx.get_indent() + emit(es.expression, ctx) + ";"
}

///|
/// Emit labeled statement
fn emit_labeled_statement(
  ls : LabeledStatement,
  ctx : EmitterContext,
) -> String {
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
fn emit_binary_expression(
  be : BinaryExpression,
  ctx : EmitterContext,
) -> String {
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
fn emit_conditional_expression(
  ce : ConditionalExpression,
  ctx : EmitterContext,
) -> String {
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
fn emit_property_access_expression(
  pae : PropertyAccessExpression,
  ctx : EmitterContext,
) -> String {
  // Add source mapping at the property access
  ctx.add_mapping(
    pae.location.start.line,
    pae.location.start.column,
    Some(pae.name),
  )
  emit(pae.expression, ctx) + "." + pae.name
}

///|
/// Emit element access expression
fn emit_element_access_expression(
  eae : ElementAccessExpression,
  ctx : EmitterContext,
) -> String {
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
fn emit_function_expression(
  fe : FunctionExpression,
  ctx : EmitterContext,
) -> String {
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
fn emit_array_literal_expression(
  ale : ArrayLiteralExpression,
  ctx : EmitterContext,
) -> String {
  let mut result = "["
  for i = 0; i < ale.elements.length(); i = i + 1 {
    match ale.elements[i] {
      Some(elem) => result = result + emit(elem, ctx)
      None => () // Array hole
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
fn emit_object_literal_expression(
  ole : ObjectLiteralExpression,
  ctx : EmitterContext,
) -> String {
  if ole.properties.length() == 0 {
    return "{}"
  }
  let mut result = "{ "
  for i = 0; i < ole.properties.length(); i = i + 1 {
    match ole.properties[i] {
      PropertyAssignment(name, value, _) =>
        result = result + name + ": " + emit(value, ctx)
      ShorthandProperty(name, _) => result = result + name
      SpreadAssignment(expr, _) => result = result + "..." + emit(expr, ctx)
      MethodDeclaration(name, func_expr, _) =>
        result = result + name + emit_function_expression(func_expr, ctx)
      GetAccessor(name, func_expr, _) =>
        result = result +
          "get " +
          name +
          emit_function_expression(func_expr, ctx)
      SetAccessor(name, func_expr, _) =>
        result = result +
          "set " +
          name +
          emit_function_expression(func_expr, ctx)
      ComputedPropertyAssignment(name_expr, value, _) =>
        result = result + "[" + emit(name_expr, ctx) + "]: " + emit(value, ctx)
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
fn emit_parenthesized_expression(
  pe : ParenthesizedExpression,
  ctx : EmitterContext,
) -> String {
  "(" + emit(pe.expression, ctx) + ")"
}

///|
/// Emit template expression
fn emit_template_expression(
  te : TemplateExpression,
  ctx : EmitterContext,
) -> String {
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
fn emit_spread_expression(
  se : SpreadExpression,
  ctx : EmitterContext,
) -> String {
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
fn emit_array_binding_pattern(
  abp : ArrayBindingPattern,
  ctx : EmitterContext,
) -> String {
  let mut result = "["
  for i = 0; i < abp.elements.length(); i = i + 1 {
    match abp.elements[i] {
      Some(elem) => result = result + emit(elem, ctx)
      None => () // Array hole
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
fn emit_object_binding_pattern(
  obp : ObjectBindingPattern,
  ctx : EmitterContext,
) -> String {
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

///|
/// Emit JSDoc comment - preserve as multi-line comment
fn emit_jsdoc_comment(jsdoc : JSDocComment) -> String {
  // Preserve JSDoc comments in output for documentation tools
  "/**" + jsdoc.comment + "*/"
}

// ============================================================================
// JSX Emission Functions
// ============================================================================

///|
/// Emit JSX element: <tag>...</tag> -> React.createElement(tag, props, ...children)
fn emit_jsx_element(je : JsxElement, ctx : EmitterContext) -> String {
  // Get tag name and attributes from opening element
  let (tag_name, attributes) = match je.opening_element {
    JsxOpeningElement(joe) => (emit_jsx_tag_name(joe.tag_name), joe.attributes)
    _ => ("\"div\"", []) // Fallback
  }
  let mut result = "React.createElement(" + tag_name

  // Emit props
  result = result + ", " + emit_jsx_attributes(attributes, ctx)

  // Emit children
  for child in je.children {
    let child_str = emit_jsx_child(child, ctx)
    if child_str.length() > 0 {
      result = result + ", " + child_str
    }
  }
  result = result + ")"
  result
}

///|
/// Emit JSX self-closing element: <tag ... /> -> React.createElement(tag, props)
fn emit_jsx_self_closing_element(
  jsce : JsxSelfClosingElement,
  ctx : EmitterContext,
) -> String {
  let tag_name = emit_jsx_tag_name(jsce.tag_name)
  let mut result = "React.createElement(" + tag_name

  // Emit props
  result = result + ", " + emit_jsx_attributes(jsce.attributes, ctx)
  result = result + ")"
  result
}

///|
/// Emit JSX fragment: <>...</> -> React.createElement(React.Fragment, null, ...children)
fn emit_jsx_fragment(jf : JsxFragment, ctx : EmitterContext) -> String {
  let mut result = "React.createElement(React.Fragment, null"

  // Emit children
  for child in jf.children {
    let child_str = emit_jsx_child(child, ctx)
    if child_str.length() > 0 {
      result = result + ", " + child_str
    }
  }
  result = result + ")"
  result
}

///|
/// Emit JSX opening element (used when JsxOpeningElement appears standalone)
fn emit_jsx_opening_element(
  joe : JsxOpeningElement,
  ctx : EmitterContext,
) -> String {
  let tag_name = emit_jsx_tag_name(joe.tag_name)
  let mut result = "React.createElement(" + tag_name

  // Emit props
  result = result + ", " + emit_jsx_attributes(joe.attributes, ctx)
  result = result + ")"
  result
}

///|
/// Emit JSX expression: {expr}
fn emit_jsx_expression(je : JsxExpression, ctx : EmitterContext) -> String {
  match je.expression {
    Some(expr) => emit(expr, ctx)
    None => ""
  }
}

///|
/// Emit JSX tag name
fn emit_jsx_tag_name(tag_name : JsxTagName) -> String {
  match tag_name {
    JsxTagName::Identifier(name, _) =>
      // If starts with lowercase, it's a string (HTML element)
      // If starts with uppercase, it's a component reference
      if is_lowercase_start(name) {
        "\"" + name + "\""
      } else {
        name
      }
    JsxTagName::NamespacedName(ns, name, _) => "\"" + ns + ":" + name + "\""
    JsxTagName::PropertyAccess(expr, prop, _) =>
      // For Member.Component, we need to emit the expression
      match expr {
        Identifier(id) => id.name + "." + prop
        _ => prop // Fallback
      }
  }
}

///|
/// Check if a string starts with a lowercase letter
fn is_lowercase_start(s : String) -> Bool {
  if s.length() == 0 {
    return false
  }
  let first_char = s[0]
  first_char >= 'a' && first_char <= 'z'
}

///|
/// Emit JSX attributes as props object
fn emit_jsx_attributes(
  attributes : Array[JsxAttribute],
  ctx : EmitterContext,
) -> String {
  if attributes.length() == 0 {
    return "null"
  }
  let mut result = "{ "
  let mut first = true
  for attr in attributes {
    match attr {
      JsxAttribute::Attribute(attr_node) => {
        if not(first) {
          result = result + ", "
        }
        first = false
        let attr_name = emit_jsx_attribute_name(attr_node.name)
        result = result + attr_name + ": "
        match attr_node.initializer {
          Some(value) => result = result + emit_jsx_attribute_value(value, ctx)
          None => result = result + "true" // Boolean attribute like "disabled"
        }
      }
      JsxAttribute::SpreadAttribute(expr, _) => {
        if not(first) {
          result = result + ", "
        }
        first = false
        result = result + "..." + emit(expr, ctx)
      }
    }
  }
  result = result + " }"
  result
}

///|
/// Emit JSX attribute name
fn emit_jsx_attribute_name(name : JsxAttributeName) -> String {
  match name {
    JsxAttributeName::Identifier(id, _) =>
      // Convert JSX attribute names to React props (e.g., class -> className)
      if id == "class" {
        "className"
      } else if id == "for" {
        "htmlFor"
      } else {
        id
      }
    JsxAttributeName::NamespacedName(ns, n, _) => "\"" + ns + ":" + n + "\""
  }
}

///|
/// Emit JSX attribute value
fn emit_jsx_attribute_value(
  value : JsxAttributeValue,
  ctx : EmitterContext,
) -> String {
  match value {
    JsxAttributeValue::StringLiteral(s, _) => "\"" + escape_string(s) + "\""
    JsxAttributeValue::Expression(expr, _) => emit(expr, ctx)
    JsxAttributeValue::Element(elem, _) => emit(elem, ctx)
  }
}

///|
/// Emit JSX child
fn emit_jsx_child(child : JsxChild, ctx : EmitterContext) -> String {
  match child {
    JsxChild::Text(text, _) =>
      // Skip whitespace-only text nodes
      if is_whitespace_only(text) {
        ""
      } else {
        "\"" + escape_jsx_text(text) + "\""
      }
    JsxChild::Expression(jsx_expr) => emit_jsx_expression(jsx_expr, ctx)
    JsxChild::Element(elem, _) => emit(elem, ctx)
    JsxChild::Fragment(frag, _) => emit(frag, ctx)
  }
}

///|
/// Check if a string contains only whitespace characters
fn is_whitespace_only(s : String) -> Bool {
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i]
    if c != ' ' && c != '\t' && c != '\n' && c != '\r' {
      return false
    }
  }
  true
}

///|
/// Escape text for JSX string output
fn escape_jsx_text(s : String) -> String {
  s
  .replace(old="\\", new="\\\\")
  .replace(old="\"", new="\\\"")
  .replace(old="\n", new="\\n")
  .replace(old="\r", new="\\r")
  .replace(old="\t", new="\\t")
}
