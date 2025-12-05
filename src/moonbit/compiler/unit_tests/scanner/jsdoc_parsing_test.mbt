// JSDoc Parsing Tests
// Tests for JSDoc comment parsing support

///|
test "parse jsdoc - simple description" {
  let content = "This is a simple description"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.description, "This is a simple description")
  assert_eq(result.tags.length(), 0)
}

///|
test "parse jsdoc - param tag with type" {
  let content = "@param {string} name The user name"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Param(param) => {
      assert_eq(param.name, "name")
      assert_eq(param.type_annotation, Some("string"))
      assert_true(param.description.contains("user name"))
      assert_eq(param.is_optional, false)
    }
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - optional param" {
  let content = "@param {string} [name] Optional name"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Param(param) => assert_eq(param.is_optional, true)
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - returns tag" {
  let content = "@returns {number} The computed value"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Returns(ret) => {
      assert_eq(ret.type_annotation, Some("number"))
      assert_true(ret.description.contains("computed value"))
    }
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - return tag alias" {
  let content = "@return {boolean} True if valid"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Returns(_) => ()
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - type tag" {
  let content = "@type {Array<string>}"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Type(typ) => assert_eq(typ.type_annotation, "Array<string>")
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - typedef tag" {
  let content = "@typedef {Object} Person A person object"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.TypeDef(td) => {
      assert_eq(td.type_annotation, "Object")
      assert_eq(td.name, "Person")
    }
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - template tag single" {
  let content = "@template T"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Template(template) => {
      assert_eq(template.type_params.length(), 1)
      assert_eq(template.type_params[0], "T")
    }
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - template tag multiple" {
  let content = "@template T, U, V"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Template(template) => {
      assert_eq(template.type_params.length(), 3)
      assert_eq(template.type_params[0], "T")
      assert_eq(template.type_params[1], "U")
      assert_eq(template.type_params[2], "V")
    }
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - deprecated tag" {
  let content = "@deprecated Use newFunction instead"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Deprecated(dep) =>
      assert_true(dep.description.contains("newFunction"))
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - deprecated without reason" {
  let content = "@deprecated"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Deprecated(dep) => assert_eq(dep.description, "")
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - example tag single line" {
  let content = "@example const x = foo();"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Example(ex) => assert_true(ex.content.contains("foo()"))
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - example tag multi-line" {
  let content = "@example\nconst x = foo();\nconsole.log(x);"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Example(ex) => {
      assert_true(ex.content.contains("foo()"))
      assert_true(ex.content.contains("console.log"))
    }
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - see tag" {
  let content = "@see OtherClass"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.See(see) => assert_eq(see.reference, "OtherClass")
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - author tag" {
  let content = "@author John Doe"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Author(author) => assert_eq(author.name, "John Doe")
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - since tag" {
  let content = "@since 1.0.0"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Since(since) => assert_eq(since.version, "1.0.0")
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - throws tag" {
  let content = "@throws {Error} When input is invalid"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Throws(th) => {
      assert_eq(th.type_annotation, Some("Error"))
      assert_true(th.description.contains("invalid"))
    }
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - private tag" {
  let content = "@private"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Private(_) => ()
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - public tag" {
  let content = "@public"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Public(_) => ()
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - protected tag" {
  let content = "@protected"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Protected(_) => ()
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - readonly tag" {
  let content = "@readonly"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Readonly(_) => ()
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - override tag" {
  let content = "@override"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Override(_) => ()
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - abstract tag" {
  let content = "@abstract"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Abstract(_) => ()
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - unknown tag" {
  let content = "@customtag some value"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Unknown(name, value, _) => {
      assert_eq(name, "customtag")
      assert_eq(value, "some value")
    }
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - multiple tags" {
  let content = "Function description\n@param {string} name The name\n@returns {void}"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.description, "Function description")
  assert_eq(result.tags.length(), 2)
  match result.tags[0] {
    @compiler.Param(_) => ()
    _ => assert_true(false)
  }
  match result.tags[1] {
    @compiler.Returns(_) => ()
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - with asterisk prefix" {
  let content = " * Function description\n * @param {string} name"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.description, "Function description")
  assert_eq(result.tags.length(), 1)
}

///|
test "parse jsdoc - complex type annotation" {
  let content = "@type {Map<string, Array<{id: number, name: string}>>}"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Type(typ) =>
      // Should handle nested braces correctly
      assert_true(typ.type_annotation.contains("Map"))
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - arg alias for param" {
  let content = "@arg {number} count"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Param(param) => assert_eq(param.name, "count")
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - argument alias for param" {
  let content = "@argument {number} value"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Param(param) => assert_eq(param.name, "value")
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - exception alias for throws" {
  let content = "@exception {TypeError} When type is wrong"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Throws(_) => ()
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - version alias for since" {
  let content = "@version 2.0.0"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Since(since) => assert_eq(since.version, "2.0.0")
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - virtual tag" {
  let content = "@virtual"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Virtual(_) => ()
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - empty content" {
  let content = ""
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.description, "")
  assert_eq(result.tags.length(), 0)
}

///|
test "parse jsdoc - whitespace only" {
  let content = "   \n   \n   "
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.description, "")
  assert_eq(result.tags.length(), 0)
}

///|
test "parse jsdoc - param without type" {
  let content = "@param name The parameter name"
  let result = @compiler.parse_jsdoc(content)
  assert_eq(result.tags.length(), 1)
  match result.tags[0] {
    @compiler.Param(param) => {
      assert_eq(param.type_annotation, None)
      assert_eq(param.name, "name")
    }
    _ => assert_true(false)
  }
}

///|
test "parse jsdoc - multiline description" {
  let content = "First line of description\nSecond line of description\n@param x"
  let result = @compiler.parse_jsdoc(content)
  assert_true(result.description.contains("First line"))
  assert_true(result.description.contains("Second line"))
  assert_eq(result.tags.length(), 1)
}
