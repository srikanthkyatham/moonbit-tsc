// Symbol types for the TypeScript compiler
// Used by the binder and checker

/// Symbol represents a named declaration in the program
pub struct Symbol {
  pub name : String
  pub kind : SymbolKind
  pub flags : SymbolFlags
  pub declarations : Array[Node]
  pub value_declaration : Option[Node]
  pub members : Option[SymbolTable]
  pub exports : Option[SymbolTable]
  pub id : Int  // Unique identifier
} derive(Show)

/// Symbol table - maps names to symbols
pub type SymbolTable = Map[String, Symbol]

/// Kind of symbol
pub enum SymbolKind {
  Variable
  Function
  Class
  Interface
  Enum
  EnumMember
  Module
  Type
  TypeParameter
  Property
  Method
  GetAccessor
  SetAccessor
  Parameter
  Alias
  ExportValue
  ExportType
} derive(Show, Eq)

/// Symbol flags (bitwise)
pub struct SymbolFlags {
  pub is_export : Bool
  pub is_ambient : Bool
  pub is_instantiated : Bool
  pub is_merged : Bool
  pub is_transient : Bool
  pub is_assignment : Bool
  pub is_optional : Bool
  pub is_readonly : Bool
  pub is_static : Bool
  pub is_private : Bool
  pub is_protected : Bool
  pub is_public : Bool
  pub is_abstract : Bool
  pub is_async : Bool
} derive(Show)

/// Create default symbol flags
pub fn SymbolFlags::default() -> SymbolFlags {
  {
    is_export: false,
    is_ambient: false,
    is_instantiated: false,
    is_merged: false,
    is_transient: false,
    is_assignment: false,
    is_optional: false,
    is_readonly: false,
    is_static: false,
    is_private: false,
    is_protected: false,
    is_public: true,  // Default is public
    is_abstract: false,
    is_async: false,
  }
}

/// Create a new symbol
pub fn Symbol::new(name : String, kind : SymbolKind, id : Int) -> Symbol {
  {
    name,
    kind,
    flags: SymbolFlags::default(),
    declarations: [],
    value_declaration: None,
    members: None,
    exports: None,
    id,
  }
}

/// Add a declaration to a symbol
pub fn Symbol::add_declaration(self : Symbol, decl : Node) -> Symbol {
  let new_declarations = self.declarations
  new_declarations.push(decl)

  let new_value_decl = match self.value_declaration {
    Some(_) => self.value_declaration
    None => Some(decl)
  }

  { ..self, declarations: new_declarations, value_declaration: new_value_decl }
}

/// Flow node for control flow analysis
pub enum FlowNode {
  Start(FlowStart)
  Assignment(FlowAssignment)
  Call(FlowCall)
  Condition(FlowCondition)
  SwitchClause(FlowSwitchClause)
  Label(FlowLabel)
  ArrayMutation(FlowArrayMutation)
  Return(FlowReturn)
  Unreachable(FlowUnreachable)
} derive(Show)

pub struct FlowStart {
  pub id : Int
} derive(Show)

pub struct FlowAssignment {
  pub node : Node
  pub antecedent : Int  // ID of previous flow node
  pub id : Int
} derive(Show)

pub struct FlowCall {
  pub node : Node
  pub antecedent : Int
  pub id : Int
} derive(Show)

pub struct FlowCondition {
  pub expression : Node
  pub antecedent : Int
  pub id : Int
} derive(Show)

pub struct FlowSwitchClause {
  pub switch_statement : Node
  pub clause_start : Int
  pub clause_end : Int
  pub antecedent : Int
  pub id : Int
} derive(Show)

pub struct FlowLabel {
  pub antecedents : Array[Int]
  pub id : Int
} derive(Show)

pub struct FlowArrayMutation {
  pub node : Node
  pub antecedent : Int
  pub id : Int
} derive(Show)

pub struct FlowReturn {
  pub node : Node
  pub antecedent : Int
  pub id : Int
} derive(Show)

pub struct FlowUnreachable {
  pub id : Int
} derive(Show)

/// Get flow node ID
pub fn flow_id(flow : FlowNode) -> Int {
  match flow {
    Start(f) => f.id
    Assignment(f) => f.id
    Call(f) => f.id
    Condition(f) => f.id
    SwitchClause(f) => f.id
    Label(f) => f.id
    ArrayMutation(f) => f.id
    Return(f) => f.id
    Unreachable(f) => f.id
  }
}

/// Scope information
pub struct Scope {
  pub parent : Option[Int]  // Parent scope ID
  pub symbols : SymbolTable
  pub id : Int
} derive(Show)

/// Create a new scope
pub fn Scope::new(parent : Option[Int], id : Int) -> Scope {
  {
    parent,
    symbols: Map::new(),
    id,
  }
}

/// Diagnostic message
pub struct Diagnostic {
  pub message : String
  pub location : SourceLocation
  pub category : DiagnosticCategory
  pub code : Int
} derive(Show)

pub enum DiagnosticCategory {
  Error
  Warning
  Message
  Suggestion
} derive(Show, Eq)

/// Create a new diagnostic
pub fn Diagnostic::error(
  message : String,
  location : SourceLocation,
  code : Int
) -> Diagnostic {
  { message, location, category: DiagnosticCategory::Error, code }
}

pub fn Diagnostic::warning(
  message : String,
  location : SourceLocation,
  code : Int
) -> Diagnostic {
  { message, location, category: DiagnosticCategory::Warning, code }
}

pub fn Diagnostic::suggestion(
  message : String,
  location : SourceLocation,
  code : Int
) -> Diagnostic {
  { message, location, category: DiagnosticCategory::Suggestion, code }
}
