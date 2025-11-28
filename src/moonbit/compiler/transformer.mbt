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
// Target-Based Downleveling:
// -------------------------
// ES5 (< ES2015):
// - Arrow functions → Function expressions
// - const/let declarations → var declarations
// - Template literals → String concatenation
// - for-of loops → Traditional indexed for loops
// - Spread in arrays → Array.concat() calls
//
// < ES2016:
// - Exponentiation operator (**) → Math.pow() calls
//
// < ES2020:
// - Optional chaining (?.) → Conditional expressions (a?.b → a == null ? undefined : a.b)
// - Nullish coalescing (??) → Conditional expressions (a ?? b → a !== null ? a : b)
//
// ES2015+ Preservation:
// - Arrow functions, const/let, template literals preserved
//
// ES2016+ Preservation:
// - Exponentiation operator (**) preserved
//
// ES2020+ (ESNext) Preservation:
// - Optional chaining (?.) preserved
// - Nullish coalescing (??) preserved

///|
/// JSX transformation mode
pub(all) enum JsxTransform {
  /// Preserve JSX as-is (no transformation)
  Preserve
  /// Classic mode: React.createElement(type, props, ...children)
  Classic(String, String) // (factory, fragmentFactory)
  /// Automatic mode: jsx/jsxs from runtime import
  Automatic(String) // import source (e.g., "react")
  /// Automatic dev mode: jsxDEV from runtime import
  AutomaticDev(String) // import source
} derive(Show)

///|
/// TransformerContext holds state during transformation
pub struct TransformerContext {
  target : Target // Target ECMAScript version
  in_decorated_class : Bool // True if we're inside a class with decorators
  const_enums : Map[String, Map[String, Node]] // Const enum name -> member name -> value
  jsx_transform : JsxTransform // JSX transformation mode
  temp_counter : Ref[Int] // Counter for generating unique temporary variable names
}

///|
/// Generate a unique temporary variable name
fn gen_temp_name(ctx : TransformerContext, prefix : String) -> String {
  let count = ctx.temp_counter.val
  ctx.temp_counter.val = count + 1
  prefix + count.to_string()
}

///|
/// Target ECMAScript version
#valtype
pub(all) enum Target {
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
/// Get the ordinal value of a target for comparison
pub fn Target::ordinal(self : Target) -> Int {
  match self {
    ES5 => 0
    ES2015 => 1
    ES2016 => 2
    ES2017 => 3
    ES2018 => 4
    ES2019 => 5
    ES2020 => 6
    ESNext => 7
  }
}

///|
/// Check if target supports a feature introduced in a specific version
pub fn Target::supports(self : Target, min_version : Target) -> Bool {
  self.ordinal() >= min_version.ordinal()
}

///|
/// Check if target is older than a specific version (requires downleveling)
pub fn Target::older_than(self : Target, version : Target) -> Bool {
  self.ordinal() < version.ordinal()
}

///|
/// Create a new transformer context
pub fn TransformerContext::new(target : Target) -> TransformerContext {
  { target, in_decorated_class: false, const_enums: Map::new(), jsx_transform: Preserve, temp_counter: Ref::new(0) }
}

///|
/// Create a new transformer context with JSX options
pub fn TransformerContext::with_jsx(target : Target, jsx_transform : JsxTransform) -> TransformerContext {
  { target, in_decorated_class: false, const_enums: Map::new(), jsx_transform, temp_counter: Ref::new(0) }
}

///|
/// Create default transformer context (ES2015 target)
pub fn TransformerContext::default() -> TransformerContext {
  { target: ES2015, in_decorated_class: false, const_enums: Map::new(), jsx_transform: Preserve, temp_counter: Ref::new(0) }
}

///|
/// Create transformer context for ES5 target
pub fn TransformerContext::es5() -> TransformerContext {
  { target: ES5, in_decorated_class: false, const_enums: Map::new(), jsx_transform: Preserve, temp_counter: Ref::new(0) }
}

///|
/// Create a new context with in_decorated_class flag set
fn TransformerContext::with_decorated_class(
  self : TransformerContext,
  decorated : Bool,
) -> TransformerContext {
  { target: self.target, in_decorated_class: decorated, const_enums: self.const_enums, jsx_transform: self.jsx_transform, temp_counter: self.temp_counter }
}

///|
/// Create transformer context for ES2015 target
pub fn TransformerContext::es2015() -> TransformerContext {
  { target: ES2015, in_decorated_class: false, const_enums: Map::new(), jsx_transform: Preserve, temp_counter: Ref::new(0) }
}

///|
/// Create transformer context for ES2016 target
pub fn TransformerContext::es2016() -> TransformerContext {
  { target: ES2016, in_decorated_class: false, const_enums: Map::new(), jsx_transform: Preserve, temp_counter: Ref::new(0) }
}

///|
/// Create transformer context for ES2017 target
pub fn TransformerContext::es2017() -> TransformerContext {
  { target: ES2017, in_decorated_class: false, const_enums: Map::new(), jsx_transform: Preserve, temp_counter: Ref::new(0) }
}

///|
/// Create transformer context for ES2018 target
pub fn TransformerContext::es2018() -> TransformerContext {
  { target: ES2018, in_decorated_class: false, const_enums: Map::new(), jsx_transform: Preserve, temp_counter: Ref::new(0) }
}

///|
/// Create transformer context for ES2019 target
pub fn TransformerContext::es2019() -> TransformerContext {
  { target: ES2019, in_decorated_class: false, const_enums: Map::new(), jsx_transform: Preserve, temp_counter: Ref::new(0) }
}

///|
/// Create transformer context for ES2020 target
pub fn TransformerContext::es2020() -> TransformerContext {
  { target: ES2020, in_decorated_class: false, const_enums: Map::new(), jsx_transform: Preserve, temp_counter: Ref::new(0) }
}

///|
/// Create transformer context for ESNext target
pub fn TransformerContext::esnext() -> TransformerContext {
  { target: ESNext, in_decorated_class: false, const_enums: Map::new(), jsx_transform: Preserve, temp_counter: Ref::new(0) }
}

///|
/// Collect const enum declarations from statements and populate the context
fn collect_const_enums(
  statements : Array[Node],
  ctx : TransformerContext,
) -> Unit {
  for stmt in statements {
    match stmt {
      EnumDeclaration(ed) =>
        if ed.is_const {
          // Build member map for this const enum
          let members : Map[String, Node] = Map::new()
          let mut auto_value = 0
          for m in ed.members {
            let value : Node = match m.initializer {
              Some(init) => {
                // Try to extract numeric value for auto-increment
                match init {
                  NumericLiteral(nl) => {
                    let num_val = @strconv.parse_int(nl.value) catch { _ => 0 }
                    auto_value = num_val + 1
                  }
                  _ => ()
                }
                init
              }
              None => {
                // Auto-increment numeric value
                let node : Node = Node::NumericLiteral({
                  value: auto_value.to_string(),
                  location: m.location,
                })
                auto_value = auto_value + 1
                node
              }
            }
            members.set(m.name, value)
          }
          ctx.const_enums.set(ed.name, members)
        }
      _ => ()
    }
  }
}

///|
/// Transform a TypeScript AST to JavaScript AST
pub fn transform(node : Node, ctx : TransformerContext) -> Node {
  match node {
    // Source File - transform all statements
    SourceFile(sf) => {
      // First pass: collect const enum declarations
      collect_const_enums(sf.statements, ctx)
      // Second pass: transform statements
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
    DebuggerStatement(ds) => DebuggerStatement(ds)
    LabeledStatement(labeled_stmt) =>
      transform_labeled_statement(labeled_stmt, ctx)
    WithStatement(with_stmt) => transform_with_statement(with_stmt, ctx)

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
    ClassExpression(ce) => transform_class_expression(ce, ctx)
    ArrayLiteralExpression(ale) => transform_array_literal_expression(ale, ctx)
    ObjectLiteralExpression(ole) =>
      transform_object_literal_expression(ole, ctx)
    ParenthesizedExpression(pe) => transform_parenthesized_expression(pe, ctx)
    TemplateExpression(te) => transform_template_expression(te, ctx)
    TaggedTemplateExpression(tte) => transform_tagged_template_expression(tte, ctx)

    // Type assertions - remove them, keep only the expression
    AsExpression(ae) => transform(ae.expression, ctx)
    TypeAssertionExpression(tae) => transform(tae.expression, ctx)
    NonNullExpression(nne) => transform(nne.expression, ctx)
    SatisfiesExpression(se) => transform(se.expression, ctx)
    SpreadExpression(se) => transform_spread_expression(se, ctx)
    OptionalChain(oc) => transform_optional_chain(oc, ctx)
    AwaitExpression(ae) => transform_await_expression(ae, ctx)
    YieldExpression(ye) => transform_yield_expression(ye, ctx)
    ImportExpression(ie) => transform_import_expression(ie, ctx)

    // Binding Patterns
    ArrayBindingPattern(abp) => transform_array_binding_pattern(abp, ctx)
    ObjectBindingPattern(obp) => transform_object_binding_pattern(obp, ctx)

    // Primary Expressions - keep as-is
    Identifier(id) => Identifier(id)
    NumericLiteral(nl) => NumericLiteral(nl)
    BigIntLiteral(bi) => BigIntLiteral(bi)
    StringLiteral(sl) => StringLiteral(sl)
    BooleanLiteral(bl) => BooleanLiteral(bl)
    NullLiteral(nl) => NullLiteral(nl)
    RegExpLiteral(rl) => RegExpLiteral(rl)
    ThisExpression(te) => ThisExpression(te)
    SuperExpression(se) => SuperExpression(se)
    MetaProperty(mp) => MetaProperty(mp) // import.meta and new.target pass through

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
    | NamedTupleMember(_)
    | TypePredicate(_)
    | TypeOperator(_)
    | InferType(_)
    | TemplateLiteralType(_)
    | TypeLiteral(_)
    | TypeLiteralProperty(_) =>
      // These should only appear in type positions and will be stripped
      // If they somehow appear in expression position, it's an error
      abort("Type node in expression position during transformation")

    // Class members - transform if needed
    Parameter(p) => transform_parameter(p, ctx)
    PropertyDeclaration(pd) => transform_property_declaration(pd, ctx)
    IndexSignatureDeclaration(isd) => EmptyStatement({ location: isd.location }) // Type-only, remove
    MethodDeclaration(md) => transform_method_declaration(md, ctx)
    ConstructorDeclaration(cd) => transform_constructor_declaration(cd, ctx)
    GetAccessor(ga) => transform_get_accessor(ga, ctx)
    SetAccessor(sa) => transform_set_accessor(sa, ctx)
    StaticBlock(sb) =>
      // Transform the body of the static block
      StaticBlock(StaticBlock::{
        body: transform(sb.body, ctx),
        location: sb.location,
      })
    Decorator(d) => Decorator(d) // Keep decorators as-is

    // Auto-accessor - pass through (native ES2022+)
    AutoAccessor(aa) =>
      AutoAccessor(AutoAccessor::{
        name: aa.name,
        type_annotation: None, // Strip type annotation
        initializer: match aa.initializer {
          Some(init) => Some(transform(init, ctx))
          None => None
        },
        decorators: aa.decorators,
        modifiers: aa.modifiers,
        location: aa.location,
      })

    // Using statement - pass through (native ES2024+)
    UsingStatement(us) => {
      let transformed_decls : Array[VariableDeclaration] = []
      for decl in us.declarations {
        transformed_decls.push(VariableDeclaration::{
          name: transform(decl.name, ctx),
          type_annotation: None, // Strip type annotation
          initializer: match decl.initializer {
            Some(init) => Some(transform(init, ctx))
            None => None
          },
          location: decl.location,
        })
      }
      UsingStatement(UsingStatement::{
        declarations: transformed_decls,
        is_await: us.is_await,
        location: us.location,
      })
    }

    // Module declaration
    ModuleDeclaration(md) => transform_module_declaration(md, ctx)

    // JSX - transform based on jsx_transform mode
    JsxElement(jsx) => transform_jsx_element(jsx, ctx)
    JsxSelfClosingElement(jsx) => transform_jsx_self_closing(jsx, ctx)
    JsxFragment(jsx) => transform_jsx_fragment(jsx, ctx)
    JsxOpeningElement(jsx) => JsxOpeningElement(jsx) // Not used directly
    JsxClosingElement(jsx) => JsxClosingElement(jsx) // Not used directly
    JsxExpression(jsx) => transform_jsx_expression(jsx, ctx)

    // JSDoc - pass through unchanged
    JSDocComment(jsdoc) => JSDocComment(jsdoc)
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
/// Transform variable statement (remove type annotations, downlevel const/let for < ES2015)
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

  // const/let were introduced in ES2015
  // For < ES2015 (ES5), convert const/let to var
  let (is_const, is_let) = if ctx.target.older_than(ES2015) {
    (false, false) // ES5 only has var
  } else {
    (vs.is_const, vs.is_let)
  }
  VariableStatement(VariableStatement::{
    declarations: transformed_decls,
    is_const,
    is_let,
    modifiers: vs.modifiers,
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
    modifiers: fd.modifiers,
    location: fd.location,
  })
}

///|
/// Transform class declaration (remove type annotations, handle parameter properties)
fn transform_class_declaration(
  cd : ClassDeclaration,
  ctx : TransformerContext,
) -> Node {
  // If class has decorators, use a context that preserves types for metadata
  let has_class_decorators = cd.decorators.length() > 0
  let member_ctx = ctx.with_decorated_class(has_class_decorators)

  // First pass: find constructor and extract parameter properties
  let param_properties : Array[(String, Array[Modifier], SourceLocation)] = []

  for cmember in cd.members {
    match cmember {
      ConstructorDeclaration(ctor) => {
        // Extract parameter properties (parameters with access modifiers)
        for param in ctor.parameters {
          match param {
            Parameter(p) => {
              if has_access_modifier(p.modifiers) {
                match p.name {
                  Identifier(id) =>
                    param_properties.push((id.name, p.modifiers, p.location))
                  _ => ()
                }
              }
            }
            _ => ()
          }
        }
      }
      _ => ()
    }
  }

  // Transform all members
  let transformed_members : Array[Node] = []

  // Add generated property declarations for parameter properties
  for prop in param_properties {
    let (name, modifiers, location) = prop
    transformed_members.push(
      Node::PropertyDeclaration(PropertyDeclaration::{
        name,
        type_annotation: None, // Type is removed in JS output
        initializer: None, // Will be assigned in constructor
        is_optional: false,
        decorators: [],
        modifiers,
        location,
      }),
    )
  }

  // Transform existing members
  for cmember in cd.members {
    match cmember {
      ConstructorDeclaration(ctor) => {
        // Transform constructor with parameter property assignments
        let transformed = transform_constructor_with_param_properties(
          ctor, param_properties, member_ctx,
        )
        transformed_members.push(transformed)
      }
      _ => {
        let transformed = transform(cmember, member_ctx)
        transformed_members.push(transformed)
      }
    }
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
    modifiers: cd.modifiers,
    location: cd.location,
  })
}

///|
/// Transform class expression (same as class declaration but returns ClassExpression)
fn transform_class_expression(
  cd : ClassDeclaration,
  ctx : TransformerContext,
) -> Node {
  // If class has decorators, use a context that preserves types for metadata
  let has_class_decorators = cd.decorators.length() > 0
  let member_ctx = ctx.with_decorated_class(has_class_decorators)

  // First pass: find constructor and extract parameter properties
  let param_properties : Array[(String, Array[Modifier], SourceLocation)] = []

  for cmember in cd.members {
    match cmember {
      ConstructorDeclaration(ctor) => {
        // Extract parameter properties (parameters with access modifiers)
        for param in ctor.parameters {
          match param {
            Parameter(p) => {
              if has_access_modifier(p.modifiers) {
                match p.name {
                  Identifier(id) =>
                    param_properties.push((id.name, p.modifiers, p.location))
                  _ => ()
                }
              }
            }
            _ => ()
          }
        }
      }
      _ => ()
    }
  }

  // Transform all members
  let transformed_members : Array[Node] = []

  // Add generated property declarations for parameter properties
  for prop in param_properties {
    let (name, modifiers, location) = prop
    transformed_members.push(
      Node::PropertyDeclaration(PropertyDeclaration::{
        name,
        type_annotation: None, // Type is removed in JS output
        initializer: None, // Will be assigned in constructor
        is_optional: false,
        decorators: [],
        modifiers,
        location,
      }),
    )
  }

  // Transform existing members
  for cmember in cd.members {
    match cmember {
      ConstructorDeclaration(ctor) => {
        // Transform constructor with parameter property assignments
        let transformed = transform_constructor_with_param_properties(
          ctor, param_properties, member_ctx,
        )
        transformed_members.push(transformed)
      }
      _ => {
        let transformed = transform(cmember, member_ctx)
        transformed_members.push(transformed)
      }
    }
  }

  ClassExpression({
    name: match cd.name {
      Some(n) => Some(transform(n, ctx))
      None => None
    },
    type_parameters: [], // Remove type parameters
    heritage_clauses: transform_heritage_clauses(cd.heritage_clauses, ctx),
    members: transformed_members,
    is_abstract: cd.is_abstract,
    decorators: cd.decorators,
    modifiers: cd.modifiers,
    location: cd.location,
  })
}

///|
/// Check if a parameter has an access modifier (public, private, protected, readonly)
fn has_access_modifier(modifiers : Array[Modifier]) -> Bool {
  for m in modifiers {
    match m {
      Public | Private | Protected | Readonly => return true
      _ => ()
    }
  }
  false
}

///|
/// Transform constructor with parameter property assignments
fn transform_constructor_with_param_properties(
  ctor : ConstructorDeclaration,
  param_properties : Array[(String, Array[Modifier], SourceLocation)],
  ctx : TransformerContext,
) -> Node {
  // Generate this.x = x assignments for parameter properties
  let assignments : Array[Node] = []
  for prop in param_properties {
    let (name, _, location) = prop
    // Create: this.name = name;
    let assignment = Node::ExpressionStatement(ExpressionStatement::{
      expression: Node::BinaryExpression(BinaryExpression::{
        left: Node::PropertyAccessExpression(PropertyAccessExpression::{
          expression: Node::ThisExpression(ThisExpression::{ location }),
          name,
          location,
        }),
        operator: BinaryOperator::Assign,
        right: Node::Identifier(Identifier::{ name, location }),
        location,
      }),
      location,
    })
    assignments.push(assignment)
  }

  // Check if we should preserve type annotations (for decorator metadata)
  let mut has_param_decorators = false
  for param in ctor.parameters {
    match param {
      Parameter(p) =>
        if p.decorators.length() > 0 {
          has_param_decorators = true
          break
        }
      _ => ()
    }
  }
  let preserve_types = ctor.decorators.length() > 0 ||
    has_param_decorators ||
    ctx.in_decorated_class

  // Transform parameters - remove access modifiers from parameter properties
  let transformed_params : Array[Node] = []
  for param in ctor.parameters {
    match param {
      Parameter(p) => {
        // Remove access modifiers from parameter properties
        let new_modifiers : Array[Modifier] = []
        for m in p.modifiers {
          match m {
            Public | Private | Protected | Readonly => () // Skip access modifiers
            _ => new_modifiers.push(m)
          }
        }
        transformed_params.push(
          Node::Parameter(Parameter::{
            name: transform(p.name, ctx),
            type_annotation: if preserve_types { p.type_annotation } else { None },
            initializer: match p.initializer {
              Some(init) => Some(transform(init, ctx))
              None => None
            },
            is_optional: p.is_optional,
            is_rest: p.is_rest,
            is_this_parameter: p.is_this_parameter,
            decorators: p.decorators,
            modifiers: new_modifiers,
            location: p.location,
          }),
        )
      }
      _ => transformed_params.push(transform(param, ctx))
    }
  }

  // Transform body and prepend assignments
  let transformed_body : Node? = match ctor.body {
    Some(body) =>
      match body {
        BlockStatement(block) => {
          // Prepend assignments to existing statements
          let new_statements : Array[Node] = []
          for a in assignments {
            new_statements.push(a)
          }
          for stmt in block.statements {
            new_statements.push(transform(stmt, ctx))
          }
          Some(
            Node::BlockStatement(BlockStatement::{
              statements: new_statements,
              location: block.location,
            }),
          )
        }
        _ => Some(transform(body, ctx))
      }
    None =>
      // If no body but we have assignments, create a body
      if assignments.length() > 0 {
        Some(
          Node::BlockStatement(BlockStatement::{
            statements: assignments,
            location: ctor.location,
          }),
        )
      } else {
        None
      }
  }

  ConstructorDeclaration({
    parameters: transformed_params,
    body: transformed_body,
    decorators: ctor.decorators,
    location: ctor.location,
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
        // Keep extends clause but convert TypeReference to Identifier
        let transformed_types : Array[Node] = []
        for type_node in clause.types {
          // Heritage clause types are TypeReference nodes from parser
          // Convert them to Identifier nodes for JavaScript output
          match type_node {
            TypeReference(tr) =>
              transformed_types.push(
                Node::Identifier(Identifier::{
                  name: tr.type_name,
                  location: tr.location,
                }),
              )
            Identifier(_) => transformed_types.push(type_node)
            _ => transformed_types.push(transform(type_node, ctx))
          }
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
  // Const enums are inlined and don't produce any output
  if ed.is_const {
    return EmptyStatement({ location: ed.location })
  }

  // Regular enums: convert to const objects
  let properties : Array[ObjectProperty] = []
  let mut auto_value = 0
  for a_member in ed.members {
    let value_node : Node = match a_member.initializer {
      Some(init) => {
        // Try to extract numeric value for auto-increment
        match init {
          NumericLiteral(nl) => {
            let num_val = @strconv.parse_int(nl.value) catch { _ => 0 }
            auto_value = num_val + 1
          }
          _ => ()
        }
        transform(init, ctx)
      }
      None => {
        // Auto-increment numeric value
        let node : Node = Node::NumericLiteral({
          value: auto_value.to_string(),
          location: a_member.location,
        })
        auto_value = auto_value + 1
        node
      }
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
    modifiers: ed.modifiers,
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
/// Transform parameters preserving type annotations (for decorated methods)
fn transform_parameters_preserve_types(
  params : Array[Node],
  ctx : TransformerContext,
) -> Array[Node] {
  let result : Array[Node] = []
  for param in params {
    match param {
      Parameter(p) =>
        result.push(
          Parameter({
            name: transform(p.name, ctx),
            type_annotation: p.type_annotation, // Preserve type for metadata
            initializer: match p.initializer {
              Some(init) => Some(transform(init, ctx))
              None => None
            },
            is_rest: p.is_rest,
            is_optional: p.is_optional,
            is_this_parameter: p.is_this_parameter,
            decorators: p.decorators,
            modifiers: p.modifiers,
            location: p.location,
          }),
        )
      _ => result.push(transform(param, ctx))
    }
  }
  result
}

///|
/// Transform parameter (remove type annotation unless decorated)
fn transform_parameter(p : Parameter, ctx : TransformerContext) -> Node {
  // Preserve type annotation if parameter has decorators (for metadata emission)
  let preserve_type = p.decorators.length() > 0
  Parameter({
    name: transform(p.name, ctx),
    type_annotation: if preserve_type { p.type_annotation } else { None },
    initializer: match p.initializer {
      Some(init) => Some(transform(init, ctx))
      None => None
    },
    is_rest: p.is_rest,
    is_optional: p.is_optional,
    is_this_parameter: p.is_this_parameter,
    decorators: p.decorators, // Preserve decorators for output
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
  // ES2015+ supports for-of natively
  if ctx.target != ES5 {
    return ForOfStatement({
      await_modifier: fos.await_modifier,
      initializer: transform(fos.initializer, ctx),
      expression: transform(fos.expression, ctx),
      statement: transform(fos.statement, ctx),
      location: fos.location,
    })
  }

  // For ES5, convert for-of to traditional for loop with index
  // for (const item of array) becomes:
  // for (var _i = 0, _arr = array; _i < _arr.length; _i++) { var item = _arr[_i]; ...body }

  // Generate unique variable names
  let index_name = gen_temp_name(ctx, "_i$")
  let arr_name = gen_temp_name(ctx, "_arr$")
  let loc = fos.location

  // Extract variable name from initializer
  let var_name : String = match fos.initializer {
    VariableStatement(vs) =>
      if vs.declarations.length() > 0 {
        match vs.declarations[0].name {
          Identifier(id) => id.name
          _ => "_item"
        }
      } else {
        "_item"
      }
    Identifier(id) => id.name
    _ => "_item"
  }

  // Transform the expression (the array being iterated)
  let transformed_expr = transform(fos.expression, ctx)

  // Create identifier nodes for our temp variables
  let index_id = Node::Identifier(Identifier::{ name: index_name, location: loc })
  let arr_id = Node::Identifier(Identifier::{ name: arr_name, location: loc })
  let var_id = Node::Identifier(Identifier::{ name: var_name, location: loc })

  // Create initializer: var _i = 0, _arr = array
  let init_decls = [
    VariableDeclaration::{
      name: index_id,
      type_annotation: None,
      initializer: Some(Node::NumericLiteral(NumericLiteral::{ value: "0", location: loc })),
      location: loc,
    },
    VariableDeclaration::{
      name: arr_id,
      type_annotation: None,
      initializer: Some(transformed_expr),
      location: loc,
    },
  ]
  let initializer = Node::VariableStatement(VariableStatement::{
    declarations: init_decls,
    is_const: false,
    is_let: false,
    modifiers: [],
    location: loc,
  })

  // Create condition: _i < _arr.length
  let condition = Node::BinaryExpression(BinaryExpression::{
    left: index_id,
    operator: LessThan,
    right: Node::PropertyAccessExpression(PropertyAccessExpression::{
      expression: arr_id,
      name: "length",
      location: loc,
    }),
    location: loc,
  })

  // Create incrementor: _i++
  let incrementor = Node::UnaryExpression(UnaryExpression::{
    operator: Increment,
    operand: index_id,
    is_prefix: false,
    location: loc,
  })

  // Create variable declaration for loop body: var item = _arr[_i];
  let item_decl = Node::VariableStatement(VariableStatement::{
    declarations: [
      VariableDeclaration::{
        name: var_id,
        type_annotation: None,
        initializer: Some(Node::ElementAccessExpression(ElementAccessExpression::{
          expression: arr_id,
          argument_expression: index_id,
          location: loc,
        })),
        location: loc,
      },
    ],
    is_const: false,
    is_let: false,
    modifiers: [],
    location: loc,
  })

  // Transform the original body
  let transformed_body = transform(fos.statement, ctx)

  // Create new body with item declaration prepended
  let new_body = match transformed_body {
    BlockStatement(bs) => {
      let new_statements : Array[Node] = [item_decl]
      for stmt in bs.statements {
        new_statements.push(stmt)
      }
      Node::BlockStatement(BlockStatement::{
        statements: new_statements,
        location: bs.location,
      })
    }
    _ => {
      // Wrap in block if not already a block
      Node::BlockStatement(BlockStatement::{
        statements: [item_decl, transformed_body],
        location: loc,
      })
    }
  }

  // Create the for loop
  ForStatement(ForStatement::{
    initializer: Some(initializer),
    condition: Some(condition),
    incrementor: Some(incrementor),
    statement: new_body,
    location: loc,
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
/// Transform binary expression (downlevel based on target)
fn transform_binary_expression(
  be : BinaryExpression,
  ctx : TransformerContext,
) -> Node {
  // Exponentiation operator (**) was introduced in ES2016
  // For < ES2016, convert to Math.pow()
  if ctx.target.older_than(ES2016) && be.operator == Exponentiate {
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
  } else if ctx.target.older_than(ES2020) && be.operator == NullishCoalescing {
    // Nullish coalescing (??) was introduced in ES2020
    // Transform: a ?? b  →  a !== null && a !== undefined ? a : b
    // Simplified: (a != null ? a : b) for loose equality
    let left_transformed = transform(be.left, ctx)
    let right_transformed = transform(be.right, ctx)
    // Create: left != null ? left : right
    // Note: This is a simplified transform; full transform would need temp variable
    Node::ConditionalExpression({
      condition: Node::BinaryExpression({
        left: left_transformed,
        operator: StrictNotEquals,
        right: Node::NullLiteral({ location: be.location }),
        location: be.location,
      }),
      when_true: left_transformed,
      when_false: right_transformed,
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
  // Check if this is a const enum member access (e.g., Direction.Up)
  match pae.expression {
    Identifier(id) =>
      // Check if the identifier is a const enum
      match ctx.const_enums.get(id.name) {
        Some(members) =>
          // Check if the property is a member of this const enum
          match members.get(pae.name) {
            Some(value) =>
              // Inline the const enum value
              return value
            None => ()
          }
        None => ()
      }
    _ => ()
  }

  // Default: transform normally
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
/// Transform arrow function (remove type annotations, downlevel for < ES2015)
fn transform_arrow_function(
  af : ArrowFunction,
  ctx : TransformerContext,
) -> Node {
  // Arrow functions were introduced in ES2015
  // For < ES2015 (ES5), convert arrow functions to regular function expressions
  if ctx.target.older_than(ES2015) {
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
  // For ES5, need to transform spread elements to .concat() calls
  // e.g., [1, ...arr, 2] => [1].concat(arr, [2])
  if ctx.target == ES5 && has_spread_element(ale.elements) {
    return transform_array_with_spread_es5(ale, ctx)
  }

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
/// Check if array elements contain any spread expressions
fn has_spread_element(elements : Array[Node?]) -> Bool {
  for element in elements {
    match element {
      Some(SpreadExpression(_)) => return true
      _ => ()
    }
  }
  false
}

///|
/// Transform array with spread elements to ES5 .concat() calls
/// [1, ...arr, 2] => [1].concat(arr, [2])
/// [...arr1, ...arr2] => [].concat(arr1, arr2)
fn transform_array_with_spread_es5(
  ale : ArrayLiteralExpression,
  ctx : TransformerContext,
) -> Node {
  let loc = ale.location

  // Build segments: each segment is either:
  // - A group of non-spread elements (becomes an array literal)
  // - A spread element (becomes a direct argument to concat)
  let segments : Array[Node] = []
  let current_group : Array[Node?] = []

  for element in ale.elements {
    match element {
      Some(SpreadExpression(se)) => {
        // Flush current group as array literal
        if current_group.length() > 0 {
          segments.push(
            ArrayLiteralExpression({
              elements: current_group.copy(),
              location: loc,
            }),
          )
          current_group.clear()
        }
        // Add spread expression's inner expression directly
        segments.push(transform(se.expression, ctx))
      }
      Some(e) => {
        current_group.push(Some(transform(e, ctx)))
      }
      None => {
        // Hole in array
        current_group.push(None)
      }
    }
  }

  // Flush remaining group
  if current_group.length() > 0 {
    segments.push(
      ArrayLiteralExpression({ elements: current_group.copy(), location: loc }),
    )
  }

  // If no segments, return empty array
  if segments.length() == 0 {
    return ArrayLiteralExpression({ elements: [], location: loc })
  }

  // If only one segment and it's already an array literal, return it
  if segments.length() == 1 {
    match segments[0] {
      ArrayLiteralExpression(_) => return segments[0]
      _ => ()
    }
  }

  // Build: first_segment.concat(rest_segments...)
  // If first segment is a spread, start with empty array: [].concat(...)
  let (base, concat_args) : (Node, Array[Node]) = match segments[0] {
    ArrayLiteralExpression(_) => {
      let rest : Array[Node] = []
      for i in 1..<segments.length() {
        rest.push(segments[i])
      }
      (segments[0], rest)
    }
    _ => {
      // First segment is spread result, use empty array as base
      (ArrayLiteralExpression({ elements: [], location: loc }), segments)
    }
  }

  // Create: base.concat(arg1, arg2, ...)
  let concat_access = PropertyAccessExpression({
    expression: base,
    name: "concat",
    location: loc,
  })

  CallExpression({
    expression: concat_access,
    type_arguments: [],
    arguments: concat_args,
    location: loc,
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
        ComputedPropertyAssignment(
          transform(name_expr, ctx),
          transform(value, ctx),
          loc,
        )
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
/// Transform template expression (downlevel to string concatenation for < ES2015)
fn transform_template_expression(
  te : TemplateExpression,
  ctx : TransformerContext,
) -> Node {
  // Template literals were introduced in ES2015
  // For < ES2015 (ES5), convert template literals to string concatenation
  // Example: `Hello ${name}!` becomes "Hello " + name + "!"
  if ctx.target.older_than(ES2015) {
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
/// Transform tagged template expression: tag`template`
fn transform_tagged_template_expression(
  tte : TaggedTemplateExpression,
  ctx : TransformerContext,
) -> Node {
  // Transform both the tag and the template
  let transformed_tag = transform(tte.tag, ctx)
  let transformed_template = transform(tte.template, ctx)
  TaggedTemplateExpression({
    tag: transformed_tag,
    template: transformed_template,
    location: tte.location,
  })
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
/// Transform optional chain expression (downlevel for < ES2020)
fn transform_optional_chain(
  oc : OptionalChain,
  ctx : TransformerContext,
) -> Node {
  let transformed_expr = transform(oc.expression, ctx)

  // Optional chaining (?.) was introduced in ES2020
  // For < ES2020, transform: a?.b → a == null ? undefined : a.b
  if ctx.target.older_than(ES2020) {
    // Create the null check condition: expr == null
    let null_check = Node::BinaryExpression({
      left: transformed_expr,
      operator: Equals, // loose equality catches both null and undefined
      right: Node::NullLiteral({ location: oc.location }),
      location: oc.location,
    })

    // Create the property access / call / element access
    let access_expr = match oc.chain {
      OptionalChainKind::Property(prop) =>
        Node::PropertyAccessExpression({
          expression: transformed_expr,
          name: prop,
          location: oc.location,
        })
      OptionalChainKind::Call(args) => {
        let transformed_args : Array[Node] = []
        for arg in args {
          transformed_args.push(transform(arg, ctx))
        }
        Node::CallExpression({
          expression: transformed_expr,
          type_arguments: [],
          arguments: transformed_args,
          location: oc.location,
        })
      }
      OptionalChainKind::Element(index) =>
        Node::ElementAccessExpression({
          expression: transformed_expr,
          argument_expression: transform(index, ctx),
          location: oc.location,
        })
    }

    // Create: expr == null ? undefined : expr.prop
    Node::ConditionalExpression({
      condition: null_check,
      when_true: Node::Identifier({ name: "undefined", location: oc.location }),
      when_false: access_expr,
      location: oc.location,
    })
  } else {
    // ES2020+ keeps optional chaining
    let transformed_chain = match oc.chain {
      OptionalChainKind::Property(prop) => OptionalChainKind::Property(prop)
      OptionalChainKind::Call(args) => {
        let transformed_args : Array[Node] = []
        for arg in args {
          transformed_args.push(transform(arg, ctx))
        }
        OptionalChainKind::Call(transformed_args)
      }
      OptionalChainKind::Element(index) =>
        OptionalChainKind::Element(transform(index, ctx))
    }
    OptionalChain({
      expression: transformed_expr,
      chain: transformed_chain,
      location: oc.location,
    })
  }
}

///|
/// Transform await expression
fn transform_await_expression(
  ae : AwaitExpression,
  ctx : TransformerContext,
) -> Node {
  AwaitExpression({
    expression: transform(ae.expression, ctx),
    location: ae.location,
  })
}

///|
/// Transform yield expression
fn transform_yield_expression(
  ye : YieldExpression,
  ctx : TransformerContext,
) -> Node {
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
/// Transform dynamic import expression: import('./module')
fn transform_import_expression(
  ie : ImportExpression,
  ctx : TransformerContext,
) -> Node {
  // Transform the source expression (in case it contains expressions that need transformation)
  ImportExpression({
    source: transform(ie.source, ctx),
    location: ie.location,
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
  // Preserve type annotation if property has decorators (for metadata emission)
  let preserve_type = pd.decorators.length() > 0
  PropertyDeclaration({
    name: pd.name,
    type_annotation: if preserve_type { pd.type_annotation } else { None },
    initializer: match pd.initializer {
      Some(init) => Some(transform(init, ctx))
      None => None
    },
    is_optional: pd.is_optional,
    decorators: pd.decorators,
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
  // Preserve types if method has decorators (for metadata emission)
  let preserve_types = md.decorators.length() > 0
  MethodDeclaration({
    name: md.name,
    type_parameters: [], // Remove type parameters
    parameters: if preserve_types {
      transform_parameters_preserve_types(md.parameters, ctx)
    } else {
      transform_parameters(md.parameters, ctx)
    },
    return_type: if preserve_types { md.return_type } else { None },
    body: match md.body {
      Some(b) => Some(transform(b, ctx))
      None => None
    },
    decorators: md.decorators,
    modifiers: md.modifiers,
    is_async: md.is_async,
    is_generator: md.is_generator,
    is_optional: md.is_optional,
    location: md.location,
  })
}

///|
/// Transform constructor declaration (remove type annotations)
fn transform_constructor_declaration(
  cd : ConstructorDeclaration,
  ctx : TransformerContext,
) -> Node {
  // Preserve parameter types if:
  // - Constructor has decorators, or
  // - Any parameter has decorators, or
  // - Class has decorators (via context flag)
  let mut has_param_decorators = false
  for param in cd.parameters {
    match param {
      Parameter(p) =>
        if p.decorators.length() > 0 {
          has_param_decorators = true
          break
        }
      _ => ()
    }
  }
  let preserve_types = cd.decorators.length() > 0 ||
    has_param_decorators ||
    ctx.in_decorated_class
  ConstructorDeclaration({
    parameters: if preserve_types {
      transform_parameters_preserve_types(cd.parameters, ctx)
    } else {
      transform_parameters(cd.parameters, ctx)
    },
    body: match cd.body {
      Some(b) => Some(transform(b, ctx))
      None => None
    },
    decorators: cd.decorators,
    location: cd.location,
  })
}

///|
/// Transform get accessor (remove type annotation)
fn transform_get_accessor(ga : GetAccessor, ctx : TransformerContext) -> Node {
  // Preserve return type if getter has decorators (for metadata emission)
  let preserve_type = ga.decorators.length() > 0
  GetAccessor({
    name: ga.name,
    return_type: if preserve_type { ga.return_type } else { None },
    body: match ga.body {
      Some(b) => Some(transform(b, ctx))
      None => None
    },
    decorators: ga.decorators,
    modifiers: ga.modifiers,
    location: ga.location,
  })
}

///|
/// Transform set accessor (remove type annotation)
fn transform_set_accessor(sa : SetAccessor, ctx : TransformerContext) -> Node {
  // Preserve parameter type if setter has decorators (for metadata emission)
  let preserve_type = sa.decorators.length() > 0
  let transformed_param : Node = if preserve_type {
    // Preserve type annotation on parameter for metadata
    match sa.parameter {
      Parameter(p) =>
        Node::Parameter({
          name: transform(p.name, ctx),
          type_annotation: p.type_annotation,
          initializer: match p.initializer {
            Some(init) => Some(transform(init, ctx))
            None => None
          },
          is_rest: p.is_rest,
          is_optional: p.is_optional,
          is_this_parameter: p.is_this_parameter,
          decorators: p.decorators,
          modifiers: p.modifiers,
          location: p.location,
        })
      _ => transform(sa.parameter, ctx)
    }
  } else {
    transform(sa.parameter, ctx)
  }
  SetAccessor({
    name: sa.name,
    parameter: transformed_param,
    body: match sa.body {
      Some(b) => Some(transform(b, ctx))
      None => None
    },
    decorators: sa.decorators,
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
    is_ambient: md.is_ambient,
    location: md.location,
  })
}

// ============================================================================
// JSX Transformation
// ============================================================================
// Transforms JSX syntax into function calls:
// - Classic mode: React.createElement(type, props, ...children)
// - Automatic mode: jsx(type, props) / jsxs(type, props) from runtime

///|
/// Transform JSX element: <tag>children</tag>
fn transform_jsx_element(jsx : JsxElement, ctx : TransformerContext) -> Node {
  match ctx.jsx_transform {
    Preserve => JsxElement(jsx)
    Classic(factory, _) => {
      // Extract tag name and attributes from opening element
      guard jsx.opening_element is JsxOpeningElement(opening) else {
        return JsxElement(jsx)
      }
      transform_jsx_to_classic(
        opening.tag_name,
        opening.attributes,
        jsx.children,
        jsx.location,
        factory,
        ctx,
      )
    }
    Automatic(import_source) => {
      guard jsx.opening_element is JsxOpeningElement(opening) else {
        return JsxElement(jsx)
      }
      transform_jsx_to_automatic(
        opening.tag_name,
        opening.attributes,
        jsx.children,
        jsx.location,
        import_source,
        false,
        ctx,
      )
    }
    AutomaticDev(import_source) => {
      guard jsx.opening_element is JsxOpeningElement(opening) else {
        return JsxElement(jsx)
      }
      transform_jsx_to_automatic(
        opening.tag_name,
        opening.attributes,
        jsx.children,
        jsx.location,
        import_source,
        true,
        ctx,
      )
    }
  }
}

///|
/// Transform JSX self-closing element: <tag ... />
fn transform_jsx_self_closing(jsx : JsxSelfClosingElement, ctx : TransformerContext) -> Node {
  match ctx.jsx_transform {
    Preserve => JsxSelfClosingElement(jsx)
    Classic(factory, _) => {
      transform_jsx_to_classic(
        jsx.tag_name,
        jsx.attributes,
        [], // No children for self-closing
        jsx.location,
        factory,
        ctx,
      )
    }
    Automatic(import_source) => {
      transform_jsx_to_automatic(
        jsx.tag_name,
        jsx.attributes,
        [],
        jsx.location,
        import_source,
        false,
        ctx,
      )
    }
    AutomaticDev(import_source) => {
      transform_jsx_to_automatic(
        jsx.tag_name,
        jsx.attributes,
        [],
        jsx.location,
        import_source,
        true,
        ctx,
      )
    }
  }
}

///|
/// Transform JSX fragment: <>children</>
fn transform_jsx_fragment(jsx : JsxFragment, ctx : TransformerContext) -> Node {
  match ctx.jsx_transform {
    Preserve => JsxFragment(jsx)
    Classic(_, fragment_factory) => {
      transform_jsx_fragment_to_classic(
        jsx.children,
        jsx.location,
        fragment_factory,
        ctx,
      )
    }
    Automatic(import_source) => {
      transform_jsx_fragment_to_automatic(
        jsx.children,
        jsx.location,
        import_source,
        false,
        ctx,
      )
    }
    AutomaticDev(import_source) => {
      transform_jsx_fragment_to_automatic(
        jsx.children,
        jsx.location,
        import_source,
        true,
        ctx,
      )
    }
  }
}

///|
/// Transform JSX expression container: {expression}
fn transform_jsx_expression(jsx : JsxExpression, ctx : TransformerContext) -> Node {
  match jsx.expression {
    Some(expr) => transform(expr, ctx)
    None => Node::Identifier({ name: "undefined", location: jsx.location })
  }
}

///|
/// Transform JSX to classic React.createElement call
fn transform_jsx_to_classic(
  tag_name : JsxTagName,
  attributes : Array[JsxAttribute],
  children : Array[JsxChild],
  location : SourceLocation,
  factory : String,
  ctx : TransformerContext,
) -> Node {
  // Create the factory function call
  let factory_expr = create_factory_expression(factory, location)

  // Create the type argument (tag name)
  let type_arg = jsx_tag_name_to_node(tag_name, location)

  // Create the props object (or null if no attributes)
  let props_arg = jsx_attributes_to_props(attributes, location, ctx)

  // Create children arguments
  let children_args = jsx_children_to_args(children, ctx)

  // Build arguments: [type, props, ...children]
  let arguments : Array[Node] = [type_arg, props_arg]
  for child in children_args {
    arguments.push(child)
  }

  Node::CallExpression({
    expression: factory_expr,
    type_arguments: [],
    arguments,
    location,
  })
}

///|
/// Transform JSX fragment to classic React.Fragment call
fn transform_jsx_fragment_to_classic(
  children : Array[JsxChild],
  location : SourceLocation,
  fragment_factory : String,
  ctx : TransformerContext,
) -> Node {
  // Parse factory string (e.g., "React.createElement")
  let factory_parts = split_string(fragment_factory, '.')
  let factory_expr = if factory_parts.length() == 1 {
    Node::Identifier({ name: fragment_factory, location })
  } else {
    // React.createElement -> PropertyAccess
    let mut expr = Node::Identifier({ name: factory_parts[0], location })
    for i = 1; i < factory_parts.length(); i = i + 1 {
      expr = Node::PropertyAccessExpression({ expression: expr, name: factory_parts[i], location })
    }
    expr
  }

  // React.createElement(React.Fragment, null, ...children)
  let create_element = create_factory_expression("React.createElement", location)
  let children_args = jsx_children_to_args(children, ctx)

  let arguments : Array[Node] = [factory_expr, Node::NullLiteral({ location, })]
  for child in children_args {
    arguments.push(child)
  }

  Node::CallExpression({
    expression: create_element,
    type_arguments: [],
    arguments,
    location,
  })
}

///|
/// Transform JSX to automatic runtime (jsx/jsxs)
fn transform_jsx_to_automatic(
  tag_name : JsxTagName,
  attributes : Array[JsxAttribute],
  children : Array[JsxChild],
  location : SourceLocation,
  _import_source : String,
  _is_dev : Bool,
  ctx : TransformerContext,
) -> Node {
  // For automatic mode, we use _jsx or _jsxs
  // _jsx for single or no children, _jsxs for multiple children
  let transformed_children = jsx_children_to_args(children, ctx)
  let jsx_fn = if transformed_children.length() > 1 { "_jsxs" } else { "_jsx" }

  let jsx_expr = Node::Identifier({ name: jsx_fn, location })
  let type_arg = jsx_tag_name_to_node(tag_name, location)

  // For automatic mode, children go in props.children
  let props = jsx_attributes_to_props_with_children(
    attributes,
    transformed_children,
    location,
    ctx,
  )

  Node::CallExpression({
    expression: jsx_expr,
    type_arguments: [],
    arguments: [type_arg, props],
    location,
  })
}

///|
/// Transform JSX fragment to automatic runtime
fn transform_jsx_fragment_to_automatic(
  children : Array[JsxChild],
  location : SourceLocation,
  _import_source : String,
  _is_dev : Bool,
  ctx : TransformerContext,
) -> Node {
  let transformed_children = jsx_children_to_args(children, ctx)
  let jsx_fn = if transformed_children.length() > 1 { "_jsxs" } else { "_jsx" }

  let jsx_expr = Node::Identifier({ name: jsx_fn, location })
  let fragment_expr = Node::Identifier({ name: "_Fragment", location })

  // Create props with children
  let props = if transformed_children.length() == 0 {
    Node::ObjectLiteralExpression({ properties: [], location })
  } else if transformed_children.length() == 1 {
    Node::ObjectLiteralExpression({
      properties: [PropertyAssignment("children", transformed_children[0], location)],
      location,
    })
  } else {
    Node::ObjectLiteralExpression({
      properties: [
        PropertyAssignment(
          "children",
          Node::ArrayLiteralExpression({
            elements: transformed_children.map(fn(c) { Some(c) }),
            location,
          }),
          location,
        ),
      ],
      location,
    })
  }

  Node::CallExpression({
    expression: jsx_expr,
    type_arguments: [],
    arguments: [fragment_expr, props],
    location,
  })
}

///|
/// Create a factory expression from a dotted string like "React.createElement"
fn create_factory_expression(factory : String, location : SourceLocation) -> Node {
  let parts = split_string(factory, '.')
  if parts.length() == 1 {
    Node::Identifier({ name: factory, location })
  } else {
    let mut expr = Node::Identifier({ name: parts[0], location })
    for i = 1; i < parts.length(); i = i + 1 {
      expr = Node::PropertyAccessExpression({
        expression: expr,
        name: parts[i],
        location,
      })
    }
    expr
  }
}

///|
/// Convert JSX tag name to AST node
fn jsx_tag_name_to_node(tag_name : JsxTagName, location : SourceLocation) -> Node {
  match tag_name {
    Identifier(name, _) => {
      // Lowercase = intrinsic element (string), uppercase = component (identifier)
      if name.length() > 0 && is_lowercase(name[0]) {
        Node::StringLiteral({ value: name, location })
      } else {
        Node::Identifier({ name, location })
      }
    }
    NamespacedName(ns, name, _) => {
      // xml:href -> "xml:href"
      Node::StringLiteral({ value: ns + ":" + name, location })
    }
    PropertyAccess(expr, name, _) => {
      // Module.Component -> Module.Component (keep as identifier chain)
      Node::PropertyAccessExpression({ expression: expr, name, location })
    }
  }
}

///|
/// Check if a character code represents a lowercase letter
fn is_lowercase(code : Int) -> Bool {
  code >= 'a'.to_int() && code <= 'z'.to_int()
}

///|
/// Convert JSX attributes to props object
fn jsx_attributes_to_props(
  attributes : Array[JsxAttribute],
  location : SourceLocation,
  ctx : TransformerContext,
) -> Node {
  if attributes.length() == 0 {
    return Node::NullLiteral({ location, })
  }

  let properties : Array[ObjectProperty] = []
  let mut has_spread = false

  for attr in attributes {
    match attr {
      Attribute(attr_node) => {
        let name = jsx_attr_name_to_string(attr_node.name)
        let value = match attr_node.initializer {
          Some(init) => jsx_attr_value_to_node(init, ctx)
          None => Node::BooleanLiteral({ value: true, location: attr_node.location })
        }
        properties.push(PropertyAssignment(name, value, attr_node.location))
      }
      SpreadAttribute(expr, loc) => {
        has_spread = true
        properties.push(SpreadAssignment(transform(expr, ctx), loc))
      }
    }
  }

  // If we have spread attributes, we might need Object.assign
  // For simplicity, just use object literal with spread
  if has_spread {
    Node::ObjectLiteralExpression({ properties, location })
  } else {
    Node::ObjectLiteralExpression({ properties, location })
  }
}

///|
/// Convert JSX attributes to props with children (for automatic mode)
fn jsx_attributes_to_props_with_children(
  attributes : Array[JsxAttribute],
  children : Array[Node],
  location : SourceLocation,
  ctx : TransformerContext,
) -> Node {
  let properties : Array[ObjectProperty] = []

  for attr in attributes {
    match attr {
      Attribute(attr_node) => {
        let name = jsx_attr_name_to_string(attr_node.name)
        let value = match attr_node.initializer {
          Some(init) => jsx_attr_value_to_node(init, ctx)
          None => Node::BooleanLiteral({ value: true, location: attr_node.location })
        }
        properties.push(PropertyAssignment(name, value, attr_node.location))
      }
      SpreadAttribute(expr, loc) => {
        properties.push(SpreadAssignment(transform(expr, ctx), loc))
      }
    }
  }

  // Add children to props
  if children.length() == 1 {
    properties.push(PropertyAssignment("children", children[0], location))
  } else if children.length() > 1 {
    properties.push(
      PropertyAssignment(
        "children",
        Node::ArrayLiteralExpression({
          elements: children.map(fn(c) { Some(c) }),
          location,
        }),
        location,
      ),
    )
  }

  Node::ObjectLiteralExpression({ properties, location })
}

///|
/// Convert JSX attribute name to string
fn jsx_attr_name_to_string(name : JsxAttributeName) -> String {
  match name {
    JsxAttributeName::Identifier(id, _) => id
    JsxAttributeName::NamespacedName(ns, n, _) => ns + ":" + n
  }
}

///|
/// Convert JSX attribute value to AST node
fn jsx_attr_value_to_node(value : JsxAttributeValue, ctx : TransformerContext) -> Node {
  match value {
    StringLiteral(s, loc) => Node::StringLiteral({ value: s, location: loc })
    Expression(expr, _) => transform(expr, ctx)
    Element(elem, _) => transform(elem, ctx)
  }
}

///|
/// Convert JSX children to array of argument nodes
fn jsx_children_to_args(children : Array[JsxChild], ctx : TransformerContext) -> Array[Node] {
  let result : Array[Node] = []

  for child in children {
    match child {
      JsxChild::Text(text, loc) => {
        // Skip whitespace-only text
        let trimmed = trim_jsx_text(text)
        if trimmed.length() > 0 {
          result.push(Node::StringLiteral({ value: trimmed, location: loc }))
        }
      }
      JsxChild::Expression(jsx_expr) => {
        match jsx_expr.expression {
          Some(expr) => result.push(transform(expr, ctx))
          None => () // Skip empty expressions
        }
      }
      JsxChild::Element(elem, _) => {
        result.push(transform(elem, ctx))
      }
      JsxChild::Fragment(frag, _) => {
        result.push(transform(frag, ctx))
      }
    }
  }

  result
}

///|
/// Trim JSX text content (normalize whitespace)
fn trim_jsx_text(text : String) -> String {
  let result = StringBuilder::new()
  let mut last_was_space = true
  let mut has_content = false

  for i = 0; i < text.length(); i = i + 1 {
    let ch = text[i]
    if ch == ' '.to_int() || ch == '\t'.to_int() || ch == '\n'.to_int() || ch == '\r'.to_int() {
      if not(last_was_space) && has_content {
        result.write_char(' ')
        last_was_space = true
      }
    } else {
      result.write_char(Int::unsafe_to_char(ch))
      last_was_space = false
      has_content = true
    }
  }

  // Trim trailing space
  let s = result.to_string()
  if s.has_suffix(" ") {
    @utils.substr(s, start=0, end=s.length() - 1)
  } else {
    s
  }
}

///|
/// Split a string by a delimiter character
fn split_string(s : String, delim : Char) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  let delim_code = delim.to_int()

  for i = 0; i < s.length(); i = i + 1 {
    if s[i] == delim_code {
      result.push(current.to_string())
      current.reset()
    } else {
      current.write_char(Int::unsafe_to_char(s[i]))
    }
  }

  // Don't forget the last part
  let last = current.to_string()
  if last.length() > 0 || result.length() > 0 {
    result.push(last)
  }

  result
}
