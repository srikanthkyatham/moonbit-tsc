// Direction - Bidirectional Type Checking Mode
// Used by the v2 type checker to distinguish between type inference and type checking

///|
/// Direction for bidirectional type checking
///
/// - `Infer`: Bottom-up inference - figure out what type an expression has
/// - `Check(TypeV2)`: Top-down checking - verify expression matches expected type
pub enum Direction {
  Infer // Bottom-up: infer the type of an expression
  Check(TypeV2) // Top-down: check against an expected type
} derive(Debug, Eq)

///|
/// Check if direction is inference mode
pub fn Direction::is_infer(self : Direction) -> Bool {
  match self {
    Infer => true
    Check(_) => false
  }
}

///|
/// Check if direction is check mode
pub fn Direction::is_check(self : Direction) -> Bool {
  match self {
    Infer => false
    Check(_) => true
  }
}

///|
/// Get the expected type if in check mode
pub fn Direction::expected_type(self : Direction) -> TypeV2? {
  match self {
    Infer => None
    Check(ty) => Some(ty)
  }
}

///|
/// Create a check direction from an optional type
/// Returns Infer if type is None, Check(ty) if Some(ty)
pub fn Direction::from_optional(ty : TypeV2?) -> Direction {
  match ty {
    None => Infer
    Some(t) => Check(t)
  }
}

///|
/// Convert direction to check mode with given type
/// Used when we need to push expected type down
pub fn Direction::with_type(expected : TypeV2) -> Direction {
  Check(expected)
}

///|
/// Map over the expected type in Check mode
pub fn Direction::map(self : Direction, f : (TypeV2) -> TypeV2) -> Direction {
  match self {
    Infer => Infer
    Check(ty) => Check(f(ty))
  }
}
