// Unresolved type-name (TS2304) support.
//
// The checker resolves type annotations through many independent code paths,
// and not all of them register in-scope type parameters or local declarations
// before resolving member/parameter annotations. To keep TS2304 free of false
// positives, we pre-collect every name that is *declared anywhere in the file*
// (type parameters, interfaces, classes, type aliases, enums, namespaces,
// imports, value bindings) and suppress TS2304 for those names. A name that is
// never declared in the file and is not a standard-library global is genuinely
// unresolvable, which is exactly when tsc reports TS2304 in type position.
//
// This is deliberately conservative: an out-of-scope-but-declared-elsewhere
// name is not reported (missing error), which costs far less than a false
// positive.

///|
/// Sentinel entry in `declared_type_names` meaning "suppress all TS2304
/// reporting". Used when the file has parse errors: a partial AST makes both
/// the symbol table and the declared-name collection unreliable, so any
/// unresolved-name error would likely be a false positive. "*" can never be
/// a real type name.
pub const SUPPRESS_ALL_UNRESOLVED_TYPE_NAMES : String = "*"

///|
/// Collect all names declared anywhere in the file that could legitimately
/// appear in type position (or that would produce a different error code than
/// TS2304, e.g. TS2749 for values used as types).
pub fn collect_declared_type_names(
  statements : Array[Node],
) -> @hashset.HashSet[String] {
  let names : @hashset.HashSet[String] = @hashset.HashSet([])
  for stmt in statements {
    collect_names_from_node(stmt, names)
  }
  names
}

///|
fn collect_names_opt(node : Node?, names : @hashset.HashSet[String]) -> Unit {
  match node {
    Some(n) => collect_names_from_node(n, names)
    None => ()
  }
}

///|
fn collect_names_from_nodes(
  nodes : Array[Node],
  names : @hashset.HashSet[String],
) -> Unit {
  for n in nodes {
    collect_names_from_node(n, names)
  }
}

///|
/// Add type parameter names (and walk their constraint/default type nodes,
/// which can contain further declarations like infer/mapped-type parameters)
fn collect_type_parameter_names(
  type_parameters : Array[TypeParameter],
  names : @hashset.HashSet[String],
) -> Unit {
  for tp in type_parameters {
    names.add(tp.name)
    collect_names_opt(tp.constraint, names)
    collect_names_opt(tp.default, names)
  }
}

///|
/// Add binding names from an identifier or destructuring pattern
fn collect_binding_names_into_set(
  node : Node,
  names : @hashset.HashSet[String],
) -> Unit {
  match node {
    Identifier(id) => names.add(id.name)
    ArrayBindingPattern(pat) =>
      for el in pat.elements {
        match el {
          Some(e) => collect_binding_names_into_set(e, names)
          None => ()
        }
      }
    ObjectBindingPattern(pat) =>
      for prop in pat.properties {
        collect_binding_names_into_set(prop.name, names)
        collect_names_opt(prop.initializer, names)
      }
    BindingElement(be) => {
      collect_binding_names_into_set(be.name, names)
      collect_names_opt(be.initializer, names)
    }
    _ => ()
  }
}

///|
fn collect_names_from_variable_declarations(
  declarations : Array[VariableDeclaration],
  names : @hashset.HashSet[String],
) -> Unit {
  for decl in declarations {
    collect_binding_names_into_set(decl.name, names)
    collect_names_opt(decl.type_annotation, names)
    collect_names_opt(decl.initializer, names)
  }
}

///|
fn collect_names_from_heritage_clauses(
  heritage_clauses : Array[HeritageClause],
  names : @hashset.HashSet[String],
) -> Unit {
  for clause in heritage_clauses {
    collect_names_from_nodes(clause.types, names)
  }
}

///|
fn collect_names_from_function_expression(
  func : FunctionExpression,
  names : @hashset.HashSet[String],
) -> Unit {
  match func.name {
    Some(n) => names.add(n)
    None => ()
  }
  collect_type_parameter_names(func.type_parameters, names)
  collect_names_from_nodes(func.parameters, names)
  collect_names_opt(func.return_type, names)
  collect_names_from_node(func.body, names)
}

///|
fn collect_names_from_object_property(
  prop : ObjectProperty,
  names : @hashset.HashSet[String],
) -> Unit {
  match prop {
    PropertyAssignment(_, value, _) => collect_names_from_node(value, names)
    ShorthandProperty(_, _) => ()
    SpreadAssignment(expr, _) => collect_names_from_node(expr, names)
    MethodDeclaration(_, func, _)
    | GetAccessor(_, func, _)
    | SetAccessor(_, func, _) =>
      collect_names_from_function_expression(func, names)
    ComputedPropertyAssignment(key, value, _) => {
      collect_names_from_node(key, names)
      collect_names_from_node(value, names)
    }
    ComputedMethodDeclaration(key, func, _)
    | ComputedGetAccessor(key, func, _)
    | ComputedSetAccessor(key, func, _) => {
      collect_names_from_node(key, names)
      collect_names_from_function_expression(func, names)
    }
  }
}

///|
fn collect_names_from_class(
  class_decl : ClassDeclaration,
  names : @hashset.HashSet[String],
) -> Unit {
  match class_decl.name {
    Some(Identifier(id)) => names.add(id.name)
    _ => ()
  }
  collect_type_parameter_names(class_decl.type_parameters, names)
  collect_names_from_heritage_clauses(class_decl.heritage_clauses, names)
  collect_names_from_nodes(class_decl.members, names)
  collect_names_from_nodes(class_decl.decorators, names)
}

///|
/// Recursive walk over statements, expressions, class members and type nodes.
/// Adds every declared name to `names`.
fn collect_names_from_node(
  node : Node,
  names : @hashset.HashSet[String],
) -> Unit {
  match node {
    SourceFile(sf) => collect_names_from_nodes(sf.statements, names)

    // Declarations
    VariableStatement(vs) =>
      collect_names_from_variable_declarations(vs.declarations, names)
    UsingStatement(us) =>
      collect_names_from_variable_declarations(us.declarations, names)
    FunctionDeclaration(func) => {
      match func.name {
        Some(Identifier(id)) => names.add(id.name)
        _ => ()
      }
      collect_type_parameter_names(func.type_parameters, names)
      collect_names_from_nodes(func.parameters, names)
      collect_names_opt(func.return_type, names)
      collect_names_opt(func.body, names)
    }
    ClassDeclaration(class_decl) | ClassExpression(class_decl) =>
      collect_names_from_class(class_decl, names)
    InterfaceDeclaration(iface) => {
      names.add(iface.name)
      collect_type_parameter_names(iface.type_parameters, names)
      collect_names_from_heritage_clauses(iface.heritage_clauses, names)
      collect_names_from_nodes(iface.members, names)
    }
    TypeAliasDeclaration(alias) => {
      names.add(alias.name)
      collect_type_parameter_names(alias.type_parameters, names)
      collect_names_from_node(alias.type_node, names)
    }
    EnumDeclaration(enum_decl) => {
      names.add(enum_decl.name)
      for enum_member in enum_decl.members {
        collect_names_opt(enum_member.initializer, names)
      }
    }
    ModuleDeclaration(mod_decl) => {
      names.add(mod_decl.name)
      collect_names_opt(mod_decl.body, names)
    }
    ImportDeclaration(import_decl) =>
      match import_decl.import_clause {
        Some(clause) => {
          match clause.name {
            Some(n) => names.add(n)
            None => ()
          }
          match clause.named_bindings {
            Some(NamespaceImport(n, _)) => names.add(n)
            Some(NamedImports(specifiers, _)) =>
              for spec in specifiers {
                names.add(spec.name)
              }
            None => ()
          }
        }
        None => ()
      }
    ImportEqualsDeclaration(ie) => names.add(ie.name)
    ExportAssignment(ea) => collect_names_from_node(ea.expression, names)

    // Class members
    PropertyDeclaration(prop) => {
      collect_names_opt(prop.computed_name_expr, names)
      collect_names_opt(prop.type_annotation, names)
      collect_names_opt(prop.initializer, names)
      collect_names_from_nodes(prop.decorators, names)
    }
    MethodDeclaration(meth) => {
      collect_names_opt(meth.computed_name_expr, names)
      collect_type_parameter_names(meth.type_parameters, names)
      collect_names_from_nodes(meth.parameters, names)
      collect_names_opt(meth.return_type, names)
      collect_names_opt(meth.body, names)
      collect_names_from_nodes(meth.decorators, names)
    }
    ConstructorDeclaration(ctor) => {
      collect_names_from_nodes(ctor.parameters, names)
      collect_names_opt(ctor.body, names)
      collect_names_from_nodes(ctor.decorators, names)
    }
    GetAccessor(acc) => {
      collect_names_opt(acc.computed_name_expr, names)
      collect_names_opt(acc.return_type, names)
      collect_names_opt(acc.body, names)
      collect_names_from_nodes(acc.decorators, names)
    }
    SetAccessor(acc) => {
      collect_names_opt(acc.computed_name_expr, names)
      collect_names_from_node(acc.parameter, names)
      collect_names_opt(acc.body, names)
      collect_names_from_nodes(acc.decorators, names)
    }
    StaticBlock(block) => collect_names_from_node(block.body, names)
    AutoAccessor(acc) => {
      collect_names_opt(acc.type_annotation, names)
      collect_names_opt(acc.initializer, names)
      collect_names_from_nodes(acc.decorators, names)
    }
    IndexSignatureDeclaration(sig) => {
      collect_names_from_node(sig.parameter_type, names)
      collect_names_from_node(sig.return_type, names)
    }
    Parameter(param) => {
      collect_binding_names_into_set(param.name, names)
      collect_names_opt(param.type_annotation, names)
      collect_names_opt(param.initializer, names)
      collect_names_from_nodes(param.decorators, names)
    }
    Decorator(dec) => collect_names_from_node(dec.expression, names)

    // Control flow statements
    IfStatement(if_stmt) => {
      collect_names_from_node(if_stmt.condition, names)
      collect_names_from_node(if_stmt.then_statement, names)
      collect_names_opt(if_stmt.else_statement, names)
    }
    SwitchStatement(switch_stmt) => {
      collect_names_from_node(switch_stmt.expression, names)
      for case_clause in switch_stmt.cases {
        collect_names_opt(case_clause.expression, names)
        collect_names_from_nodes(case_clause.statements, names)
      }
    }
    ForStatement(for_stmt) => {
      collect_names_opt(for_stmt.initializer, names)
      collect_names_opt(for_stmt.condition, names)
      collect_names_opt(for_stmt.incrementor, names)
      collect_names_from_node(for_stmt.statement, names)
    }
    ForInStatement(for_in) => {
      collect_names_from_node(for_in.initializer, names)
      collect_names_from_node(for_in.expression, names)
      collect_names_from_node(for_in.statement, names)
    }
    ForOfStatement(for_of) => {
      collect_names_from_node(for_of.initializer, names)
      collect_names_from_node(for_of.expression, names)
      collect_names_from_node(for_of.statement, names)
    }
    WhileStatement(while_stmt) => {
      collect_names_from_node(while_stmt.condition, names)
      collect_names_from_node(while_stmt.statement, names)
    }
    DoWhileStatement(do_stmt) => {
      collect_names_from_node(do_stmt.statement, names)
      collect_names_from_node(do_stmt.condition, names)
    }
    ReturnStatement(ret) => collect_names_opt(ret.expression, names)
    ThrowStatement(throw_stmt) =>
      collect_names_from_node(throw_stmt.expression, names)
    TryStatement(try_stmt) => {
      collect_names_from_node(try_stmt.try_block, names)
      match try_stmt.catch_clause {
        Some(catch_clause) => {
          collect_names_opt(catch_clause.variable_declaration, names)
          match catch_clause.variable_declaration {
            Some(v) => collect_binding_names_into_set(v, names)
            None => ()
          }
          collect_names_from_node(catch_clause.block, names)
        }
        None => ()
      }
      collect_names_opt(try_stmt.finally_block, names)
    }
    BlockStatement(block) => collect_names_from_nodes(block.statements, names)
    ExpressionStatement(expr_stmt) =>
      collect_names_from_node(expr_stmt.expression, names)
    LabeledStatement(labeled) =>
      collect_names_from_node(labeled.statement, names)
    WithStatement(with_stmt) => {
      collect_names_from_node(with_stmt.expression, names)
      collect_names_from_node(with_stmt.statement, names)
    }

    // Expressions
    BinaryExpression(bin) => {
      collect_names_from_node(bin.left, names)
      collect_names_from_node(bin.right, names)
    }
    UnaryExpression(unary) => collect_names_from_node(unary.operand, names)
    ConditionalExpression(cond) => {
      collect_names_from_node(cond.condition, names)
      collect_names_from_node(cond.when_true, names)
      collect_names_from_node(cond.when_false, names)
    }
    CallExpression(call) => {
      collect_names_from_node(call.expression, names)
      collect_names_from_nodes(call.type_arguments, names)
      collect_names_from_nodes(call.arguments, names)
    }
    NewExpression(new_expr) => {
      collect_names_from_node(new_expr.expression, names)
      collect_names_from_nodes(new_expr.type_arguments, names)
      match new_expr.arguments {
        Some(args) => collect_names_from_nodes(args, names)
        None => ()
      }
    }
    PropertyAccessExpression(pae) =>
      collect_names_from_node(pae.expression, names)
    ElementAccessExpression(eae) => {
      collect_names_from_node(eae.expression, names)
      collect_names_from_node(eae.argument_expression, names)
    }
    ArrowFunction(arrow) => {
      collect_type_parameter_names(arrow.type_parameters, names)
      collect_names_from_nodes(arrow.parameters, names)
      collect_names_opt(arrow.return_type, names)
      collect_names_from_node(arrow.body, names)
    }
    FunctionExpression(func) =>
      collect_names_from_function_expression(func, names)
    ArrayLiteralExpression(arr) =>
      for el in arr.elements {
        collect_names_opt(el, names)
      }
    ObjectLiteralExpression(obj) =>
      for prop in obj.properties {
        collect_names_from_object_property(prop, names)
      }
    ParenthesizedExpression(paren) =>
      collect_names_from_node(paren.expression, names)
    TemplateExpression(template) =>
      for span in template.template_spans {
        collect_names_from_node(span.expression, names)
      }
    TaggedTemplateExpression(tagged) => {
      collect_names_from_node(tagged.tag, names)
      collect_names_from_node(tagged.template, names)
      collect_names_from_nodes(tagged.type_arguments, names)
    }
    AsExpression(as_expr) => {
      collect_names_from_node(as_expr.expression, names)
      collect_names_from_node(as_expr.type_node, names)
    }
    SatisfiesExpression(sat) => {
      collect_names_from_node(sat.expression, names)
      collect_names_from_node(sat.type_node, names)
    }
    TypeAssertionExpression(assertion) => {
      collect_names_from_node(assertion.type_node, names)
      collect_names_from_node(assertion.expression, names)
    }
    NonNullExpression(nn) => collect_names_from_node(nn.expression, names)
    SpreadExpression(spread) =>
      collect_names_from_node(spread.expression, names)
    OptionalChain(chain) => {
      collect_names_from_node(chain.expression, names)
      match chain.chain {
        Call(args) => collect_names_from_nodes(args, names)
        Element(el) => collect_names_from_node(el, names)
        Property(_) => ()
      }
    }
    AwaitExpression(await_expr) =>
      collect_names_from_node(await_expr.expression, names)
    YieldExpression(yield_expr) =>
      collect_names_opt(yield_expr.expression, names)
    BindingElement(be) => {
      collect_binding_names_into_set(be.name, names)
      collect_names_opt(be.initializer, names)
    }
    ArrayBindingPattern(_) | ObjectBindingPattern(_) =>
      collect_binding_names_into_set(node, names)

    // Type nodes: walk them for nested type-parameter declarations
    // (function types, constructor types, mapped types, infer types)
    FunctionType(ft) => {
      collect_type_parameter_names(ft.type_parameters, names)
      collect_names_from_nodes(ft.parameters, names)
      collect_names_from_node(ft.return_type, names)
    }
    ConstructorType(ct) => {
      collect_type_parameter_names(ct.type_parameters, names)
      collect_names_from_nodes(ct.parameters, names)
      collect_names_from_node(ct.return_type, names)
    }
    MappedType(mapped) => {
      names.add(mapped.type_parameter.name)
      collect_names_opt(mapped.type_parameter.constraint, names)
      collect_names_opt(mapped.type_parameter.default, names)
      collect_names_opt(mapped.name_type, names)
      collect_names_opt(mapped.type_node, names)
    }
    InferType(infer) => names.add(infer.type_parameter)
    TypeReference(type_ref) =>
      collect_names_from_nodes(type_ref.type_arguments, names)
    UnionType(union_type) =>
      collect_names_from_nodes(union_type.types, names)
    IntersectionType(intersection) =>
      collect_names_from_nodes(intersection.types, names)
    ArrayType(array_type) =>
      collect_names_from_node(array_type.element_type, names)
    TupleType(tuple) => collect_names_from_nodes(tuple.element_types, names)
    ConditionalType(cond) => {
      collect_names_from_node(cond.check_type, names)
      collect_names_from_node(cond.extends_type, names)
      collect_names_from_node(cond.true_type, names)
      collect_names_from_node(cond.false_type, names)
    }
    IndexedAccessType(idx) => {
      collect_names_from_node(idx.object_type, names)
      collect_names_from_node(idx.index_type, names)
    }
    OptionalType(opt) => collect_names_from_node(opt.element_type, names)
    RestType(rest) => collect_names_from_node(rest.element_type, names)
    NamedTupleMember(member) =>
      collect_names_from_node(member.element_type, names)
    TypePredicate(pred) => collect_names_opt(pred.type_node, names)
    TypeOperator(op) => collect_names_from_node(op.type_node, names)
    TemplateLiteralType(template) =>
      for span in template.spans {
        collect_names_from_node(span.type_node, names)
      }
    TypeLiteral(type_literal) =>
      collect_names_from_nodes(type_literal.members, names)
    TypeLiteralProperty(prop) => collect_names_opt(prop.type_node, names)
    ParenthesizedType(paren) =>
      collect_names_from_node(paren.type_node, names)

    // Leaves and everything else: nothing to collect
    _ => ()
  }
}
