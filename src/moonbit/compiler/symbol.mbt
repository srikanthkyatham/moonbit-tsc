// Symbol types for the TypeScript compiler
// Used by the binder and checker

///|
/// Symbol represents a named declaration in the program
pub struct Symbol {
  name : String
  kind : SymbolKind
  flags : SymbolFlags
  declarations : Array[Node]
  value_declaration : Node?
  members : SymbolTable?
  exports : SymbolTable?
  id : Int // Unique identifier
} derive(Show)

///|
/// Symbol table - maps names to symbols
pub type SymbolTable = Map[String, Symbol]

///|
/// Kind of symbol
#valtype
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

///|
/// Symbol flags (bitwise)
pub struct SymbolFlags {
  is_export : Bool
  is_ambient : Bool
  is_instantiated : Bool
  is_merged : Bool
  is_transient : Bool
  is_assignment : Bool
  is_optional : Bool
  is_readonly : Bool
  is_const : Bool  // Track const vs let/var
  is_static : Bool
  is_private : Bool
  is_protected : Bool
  is_public : Bool
  is_abstract : Bool
  is_async : Bool
} derive(Show)

///|
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
    is_const: false,  // Default is let/var
    is_static: false,
    is_private: false,
    is_protected: false,
    is_public: true, // Default is public
    is_abstract: false,
    is_async: false,
  }
}

///|
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

///|
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

///|
/// Flow node for control flow analysis
pub enum FlowNode {
  // Basic nodes
  Start(FlowStart)
  End(FlowEnd)

  // Assignment and mutation
  Assignment(FlowAssignment)
  ArrayMutation(FlowArrayMutation)

  // Function calls
  Call(FlowCall)

  // Branching
  Condition(FlowCondition)
  TrueCondition(FlowBranchCondition) // True branch of condition
  FalseCondition(FlowBranchCondition) // False branch of condition

  // Switch
  SwitchClause(FlowSwitchClause)

  // Loops
  LoopLabel(FlowLoopLabel)

  // Labels and jumps
  Label(FlowLabel)
  BranchLabel(FlowBranchLabel) // break/continue target

  // Return and throw
  Return(FlowReturn)
  Throw(FlowThrow)

  // Unreachable
  Unreachable(FlowUnreachable)

  // Narrowing
  Narrowing(FlowNarrowing)

  // Reducer (merges multiple flows)
  Reducer(FlowReducer)
} derive(Show)

///|
pub struct FlowStart {
  id : Int
} derive(Show)

///|
pub struct FlowAssignment {
  node : Node
  antecedent : Int // ID of previous flow node
  id : Int
} derive(Show)

///|
pub struct FlowCall {
  node : Node
  antecedent : Int
  id : Int
} derive(Show)

///|
pub struct FlowCondition {
  expression : Node
  antecedent : Int
  id : Int
} derive(Show)

///|
pub struct FlowSwitchClause {
  switch_statement : Node
  clause_start : Int
  clause_end : Int
  antecedent : Int
  id : Int
} derive(Show)

///|
pub struct FlowLabel {
  antecedents : Array[Int]
  id : Int
} derive(Show)

///|
pub struct FlowArrayMutation {
  node : Node
  antecedent : Int
  id : Int
} derive(Show)

///|
pub struct FlowReturn {
  node : Node
  antecedent : Int
  id : Int
} derive(Show)

///|
pub struct FlowUnreachable {
  id : Int
} derive(Show)

///|
/// Flow end node
pub struct FlowEnd {
  antecedent : Int
  id : Int
} derive(Show)

///|
/// Flow branch condition (true or false branch)
pub struct FlowBranchCondition {
  antecedent : Int // Points to the Condition node
  is_true_branch : Bool
  id : Int
} derive(Show)

///|
/// Flow throw node
pub struct FlowThrow {
  node : Node
  antecedent : Int
  id : Int
} derive(Show)

///|
/// Flow loop label (for break/continue)
pub struct FlowLoopLabel {
  antecedents : Array[Int]
  break_target : Int?
  continue_target : Int?
  id : Int
} derive(Show)

///|
/// Flow branch label (jump target)
pub struct FlowBranchLabel {
  name : String? // None for unlabeled
  antecedents : Array[Int]
  id : Int
} derive(Show)

///|
/// Flow narrowing node (type guard effects)
pub struct FlowNarrowing {
  expression : Node
  narrowed_symbol : Int // Symbol ID being narrowed
  narrowed_type : Node // Type node
  antecedent : Int
  id : Int
} derive(Show)

///|
/// Flow reducer (joins multiple branches)
pub struct FlowReducer {
  antecedents : Array[Int]
  id : Int
} derive(Show)

///|
/// Get flow node ID
pub fn flow_id(flow : FlowNode) -> Int {
  match flow {
    Start(f) => f.id
    End(f) => f.id
    Assignment(f) => f.id
    ArrayMutation(f) => f.id
    Call(f) => f.id
    Condition(f) => f.id
    TrueCondition(f) => f.id
    FalseCondition(f) => f.id
    SwitchClause(f) => f.id
    LoopLabel(f) => f.id
    Label(f) => f.id
    BranchLabel(f) => f.id
    Return(f) => f.id
    Throw(f) => f.id
    Unreachable(f) => f.id
    Narrowing(f) => f.id
    Reducer(f) => f.id
  }
}

///|
/// Scope information
pub struct Scope {
  parent : Int? // Parent scope ID
  symbols : SymbolTable
  id : Int
} derive(Show)

///|
/// Create a new scope
pub fn Scope::new(parent : Int?, id : Int) -> Scope {
  { parent, symbols: Map::new(), id }
}

///|
/// Diagnostic message
pub struct Diagnostic {
  message : String
  location : SourceLocation
  category : DiagnosticCategory
  code : Int
} derive(Show)

///|
#valtype
pub enum DiagnosticCategory {
  Error
  Warning
  Message
  Suggestion
} derive(Show, Eq)

///|
/// Create a new diagnostic
pub fn Diagnostic::error(
  message : String,
  location : SourceLocation,
  code : Int,
) -> Diagnostic {
  { message, location, category: DiagnosticCategory::Error, code }
}

///|
pub fn Diagnostic::warning(
  message : String,
  location : SourceLocation,
  code : Int,
) -> Diagnostic {
  { message, location, category: DiagnosticCategory::Warning, code }
}

///|
pub fn Diagnostic::suggestion(
  message : String,
  location : SourceLocation,
  code : Int,
) -> Diagnostic {
  { message, location, category: DiagnosticCategory::Suggestion, code }
}

// ============================================================================
// Module Detection
// ============================================================================

///|
/// Module information
pub struct ModuleInfo {
  /// Is this file an ES module (has import/export)?
  is_external_module : Bool
  /// Is this file using CommonJS?
  is_commonjs_module : Bool
  /// Is this an ambient module (declare module)?
  is_ambient_module : Bool
  /// Has "use strict" directive?
  is_strict_mode : Bool
  /// Module specifier (for ambient modules)
  module_name : String?
  /// Import statements
  imports : Array[ImportInfo]
  /// Export statements
  exports : Array[ExportInfo]
} derive(Show)

///|
/// Create default module info (non-module script)
pub fn ModuleInfo::default() -> ModuleInfo {
  {
    is_external_module: false,
    is_commonjs_module: false,
    is_ambient_module: false,
    is_strict_mode: false,
    module_name: None,
    imports: [],
    exports: [],
  }
}

///|
/// Import information
pub struct ImportInfo {
  module_specifier : String
  is_type_only : Bool
  default_import : String?
  namespace_import : String?
  named_imports : Array[(String, String)] // (propertyName, localName)
  location : SourceLocation
} derive(Show)

///|
/// Export information
pub struct ExportInfo {
  kind : ExportKind
  name : String?
  is_type_only : Bool
  module_specifier : String?
  location : SourceLocation
} derive(Show)

///|
/// Export kind
#valtype
pub enum ExportKind {
  Default // export default expr
  Named // export { x }
  Declaration // export const x = 1
  Namespace // export * from 'mod'
  NamespaceAs // export * as ns from 'mod'
  Equals // export = expr (CommonJS)
} derive(Show, Eq)

// ============================================================================
// Container Management
// ============================================================================

///|
/// Container kinds
#valtype
pub enum ContainerKind {
  SourceFile
  Module
  Class
  Interface
  Function
  Block
  ForStatement
  CatchBlock
  EnumDeclaration
} derive(Show, Eq)

///|
/// Container information
pub struct Container {
  kind : ContainerKind
  symbol : Symbol?
  parent : Int? // Parent container ID
  locals : SymbolTable
  id : Int
} derive(Show)

///|
/// Create a new container
pub fn Container::new(kind : ContainerKind, parent : Int?, id : Int) -> Container {
  { kind, symbol: None, parent, locals: Map::new(), id }
}

// ============================================================================
// Cross-File Linking
// ============================================================================

///|
/// Bound source file (AST with symbol information)
pub struct BoundSourceFile {
  file_path : String
  global_scope : Scope
  statements : Array[Node]
  symbol_count : Int
  diagnostics : Array[Diagnostic]
  module_info : ModuleInfo
} derive(Show)

///|
/// Program represents multiple source files
pub struct Program {
  source_files : Array[BoundSourceFile]
  global_symbols : SymbolTable
  module_map : Map[String, BoundSourceFile] // Module specifier -> file
} derive(Show)

///|
/// Create a new program
pub fn Program::new() -> Program {
  { source_files: [], global_symbols: Map::new(), module_map: Map::new() }
}

// ============================================================================
// Control Flow Graph
// ============================================================================

///|
/// Control flow graph for a function/module
pub struct ControlFlowGraph {
  nodes : Array[FlowNode]
  entry : Int // Entry node ID
  exit : Int // Exit node ID
  node_map : Map[Int, FlowNode] // ID to node
} derive(Show)

///|
/// CFG builder state
pub struct CFGBuilder {
  nodes : Array[FlowNode]
  next_id : Int
  current_flow : Int // Current flow node ID
  /// Label tracking
  labels : Map[String, Int] // Label name to FlowLabel ID
  /// Loop tracking for break/continue
  loop_stack : Array[LoopContext]
  /// Switch tracking
  switch_stack : Array[SwitchContext]
  /// Return collection
  return_flows : Array[Int]
} derive(Show)

///|
/// Loop context for break/continue
pub struct LoopContext {
  break_label : Int
  continue_label : Int
  label_name : String?
} derive(Show)

///|
/// Switch context
pub struct SwitchContext {
  break_label : Int
  clause_flows : Array[Int]
} derive(Show)

///|
/// Create new CFG builder
pub fn CFGBuilder::new() -> CFGBuilder {
  let start_node = FlowNode::Start(FlowStart::{ id: 0 })
  {
    nodes: [start_node],
    next_id: 1,
    current_flow: 0,
    labels: Map::new(),
    loop_stack: [],
    switch_stack: [],
    return_flows: [],
  }
}

// ============================================================================
// Symbol Links (for type checking)
// ============================================================================

///|
/// Symbol links for type checking
pub struct SymbolLinks {
  /// Resolved type for the symbol
  resolved_type : Node?
  /// Declared type (from annotation)
  declared_type : Node?
  /// Target of alias
  alias_target : Symbol?
  /// Whether symbol has been referenced
  is_referenced : Bool
  /// Whether symbol has been assigned
  is_assigned : Bool
} derive(Show)

///|
/// Create default symbol links
pub fn SymbolLinks::default() -> SymbolLinks {
  {
    resolved_type: None,
    declared_type: None,
    alias_target: None,
    is_referenced: false,
    is_assigned: false,
  }
}
