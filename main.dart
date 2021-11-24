import 'dart:io';
import 'lexer.dart';
import 'parser.dart';

void main(List<String> args) {
  if(args.length == 0) args = ["pfs/file"];
  Map<String, String> files = filer(args[0]);
  run(files);
}

Map<String, String> filer(String file) {
  Map<String, String> result = {};
  for(String file in File("$file.inc").readAsLinesSync()) {
    result.addAll((filer(file)));
  }
  result[file] = (File("$file.pfs").readAsStringSync());
  return result;
}

void run(Map<String, String> sources) {    
  List<Token> allTokens = [];
  bool hadError = false;
  Scanner scanner;
  for (MapEntry<String, String> source in sources.entries) {
    //print(source);
    scanner = new Scanner(source.value, print, source.key);    
    List<Token> tokens = scanner.scanTokens();
    allTokens+=(tokens);
    if(scanner.hadError) hadError = true;
  }
  allTokens.add(new Token(TokenType.EOF, "", null, scanner.line, scanner.file));
  //print(allTokens);
  
  if(!hadError) {        
    parse(allTokens);
  }                                         
}