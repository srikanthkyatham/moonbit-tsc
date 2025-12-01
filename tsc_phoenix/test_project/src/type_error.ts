// This file should produce type errors

function add(a: number, b: number): number {
  return a + b;
}

// Type error: string assigned to number
const result: number = "not a number";

// Type error: wrong argument type
add("hello", 5);
