// Utility functions

export function add(a: number, b: number): number {
  return a + b;
}

export function multiply(a: number, b: number): number {
  return a * b;
}

// Type error: wrong return type
export function divide(a: number, b: number): string {
  return a / b;
}
