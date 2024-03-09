### TOKENS
```
LETTER : A-Z | a-z -- capital or small letter
DIGIT : 0-9
NAME : LETTER (LETTER | DIGIT)* -- procedure names and variables are strings of letters, and
digits, starting with a letter
INTEGER : DIGIT+ -- constants are sequences of digits
```

### CSG
```
program : procedure+
procedure : ‘procedure’ proc_name ‘{‘ stmtLst ‘}’
stmtLst : stmt+
stmt : call | while | if | assign
call : ‘call’ proc_name ‘;’
while : ‘while’ var_name ‘{‘ stmtLst ‘}’
if : ‘if’ var_name ‘then’ ‘{‘ stmtLst ‘}’ ‘else’ ‘{‘ stmtLst ‘}’
assign : var_name ‘=’ expr ‘;’
expr : expr ‘+’ term | expr ‘-’ term | term
term : term ‘*’ factor | factor
factor : var_name | const_value | ‘(’ expr ‘)’
var_name : NAME
proc_name : NAME
const_value : INTEGER
```