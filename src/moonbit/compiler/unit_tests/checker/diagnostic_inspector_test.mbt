// Diagnostic Inspector Tests
// Tests that inspect what diagnostics are produced for complex type mismatches

///|
/// Helper function to parse, bind, and check source code
fn inspect_diagnostics(source : String) -> String {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(typed) =>
              if typed.diagnostics.length() > 0 {
                format_all_diagnostics(typed.diagnostics)
              } else {
                "OK: No errors"
              }
            Err(diagnostics) => format_all_diagnostics(diagnostics)
          }
        Err(diagnostics) => format_all_diagnostics(diagnostics)
      }
    Err(diagnostics) => format_all_diagnostics(diagnostics)
  }
}

///|
fn format_all_diagnostics(diagnostics : Array[@compiler.Diagnostic]) -> String {
  let mut result = "Found \{diagnostics.length()} diagnostic(s):\n"
  for i = 0; i < diagnostics.length(); i = i + 1 {
    let d = diagnostics[i]
    result = result +
      "[\{i + 1}] TS\{d.code}: \{d.message} (line \{d.location.start.line})\n"
  }
  result
}

///|
test "inspect/complex - deeply nested object type mismatch" {
  let source =
    #|interface Address {
    #|  street: string;
    #|  city: string;
    #|  zipCode: number;
    #|}
    #|interface PersonDetails {
    #|  name: string;
    #|  age: number;
    #|  address: Address;
    #|}
    #|interface Company {
    #|  name: string;
    #|  employees: PersonDetails[];
    #|  headquarters: Address;
    #|}
    #|const company: Company = {
    #|  name: "Acme Corp",
    #|  employees: [
    #|    {
    #|      name: "John",
    #|      age: "thirty",
    #|      address: {
    #|        street: "123 Main St",
    #|        city: "NYC",
    #|        zipCode: "10001"
    #|      }
    #|    }
    #|  ],
    #|  headquarters: {
    #|    street: 456,
    #|    city: "LA",
    #|    zipCode: 90001
    #|  }
    #|};
  let result = inspect_diagnostics(source)
  println(result)
  inspect(
    result,
    content=(
      #|Found 3 diagnostic(s):
      #|[1] TS2322: Type 'string' is not assignable to type 'number' at employees[element].age (line 16)
      #|[2] TS2322: Type 'string' is not assignable to type 'number' at employees[element].address.zipCode (line 16)
      #|[3] TS2322: Type 'number' is not assignable to type 'string' at headquarters.street (line 16)
      #|
    ),
  )
}

///|
test "inspect/complex - generic function with complex constraint violation" {
  let source =
    #|interface Comparable<T> {
    #|  compareTo(other: T): number;
    #|}
    #|interface Serializable {
    #|  serialize(): string;
    #|}
    #|function process<T extends Comparable<T> & Serializable, U extends T>(
    #|  primary: T,
    #|  secondary: U
    #|): string {
    #|  return primary.serialize();
    #|}
    #|process(42, "hello");
  let result = inspect_diagnostics(source)
  println(result)
  inspect(result, content="OK: No errors")
}

///|
test "inspect/complex - function signature with multiple param mismatches" {
  let source =
    #|type Config = {
    #|  timeout: number;
    #|  retries: number;
    #|  headers: { [key: string]: string };
    #|};
    #|type RequestCallback = (error: Error | null, data: string) => void;
    #|function makeRequest(
    #|  url: string,
    #|  method: "GET" | "POST" | "PUT" | "DELETE",
    #|  config: Config,
    #|  callback: RequestCallback
    #|): void {
    #|}
    #|makeRequest(
    #|  123,
    #|  "PATCH",
    #|  { timeout: "fast", retries: true, headers: null },
    #|  (err, data) => data.length
    #|);
  let result = inspect_diagnostics(source)
  println(result)
  // Now correctly detects type errors in function arguments
  inspect(
    result,
    content=(
      #|Found 1 diagnostic(s):
      #|[1] TS2769: No overload matches this call. Arguments: (number, string, object, function) (line 14)
      #|
    ),
  )
}

///|
test "inspect/complex - union of object types with discriminant mismatch" {
  let source =
    #|type Circle = { kind: "circle"; radius: number };
    #|type Square = { kind: "square"; side: number };
    #|type Triangle = { kind: "triangle"; base: number; height: number };
    #|type Shape = Circle | Square | Triangle;
    #|
    #|const shape: Shape = {
    #|  kind: "hexagon",
    #|  sides: 6
    #|};
  let result = inspect_diagnostics(source)
  println(result)
  // tsc correctly errors: Type '"hexagon"' is not assignable to type '"square" | "triangle" | "circle"'
  inspect(
    result,
    content=(
      #|Found 1 diagnostic(s):
      #|[1] TS2322: Type 'string' is not assignable to discriminant property 'kind'. Expected one of: 'circle' | 'square' | 'triangle' (line 6)
      #|
    ),
  )
}

///|
test "inspect/complex - intersection type with conflicting properties" {
  let source =
    #|interface Named {
    #|  name: string;
    #|  id: number;
    #|}
    #|interface Dated {
    #|  createdAt: Date;
    #|  updatedAt: Date;
    #|}
    #|type Record = Named & Dated;
    #|
    #|const record: Record = {
    #|  name: 123,
    #|  id: "abc",
    #|  createdAt: "2024-01-01",
    #|  updatedAt: new Date()
    #|};
  let result = inspect_diagnostics(source)
  println(result)
  inspect(result, content="OK: No errors")
}

///|
test "inspect/complex - mapped type with readonly violation" {
  // Mapped types are now fully expanded to concrete object types
  // Readonly enforcement works correctly
  let source =
    #|type MyReadonly<T> = { readonly [K in keyof T]: T[K] };
    #|interface Point { x: number; y: number; }
    #|const frozen: MyReadonly<Point> = { x: 10, y: 20 };
    #|frozen.x = 30;
  let result = inspect_diagnostics(source)
  println(result)
  // Now correctly errors with TS2540 for readonly violation
  inspect(
    result,
    content=(
      #|Found 1 diagnostic(s):
      #|[1] TS2540: Cannot assign to 'x' because it is a readonly property. (line 4)
      #|
    ),
  )
}

///|
test "inspect/complex - conditional type with never result" {
  let source =
    #|type ExtractString<T> = T extends string ? T : never;
    #|type Result = ExtractString<number>;
    #|const value: Result = 42;
  let result = inspect_diagnostics(source)
  println(result)
  inspect(result, content="OK: No errors")
}

///|
test "inspect/complex - nested generic type with invalid structure" {
  let source =
    #|interface Container<T> {
    #|  value: T;
    #|  nested: { inner: T };
    #|}
    #|const box: Container<number> = {
    #|  value: 1,
    #|  nested: {
    #|    inner: "hello"
    #|  }
    #|};
  let result = inspect_diagnostics(source)
  println(result)
  inspect(result, content="OK: No errors")
}

///|
test "inspect/complex - callback function with wrong return type" {
  let source =
    #|function map<T, U>(arr: T[], fn: (item: T) => U): U[] {
    #|  return arr.map(fn);
    #|}
    #|const numbers: number[] = [1, 2, 3];
    #|const result: boolean[] = map(numbers, (n) => n.toString());
  let result = inspect_diagnostics(source)
  println(result)
  inspect(result, content="OK: No errors")
}

///|
test "inspect/complex - template literal type mismatch" {
  let source =
    #|type EventName = `on${Capitalize<string>}`;
    #|type HTTPMethod = "GET" | "POST" | "PUT" | "DELETE";
    #|type Endpoint = `/${string}/${HTTPMethod}`;
    #|
    #|const event: EventName = "onClick";
    #|const badEvent: EventName = "click";
    #|const endpoint: Endpoint = "/users/INVALID";
  let result = inspect_diagnostics(source)
  println(result)
  inspect(result, content="OK: No errors")
}

///|
test "inspect/complex - index signature constraint violation" {
  let source =
    #|interface StringDict {
    #|  [key: string]: string;
    #|}
    #|const dict: StringDict = {
    #|  a: "hello",
    #|  b: 123,
    #|  c: true
    #|};
  let result = inspect_diagnostics(source)
  println(result)
  inspect(
    result,
    content=(
      #|Found 2 diagnostic(s):
      #|[1] TS2322: Property 'b' of type 'number' is not assignable to index signature type 'string' (line 4)
      #|[2] TS2322: Property 'c' of type 'boolean' is not assignable to index signature type 'string' (line 4)
      #|
    ),
  )
}

///|
test "inspect/complex - rest parameter type mismatch" {
  let source =
    #|function sum(...numbers: number[]): number {
    #|  return numbers.reduce((a, b) => a + b, 0);
    #|}
    #|sum(1, 2, "three", 4, true);
  let result = inspect_diagnostics(source)
  println(result)
  // Now correctly detects type errors in rest parameters
  inspect(
    result,
    content=(
      #|Found 1 diagnostic(s):
      #|[1] TS2769: No overload matches this call. Arguments: (number, number, string, number, boolean) (line 4)
      #|
    ),
  )
}

///|
test "inspect/complex - overloaded function with no matching signature" {
  let source =
    #|function process(x: string): string;
    #|function process(x: number): number;
    #|function process(x: string | number): string | number {
    #|  return x;
    #|}
    #|process(true);
  let result = inspect_diagnostics(source)
  println(result)
  // Now correctly detects no matching overload (aligned with tsc - only 1 error)
  inspect(
    result,
    content=(
      #|Found 1 diagnostic(s):
      #|[1] TS2769: No overload matches this call. Arguments: (boolean) (line 6)
      #|
    ),
  )
}

///|
test "inspect/complex - class implementing interface with wrong method signature" {
  let source =
    #|interface Calculator {
    #|  add(a: number, b: number): number;
    #|  subtract(a: number, b: number): number;
    #|}
    #|class BadCalculator implements Calculator {
    #|  add(a: string, b: string): string {
    #|    return a + b;
    #|  }
    #|  subtract(a: number, b: number): string {
    #|    return String(a - b);
    #|  }
    #|}
  let result = inspect_diagnostics(source)
  println(result)
  inspect(result, content="OK: No errors")
}

///|
test "inspect/complex - Promise chain type propagation error" {
  let source =
    #|function fetchUser(): Promise<{ name: string; id: number }> {
    #|  return Promise.resolve({ name: "John", id: 1 });
    #|}
    #|const result: Promise<boolean> = fetchUser()
    #|  .then(user => user.name)
    #|  .then(name => name.length);
  let result = inspect_diagnostics(source)
  println(result)
  inspect(result, content="OK: No errors")
}

///|
test "inspect/basic - simple string to number" {
  let source = "const x: number = \"hello\";"
  let result = inspect_diagnostics(source)
  println(result)
  inspect(
    result,
    content=(
      #|Found 1 diagnostic(s):
      #|[1] TS2322: Type 'string' is not assignable to type 'number' (line 1)
      #|
    ),
  )
}

///|
test "inspect/basic - boolean to number" {
  let source = "const x: number = true;"
  let result = inspect_diagnostics(source)
  println(result)
  inspect(
    result,
    content=(
      #|Found 1 diagnostic(s):
      #|[1] TS2322: Type 'boolean' is not assignable to type 'number' (line 1)
      #|
    ),
  )
}

///|
test "inspect/basic - union type mismatch" {
  let source = "const x: string | number = true;"
  let result = inspect_diagnostics(source)
  println(result)
  inspect(
    result,
    content=(
      #|Found 1 diagnostic(s):
      #|[1] TS2322: Type 'boolean' is not assignable to type 'string | number' (line 1)
      #|
    ),
  )
}

///|
test "inspect/debug - class instantiation" {
  let source = "class Foo { method(): void {} } const x = new Foo();"
  let result = inspect_diagnostics(source)
  println(result)
  inspect(result, content="OK: No errors")
}
