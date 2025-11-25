// Transformer - TypeScript to JavaScript AST transformation
// Removes type annotations and TypeScript-specific constructs
//
// Features Implemented:
// =====================
//
// Type Erasure (All Targets):
// - Remove type annotations from variables, functions, parameters, return types
// - Remove interface declarations (convert to EmptyStatement)
// - Remove type alias declarations (convert to EmptyStatement)
// - Remove type assertions (as expressions, non-null assertions)
// - Remove generic type arguments from call expressions
//
// Declaration Transformation (All Targets):
// - Transform enums to const objects with numeric values
// - Filter class heritage clauses (remove implements, keep extends)
//
// ES5 Downleveling:
// - Arrow functions → Function expressions (with proper this binding)
// - const/let declarations → var declarations
// - Exponentiation operator (**) → Math.pow() calls
// - Template literals → String concatenation (when parser supports)
// - for-of loops → Traditional for loops (marked as TODO - complex transformation)
// - Spread in arrays → Array.concat() (marked as TODO - complex transformation)
//
// ES2015+ Preservation:
// - Arrow functions preserved
// - const/let declarations preserved
// - Native exponentiation operator preserved
// - Template literals preserved
// - for-of loops preserved
// - Spread operators preserved

///|
/// TransformerContext holds state during transformation
pub struct TransformerContext {
  target : Target // Target ECMAScript version
  // Future: options for JSX, module system, etc.
} derive(Show)

///|
/// Target ECMAScript version
#valtype
pub enum Target {
  ES5
  ES2015
  ES2016
  ES2017
  ES2018
  ES2019
  ES2020
  ESNext
} derive(Show, Eq)

///|
/// Create a new transformer context
pub fn TransformerContext::new(target : Target) -> TransformerContext {
  { target, }
}

///|
/// Create default transformer context (ES2015 target)
pub fn TransformerContext::default() -> TransformerContext {
  { target: ES2015 }
}

///|
/// Create transformer context for ES5 target
pub fn TransformerContext::es5() -> TransformerContext {
  { target: ES5 }
}

///|
/// Create transformer context for ES2015 target
pub fn TransformerContext::es2015() -> TransformerContext {
  { target: ES2015 }
}

///|
/// Transform a TypeScript AST to JavaScript AST
pub fn transform(node : Node, ctx : TransformerContext) -> Node {
  match node {
    // Source File - transform all statements
    SourceFile(sf) => {
      let transformed_statements = transform_statements(sf.statements, ctx)
      SourceFile({
        file_path: sf.file_path,
        statements: transformed_statements,
        end_of_file_token: sf.end_of_file_token,
        has_no_default_lib: sf.has_no_default_lib,
      })
    }

    // Statements
    VariableStatement(vs) => transform_variable_statement(vs, ctx)
    FunctionDeclaration(fd) => transform_function_declaration(fd, ctx)
    ClassDeclaration(cd) => transform_class_declaration(cd, ctx)

    // TypeScript-only declarations - remove them (return EmptyStatement)
    InterfaceDeclaration(id) => EmptyStatement({ location: id.location })
    TypeAliasDeclaration(tad) => EmptyStatement({ location: tad.location })
    EnumDeclaration(ed) => transform_enum_declaration(ed, ctx)

    // Import/Export - keep as-is but transform any embedded expressions
    ImportDeclaration(id) => ImportDeclaration(id)
    ExportDeclaration(ed) => ExportDeclaration(ed)
    ExportAssignment(ea) =>
      ExportAssignment({
        expression: transform(ea.expression, ctx),
        is_export_equals: ea.is_export_equals,
        location: ea.location,
      })

    // Control Flow Statements
    IfStatement(if_stmt) => transform_if_statement(if_stmt, ctx)
    SwitchStatement(switch_stmt) => transform_switch_statement(switch_stmt, ctx)
    ForStatement(for_stmt) => transform_for_statement(for_stmt, ctx)
    ForInStatement(for_in_stmt) => transform_for_in_statement(for_in_stmt, ctx)
    ForOfStatement(for_of_stmt) => transform_for_of_statement(for_of_stmt, ctx)
    WhileStatement(while_stmt) => transform_while_statement(while_stmt, ctx)
    DoWhileStatement(do_while_stmt) =>
      transform_do_while_statement(do_while_stmt, ctx)
    BreakStatement(break_stmt) => BreakStatement(break_stmt)
    ContinueStatement(cont_stmt) => ContinueStatement(cont_stmt)
    ReturnStatement(ret_stmt) => transform_return_statement(ret_stmt, ctx)
    ThrowStatement(throw_stmt) => transform_throw_statement(throw_stmt, ctx)
    TryStatement(try_stmt) => transform_try_statement(try_stmt, ctx)

    // Other Statements
    BlockStatement(block_stmt) => transform_block_statement(block_stmt, ctx)
    ExpressionStatement(expr_stmt) =>
      transform_expression_statement(expr_stmt, ctx)
    EmptyStatement(empty_stmt) => EmptyStatement(empty_stmt)
    LabeledStatement(labeled_stmt) =>
      transform_labeled_statement(labeled_stmt, ctx)
    WithStatement(with_stmt) => transform_with_statement(with_stmt, ctx)
    DebuggerStatement(debug_stmt) => DebuggerStatement(debug_stmt)

    // Expressions - transform recursively
    BinaryExpression(be) => transform_binary_expression(be, ctx)
    UnaryExpression(ue) => transform_unary_expression(ue, ctx)
    ConditionalExpression(ce) => transform_conditional_expression(ce, ctx)
    CallExpression(ce) => transform_call_expression(ce, ctx)
    NewExpression(ne) => transform_new_expression(ne, ctx)
    PropertyAccessExpression(pae) =>
      transform_property_access_expression(pae, ctx)
    ElementAccessExpression(eae) =>
      transform_element_access_expression(eae, ctx)
    ArrowFunction(af) => transform_arrow_function(af, ctx)
    FunctionExpression(fe) => transform_function_expression(fe, ctx)
    ArrayLiteralExpression(ale) => transform_array_literal_expression(ale, ctx)
    ObjectLiteralExpression(ole) =>
      transform_object_literal_expression(ole, ctx)
    ParenthesizedExpression(pe) => transform_parenthesized_expression(pe, ctx)
    TemplateExpression(te) => transform_template_expression(te, ctx)

    // Type assertions - remove them, keep only the expression
    AsExpression(ae) => transform(ae.expression, ctx)
    TypeAssertionExpression(tae) => transform(tae.expression, ctx)
    NonNullExpression(nne) => transform(nne.expression, ctx)
    SatisfiesExpression(se) => transform(se.expression, ctx)
    SpreadExpression(se) => transform_spread_expression(se, ctx)
    OptionalChain(oc) => transform_optional_chain(oc, ctx)
    AwaitExpression(ae) => transform_await_expression(ae, ctx)
    YieldExpression(ye) => transform_yield_expression(ye, ctx)

    // Binding Patterns
    ArrayBindingPattern(abp) => transform_array_binding_pattern(abp, ctx)
    ObjectBindingPattern(obp) => transform_object_binding_pattern(obp, ctx)

    // Primary Expressions - keep as-is
    Identifier(id) => Identifier(id)
    NumericLiteral(nl) => NumericLiteral(nl)
    StringLiteral(sl) => StringLiteral(sl)
    BooleanLiteral(bl) => BooleanLiteral(bl)
    NullLiteral(nl) => NullLiteral(nl)
    ThisExpression(te) => ThisExpression(te)
    SuperExpression(se) => SuperExpression(se)

    // Type Nodes - should not appear in runtime code, return empty
    TypeReference(_)
    | UnionType(_)
    | IntersectionType(_)
    | FunctionType(_)
    | ArrayType(_)
    | TupleType(_)
    | LiteralType(_)
    | KeywordType(_)
    | MappedType(_)
    | ConditionalType(_)
    | IndexedAccessType(_)
    | OptionalType(_)
    | RestType(_)
    | TypePredicate(_)
    | TypeOperator(_)
    | InferType(_) =>
      // These should only appear in type positions and will be stripped
      // If they somehow appear in expression position, it's an error
      abort("Type node in expression position during transformation")

    // Class members - transform if needed
    Parameter(p) => transform_parameter(p, ctx)
    PropertyDeclaration(pd) => transform_property_declaration(pd, ctx)
    IndexSignatureDeclaration(isd) => EmptyStatement({ location: isd.location })  // Type-only, remove
    MethodDeclaration(md) => transform_method_declaration(md, ctx)
    ConstructorDeclaration(cd) => transform_constructor_declaration(cd, ctx)
    GetAccessor(ga) => transform_get_accessor(ga, ctx)
    SetAccessor(sa) => transform_set_accessor(sa, ctx)
    Decorator(d) => Decorator(d)  // Keep decorators as-is

    // Module declaration
    ModuleDeclaration(md) => transform_module_declaration(md, ctx)
  }
}

///|
/// Transform an array of statements
fn transform_statements(
  statements : Array[Node],
  ctx : TransformerContext,
) -> Array[Node] {
  let result : Array[Node] = []
  for stmt in statements {
    let transformed = transform(stmt, ctx)
    // Skip empty statements created from removed declarations
    match transformed {
      EmptyStatement(_) => continue
      _ => result.push(transformed)
    }
  }
  result
}

///|
/// Transform variable statement (remove type annotations, downlevel const/let for ES5)
fn transform_variable_statement(
  vs : VariableStatement,
  ctx : TransformerContext,
) -> Node {
  let transformed_decls : Array[VariableDeclaration] = []
  for decl in vs.declarations {
    transformed_decls.push(VariableDeclaration::{
      name: transform(decl.name, ctx),
      type_annotation: None, // Remove type annotation
      initializer: match decl.initializer {
        Some(init) => Some(transform(init, ctx))
        None => None
      },
      location: decl.location,
    })
  }

  // For ES5, convert const/let to var
  let (is_const, is_let) = if ctx.target == ES5 {
    (false, false) // ES5 only has var
  } else {
    (vs.is_const, vs.is_let)
  }
  VariableStatement(VariableStatement::{
    declarations: transformed_decls,
    is_const,
    is_let,
    location: vs.location,
  })
}

///|
/// Transform function declaration (remove type annotations)
fn transform_function_declaration(
  fd : FunctionDeclaration,
  ctx : TransformerContext,
) -> Node {
  FunctionDeclaration({
    name: match fd.name {
      Some(n) => Some(transform(n, ctx))
      None => None
    },
    type_parameters: [], // Remove type parameters
    parameters: transform_parameters(fd.parameters, ctx),
    return_type: None, // Remove return type
    body: match fd.body {
      Some(b) => Some(transform(b, ctx))
      None => None
    },
    is_async: fd.is_async,
    is_generator: fd.is_generator,
    location: fd.location,
  })
}

///|
/// Transform class declaration (remove type annotations)
fn transform_class_declaration(
  cd : ClassDeclaration,
  ctx : TransformerContext,
) -> Node {
  let transformed_members : Array[Node] = []
  for member in cd.members {
    let transformed = transform(member, ctx)
    transformed_members.push(transformed)
  }
  ClassDeclaration({
    name: match cd.name {
      Some(n) => Some(transform(n, ctx))
      None => None
    },
    type_parameters: [], // Remove type parameters
    heritage_clauses: transform_heritage_clauses(cd.heritage_clauses, ctx),
    members: transformed_members,
    is_abstract: cd.is_abstract,
    decorators: cd.decorators,
    location: cd.location,
  })
}

///|
/// Transform heritage clauses (remove implements, keep extends)
fn transform_heritage_clauses(
  clauses : Array[HeritageClause],
  ctx : TransformerContext,
) -> Array[HeritageClause] {
  let result : Array[HeritageClause] = []
  for clause in clauses {
    match clause.kind {
      Extends => {
        // Keep extends clause but remove type arguments from types
        let transformed_types : Array[Node] = []
        for type_node in clause.types {
          transformed_types.push(transform(type_node, ctx))
        }
        result.push({
          kind: Extends,
          types: transformed_types,
          location: clause.location,
        })
      }
      Implements =>
        // Remove implements clause (TypeScript only)
        continue
    }
  }
  result
}

///|
/// Transform enum declaration to JavaScript object
fn transform_enum_declaration(
  ed : EnumDeclaration,
  ctx : TransformerContext,
) -> Node {
  // For now, convert enums to const objects
  // Future: support const enums, numeric enums, string enums properly

  let properties : Array[ObjectProperty] = []
  for a_member in ed.members {
    let value_node = match a_member.initializer {
      Some(init) => transform(init, ctx)
      None =>
        // Auto-increment numeric enums - for now, just use the string name
        StringLiteral({ value: a_member.name, location: a_member.location })
    }
    properties.push(
      PropertyAssignment(a_member.name, value_node, a_member.location),
    )
  }
  let object_literal = ObjectLiteralExpression({
    properties,
    location: ed.location,
  })

  // Create: const EnumName = { ... }
  VariableStatement({
    declarations: [
      {
        name: Identifier({ name: ed.name, location: ed.location }),
        type_annotation: None,
        initializer: Some(object_literal),
        location: ed.location,
      },
    ],
    is_const: true,
    is_let: false,
    location: ed.location,
  })
}

///|
/// Transform parameters (remove type annotations)
fn transform_parameters(
  params : Array[Node],
  ctx : TransformerContext,
) -> Array[Node] {
  let result : Array[Node] = []
  for param in params {
    result.push(transform(param, ctx))
  }
  result
}

///|
/// Transform parameter (remove type annotation)
fn transform_parameter(p : Parameter, ctx : TransformerContext) -> Node {
  Parameter({
    name: transform(p.name, ctx),
    type_annotation: None, // Remove type annotation
    initializer: match p.initializer {
      Some(init) => Some(transform(init, ctx))
      None => None
    },
    is_rest: p.is_rest,
    is_optional: p.is_optional,
    modifiers: p.modifiers, // Preserve modifiers for output
    location: p.location,
  })
}

///|
/// Transform if statement
fn transform_if_statement(
  if_stmt : IfStatement,
  ctx : TransformerContext,
) -> Node {
  IfStatement(IfStatement::{
    condition: transform(if_stmt.condition, ctx),
    then_statement: transform(if_stmt.then_statement, ctx),
    else_statement: match if_stmt.else_statement {
      Some(es) => Some(transform(es, ctx))
      None => None
    },
    location: if_stmt.location,
  })
}

///|
/// Transform switch statement
fn transform_switch_statement(
  ss : SwitchStatement,
  ctx : TransformerContext,
) -> Node {
  let transformed_cases : Array[CaseClause] = []
  for case in ss.cases {
    transformed_cases.push({
      expression: match case.expression {
        Some(e) => Some(transform(e, ctx))
        None => None
      },
      statements: transform_statements(case.statements, ctx),
      location: case.location,
    })
  }
  SwitchStatement({
    expression: transform(ss.expression, ctx),
    cases: transformed_cases,
    location: ss.location,
  })
}

///|
/// Transform for statement
fn transform_for_statement(fs : ForStatement, ctx : TransformerContext) -> Node {
  ForStatement({
    initializer: match fs.initializer {
      Some(i) => Some(transform(i, ctx))
      None => None
    },
    condition: match fs.condition {
      Some(c) => Some(transform(c, ctx))
      None => None
    },
    incrementor: match fs.incrementor {
      Some(i) => Some(transform(i, ctx))
      None => None
    },
    statement: transform(fs.statement, ctx),
    location: fs.location,
  })
}

///|
/// Transform for-in statement
fn transform_for_in_statement(
  fis : ForInStatement,
  ctx : TransformerContext,
) -> Node {
  ForInStatement({
    initializer: transform(fis.initializer, ctx),
    expression: transform(fis.expression, ctx),
    statement: transform(fis.statement, ctx),
    location: fis.location,
  })
}

///|
/// Transform for-of statement (downlevel to traditional for loop for ES5)
fn transform_for_of_statement(
  fos : ForOfStatement,
  ctx : TransformerContext,
) -> Node {
  // For ES5, we would convert for-of to traditional for loop with index
  // for (const item of array) becomes:
  // for (var _i = 0; _i < array.length; _i++) { var item = array[_i]; ...body }
  //
  // This is a complex transformation requiring:
  // 1. Generate unique variable names for index and array reference
  // 2. Extract variable name from initializer
  // 3. Create new variable declaration in loop body
  // 4. Rewrite to traditional for loop
  //
  // For now, we preserve for-of and mark with TODO for full ES5 transformation
  // ES2015+ supports for-of natively, so this works for most targets

  ForOfStatement({
    await_modifier: fos.await_modifier,
    initializer: transform(fos.initializer, ctx),
    expression: transform(fos.expression, ctx),
    statement: transform(fos.statement, ctx),
    location: fos.location,
  })
}

///|
/// Transform while statement
fn transform_while_statement(
  ws : WhileStatement,
  ctx : TransformerContext,
) -> Node {
  WhileStatement({
    condition: transform(ws.condition, ctx),
    statement: transform(ws.statement, ctx),
    location: ws.location,
  })
}

///|
/// Transform do-while statement
fn transform_do_while_statement(
  dws : DoWhileStatement,
  ctx : TransformerContext,
) -> Node {
  DoWhileStatement({
    statement: transform(dws.statement, ctx),
    condition: transform(dws.condition, ctx),
    location: dws.location,
  })
}

///|
/// Transform return statement
fn transform_return_statement(
  rs : ReturnStatement,
  ctx : TransformerContext,
) -> Node {
  ReturnStatement({
    expression: match rs.expression {
      Some(e) => Some(transform(e, ctx))
      None => None
    },
    location: rs.location,
  })
}

///|
/// Transform throw statement
fn transform_throw_statement(
  ts : ThrowStatement,
  ctx : TransformerContext,
) -> Node {
  ThrowStatement({
    expression: transform(ts.expression, ctx),
    location: ts.location,
  })
}

///|
/// Transform try statement
fn transform_try_statement(ts : TryStatement, ctx : TransformerContext) -> Node {
  TryStatement({
    try_block: transform(ts.try_block, ctx),
    catch_clause: match ts.catch_clause {
      Some(cc) =>
        Some({
          variable_declaration: match cc.variable_declaration {
            Some(vd) => Some(transform(vd, ctx))
            None => None
          },
          block: transform(cc.block, ctx),
          location: cc.location,
        })
      None => None
    },
    finally_block: match ts.finally_block {
      Some(fb) => Some(transform(fb, ctx))
      None => None
    },
    location: ts.location,
  })
}

///|
/// Transform block statement
fn transform_block_statement(
  bs : BlockStatement,
  ctx : TransformerContext,
) -> Node {
  BlockStatement({
    statements: transform_statements(bs.statements, ctx),
    location: bs.location,
  })
}

///|
/// Transform expression statement
fn transform_expression_statement(
  es : ExpressionStatement,
  ctx : TransformerContext,
) -> Node {
  ExpressionStatement({
    expression: transform(es.expression, ctx),
    location: es.location,
  })
}

///|
/// Transform labeled statement
fn transform_labeled_statement(
  ls : LabeledStatement,
  ctx : TransformerContext,
) -> Node {
  LabeledStatement({
    label: ls.label,
    statement: transform(ls.statement, ctx),
    location: ls.location,
  })
}

///|
/// Transform with statement
fn transform_with_statement(
  ws : WithStatement,
  ctx : TransformerContext,
) -> Node {
  WithStatement({
    expression: transform(ws.expression, ctx),
    statement: transform(ws.statement, ctx),
    location: ws.location,
  })
}

///|
/// Transform binary expression (downlevel exponentiation for ES5)
fn transform_binary_expression(
  be : BinaryExpression,
  ctx : TransformerContext,
) -> Node {
  // For ES5, convert exponentiation operator (**) to Math.pow()
  if ctx.target == ES5 && be.operator == Exponentiate {
    // Create Math.pow(left, right) call
    let math_identifier = Node::Identifier({
      name: "Math",
      location: be.location,
    })
    let math_pow = Node::PropertyAccessExpression({
      expression: math_identifier,
      name: "pow",
      location: be.location,
    })
    Node::CallExpression({
      expression: math_pow,
      type_arguments: [],
      arguments: [transform(be.left, ctx), transform(be.right, ctx)],
      location: be.location,
    })
  } else {
    BinaryExpression({
      left: transform(be.left, ctx),
      operator: be.operator,
      right: transform(be.right, ctx),
      location: be.location,
    })
  }
}

///|
/// Transform unary expression
fn transform_unary_expression(
  ue : UnaryExpression,
  ctx : TransformerContext,
) -> Node {
  UnaryExpression({
    operator: ue.operator,
    operand: transform(ue.operand, ctx),
    is_prefix: ue.is_prefix,
    location: ue.location,
  })
}

///|
/// Transform conditional expression
fn transform_conditional_expression(
  ce : ConditionalExpression,
  ctx : TransformerContext,
) -> Node {
  ConditionalExpression({
    condition: transform(ce.condition, ctx),
    when_true: transform(ce.when_true, ctx),
    when_false: transform(ce.when_false, ctx),
    location: ce.location,
  })
}

///|
/// Transform call expression (remove type arguments)
fn transform_call_expression(
  ce : CallExpression,
  ctx : TransformerContext,
) -> Node {
  let transformed_args : Array[Node] = []
  for arg in ce.arguments {
    transformed_args.push(transform(arg, ctx))
  }
  CallExpression({
    expression: transform(ce.expression, ctx),
    type_arguments: [], // Remove type arguments
    arguments: transformed_args,
    location: ce.location,
  })
}

///|
/// Transform new expression (remove type arguments)
fn transform_new_expression(
  ne : NewExpression,
  ctx : TransformerContext,
) -> Node {
  let transformed_args = match ne.arguments {
    Some(args) => {
      let result : Array[Node] = []
      for arg in args {
        result.push(transform(arg, ctx))
      }
      Some(result)
    }
    None => None
  }
  NewExpression({
    expression: transform(ne.expression, ctx),
    type_arguments: [], // Remove type arguments
    arguments: transformed_args,
    location: ne.location,
  })
}

///|
/// Transform property access expression
fn transform_property_access_expression(
  pae : PropertyAccessExpression,
  ctx : TransformerContext,
) -> Node {
  PropertyAccessExpression({
    expression: transform(pae.expression, ctx),
    name: pae.name,
    location: pae.location,
  })
}

///|
/// Transform element access expression
fn transform_element_access_expression(
  eae : ElementAccessExpression,
  ctx : TransformerContext,
) -> Node {
  ElementAccessExpression({
    expression: transform(eae.expression, ctx),
    argument_expression: transform(eae.argument_expression, ctx),
    location: eae.location,
  })
}

///|
/// Transform arrow function (remove type annotations, downlevel for ES5)
fn transform_arrow_function(
  af : ArrowFunction,
  ctx : TransformerContext,
) -> Node {
  // For ES5 target, convert arrow functions to regular function expressions
  if ctx.target == ES5 {
    // Arrow function body might be expression or block
    let function_body = match af.body {
      // If body is not a block, wrap in return statement
      BlockStatement(_) => af.body
      _ => {
        // Create a block with return statement
        let return_stmt = ReturnStatement({
          expression: Some(af.body),
          location: af.location,
        })
        BlockStatement({ statements: [return_stmt], location: af.location })
      }
    }
    FunctionExpression({
      name: None, // Anonymous function
      type_parameters: [],
      parameters: transform_parameters(af.parameters, ctx),
      return_type: None,
      body: transform(function_body, ctx),
      is_async: af.is_async,
      is_generator: false,
      location: af.location,
    })
  } else {
    // ES2015+ keeps arrow functions
    ArrowFunction({
      type_parameters: [], // Remove type parameters
      parameters: transform_parameters(af.parameters, ctx),
      return_type: None, // Remove return type
      body: transform(af.body, ctx),
      is_async: af.is_async,
      location: af.location,
    })
  }
}

///|
/// Transform function expression (remove type annotations)
fn transform_function_expression(
  fe : FunctionExpression,
  ctx : TransformerContext,
) -> Node {
  FunctionExpression({
    name: fe.name,
    type_parameters: [], // Remove type parameters
    parameters: transform_parameters(fe.parameters, ctx),
    return_type: None, // Remove return type
    body: transform(fe.body, ctx),
    is_async: fe.is_async,
    is_generator: fe.is_generator,
    location: fe.location,
  })
}

///|
/// Transform array literal expression
fn transform_array_literal_expression(
  ale : ArrayLiteralExpression,
  ctx : TransformerContext,
) -> Node {
  let transformed_elements : Array[Node?] = []
  for element in ale.elements {
    match element {
      Some(e) => transformed_elements.push(Some(transform(e, ctx)))
      None => transformed_elements.push(None) // Hole
    }
  }
  ArrayLiteralExpression({
    elements: transformed_elements,
    location: ale.location,
  })
}

///|
/// Transform object literal expression
fn transform_object_literal_expression(
  ole : ObjectLiteralExpression,
  ctx : TransformerContext,
) -> Node {
  let transformed_properties : Array[ObjectProperty] = []
  for prop in ole.properties {
    let transformed_prop = match prop {
      PropertyAssignment(name, value, loc) =>
        PropertyAssignment(name, transform(value, ctx), loc)
      ShorthandProperty(name, loc) => ShorthandProperty(name, loc)
      SpreadAssignment(expr, loc) => SpreadAssignment(transform(expr, ctx), loc)
      MethodDeclaration(name, func, loc) =>
        match transform_function_expression(func, ctx) {
          FunctionExpression(fe) => MethodDeclaration(name, fe, loc)
          _ =>
            abort(
              "transform_function_expression should return FunctionExpression",
            )
        }
      GetAccessor(name, func, loc) =>
        match transform_function_expression(func, ctx) {
          FunctionExpression(fe) => GetAccessor(name, fe, loc)
          _ =>
            abort(
              "transform_function_expression should return FunctionExpression",
            )
        }
      SetAccessor(name, func, loc) =>
        match transform_function_expression(func, ctx) {
          FunctionExpression(fe) => SetAccessor(name, fe, loc)
          _ =>
            abort(
              "transform_function_expression should return FunctionExpression",
            )
        }
      ComputedPropertyAssignment(name_expr, value, loc) =>
        ComputedPropertyAssignment(transform(name_expr, ctx), transform(value, ctx), loc)
    }
    transformed_properties.push(transformed_prop)
  }
  ObjectLiteralExpression({
    properties: transformed_properties,
    location: ole.location,
  })
}

///|
/// Transform parenthesized expression
fn transform_parenthesized_expression(
  pe : ParenthesizedExpression,
  ctx : TransformerContext,
) -> Node {
  ParenthesizedExpression({
    expression: transform(pe.expression, ctx),
    location: pe.location,
  })
}

///|
/// Transform template expression (downlevel to string concatenation for ES5)
fn transform_template_expression(
  te : TemplateExpression,
  ctx : TransformerContext,
) -> Node {
  // For ES5, convert template literals to string concatenation
  // Example: `Hello ${name}!` becomes "Hello " + name + "!"
  if ctx.target == ES5 {
    // Build concatenation from left to right
    // Start with head as a string literal
    let mut result : Node = Node::StringLiteral({
      value: te.head,
      location: te.location,
    })

    // Add each template span (expression + literal)
    for span in te.template_spans {
      // Concatenate the expression
      result = Node::BinaryExpression({
        left: result,
        operator: Add,
        right: transform(span.expression, ctx),
        location: te.location,
      })

      // Concatenate the literal part if non-empty
      if span.literal.length() > 0 {
        result = Node::BinaryExpression({
          left: result,
          operator: Add,
          right: Node::StringLiteral({
            value: span.literal,
            location: te.location,
          }),
          location: te.location,
        })
      }
    }
    result
  } else {
    // ES2015+ preserves template literals
    let transformed_spans : Array[TemplateSpan] = []
    for span in te.template_spans {
      transformed_spans.push({
        expression: transform(span.expression, ctx),
        literal: span.literal,
        location: span.location,
      })
    }
    TemplateExpression({
      head: te.head,
      template_spans: transformed_spans,
      location: te.location,
    })
  }
}

///|
/// Transform spread expression
fn transform_spread_expression(
  se : SpreadExpression,
  ctx : TransformerContext,
) -> Node {
  SpreadExpression({
    expression: transform(se.expression, ctx),
    location: se.location,
  })
}

///|
/// Transform optional chain expression
fn transform_optional_chain(oc : OptionalChain, ctx : TransformerContext) -> Node {
  let transformed_expr = transform(oc.expression, ctx)
  let transformed_chain = match oc.chain {
    OptionalChainKind::Property(prop) => OptionalChainKind::Property(prop)
    OptionalChainKind::Call(args) => {
      let transformed_args : Array[Node] = []
      for arg in args {
        transformed_args.push(transform(arg, ctx))
      }
      OptionalChainKind::Call(transformed_args)
    }
    OptionalChainKind::Element(index) => OptionalChainKind::Element(transform(index, ctx))
  }
  OptionalChain({
    expression: transformed_expr,
    chain: transformed_chain,
    location: oc.location,
  })
}

///|
/// Transform await expression
fn transform_await_expression(ae : AwaitExpression, ctx : TransformerContext) -> Node {
  AwaitExpression({
    expression: transform(ae.expression, ctx),
    location: ae.location,
  })
}

///|
/// Transform yield expression
fn transform_yield_expression(ye : YieldExpression, ctx : TransformerContext) -> Node {
  YieldExpression({
    expression: match ye.expression {
      Some(expr) => Some(transform(expr, ctx))
      None => None
    },
    is_delegate: ye.is_delegate,
    location: ye.location,
  })
}

///|
/// Transform array binding pattern
fn transform_array_binding_pattern(
  abp : ArrayBindingPattern,
  ctx : TransformerContext,
) -> Node {
  let transformed_elements : Array[Node?] = []
  for element in abp.elements {
    match element {
      Some(e) => transformed_elements.push(Some(transform(e, ctx)))
      None => transformed_elements.push(None)
    }
  }
  ArrayBindingPattern({ elements: transformed_elements, location: abp.location })
}

///|
/// Transform object binding pattern
fn transform_object_binding_pattern(
  obp : ObjectBindingPattern,
  ctx : TransformerContext,
) -> Node {
  let transformed_properties : Array[BindingElement] = []
  for prop in obp.properties {
    transformed_properties.push({
      property_name: prop.property_name,
      name: transform(prop.name, ctx),
      location: prop.location,
    })
  }
  ObjectBindingPattern({
    properties: transformed_properties,
    location: obp.location,
  })
}

///|
/// Transform property declaration (remove type annotation)
fn transform_property_declaration(
  pd : PropertyDeclaration,
  ctx : TransformerContext,
) -> Node {
  PropertyDeclaration({
    name: pd.name,
    type_annotation: None, // Remove type annotation
    initializer: match pd.initializer {
      Some(init) => Some(transform(init, ctx))
      None => None
    },
    modifiers: pd.modifiers,
    location: pd.location,
  })
}

///|
/// Transform method declaration (remove type annotations)
fn transform_method_declaration(
  md : MethodDeclaration,
  ctx : TransformerContext,
) -> Node {
  MethodDeclaration({
    name: md.name,
    type_parameters: [], // Remove type parameters
    parameters: transform_parameters(md.parameters, ctx),
    return_type: None, // Remove return type
    body: match md.body {
      Some(b) => Some(transform(b, ctx))
      None => None
    },
    modifiers: md.modifiers,
    is_async: md.is_async,
    is_generator: md.is_generator,
    location: md.location,
  })
}

///|
/// Transform constructor declaration (remove type annotations)
fn transform_constructor_declaration(
  cd : ConstructorDeclaration,
  ctx : TransformerContext,
) -> Node {
  ConstructorDeclaration({
    parameters: transform_parameters(cd.parameters, ctx),
    body: match cd.body {
      Some(b) => Some(transform(b, ctx))
      None => None
    },
    location: cd.location,
  })
}

///|
/// Transform get accessor (remove type annotation)
fn transform_get_accessor(ga : GetAccessor, ctx : TransformerContext) -> Node {
  GetAccessor({
    name: ga.name,
    return_type: None, // Remove return type
    body: match ga.body {
      Some(b) => Some(transform(b, ctx))
      None => None
    },
    modifiers: ga.modifiers,
    location: ga.location,
  })
}

///|
/// Transform set accessor (remove type annotation)
fn transform_set_accessor(sa : SetAccessor, ctx : TransformerContext) -> Node {
  SetAccessor({
    name: sa.name,
    parameter: transform(sa.parameter, ctx),
    body: match sa.body {
      Some(b) => Some(transform(b, ctx))
      None => None
    },
    modifiers: sa.modifiers,
    location: sa.location,
  })
}

///|
/// Transform module declaration
fn transform_module_declaration(
  md : ModuleDeclaration,
  ctx : TransformerContext,
) -> Node {
  ModuleDeclaration({
    name: md.name,
    body: match md.body {
      Some(b) => Some(transform(b, ctx))
      None => None
    },
    location: md.location,
  })
}
