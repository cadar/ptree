-module(t).
-compile(export_all).
-include_lib("eunit/include/eunit.hrl").
-define(PrevA10,Prev,Next,A0,A1,A2,A3,A4,A5).
-define(A0toBin,A0,A1,A2,A3,A4,A5,Bin).
ran()-> integer_to_list(random:uniform(1000000)).
start1() -> 
    log(start),
%    L1=ran_list(100000),
    Num = lists:reverse(lists:seq(1,10)),
%    Num = lists:seq(1,10),
    L=lists:map(fun(Z) -> integer_to_list(Z) end,Num),
    catch register(head,new([])),
    lists:map(fun(X)-> add({X,list_to_binary(X)},head) end, L),
    sl(1000),
    Add=now(),
    lists:map(fun(X)-> find(X) end, L),
    R=lists:foldr(fun(_,A)-> case recok() of
                                 ok -> A;
                                 D-> [D|A] end end, [],L),
    Find=now(),
    log({seconds,timer:now_diff(Find,Add)/1000/1000,sec}),
    log({missing,R}),
    list(),
    log(done),L.
start()-> 
    log(start),
    catch register(head,new([])),
    log({head,whereis(head)}),
    lists:map(fun(X)-> add({integer_to_list(X),list_to_binary(integer_to_list(X))},head),sl(1) end, 
              [
               10,2000
              ]),
    list().
list()-> sl(1000),log('--- list ---'),head!all,sl(1000),log('======'),ok.
    

%% API
add(Word,Index) -> whereis(Index)!{add,Word},sl(10).
find(Word) -> head!{find,Word,self()}.
rec() -> receive Res -> io:format("res:~p~n",[Res]) end.
recok() -> receive {found,_} -> ok; D->io:format("res:~p~n",[D]),D end.
%% Internals
new(Nodes) -> spawn(fun()-> tnode(Nodes,no_prev,no_next,nil,nil,nil,nil,nil,nil,nil) end).
tnode(Nodes,?PrevA10,Bin) -> 
    receive
        all -> case Bin of 
                   nil -> io:format("      [~p] ~p ~p~n",[    self(),Prev,Next]);
                   _ ->   io:format("~5.s [~p] ~p ~p~n",[Bin,self(),Prev,Next]) end,
               catch Next!all,
               tnode(Nodes,?PrevA10,Bin);
        {find,[],Me} -> case Bin of nil -> Me!{nohit,Bin}; _ -> Me!{found,Bin} end,
                        tnode(Nodes,?PrevA10,Bin);
        {find,Word,Me} -> 
            Key = hd(Word),
            case Key of 
                $1 -> next(A1,Word,Me);
                $2 -> next(A2,Word,Me);
                $3 -> next(A3,Word,Me);
                _ -> case proplists:lookup(Key,Nodes) of
                         {_,Nex} -> Nex!{find,tl(Word),Me};
                         none    -> Me!{nohit,Word}
                     end
            end,
            tnode(Nodes,?PrevA10,Bin);
        {add,{[],SetBin}} -> tnode(Nodes,?PrevA10,SetBin);
        {add,{Word,PassBin}} ->	
            Key=hd(Word),
            Rest=tl(Word),
            case Key of
                $0 -> case ainit(A0,Key,Nodes,Rest,PassBin) of 
                          loop -> tnode(Nodes,?PrevA10,Bin);	
                          New  -> tnode(a({Key,New},Nodes),Prev,Next,New,A1,A2,A3,A4,A5,Bin) end;
                $1 -> case ainit(A1,Key,Nodes,Rest,PassBin) of 
                          loop -> tnode(Nodes,?PrevA10,Bin);	
                          New  -> tnode(a({Key,New},Nodes),Prev,Next,A0,New,A2,A3,A4,A5,Bin) end;
                $2 -> case ainit(A2,Key,Nodes,Rest,PassBin) of 
                          loop -> tnode(Nodes,?PrevA10,Bin);	
                          New  -> tnode(a({Key,New},Nodes),Prev,Next,A0,A1,New,A3,A4,A5,Bin) end;
                $3 -> case ainit(A3,Key,Nodes,Rest,PassBin) of 
                          loop -> tnode(Nodes,?PrevA10,Bin);	
                          New  -> tnode(a({Key,New},Nodes),Prev,Next,A0,A1,A2,New,A4,A5,Bin) end;
                K -> case ainit(up(K,Nodes),K,Nodes,Rest,PassBin) of 
                          loop -> tnode(Nodes,?PrevA10,Bin);	
                          New  -> tnode(a({K,New},Nodes),Prev,Next,A0,A1,A2,A3,A4,A5,Bin) end
            end;
        {init_new,NewPrev} -> log([new_node,start,looking,for,deepnode,here,NewPrev]),
                              catch NewPrev!{set1_next,self()},
                              tnode(Nodes,NewPrev,Next,?A0toBin);
        {set1_next,New}    -> catch New !{set2_next,Next},
                              tnode(Nodes,Prev,New,?A0toBin);	
        {set2_next,Old}    -> catch Old!{set3_prev,self()},
                              tnode(Nodes,Prev,Old,?A0toBin);
        {set3_prev,New}    -> tnode(Nodes,New,Next,?A0toBin)
    end.
last_pid(Nodes)-> try 
                      {_,Deep} = lists:last(Nodes),
                      Deep
                  catch _:_ -> [] end.
next(Key,Word,Me) -> case Key of
                         nil -> Me!{nohit,Word};
                         Nex -> Nex!{find,tl(Word),Me}
                     end.
up(A,Nodes) -> case proplists:lookup(A,Nodes) of none -> nil; {_,Pid}->Pid end.
ainit(nil,Key,Nodes,PassRest,PassBin) -> 
    log([ainit,Key]),
    Prev=nil_is_self(prev(Key,Nodes)),
    New=new([]),New!{init_new,Prev},
    New!{add,{PassRest,PassBin}},
    New;
ainit(Nex,_,_,Rest,PassBin) ->
    log([afound,Nex]),
    Nex!{add,{Rest,PassBin}},
    loop.
%% -------------------------------------------------------------------------------
nil_is_self([])  -> self();
nil_is_self(Pid) -> Pid. 
prev(_,[])                                                 -> [];
prev(Key,[{Key,_}])                                        -> throw(err_dup1);
prev(Key,[{Key,_}|_])                                      -> throw(err_dup2);
prev(Key,[{First,Pid}])         when First < Key           -> Pid;
prev(Key,[{First,Pid},{N,_}|_]) when First < Key , Key < N -> Pid;
prev(Key,[_|Nodes])                                        -> prev(Key,Nodes).

a(New,Nodes) -> a(New,Nodes,[]).
a({Key,New},[],Acc)                         -> lists:reverse(Acc)++[{Key,New}];
a({Key,New},[{F,N}|Nodes],Acc) when Key < F -> lists:reverse(Acc)++[{Key,New},{F,N}|Nodes];
a({Key,New},[{F,N}|Nodes],Acc)              -> a({Key,New},Nodes,[{F,N}|Acc]).
%% -------------------------------------------------------------------------------
pdel(Key,N)-> proplists:delete(Key,N).
ran_list(N)-> lists:foldr(fun(_X,A) -> [ran()|A] end,[],lists:seq(1,N)).
sl(Ms)->timer:sleep(Ms).
log(Msg) -> io:format("~p:~p~n",[self(),Msg]),Msg.
%% -------------------------------------------------------------------------------
prev_test_()->[
               ?_assert(prev($1,[{$2,pid}]) == []),
               ?_assert(prev($4,[{$3,pid}]) == pid),
               ?_assert(prev($1,[{$2,pid},{$4,d}]) == []),
               ?_assert(prev($3,[{$2,pid},{$4,d}]) == pid),
               ?_assert(prev($3,[{$2,pid},{$4,d},{$5,e}]) == pid),
               ?_assert(prev($5,[{$2,b},{$4,pid}]) == pid),
               ?_assert(prev($5,[{$1,a},{$2,b},{$4,pid},{$6,e}]) == pid),
               ?_assert(prev($5,[{$1,a},{$2,b},{$4,pid},{$6,e},{$7,g}]) == pid),
               ?_assert(prev($5,[{$1,a},{$2,b},{$4,pid}]) == pid),
               ?_assert(prev(s,[]) == []),
               ?_assert(a({$5,b}, [{$4,a}])        == [{$4,a},{$5,b}]),
               ?_assert(a({$3,b}, [{$4,a}])        == [{$3,b},{$4,a}]),
               ?_assert(a({$5,b}, [{$4,a},{$6,c}]) == [{$4,a},{$5,b},{$6,c}]),
               ?_assert(a({$7,b}, [{$4,a},{$6,c}]) == [{$4,a},{$6,c},{$7,b}]),
               ?_assert(a({$1,b}, [{$4,a},{$6,c}]) == [{$1,b},{$4,a},{$6,c}]),
               ?_assert(a({$1,a}, []) == [{$1,a}])
              ].

