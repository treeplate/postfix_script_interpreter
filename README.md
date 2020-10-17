# PostFix Script
A language whose main feature is postfix functions.

# Introduction

PostFixScript is a dynamically typed language with structured record types.

Source files come in pairs. The first is a ".inc" file that lists the files to import before compiling the second file, which is a ".pfs" file. Paths in the ".inc" files are relative to the current working directory.

There is one global scope shared by all files.

## Language reference

A PFS file is a statement block.

### Comments

Comments start with two slashes (`//`) not in a string literal, and end at next line feed.

Comments are treated like whitespace.

### Scopes

Identifiers (e.g for variables and functions) share a single namespace.

Blocks, functions, and instances each introduce a new scope. Scopes are lexically nested.

### Types

Values can be null, true, false, doubles, strings, functions, or instances of classes.

### Statements

#### Statement blocks (<block>)

A statement block is a list of statements. There are several kinds of statements, each listed in this section.

Some statements can be followed by a comma to indicate the end of the statement. These commas are always optional, though they may be necessary to separate two statements that would otherwise be interpreted as a single longer statement.

#### Print

```
print <expr>;
```

Prints the result of evaluating <expr> to the console.

#### If

```
if <expr> { <block> }
if <expr> { <block> } else { <block> }
```

Evaluates the expression. If the result is true, runs the first block, otherwise runs the second (if present). It is an error for the expression to not return true or false.

#### Assignment

```
var <identifier> = <expr>;
```

Assigns the result of evaluating the given expression to the variable with the given identifier.

If there is variable with the given identifier in scope, that is the variable referenced by the assignment statement. Otherwise, a new variable is introduced in the nearest enclosing scope.

This has some surprising side-effects; for example, consider the following two examples:

```
var foo = 0
fun test() {
  var foo = 1
}
test()
print foo // prints 1.0
```

```
fun test() {
  var foo = 1
}
var foo = 0
test()
print foo // prints 0.0
```

#### Return

```
return <expr>;
```

Causes the nearest enclosing function execution to be interrupted, returning the value of the given expression.

It is an error to call a return statement outside a function.

#### Function declarations

```
fun <identifier>(<parameters>) { <block> }
```

Introduces a new variable to the nearest enclosing scope whose name is the given identifier and whose value is a function. Parameters are a comma separated-list of identifiers.

There is a function called `type` that tells you the type of its argument:

* `"boolean"`
* `"number"`
* `"string"`
* `"function"`
* `"class"`
* `<instance type>`

See the section on function invocations below for details on how parameters are bound.


#### Classes

```
class <identifier> {
  <variable assignments>
  <function declarations>
}
```

Introduces a new variable to the nearest enclosing scope whose name is the given identifier and whose value is a function with no parameters that returns a new instance of the class.

When a new instance is created, the variable assignments and function declarations of the class are evaluated in the context of a new scope (the instance scope), and then, if there is a variable called `init` in scope of the instance, it is called as a function with no arguments (see below).

##### Operator Overloads

There are many operator overloads, described here:
* `plus`: Takes one argument; corresponds to `+`.
* `minus`: Takes one argument; corresponds to `-`.
* `negate`: Takes no arguments; corresponds to unary `-`.
* `times`: Takes one argument; corresponds to `*`.
* `div`: Takes one argument; corresponds to `/`.
* `equals`: Takes one argument; corresponds to `=`.
* `toStr`: Takes no argument; must return string; corresponds to `$`.

#### Expression statements

```
<expr>,
```

Evaluates the expression and discards the result.


### Expressions

There are various forms of expressions. They are processed in the order listed in this section.

* `<expr> or <expr>`: Left hand side must evaluate to a boolean value. If it is true, returns true, otherwise, returns the right hand side, which must evaluate to a boolean value.
* `<expr> != <expr>`: Evaluates both expressions, returns true if they are not equal, otherwise returns false.
* `<expr> = <expr>`: Evaluates both expressions, returns true if they are equal, otherwise returns false.
* `<expr> < <expr>`: Evaluates both expressions, which must both be numbers. Returns true if the left hand side is smaller than the right hand side, otherwise returns false.
* `<expr> + <expr>`: Evaluates both expressions, which must both be numbers or both be strings. Returns the sum if they are both numbers or the concatenation if they are both strings.
* `<expr> - <expr>`: Evaluates both expressions, which must both be numbers. Returns the result of substracting the right hand side from the left hand side.
* `<expr> * <expr>`: Evaluates both expressions, which must both be numbers. Returns their product.
* `<expr> / <expr>`: Evaluates both expressions, which must both be numbers. Returns the result of dividing the left hand side by the right hand side.
* Postfix function invocation (see below).
* C-style function invocation (see below).
* `$<expr>`: Evaluates the expression and returns its string value.
* `-<expr>`: Evaluates the expression and returns its negation.
* `(<expr>)`: Evaluates and returns the nested expression.
* `<expr> . <expr>`: The first expression must be an instance of a class. Evaluates the second one with the scope of the first.
* `<identifier>`: Returns the value of the variable with that name in the nearest enclosing scope that has a variable of that name.
* Literals (see below).

#### Function invocations

##### Prefix syntax

```
<expr> <identifier>
```

If a function has a single argument, it can be called by postfix notation, giving the argument as an expression before the identifier. If the identifier specifies a variable in scope, then it is called with the value of the given expression as the first argument.

##### C-style syntax

Functions can also be called by specifying the identifier that specifies a variable in scope whose value is a function followed by a comma-separated list of expressions inside parentheses. Each expression is evaluated in left-to-right order, and the values of those expressions is passed to the function as the function's arguments.

##### Function invocation semantics

When a function is called, a new scope is created. The given arguments are mapped to the function's declared parameters. The number of arguments differing is an error.

#### Literals

* `1`, `1.0`: (positive) (numbers with fractional component)
* "string": a string
* `true`, `false`: booleans
* `nil`: null
* `newline`: newline
