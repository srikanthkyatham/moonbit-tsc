///|
/// Built-in Type Helper Functions
///
/// This module provides helper functions and data structures for declaratively
/// defining built-in global types (Math, Console, JSON, Date, etc.) to eliminate
/// code duplication in type constructor functions.
///

///|
/// Type kind for declarative type specification
pub enum TypeKind {
  TKNumber
  TKString
  TKBoolean
  TKVoid
  TKAny
  TKSymbol
} derive(Debug)

///|
/// Parameter configuration for declarative method/function definitions
pub struct BuiltinParamConfig {
  param_name : String
  param_kind : TypeKind
  optional : Bool
  rest : Bool
} derive(Debug)

///|
/// Convert TypeKind to actual Type
fn type_kind_to_type(kind : TypeKind, info : TypeInfo) -> Type {
  match kind {
    TKNumber => Type::Number(info)
    TKString => Type::String(info)
    TKBoolean => Type::Boolean(info)
    TKVoid => Type::Void(info)
    TKAny => Type::Any(info)
    TKSymbol => Type::Symbol(info)
  }
}

///|
/// Create CheckerParameter from BuiltinParamConfig
fn param_config_to_checker_param(
  config : BuiltinParamConfig,
  info : TypeInfo
) -> CheckerParameter {
  CheckerParameter::{
    name: config.param_name,
    param_type: type_kind_to_type(config.param_kind, info),
    is_optional: config.optional,
    is_rest: config.rest,
  }
}

///|
/// Create a simple non-optional, non-readonly property
pub fn make_simple_property(name : String, prop_type : Type) -> PropertySignature {
  PropertySignature::{
    name,
    prop_type,
    is_optional: false,
    is_readonly: false,
    is_method: false,
  }
}

///|
/// Create a readonly property (for module exports and constants)
pub fn make_readonly_property(
  name : String,
  prop_type : Type
) -> PropertySignature {
  PropertySignature::{
    name,
    prop_type,
    is_optional: false,
    is_readonly: true,
    is_method: false,
  }
}

///|
/// Create a method property from function type parameters
pub fn make_method_property(
  name : String,
  parameters : Array[CheckerParameter],
  return_type : Type,
  info : TypeInfo
) -> PropertySignature {
  PropertySignature::{
    name,
    prop_type: Type::Function(CheckerFunctionType::{
      parameters,
      return_type,
      info,
    }),
    is_optional: false,
    is_readonly: false,
    is_method: true,
  }
}

///|
/// Create a method with a single parameter
pub fn make_unary_method(
  name : String,
  param_name : String,
  param_type : TypeKind,
  return_type : TypeKind,
  info : TypeInfo
) -> PropertySignature {
  let param = CheckerParameter::{
    name: param_name,
    param_type: type_kind_to_type(param_type, info),
    is_optional: false,
    is_rest: false,
  }
  make_method_property(
    name,
    [param],
    type_kind_to_type(return_type, info),
    info
  )
}

///|
/// Create a method with a rest parameter
pub fn make_rest_method(
  name : String,
  param_name : String,
  param_type : TypeKind,
  return_type : TypeKind,
  info : TypeInfo
) -> PropertySignature {
  let rest_param = CheckerParameter::{
    name: param_name,
    param_type: type_kind_to_type(param_type, info),
    is_optional: false,
    is_rest: true,
  }
  make_method_property(
    name,
    [rest_param],
    type_kind_to_type(return_type, info),
    info
  )
}

///|
/// Create a method with no parameters
pub fn make_nullary_method(
  name : String,
  return_type : TypeKind,
  info : TypeInfo
) -> PropertySignature {
  make_method_property(
    name,
    [],
    type_kind_to_type(return_type, info),
    info
  )
}

///|
/// Create a method with two parameters
pub fn make_binary_method(
  name : String,
  param1_name : String,
  param1_type : TypeKind,
  param2_name : String,
  param2_type : TypeKind,
  return_type : TypeKind,
  info : TypeInfo
) -> PropertySignature {
  let param1 = CheckerParameter::{
    name: param1_name,
    param_type: type_kind_to_type(param1_type, info),
    is_optional: false,
    is_rest: false,
  }
  let param2 = CheckerParameter::{
    name: param2_name,
    param_type: type_kind_to_type(param2_type, info),
    is_optional: false,
    is_rest: false,
  }
  make_method_property(
    name,
    [param1, param2],
    type_kind_to_type(return_type, info),
    info
  )
}

///|
/// Check whether a type name is a global type provided by the TypeScript
/// standard library (lib.es5.d.ts through lib.esnext.d.ts, plus common
/// DOM / WebWorker / scripthost globals). We do not model the full standard
/// library in the symbol table, so TS2304 ("Cannot find name") must be
/// suppressed for these names in type position to avoid false positives.
pub fn is_known_lib_type_name(name : String) -> Bool {
  // Large lib.dom.d.ts families, matched by prefix
  if name.has_prefix("HTML") ||
    name.has_prefix("SVG") ||
    name.has_prefix("CSS") ||
    name.has_prefix("IDB") ||
    name.has_prefix("RTC") ||
    name.has_prefix("WebGL") ||
    name.has_prefix("GPU") ||
    name.has_prefix("Intl") ||
    name.has_prefix("MediaStream") ||
    name.has_prefix("Audio") ||
    name.has_prefix("Speech") ||
    name.has_prefix("Performance") ||
    name.has_prefix("Payment") ||
    name.has_prefix("Push") ||
    name.has_prefix("Service") ||
    name.has_prefix("Text") ||
    name.has_prefix("Touch") ||
    name.has_prefix("Track") ||
    name.has_prefix("URL") ||
    name.has_prefix("WebSocket") ||
    name.has_prefix("Worker") ||
    name.has_prefix("XML") ||
    name.has_prefix("XPath") {
    return true
  }
  // lib.es5.d.ts interface families, matched by suffix
  if name.has_suffix("Constructor") ||
    name.has_suffix("EventMap") ||
    name.has_suffix("EventInit") ||
    name.has_suffix("Event") ||
    name.has_suffix("EventTarget") ||
    name.has_suffix("EventHandler") ||
    name.has_suffix("ElementTagNameMap") ||
    name.has_suffix("Options") ||
    name.has_suffix("Init") ||
    name.has_suffix("Callback") ||
    name.has_suffix("State") ||
    name.has_suffix("List") ||
    name.has_suffix("Observer") ||
    name.has_suffix("ObserverEntry") ||
    name.has_suffix("Registry") {
    return true
  }
  match name {
    // Lowercase intrinsic keywords that can arrive as type references
    "object"
    | "symbol"
    | "bigint"
    | "null"
    | "true"
    | "false"
    | "this"
    | "globalThis"
    | "intrinsic"
    // ECMAScript global object/value types (lib.es5.d.ts+)
    | "Array"
    | "ArrayLike"
    | "ReadonlyArray"
    | "ConcatArray"
    | "Object"
    | "Function"
    | "CallableFunction"
    | "NewableFunction"
    | "String"
    | "Number"
    | "Boolean"
    | "Symbol"
    | "BigInt"
    | "Date"
    | "RegExp"
    | "RegExpMatchArray"
    | "RegExpExecArray"
    | "Error"
    | "EvalError"
    | "RangeError"
    | "ReferenceError"
    | "SyntaxError"
    | "TypeError"
    | "URIError"
    | "AggregateError"
    | "SuppressedError"
    | "Promise"
    | "PromiseLike"
    | "Thenable"
    | "Generator"
    | "GeneratorFunction"
    | "AsyncGenerator"
    | "AsyncGeneratorFunction"
    | "Iterator"
    | "Iterable"
    | "IterableIterator"
    | "IteratorObject"
    | "ArrayIterator"
    | "MapIterator"
    | "SetIterator"
    | "StringIterator"
    | "IteratorResult"
    | "IteratorYieldResult"
    | "IteratorReturnResult"
    | "AsyncIterator"
    | "AsyncIterable"
    | "AsyncIterableIterator"
    | "AsyncIteratorObject"
    | "Map"
    | "WeakMap"
    | "Set"
    | "WeakSet"
    | "ReadonlyMap"
    | "ReadonlySet"
    | "WeakRef"
    | "FinalizationRegistry"
    | "Proxy"
    | "ProxyHandler"
    | "Reflect"
    | "ArrayBuffer"
    | "ArrayBufferLike"
    | "ArrayBufferView"
    | "ArrayBufferTypes"
    | "SharedArrayBuffer"
    | "DataView"
    | "Int8Array"
    | "Uint8Array"
    | "Uint8ClampedArray"
    | "Int16Array"
    | "Uint16Array"
    | "Int32Array"
    | "Uint32Array"
    | "Float16Array"
    | "Float32Array"
    | "Float64Array"
    | "BigInt64Array"
    | "BigUint64Array"
    | "Atomics"
    | "JSON"
    | "Math"
    | "Intl"
    | "PropertyKey"
    | "PropertyDescriptor"
    | "PropertyDescriptorMap"
    | "TypedPropertyDescriptor"
    | "TemplateStringsArray"
    | "ImportMeta"
    | "ImportCallOptions"
    | "ImportAssertions"
    | "ImportAttributes"
    | "IArguments"
    | "Disposable"
    | "AsyncDisposable"
    | "DisposableStack"
    | "AsyncDisposableStack"
    // Utility types (lib.es5.d.ts)
    | "Awaited"
    | "Partial"
    | "Required"
    | "Readonly"
    | "Pick"
    | "Record"
    | "Exclude"
    | "Extract"
    | "Omit"
    | "NonNullable"
    | "Parameters"
    | "ConstructorParameters"
    | "ReturnType"
    | "InstanceType"
    | "ThisParameterType"
    | "OmitThisParameter"
    | "ThisType"
    | "Uppercase"
    | "Lowercase"
    | "Capitalize"
    | "Uncapitalize"
    | "NoInfer"
    // Decorators (lib.es5.d.ts / lib.decorators.d.ts)
    | "ClassDecorator"
    | "PropertyDecorator"
    | "MethodDecorator"
    | "ParameterDecorator"
    | "ClassMemberDecoratorContext"
    | "DecoratorContext"
    | "DecoratorMetadata"
    | "DecoratorMetadataObject"
    | "ClassMethodDecoratorContext"
    | "ClassGetterDecoratorContext"
    | "ClassSetterDecoratorContext"
    | "ClassFieldDecoratorContext"
    | "ClassAccessorDecoratorContext"
    | "ClassAccessorDecoratorTarget"
    | "ClassAccessorDecoratorResult"
    // Common DOM / WebWorker globals (lib.dom.d.ts default lib)
    | "Window"
    | "Document"
    | "DocumentFragment"
    | "Element"
    | "Node"
    | "Attr"
    | "CharacterData"
    | "Comment"
    | "Range"
    | "Selection"
    | "ShadowRoot"
    | "Event"
    | "EventTarget"
    | "EventListener"
    | "EventListenerObject"
    | "Console"
    | "Storage"
    | "Location"
    | "History"
    | "Navigator"
    | "Screen"
    | "XMLHttpRequest"
    | "FormData"
    | "Blob"
    | "File"
    | "FileList"
    | "FileReader"
    | "Headers"
    | "Request"
    | "Response"
    | "WebSocket"
    | "Worker"
    | "MessagePort"
    | "MessageChannel"
    | "BroadcastChannel"
    | "AbortController"
    | "AbortSignal"
    | "DOMException"
    | "DOMParser"
    | "DOMStringMap"
    | "DOMTokenList"
    | "DOMRect"
    | "DOMRectReadOnly"
    | "ClientRect"
    | "MutationObserver"
    | "IntersectionObserver"
    | "ResizeObserver"
    | "Performance"
    | "Crypto"
    | "SubtleCrypto"
    | "TextEncoder"
    | "TextDecoder"
    | "ReadableStream"
    | "WritableStream"
    | "TransformStream"
    | "CanvasRenderingContext2D"
    | "ImageData"
    | "ImageBitmap"
    | "Animation"
    | "StyleSheet"
    | "MediaQueryList"
    | "MutationRecord"
    | "NamedNodeMap"
    | "HTMLCollection"
    | "HTMLCollectionOf"
    | "NodeListOf"
    | "GlobalEventHandlers"
    | "WindowOrWorkerGlobalScope"
    // scripthost lib
    | "ActiveXObject"
    | "VarDate" => true
    _ => false
  }
}
