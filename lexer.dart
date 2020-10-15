enum TokenType {                                   
  // Single-character tokens.                      
  LEFT_PAREN, RIGHT_PAREN, LEFT_BRACE, RIGHT_BRACE,
  COMMA, DOT, MINUS, PLUS, SLASH, STAR, SEMICOLON,

  // One or two character tokens.                  
  BANG, BANG_EQUAL,                                
  EQUAL, EQUAL_EQUAL,                              
  GREATER, GREATER_EQUAL,                          
  LESS, LESS_EQUAL, DOLLAR,                    

  // Literals.                                     
  IDENTIFIER, STRING, NUMBER,                      

  // Keywords.                                     
  AND, CLASS, ELSE, FALSE, FUN, FOR, IF, NIL, OR,  
  PRINT, SUPER, TRUE, VAR, WHILE, RETURN, NEWLINE, LOCAL, SCOPE,

  EOF                                              
}

class Token {                                              
  final TokenType type;                                   
  final String lexeme;                                    
  final Object literal;                                   
  final String line;

  Token(this.type, this.lexeme, this.literal, int line, String file): line = "$line of $file";

  String toString() {                                      
    return "$type $lexeme $literal";                   
  }                          
}

typedef Print = void Function(String message);

class Scanner {  
  bool hadError = false;

  void error(int line, String message) {           
    report(line, "", message);                            
  }

  void report(int line, String where, String message) {
    print("[line $line file $file] Error" + where + ": " + message);
    hadError = true;          
  }

  final String source;                                   
  final List<Token> tokens = [];  
  static final Map<String, TokenType> keywords = {                      
    "class": TokenType.CLASS,                     
    "else": TokenType.ELSE,                      
    "false": TokenType.FALSE,                     
    "for": TokenType.FOR,                       
    "fun": TokenType.FUN,                       
    "if": TokenType.IF,                        
    "nil": TokenType.NIL,                       
    "or": TokenType.OR,    
    "and": TokenType.AND,                    
    "print": TokenType.PRINT,                   
    "super": TokenType.SUPER,                         
    "true": TokenType.TRUE,                      
    "var": TokenType.VAR,     
    "while": TokenType.WHILE, 
    "return": TokenType.RETURN,
    "newline": TokenType.NEWLINE,
    "local": TokenType.LOCAL,
    "scope": TokenType.SCOPE,

    // Winnie-the-Pooh keywords

    "Winnie": TokenType.VAR,
    "pooh": TokenType.EQUAL,
    "Piglet": TokenType.PRINT,
    "very": TokenType.COMMA,
    "Eeyore": TokenType.FUN,
    "sad": TokenType.LEFT_PAREN,
    "lonely": TokenType.RIGHT_PAREN,
    "went": TokenType.LEFT_BRACE,
    "end": TokenType.RIGHT_BRACE,
    "take": TokenType.MINUS,
    "his": TokenType.DOT,
    "give": TokenType.PLUS,
    "Here": TokenType.RETURN,
    "says": TokenType.DOLLAR,
    "yes": TokenType.TRUE,
    "no": TokenType.FALSE,
    "Rabbit": TokenType.CLASS,
    
};

  int start = 0;                               
  int current = 0;                             
  int line = 1; 
  final String file;                     

  final Print print;

  Scanner(this.source, this.print, this.file);

  List<Token> scanTokens() {                        
    while (!isAtEnd()) {                            
      // We are at the beginning of the next lexeme.
      start = current;                              
      scanToken();                                  
    }
    return tokens;
  }

  void scanToken() {                     
    String c = advance();                          
    switch (c) {                                 
      case '(': addToken(TokenType.LEFT_PAREN); break;     
      case ')': addToken(TokenType.RIGHT_PAREN); break;    
      case '{': addToken(TokenType.LEFT_BRACE); break;     
      case '}': addToken(TokenType.RIGHT_BRACE); break;    
      case ';': addToken(TokenType.SEMICOLON); break;
      case ',': addToken(TokenType.COMMA); break;          
      case '.': addToken(TokenType.DOT); break;         
      case '+': addToken(TokenType.PLUS); break;   
      case '-': addToken(TokenType.MINUS); break;   
      case '*': addToken(TokenType.STAR); break;
      case '&': addToken(TokenType.AND); break;
      case '\$': addToken(TokenType.DOLLAR); break;
      case '!': addToken(match('=') ? TokenType.BANG_EQUAL : TokenType.BANG); break;      
      case '=': addToken(match('=') ? TokenType.EQUAL_EQUAL : TokenType.EQUAL); break;    
      case '<': addToken(match('=') ? TokenType.LESS_EQUAL : TokenType.LESS); break;      
      case '>': addToken(match('=') ? TokenType.GREATER_EQUAL : TokenType.GREATER); break;
      case '/':                                                       
        if (match('/')) {                                             
          // A comment goes until the end of the line.                
          while (peek() != '\n' && !isAtEnd()) advance();             
        } else {                                                      
          addToken(TokenType.SLASH);                                            
        }                                                             
        break;
      case ' ':                                    
      case '\r':                                   
      case '\t':                                   
        // Ignore whitespace.                      
        break;
      case '"': string(); break;  
      case '\n':                                   
        line++;                                    
        break;
      default:                                     
        if (isDigit(c)) {                          
          number();
        } else if (isAlpha(c)) {                   
          identifier();                                
        } else {                                   
          error(line, "Unexpected character $c.");
        } 
      break;                                 
    }                                            
  }

  void identifier() {                
    while (isAlphaNumeric(peek())) advance();
    String text = source.substring(start, current);

    TokenType type = keywords[text];           
    if (type == null) type = TokenType.IDENTIFIER;           
    addToken(type);                    
  }
  
  bool isAlpha(String c) {       
    return RegExp("[a-zA-z_]").hasMatch(c);                   
  }

  bool isAlphaNumeric(String c) {
    return isAlpha(c) || isDigit(c);      
  } 
  
  bool isDigit(String c) {
    return c == "0" || c == "1" || c == "2" || c == "3" || c == "4" || c == "5" || c == "6" || c == "7" || c == "8" || c == "9";   
  } 

  String peekNext() {                         
    if (current + 1 >= source.length) return '#';
    return source[current + 1];              
  }

  void number() {                                     
    while (isDigit(peek())) advance();

    // Look for a fractional part.                            
    if (peek() == '.' && isDigit(peekNext())) {               
      // Consume the "."                                      
      advance();                                              

      while (isDigit(peek())) advance();                      
    }                                                         

    addLiteralToken(TokenType.NUMBER, double.parse(source.substring(start, current)));
  }

  void string() {                                   
    while (peek() != '"' && !isAtEnd()) {                   
      if (peek() == '\n') line++;                           
      advance();                                            
    }

    // Unterminated string.                                 
    if (isAtEnd()) {                                        
      error(line, "Unterminated string.");              
      return;                                               
    }                                                       

    // The closing ".                                       
    advance();                                              

    // Trim the surrounding quotes.                         
    String value = source.substring(start + 1, current - 1);
    addLiteralToken(TokenType.STRING, value);                                
  }

  String peek() {           
    if (isAtEnd()) return '#';   
    return source[current];
  }  

  bool isAtEnd() {         
    return current >= source.length;
  }

  bool match(String expected) {                 
    if (isAtEnd()) return false;                         
    if (source[current] != expected) return false;

    current++;                                           
    return true;                                         
  }

  String advance() {                               
    current++; 
    return source[current - 1];                   
  }

  void addToken(TokenType type) {                
    addLiteralToken(type, null);     
  }       

  void addLiteralToken(TokenType type, Object literal) {
    String text = source.substring(start, current);      
    tokens.add(new Token(type, text, literal, line, file));    
  }    
}   