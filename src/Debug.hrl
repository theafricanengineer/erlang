-ifdef(show).
    -define(SHOW_EVAL(Expression), Exp = Expression, io:format("SHOW: ~p~n", [Exp]), Exp).
-else.
    -define(SHOW_EVAL(Expression), Expression).
-endif.
