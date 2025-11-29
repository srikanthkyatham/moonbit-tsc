// Index Signature Checking - TypeScript index signature compatibility
// Implements:
// 1. Index signature compatibility checking
// 2. noUncheckedIndexedAccess enforcement
// 3. Numeric vs string index signature covariance
// 4. Symbol index signatures

// ============================================================================
// Index Signature Key Types
// ============================================================================

///|
/// Index signature key types in TypeScript
/// TypeScript supports three key types: string, number, and symbol
pub enum IndexKeyType {
  StringKey // [key: string]: T
  NumberKey // [key: number]: T
  SymbolKey // [key: symbol]: T
} derive(Show, Eq)

///|
/// Get the index key type from a TypeV2 type
pub fn get_index_key_type(ty : TypeV2) -> IndexKeyType? {
  match ty {
    TString | TLiteralString(_) => Some(StringKey)
    TNumber | TLiteralNumber(_) => Some(NumberKey)
    TSymbol => Some(SymbolKey)
    _ => None
  }
}

///|
/// Check if a type is a valid index key type
pub fn is_valid_index_key_type(ty : TypeV2) -> Bool {
  match ty {
    TString | TNumber | TSymbol => true
    TLiteralString(_) | TLiteralNumber(_) => true
    TUnion(types) => types.iter().all(is_valid_index_key_type)
    _ => false
  }
}

// ============================================================================
// Index Signature Compatibility
// ============================================================================

///|
/// Index signature error details
pub struct IndexKeyTypeMismatchInfo {
  expected_key : String
  actual_key : String
} derive(Show)

///|
/// Index value type mismatch info
pub struct IndexValueTypeMismatchInfo {
  expected_value : String
  actual_value : String
} derive(Show)

///|
/// Numeric string covariance error info
pub struct NumericStringCovarianceInfo {
  numeric_type : String
  string_type : String
} derive(Show)

///|
/// Errors that can occur during index signature checking
pub enum IndexSignatureError {
  IndexKeyTypeMismatch(IndexKeyTypeMismatchInfo)
  IndexValueTypeMismatch(IndexValueTypeMismatchInfo)
  InvalidIndexKeyType(String) // key_type
  ReadonlyIndexMismatch
  MissingIndexSignature(String) // required_key
  NumericIndexNotSubtypeOfString(NumericStringCovarianceInfo)
} derive(Show)

///|
/// Result of index signature compatibility check
pub struct IndexSignatureCheckResult {
  is_compatible : Bool
  errors : Array[IndexSignatureError]
} derive(Show)

///|
/// Check if two index signatures are compatible
/// Source signature must be assignable to target signature
pub fn check_index_signature_compatibility(
  source : IndexSignatureV2,
  target : IndexSignatureV2,
) -> IndexSignatureCheckResult {
  let errors : Array[IndexSignatureError] = []

  // Check key type compatibility
  let source_key_type = get_index_key_type(source.key_type)
  let target_key_type = get_index_key_type(target.key_type)

  match (source_key_type, target_key_type) {
    (Some(sk), Some(tk)) =>
      if sk != tk {
        errors.push(
          IndexKeyTypeMismatch(
            {
              expected_key: format_type_v2(target.key_type),
              actual_key: format_type_v2(source.key_type),
            },
          ),
        )
      }
    (None, _) =>
      errors.push(InvalidIndexKeyType(format_type_v2(source.key_type)))
    (_, None) =>
      errors.push(InvalidIndexKeyType(format_type_v2(target.key_type)))
  }

  // Check value type compatibility (covariant)
  if not(is_index_value_subtype(source.value_type, target.value_type)) {
    errors.push(
      IndexValueTypeMismatch(
        {
          expected_value: format_type_v2(target.value_type),
          actual_value: format_type_v2(source.value_type),
        },
      ),
    )
  }

  // Check readonly compatibility
  // A readonly index signature is more restrictive, so non-readonly cannot be assigned to readonly
  if target.is_readonly && not(source.is_readonly) {
    errors.push(ReadonlyIndexMismatch)
  }

  { is_compatible: errors.is_empty(), errors }
}

///|
/// Check if source value type is subtype of target value type
fn is_index_value_subtype(source : TypeV2, target : TypeV2) -> Bool {
  // Same type
  if source == target {
    return true
  }

  match (source, target) {
    (TAny, _) => true
    (_, TAny) => true
    (_, TUnknown) => true
    (TNever, _) => true
    (TLiteralString(_), TString) => true
    (TLiteralNumber(_), TNumber) => true
    (TLiteralBool(_), TBoolean) => true
    (TLiteralBigInt(_), TBigInt) => true

    // Union handling
    (src, TUnion(target_types)) =>
      target_types.iter().any(fn(t) { is_index_value_subtype(src, t) })
    (TUnion(source_types), tgt) =>
      source_types.iter().all(fn(s) { is_index_value_subtype(s, tgt) })
    _ => false
  }
}

// ============================================================================
// Numeric vs String Index Signature Covariance
// ============================================================================

///|
/// Validate that numeric index signatures are subtypes of string index signatures
/// In JavaScript, numeric keys are converted to strings (e.g., obj[0] === obj["0"])
/// Therefore: { [n: number]: T1, [s: string]: T2 } requires T1 <: T2
pub fn check_numeric_string_covariance(
  numeric_sig : IndexSignatureV2?,
  string_sig : IndexSignatureV2?,
) -> IndexSignatureCheckResult {
  match (numeric_sig, string_sig) {
    (Some(num), Some(str_sig)) => {
      // Numeric index value type must be subtype of string index value type
      if is_index_value_subtype(num.value_type, str_sig.value_type) {
        { is_compatible: true, errors: [] }
      } else {
        {
          is_compatible: false,
          errors: [
            NumericIndexNotSubtypeOfString(
              {
                numeric_type: format_type_v2(num.value_type),
                string_type: format_type_v2(str_sig.value_type),
              },
            ),
          ],
        }
      }
    }
    // If only one or none exist, no covariance check needed
    _ => { is_compatible: true, errors: [] }
  }
}

// ============================================================================
// Extended Object Type with Multiple Index Signatures
// ============================================================================

///|
/// Extended index signatures supporting all three key types
pub struct ExtendedIndexSignatures {
  string_index : IndexSignatureV2?
  number_index : IndexSignatureV2?
  symbol_index : IndexSignatureV2?
} derive(Show, Eq)

///|
/// Create empty extended index signatures
pub fn ExtendedIndexSignatures::empty() -> ExtendedIndexSignatures {
  { string_index: None, number_index: None, symbol_index: None }
}

///|
/// Get the index signature for a given key type
pub fn get_signature_for_key(
  sigs : ExtendedIndexSignatures,
  key : TypeV2,
) -> IndexSignatureV2? {
  match get_index_key_type(key) {
    Some(StringKey) => sigs.string_index
    Some(NumberKey) =>
      // For numeric keys, first try numeric signature, then fall back to string
      match sigs.number_index {
        Some(sig) => Some(sig)
        None => sigs.string_index // Numeric keys coerce to strings
      }
    Some(SymbolKey) => sigs.symbol_index
    None => None
  }
}

///|
/// Check compatibility of extended index signatures
pub fn check_extended_index_compatibility(
  source : ExtendedIndexSignatures,
  target : ExtendedIndexSignatures,
) -> IndexSignatureCheckResult {
  let all_errors : Array[IndexSignatureError] = []

  // Check string index signature
  match (source.string_index, target.string_index) {
    (Some(src), Some(tgt)) => {
      let result = check_index_signature_compatibility(src, tgt)
      all_errors.append(result.errors)
    }
    (None, Some(_)) => all_errors.push(MissingIndexSignature("string"))
    _ => ()
  }

  // Check number index signature
  match (source.number_index, target.number_index) {
    (Some(src), Some(tgt)) => {
      let result = check_index_signature_compatibility(src, tgt)
      all_errors.append(result.errors)
    }
    (None, Some(_)) => all_errors.push(MissingIndexSignature("number"))
    _ => ()
  }

  // Check symbol index signature
  match (source.symbol_index, target.symbol_index) {
    (Some(src), Some(tgt)) => {
      let result = check_index_signature_compatibility(src, tgt)
      all_errors.append(result.errors)
    }
    (None, Some(_)) => all_errors.push(MissingIndexSignature("symbol"))
    _ => ()
  }

  // Check numeric-string covariance for source
  let cov_result = check_numeric_string_covariance(
    source.number_index,
    source.string_index,
  )
  all_errors.append(cov_result.errors)

  { is_compatible: all_errors.is_empty(), errors: all_errors }
}

// ============================================================================
// noUncheckedIndexedAccess Support
// ============================================================================

///|
/// Apply noUncheckedIndexedAccess transformation to element access result
/// When enabled, element access via index signatures returns T | undefined
pub fn apply_unchecked_indexed_access(
  ty : TypeV2,
  no_unchecked : Bool,
  is_known_property : Bool,
) -> TypeV2 {
  // If the flag is disabled or this is a known property, return as-is
  if not(no_unchecked) || is_known_property {
    return ty
  }

  // Add undefined to the type
  match ty {
    TUndefined => TUndefined // Already undefined
    TUnion(types) =>
      if types.iter().any(fn(t) { t == TUndefined }) {
        ty // Already includes undefined
      } else {
        let new_types : Array[TypeV2] = []
        new_types.append(types)
        new_types.push(TUndefined)
        make_union(new_types)
      }
    _ => make_union([ty, TUndefined])
  }
}

///|
/// Check if an access is to a known property (not via index signature)
pub fn is_known_property_access(
  obj_type : ObjectTypeV2,
  key : TypeV2,
) -> Bool {
  match key {
    TLiteralString(name) => obj_type.fields.contains(name)
    TLiteralNumber(n) => {
      // Check if there's a field with this numeric name
      let key_str = if n == n.to_int().to_double() {
        n.to_int().to_string()
      } else {
        n.to_string()
      }
      obj_type.fields.contains(key_str)
    }
    _ => false
  }
}

// ============================================================================
// Index Signature Inference
// ============================================================================

///|
/// Infer the result type of an element access expression
/// Takes into account:
/// - Known properties
/// - Index signatures
/// - noUncheckedIndexedAccess setting
pub fn infer_index_access_type(
  obj_type : TypeV2,
  index_type : TypeV2,
  no_unchecked_indexed_access : Bool,
) -> TypeV2 {
  match obj_type {
    TArray(elem_ty) =>
      apply_unchecked_indexed_access(
        elem_ty,
        no_unchecked_indexed_access,
        false,
      )
    TTuple(elems) =>
      // For tuples, check if index is a literal number
      match index_type {
        TLiteralNumber(n) => {
          let idx = n.to_int()
          if idx >= 0 && idx < elems.length() {
            elems[idx].ty // Known index - no undefined needed
          } else {
            TUndefined // Out of bounds - always undefined
          }
        }
        TNumber =>
          // Unknown numeric index - union of all element types + undefined
          apply_unchecked_indexed_access(
            make_union(elems.map(fn(e) { e.ty })),
            no_unchecked_indexed_access,
            false,
          )
        _ => TAny
      }
    TString =>
      // String indexing returns string (single character)
      TString
    TObject(obj) => {
      // Check for known property first
      let is_known = is_known_property_access(obj, index_type)
      if is_known {
        // Access known property
        match index_type {
          TLiteralString(name) =>
            match obj.fields.get(name) {
              Some(field) => field.ty
              None => TAny
            }
          TLiteralNumber(n) => {
            let key_str = if n == n.to_int().to_double() {
              n.to_int().to_string()
            } else {
              n.to_string()
            }
            match obj.fields.get(key_str) {
              Some(field) => field.ty
              None => TAny
            }
          }
          _ => TAny
        }
      } else {
        // Access via index signature
        match obj.index_signature {
          Some(sig) =>
            apply_unchecked_indexed_access(
              sig.value_type,
              no_unchecked_indexed_access,
              false,
            )
          None => TAny
        }
      }
    }
    TAny | TUnknown => TAny
    _ => TAny
  }
}

// ============================================================================
// Object Subtype Checking with Index Signatures
// ============================================================================

///|
/// Check if source object is subtype of target, including index signature compatibility
pub fn is_object_subtype_with_index(
  source : ObjectTypeV2,
  target : ObjectTypeV2,
) -> Bool {
  // All required properties in target must exist in source with compatible types
  for kv in target.fields {
    let name = kv.0
    let tgt_field = kv.1
    match source.fields.get(name) {
      None =>
        // If property is missing, check if source has compatible index signature
        if not(tgt_field.optional) {
          // Check if source index signature can satisfy the property
          match source.index_signature {
            Some(src_sig) =>
              // Index signature key must be string and value must be compatible
              match get_index_key_type(src_sig.key_type) {
                Some(StringKey) =>
                  if not(is_index_value_subtype(src_sig.value_type, tgt_field.ty)) {
                    return false
                  }
                _ => return false
              }
            None => return false
          }
        }
      Some(src_field) =>
        if not(is_index_value_subtype(src_field.ty, tgt_field.ty)) {
          return false
        }
    }
  }

  // Check index signature compatibility
  match (source.index_signature, target.index_signature) {
    (Some(src_sig), Some(tgt_sig)) => {
      let result = check_index_signature_compatibility(src_sig, tgt_sig)
      if not(result.is_compatible) {
        return false
      }
    }
    (None, Some(_)) =>
      // Target requires index signature but source doesn't have one
      // This is OK only if source has all properties that target might access
      // For simplicity, we allow this (TypeScript does in some cases)
      ()
    _ => ()
  }

  true
}

// ============================================================================
// Error Message Generation
// ============================================================================

///|
/// Generate error message for index signature errors
pub fn format_index_signature_error(error : IndexSignatureError) -> String {
  match error {
    IndexKeyTypeMismatch(info) =>
      "Index key type '" +
      info.actual_key +
      "' is not assignable to type '" +
      info.expected_key +
      "'."
    IndexValueTypeMismatch(info) =>
      "Index value type '" +
      info.actual_value +
      "' is not assignable to type '" +
      info.expected_value +
      "'."
    InvalidIndexKeyType(key_type) =>
      "An index signature parameter type must be 'string', 'number', or 'symbol'. Got '" +
      key_type +
      "'."
    ReadonlyIndexMismatch =>
      "Index signature in type is 'readonly' and cannot be assigned to the mutable index signature in target type."
    MissingIndexSignature(required_key) =>
      "Property '" +
      required_key +
      "' is missing in type which has an index signature for '" +
      required_key +
      "' keys."
    NumericIndexNotSubtypeOfString(info) =>
      "Numeric index type '" +
      info.numeric_type +
      "' is not assignable to string index type '" +
      info.string_type +
      "'. (TS2413)"
  }
}
