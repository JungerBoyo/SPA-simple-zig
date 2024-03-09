### ASG grammar
```
program : procedure+
procedure : stmtLst
stmtLst : stmt+
stmt : assign | call | while | if
assign : variable expr
expr : plus | minus | times | ref
plus : expr expr
minus : expr expr
times : expr expr
ref : variable | constant
while: variable stmtLst
if : variable stmtLst stmtLst
```

### Attributes
```
procedure.procName, call.procName, variable.varName : NAME
constant.value : INTEGER
stmt.stmt# : INTEGER
```