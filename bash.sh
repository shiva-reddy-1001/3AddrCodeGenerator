
yacc -d CodeGenerator.y
if (($? == 0))
then
	lex CodeGenerator.l y.tab.h
fi

if (($? == 0))
then
	gcc lex.yy.c y.tab.c
fi
echo "Done Compiling"
