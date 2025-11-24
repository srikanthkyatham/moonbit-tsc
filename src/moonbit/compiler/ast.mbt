// AST node types for TypeScript
// Represents the Abstract Syntax Tree structure

///|
/// Main AST node type - discriminated union of all possible nodes
pub enum Node {
  // Source File (root)
  SourceFile(SourceFile)

  // Statements
  VariableStatement(VariableStatement)
  FunctionDeclaration(FunctionDeclaration)
  ClassDeclaration(ClassDeclaration)
  InterfaceDeclaration(InterfaceDeclaration)
  TypeAliasDeclaration(TypeAliasDeclaration)
  EnumDeclaration(EnumDeclaration)
  ModuleDeclaration(ModuleDeclaration)
  ImportDeclaration(ImportDeclaration)
  ExportDeclaration(ExportDeclaration)
  ExportAssignment(ExportAssignment)

  // Control Flow Statements
  IfStatement(IfStatement)
  SwitchStatement(SwitchStatement)
  ForStatement(ForStatement)
  ForInStatement(ForInStatement)
  ForOfStatement(ForOfStatement)
  WhileStatement(WhileStatement)
  DoWhileStatement(DoWhileStatement)
  BreakStatement(BreakStatement)
  ContinueStatement(ContinueStatement)
  ReturnStatement(ReturnStatement)
  ThrowStatement(ThrowStatement)
  TryStatement(TryStatement)

  // Other Statements
  BlockStatement(BlockStatement)
  ExpressionStatement(ExpressionStatement)
  EmptyStatement(EmptyStatement)
  LabeledStatement(LabeledStatement)
  WithStatement(WithStatement)
  DebuggerStatement(DebuggerStatement)

  // Expressions
  BinaryExpression(BinaryExpression)
  UnaryExpression(UnaryExpression)
  ConditionalExpression(ConditionalExpression)
  CallExpression(CallExpression)
  NewExpression(NewExpression)
  PropertyAccessExpression(PropertyAccessExpression)
  ElementAccessExpression(ElementAccessExpression)
  ArrowFunction(ArrowFunction)
  FunctionExpression(FunctionExpression)
  ArrayLiteralExpression(ArrayLiteralExpression)
  ObjectLiteralExpression(ObjectLiteralExpression)
  ParenthesizedExpression(ParenthesizedExpression)
  TemplateExpression(TemplateExpression)
  AsExpression(AsExpression)
  TypeAssertionExpression(TypeAssertionExpression)
  NonNullExpression(NonNullExpression)
  SpreadExpression(SpreadExpression)

  // Binding Patterns
  ArrayBindingPattern(ArrayBindingPattern)
  ObjectBindingPattern(ObjectBindingPattern)

  // Primary Expressions
  Identifier(Identifier)
  NumericLiteral(NumericLiteral)
  StringLiteral(StringLiteral)
  BooleanLiteral(BooleanLiteral)
  NullLiteral(NullLiteral)
  ThisExpression(ThisExpression)
  SuperExpression(SuperExpression)

  // Type Nodes
  TypeReference(TypeReference)
  UnionType(UnionType)
  IntersectionType(IntersectionType)
  FunctionType(FunctionType)
  ArrayType(ArrayType)
  TupleType(TupleType)
  LiteralType(LiteralType)
  KeywordType(KeywordType)
  MappedType(MappedType)
  ConditionalType(ConditionalType)
  IndexedAccessType(IndexedAccessType)

  // Other
  Parameter(Parameter)
  PropertyDeclaration(PropertyDeclaration)
  IndexSignatureDeclaration(IndexSignatureDeclaration)
  MethodDeclaration(MethodDeclaration)
  ConstructorDeclaration(ConstructorDeclaration)
  GetAccessor(GetAccessor)
  SetAccessor(SetAccessor)
} derive(Show)

///|
/// Source file - root of AST
pub struct SourceFile {
  file_path : String
  statements : Array[Node]
  end_of_file_token : Token
  has_no_default_lib : Bool
} derive(Show)

///|
/// Variable statement (let/const/var)
pub struct VariableStatement {
  declarations : Array[VariableDeclaration]
  is_const : Bool
  is_let : Bool
  location : SourceLocation
} derive(Show)

///|
pub struct VariableDeclaration {
  name : Node // Identifier or binding pattern
  type_annotation : Node?
  initializer : Node?
  location : SourceLocation
} derive(Show)

///|
/// Function declaration
pub struct FunctionDeclaration {
  name : Node? // Identifier (None for anonymous)
  type_parameters : Array[TypeParameter]
  parameters : Array[Node]
  return_type : Node?
  body : Node? // BlockStatement
  is_async : Bool
  is_generator : Bool
  location : SourceLocation
} derive(Show)

///|
/// Type parameter (generic)
pub struct TypeParameter {
  name : String
  constraint : Node?
  default : Node?
  location : SourceLocation
} derive(Show)

///|
/// Class declaration
pub struct ClassDeclaration {
  name : Node?
  type_parameters : Array[TypeParameter]
  heritage_clauses : Array[HeritageClause]
  members : Array[Node]
  is_abstract : Bool
  location : SourceLocation
} derive(Show)

///|
pub struct HeritageClause {
  kind : HeritageKind
  types : Array[Node]
  location : SourceLocation
} derive(Show)

///|
#valtype
pub enum HeritageKind {
  Extends
  Implements
} derive(Show, Eq)

///|
/// Interface declaration
pub struct InterfaceDeclaration {
  name : String
  type_parameters : Array[TypeParameter]
  heritage_clauses : Array[HeritageClause]
  members : Array[Node]
  location : SourceLocation
} derive(Show)

///|
/// Type alias
pub struct TypeAliasDeclaration {
  name : String
  type_parameters : Array[TypeParameter]
  type_node : Node
  location : SourceLocation
} derive(Show)

///|
/// Enum declaration
pub struct EnumDeclaration {
  name : String
  members : Array[EnumMember]
  is_const : Bool
  location : SourceLocation
} derive(Show)

///|
pub struct EnumMember {
  name : String
  initializer : Node?
  location : SourceLocation
} derive(Show)

///|
/// Module/namespace declaration
pub struct ModuleDeclaration {
  name : String
  body : Node?
  location : SourceLocation
} derive(Show)

///|
/// Import declaration
pub struct ImportDeclaration {
  import_clause : ImportClause?
  module_specifier : String
  location : SourceLocation
} derive(Show)

///|
pub struct ImportClause {
  name : String? // Default import
  named_bindings : NamedImports?
  location : SourceLocation
} derive(Show)

///|
pub enum NamedImports {
  NamespaceImport(String, SourceLocation) // * as name
  NamedImports(Array[ImportSpecifier], SourceLocation)
} derive(Show)

///|
pub struct ImportSpecifier {
  property_name : String? // For "import { foo as bar }"
  name : String
  location : SourceLocation
} derive(Show)

///|
/// Export declaration
pub struct ExportDeclaration {
  export_clause : NamedExports?
  module_specifier : String?
  location : SourceLocation
} derive(Show)

///|
pub enum NamedExports {
  NamedExports(Array[ExportSpecifier], SourceLocation)
} derive(Show)

///|
pub struct ExportSpecifier {
  property_name : String?
  name : String
  location : SourceLocation
} derive(Show)

///|
pub struct ExportAssignment {
  expression : Node
  is_export_equals : Bool
  location : SourceLocation
} derive(Show)

///|
/// Control flow statements
pub struct IfStatement {
  condition : Node
  then_statement : Node
  else_statement : Node?
  location : SourceLocation
} derive(Show)

///|
pub struct SwitchStatement {
  expression : Node
  cases : Array[CaseClause]
  location : SourceLocation
} derive(Show)

///|
pub struct CaseClause {
  expression : Node? // None for default
  statements : Array[Node]
  location : SourceLocation
} derive(Show)

///|
pub struct ForStatement {
  initializer : Node?
  condition : Node?
  incrementor : Node?
  statement : Node
  location : SourceLocation
} derive(Show)

///|
pub struct ForInStatement {
  initializer : Node
  expression : Node
  statement : Node
  location : SourceLocation
} derive(Show)

///|
pub struct ForOfStatement {
  await_modifier : Bool
  initializer : Node
  expression : Node
  statement : Node
  location : SourceLocation
} derive(Show)

///|
pub struct WhileStatement {
  condition : Node
  statement : Node
  location : SourceLocation
} derive(Show)

///|
pub struct DoWhileStatement {
  statement : Node
  condition : Node
  location : SourceLocation
} derive(Show)

///|
pub struct BreakStatement {
  label : String?
  location : SourceLocation
} derive(Show)

///|
pub struct ContinueStatement {
  label : String?
  location : SourceLocation
} derive(Show)

///|
pub struct ReturnStatement {
  expression : Node?
  location : SourceLocation
} derive(Show)

///|
pub struct ThrowStatement {
  expression : Node
  location : SourceLocation
} derive(Show)

///|
pub struct TryStatement {
  try_block : Node
  catch_clause : CatchClause?
  finally_block : Node?
  location : SourceLocation
} derive(Show)

///|
pub struct CatchClause {
  variable_declaration : Node?
  block : Node
  location : SourceLocation
} derive(Show)

///|
/// Other statements
pub struct BlockStatement {
  statements : Array[Node]
  location : SourceLocation
} derive(Show)

///|
pub struct ExpressionStatement {
  expression : Node
  location : SourceLocation
} derive(Show)

///|
pub struct EmptyStatement {
  location : SourceLocation
} derive(Show)

///|
pub struct LabeledStatement {
  label : String
  statement : Node
  location : SourceLocation
} derive(Show)

///|
pub struct WithStatement {
  expression : Node
  statement : Node
  location : SourceLocation
} derive(Show)

///|
pub struct DebuggerStatement {
  location : SourceLocation
} derive(Show)

///|
/// Binary expressions
pub struct BinaryExpression {
  left : Node
  operator : BinaryOperator
  right : Node
  location : SourceLocation
} derive(Show)

///|
#valtype
pub enum BinaryOperator {
  // Arithmetic
  Add // +
  Subtract // -
  Multiply // *
  Divide // /
  Remainder // %
  Exponentiate // **

  // Comparison
  LessThan // <
  GreaterThan // >
  LessThanEquals // <=
  GreaterThanEquals // >=
  Equals // ==
  NotEquals // !=
  StrictEquals // ===
  StrictNotEquals // !==

  // Logical
  LogicalAnd // &&
  LogicalOr // ||
  NullishCoalescing // ??

  // Bitwise
  BitwiseAnd // &
  BitwiseOr // |
  BitwiseXor // ^
  LeftShift // <<
  RightShift // >>
  UnsignedRightShift // >>>

  // Assignment
  Assign // =
  AddAssign // +=
  SubtractAssign // -=
  MultiplyAssign // *=
  DivideAssign // /=
  RemainderAssign // %=
  BitwiseAndAssign // &=
  BitwiseOrAssign // |=
  BitwiseXorAssign // ^=

  // Other
  In
  InstanceOf
  Comma
} derive(Show, Eq)

///|
/// Unary expressions
pub struct UnaryExpression {
  operator : UnaryOperator
  operand : Node
  is_prefix : Bool
  location : SourceLocation
} derive(Show)

///|
#valtype
pub enum UnaryOperator {
  Plus // +
  Minus // -
  LogicalNot // !
  BitwiseNot // ~
  Increment // ++
  Decrement // --
  TypeOf
  Void
  Delete
} derive(Show, Eq)

///|
/// Conditional (ternary) expression
pub struct ConditionalExpression {
  condition : Node
  when_true : Node
  when_false : Node
  location : SourceLocation
} derive(Show)

///|
/// Call expression
pub struct CallExpression {
  expression : Node
  type_arguments : Array[Node]
  arguments : Array[Node]
  location : SourceLocation
} derive(Show)

///|
/// New expression
pub struct NewExpression {
  expression : Node
  type_arguments : Array[Node]
  arguments : Array[Node]?
  location : SourceLocation
} derive(Show)

///|
/// Property access (obj.property)
pub struct PropertyAccessExpression {
  expression : Node
  name : String
  location : SourceLocation
} derive(Show)

///|
/// Element access (obj[element])
pub struct ElementAccessExpression {
  expression : Node
  argument_expression : Node
  location : SourceLocation
} derive(Show)

///|
/// Arrow function
pub struct ArrowFunction {
  type_parameters : Array[TypeParameter]
  parameters : Array[Node]
  return_type : Node?
  body : Node // Block or expression
  is_async : Bool
  location : SourceLocation
} derive(Show)

///|
/// Function expression
pub struct FunctionExpression {
  name : String?
  type_parameters : Array[TypeParameter]
  parameters : Array[Node]
  return_type : Node?
  body : Node
  is_async : Bool
  is_generator : Bool
  location : SourceLocation
} derive(Show)

///|
/// Array literal [1, 2, 3]
pub struct ArrayLiteralExpression {
  elements : Array[Node?] // None for holes
  location : SourceLocation
} derive(Show)

///|
/// Object literal { key: value }
pub struct ObjectLiteralExpression {
  properties : Array[ObjectProperty]
  location : SourceLocation
} derive(Show)

///|
pub enum ObjectProperty {
  PropertyAssignment(String, Node, SourceLocation)
  ShorthandProperty(String, SourceLocation)
  SpreadAssignment(Node, SourceLocation)
  MethodDeclaration(String, FunctionExpression, SourceLocation)
  GetAccessor(String, FunctionExpression, SourceLocation)
  SetAccessor(String, FunctionExpression, SourceLocation)
} derive(Show)

///|
/// Parenthesized expression
pub struct ParenthesizedExpression {
  expression : Node
  location : SourceLocation
} derive(Show)

///|
/// Template expression
pub struct TemplateExpression {
  head : String
  template_spans : Array[TemplateSpan]
  location : SourceLocation
} derive(Show)

///|
pub struct TemplateSpan {
  expression : Node
  literal : String
  location : SourceLocation
} derive(Show)

///|
/// Type assertion (as)
pub struct AsExpression {
  expression : Node
  type_node : Node
  location : SourceLocation
} derive(Show)

///|
/// Type assertion (<Type>expr)
pub struct TypeAssertionExpression {
  type_node : Node
  expression : Node
  location : SourceLocation
} derive(Show)

///|
/// Non-null assertion (expr!)
pub struct NonNullExpression {
  expression : Node
  location : SourceLocation
} derive(Show)

///|
/// Spread (...expr)
pub struct SpreadExpression {
  expression : Node
  location : SourceLocation
} derive(Show)

///|
/// Array binding pattern for destructuring ([a, b])
pub struct ArrayBindingPattern {
  elements : Array[Node?] // Can be Identifier, ArrayBindingPattern, ObjectBindingPattern, or None for holes
  location : SourceLocation
} derive(Show)

///|
/// Object binding pattern for destructuring ({ x, y })
pub struct ObjectBindingPattern {
  properties : Array[BindingElement]
  location : SourceLocation
} derive(Show)

///|
/// Binding element in object pattern
pub struct BindingElement {
  property_name : String // The property name from the source object
  name : Node // The binding name (Identifier or nested pattern)
  location : SourceLocation
} derive(Show)

///|
/// Primary expressions
pub struct Identifier {
  name : String
  location : SourceLocation
} derive(Show)

///|
pub struct NumericLiteral {
  value : String
  location : SourceLocation
} derive(Show)

///|
pub struct StringLiteral {
  value : String
  location : SourceLocation
} derive(Show)

///|
pub struct BooleanLiteral {
  value : Bool
  location : SourceLocation
} derive(Show)

///|
pub struct NullLiteral {
  location : SourceLocation
} derive(Show)

///|
pub struct ThisExpression {
  location : SourceLocation
} derive(Show)

///|
pub struct SuperExpression {
  location : SourceLocation
} derive(Show)

///|
/// Type nodes
pub struct TypeReference {
  type_name : String
  type_arguments : Array[Node]
  location : SourceLocation
} derive(Show)

///|
pub struct UnionType {
  types : Array[Node]
  location : SourceLocation
} derive(Show)

///|
pub struct IntersectionType {
  types : Array[Node]
  location : SourceLocation
} derive(Show)

///|
pub struct FunctionType {
  type_parameters : Array[TypeParameter]
  parameters : Array[Node]
  return_type : Node
  location : SourceLocation
} derive(Show)

///|
pub struct ArrayType {
  element_type : Node
  location : SourceLocation
} derive(Show)

///|
pub struct TupleType {
  element_types : Array[Node]
  location : SourceLocation
} derive(Show)

///|
pub struct LiteralType {
  literal : Node
  location : SourceLocation
} derive(Show)

///|
pub struct KeywordType {
  kind : TypeKeyword
  location : SourceLocation
} derive(Show)

///|
#valtype
pub enum TypeKeyword {
  Any
  Unknown
  Never
  Void
  Undefined
  Null
  Boolean
  Number
  String
  Symbol
  Object
} derive(Show, Eq)

///|
pub struct MappedType {
  type_parameter : TypeParameter
  type_node : Node?
  location : SourceLocation
} derive(Show)

///|
pub struct ConditionalType {
  check_type : Node
  extends_type : Node
  true_type : Node
  false_type : Node
  location : SourceLocation
} derive(Show)

///|
pub struct IndexedAccessType {
  object_type : Node
  index_type : Node
  location : SourceLocation
} derive(Show)

///|
/// Parameter
pub struct Parameter {
  name : Node
  type_annotation : Node?
  initializer : Node?
  is_optional : Bool
  is_rest : Bool
  location : SourceLocation
} derive(Show)

///|
/// Class members
pub struct PropertyDeclaration {
  name : String
  type_annotation : Node?
  initializer : Node?
  modifiers : Array[Modifier]
  location : SourceLocation
} derive(Show)

///|
pub struct IndexSignatureDeclaration {
  parameter_name : String
  parameter_type : Node
  return_type : Node
  location : SourceLocation
} derive(Show)

///|
pub struct MethodDeclaration {
  name : String
  type_parameters : Array[TypeParameter]
  parameters : Array[Node]
  return_type : Node?
  body : Node?
  modifiers : Array[Modifier]
  is_async : Bool
  is_generator : Bool
  location : SourceLocation
} derive(Show)

///|
pub struct ConstructorDeclaration {
  parameters : Array[Node]
  body : Node?
  location : SourceLocation
} derive(Show)

///|
pub struct GetAccessor {
  name : String
  return_type : Node?
  body : Node?
  modifiers : Array[Modifier]
  location : SourceLocation
} derive(Show)

///|
pub struct SetAccessor {
  name : String
  parameter : Node
  body : Node?
  modifiers : Array[Modifier]
  location : SourceLocation
} derive(Show)

///|
/// Modifiers
#valtype
pub enum Modifier {
  Public
  Private
  Protected
  Static
  Readonly
  Abstract
  Async
  Export
  Default
  Declare
  Const
} derive(Show, Eq)

///|
/// Helper to get location from any node
pub fn get_location(node : Node) -> SourceLocation {
  match node {
    SourceFile(s) => s.end_of_file_token.location()
    VariableStatement(v) => v.location
    FunctionDeclaration(f) => f.location
    ClassDeclaration(c) => c.location
    InterfaceDeclaration(i) => i.location
    TypeAliasDeclaration(t) => t.location
    EnumDeclaration(e) => e.location
    ModuleDeclaration(m) => m.location
    ImportDeclaration(i) => i.location
    ExportDeclaration(e) => e.location
    ExportAssignment(e) => e.location
    IfStatement(i) => i.location
    SwitchStatement(s) => s.location
    ForStatement(f) => f.location
    ForInStatement(f) => f.location
    ForOfStatement(f) => f.location
    WhileStatement(w) => w.location
    DoWhileStatement(d) => d.location
    BreakStatement(b) => b.location
    ContinueStatement(c) => c.location
    ReturnStatement(r) => r.location
    ThrowStatement(t) => t.location
    TryStatement(t) => t.location
    BlockStatement(b) => b.location
    ExpressionStatement(e) => e.location
    EmptyStatement(e) => e.location
    LabeledStatement(l) => l.location
    WithStatement(w) => w.location
    DebuggerStatement(d) => d.location
    BinaryExpression(b) => b.location
    UnaryExpression(u) => u.location
    ConditionalExpression(c) => c.location
    CallExpression(c) => c.location
    NewExpression(n) => n.location
    PropertyAccessExpression(p) => p.location
    ElementAccessExpression(e) => e.location
    ArrowFunction(a) => a.location
    FunctionExpression(f) => f.location
    ArrayLiteralExpression(a) => a.location
    ObjectLiteralExpression(o) => o.location
    ParenthesizedExpression(p) => p.location
    TemplateExpression(t) => t.location
    AsExpression(a) => a.location
    TypeAssertionExpression(t) => t.location
    NonNullExpression(n) => n.location
    SpreadExpression(s) => s.location
    ArrayBindingPattern(a) => a.location
    ObjectBindingPattern(o) => o.location
    Identifier(i) => i.location
    NumericLiteral(n) => n.location
    StringLiteral(s) => s.location
    BooleanLiteral(b) => b.location
    NullLiteral(n) => n.location
    ThisExpression(t) => t.location
    SuperExpression(s) => s.location
    TypeReference(t) => t.location
    UnionType(u) => u.location
    IntersectionType(i) => i.location
    FunctionType(f) => f.location
    ArrayType(a) => a.location
    TupleType(t) => t.location
    LiteralType(l) => l.location
    KeywordType(k) => k.location
    MappedType(m) => m.location
    ConditionalType(c) => c.location
    IndexedAccessType(i) => i.location
    Parameter(p) => p.location
    PropertyDeclaration(p) => p.location
    IndexSignatureDeclaration(i) => i.location
    MethodDeclaration(m) => m.location
    ConstructorDeclaration(c) => c.location
    GetAccessor(g) => g.location
    SetAccessor(s) => s.location
  }
}
