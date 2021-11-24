import 'lexer.dart';
import 'dart:io';

void parse(List<Token> tokens) {
  TokenGetter getter = TokenGetter(tokens);
  List<Statement> program = [];
  while (getter.peek().type != TokenType.EOF) {
    program.add(parseLine(getter));
    //print("Ok ${getter.peek().type}");
  }
  //print(Block(program, "dbg").debugPrint());
  print("Running...");
  Block(funs + program, "root")..setup()..run();
}


final List<Statement> funs = [
  FunDecl("type", ["x"], (Scope scope) {
    dynamic x = scope.getVar("x");
    switch(x.runtimeType) {
      case double:
        return "number";
      case String:
        return "string";
      case Instance:
        return scope.getVar("${x.name}");
      case Class:
        return "class";
      case bool: 
        return "boolean";
      case Fun:
        return "function";
      default:
        return "<unknown type>";
    }
  }),
  FunDecl("readfile", ["x"], (Scope scope) {
    return File(scope.getVar("x")).readAsStringSync();
  }),
  FunDecl("init", [], (Scope scope) {}),
  FunDecl("parsenum", ["x"], (Scope scope) {
    dynamic x = scope.getVar("x");
    return double.parse(x);
  }),
  FunDecl("index", ["x", "y"], (Scope scope) {
    dynamic x = scope.getVar("x");
    dynamic y = scope.getVar("y");
    return x[y.round()];
  }),
  FunDecl("length", ["x"], (Scope scope) {
    dynamic x = scope.getVar("x");
    return x.length;
  }),
  FunDecl("ceil", ["x"], (Scope scope) {
    dynamic x = scope.getVar("x");
    return x.ceil();
  })
]; 

class FunDecl extends Statement {
  FunDecl(this.name, this.args, this.evalr);
  final String name;
  final List<String> args;
  final dynamic Function(Scope) evalr;
  void run(Scope scope) {
    scope.addVar("$name", Fun(Block([ReturnStatement(FunRun(evalr))], "the_${name}_fun")..setup(scope), args), "N/A");
  }
}

class FunRun extends Expression {
  FunRun(this.evalr);
  final dynamic Function(Scope) evalr;
  dynamic eval(Scope scope) {
    return evalr(scope);
  }
}

Statement parseLine(TokenGetter tokens) {
  //print("[line ${tokens.peek().line}] ${tokens.peek().lexeme}");
  switch(tokens.peek().type) {
    case TokenType.PRINT:
      tokens.advance();
      //print("PRINT");
      return PrintStatement.parse(tokens);
    case TokenType.IF:
      //print("IF");
      tokens.advance();
      return IfStatement.parse(tokens);
    case TokenType.WHILE:
      //print("IF");
      tokens.advance();
      return WhileStatement.parse(tokens);
    case TokenType.FUN:
      //print("FUN");
      tokens.advance();
      return FunDeclStatement.parse(tokens);
    case TokenType.CLASS:
      //print("CLASS");
      tokens.advance();
      return ClassStatement.parse(tokens);
    case TokenType.VAR:
      //print("VAR");
      tokens.advance();
      return AssignmentStatement.parse(tokens);
    case TokenType.LOCAL:
      //print("VAR");
      tokens.advance();
      return LAssignmentStatement.parse(tokens);
    case TokenType.SCOPE:
      tokens.advance();
      return ScopeStatement.parse(tokens);
    case TokenType.RETURN:
      //print("RETURN");
      tokens.advance();
      var retur = ReturnStatement(parseExpression(tokens));
      if(tokens.peek().type == TokenType.SEMICOLON) tokens.advance();
      return retur;
    default:
      //print("${tokens.peek().type}");
      var retur = ExprStatement(parseExpression(tokens));
      if(tokens.peek().type == TokenType.SEMICOLON) tokens.advance();
      //print("${retur.expr}.." + tokens.peek().type.toString());
      return retur;
  }
}

Statement parseClassLine(TokenGetter tokens) {
  switch(tokens.peek().type) {
    case TokenType.FUN:
      //print("FUN");
      tokens.advance();
      return FunDeclStatement.parse(tokens);
    case TokenType.VAR:
      //print("VAR");
      tokens.advance();
      return AssignmentStatement.parse(tokens);
    case TokenType.LOCAL:
      //print("VAR");
      tokens.advance();
      return LAssignmentStatement.parse(tokens);
    default:
      throw UnimplementedError("[line ${tokens.peek().line}] Unrecognized token ${tokens.peek().type} in class declaration");
  }
}

abstract class Statement{
  const Statement();
  void run(Scope scope);
  String debugPrint() => "XXX";
  Statement copy() => this;
}

class ExprStatement extends Statement {
  ExprStatement(this.expr);
  final Expression expr;
  dynamic run(Scope scope) {
    return expr.eval(scope);
  }
  String debugPrint() => expr.debugPrint();
}

class AssignmentStatement extends Statement {
  AssignmentStatement(this.name, this.value);
  String name;
  Expression value;
  factory AssignmentStatement.parse(TokenGetter tokens) {
    if(tokens.peek().type != TokenType.IDENTIFIER) throw UnimplementedError("No name after VAR");
    var name = tokens.peek().lexeme;
    tokens.advance();
    if(tokens.peek().type != TokenType.EQUAL) {
      if(tokens.peek().type == TokenType.SEMICOLON) tokens.advance();
      return AssignmentStatement(name, NullExpression());
    }
    tokens.advance();
    var value = parseExpression(tokens);
    if(tokens.peek().type == TokenType.SEMICOLON) tokens.advance();
    return AssignmentStatement(name, value);
  }
  void run(Scope scope) {
    var to = value.eval(scope);
    //print("at $scope: var $name = $to");
    scope?.addPar(name, to);
  }
  String debugPrint() => "$name = ${value.debugPrint()}";
}

class LAssignmentStatement extends Statement {
  LAssignmentStatement(this.name, this.value, this.line);
  String name;
  String line;
  Expression value;
  factory LAssignmentStatement.parse(TokenGetter tokens) {
    if(tokens.peek().type != TokenType.IDENTIFIER) throw UnimplementedError("No name after LOCAL");
    var name = tokens.peek().lexeme;
    tokens.advance();
    if(tokens.peek().type != TokenType.EQUAL) {
      if(tokens.peek().type == TokenType.SEMICOLON) tokens.advance();
      return LAssignmentStatement(name, NullExpression(), tokens.peek().line);
    }
    tokens.advance();
    var value = parseExpression(tokens);
    if(tokens.peek().type == TokenType.SEMICOLON) tokens.advance();
    return LAssignmentStatement(name, value, tokens.peek().line);
  }
  void run(Scope scope) {
    var to = value.eval(scope);
    //print("at $scope: var $name = $to");
    scope?.addVar(name, to, line);
  }
  String debugPrint() => "$name = ${value.debugPrint()}";
}

class Block extends Statement {
  final List<Statement> runners;
  static var nid = 0;
  final String name;
  Block(this.runners, this.name) {
    nid++;
    id = nid;
  }
  Scope blockScope;
  Scope parentSetupScope;
  int id;
  dynamic run([Scope scope]) {
    blockScope = Scope(name, parentSetupScope);
    if(blockScope == null) throw UnimplementedError("Not setupped yet");
    for (var i = 0; i < runners.length; i++) {
      //print("block: ${i+1}th ran ${blockScope} (from $scope) thing(${runners[i].runtimeType})");
      //print(" ");
      //print("$name:$blockScope:${blockScope.vars}");
      runners[i].run(blockScope);
      //print("$from's ${i+1}th ran A thing(${runners[i].runtimeType})");
    }
  }
  void setup([Scope scope]) {
    //print("setting up $name at $scope");
    parentSetupScope = scope;
  }
  String debugPrint() {
    String result = "";
    for (dynamic part in runners) {
      //print("$id-  " + part.debugPrint().split("\n").join("\n  ") + "//");
      result += "  " + part.debugPrint().split("\n").join("\n  ");
      result += "\n";
    }
    return result;
  }
  Statement copy() => Block(runners.map((Statement runner) => runner.copy()).toList(), name);
}

class Return {
  const Return(this.value);
  final dynamic value;
  String toString() => "Returned outside function";
}

class ReturnStatement extends Statement{
  ReturnStatement(this.expr);
  final Expression expr;
  void run(Scope scope) {
    throw Return(expr.eval(scope));
  }
  String debugPrint() => "return ${expr.debugPrint()}";
}
 
class Fun {
  Fun(this.block, this.args);
  final Block block;
  final List<String> args;
  String toString() => "Func(${args.join(", ")})";
}

class Class {
  Class(this.block);
  final Block block;
}

class VE extends Expression {
  VE(this.value);
  dynamic value;
  dynamic eval(Scope scope) => value;
}

class Instance {
  static Map<Class, int> classes = {};
  Instance(this.name, Class iClass, Scope parent): id = classes[iClass] ?? 0, scope = Scope("instance${classes[iClass] ?? 0}_$name", parent) {
    Block nB = iClass.block.copy();
    nB.runners.insert(0, LAssignmentStatement("this", VE(this), "N/A"));
    nB.setup(parent);
    classes[iClass] = (classes[iClass] ?? 0) + 1;
    //print(scope);
    nB.run(parent);
    scope = nB.blockScope;
    //print("$id: ${nB.id}");
  }
  final int id;
  T callFun<T>(String n, List<dynamic> args) {
    //print(n);
    //print(scope);
    var fun = scope._getVar(n);
    //print(fun.block.blockScope);
    //print("$id: $scope ${scope.vars}");
    if(fun == null) {
      return null;
    }
    if(fun.args.length != args.length) {
      throw("Wrong num' of arg's $n: exp: ${args.length}: got: ${fun.args.length}");
    }
    //print("calling $name#$id.$n w/ $args <");
    for (int i = 0; i < args.length; i++) {
      //print("  arg<");
      //print("    b4: ${scope.vars}");
      fun.block.blockScope
      .addVar((fun.args)[i],
      args[i]);
      //print("    :");
      //print("    after: ${scope.vars}");
      //print("  >\n");
    }
    try {
      //print("  try<");
      //print("    b4: ${scope.vars}");
      //print("  >?\n>?\n");
      var result = scope.getVar(n)?.block?.run(scope);
      //print("    calling $name(${args.join(", ")}); got $result");
      //print("  >\n>\n");
    } on Return catch(r) {
      return r.value as T;
    } catch(e, st) {
      throw UnimplementedError("$st(calling $name with ${scope.vars})$e");
    }
    return null;
  }
  Scope scope;
  final String name;
  operator +(dynamic other) => callFun("plus", [other]) ?? (throw UnimplementedError("No valid + on $name"));
  operator -(dynamic other) => callFun("minus", [other]) ?? (throw UnimplementedError("No valid - on $name"));
  operator -()              => callFun("negate", []) ?? (throw UnimplementedError("No valid unary - on $name"));
  operator *(dynamic other) => callFun("times", [other]) ?? (throw UnimplementedError("No valid * on $name"));
  operator /(dynamic other) => callFun("div", [other]) ?? (throw UnimplementedError("No valid / on $name"));
  operator ==(dynamic other) => callFun("equals", [other]) ?? super == other;
  String toString() => callFun<String>("toStr", []) ?? "$name#$id";
}
class Scope {
  Scope(this.debugName, this.parent) {

  }
  final String debugName;
  String toString() => describe();
  final Scope parent;
  Map<String, dynamic> vars = {};
  String addVar(String name, dynamic value, String line) { 
   if(vars[name] != null) throw UnimplementedError("Duplicate local $name [line $line]");
   vars[name] = value;
   return "XXX";
  }
  void addAll(Scope scope) {
    //print("Scope $debugName is adding everything from ${scope?.debugName}");
    if (scope != null) {
      for (var key in scope.vars.keys) {
        //print("  $key: ${scope.vars[key].runtimeType} = ${scope.vars[key]}");
      }
    }
    vars.addAll(scope?.vars ?? {});
  }

  String addPar(String name, dynamic value, [Scope debugChild]) {
    if(vars[name] == null) {
      //print("$debugName(${describe()}) > ${parent.describe()}");
      if(parent == null) { 
      if(debugChild != null) return "ERR: No existing variable '$name' when setting variable";
      throw UnimplementedError("No existing variable '$name' when setting variable (${describe()})"); 
      }
      print(parent.addPar(name, value));
    } else {
      vars[name] = value;
    }
    //print("adding $debugName@${describe()}");
    return "XXXX";
  }

  String describe() => parent != null ? "$debugName>" + parent.describe() : '$debugName';

  dynamic _getVar(String name) => vars[name] ?? parent?._getVar(name);

  dynamic getVar(String name) => _getVar(name) ?? (throw UnimplementedError("No $name exists on $this ${this.vars}"));
}

class ScopeStatement extends Statement{
  ScopeStatement(this.a, this.b, this.block);
  final IdentifierExpression a;
  final Expression b;
  final Block block;
  String debugPrint() => "TODO";
  dynamic run(Scope scope) {
    Scope x = Scope("scope_statement_scope", b.eval(scope).scope);
    x.addVar(a.name, a.eval(scope), "TODO");
    block.setup(x);
    block.run();
  }
  factory ScopeStatement.parse(TokenGetter tokens) {
    //print("parseExpressioning#3");
    IdentifierExpression first = IdentifierExpression(tokens.advance().lexeme);
    Expression second = parseExpression(tokens);
    if(tokens.peek().type != TokenType.LEFT_BRACE) {
      print("no LB, ${tokens.peek().type} [line ${tokens.peek().line}]");
      throw UnimplementedError();
    }
    tokens.advance();
    List<Statement> block = [];
    while(tokens.peek().type != TokenType.RIGHT_BRACE) {
      //print("Please...");
      block.add(parseLine(tokens));
    }
    tokens.advance();
    //print("End while");
    return ScopeStatement(first,second, Block(block, "scope_statement"));  
  }
}

class WhileStatement extends Statement{
  WhileStatement(this.boolean, this.block);
  final Expression boolean;
  final Block block;
  String debugPrint() => "while ${boolean.debugPrint()} {\n${block.debugPrint()}\n}";
  dynamic run(Scope scope) {
    while(boolean.eval(scope)) {
      block.setup(scope);
      block.run(scope);
    }
  }
  factory WhileStatement.parse(TokenGetter tokens) {
    //print("parseExpressioning#3");
    Expression boolean = parseExpression(tokens);
    if(tokens.peek().type != TokenType.LEFT_BRACE) {
      print("no LB, ${tokens.peek().type} [line ${tokens.peek().line}]");
      throw UnimplementedError();
    }
    tokens.advance();
    List<Statement> block = [];
    while(tokens.peek().type != TokenType.RIGHT_BRACE) {
      //print("Please...");
      block.add(parseLine(tokens));
    }
    tokens.advance();
    //print("End while");
    return WhileStatement(boolean, Block(block, "while"));  
  }
}

class IfStatement extends Statement{
  IfStatement(this.boolean, this.block, this.elseblock);
  final Expression boolean;
  final Block block;
  final Block elseblock;
  String debugPrint() => "if ${boolean.debugPrint()} {\n${block.debugPrint()}\n}";
  dynamic run(Scope scope) {
    if(boolean.eval(scope)) {
      //print("...this worked");
       block.setup(scope);
      return block.run(scope);
    } else {
      elseblock.setup(scope);
      return elseblock.run(scope);
    }
  }
  factory IfStatement.parse(TokenGetter tokens) {
    //print("parseExpressioning#3");
    Expression boolean = parseExpression(tokens);
    if(tokens.peek().type != TokenType.LEFT_BRACE) {
      print("no LB, ${tokens.peek().type} [line ${tokens.peek().line}]");
      throw UnimplementedError();
    }
    tokens.advance();
    List<Statement> block = [];
    List<Statement> elseblock = [];
    while(tokens.peek().type != TokenType.RIGHT_BRACE) {
      //print("Please...");
      block.add(parseLine(tokens));
    }
    tokens.advance();
    if(tokens.peek().type == TokenType.ELSE) {
      tokens.advance();
      if(tokens.peek().type != TokenType.LEFT_BRACE) {
        //print("no LB, ${tokens.peek().type}");
        throw UnimplementedError("no left brace after 'else' line ${tokens.peek().line}");
      }
      tokens.advance();
      while(tokens.peek().type != TokenType.RIGHT_BRACE) {
        //print("Please...");
        elseblock.add(parseLine(tokens));
      }
      tokens.advance();
    }
    //print("End while");
    return IfStatement(boolean, Block(block, "if"), Block(elseblock, "else"));  
  }
}

class ClassStatement extends Statement { 
  ClassStatement(this.name, this.block);
  final Block block;
  Scope get scope => block.blockScope;
  final String name; 
  factory ClassStatement.parse(TokenGetter tokens) {
    if(tokens.peek().type != TokenType.IDENTIFIER) {
      throw UnimplementedError("No name near 'CLASS'");
    }
    var name = tokens.advance().lexeme;
    //print("LOOKYER: a ${tokens.peek().type}");
    if(tokens.peek().type != TokenType.LEFT_BRACE) {
      //print("no LB, ${tokens.peek().type}");
      throw UnimplementedError('NO "{" NEAR "class $name"');
    }
    tokens.advance();
    List<Statement> block = [];
    while(tokens.peek().type != TokenType.RIGHT_BRACE) {
      //print("Please...");
      //print("At ${tokens.peek().type}");
      //print("middle ${tokens.peek().type}");
      block.add(parseClassLine(tokens));
    }
    //print("Closing RIGHT_BRACE");
    tokens.advance();
    //print("Now ${tokens.peek()}");
    //print("$name$args");

    return ClassStatement("$name", Block(block, "$name-class"));
  }
  String debugPrint() => "class $name {\n${block.debugPrint()}\n}";
  void run(Scope scope) {
    block..setup(scope)..run(scope);
    scope?.addVar(name + "_class", Class(block), "N/A");
    scope?.addVar(name, Fun(Block([CustomVarStatement(name + "_lastinst", ()=>Instance(name, scope?.getVar(name + "_class"), scope)), InitStatement(name + "_lastinst"), ReturnStatement(IdentifierExpression(name + "_lastinst"))], "$name<init>"), scope.getVar(name + "_class").block.blockScope.getVar("init").args), "N/A");
    scope?.getVar(name).block.setup(scope);
  }
}

class InitStatement extends Statement {
  InitStatement(this.instance);
  final String instance;
  void run(Scope scope) {
    dynamic result = FunCallExpression(IdentifierExpression("init"), scope.getVar(instance).scope.getVar("init").args.map((String arg) => IdentifierExpression(arg)).toList().cast<Expression>().toList()).eval(scope.getVar(instance).scope);
    //print("Ins($instance)");
    return result;
  }
}

class CustomVarStatement extends Statement {
  CustomVarStatement(this.name, this.fun);
  final dynamic Function() fun;
  final String name;
  void run(Scope scope) {
    scope.vars[name] = fun();
  }
}

class PrintStatement extends Statement {
  PrintStatement(this.expr);
  final Expression expr;
  void run(Scope scope) {
    //print("printin' $expr");
    var result = expr.eval(scope);
    print(result is double ? result.round() == result ? result.toString().substring(0, result.toString().length-2) : result.toString() : result.toString());
  }
  factory PrintStatement.parse(TokenGetter tokens) {
    //print("parseExpressioning#4");
    var result = PrintStatement(parseExpression(tokens));
    if(tokens.peek().type == TokenType.SEMICOLON) tokens.advance();
    return result;
  } 
  String debugPrint() => "print ${expr.debugPrint()}";
}

class FunDeclStatement extends Statement{
  FunDeclStatement(this.name, this.fun, this.args);
  final Block fun;
  final String name;
  final List<String> args;
  String debugPrint() => "\u001b[33mfun\u001b[0m $name(${args.join(", ")}) {\n${fun.debugPrint()}\n}";
  factory FunDeclStatement.parse(TokenGetter tokens) {
    //print("LOOKYMCLOOK: a ${tokens.peek().type}");
    if(tokens.peek().type != TokenType.IDENTIFIER) {
      throw UnimplementedError("No name near 'FUN', ${tokens.peek().line}, ${tokens.peek().type}");
    }
    var name = tokens.advance().lexeme;
    //print("$name.LOOKYER: a ${tokens.peek().type}");
    if(tokens.advance().type != TokenType.LEFT_PAREN) {
      throw UnimplementedError("NO \"(\" NEAR $name");
    }
    //print("$name.LOOKYEREL: a ${tokens.peek().type}");
    var args = <String>[];
    while(true) {
      //print("while #N: ${tokens.peek().type}/${tokens.peek().lexeme}");
      if(tokens.peek().type != TokenType.IDENTIFIER) {
        //print("LOOKY: a ${tokens.peek().type}");
        tokens.advance();
        break;
      }
      args.add(tokens.advance().lexeme);
      if(tokens.peek().type != TokenType.COMMA) {
        //print("$name.LOOK: a ${tokens.peek().type}");
        tokens.advance();
        //print("$name.LOOK2: a ${tokens.peek().type}");
        break;
      }
      tokens.advance();
    }
    if(tokens.peek().type != TokenType.LEFT_BRACE) {
      //print("[line ${tokens.peek().line}] $name.no LB, ${tokens.peek().type}");
      throw UnimplementedError('NO "{" NEAR "fun $name(${args.join(', ')}) [line ${tokens.peek().line}]"');
    }
    tokens.advance();
    List<Statement> block = [];
    while(tokens.peek().type != TokenType.RIGHT_BRACE) {
      //print("Please...");
      //print("At ${tokens.peek().type}");
      //print("middle ${tokens.peek().type}");
      block.add(parseLine(tokens));
    }
    //print("Closing RIGHT_BRACE");
    tokens.advance();
    //print("Now ${tokens.peek()}");
    //print("$name$args");

    return FunDeclStatement("$name", Block(block, "$name-fun"), args);
  }
  void run(Scope scope) {
    fun.setup(scope);
    scope?.addVar(name, Fun(fun, args), "TODO");
  }
  Statement copy() => FunDeclStatement(name, fun.copy(), args);
}

abstract class Expression {
  dynamic eval(Scope scope);
  String str(Scope scope) {
    return "${eval(scope)}";
  }
  String debugPrint() => "???";
}

Expression parseExpression(TokenGetter tokens) {
  //print("Parsing expr...");
  Expression result = OrExpression.parse(tokens);
  //print("Got $result, at ${tokens.peek().type}");
  return result;
}

class IdentifierExpression extends Expression {
  final String name;
  IdentifierExpression(this.name);
  dynamic eval(Scope scope) => scope.getVar(name);
  String debugPrint() => "$name";
  String toString() => "$name";
}

class StringExpression extends Expression{
  StringExpression(this.value);
  final String value;
  String eval(Scope scope) => value;
  String debugPrint() => "\"$value\"";
}

class NumExpression extends Expression{
  NumExpression(this.value);
  final double value;
  double eval(Scope scope) => value;
  String debugPrint() => "$value";
}

class BoolExpression extends Expression {
  BoolExpression(this.value);
  final bool value;
  bool eval(Scope scope) => value;
  String debugPrint() => "$value";
}

class TokenGetter {
  int current = 0;
  final List<Token> tokens;
  TokenGetter(this.tokens);
  Token peek() {
    return tokens[current];
  }
  bool isAtEnd() {         
    return current >= tokens.length;
  }
  Token advance() {                               
    current++;
    //print(tokens[current - 1].lexeme);                                           
    return tokens[current - 1];              
  }
}

class OrExpression extends Expression {
  OrExpression(this.a, this.b);
  final Expression a;
  final Expression b;
  bool eval(Scope scope) => a.eval(scope) || b.eval(scope);
  static Expression parse(TokenGetter tokens) {
    var a = AndExpression.parse(tokens);
    if(tokens.peek().type != TokenType.OR) {
      //print("not OR: ${tokens.peek().type}");
      return a;
    }
    tokens.advance();
    var b = OrExpression.parse(tokens);
    return OrExpression(a, b);
  }
  String debugPrint() => "${a.debugPrint()} || ${b.debugPrint()}";
}

class AndExpression extends Expression {
  AndExpression(this.a, this.b);
  final Expression a;
  final Expression b;
  bool eval(Scope scope) => a.eval(scope) && b.eval(scope);
  static Expression parse(TokenGetter tokens) {
    var a = NotEqualsExpression.parse(tokens);
    if(tokens.peek().type != TokenType.AND) {
      //print("not OR: ${tokens.peek().type}");
      return a;
    }
    tokens.advance();
    var b = AndExpression.parse(tokens);
    return AndExpression(a, b);
  }
  String debugPrint() => "${a.debugPrint()} && ${b.debugPrint()}";
}

class DotExpression extends Expression {
  DotExpression(this.instance, this.getter);
  final Expression getter;
  final Expression instance;
  static Expression parse(TokenGetter tokens, Expression ins) {
    return DotExpression(ins, IdentifierExpression(tokens.advance().lexeme));
  }
  String debugPrint() => instance.debugPrint() + "." + getter.debugPrint();
  dynamic eval(Scope scope) {
    var evaluation = instance.eval(scope);
    if(!(evaluation is Instance || evaluation is Class)) {
      //print("${instance.debugPrint()} is a ${evaluation.runtimeType}");
    }
    return getter.eval(evaluation?.scope);
  }
}

class NotEqualsExpression extends Expression {
  NotEqualsExpression(this.a, this.b);
  final Expression a;
  final Expression b;
  bool eval(Scope scope) => a.eval(scope) != b.eval(scope);
  static Expression parse(TokenGetter tokens) {
    var a = EqualsExpression.parse(tokens);
    if(tokens.peek().type != TokenType.BANG_EQUAL) {
      //print("not BANG_EQUAL: ${tokens.peek().type}");
      return a;
    }
    tokens.advance();
    var b = NotEqualsExpression.parse(tokens);
    return NotEqualsExpression(a, b);
  }
  String debugPrint() => "${a.debugPrint()} != ${b.debugPrint()}";
}

class EqualsExpression extends Expression {
  EqualsExpression(this.a, this.b);
  final Expression a;
  final Expression b;
  bool eval(Scope scope) => a.eval(scope) == b.eval(scope);
  static Expression parse(TokenGetter tokens) {
    var a = LessExpression.parse(tokens);
    if(tokens.peek().type != TokenType.EQUAL_EQUAL && tokens.peek().type != TokenType.EQUAL) {
      //print("not EQUAL: ${tokens.peek().type}");
      return a;
    }
    tokens.advance();
    var b = EqualsExpression.parse(tokens);
    return EqualsExpression(a, b);
  }
  String debugPrint() => "${a.debugPrint()} = ${b.debugPrint()}";
}


class LessExpression extends Expression { 
  LessExpression(this.a, this.b);
  final Expression a;
  final Expression b;
  bool eval(Scope scope) => a.eval(scope) < b.eval(scope);
  static Expression parse(TokenGetter tokens) {
    var a = LessEqualExpression.parse(tokens);
    if(tokens.peek().type != TokenType.LESS) {
      //print("not LESS: ${tokens.peek().type}");
      return a;
    }
    tokens.advance();
    var b = LessExpression.parse(tokens);
    return LessExpression(a, b);
  }
  String debugPrint() => "${a.debugPrint()} < ${b.debugPrint()}";
}

class LessEqualExpression extends Expression { 
  LessEqualExpression(this.a, this.b);
  final Expression a;
  final Expression b;
  bool eval(Scope scope) => a.eval(scope) <= b.eval(scope);
  static Expression parse(TokenGetter tokens) {
    var a = GreaterExpression.parse(tokens);
    if(tokens.peek().type != TokenType.LESS_EQUAL) {
      //print("not LESS: ${tokens.peek().type}");
      return a;
    }
    tokens.advance();
    var b = LessEqualExpression.parse(tokens);
    return LessEqualExpression(a, b);
  }
  String debugPrint() => "${a.debugPrint()} <= ${b.debugPrint()}";
}

class GreaterExpression extends Expression { 
  GreaterExpression(this.a, this.b);
  final Expression a;
  final Expression b;
  bool eval(Scope scope) => a.eval(scope) > b.eval(scope);
  static Expression parse(TokenGetter tokens) {
    var a = GreaterEqualExpression.parse(tokens);
    if(tokens.peek().type != TokenType.GREATER) {
      //print("not LESS: ${tokens.peek().type}");
      return a;
    }
    tokens.advance();
    var b = GreaterExpression.parse(tokens);
    return GreaterExpression(a, b);
  }
  String debugPrint() => "${a.debugPrint()} > ${b.debugPrint()}";
}

class GreaterEqualExpression extends Expression { 
  GreaterEqualExpression(this.a, this.b);
  final Expression a;
  final Expression b;
  bool eval(Scope scope) => a.eval(scope) >= b.eval(scope);
  static Expression parse(TokenGetter tokens) {
    var a = PlusExpression.parse(tokens);
    if(tokens.peek().type != TokenType.GREATER_EQUAL) {
      //print("not LESS: ${tokens.peek().type}");
      return a;
    }
    tokens.advance();
    var b = GreaterEqualExpression.parse(tokens);
    return GreaterEqualExpression(a, b);
  }
  String debugPrint() => "${a.debugPrint()} >= ${b.debugPrint()}";
}

class PlusExpression extends Expression {
  PlusExpression(this.a, this.b);
  final Expression a;
  final Expression b;
  dynamic eval(Scope scope) => a.eval(scope) + b.eval(scope);
  static Expression parse(TokenGetter tokens) {
    var a = MinusExpression.parse(tokens);
    if(tokens.peek().type != TokenType.PLUS) {
      //print("not LESS: ${tokens.peek().type}");
      return a;
    }
    tokens.advance();
    var b = PlusExpression.parse(tokens);
    return PlusExpression(a, b);
  }
  String debugPrint() => "${a.debugPrint()} + ${b.debugPrint()}";
}

class MinusExpression extends Expression {
  MinusExpression(this.a, this.b);
  final Expression a;
  final Expression b;
  dynamic eval(Scope scope) => a.eval(scope) - b.eval(scope);
  static Expression parse(TokenGetter tokens) {
    var a = TimesExpression.parse(tokens);
    if(tokens.peek().type != TokenType.MINUS) {
      //print("not LESS: ${tokens.peek().type}");
      return a;
    }
    tokens.advance();
    var b = MinusExpression.parse(tokens);
    return MinusExpression(a, b);
  }
  String debugPrint() => "${a.debugPrint()} - ${b.debugPrint()}";
}

class TimesExpression extends Expression {
  TimesExpression(this.a, this.b);
  final Expression a;
  final Expression b;
  dynamic eval(Scope scope) => a.eval(scope) * (a.eval(scope) is String ? (b.eval(scope) as double).round() :b.eval(scope));
  static Expression parse(TokenGetter tokens) {
    var a = DivExpression.parse(tokens);
    if(tokens.peek().type != TokenType.STAR) {
      //print("not LESS: ${tokens.peek().type}");
      return a;
    }
    tokens.advance();
    var b = TimesExpression.parse(tokens);
    return TimesExpression(a, b);
  }
  String debugPrint() => "${a.debugPrint()} * ${b.debugPrint()}";
}

class DivExpression extends Expression {
  DivExpression(this.a, this.b);
  final Expression a;
  final Expression b;
  dynamic eval(Scope scope) => a.eval(scope) / b.eval(scope);
  static Expression parse(TokenGetter tokens) {
    var a = parsePost(tokens);
    if(tokens.peek().type != TokenType.SLASH) {
      //print("not LESS: ${tokens.peek().type}");
      return a;
    }
    tokens.advance();
    var b = DivExpression.parse(tokens);
    return DivExpression(a, b);
  }
  String debugPrint() => "${a.debugPrint()} / ${b.debugPrint()}";
}

Expression parsePost(TokenGetter tokens) {
  var value = FunCallExpression.parse(tokens);
  if(tokens.peek().type != TokenType.IDENTIFIER) {
    return value;
  }
  var x = FunCallExpression(IdentifierExpression(tokens.peek().lexeme), [value]);
  tokens.advance();
  while(tokens.peek().type == TokenType.IDENTIFIER) {
    x = FunCallExpression(IdentifierExpression(tokens.peek().lexeme), [x]);
    tokens.advance();
  }
  return x;
}

class FunCallExpression extends Expression {
  FunCallExpression(this.a, this.args);
  final Expression a;
  final List<Expression> args;
  static Expression parse(TokenGetter tokens) {
    Expression a = TostrExpression.parse(tokens);
    while(tokens.peek().type == TokenType.DOT) {
      tokens.advance();
      a = DotExpression.parse(tokens, a);
    }
    //print("$a..2${tokens.peek().type}");
    if(tokens.peek().type != TokenType.LEFT_PAREN) return a;
    tokens.advance();
    List<Expression> args = [];
    while(true) {
      if(tokens.peek().type == TokenType.RIGHT_PAREN) break;
      //print("parseExpressioning");
      args.add(parseExpression(tokens));
      if(tokens.peek().type != TokenType.COMMA) break;
      tokens.advance();
      //print("FunCallExpression at ${tokens.peek().type}");
    }
    //print("$a...${tokens.peek().type}");
    if(tokens.peek().type != TokenType.RIGHT_PAREN) throw UnimplementedError("NO ')' after funcall args(${tokens.peek().type})");
    tokens.advance();
    return FunCallExpression(a, args);
  }
  dynamic eval(Scope scope) {
    var fun = a.eval(scope);
    //print(fun.block);
    if(fun == null) print("Function ${a.debugPrint()} does not exist");
    if(!(fun is Fun)) print("${a.debugPrint()} is a ${fun.runtimeType}");
    if(fun?.args?.length != args.length && fun != null) {
      throw("Wrong number of arguments for ${a.debugPrint()}: exp: ${fun.args.length}: got: ${args.length}");
    }
    //print(a.toString() + "........" + fun.toString());
    //print(args.toString() + ":" + fun.args.toString());
    for (int i = 0; i < args.length; i++) {
      //print(i);

      fun.block.parentSetupScope
      .vars[fun.args[i]] =
      (args ?? List(i+1))[i].eval(scope);
    }
    try {
      var result = fun?.block?.run(scope);
      //print("calling $name(${args.join(", ")}); got $result");
      return result;
    } on Return catch(r) {
      //print("got ${r.value}");
      return r.value;
    } on NoSuchMethodError catch(e,st) {
      throw UnimplementedError("(calling ${a.debugPrint()} with ${scope.vars})$e$st");
    }
    return null;
  }
  String debugPrint() => "funcallexpr: ${a.debugPrint()}(${args.map((Expression expr) => expr.debugPrint()).join(", ")})";
  String toString() => debugPrint();
}

class TostrExpression extends Expression {
  TostrExpression(this.value);
  final Expression value;
  String eval(Scope scope) => value.str(scope);
  static Expression parse(TokenGetter tokens) {
    if(tokens.peek().type != TokenType.DOLLAR) {
      //print("not OR: ${tokens.peek().type}");
      return parseNumericNegation(tokens);
    }
    tokens.advance();
    var value = TostrExpression.parse(tokens);
    return TostrExpression(value);
  }
  String debugPrint() => "(\$${value.debugPrint()})";
}

Expression parseNumericNegation(TokenGetter tokens) {
  if(tokens.peek().type != TokenType.MINUS) {
    return parseGroup(tokens);
  }
  tokens.advance();
  return MinusExpression(NumExpression(0.0), parseNumericNegation(tokens));
} 

Expression parseGroup(TokenGetter tokens) {
  //"(" here?
  if(tokens.peek().type != TokenType.LEFT_PAREN) {
    //print("not LEFT_PAREN: ${tokens.peek().type}");
    var result = parseValue(tokens);
    tokens.advance();
    //print("now at ${tokens.peek().type}");
    return result;
  }
  //print("ingroup");
  tokens.advance();
  //print("parseExpressioning#2");
  var result = parseExpression(tokens);
  print("DEBUG: $result");
  if(tokens.peek().type != TokenType.RIGHT_PAREN) {
    //print("no RIGHT_PAREN, ${tokens.peek().type}");
    throw UnimplementedError("No right parenteses on line ${tokens.peek().line}");
  }
  tokens.advance();
  return result;

  //")" ends it
}


Expression parseValue(TokenGetter tokens) {
  //print("V ${tokens.peek().type}");
  switch(tokens.peek().type) {
    case TokenType.STRING:
      return StringExpression(tokens.peek().literal);
    case TokenType.NUMBER:
      return NumExpression(tokens.peek().literal);
    case TokenType.TRUE:
      return BoolExpression(true);
    case TokenType.FALSE:
      return BoolExpression(false);
    case TokenType.IDENTIFIER:
      return IdentifierExpression(tokens.peek().lexeme);
    case TokenType.NIL:
      return NullExpression();
    case TokenType.NEWLINE:
      return StringExpression("\n");
    default:
      print("[line ${tokens.peek().line}] Unexpected ${tokens.peek().lexeme}");
      throw UnimplementedError();
  }
}

class NullExpression extends Expression {Nil eval(Scope _) => nil;}

class Nil { 
  String toString() => "nil";
}

final Nil nil = Nil(); 