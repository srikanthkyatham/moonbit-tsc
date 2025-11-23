// Simple TypeScript example for testing the compiler

// Variable declarations
const message: string = "Hello, MoonBit-Zig Compiler!";
let count: number = 42;
var flag: boolean = true;

// Function declaration
function greet(name: string): string {
  return `Hello, ${name}!`;
}

// Arrow function
const add = (a: number, b: number): number => a + b;

// Class declaration
class Person {
  private name: string;
  private age: number;

  constructor(name: string, age: number) {
    this.name = name;
    this.age = age;
  }

  public greet(): string {
    return `Hello, I'm ${this.name}`;
  }
}

// Interface
interface Point {
  x: number;
  y: number;
}

// Type alias
type Callback = (value: string) => void;

// Enum
enum Color {
  Red,
  Green,
  Blue
}

// Control flow
if (flag) {
  console.log(message);
} else {
  console.log("Flag is false");
}

// Loops
for (let i = 0; i < count; i++) {
  console.log(i);
}

// Array and objects
const numbers: number[] = [1, 2, 3, 4, 5];
const point: Point = { x: 10, y: 20 };

// Async function
async function fetchData(url: string): Promise<string> {
  const response = await fetch(url);
  return response.text();
}

// Export
export { greet, Person, Point };
