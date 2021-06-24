%{
#include <iostream>
#include <set>
#include <vector>

#include "parser.hpp"

using namespace std;
extern int yylex();
void yyerror(YYLTYPE* loc, const char* err);
string* translate_boolean_str(string* boolean_str);

/*
 * Here, target_program is a string that will hold the target program being
 * generated, and symbols is a simple symbol table.
 */
struct Node* root;

string* target_program;
set<string> symbols;
%}

%code requires {
  #include "ast.hpp"
}

/* Enable location tracking. */
%locations

/*
 * All program constructs will be represented as strings, specifically as
 * their corresponding C/C++ translation.
 */
//%define api.value.type { string* }

%union{
	struct Node* node;
	string* str;
}
/*
 * Because the lexer can generate more than one token at a time (i.e. DEDENT
 * tokens), we'll use a push parser.
 */
%define api.pure full
%define api.push-pull push

/*
 * These are all of the terminals in our grammar, i.e. the syntactic
 * categories that can be recognized by the lexer.
 */
%token <str> IDENTIFIER
%token <str> FLOAT INTEGER BOOLEAN
%token <node> INDENT DEDENT NEWLINE
%token <node> AND BREAK DEF ELIF ELSE FOR IF NOT OR RETURN WHILE
%token <node> ASSIGN PLUS MINUS TIMES DIVIDEDBY
%token <node> EQ NEQ GT GTE LT LTE
%token <node> LPAREN RPAREN COMMA COLON
%type <node> program statements statement primary_expression negated_expression expression assign_statement
%type <node> block condition if_statement elif_blocks else_block while_statement break_statement
/*
 * Here, we're defining the precedence of the operators.  The ones that appear
 * later have higher precedence.  All of the operators are left-associative
 * except the "not" operator, which is right-associative.
 */
%left OR
%left AND
%right NOT
%left EQ NEQ GT GTE LT LTE
%left PLUS MINUS
%left TIMES DIVIDEDBY

/* This is our goal/start symbol. */
%start program

%%

/*
 * Each of the CFG rules below recognizes a particular program construct in
 * Python and creates a new string containing the corresponding C/C++
 * translation.  Since we're allocating strings as we go, we also free them
 * as we no longer need them.  Specifically, each string is freed after it is
 * combined into a larger string.
 */

/*
 * This is the goal/start symbol.  Once all of the statements in the entire
 * source program are translated, this symbol receives the string containing
 * all of the translations and assigns it to the global target_program, so it
 * can be used outside the parser.
 */

program
  : statements 
  { 
    string* type = new string("BLOCK");
    string* val = new string("");
    root = new Node(type, val);
    root->children.push_back($1);
    }

  ;

/*
 * The `statements` symbol represents a set of contiguous statements.  It is
 * used to represent the entire program in the rule above and to represent a
 * block of statements in the `block` rule below.  The second production here
 * simply concatenates each new statement's translation into a running
 * translation for the current set of statements.
 */
statements
  : statement 
  { 
    $$ = $1;
  }
  | statements statement 
  {
    $$ = $1; 
    $$ -> children.push_back($2);
  }
  ;

/*
 * This is a high-level symbol used to represent an individual statement.
 */
statement
  : assign_statement { $$ = $1; }
  | if_statement { $$ = $1; }
  | while_statement { $$ = $1; }
  | break_statement { $$ = $1; }
  ;

/*
 * A primary expression is a "building block" of an expression.
 */
primary_expression
  : IDENTIFIER 
  { 
    string* type = new string("IDENTIFIER");
    string* val = new string(*$1);
		$$ = new Node(type, val);
  }
  | FLOAT 
  { 
    string* type = new string("FLOAT");
    string* val = new string(*$1);
		$$ = new Node(type, val);
  }
  | INTEGER 
  { 
    string* type = new string("INTEGER");
    string* val = new string(*$1);
		$$ = new Node(type, val);
  }
  | BOOLEAN 
  {
    if (*$1 == "True") {
      string* type = new string("Boolean");
      string* val = new string("True");
		  $$ = new Node(type, val);
    }
    else if (*$1 == "False") {
      string* type = new string("Boolean");
      string* val = new string("False");
      $$ = new Node(type, val);
    }
  }
  | LPAREN expression RPAREN 
  { 
    $$ = $2;
  }

  ;

/*
 * Symbol representing a boolean "not" operation.
 */
negated_expression
  : NOT primary_expression 
  { 
  }
  ;

/*
 * Symbol representing algebraic expressions.  For most forms of algebraic
 * expression, we generate a translated string that simply concatenates the
 * C++ translations of the operands with the C++ translation of the operator.
 */
expression
  : primary_expression { $$ = $1; }
  | negated_expression { $$ = $1; }
  | expression PLUS expression 
    { 
        string* type = new string("Plus");
        string* val = new string("");
        struct Node* node = new Node(type, val);

        node -> children.push_back($1);
        node -> children.push_back($3);
        $$ = node;

    }
  | expression MINUS expression 
  { 
        string* type = new string("Minus");
        string* val = new string("");
        struct Node* node = new Node(type, val);
        node -> children.push_back($1);
        node -> children.push_back($3);
        $$ = node;
  }
  | expression TIMES expression 
  {   
        string* type = new string("Times");
        string* val = new string("");
        struct Node* node = new Node(type, val);
        node -> children.push_back($1);
        node -> children.push_back($3);
        $$ = node;
   }
  | expression DIVIDEDBY expression 
  { 
        string* type = new string("DIVIDEDBY");
        string* val = new string("");
        struct Node* node = new Node(type, val);
        node -> children.push_back($1);
        node -> children.push_back($3);
        $$ = node;
  }
  | expression EQ expression   
  { 
        string* type = new string("EQ");
        string* val = new string("");
        struct Node* node = new Node(type, val);
        node -> children.push_back($1);
        node -> children.push_back($3);
        $$ = node;
  }
  | expression NEQ expression 
  {
        string* type = new string("NEQ");
        string* val = new string("");
        struct Node* node = new Node(type, val);
        node -> children.push_back($1);
        node -> children.push_back($3);
        $$ = node;
  }
  | expression GT expression 
  { 
        string* type = new string("GT");
        string* val = new string("");
        struct Node* node = new Node(type, val);
        node -> children.push_back($1);
        node -> children.push_back($3);
        $$ = node;
  }
  | expression GTE expression
  { 
        string* type = new string("GTE");
        string* val = new string("");
        struct Node* node = new Node(type, val);
        node -> children.push_back($1);
        node -> children.push_back($3);
        $$ = node;
  } 
  | expression LT expression
    { 
        string* type = new string("LT");
        string* val = new string("");
        struct Node* node = new Node(type, val);
        node -> children.push_back($1);
        node -> children.push_back($3);
        $$ = node;
  }
  | expression LTE expression
    { 
        string* type = new string("LTE");
        string* val = new string("");
        struct Node* node = new Node(type, val);
        node -> children.push_back($1);
        node -> children.push_back($3);
        $$ = node;
  }
  ;

/*
 * This symbol represents an assignment statement.  For each assignment
 * statement, we first make sure to insert the LHS identifier into the symbol
 * table, since it is potentially a new symbol.  Then, we generate a C++
 * translation for the whole assignment by combining the C++ translations of
 * the LHS and the RHS along with an equals sign and a semi-colon, to make sure
 * we have proper C++ punctuation.
 */
 
assign_statement
  : IDENTIFIER ASSIGN expression NEWLINE
  {
        string* type = new string("Identifier");
        string* val = new string(*$1);
        struct Node* node = new Node(type, val);
        
        string* type2 = new string("Assignment");
        string* val2 = new string("");
        struct Node* assignment = new Node(type2,val2);

        assignment->children.push_back(node);
        assignment->children.push_back($3);
        $$ = assignment;
  }
  ;

/*
 * A `block` represents the collection of statements associated with an
 * if, elif, else, or while statement.  The C++ translation for a block of
 * statements is wrapped in curly braces ({}) instead of INDENT and DEDENT.
 */
block
  : INDENT statements DEDENT 
  { 
    string* type = new string("BLOCK");
    string* val = new string("");
    struct Node* node = new Node(type, val);
    node->children.push_back($2);
    $$ = node;
  }
  ;

/*
 * This symbol represents a boolean condition, used with an if, elif, or while.
 * The C++ translation of a condition concatenates the C++ translations of its
 * operators with one of the C++ boolean operators && or ||.
 */
condition
  : expression { $$ = $1; }
  | condition AND condition 
  { 
    string* type = new string("AND");
    string* val = new string("");
    struct Node* node = new Node(type, val);
    node->children.push_back($1);
    node->children.push_back($3);
    $$ = node;
  }
  | condition OR condition 
  {
    string* type = new string("OR");
    string* val = new string("");
    struct Node* node = new Node(type, val);
    node->children.push_back($1);
    node->children.push_back($3);
    $$ = node;
  }
  ;

/*
 * This symbol represents an entire if statement, including optional elif
 * blocks and an optional else block.  The C++ translations for the blocks
 * are simply combined here into one larger translation, and the if condition
 * is wrapped in parentheses, as is required in C++.
 */
if_statement
  : IF condition COLON NEWLINE block elif_blocks else_block 
  { 
    string* type = new string("If");
    string* val = new string("");
    struct Node* node = new Node(type,val);
    node->children.push_back($2);
    node->children.push_back($5);
    if($6) {
      node->children.push_back($6);
    }
    if($7) {
      node->children.push_back($7);
    }
    $$ = node;
  }
  ;

/*
 * This symbol represents zero or more elif blocks to be attached to an if
 * statement.  When a new elif block is recognized, the Pythonic "elif" is
 * translated to the C++ "else if", and the condition is wrapped in parens.
 */
elif_blocks
  : %empty { $$ = NULL; }
  | elif_blocks ELIF condition COLON NEWLINE block  
  {
    if($1) {
      string* type = new string("Else If");
      string* val = new string("");
      struct Node* node = new Node(type,val);
      node->children.push_back($3);
      node->children.push_back($6);
      node->children.push_back($1);
      $$ = node;
    } else {
      string* type = new string("Else if");
      string* val = new string("");
      struct Node* node = new Node(type,val);
      node->children.push_back($3);
      node->children.push_back($6);
      $$ = node;
    }
  }
  ;

/*
 * This symbol represents an if statement's optional else block.
 */
else_block
  : %empty { $$ = NULL; }
  | ELSE COLON NEWLINE block 
  {   
    $$ = $4;
  }


/*
 * This symbol represents a while statement.  The C++ translation wraps the
 * while condition in parentheses.
 */
while_statement
  : WHILE condition COLON NEWLINE block 
  { 
    string* type = new string("While");
    string* val = new string("");
    struct Node* node = new Node(type,val);
    node->children.push_back($2);
    node->children.push_back($5);
    $$ = node;
  }
  ;

/*
 * This symbol represents a break statement.  The C++ translation simply adds
 * a semicolon.
 */
break_statement
  : BREAK NEWLINE 
  { 
    string* type = new string("BREAK");
    string* val = new string("");
    struct Node* node = new Node(type,val);
    $$ = node;
  }
  ;

%%

/*
 * This is our simple error reporting function.  It prints the line number
 * and text of each error.
 */
void yyerror(YYLTYPE* loc, const char* err) {
  cerr << "Error (line " << loc->first_line << "): " << err << endl;
}

/*
 * This function translates a Python boolean value into the corresponding
 * C++ boolean value.
 */
string* translate_boolean_str(string* boolean_str) {
  if (*boolean_str == "True") {
    return new string("true");
  } else {
    return new string("false");
  }
}
