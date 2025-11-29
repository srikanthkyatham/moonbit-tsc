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
  is_const : Bool // Track const vs let/var
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
    is_const: false, // Default is let/var
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
/// TypeScript diagnostic error codes
/// These codes match the official TypeScript compiler error codes
pub enum DiagnosticCode {
  // Type Assignment Errors (2300-2399)
  TS2314 // Generic type requires more type arguments
  TS2322 // Type 'X' is not assignable to type 'Y'
  TS2344 // Type 'X' does not satisfy the constraint 'Y'
  TS2345 // Argument of type 'X' is not assignable to parameter of type 'Y'
  TS2349 // This expression is not callable
  TS2355 // A function whose declared type is neither 'void' nor 'any' must return a value
  TS2363 // The right-hand side of an arithmetic operation must be of type 'any', 'number', 'bigint' or an enum type

  // Enum Errors (2400-2499)
  TS2474 // const enum member initializers can only contain literal values and other computed enum values

  // Variable/Constant Errors (2500-2599)
  TS2511 // Cannot create an instance of an abstract class
  TS2554 // Expected X arguments, but got Y
  TS2558 // Expected X type arguments, but got Y
  TS2588 // Cannot assign to 'X' because it is a constant

  // Overload Errors (2300-2399 and 2700-2799)
  TS2383 // Overload signatures must all be ambient or non-ambient
  TS2391 // Function implementation is missing or not immediately following the declaration
  TS2394 // Overload signature is not compatible with function implementation
  TS2769 // No overload matches this call

  // Unreachable Code (7000-7099)
  TS7027 // Unreachable code detected
} derive(Show, Eq)

///|
/// Convert DiagnosticCode to its numeric value
pub fn DiagnosticCode::to_int(self : DiagnosticCode) -> Int {
  match self {
    TS2314 => 2314
    TS2322 => 2322
    TS2344 => 2344
    TS2345 => 2345
    TS2349 => 2349
    TS2355 => 2355
    TS2363 => 2363
    TS2474 => 2474
    TS2511 => 2511
    TS2554 => 2554
    TS2558 => 2558
    TS2588 => 2588
    TS2383 => 2383
    TS2391 => 2391
    TS2394 => 2394
    TS2769 => 2769
    TS7027 => 7027
  }
}

///|
/// Convert numeric code to DiagnosticCode (if valid)
pub fn DiagnosticCode::from_int(code : Int) -> DiagnosticCode? {
  match code {
    2314 => Some(TS2314)
    2322 => Some(TS2322)
    2344 => Some(TS2344)
    2345 => Some(TS2345)
    2349 => Some(TS2349)
    2355 => Some(TS2355)
    2363 => Some(TS2363)
    2474 => Some(TS2474)
    2511 => Some(TS2511)
    2554 => Some(TS2554)
    2558 => Some(TS2558)
    2588 => Some(TS2588)
    2383 => Some(TS2383)
    2391 => Some(TS2391)
    2394 => Some(TS2394)
    2769 => Some(TS2769)
    7027 => Some(TS7027)
    _ => None
  }
}

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

///|
/// Create an error diagnostic with a DiagnosticCode enum
pub fn Diagnostic::error_with_code(
  message : String,
  location : SourceLocation,
  code : DiagnosticCode,
) -> Diagnostic {
  {
    message,
    location,
    category: DiagnosticCategory::Error,
    code: code.to_int(),
  }
}

///|
/// Check if a diagnostic has a specific DiagnosticCode
pub fn Diagnostic::has_code(self : Diagnostic, code : DiagnosticCode) -> Bool {
  self.code == code.to_int()
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
pub fn Container::new(
  kind : ContainerKind,
  parent : Int?,
  id : Int,
) -> Container {
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
  control_flow_graph : ControlFlowGraph
  ambient_modules : AmbientModuleRegistry // Ambient module declarations (declare module "pattern")
  module_augmentations : Array[ModuleAugmentation] // Module augmentations (declare module in module files)
  global_augmentations : Array[GlobalAugmentation] // Global augmentations (declare global { })
  triple_slash_directives : Array[TripleSlashDirective] // Triple-slash directives (/// <reference ...>)
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

///|
/// Build the final ControlFlowGraph from the builder
pub fn CFGBuilder::build(self : CFGBuilder) -> ControlFlowGraph {
  // Create the exit node
  let exit_id = self.next_id
  let exit_node = FlowNode::End(FlowEnd::{
    antecedent: self.current_flow,
    id: exit_id,
  })
  let nodes = self.nodes
  nodes.push(exit_node)

  // Build node map for quick lookup
  let node_map : Map[Int, FlowNode] = Map::new()
  for i = 0; i < nodes.length(); i = i + 1 {
    let node = nodes[i]
    node_map.set(flow_id(node), node)
  }
  {
    nodes,
    entry: 0, // Start node ID is always 0
    exit: exit_id,
    node_map,
  }
}

///|
/// Add an assignment flow node
pub fn CFGBuilder::add_assignment(self : CFGBuilder, node : Node) -> CFGBuilder {
  let id = self.next_id
  let flow_node = FlowNode::Assignment(FlowAssignment::{
    node,
    antecedent: self.current_flow,
    id,
  })
  let nodes = self.nodes
  nodes.push(flow_node)
  { ..self, next_id: id + 1, current_flow: id }
}

///|
/// Add a call flow node
pub fn CFGBuilder::add_call(self : CFGBuilder, node : Node) -> CFGBuilder {
  let id = self.next_id
  let flow_node = FlowNode::Call(FlowCall::{
    node,
    antecedent: self.current_flow,
    id,
  })
  let nodes = self.nodes
  nodes.push(flow_node)
  { ..self, next_id: id + 1, current_flow: id }
}

///|
/// Add a condition flow node
pub fn CFGBuilder::add_condition(
  self : CFGBuilder,
  expression : Node,
) -> CFGBuilder {
  let id = self.next_id
  let flow_node = FlowNode::Condition(FlowCondition::{
    expression,
    antecedent: self.current_flow,
    id,
  })
  let nodes = self.nodes
  nodes.push(flow_node)
  { ..self, next_id: id + 1, current_flow: id }
}

///|
/// Add a return flow node
pub fn CFGBuilder::add_return(self : CFGBuilder, node : Node) -> CFGBuilder {
  let id = self.next_id
  let flow_node = FlowNode::Return(FlowReturn::{
    node,
    antecedent: self.current_flow,
    id,
  })
  let nodes = self.nodes
  nodes.push(flow_node)
  let return_flows = self.return_flows
  return_flows.push(id)
  { ..self, next_id: id + 1, current_flow: id, return_flows }
}

///|
/// Add a throw flow node
pub fn CFGBuilder::add_throw(self : CFGBuilder, node : Node) -> CFGBuilder {
  let id = self.next_id
  let flow_node = FlowNode::Throw(FlowThrow::{
    node,
    antecedent: self.current_flow,
    id,
  })
  let nodes = self.nodes
  nodes.push(flow_node)
  { ..self, next_id: id + 1, current_flow: id }
}

///|
/// Add an unreachable flow node
pub fn CFGBuilder::add_unreachable(self : CFGBuilder) -> CFGBuilder {
  let id = self.next_id
  let flow_node = FlowNode::Unreachable(FlowUnreachable::{ id, })
  let nodes = self.nodes
  nodes.push(flow_node)
  { ..self, next_id: id + 1, current_flow: id }
}

///|
/// Add an array mutation flow node
pub fn CFGBuilder::add_array_mutation(
  self : CFGBuilder,
  node : Node,
) -> CFGBuilder {
  let id = self.next_id
  let flow_node = FlowNode::ArrayMutation(FlowArrayMutation::{
    node,
    antecedent: self.current_flow,
    id,
  })
  let nodes = self.nodes
  nodes.push(flow_node)
  { ..self, next_id: id + 1, current_flow: id }
}

///|
/// Add a switch clause flow node
pub fn CFGBuilder::add_switch_clause(
  self : CFGBuilder,
  switch_statement : Node,
  clause_start : Int,
  clause_end : Int,
) -> CFGBuilder {
  let id = self.next_id
  let flow_node = FlowNode::SwitchClause(FlowSwitchClause::{
    switch_statement,
    clause_start,
    clause_end,
    antecedent: self.current_flow,
    id,
  })
  let nodes = self.nodes
  nodes.push(flow_node)
  { ..self, next_id: id + 1, current_flow: id }
}

///|
/// Push a loop context
pub fn CFGBuilder::push_loop(
  self : CFGBuilder,
  break_label : Int,
  continue_label : Int,
  label_name : String?,
) -> CFGBuilder {
  let loop_stack = self.loop_stack
  loop_stack.push(LoopContext::{ break_label, continue_label, label_name })
  { ..self, loop_stack, }
}

///|
/// Pop a loop context
pub fn CFGBuilder::pop_loop(self : CFGBuilder) -> CFGBuilder {
  let loop_stack = self.loop_stack
  let _ = loop_stack.pop()
  { ..self, loop_stack, }
}

///|
/// Get current loop context
pub fn CFGBuilder::current_loop(self : CFGBuilder) -> LoopContext? {
  if self.loop_stack.length() > 0 {
    Some(self.loop_stack[self.loop_stack.length() - 1])
  } else {
    None
  }
}

///|
/// Push a switch context for tracking switch statement flow
pub fn CFGBuilder::push_switch(
  self : CFGBuilder,
  break_label : Int,
) -> CFGBuilder {
  let switch_stack = self.switch_stack
  switch_stack.push(SwitchContext::{ break_label, clause_flows: [] })
  { ..self, switch_stack, }
}

///|
/// Pop the current switch context
pub fn CFGBuilder::pop_switch(self : CFGBuilder) -> CFGBuilder {
  let switch_stack = self.switch_stack
  let _ = switch_stack.pop()
  { ..self, switch_stack, }
}

///|
/// Get current switch context
pub fn CFGBuilder::current_switch(self : CFGBuilder) -> SwitchContext? {
  if self.switch_stack.length() > 0 {
    Some(self.switch_stack[self.switch_stack.length() - 1])
  } else {
    None
  }
}

///|
/// Add a clause flow to the current switch context
pub fn CFGBuilder::add_clause_flow(
  self : CFGBuilder,
  flow_id : Int,
) -> CFGBuilder {
  if self.switch_stack.length() > 0 {
    let current = self.switch_stack[self.switch_stack.length() - 1]
    current.clause_flows.push(flow_id)
  }
  self
}

///|
/// Get the break label for the current switch context
pub fn CFGBuilder::get_switch_break_label(self : CFGBuilder) -> Int? {
  match self.current_switch() {
    Some(ctx) => Some(ctx.break_label)
    None => None
  }
}

///|
/// Create an empty ControlFlowGraph
pub fn ControlFlowGraph::empty() -> ControlFlowGraph {
  let start_node = FlowNode::Start(FlowStart::{ id: 0 })
  let end_node = FlowNode::End(FlowEnd::{ antecedent: 0, id: 1 })
  let node_map : Map[Int, FlowNode] = Map::new()
  node_map.set(0, start_node)
  node_map.set(1, end_node)
  { nodes: [start_node, end_node], entry: 0, exit: 1, node_map }
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

// ============================================================================
// Ambient Module Registry
// ============================================================================

///|
/// Information about an ambient module declaration
pub struct AmbientModuleInfo {
  /// Module specifier pattern (e.g., "*.css", "lodash", "express")
  pattern : String
  /// Is this a wildcard pattern?
  is_wildcard : Bool
  /// The symbol table for this module's exports
  exports : SymbolTable
  /// The bound AST body of the module (for later analysis)
  body : Node?
  /// Location of the declaration
  location : SourceLocation
} derive(Show)

///|
/// Registry of ambient module declarations
pub struct AmbientModuleRegistry {
  /// Exact module matches (e.g., "lodash", "express")
  exact_modules : Map[String, AmbientModuleInfo]
  /// Wildcard patterns (e.g., "*.css", "*.json")
  wildcard_patterns : Array[AmbientModuleInfo]
} derive(Show)

///|
/// Create an empty ambient module registry
pub fn AmbientModuleRegistry::new() -> AmbientModuleRegistry {
  { exact_modules: Map::new(), wildcard_patterns: [] }
}

///|
/// Register an ambient module
pub fn AmbientModuleRegistry::register(
  self : AmbientModuleRegistry,
  pattern : String,
  exports : SymbolTable,
  body : Node?,
  location : SourceLocation,
) -> Unit {
  let is_wildcard = pattern.contains("*")
  let info = AmbientModuleInfo::{
    pattern,
    is_wildcard,
    exports,
    body,
    location,
  }
  if is_wildcard {
    self.wildcard_patterns.push(info)
  } else {
    self.exact_modules[pattern] = info
  }
}

///|
/// Look up an ambient module by specifier
/// Returns the exports symbol table if found
pub fn AmbientModuleRegistry::lookup(
  self : AmbientModuleRegistry,
  specifier : String,
) -> AmbientModuleInfo? {
  // Try exact match first
  match self.exact_modules.get(specifier) {
    Some(info) => return Some(info)
    None => ()
  }

  // Try wildcard patterns
  for info in self.wildcard_patterns {
    if match_ambient_pattern(info.pattern, specifier) {
      return Some(info)
    }
  }

  None
}

// ============================================================================
// Module Augmentation
// ============================================================================

///|
/// Information about a module augmentation (declare module in a module file)
/// Module augmentations extend existing modules rather than creating new ones
pub struct ModuleAugmentation {
  /// The module being augmented (e.g., "express", "lodash")
  module_name : String
  /// The declarations to merge into the module
  declarations : SymbolTable
  /// The AST body for later processing
  body : Node?
  /// Location of the augmentation
  location : SourceLocation
} derive(Show)

///|
/// Global augmentation - adds declarations to global scope
/// Created from `declare global { }` blocks in module files
pub struct GlobalAugmentation {
  /// The declarations to add to global scope
  declarations : SymbolTable
  /// The AST body for later processing
  body : Node?
  /// Location of the augmentation
  location : SourceLocation
} derive(Show)

///|
/// Triple-slash directive kind
pub enum TripleSlashDirectiveKind {
  /// `/// <reference path="./file.ts" />`
  ReferencePath(String)
  /// `/// <reference types="node" />`
  ReferenceTypes(String)
  /// `/// <reference lib="es2015" />`
  ReferenceLib(String)
  /// `/// <reference no-default-lib="true" />`
  NoDefaultLib(Bool)
  /// `/// <amd-module name="..." />`
  AmdModule(String)
  /// `/// <amd-dependency path="..." />`
  AmdDependency(String)
} derive(Show, Eq)

///|
/// Triple-slash directive
pub struct TripleSlashDirective {
  /// The kind and value of the directive
  kind : TripleSlashDirectiveKind
  /// Location in source
  location : SourceLocation
} derive(Show)

///|
/// Parse a triple-slash directive from content (after ///)
/// Returns None if content is not a valid directive
pub fn parse_triple_slash_directive(
  content : String,
  location : SourceLocation,
) -> TripleSlashDirective? {
  let trimmed = trim_whitespace(content)

  // Must start with <reference or <amd-
  if not(trimmed.has_prefix("<")) {
    return None
  }

  // Try to parse reference directive
  // Format: <reference path="..." /> or <reference types="..." /> etc.
  if trimmed.has_prefix("<reference") {
    // Extract attribute
    match extract_attribute(trimmed, "path") {
      Some(path) =>
        return Some(
          TripleSlashDirective::{ kind: ReferencePath(path), location },
        )
      None => ()
    }
    match extract_attribute(trimmed, "types") {
      Some(types) =>
        return Some(
          TripleSlashDirective::{ kind: ReferenceTypes(types), location },
        )
      None => ()
    }
    // Check no-default-lib BEFORE lib (lib is a substring of no-default-lib)
    match extract_attribute(trimmed, "no-default-lib") {
      Some(no_default) => {
        let value = no_default == "true"
        return Some(
          TripleSlashDirective::{ kind: NoDefaultLib(value), location },
        )
      }
      None => ()
    }
    match extract_attribute(trimmed, "lib") {
      Some(lib) =>
        return Some(
          TripleSlashDirective::{ kind: ReferenceLib(lib), location },
        )
      None => ()
    }
  }

  // Try to parse amd-module directive
  if trimmed.has_prefix("<amd-module") {
    match extract_attribute(trimmed, "name") {
      Some(name) =>
        return Some(TripleSlashDirective::{ kind: AmdModule(name), location })
      None => ()
    }
  }

  // Try to parse amd-dependency directive
  if trimmed.has_prefix("<amd-dependency") {
    match extract_attribute(trimmed, "path") {
      Some(path) =>
        return Some(
          TripleSlashDirective::{ kind: AmdDependency(path), location },
        )
      None => ()
    }
  }

  None
}

///|
/// Trim whitespace from start and end of string
fn trim_whitespace(s : String) -> String {
  if s.length() == 0 {
    return ""
  }
  let chars = s.to_array()
  let len = chars.length()
  if len == 0 {
    return ""
  }
  let mut start = 0
  let mut end = len
  // Skip leading whitespace
  while start < end && (chars[start] == ' ' || chars[start] == '\t') {
    start = start + 1
  }
  // Skip trailing whitespace
  while end > start && (chars[end - 1] == ' ' || chars[end - 1] == '\t') {
    end = end - 1
  }
  // Build result string
  let result = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    result.write_char(chars[i])
  }
  result.to_string()
}

///|
/// Extract attribute value from XML-like tag
/// e.g., extract_attribute("<reference path=\"foo.ts\" />", "path") => Some("foo.ts")
fn extract_attribute(tag : String, attr_name : String) -> String? {
  // Early return for empty or short strings
  if tag.length() == 0 || attr_name.length() == 0 {
    return None
  }

  // Look for attr_name="value" or attr_name='value'
  let search_double = attr_name + "=\""
  let search_single = attr_name + "='"
  let tag_chars = tag.to_array()
  let tag_len = tag_chars.length()

  // Try double quotes first
  let mut start_idx = -1
  let search_len = search_double.length()
  if tag_len >= search_len {
    let search_chars = search_double.to_array()
    let max_i = tag_len - search_len
    for i = 0; i <= max_i; i = i + 1 {
      let mut matches = true
      for j = 0; j < search_len; j = j + 1 {
        if tag_chars[i + j] != search_chars[j] {
          matches = false
          break
        }
      }
      if matches {
        start_idx = i + search_len
        break
      }
    }
  }

  if start_idx >= 0 {
    // Find closing double quote
    let value = StringBuilder::new()
    for i = start_idx; i < tag_len; i = i + 1 {
      if tag_chars[i] == '"' {
        return Some(value.to_string())
      }
      value.write_char(tag_chars[i])
    }
  }

  // Try single quotes
  start_idx = -1
  let search_len2 = search_single.length()
  if tag_len >= search_len2 {
    let search_chars2 = search_single.to_array()
    let max_i2 = tag_len - search_len2
    for i = 0; i <= max_i2; i = i + 1 {
      let mut matches = true
      for j = 0; j < search_len2; j = j + 1 {
        if tag_chars[i + j] != search_chars2[j] {
          matches = false
          break
        }
      }
      if matches {
        start_idx = i + search_len2
        break
      }
    }
  }

  if start_idx >= 0 {
    // Find closing single quote
    let value = StringBuilder::new()
    for i = start_idx; i < tag_chars.length(); i = i + 1 {
      if tag_chars[i] == '\'' {
        return Some(value.to_string())
      }
      value.write_char(tag_chars[i])
    }
  }

  None
}

///|
/// Match a module specifier against an ambient module pattern
/// Supports wildcard patterns like "*.css", "*.json", "images/*"
fn match_ambient_pattern(pattern : String, specifier : String) -> Bool {
  // Find the * in the pattern
  let mut star_idx = -1
  for i = 0; i < pattern.length(); i = i + 1 {
    if pattern[i] == '*' {
      star_idx = i
      break
    }
  }

  if star_idx == -1 {
    // No wildcard, exact match
    return pattern == specifier
  }

  // Split pattern into prefix and suffix around *
  let prefix = @utils.substr(pattern, start=0, end=star_idx)
  let suffix = if star_idx + 1 < pattern.length() {
    @utils.substr(pattern, start=star_idx + 1)
  } else {
    ""
  }

  // Check if specifier matches prefix....*....suffix
  if not(specifier.has_prefix(prefix)) {
    return false
  }
  if suffix.length() > 0 && not(specifier.has_suffix(suffix)) {
    return false
  }

  // Ensure there's at least one character between prefix and suffix
  specifier.length() >= prefix.length() + suffix.length()
}
