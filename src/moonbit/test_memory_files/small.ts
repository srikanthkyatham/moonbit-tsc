// Small TypeScript file (~100 lines, ~2KB)
// Basic functions and variables

const greeting = "Hello, World!";
let count = 0;
var isActive = true;

function add(a: number, b: number): number {
  return a + b;
}

function subtract(a: number, b: number): number {
  return a - b;
}

function multiply(a: number, b: number): number {
  return a * b;
}

function divide(a: number, b: number): number {
  if (b === 0) {
    throw "Division by zero";
  }
  return a / b;
}

const square = (x: number): number => x * x;
const cube = (x: number): number => x * x * x;

interface Point {
  x: number;
  y: number;
}

interface Circle {
  center: Point;
  radius: number;
}

function distance(p1: Point, p2: Point): number {
  const dx = p2.x - p1.x;
  const dy = p2.y - p1.y;
  return Math.sqrt(dx * dx + dy * dy);
}

function circleArea(circle: Circle): number {
  return Math.PI * circle.radius * circle.radius;
}

class Person {
  name: string;
  age: string;

  constructor(name: string, age: number) {
    this.name = name;
    this.age = age;
  }

  greet(): string {
    return "Hello, I'm " + this.name;
  }

  birthday(): void {
    this.age = this.age + 1;
  }
}

enum Color {
  Red,
  Green,
  Blue,
}

type Status = "active" | "inactive" | "pending";

function processStatus(status: Status): string {
  switch (status) {
    case "active":
      return "Processing active";
    case "inactive":
      return "Processing inactive";
    case "pending":
      return "Processing pending";
    default:
      return "Unknown status";
  }
}

function factorial(n: number): number {
  if (n <= 1) {
    return 1;
  }
  return n * factorial(n - 1);
}

function fibonacci(n: number): number {
  if (n <= 1) {
    return n;
  }
  return fibonacci(n - 1) + fibonacci(n - 2);
}

const numbers = [1, 2, 3, 4, 5];
const doubled = numbers.map((x) => x * 2);
const sum = numbers.reduce((acc, x) => acc + x, 0);
