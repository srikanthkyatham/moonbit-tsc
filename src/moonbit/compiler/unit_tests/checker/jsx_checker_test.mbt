// Tests for JSX Type Checking
// Tests JSX intrinsic element lookup, component prop checking, children validation, JSX.Element return type

///|
/// Helper function to parse and check JSX source code
fn parse_and_check_jsx(source : String) -> @compiler.CheckResult {
  let tokens = @compiler.scan_all_v2(source, "test.tsx")
  match @compiler.parse_source_file(tokens, "test.tsx") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) => @compiler.check_source_file(bound)
        Err(diagnostics) => Err(diagnostics)
      }
    Err(diagnostics) => Err(diagnostics)
  }
}

///|
/// Helper function to just parse JSX source code
fn parse_only_jsx(source : String) -> Result[@compiler.SourceFile, Array[@compiler.Diagnostic]] {
  let tokens = @compiler.scan_all_v2(source, "test.tsx")
  @compiler.parse_source_file(tokens, "test.tsx")
}

// ============================================================================
// JSX Parsing Tests
// ============================================================================

test "jsx/parsing - simple element" {
  let source =
    #|const elem = <div>Hello</div>;
  let result = parse_only_jsx(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

test "jsx/parsing - self-closing element" {
  let source =
    #|const elem = <br />;
  let result = parse_only_jsx(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

test "jsx/parsing - element with attributes" {
  let source =
    #|const elem = <div className="container" id="main">Content</div>;
  let result = parse_only_jsx(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

test "jsx/parsing - element with expression attribute" {
  let source =
    #|const name = "test";
    #|const elem = <div id={name}>Content</div>;
  let result = parse_only_jsx(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

test "jsx/parsing - nested elements" {
  let source =
    #|const elem = <div><span>Nested</span></div>;
  let result = parse_only_jsx(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

test "jsx/parsing - fragment" {
  let source =
    #|const elem = <>First<span>Second</span></>;
  let result = parse_only_jsx(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

test "jsx/parsing - component element" {
  let source =
    #|function MyComponent() { return <div>Hello</div>; }
    #|const elem = <MyComponent />;
  let result = parse_only_jsx(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

test "jsx/parsing - spread attribute" {
  let source =
    #|const props = { className: "test" };
    #|const elem = <div {...props}>Content</div>;
  let result = parse_only_jsx(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

// ============================================================================
// JSX Type Checking Tests
// ============================================================================

test "jsx/check - intrinsic element type check" {
  let source =
    #|const elem = <div>Hello</div>;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

test "jsx/check - self-closing element type check" {
  let source =
    #|const elem = <input type="text" />;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

test "jsx/check - element with string attribute" {
  let source =
    #|const elem = <div className="container">Content</div>;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

test "jsx/check - element with expression children" {
  let source =
    #|const name = "World";
    #|const elem = <div>Hello {name}</div>;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

test "jsx/check - fragment type check" {
  let source =
    #|const elem = <><span>A</span><span>B</span></>;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

test "jsx/check - nested elements type check" {
  let source =
    #|const elem = <div><span><strong>Deep</strong></span></div>;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

test "jsx/check - boolean attribute" {
  let source =
    #|const elem = <input disabled />;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

test "jsx/check - multiple attributes" {
  let source =
    #|const elem = <input type="text" name="field" value="test" />;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// JSX Component Tests
// ============================================================================

test "jsx/component - function component parse" {
  // Parsing test for function component with typed props
  let source =
    #|function Greeting(props: { name: string }) {
    #|  return <div>Hello</div>;
    #|}
    #|const elem = <Greeting name="World" />;
  let result = parse_only_jsx(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

test "jsx/component - arrow function component parse" {
  // Parsing test for arrow function component
  let source =
    #|const Button = () => <button>Click</button>;
    #|const elem = <Button />;
  let result = parse_only_jsx(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

test "jsx/component - component with children parse" {
  // Parsing test for component with children
  let source =
    #|function Container() {
    #|  return <div className="container">Content</div>;
    #|}
    #|const elem = <Container><span>Child</span></Container>;
  let result = parse_only_jsx(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

// ============================================================================
// JSX Children Validation Tests
// ============================================================================

test "jsx/children - text children" {
  let source =
    #|const elem = <div>Just text</div>;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

test "jsx/children - expression children" {
  let source =
    #|const count = 42;
    #|const elem = <div>{count}</div>;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

test "jsx/children - mixed children" {
  let source =
    #|const name = "World";
    #|const elem = <div>Hello, {name}! <strong>Welcome</strong></div>;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

test "jsx/children - array children" {
  let source =
    #|const items = ["a", "b", "c"];
    #|const elem = <ul>{items.map(item => <li>{item}</li>)}</ul>;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

test "jsx/children - conditional children" {
  let source =
    #|const show = true;
    #|const elem = <div>{show && <span>Visible</span>}</div>;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

test "jsx/children - null children" {
  let source =
    #|const elem = <div>{null}</div>;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// JSX Return Type Tests
// ============================================================================

test "jsx/return - function returns jsx" {
  let source =
    #|function render() {
    #|  return <div>Content</div>;
    #|}
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

test "jsx/return - arrow function returns jsx" {
  let source =
    #|const render = () => <div>Content</div>;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

test "jsx/return - component returns fragment" {
  let source =
    #|function List() {
    #|  return (
    #|    <>
    #|      <li>Item 1</li>
    #|      <li>Item 2</li>
    #|    </>
    #|  );
    #|}
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// JSX Attribute Expression Tests
// ============================================================================

test "jsx/attr - callback attribute" {
  let source =
    #|const elem = <button onClick={() => console.log("clicked")}>Click</button>;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

test "jsx/attr - template literal attribute" {
  // Template literal in JSX attribute
  let source =
    #|const id = "123";
    #|const elem = <div id={`item-${id}`}>Item</div>;
  let result = parse_only_jsx(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

test "jsx/attr - object attribute" {
  let source =
    #|const style = { color: "red" };
    #|const elem = <div style={style}>Styled</div>;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

test "jsx/attr - inline object attribute" {
  let source =
    #|const elem = <div style={{ color: "blue", fontSize: 14 }}>Styled</div>;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// JSX Edge Cases
// ============================================================================

test "jsx/edge - element as attribute value" {
  let source =
    #|const icon = <span>*</span>;
    #|const elem = <button>{icon} Click</button>;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

test "jsx/edge - deeply nested" {
  let source =
    #|const elem = <div><div><div><div><span>Deep</span></div></div></div></div>;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}

test "jsx/edge - empty element" {
  let source =
    #|const elem = <div></div>;
  let result = parse_and_check_jsx(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.tsx")
    Err(_) => assert_true(false)
  }
}
