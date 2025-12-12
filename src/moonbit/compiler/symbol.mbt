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
  locals : SymbolTable? // All members in namespace (exported + non-exported)
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
    locals: None,
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
  // ============================================================================
  // Syntax Errors (1xxx)
  // ============================================================================
  TS1005 // '{0}' expected
  TS1104 // A 'continue' statement can only be used within an enclosing iteration statement
  TS1109 // Expression expected
  TS1155 // 'const' declarations must be initialized
  TS1160 // Unterminated template literal
  TS1163 // A 'yield' expression is only allowed in a generator body
  TS1166 // A computed property name in a class property declaration must have a simple literal type or a 'unique symbol' type
  TS1182 // A destructuring declaration must have an initializer
  TS1186 // A rest element cannot have an initializer
  TS1187 // A parameter property may not be declared using a binding pattern
  TS1188 // Only a single variable declaration is allowed in a 'for...of' statement
  TS1214 // Identifier expected. '{0}' is a reserved word in strict mode. Modules are automatically in strict mode
  TS1221 // Generators are not allowed in an ambient context
  TS1308 // 'await' expressions are only allowed within async functions and at the top levels of modules
  TS1357 // An enum member name must be followed by a ',', '=', or '}'
  TS1359 // Identifier expected. '{0}' is a reserved word that cannot be used here

  // ============================================================================
  // Name Resolution Errors (2304-2318)
  // ============================================================================
  TS2304 // Cannot find name '{0}'
  TS2305 // Module '{0}' has no exported member '{1}'
  TS2306 // File '{0}' is not a module
  TS2307 // Cannot find module '{0}'
  TS2308 // Module '{0}' has already exported a member named '{1}'. Consider explicitly re-exporting to resolve the ambiguity
  TS2314 // Generic type '{0}' requires {1} type argument(s)
  TS2315 // Type '{0}' is not generic
  TS2318 // Cannot find global type '{0}'

  // ============================================================================
  // Type Assignment & Compatibility Errors (2320-2380)
  // ============================================================================
  TS2320 // Interface '{0}' cannot simultaneously extend types '{1}' and '{2}'
  TS2322 // Type '{0}' is not assignable to type '{1}'
  TS2324 // Property '{0}' is missing in type '{1}'
  TS2326 // Types of parameters '{0}' and '{1}' are incompatible
  TS2328 // Types of property '{0}' are incompatible
  TS2329 // Index signature is missing in type '{0}'
  TS2331 // 'this' cannot be referenced in a module or namespace body
  TS2332 // 'this' cannot be referenced in current location
  TS2334 // 'this' cannot be referenced in a static property initializer
  TS2335 // 'super' can only be referenced in a derived class
  TS2337 // Super calls are not permitted outside constructors
  TS2339 // Property '{0}' does not exist on type '{1}'
  TS2341 // Property '{0}' is private and only accessible within class '{1}'
  TS2344 // Type '{0}' does not satisfy the constraint '{1}'
  TS2345 // Argument of type '{0}' is not assignable to parameter of type '{1}'
  TS2348 // Value of type '{0}' has no properties in common with type '{1}'
  TS2349 // This expression is not callable
  TS2350 // Only a void function can be called with the 'new' keyword
  TS2351 // This expression is not constructable
  TS2352 // Conversion of type '{0}' to type '{1}' may be a mistake
  TS2355 // A function whose declared type is neither 'void' nor 'any' must return a value
  TS2356 // An arithmetic operand must be of type 'any', 'number', 'bigint' or an enum type
  TS2357 // The operand of an increment or decrement operator must be a variable
  TS2358 // The left-hand side of an 'instanceof' expression must be of type 'any', an object type or a type parameter
  TS2359 // The right-hand side of an 'instanceof' expression must be of type 'any' or of a type assignable to the 'Function' interface type
  TS2362 // The left-hand side of an arithmetic operation must be of type 'any', 'number', 'bigint' or an enum type
  TS2363 // The right-hand side of an arithmetic operation must be of type 'any', 'number', 'bigint' or an enum type
  TS2364 // The left-hand side of an assignment expression must be a variable or a property access
  TS2365 // Operator '{0}' cannot be applied to types '{1}' and '{2}'
  TS2366 // Function lacks ending return statement and return type does not include 'undefined'
  TS2367 // This condition will always return '{0}' since the types '{1}' and '{2}' have no overlap
  TS2368 // Type parameter name cannot be '{0}'
  TS2369 // A parameter property is only allowed in a constructor implementation
  TS2370 // A rest parameter must be of an array type
  TS2371 // A parameter initializer is only allowed in a function or constructor implementation
  TS2372 // Parameter '{0}' cannot reference itself
  TS2376 // A 'super' call must be the first statement in the constructor
  TS2377 // Constructors for derived classes must contain a 'super' call
  TS2378 // A 'get' accessor must return a value

  // ============================================================================
  // Super Call Validation Errors (TS17005, TS17009)
  // ============================================================================
  TS17005 // A constructor cannot contain a 'super' call when its class extends 'null'
  TS17009 // 'super' must be called before accessing 'this' in the constructor of a derived class

  // ============================================================================
  // Overload & Function Errors (2383-2395)
  // ============================================================================
  TS2379 // Getter and setter accessors do not agree in visibility
  TS2380 // 'get' and 'set' accessor must have the same type
  TS2383 // Overload signatures must all be ambient or non-ambient
  TS2388 // Function overload must not be static
  TS2389 // Function implementation signature must be assignable to the overload signature
  TS2390 // Constructor implementation is missing
  TS2391 // Function implementation is missing or not immediately following the declaration
  TS2393 // Duplicate function implementation
  TS2394 // This overload signature is not compatible with its implementation signature
  TS2395 // Individual declarations in merged declaration '{0}' must be all exported or all local

  // ============================================================================
  // Variable Declaration Errors (2403-2460)
  // ============================================================================
  TS2403 // Subsequent variable declarations must have the same type
  TS2406 // The left-hand side of a 'for...in' statement must be a variable or a property access
  TS2407 // The right-hand side of a 'for...in' statement must be of type 'any', an object type or a type parameter
  TS2410 // Class '{0}' incorrectly implements interface '{1}'
  TS2411 // Property '{0}' of type '{1}' is not assignable to '{2}' index type '{3}'
  TS2412 // Type '{0}' is not assignable to type '{1}' with 'exactOptionalPropertyTypes: true'
  TS2415 // Class '{0}' incorrectly extends base class '{1}'
  TS2416 // Property '{0}' in type '{1}' is not assignable to the same property in base type '{2}'
  TS2417 // Class static side '{0}' incorrectly extends base class static side '{1}'
  TS2420 // Class '{0}' incorrectly implements interface '{1}'
  TS2430 // Interface '{0}' incorrectly extends interface '{1}'
  TS2445 // Property '{0}' is protected and only accessible within class '{1}' and its subclasses
  TS2446 // Property '{0}' is protected in type '{1}' but public in type '{2}'
  TS2448 // Block-scoped variable '{0}' used before its declaration
  TS2451 // Cannot redeclare block-scoped variable '{0}'
  TS2452 // An enum member cannot have a numeric name
  TS2454 // Variable '{0}' is used before being assigned
  TS2456 // Type alias '{0}' circularly references itself
  TS2459 // Type '{0}' has no property '{1}' and no string index signature
  TS2460 // Type '{0}' is not an array type

  // ============================================================================
  // Destructuring & Iteration Errors (2461-2467)
  // ============================================================================
  TS2461 // Type '{0}' is not an array type (for parameter binding patterns)
  TS2462 // A rest element cannot have an initializer
  TS2463 // A binding pattern parameter cannot be optional in an implementation signature
  TS2464 // A computed property name must be of type 'string', 'number', 'symbol', or 'any'
  TS2465 // 'await' expression is only allowed within an async function
  TS2466 // 'yield' expression is only allowed within a generator body
  TS2467 // The type of a 'catch' clause variable must be 'any' or 'unknown'

  // ============================================================================
  // Enum Errors (2431-2432, 2452, 2474-2478)
  // ============================================================================
  TS2431 // Enum name cannot be '{0}'
  TS2432 // In an enum with multiple declarations, only one declaration can omit an initializer for its first enum element
  TS2474 // const enum member initializers can only contain literal values and other computed enum values
  TS2475 // 'const' enums can only be used in property or index access expressions or the right hand side of an import declaration or export assignment or type query
  TS2476 // A const enum member can only be accessed using a string literal
  TS2477 // 'const' enum member initializer was evaluated to a non-finite value
  TS2478 // 'const' enum member initializer was evaluated to disallowed value 'NaN'
  TS2480 // '{0}' is not allowed to be used as a name in '{1}' or 'const' declarations
  TS2481 // Cannot initialize outer scoped variable '{0}' in the same scope as block scoped declaration '{1}'
  TS18004 // No value exists in scope for the shorthand property '{0}'. Either declare one or provide an initializer
  TS18033 // Type '{0}' is not assignable to type 'number' as required for computed enum member values

  // ============================================================================
  // Export & Module Errors (2484-2502)
  // ============================================================================
  TS2484 // Export declaration conflicts with exported declaration of '{0}'
  TS2487 // The left-hand side of a 'for...of' statement must be a variable or a property access
  TS2488 // Type '{0}' must have a '[Symbol.iterator]()' method that returns an iterator
  TS2493 // Tuple type '{0}' of length '{1}' has no element at index '{2}'
  TS2494 // Using a private name '{0}'
  TS2496 // The 'arguments' object cannot be referenced in an arrow function or a top-level script
  TS2497 // This module can only be referenced with ECMAScript imports/exports
  TS2502 // '{0}' is referenced directly or indirectly in its own base expression
  TS2505 // A generator cannot have a 'void' type annotation

  // ============================================================================
  // Abstract Class Errors (2508-2520)
  // ============================================================================
  TS2508 // No base constructor has the specified number of type arguments
  TS2510 // Base constructors must all have the same return type
  TS2511 // Cannot create an instance of an abstract class
  TS2515 // Non-abstract class '{0}' does not implement inherited abstract member '{1}' from class '{2}'
  TS2516 // Abstract methods can only appear within an abstract class
  TS2517 // A non-abstract class member cannot be declared abstract
  TS2520 // 'abstract' modifier can only appear on a class, method, or property declaration
  TS2523 // 'yield' expressions cannot be used in a parameter initializer

  // ============================================================================
  // Null Safety Errors (2527-2542)
  // ============================================================================
  TS2527 // The inferred type of '{0}' references an inaccessible '{1}' type
  TS2528 // A module cannot have multiple default exports
  TS2531 // Object is possibly 'null'
  TS2532 // Object is possibly 'undefined'
  TS2533 // Object is possibly 'null' or 'undefined'
  TS2536 // Type '{0}' cannot be used to index type '{1}'
  TS2538 // Type '{0}' cannot be used as an index type
  TS2540 // Cannot assign to '{0}' because it is a read-only property
  TS2542 // Index signature in type '{0}' only permits reading

  // ============================================================================
  // Array & Iteration Errors (2548-2557)
  // ============================================================================
  TS2548 // Type '{0}' is not an array type or a string type
  TS2549 // Type '{0}' is not an array type or a string type. Use compiler option '--downlevelIteration' to allow iterating of iterators
  TS2551 // Property '{0}' does not exist on type '{1}'. Did you mean '{2}'?
  TS2552 // Cannot find name '{0}'. Did you mean '{1}'?
  TS2553 // Computed values are not permitted in an enum with string valued members
  TS2554 // Expected {0} arguments, but got {1}
  TS2555 // Expected at least {0} arguments, but got {1}
  TS2556 // A spread argument must either have a tuple type or be passed to a rest parameter
  TS2557 // Expected {0} arguments, but got {1} or more

  // ============================================================================
  // Type Arguments & Generic Errors (2558-2571)
  // ============================================================================
  TS2558 // Expected {0} type arguments, but got {1}
  TS2559 // Type '{0}' has no properties in common with type '{1}'
  TS2561 // Object literal may only specify known properties, and '{0}' does not exist in type '{1}'
  TS2564 // Property '{0}' has no initializer and is not definitely assigned in the constructor
  TS2565 // Property '{0}' is used before being assigned
  TS2566 // A rest element cannot contain a binding pattern
  TS2571 // Object is of type 'unknown'

  // ============================================================================
  // Type Complexity Errors (2574-2591)
  // ============================================================================
  TS2574 // A rest element type must be an array type
  TS2575 // No overload expects {0} arguments, but overloads do exist that expect either {1} or {2} arguments
  TS2576 // Property '{0}' is a static member of type '{1}'
  TS2578 // Unused '@ts-expect-error' directive
  TS2579 // Cannot find name '{0}'. Do you need to install type definitions for a test runner?
  TS2580 // Cannot find name '{0}'. Do you need to change your target library?
  TS2584 // Cannot find name '{0}'. Do you need to change your target library?
  TS2588 // Cannot assign to '{0}' because it is a constant
  TS2589 // Type instantiation is excessively deep and possibly infinite
  TS2590 // Expression produces a union type that is too complex to represent
  TS2591 // Cannot import type declaration files

  // ============================================================================
  // JSX Errors (2602-2608)
  // ============================================================================
  TS2602 // JSX element implicitly has type 'any' because the global type 'JSX.Element' does not exist
  TS2604 // JSX element type '{0}' does not have any construct or call signatures
  TS2607 // JSX element class does not support attributes because it does not have a '{0}' property
  TS2608 // Cannot use JSX unless the '--jsx' flag is provided

  // ============================================================================
  // Class & Constructor Errors (2630-2660)
  // ============================================================================
  TS2630 // Cannot assign an abstract constructor type to a non-abstract constructor type
  TS2631 // Cannot assign to '{0}' because it is a read-only property
  TS2632 // Types have separate declarations of a private property '{0}'
  TS2633 // This type has or is using private name '{0}'
  TS2649 // Cannot augment module '{0}' with value exports because it resolves to a non-module entity
  TS2651 // A member initializer in a enum declaration cannot reference members declared after it
  TS2655 // Types of call signatures are incompatible
  TS2656 // Types of construct signatures are incompatible
  TS2657 // JSX expressions must have one parent element

  // ============================================================================
  // This Context Errors (2673-2690)
  // ============================================================================
  TS2673 // Constructor of class '{0}' is private and only accessible within the class declaration
  TS2674 // Constructor of class '{0}' is protected and only accessible within the class declaration
  TS2678 // Type '{0}' is not comparable to type '{1}'
  TS2681 // A constructor cannot have a 'this' parameter
  TS2683 // 'this' implicitly has type 'any' because it does not have a type annotation
  TS2684 // The 'this' context of type '{0}' is not assignable to method's 'this' of type '{1}'
  TS2685 // The 'this' types of each signature are incompatible
  TS2686 // '{0}' refers to a UMD global, but the current file is a module
  TS2687 // All declarations of '{0}' must have identical modifiers
  TS2688 // Cannot find type definition file for '{0}'
  TS2689 // Cannot extend an interface '{0}'. Did you mean 'implements'?
  TS2690 // '{0}' only refers to a type, but is being used as a value here

  // ============================================================================
  // Import & Module Path Errors (2691-2710)
  // ============================================================================
  TS2691 // An import path cannot end with a '{0}' extension
  TS2692 // Cannot find module '{0}' or its corresponding type declarations
  TS2693 // '{0}' only refers to a type, but is being used as a value here
  TS2694 // Namespace '{0}' has no exported member '{1}'
  TS2695 // Left side of comma operator is unused and has no side effects
  TS2700 // Rest types may only be created from object types
  TS2701 // The target of an object rest assignment must be a variable or a property access
  TS2702 // The target of an object rest assignment may not be an optional property access
  TS2703 // The operand of a 'delete' operator must be a property reference
  TS2704 // An iterator must have a 'next()' method
  TS2706 // Required type parameters may not follow optional type parameters
  TS2707 // Generic type '{0}' requires between {1} and {2} type arguments
  TS2709 // Cannot use namespace '{0}' as a type
  TS2710 // Cannot use namespace '{0}' as a value

  // ============================================================================
  // Object Literal & Spread Errors (2711-2736)
  // ============================================================================
  TS2711 // Object literal may only specify known properties, but '{0}' does not exist in type '{1}'. Did you mean to write '{2}'?
  TS2713 // Cannot invoke an expression whose type lacks a call signature
  TS2716 // Index signature parameter type must be 'string', 'number', 'symbol', or a template literal type
  TS2717 // Type '{0}' cannot be assigned to type '{1}'
  TS2718 // 'super' must be called before accessing a property of 'super' in the constructor of a derived class
  TS2722 // Cannot invoke an object which is possibly 'undefined'
  TS2723 // Cannot invoke an object which is possibly 'null' or 'undefined'
  TS2724 // '{0}' has no exported member named '{1}'. Did you mean '{2}'?
  TS2729 // Property '{0}' is used before its initialization
  TS2730 // 'infer' declarations are only permitted in the 'extends' clause of a conditional type
  TS2733 // Property '{0}' was also declared here
  TS2736 // Operator '{0}' cannot be applied to type '{1}'
  TS2737 // BigInt literals are not available when targeting lower than ES2020

  // ============================================================================
  // Property & Type Errors (2739-2761)
  // ============================================================================
  TS2739 // Type '{0}' is missing the following properties from type '{1}': {2}
  TS2740 // Type '{0}' is missing the following properties from type '{1}': {2}, and {3} more
  TS2741 // Property '{0}' is missing in type '{1}' but required in type '{2}'
  TS2742 // The inferred type of '{0}' cannot be named without a reference to '{1}'
  TS2744 // Type '{0}' does not satisfy the constraint '{1}'
  TS2745 // Property '{0}' is incompatible with index signature
  TS2746 // Property '{0}' has conflicting declarations and is inaccessible in type '{1}'
  TS2747 // 'new' expression, whose target lacks a construct signature, implicitly has an 'any' type
  TS2748 // Cannot access '{0}' before initialization
  TS2749 // '{0}' refers to a value, but is being used as a type here. Did you mean 'typeof {0}'?
  TS2750 // A class cannot extend a primitive type like '{0}'
  TS2751 // Cannot assign an abstract constructor type to a non-abstract constructor type
  TS2752 // Type '{0}' is not assignable to type '{1}'. Two different types with this name exist
  TS2753 // '{0}' cannot be used as a value because it was exported using 'export type'
  TS2754 // The return type of an async function or method must be the global Promise<T> type
  TS2755 // The inferred type of this node exceeds the maximum length the compiler will serialize
  TS2757 // Type '{0}' is not assignable to type '{1}'
  TS2758 // Types of property '{0}' are incompatible
  TS2761 // Duplicate identifier '{0}'

  // ============================================================================
  // Spread & Yield Errors (2762-2775)
  // ============================================================================
  TS2762 // Spread types may only be created from object types
  TS2764 // 'yield' expression implicitly results in an 'any' type because its containing generator lacks a return-type annotation
  TS2766 // Cannot find module '{0}'. Did you mean to set the 'moduleResolution' option to 'node'?
  TS2767 // 'get' and 'set' accessors cannot declare 'this' parameters
  TS2769 // No overload matches this call
  TS2770 // Type of 'yield' operand in an async generator must either be a valid promise or must not contain a callable 'then' member
  TS2771 // Type is referenced directly or indirectly in the fulfillment callback of its own 'then' method
  TS2772 // Cannot use 'in' operator to search for '{0}' in '{1}'
  TS2773 // This condition will always return true since this function is always defined
  TS2774 // This condition will always return true since this '{0}' is always defined

  // ============================================================================
  // Private Member Errors (2776-2810)
  // ============================================================================
  TS2776 // Cannot read private member '{0}' here because it is not declared in class '{1}'
  TS2790 // The operand of a 'delete' operator must be optional
  TS2792 // Cannot find module '{0}'. Consider using '--resolveJsonModule' to import module with '.json' extension
  TS2793 // File '{0}' is not under 'rootDir' '{1}'. 'rootDir' is expected to contain all source files
  TS2794 // Expected {0} arguments, but got {1}. Did you forget to include 'void' in your type argument to 'Promise'?
  TS2800 // Operator '{0}' cannot be applied to types '{1}' and '{2}'
  TS2802 // Type '{0}' can only be iterated through when using the '--downlevelIteration' flag or with a '--target' of 'es2015' or higher
  TS2803 // Cannot assign to private method '{0}'. Private methods are not writable
  TS2804 // Expected {0} type arguments, but got {1}
  TS2806 // Type 'void' is not a valid type for a destructuring assignment target
  TS2807 // This syntax requires an imported helper named '{0}' with {1} parameters, which is not compatible with the one in '{2}'. Consider upgrading your version of '{2}'.
  TS2808 // A required element cannot follow an optional element
  TS2809 // Index signature must have a type annotation
  TS2810 // Property '{0}' can only be assigned to by using 'this' access within the class body

  // ============================================================================
  // Callable & Constructable Errors (2834-2859)
  // ============================================================================
  TS2834 // This expression is not callable because it is a 'get' accessor. Did you mean to use it without '()'?
  TS2835 // Each member of the union type '{0}' has signatures, but none of those signatures are compatible with each other
  TS2839 // This import is never used as a value and must use 'import type' because 'importsNotUsedAsValues' is set to 'error'
  TS2845 // A property of an interface or type literal whose type is a 'unique symbol' type must be 'readonly'
  TS2848 // Cannot assign to '{0}' because it is an import
  TS2855 // No value exists in scope for the shorthand property '{0}'
  TS2856 // Classes may not have a field named 'constructor'
  TS2857 // JSX element '{0}' has no corresponding closing tag
  TS2859 // A 'super' call must be a root-level statement within a constructor of a derived class that contains initialized properties

  // ============================================================================
  // Build/Emit Errors (4000-4099)
  // ============================================================================
  TS4000 // Import declaration '{0}' is using private name '{1}'
  TS4002 // Type parameter '{0}' of exported class has or is using private name '{1}'
  TS4004 // Parameter '{0}' of exported function has or is using private name '{1}'
  TS4020 // Extends clause of exported class '{0}' has or is using private name '{1}'
  TS4022 // Implements clause of exported class '{0}' has or is using private name '{1}'
  TS4023 // Extends expression of exported class '{0}' is not a class or interface
  TS4025 // Exported variable '{0}' has or is using name '{1}' from external module '{2}'
  TS4030 // Public property '{0}' of exported class has or is using private name '{1}'
  TS4031 // Public static property '{0}' of exported class has or is using private name '{1}'
  TS4032 // Type parameter '{0}' of exported function has or is using private name '{1}'
  TS4033 // Type parameter '{0}' of public static method from exported class has or is using private name '{1}'
  TS4043 // Return type of public getter for property '{0}' from exported class has or is using private name '{1}'
  TS4044 // Parameter '{0}' of public setter from exported class has or is using private name '{1}'
  TS4045 // Return type of method from exported interface has or is using private name '{0}'
  TS4048 // Parameter '{0}' of method from exported interface has or is using private name '{1}'
  TS4049 // Return type of constructor signature from exported interface has or is using private name '{0}'
  TS4055 // Return type of call signature from exported interface has or is using private name '{0}'
  TS4058 // Parameter '{0}' of call signature from exported interface has or is using private name '{1}'
  TS4060 // Return type of index signature from exported interface has or is using private name '{0}'
  TS4063 // Parameter '{0}' of index signature from exported interface has or is using private name '{1}'
  TS4064 // Default export of the module has or is using private name '{0}'
  TS4065 // Type parameter '{0}' of exported type alias has or is using private name '{1}'
  TS4067 // Property '{0}' of exported mapped type has or is using private name '{1}'
  TS4083 // Exported type alias '{0}' has or is using private name '{1}'
  TS4084 // Type parameter '{0}' of exported class expression has or is using private name '{1}'
  TS4090 // Cannot find parameter '{0}'
  TS4091 // A rest parameter must be of an array type
  TS4092 // A 'set' accessor cannot have a rest parameter
  TS4094 // A 'get' accessor must have at most one parameter
  TS4097 // A 'set' accessor must have exactly one parameter

  // ============================================================================
  // Compiler Options & Deprecation Warnings (5000-5999)
  // ============================================================================
  TS5107 // Option 'module={0}' is deprecated and will stop functioning in TypeScript 7.0

  // ============================================================================
  // Unreachable Code & Implicit Any (7000-7099)
  // ============================================================================
  TS7005 // Variable '{0}' implicitly has an '{1}' type
  TS7022 // '{0}' implicitly has type 'any' because it does not have a type annotation and is referenced directly or indirectly in its own initializer
  TS7023 // '{0}' implicitly has return type 'any' because it does not have a return type annotation and is referenced directly or indirectly in one of its return expressions
  TS7027 // Unreachable code detected
  TS7034 // Variable '{0}' implicitly has type '{1}' in some locations where its type cannot be determined
  TS7055 // '{0}', which lacks return-type annotation, implicitly has an 'any' yield type
  TS7057 // 'yield' expression implicitly results in an 'any' type because its containing generator lacks a return-type annotation
} derive(Show, Eq)

///|
/// Convert DiagnosticCode to its numeric value
pub fn DiagnosticCode::to_int(self : DiagnosticCode) -> Int {
  match self {
    // Syntax Errors (1xxx)
    TS1005 => 1005
    TS1104 => 1104
    TS1109 => 1109
    TS1155 => 1155
    TS1160 => 1160
    TS1163 => 1163
    TS1166 => 1166
    TS1182 => 1182
    TS1186 => 1186
    TS1187 => 1187
    TS1188 => 1188
    TS1214 => 1214
    TS1221 => 1221
    TS1308 => 1308
    TS1357 => 1357
    TS1359 => 1359
    // Name Resolution Errors (2304-2318)
    TS2304 => 2304
    TS2305 => 2305
    TS2306 => 2306
    TS2307 => 2307
    TS2308 => 2308
    TS2314 => 2314
    TS2315 => 2315
    TS2318 => 2318
    // Type Assignment & Compatibility Errors (2320-2380)
    TS2320 => 2320
    TS2322 => 2322
    TS2324 => 2324
    TS2326 => 2326
    TS2328 => 2328
    TS2329 => 2329
    TS2331 => 2331
    TS2332 => 2332
    TS2334 => 2334
    TS2335 => 2335
    TS2337 => 2337
    TS2339 => 2339
    TS2341 => 2341
    TS2344 => 2344
    TS2345 => 2345
    TS2348 => 2348
    TS2349 => 2349
    TS2350 => 2350
    TS2351 => 2351
    TS2352 => 2352
    TS2355 => 2355
    TS2356 => 2356
    TS2357 => 2357
    TS2358 => 2358
    TS2359 => 2359
    TS2362 => 2362
    TS2363 => 2363
    TS2364 => 2364
    TS2365 => 2365
    TS2366 => 2366
    TS2367 => 2367
    TS2368 => 2368
    TS2369 => 2369
    TS2370 => 2370
    TS2371 => 2371
    TS2372 => 2372
    TS2376 => 2376
    TS2377 => 2377
    TS2378 => 2378
    // Super Call Validation Errors
    TS17005 => 17005
    TS17009 => 17009
    // Overload & Function Errors (2383-2395)
    TS2379 => 2379
    TS2380 => 2380
    TS2383 => 2383
    TS2388 => 2388
    TS2389 => 2389
    TS2390 => 2390
    TS2391 => 2391
    TS2393 => 2393
    TS2394 => 2394
    TS2395 => 2395
    // Variable Declaration Errors (2403-2460)
    TS2403 => 2403
    TS2406 => 2406
    TS2407 => 2407
    TS2410 => 2410
    TS2411 => 2411
    TS2412 => 2412
    TS2415 => 2415
    TS2416 => 2416
    TS2417 => 2417
    TS2420 => 2420
    TS2430 => 2430
    TS2445 => 2445
    TS2446 => 2446
    TS2448 => 2448
    TS2451 => 2451
    TS2452 => 2452
    TS2454 => 2454
    TS2456 => 2456
    TS2459 => 2459
    TS2460 => 2460
    // Destructuring & Iteration Errors (2461-2467)
    TS2461 => 2461
    TS2462 => 2462
    TS2463 => 2463
    TS2464 => 2464
    TS2465 => 2465
    TS2466 => 2466
    TS2467 => 2467
    // Enum Errors (2431-2432, 2452, 2474-2478, 18033)
    TS2431 => 2431
    TS2432 => 2432
    TS2474 => 2474
    TS2475 => 2475
    TS2476 => 2476
    TS2477 => 2477
    TS2478 => 2478
    TS2480 => 2480
    TS2481 => 2481
    // Export & Module Errors (2484-2502)
    TS2484 => 2484
    TS2487 => 2487
    TS2488 => 2488
    TS2493 => 2493
    TS2494 => 2494
    TS2496 => 2496
    TS2497 => 2497
    TS2502 => 2502
    TS2505 => 2505
    // Abstract Class Errors (2508-2520)
    TS2508 => 2508
    TS2510 => 2510
    TS2511 => 2511
    TS2515 => 2515
    TS2516 => 2516
    TS2517 => 2517
    TS2520 => 2520
    TS2523 => 2523
    // Null Safety Errors (2527-2542)
    TS2527 => 2527
    TS2528 => 2528
    TS2531 => 2531
    TS2532 => 2532
    TS2533 => 2533
    TS2536 => 2536
    TS2538 => 2538
    TS2540 => 2540
    TS2542 => 2542
    // Array & Iteration Errors (2548-2557)
    TS2548 => 2548
    TS2549 => 2549
    TS2551 => 2551
    TS2552 => 2552
    TS2553 => 2553
    TS2554 => 2554
    TS2555 => 2555
    TS2556 => 2556
    TS2557 => 2557
    // Type Arguments & Generic Errors (2558-2571)
    TS2558 => 2558
    TS2559 => 2559
    TS2561 => 2561
    TS2564 => 2564
    TS2565 => 2565
    TS2566 => 2566
    TS2571 => 2571
    // Type Complexity Errors (2574-2591)
    TS2574 => 2574
    TS2575 => 2575
    TS2576 => 2576
    TS2578 => 2578
    TS2579 => 2579
    TS2580 => 2580
    TS2584 => 2584
    TS2588 => 2588
    TS2589 => 2589
    TS2590 => 2590
    TS2591 => 2591
    // JSX Errors (2602-2608)
    TS2602 => 2602
    TS2604 => 2604
    TS2607 => 2607
    TS2608 => 2608
    // Class & Constructor Errors (2630-2660)
    TS2630 => 2630
    TS2631 => 2631
    TS2632 => 2632
    TS2633 => 2633
    TS2649 => 2649
    TS2651 => 2651
    TS2655 => 2655
    TS2656 => 2656
    TS2657 => 2657
    // This Context Errors (2673-2690)
    TS2673 => 2673
    TS2674 => 2674
    TS2678 => 2678
    TS2681 => 2681
    TS2683 => 2683
    TS2684 => 2684
    TS2685 => 2685
    TS2686 => 2686
    TS2687 => 2687
    TS2688 => 2688
    TS2689 => 2689
    TS2690 => 2690
    // Import & Module Path Errors (2691-2710)
    TS2691 => 2691
    TS2692 => 2692
    TS2693 => 2693
    TS2694 => 2694
    TS2695 => 2695
    TS2700 => 2700
    TS2701 => 2701
    TS2702 => 2702
    TS2703 => 2703
    TS2704 => 2704
    TS2706 => 2706
    TS2707 => 2707
    TS2709 => 2709
    TS2710 => 2710
    // Object Literal & Spread Errors (2711-2736)
    TS2711 => 2711
    TS2713 => 2713
    TS2716 => 2716
    TS2717 => 2717
    TS2718 => 2718
    TS2722 => 2722
    TS2723 => 2723
    TS2724 => 2724
    TS2729 => 2729
    TS2730 => 2730
    TS2733 => 2733
    TS2736 => 2736
    TS2737 => 2737
    // Property & Type Errors (2739-2761)
    TS2739 => 2739
    TS2740 => 2740
    TS2741 => 2741
    TS2742 => 2742
    TS2744 => 2744
    TS2745 => 2745
    TS2746 => 2746
    TS2747 => 2747
    TS2748 => 2748
    TS2749 => 2749
    TS2750 => 2750
    TS2751 => 2751
    TS2752 => 2752
    TS2753 => 2753
    TS2754 => 2754
    TS2755 => 2755
    TS2757 => 2757
    TS2758 => 2758
    TS2761 => 2761
    // Spread & Yield Errors (2762-2775)
    TS2762 => 2762
    TS2764 => 2764
    TS2766 => 2766
    TS2767 => 2767
    TS2769 => 2769
    TS2770 => 2770
    TS2771 => 2771
    TS2772 => 2772
    TS2773 => 2773
    TS2774 => 2774
    // Private Member Errors (2776-2810)
    TS2776 => 2776
    TS2790 => 2790
    TS2792 => 2792
    TS2793 => 2793
    TS2794 => 2794
    TS2800 => 2800
    TS2802 => 2802
    TS2803 => 2803
    TS2804 => 2804
    TS2806 => 2806
    TS2807 => 2807
    TS2808 => 2808
    TS2809 => 2809
    TS2810 => 2810
    // Callable & Constructable Errors (2834-2859)
    TS2834 => 2834
    TS2835 => 2835
    TS2839 => 2839
    TS2845 => 2845
    TS2848 => 2848
    TS2855 => 2855
    TS2856 => 2856
    TS2857 => 2857
    TS2859 => 2859
    // Build/Emit Errors (4000-4099)
    TS4000 => 4000
    TS4002 => 4002
    TS4004 => 4004
    TS4020 => 4020
    TS4022 => 4022
    TS4023 => 4023
    TS4025 => 4025
    TS4030 => 4030
    TS4031 => 4031
    TS4032 => 4032
    TS4033 => 4033
    TS4043 => 4043
    TS4044 => 4044
    TS4045 => 4045
    TS4048 => 4048
    TS4049 => 4049
    TS4055 => 4055
    TS4058 => 4058
    TS4060 => 4060
    TS4063 => 4063
    TS4064 => 4064
    TS4065 => 4065
    TS4067 => 4067
    TS4083 => 4083
    TS4084 => 4084
    TS4090 => 4090
    TS4091 => 4091
    TS4092 => 4092
    TS4094 => 4094
    TS4097 => 4097
    // Compiler Options & Deprecation Warnings (5000-5999)
    TS5107 => 5107
    // Unreachable Code & Implicit Any (7000-7099)
    TS7005 => 7005
    TS7022 => 7022
    TS7023 => 7023
    TS7027 => 7027
    TS7034 => 7034
    TS7055 => 7055
    TS7057 => 7057
    // Shorthand property and enum errors (18xxx)
    TS18004 => 18004
    TS18033 => 18033
  }
}

///|
/// Convert numeric code to DiagnosticCode (if valid)
pub fn DiagnosticCode::from_int(code : Int) -> DiagnosticCode? {
  match code {
    // Syntax Errors (1xxx)
    1005 => Some(TS1005)
    1104 => Some(TS1104)
    1109 => Some(TS1109)
    1155 => Some(TS1155)
    1160 => Some(TS1160)
    1166 => Some(TS1166)
    1163 => Some(TS1163)
    1182 => Some(TS1182)
    1186 => Some(TS1186)
    1187 => Some(TS1187)
    1188 => Some(TS1188)
    1214 => Some(TS1214)
    1221 => Some(TS1221)
    1308 => Some(TS1308)
    1357 => Some(TS1357)
    1359 => Some(TS1359)
    // Name Resolution Errors (2304-2318)
    2304 => Some(TS2304)
    2305 => Some(TS2305)
    2306 => Some(TS2306)
    2307 => Some(TS2307)
    2308 => Some(TS2308)
    2314 => Some(TS2314)
    2315 => Some(TS2315)
    2318 => Some(TS2318)
    // Type Assignment & Compatibility Errors (2320-2380)
    2320 => Some(TS2320)
    2322 => Some(TS2322)
    2324 => Some(TS2324)
    2326 => Some(TS2326)
    2328 => Some(TS2328)
    2329 => Some(TS2329)
    2332 => Some(TS2332)
    2334 => Some(TS2334)
    2335 => Some(TS2335)
    2337 => Some(TS2337)
    2339 => Some(TS2339)
    2341 => Some(TS2341)
    2344 => Some(TS2344)
    2345 => Some(TS2345)
    2348 => Some(TS2348)
    2349 => Some(TS2349)
    2350 => Some(TS2350)
    2351 => Some(TS2351)
    2352 => Some(TS2352)
    2355 => Some(TS2355)
    2356 => Some(TS2356)
    2357 => Some(TS2357)
    2358 => Some(TS2358)
    2359 => Some(TS2359)
    2362 => Some(TS2362)
    2363 => Some(TS2363)
    2364 => Some(TS2364)
    2365 => Some(TS2365)
    2366 => Some(TS2366)
    2367 => Some(TS2367)
    2368 => Some(TS2368)
    2369 => Some(TS2369)
    2371 => Some(TS2371)
    2372 => Some(TS2372)
    2376 => Some(TS2376)
    2377 => Some(TS2377)
    2378 => Some(TS2378)
    // Overload & Function Errors (2383-2395)
    2379 => Some(TS2379)
    2380 => Some(TS2380)
    2383 => Some(TS2383)
    2388 => Some(TS2388)
    2389 => Some(TS2389)
    2390 => Some(TS2390)
    2391 => Some(TS2391)
    2393 => Some(TS2393)
    2394 => Some(TS2394)
    2395 => Some(TS2395)
    // Variable Declaration Errors (2403-2460)
    2403 => Some(TS2403)
    2406 => Some(TS2406)
    2407 => Some(TS2407)
    2410 => Some(TS2410)
    2411 => Some(TS2411)
    2412 => Some(TS2412)
    2415 => Some(TS2415)
    2416 => Some(TS2416)
    2417 => Some(TS2417)
    2420 => Some(TS2420)
    2430 => Some(TS2430)
    2445 => Some(TS2445)
    2446 => Some(TS2446)
    2448 => Some(TS2448)
    2451 => Some(TS2451)
    2452 => Some(TS2452)
    2454 => Some(TS2454)
    2456 => Some(TS2456)
    2459 => Some(TS2459)
    2460 => Some(TS2460)
    // Destructuring & Iteration Errors (2461-2467)
    2461 => Some(TS2461)
    2462 => Some(TS2462)
    2463 => Some(TS2463)
    2464 => Some(TS2464)
    2465 => Some(TS2465)
    2466 => Some(TS2466)
    2467 => Some(TS2467)
    // Enum Errors (2431-2432, 2452, 2474-2478, 18033)
    2431 => Some(TS2431)
    2432 => Some(TS2432)
    2474 => Some(TS2474)
    2475 => Some(TS2475)
    2476 => Some(TS2476)
    2477 => Some(TS2477)
    2478 => Some(TS2478)
    2480 => Some(TS2480)
    2481 => Some(TS2481)
    // Shorthand property and enum errors (18xxx)
    18004 => Some(TS18004)
    18033 => Some(TS18033)
    // Export & Module Errors (2484-2505)
    2484 => Some(TS2484)
    2487 => Some(TS2487)
    2488 => Some(TS2488)
    2493 => Some(TS2493)
    2494 => Some(TS2494)
    2496 => Some(TS2496)
    2497 => Some(TS2497)
    2502 => Some(TS2502)
    2505 => Some(TS2505)
    // Abstract Class Errors (2508-2520)
    2508 => Some(TS2508)
    2510 => Some(TS2510)
    2511 => Some(TS2511)
    2515 => Some(TS2515)
    2516 => Some(TS2516)
    2517 => Some(TS2517)
    2520 => Some(TS2520)
    2523 => Some(TS2523)
    // Null Safety Errors (2527-2542)
    2527 => Some(TS2527)
    2528 => Some(TS2528)
    2531 => Some(TS2531)
    2532 => Some(TS2532)
    2533 => Some(TS2533)
    2536 => Some(TS2536)
    2538 => Some(TS2538)
    2540 => Some(TS2540)
    2542 => Some(TS2542)
    // Array & Iteration Errors (2548-2557)
    2548 => Some(TS2548)
    2549 => Some(TS2549)
    2551 => Some(TS2551)
    2552 => Some(TS2552)
    2553 => Some(TS2553)
    2554 => Some(TS2554)
    2555 => Some(TS2555)
    2556 => Some(TS2556)
    2557 => Some(TS2557)
    // Type Arguments & Generic Errors (2558-2571)
    2558 => Some(TS2558)
    2559 => Some(TS2559)
    2561 => Some(TS2561)
    2564 => Some(TS2564)
    2565 => Some(TS2565)
    2566 => Some(TS2566)
    2571 => Some(TS2571)
    // Type Complexity Errors (2574-2591)
    2574 => Some(TS2574)
    2575 => Some(TS2575)
    2576 => Some(TS2576)
    2578 => Some(TS2578)
    2579 => Some(TS2579)
    2580 => Some(TS2580)
    2584 => Some(TS2584)
    2588 => Some(TS2588)
    2589 => Some(TS2589)
    2590 => Some(TS2590)
    2591 => Some(TS2591)
    // JSX Errors (2602-2608)
    2602 => Some(TS2602)
    2604 => Some(TS2604)
    2607 => Some(TS2607)
    2608 => Some(TS2608)
    // Class & Constructor Errors (2630-2660)
    2630 => Some(TS2630)
    2631 => Some(TS2631)
    2632 => Some(TS2632)
    2633 => Some(TS2633)
    2649 => Some(TS2649)
    2651 => Some(TS2651)
    2655 => Some(TS2655)
    2656 => Some(TS2656)
    2657 => Some(TS2657)
    // This Context Errors (2673-2690)
    2673 => Some(TS2673)
    2674 => Some(TS2674)
    2678 => Some(TS2678)
    2681 => Some(TS2681)
    2683 => Some(TS2683)
    2684 => Some(TS2684)
    2685 => Some(TS2685)
    2686 => Some(TS2686)
    2687 => Some(TS2687)
    2688 => Some(TS2688)
    2689 => Some(TS2689)
    2690 => Some(TS2690)
    // Import & Module Path Errors (2691-2710)
    2691 => Some(TS2691)
    2692 => Some(TS2692)
    2693 => Some(TS2693)
    2694 => Some(TS2694)
    2695 => Some(TS2695)
    2700 => Some(TS2700)
    2701 => Some(TS2701)
    2702 => Some(TS2702)
    2704 => Some(TS2704)
    2706 => Some(TS2706)
    2707 => Some(TS2707)
    2709 => Some(TS2709)
    2710 => Some(TS2710)
    // Object Literal & Spread Errors (2711-2736)
    2711 => Some(TS2711)
    2713 => Some(TS2713)
    2716 => Some(TS2716)
    2717 => Some(TS2717)
    2718 => Some(TS2718)
    2722 => Some(TS2722)
    2723 => Some(TS2723)
    2724 => Some(TS2724)
    2729 => Some(TS2729)
    2730 => Some(TS2730)
    2733 => Some(TS2733)
    2736 => Some(TS2736)
    2737 => Some(TS2737)
    // Property & Type Errors (2739-2761)
    2739 => Some(TS2739)
    2740 => Some(TS2740)
    2741 => Some(TS2741)
    2742 => Some(TS2742)
    2744 => Some(TS2744)
    2745 => Some(TS2745)
    2746 => Some(TS2746)
    2747 => Some(TS2747)
    2748 => Some(TS2748)
    2749 => Some(TS2749)
    2750 => Some(TS2750)
    2751 => Some(TS2751)
    2752 => Some(TS2752)
    2753 => Some(TS2753)
    2754 => Some(TS2754)
    2755 => Some(TS2755)
    2757 => Some(TS2757)
    2758 => Some(TS2758)
    2761 => Some(TS2761)
    // Spread & Yield Errors (2762-2775)
    2762 => Some(TS2762)
    2764 => Some(TS2764)
    2766 => Some(TS2766)
    2767 => Some(TS2767)
    2769 => Some(TS2769)
    2770 => Some(TS2770)
    2771 => Some(TS2771)
    2772 => Some(TS2772)
    2773 => Some(TS2773)
    2774 => Some(TS2774)
    // Private Member Errors (2776-2810)
    2776 => Some(TS2776)
    2790 => Some(TS2790)
    2792 => Some(TS2792)
    2793 => Some(TS2793)
    2794 => Some(TS2794)
    2800 => Some(TS2800)
    2802 => Some(TS2802)
    2803 => Some(TS2803)
    2804 => Some(TS2804)
    2806 => Some(TS2806)
    2807 => Some(TS2807)
    2808 => Some(TS2808)
    2809 => Some(TS2809)
    2810 => Some(TS2810)
    // Callable & Constructable Errors (2834-2859)
    2834 => Some(TS2834)
    2835 => Some(TS2835)
    2839 => Some(TS2839)
    2845 => Some(TS2845)
    2848 => Some(TS2848)
    2855 => Some(TS2855)
    2856 => Some(TS2856)
    2857 => Some(TS2857)
    2859 => Some(TS2859)
    // Build/Emit Errors (4000-4099)
    4000 => Some(TS4000)
    4002 => Some(TS4002)
    4004 => Some(TS4004)
    4020 => Some(TS4020)
    4022 => Some(TS4022)
    4023 => Some(TS4023)
    4025 => Some(TS4025)
    4030 => Some(TS4030)
    4031 => Some(TS4031)
    4032 => Some(TS4032)
    4033 => Some(TS4033)
    4043 => Some(TS4043)
    4044 => Some(TS4044)
    4045 => Some(TS4045)
    4048 => Some(TS4048)
    4049 => Some(TS4049)
    4055 => Some(TS4055)
    4058 => Some(TS4058)
    4060 => Some(TS4060)
    4063 => Some(TS4063)
    4064 => Some(TS4064)
    4065 => Some(TS4065)
    4067 => Some(TS4067)
    4083 => Some(TS4083)
    4084 => Some(TS4084)
    4090 => Some(TS4090)
    4091 => Some(TS4091)
    4092 => Some(TS4092)
    4094 => Some(TS4094)
    4097 => Some(TS4097)
    // Compiler Options & Deprecation Warnings (5000-5999)
    5107 => Some(TS5107)
    // Unreachable Code & Implicit Any (7000-7099)
    7005 => Some(TS7005)
    7022 => Some(TS7022)
    7023 => Some(TS7023)
    7027 => Some(TS7027)
    7034 => Some(TS7034)
    7055 => Some(TS7055)
    7057 => Some(TS7057)
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
  ForOfStatement
  ForInStatement
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
  ts_expect_error_directives : Array[SourceLocation] // @ts-expect-error directive locations for TS2578 checking
  compiler_directives : CompilerDirectives // Compiler directives (@importHelpers, @target, etc.)
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
        return Some(TripleSlashDirective::{
          kind: ReferencePath(path),
          location,
        })
      None => ()
    }
    match extract_attribute(trimmed, "types") {
      Some(types) =>
        return Some(TripleSlashDirective::{
          kind: ReferenceTypes(types),
          location,
        })
      None => ()
    }
    // Check no-default-lib BEFORE lib (lib is a substring of no-default-lib)
    match extract_attribute(trimmed, "no-default-lib") {
      Some(no_default) => {
        let value = no_default == "true"
        return Some(TripleSlashDirective::{
          kind: NoDefaultLib(value),
          location,
        })
      }
      None => ()
    }
    match extract_attribute(trimmed, "lib") {
      Some(lib) =>
        return Some(TripleSlashDirective::{ kind: ReferenceLib(lib), location })
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
        return Some(TripleSlashDirective::{
          kind: AmdDependency(path),
          location,
        })
      None => ()
    }
  }
  None
}

///|
/// Trim whitespace from start and end of string
pub fn trim_whitespace(s : String) -> String {
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
