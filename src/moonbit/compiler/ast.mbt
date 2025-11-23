// AST node types for TypeScript
// Represents the Abstract Syntax Tree structure

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
  MethodDeclaration(MethodDeclaration)
  ConstructorDeclaration(ConstructorDeclaration)
  GetAccessor(GetAccessor)
  SetAccessor(SetAccessor)
} derive(Show)

/// Source file - root of AST
pub struct SourceFile {
  pub file_path : String
  pub statements : Array[Node]
  pub end_of_file_token : Token
  pub has_no_default_lib : Bool
} derive(Show)

/// Variable statement (let/const/var)
pub struct VariableStatement {
  pub declarations : Array[VariableDeclaration]
  pub is_const : Bool
  pub is_let : Bool
  pub location : SourceLocation
} derive(Show)

pub struct VariableDeclaration {
  pub name : Node  // Identifier or binding pattern
  pub type_annotation : Option[Node]
  pub initializer : Option[Node]
  pub location : SourceLocation
} derive(Show)

/// Function declaration
pub struct FunctionDeclaration {
  pub name : Option[Node]  // Identifier (None for anonymous)
  pub type_parameters : Array[TypeParameter]
  pub parameters : Array[Node]
  pub return_type : Option[Node]
  pub body : Option[Node]  // BlockStatement
  pub is_async : Bool
  pub is_generator : Bool
  pub location : SourceLocation
} derive(Show)

/// Type parameter (generic)
pub struct TypeParameter {
  pub name : String
  pub constraint : Option[Node]
  pub default : Option[Node]
  pub location : SourceLocation
} derive(Show)

/// Class declaration
pub struct ClassDeclaration {
  pub name : Option[Node]
  pub type_parameters : Array[TypeParameter]
  pub heritage_clauses : Array[HeritageClause]
  pub members : Array[Node]
  pub is_abstract : Bool
  pub location : SourceLocation
} derive(Show)

pub struct HeritageClause {
  pub kind : HeritageKind
  pub types : Array[Node]
  pub location : SourceLocation
} derive(Show)

pub enum HeritageKind {
  Extends
  Implements
} derive(Show, Eq)

/// Interface declaration
pub struct InterfaceDeclaration {
  pub name : String
  pub type_parameters : Array[TypeParameter]
  pub heritage_clauses : Array[HeritageClause]
  pub members : Array[Node]
  pub location : SourceLocation
} derive(Show)

/// Type alias
pub struct TypeAliasDeclaration {
  pub name : String
  pub type_parameters : Array[TypeParameter]
  pub type_node : Node
  pub location : SourceLocation
} derive(Show)

/// Enum declaration
pub struct EnumDeclaration {
  pub name : String
  pub members : Array[EnumMember]
  pub is_const : Bool
  pub location : SourceLocation
} derive(Show)

pub struct EnumMember {
  pub name : String
  pub initializer : Option[Node]
  pub location : SourceLocation
} derive(Show)

/// Module/namespace declaration
pub struct ModuleDeclaration {
  pub name : String
  pub body : Option[Node]
  pub location : SourceLocation
} derive(Show)

/// Import declaration
pub struct ImportDeclaration {
  pub import_clause : Option[ImportClause]
  pub module_specifier : String
  pub location : SourceLocation
} derive(Show)

pub struct ImportClause {
  pub name : Option[String]  // Default import
  pub named_bindings : Option[NamedImports]
  pub location : SourceLocation
} derive(Show)

pub enum NamedImports {
  NamespaceImport(String, SourceLocation)  // * as name
  NamedImports(Array[ImportSpecifier], SourceLocation)
} derive(Show)

pub struct ImportSpecifier {
  pub property_name : Option[String]  // For "import { foo as bar }"
  pub name : String
  pub location : SourceLocation
} derive(Show)

/// Export declaration
pub struct ExportDeclaration {
  pub export_clause : Option[NamedExports]
  pub module_specifier : Option[String]
  pub location : SourceLocation
} derive(Show)

pub enum NamedExports {
  NamedExports(Array[ExportSpecifier], SourceLocation)
} derive(Show)

pub struct ExportSpecifier {
  pub property_name : Option[String]
  pub name : String
  pub location : SourceLocation
} derive(Show)

pub struct ExportAssignment {
  pub expression : Node
  pub is_export_equals : Bool
  pub location : SourceLocation
} derive(Show)

/// Control flow statements
pub struct IfStatement {
  pub condition : Node
  pub then_statement : Node
  pub else_statement : Option[Node]
  pub location : SourceLocation
} derive(Show)

pub struct SwitchStatement {
  pub expression : Node
  pub cases : Array[CaseClause]
  pub location : SourceLocation
} derive(Show)

pub struct CaseClause {
  pub expression : Option[Node]  // None for default
  pub statements : Array[Node]
  pub location : SourceLocation
} derive(Show)

pub struct ForStatement {
  pub initializer : Option[Node]
  pub condition : Option[Node]
  pub incrementor : Option[Node]
  pub statement : Node
  pub location : SourceLocation
} derive(Show)

pub struct ForInStatement {
  pub initializer : Node
  pub expression : Node
  pub statement : Node
  pub location : SourceLocation
} derive(Show)

pub struct ForOfStatement {
  pub await_modifier : Bool
  pub initializer : Node
  pub expression : Node
  pub statement : Node
  pub location : SourceLocation
} derive(Show)

pub struct WhileStatement {
  pub condition : Node
  pub statement : Node
  pub location : SourceLocation
} derive(Show)

pub struct DoWhileStatement {
  pub statement : Node
  pub condition : Node
  pub location : SourceLocation
} derive(Show)

pub struct BreakStatement {
  pub label : Option[String]
  pub location : SourceLocation
} derive(Show)

pub struct ContinueStatement {
  pub label : Option[String]
  pub location : SourceLocation
} derive(Show)

pub struct ReturnStatement {
  pub expression : Option[Node]
  pub location : SourceLocation
} derive(Show)

pub struct ThrowStatement {
  pub expression : Node
  pub location : SourceLocation
} derive(Show)

pub struct TryStatement {
  pub try_block : Node
  pub catch_clause : Option[CatchClause]
  pub finally_block : Option[Node]
  pub location : SourceLocation
} derive(Show)

pub struct CatchClause {
  pub variable_declaration : Option[Node]
  pub block : Node
  pub location : SourceLocation
} derive(Show)

/// Other statements
pub struct BlockStatement {
  pub statements : Array[Node]
  pub location : SourceLocation
} derive(Show)

pub struct ExpressionStatement {
  pub expression : Node
  pub location : SourceLocation
} derive(Show)

pub struct EmptyStatement {
  pub location : SourceLocation
} derive(Show)

pub struct LabeledStatement {
  pub label : String
  pub statement : Node
  pub location : SourceLocation
} derive(Show)

pub struct WithStatement {
  pub expression : Node
  pub statement : Node
  pub location : SourceLocation
} derive(Show)

pub struct DebuggerStatement {
  pub location : SourceLocation
} derive(Show)

/// Binary expressions
pub struct BinaryExpression {
  pub left : Node
  pub operator : BinaryOperator
  pub right : Node
  pub location : SourceLocation
} derive(Show)

pub enum BinaryOperator {
  // Arithmetic
  Add  // +
  Subtract  // -
  Multiply  // *
  Divide  // /
  Remainder  // %
  Exponentiate  // **

  // Comparison
  LessThan  // <
  GreaterThan  // >
  LessThanEquals  // <=
  GreaterThanEquals  // >=
  Equals  // ==
  NotEquals  // !=
  StrictEquals  // ===
  StrictNotEquals  // !==

  // Logical
  LogicalAnd  // &&
  LogicalOr  // ||
  NullishCoalescing  // ??

  // Bitwise
  BitwiseAnd  // &
  BitwiseOr  // |
  BitwiseXor  // ^
  LeftShift  // <<
  RightShift  // >>
  UnsignedRightShift  // >>>

  // Assignment
  Assign  // =
  AddAssign  // +=
  SubtractAssign  // -=
  MultiplyAssign  // *=
  DivideAssign  // /=
  RemainderAssign  // %=
  BitwiseAndAssign  // &=
  BitwiseOrAssign  // |=
  BitwiseXorAssign  // ^=

  // Other
  In
  InstanceOf
  Comma
} derive(Show, Eq)

/// Unary expressions
pub struct UnaryExpression {
  pub operator : UnaryOperator
  pub operand : Node
  pub is_prefix : Bool
  pub location : SourceLocation
} derive(Show)

pub enum UnaryOperator {
  Plus  // +
  Minus  // -
  LogicalNot  // !
  BitwiseNot  // ~
  Increment  // ++
  Decrement  // --
  TypeOf
  Void
  Delete
} derive(Show, Eq)

/// Conditional (ternary) expression
pub struct ConditionalExpression {
  pub condition : Node
  pub when_true : Node
  pub when_false : Node
  pub location : SourceLocation
} derive(Show)

/// Call expression
pub struct CallExpression {
  pub expression : Node
  pub type_arguments : Array[Node]
  pub arguments : Array[Node]
  pub location : SourceLocation
} derive(Show)

/// New expression
pub struct NewExpression {
  pub expression : Node
  pub type_arguments : Array[Node]
  pub arguments : Option[Array[Node]]
  pub location : SourceLocation
} derive(Show)

/// Property access (obj.property)
pub struct PropertyAccessExpression {
  pub expression : Node
  pub name : String
  pub location : SourceLocation
} derive(Show)

/// Element access (obj[element])
pub struct ElementAccessExpression {
  pub expression : Node
  pub argument_expression : Node
  pub location : SourceLocation
} derive(Show)

/// Arrow function
pub struct ArrowFunction {
  pub type_parameters : Array[TypeParameter]
  pub parameters : Array[Node]
  pub return_type : Option[Node]
  pub body : Node  // Block or expression
  pub is_async : Bool
  pub location : SourceLocation
} derive(Show)

/// Function expression
pub struct FunctionExpression {
  pub name : Option[String]
  pub type_parameters : Array[TypeParameter]
  pub parameters : Array[Node]
  pub return_type : Option[Node]
  pub body : Node
  pub is_async : Bool
  pub is_generator : Bool
  pub location : SourceLocation
} derive(Show)

/// Array literal [1, 2, 3]
pub struct ArrayLiteralExpression {
  pub elements : Array[Option[Node]]  // None for holes
  pub location : SourceLocation
} derive(Show)

/// Object literal { key: value }
pub struct ObjectLiteralExpression {
  pub properties : Array[ObjectProperty]
  pub location : SourceLocation
} derive(Show)

pub enum ObjectProperty {
  PropertyAssignment(String, Node, SourceLocation)
  ShorthandProperty(String, SourceLocation)
  SpreadAssignment(Node, SourceLocation)
  MethodDeclaration(String, FunctionExpression, SourceLocation)
  GetAccessor(String, FunctionExpression, SourceLocation)
  SetAccessor(String, FunctionExpression, SourceLocation)
} derive(Show)

/// Parenthesized expression
pub struct ParenthesizedExpression {
  pub expression : Node
  pub location : SourceLocation
} derive(Show)

/// Template expression
pub struct TemplateExpression {
  pub head : String
  pub template_spans : Array[TemplateSpan]
  pub location : SourceLocation
} derive(Show)

pub struct TemplateSpan {
  pub expression : Node
  pub literal : String
  pub location : SourceLocation
} derive(Show)

/// Type assertion (as)
pub struct AsExpression {
  pub expression : Node
  pub type_node : Node
  pub location : SourceLocation
} derive(Show)

/// Type assertion (<Type>expr)
pub struct TypeAssertionExpression {
  pub type_node : Node
  pub expression : Node
  pub location : SourceLocation
} derive(Show)

/// Non-null assertion (expr!)
pub struct NonNullExpression {
  pub expression : Node
  pub location : SourceLocation
} derive(Show)

/// Spread (...expr)
pub struct SpreadExpression {
  pub expression : Node
  pub location : SourceLocation
} derive(Show)

/// Primary expressions
pub struct Identifier {
  pub name : String
  pub location : SourceLocation
} derive(Show)

pub struct NumericLiteral {
  pub value : String
  pub location : SourceLocation
} derive(Show)

pub struct StringLiteral {
  pub value : String
  pub location : SourceLocation
} derive(Show)

pub struct BooleanLiteral {
  pub value : Bool
  pub location : SourceLocation
} derive(Show)

pub struct NullLiteral {
  pub location : SourceLocation
} derive(Show)

pub struct ThisExpression {
  pub location : SourceLocation
} derive(Show)

pub struct SuperExpression {
  pub location : SourceLocation
} derive(Show)

/// Type nodes
pub struct TypeReference {
  pub type_name : String
  pub type_arguments : Array[Node]
  pub location : SourceLocation
} derive(Show)

pub struct UnionType {
  pub types : Array[Node]
  pub location : SourceLocation
} derive(Show)

pub struct IntersectionType {
  pub types : Array[Node]
  pub location : SourceLocation
} derive(Show)

pub struct FunctionType {
  pub type_parameters : Array[TypeParameter]
  pub parameters : Array[Node]
  pub return_type : Node
  pub location : SourceLocation
} derive(Show)

pub struct ArrayType {
  pub element_type : Node
  pub location : SourceLocation
} derive(Show)

pub struct TupleType {
  pub element_types : Array[Node]
  pub location : SourceLocation
} derive(Show)

pub struct LiteralType {
  pub literal : Node
  pub location : SourceLocation
} derive(Show)

pub struct KeywordType {
  pub kind : TypeKeyword
  pub location : SourceLocation
} derive(Show)

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

pub struct MappedType {
  pub type_parameter : TypeParameter
  pub type_node : Option[Node]
  pub location : SourceLocation
} derive(Show)

pub struct ConditionalType {
  pub check_type : Node
  pub extends_type : Node
  pub true_type : Node
  pub false_type : Node
  pub location : SourceLocation
} derive(Show)

pub struct IndexedAccessType {
  pub object_type : Node
  pub index_type : Node
  pub location : SourceLocation
} derive(Show)

/// Parameter
pub struct Parameter {
  pub name : Node
  pub type_annotation : Option[Node]
  pub initializer : Option[Node]
  pub is_optional : Bool
  pub is_rest : Bool
  pub location : SourceLocation
} derive(Show)

/// Class members
pub struct PropertyDeclaration {
  pub name : String
  pub type_annotation : Option[Node]
  pub initializer : Option[Node]
  pub modifiers : Array[Modifier]
  pub location : SourceLocation
} derive(Show)

pub struct MethodDeclaration {
  pub name : String
  pub type_parameters : Array[TypeParameter]
  pub parameters : Array[Node]
  pub return_type : Option[Node]
  pub body : Option[Node]
  pub modifiers : Array[Modifier]
  pub is_async : Bool
  pub is_generator : Bool
  pub location : SourceLocation
} derive(Show)

pub struct ConstructorDeclaration {
  pub parameters : Array[Node]
  pub body : Option[Node]
  pub location : SourceLocation
} derive(Show)

pub struct GetAccessor {
  pub name : String
  pub return_type : Option[Node]
  pub body : Option[Node]
  pub modifiers : Array[Modifier]
  pub location : SourceLocation
} derive(Show)

pub struct SetAccessor {
  pub name : String
  pub parameter : Node
  pub body : Option[Node]
  pub modifiers : Array[Modifier]
  pub location : SourceLocation
} derive(Show)

/// Modifiers
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
    MethodDeclaration(m) => m.location
    ConstructorDeclaration(c) => c.location
    GetAccessor(g) => g.location
    SetAccessor(s) => s.location
  }
}
