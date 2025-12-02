// Test TypeScript file for Phoenix dashboard integration

function greet(name: string): string {
  return `Hello, ${name}!`;
}

// This should trigger a type error
const result: number = greet("World");

// This is correct
const message: string = greet("Phoenix");

console.log(message);
