%{
/* Definitions */
#include "y.tab.h"
#include <string.h>

%}
%option yylineno

%%
	/* Rules */

"char"						{strcpy(yylval.string, "char"); return TYPE;}
"float"						{strcpy(yylval.string, "float"); return TYPE;}
"int"						{strcpy(yylval.string, "int"); return TYPE;}
"for"						{return FOR;}
"do"						{return DO;}
"while"						{return WHILE;}
"if"						{return IF;}
"||"						{return OR;}
"&&"						{return AND;}
"=="              			{strcpy(yylval.string, "=="); return RELOP;}
">="						{strcpy(yylval.string, ">="); return RELOP;}
"<="						{strcpy(yylval.string, "<="); return RELOP;}
"!="						{strcpy(yylval.string, "!="); return RELOP;}
[<>]						{strcpy(yylval.string, yytext); return RELOP;}
"="							{strcpy(yylval.string, "="); return ASSIGN;}
[;\(\)\{\}]      			return yytext[0];
[-+*/\^]					{strcpy(yylval.string, yytext); return OP;}
[a-zA-Z][a-zA-Z0-9_]*      	{strcpy(yylval.string, yytext); return ID;}
[0-9]+(\.[0-9]+)?          	{strcpy(yylval.string, yytext); return NUMBER;}
[ \t\n]           			;
.                 			printf("Unexpected character\n");

%%
/* User Subroutines */

int yywrap (void) {return 1;}
