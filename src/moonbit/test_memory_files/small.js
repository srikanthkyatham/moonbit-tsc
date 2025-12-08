const greeting = "Hello, World!";
let count = 0;
var isActive = true;
function add(a, b) {
  return a + b;
}
function subtract(a, b) {
  return a - b;
}
function multiply(a, b) {
  return a * b;
}
function divide(a, b) {
  if (b === 0)   {
    throw "Division by zero";
  }
  return a / b;
}
const square = (x) => x * x;
const cube = (x) => x * x * x;
function distance(p1, p2) {
  const dx = p2.x - p1.x;
  const dy = p2.y - p1.y;
  return Math.sqrt(dx * dx + dy * dy);
}
function circleArea(circle) {
  return Math.PI * circle.radius * circle.radius;
}
class Person {
  name;
  age;
  constructor(name, age)   {
    this.name = name;
    this.age = age;
  }
  greet()   {
    return "Hello, I'm " + this.name;
  }
  birthday()   {
    this.age = this.age + 1;
  }
}
const Color = { Red: 0, Green: 1, Blue: 2 };
function processStatus(status) {
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
function factorial(n) {
  if (n <= 1)   {
    return 1;
  }
  return n * factorial(n - 1);
}
function fibonacci(n) {
  if (n <= 1)   {
    return n;
  }
  return fibonacci(n - 1) + fibonacci(n - 2);
}
const numbers = [1, 2, 3, 4, 5];
const doubled = numbers.map((x) => x * 2);
const sum = numbers.reduce((acc, x) => acc + x, 0);