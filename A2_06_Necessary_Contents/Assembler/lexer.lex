%option noyywrap

%{
#include "parser.tab.h"
#include <cstdlib>
%}

%%

\$("zero"|"t0"|"t1"|"t2"|"t3"|"t4") { yylval = std::string(yytext); return REGISTER; }
\$[a-z]+[0-9]* { std::cout << "unrecognized register: " << yytext << std::endl; exit(1); }

"add" { return ADD; }
"addi" { return ADDI; }
"sub" { return SUB; }
"subi" { return SUBI; }
"and" { return AND; }
"andi" { return ANDI; }
"or" { return OR; }
"ori" { return ORI; }
"sll" { return SLL; }
"srl" { return SRL; }
"nor" { return NOR; }
"sw" { return SW; }
"lw" { return LW; }
"beq" { return BEQ; }
"bneq" { return BNEQ; }
"j" { return J; }

"push" { return PUSH; }
"pop" { return POP; }

":" { return COLON; }
"," { return COMMA; }
"(" { return LPAREN; }
")" { return RPAREN; }

[a-zA-Z_][a-zA-Z0-9_]* { yylval = std::string(yytext); return LABEL;}
"-"?[0-9]+ { yylval = yytext[0] == '-'? std::to_string(16 + atoi(yytext)) : std::string(yytext); return INT; }

";".* {}

(\r)?\n {}

. { if (yytext[0] != ' ' && yytext[0] != '\t') std::cout << "unrecognized character: " << yytext << " ASCII value: " << int(yytext[0]) << std::endl; }

%%