%{
/* Declarations */

#include <stdio.h>
#include <string.h>
// #include "defn.h"

typedef struct MarkerrupleType {
	char* op;
	char* arg1;
	char* arg2;
	char* result;
} Quadruples;

typedef struct BoolType {
	int* trueList;
	int* falseList;
} Bool;

typedef struct StatementType {
	int* nextList;
} Statement;

typedef struct MarkerType {
	int value;
} Marker;

struct SymbolTable
{
	char* id;
	char* type;
}SymbolTable[10000];

int symTableCount=0;

int errFlag = 0;
int QuadruplesIndex = 0;
Quadruples code[100];

extern int yylineno;
void yyerror (char *s);
int yylex();

void showTable();
void createTable();
void showList(int* list);
int* createList(int n);

void codeGenerate(char* op, char* arg1, char* arg2, char* result);
void backpatcher(int* list, int value);
int* mergeLists(int* list1, int* list2);
void storeSymTable(char* id,char* type);
void checkSymTable(char* id);
void showSymTable();

%}

%union {int number; char string[10]; void* pointer;}
%token ASSIGN IF WHILE DO FOR AND OR
%token <string> TYPE ID NUMBER RELOP OP
%type <string> term
%type <pointer> B statement list M N expression

%%
/* Rules */

list	:	statement
			{
				Statement* L = (Statement*)malloc(sizeof(Statement));
				Statement* S = (Statement*)($1);
				L->nextList = S->nextList;
				
				$$ = (void*)L;
			}
	| statement M list
			{
				Statement* L = (Statement*)malloc(sizeof(Statement));
				Statement* S = (Statement*)$1;
				Marker* M = (Marker*)$2;

				backpatcher(S->nextList,M->value);
				L->nextList = S->nextList;
				
				$$ = (void*)L;
			}
	;
	
M	:	/* empty */ 
		{
			Marker* M = (Marker*)malloc(sizeof(Marker));
			M->value = QuadruplesIndex;
			$$ = (void*)M;
		}

N : /* empty */
		{		
			// This is for the case when S1 is a single statement
			Statement* N = (Statement*)malloc(sizeof(Statement));
			N->nextList = createList(QuadruplesIndex);
			codeGenerate("goto", "-", "~", "~");
			$$ = (void*)N;
		}

statement
	:	declaration ';'
			{
				Statement* S = (Statement*)malloc(sizeof(Statement));
				S->nextList = createList(-1);
				
				$$ = (void*)S;
			}
	|	expression ';'
			{
				Statement* S = (Statement*)(malloc(sizeof(Statement)));
				Statement* E = (Statement*)($1);
				S->nextList = E->nextList;
				
				$$ = (void*)S;
			}
	| WHILE '(' M B ')' M '{' list '}'
			{
				Statement* S = (Statement*)malloc(sizeof(Statement));

				Statement* list = (Statement*)($8);
				Bool* B = (Bool*)($4);
				Marker* M1 = (Marker*)($3);
				Marker* M2 = (Marker*)($6);

				backpatcher(B->trueList, M2->value);
				backpatcher(list->nextList, M1->value);
				S->nextList = B->falseList;

				// Case : S1 is single statement
				char valueStr[30];
				sprintf(valueStr, "%d", M1->value);
				codeGenerate("goto", valueStr, "~", "~");

				$$ = (void*)S;
			}
	| DO M '{' list '}' N WHILE '(' M B ')' ';'
			{
				Statement* S = (Statement*)malloc(sizeof(Statement));
				Statement* list = (Statement*)($4);
				Statement* N = (Statement*)($6);
				Bool* B = (Bool*)($10);
				Marker* M1 = (Marker*)($2);
				Marker* M2 = (Marker*)($9);

				backpatcher(N->nextList, M2->value);
				backpatcher(list->nextList, M2->value);
				backpatcher(B->trueList, M1->value);
				S->nextList = B->falseList;

				$$ = (void*)S;
			}
	| FOR '(' expression ';' M B ';' M expression N ')' M '{' list '}'
			{
				Statement* tempS = (Statement*)malloc(sizeof(Statement));
				Statement* tempS1 = (Statement*)($14);
				Statement* tempE1 = (Statement*)($3);
				Statement* tempE2 = (Statement*)($9);
				Statement* tempN = (Statement*)($10);
				Bool* tempB = (Bool*)($6);
				Marker* tempM1 = (Marker*)($5);
				Marker* tempM2 = (Marker*)($8);
				Marker* tempM3 = (Marker*)($12);

				backpatcher(tempE1->nextList, tempM1->value);
				backpatcher(tempB->trueList, tempM3->value);
				backpatcher(tempS1->nextList, tempM2->value);

				// Case : S1 is single statement
				char valueStr[30];
				sprintf(valueStr, "%d", tempM2->value);
				codeGenerate("goto", valueStr, "~", "~"); // After S1, we need to goto E2				
				
				backpatcher(tempE2->nextList, tempM1->value);	// After S2, we need to goto C
				backpatcher(tempN->nextList, tempM1->value);
				tempS->nextList = tempB->falseList;

				$$ = (void*)tempS;
			}
	|	declaration
		{
			Statement* S = (Statement*)malloc(sizeof(Statement));
			S->nextList = createList(-1);
			
			$$ = (void*)S;
			yyerror ("Expected ';' after statement");
		}
	| expression
		{
			Statement* S = (Statement*)malloc(sizeof(Statement));
			S->nextList = createList(-1);
			
			$$ = (void*)S;
			yyerror ("Expected ';' after statement");
		}
	;

B : term RELOP term
	{
		Bool* b = (Bool*)malloc(sizeof(Bool));
		char condition[30];
		condition[0] = '\0';
		strcat(condition, $1);
		strcat(condition, $2);
		strcat(condition, $3);

		b->trueList = createList(QuadruplesIndex);

		// if a RELOP b goto loc
		codeGenerate("if : goto", condition, "-", "~");

		b->falseList = createList(QuadruplesIndex);

		codeGenerate("goto", "-", "~" ,"~");

		$$ = (void*)b;
		condition[0] = '\0';
	}
	| '(' B ')' OR M '(' B ')'
	{
		Bool* b = (Bool*)malloc(sizeof(Bool));
		Bool* b1 = (Bool*)$2;
		Bool* b2 = (Bool*)$7;
		Marker* tempM1 = (Marker*)($5);

		b->trueList = mergeLists(b1->trueList, b2->trueList);
		b->falseList = b2->falseList;
		backpatcher(b1->falseList, tempM1->value);

		$$ = (void*)b;
	}
	| '(' B ')' AND M '(' B ')'
	{
		Bool* b = (Bool*)malloc(sizeof(Bool));
		Bool* b1 = (Bool*)$2;
		Bool* b2 = (Bool*)$7;
		Marker* tempM1 = (Marker*)($5);

		b->trueList = b2->trueList;
		b->falseList = mergeLists(b1->falseList, b2->falseList);
		
		backpatcher(b1->trueList, tempM1->value);

		$$ = (void*)b;
	}
	;

expression	:	ID ASSIGN term OP term
			{
				checkSymTable($1);
				Statement* E = (Statement*)malloc(sizeof(Statement));
				E->nextList = createList(-1);
				
				$$ = (void*)E;
				codeGenerate($4, $3, $5, $1);
			}
	|	ID ASSIGN term
			{
				checkSymTable($1);
				Statement* E = (Statement*)malloc(sizeof(Statement));
				E->nextList = createList(-1);
				
				$$ = (void*)E;
				codeGenerate("=", $3, "~", $1);
			}

term	:	ID {checkSymTable($1);};
	|	NUMBER 
	;

declaration	:	TYPE ID
			{
				storeSymTable($2,$1);
				//showSymTable();
				//printf("%s : %s\n", $2, $1);
			}
	;


%%
/* User Subroutines */

int main() {
	createTable();
	yyparse();

	showSymTable();
	if(!errFlag)
	{
		
		showTable();
	}
	return 0;
}

void createTable() {
	code[QuadruplesIndex].op = NULL;
}

int* createList(int loc) {
	int* list = (int*)malloc(sizeof(int)*100);
	list[0] = loc;
	list[1] = -1;
	return list;
}

void codeGenerate(char* op, char* arg1, char* arg2, char* result) {
	code[QuadruplesIndex].op = (op != NULL ? strdup(op) : NULL);
	code[QuadruplesIndex].arg1 = (arg1 != NULL ? strdup(arg1) : NULL);
	code[QuadruplesIndex].arg2 = (arg2 != NULL ? strdup(arg2) : NULL);
	code[QuadruplesIndex].result = (result != NULL ? strdup(result) : NULL);

	QuadruplesIndex++;
	code[QuadruplesIndex].op = NULL;
}

void storeSymTable(char* id, char* type){
	int flag=0;
	for(int i=0;i<symTableCount;i++){
		if(strcmp(SymbolTable[i].id,id)==0){
			flag=1;
		}
	}
	if(flag==0){
	SymbolTable[symTableCount].id = strdup(id);
	SymbolTable[symTableCount].type = strdup(type);
	symTableCount++;
	}
}

void checkSymTable(char* id){
	int flag=0;
	for(int i=0;i<symTableCount;i++){
		if(strcmp(SymbolTable[i].id,id)==0){
			flag=1;
		}
	}
	if(flag==0) {
		yyerror(" Variable not declared");
	}
}

void showSymTable(){
	for(int i=0;i<symTableCount;i++){
		printf("%s : %s\n",SymbolTable[i].id,SymbolTable[i].type);
	}
}

void showTable() {
	int i;
	printf("CODE_INDEX\tOP\t\tARG1\t\tARG2\t\tRESULT\n");
	printf("**************************************************************************************************************************************************\n");
	for(i=0; i < QuadruplesIndex; i++) {
		if(strcmp(code[i].op, "goto") == 0 ) {
			if(strcmp(code[i].arg1,"-")!=0) {
			printf("\033[0;31m"); 
			printf("%d\t\t%s\t\t%s\t\t%s\t\t%s\n", i, code[i].op, code[i].arg1, code[i].arg2, code[i].result);
			printf("\033[0m");
			}
		}
		else if(strcmp(code[i].op, "if : goto") == 0){
			printf("\033[0;31m"); 
			printf("%d\t\t%s\t%s\t\t%s\t\t%s\n", i, code[i].op, code[i].arg1, code[i].arg2, code[i].result);
			printf("\033[0m");
		} else {
			printf("%d\t\t%s\t\t%s\t\t%s\t\t%s\n", i, code[i].op, code[i].arg1, code[i].arg2, code[i].result);
		}
		//printf("%d\t\t%s\t\t%s\t\t%s\t\t%s\n", i, code[i].op, code[i].arg1, code[i].arg2, code[i].result);
	}
}

void backpatcher(int* list, int value) {
	int i=0;
	while(list[i] != -1) {
		if( strcmp(code[list[i]].op, "if : goto") == 0 ) {
			sprintf(code[list[i]].arg2, "%d", value);
		}
		else if( strcmp(code[list[i]].op, "goto") == 0 ) {
			sprintf(code[list[i]].arg1, "%d", value);
		}
		i++;
	}
}

int* mergeLists(int* list1, int* list2) {
	int* newList = createList(-1);
	int i=0, j=0;
	while(list1[j] != -1) {
		newList[i] = list1[j];
		i++;
		j++;
	}

	j=0;
	while(list2[j] != -1) {
		newList[i] = list2[j];
		i++;
		j++;
	}

	newList[i] = -1;
	return newList;
}


void yyerror (char *s) {
	errFlag = 1;
	fprintf (stderr, "%s in line no. %d\n", s, yylineno);
}

