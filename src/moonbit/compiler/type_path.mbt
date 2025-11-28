// TypePath - Error Location Path Tracking
// Tracks the path through nested types to pinpoint exactly where type mismatches occur

///|
/// Path tracking for error location in nested types
/// Used to provide detailed error messages showing exactly where a type mismatch occurred
pub enum TypePath {
  PRoot // Root of the type comparison
  PProperty(TypePath, String) // obj.foo - accessing a property
  PIndex(TypePath, Int) // tuple[0], params[1] - tuple or array index
  PArrayElement(TypePath) // T[] - array element type
  PReturnType(TypePath) // () => T - function return type
  PParameter(TypePath, Int, String) // (x: T) - function parameter (index and name)
  PTypeArg(TypePath, String, Int) // Generic<T> - type argument (name and position)
  PUnionMember(TypePath, Int) // T | U - which union member
  PIntersectionMember(TypePath, Int) // T & U - which intersection member
  PConstraint(TypePath, String) // T extends Constraint - constraint on type parameter
  PCallSignature(TypePath, Int) // Callable object signature
  PConstructSignature(TypePath, Int) // Constructor signature
  PIndexSignature(TypePath) // Index signature [key: T]: U
  PRestParam(TypePath) // Rest parameter ...args
  PTupleElement(TypePath, Int, String?) // Tuple element with optional label
} derive(Show, Eq)

///|
/// Create a root TypePath (factory function for external use)
pub fn TypePath::root() -> TypePath {
  PRoot
}

///|
/// Convert TypePath to human-readable string for error messages
pub fn TypePath::to_string(self : TypePath) -> String {
  match self {
    PRoot => ""
    PProperty(parent, name) => {
      let p = parent.to_string()
      if p.is_empty() {
        name
      } else {
        p + "." + name
      }
    }
    PIndex(parent, i) => parent.to_string() + "[" + i.to_string() + "]"
    PArrayElement(parent) => {
      let p = parent.to_string()
      if p.is_empty() {
        "[]"
      } else {
        p + "[]"
      }
    }
    PReturnType(parent) => {
      let p = parent.to_string()
      if p.is_empty() {
        "(return type)"
      } else {
        p + " (return type)"
      }
    }
    PParameter(parent, i, name) => {
      let p = parent.to_string()
      let suffix = " (parameter '" +
        name +
        "' at position " +
        i.to_string() +
        ")"
      if p.is_empty() {
        suffix
      } else {
        p + suffix
      }
    }
    PTypeArg(parent, name, i) => {
      let p = parent.to_string()
      let suffix = " (type argument '" +
        name +
        "' at position " +
        i.to_string() +
        ")"
      if p.is_empty() {
        suffix
      } else {
        p + suffix
      }
    }
    PUnionMember(parent, i) => {
      let p = parent.to_string()
      let suffix = " (union member " + i.to_string() + ")"
      if p.is_empty() {
        suffix
      } else {
        p + suffix
      }
    }
    PIntersectionMember(parent, i) => {
      let p = parent.to_string()
      let suffix = " (intersection member " + i.to_string() + ")"
      if p.is_empty() {
        suffix
      } else {
        p + suffix
      }
    }
    PConstraint(parent, name) => {
      let p = parent.to_string()
      let suffix = " (constraint on '" + name + "')"
      if p.is_empty() {
        suffix
      } else {
        p + suffix
      }
    }
    PCallSignature(parent, i) => {
      let p = parent.to_string()
      let suffix = " (call signature " + i.to_string() + ")"
      if p.is_empty() {
        suffix
      } else {
        p + suffix
      }
    }
    PConstructSignature(parent, i) => {
      let p = parent.to_string()
      let suffix = " (construct signature " + i.to_string() + ")"
      if p.is_empty() {
        suffix
      } else {
        p + suffix
      }
    }
    PIndexSignature(parent) => {
      let p = parent.to_string()
      if p.is_empty() {
        "(index signature)"
      } else {
        p + " (index signature)"
      }
    }
    PRestParam(parent) => {
      let p = parent.to_string()
      if p.is_empty() {
        "(rest parameter)"
      } else {
        p + " (rest parameter)"
      }
    }
    PTupleElement(parent, i, label) => {
      let p = parent.to_string()
      let elem_desc = match label {
        Some(l) => "'" + l + "' at position " + i.to_string()
        None => "position " + i.to_string()
      }
      let suffix = " (tuple element " + elem_desc + ")"
      if p.is_empty() {
        suffix
      } else {
        p + suffix
      }
    }
  }
}

///|
/// Check if path is at root
pub fn TypePath::is_root(self : TypePath) -> Bool {
  match self {
    PRoot => true
    _ => false
  }
}

///|
/// Get the parent path
pub fn TypePath::parent(self : TypePath) -> TypePath? {
  match self {
    PRoot => None
    PProperty(p, _)
    | PIndex(p, _)
    | PArrayElement(p)
    | PReturnType(p)
    | PParameter(p, _, _)
    | PTypeArg(p, _, _)
    | PUnionMember(p, _)
    | PIntersectionMember(p, _)
    | PConstraint(p, _)
    | PCallSignature(p, _)
    | PConstructSignature(p, _)
    | PIndexSignature(p)
    | PRestParam(p)
    | PTupleElement(p, _, _) => Some(p)
  }
}

///|
/// Get the depth of the path (number of steps from root)
pub fn TypePath::depth(self : TypePath) -> Int {
  match self {
    PRoot => 0
    PProperty(p, _)
    | PIndex(p, _)
    | PArrayElement(p)
    | PReturnType(p)
    | PParameter(p, _, _)
    | PTypeArg(p, _, _)
    | PUnionMember(p, _)
    | PIntersectionMember(p, _)
    | PConstraint(p, _)
    | PCallSignature(p, _)
    | PConstructSignature(p, _)
    | PIndexSignature(p)
    | PRestParam(p)
    | PTupleElement(p, _, _) => p.depth() + 1
  }
}

// ============================================================================
// Path Construction Helpers
// ============================================================================

///|
/// Create a property access path
pub fn TypePath::property(self : TypePath, name : String) -> TypePath {
  PProperty(self, name)
}

///|
/// Create an index access path
pub fn TypePath::index(self : TypePath, i : Int) -> TypePath {
  PIndex(self, i)
}

///|
/// Create an array element path
pub fn TypePath::array_element(self : TypePath) -> TypePath {
  PArrayElement(self)
}

///|
/// Create a return type path
pub fn TypePath::return_type(self : TypePath) -> TypePath {
  PReturnType(self)
}

///|
/// Create a parameter path
pub fn TypePath::parameter(
  self : TypePath,
  index : Int,
  name : String,
) -> TypePath {
  PParameter(self, index, name)
}

///|
/// Create a type argument path
pub fn TypePath::type_arg(
  self : TypePath,
  name : String,
  index : Int,
) -> TypePath {
  PTypeArg(self, name, index)
}

///|
/// Create a union member path
pub fn TypePath::union_member(self : TypePath, index : Int) -> TypePath {
  PUnionMember(self, index)
}

///|
/// Create an intersection member path
pub fn TypePath::intersection_member(self : TypePath, index : Int) -> TypePath {
  PIntersectionMember(self, index)
}

///|
/// Create a constraint path
pub fn TypePath::constraint(self : TypePath, param_name : String) -> TypePath {
  PConstraint(self, param_name)
}

///|
/// Create a tuple element path
pub fn TypePath::tuple_element(
  self : TypePath,
  index : Int,
  label : String?,
) -> TypePath {
  PTupleElement(self, index, label)
}
