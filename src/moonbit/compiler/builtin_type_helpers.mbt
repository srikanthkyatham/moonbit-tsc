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
