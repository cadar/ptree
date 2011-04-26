-module(t).
-compile(export_all).
-define(PrevA10,Prev,Next,A0,A1,A2,A3,A4,A5).
-define(A0toBin,A0,A1,A2,A3,A4,A5,Bin).
ran()-> integer_to_list(random:uniform(1000000)).
start0() -> 
    sl(1000),
    log(start),
    L=ran_list(1000000),
    catch register(head,new([])),
    lists:map(fun(X)-> add({X,list_to_binary(X)},head) end, L),
    sl(1000),
    Add=now(),
    lists:map(fun(X)-> find(X) end, L),
    R=lists:foldr(fun(_,A)-> case recok() of
                                 ok -> A;
                                 D-> [D|A] end end, [],L),
    Find=now(),
    log({find,timer:now_diff(Find,Add)/1000/1000,sec}),
    log({result,R}),
    log(done),L.
start()-> 
    log(start),
    catch register(head,new([])),
    log({head,whereis(head)}),
    add({"0",test0},head),
    sl(100),
    add({"1",test1},head),
    sl(3000),log('----'),
    head!all,
    sl(3000),log('----'),
    add({"2",test2},head),
    sl(3000),log('----'),
    head!all,
    log(stop).
    
%% API
add(Word,Index) -> whereis(Index)!{add,Word}.
find(Word) -> head!{find,Word,self()}.
rec() -> receive Res -> io:format("res:~p~n",[Res]) end.
recok() -> receive {found,_} -> ok; D->D end.
%% Internals
new(Nodes) -> spawn(fun()-> tnode(Nodes,no_prev,no_next,nil,nil,nil,nil,nil,nil,nil) end).
next(Key,Word,Me) -> case Key of
                         nil -> Me!{nohit,Word};
                         Nex -> Nex!{find,tl(Word),Me}
                     end.
tnode(Nodes,?PrevA10,Bin) -> 
    receive
        all -> log({Nodes,prev,Prev,next,Next,0,A0,1,A1,2,A2,3,A3,Bin}),
               case Next of 
                   no_next -> ok;
                   _ -> Next!all
               end,
               tnode(Nodes,?PrevA10,Bin);
        {find,[],Me} -> case Bin of nil -> Me!{nohit,Bin}; _ -> Me!{found,Bin} end;
        {find,Word,Me} -> 
            Key = hd(Word),
            case Key of 
                $1 -> next(A1,Word,Me);
                $2 -> next(A2,Word,Me);
                $3 -> next(A3,Word,Me);
                $4 -> next(A4,Word,Me);
                $5 -> next(A5,Word,Me);
                _ -> case proplists:lookup(Key,Nodes) of
                         {_,Nex} -> Nex!{find,tl(Word),Me};
                         none    -> Me!{nohit,Word}
                     end
            end,
            tnode(Nodes,?PrevA10,Bin);
        {add,{[],SetBin}} -> log({set,SetBin,nodes,Nodes}),
                             tnode(Nodes,?PrevA10,SetBin);
        {add,{Word,PassBin}} ->	
            Key=hd(Word),Rest=tl(Word),
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
                _ -> case proplists:lookup(Key,Nodes) of
                         none  -> tnode([{Key,nadd(Rest,PassBin)}|Nodes],?PrevA10,Bin);	
                         {_,N} -> N!{add,{Rest,PassBin}},tnode(Nodes,?PrevA10,Bin)	
                     end
            end;
        {init_new,NewPrev} -> log({init_new,prev,NewPrev}),
                              catch NewPrev!{set2_next,self()},
                              tnode(Nodes,NewPrev,Next,?A0toBin);
        {set2_next,New}    -> log({set2_next_on_prev,next,New,is_new_node,Nodes}),
                              catch Next!{set3_prev,New},
                              tnode(Nodes,Prev,New,?A0toBin);	
        {set3_prev,New}    -> log({set3_prev,prev,New,jump_over_set_prev}),
                              tnode(Nodes,New,Next,?A0toBin)
    end.
ainit(nil,Key,Nodes,Res,PassBin) -> 
    P=prev(Key,Nodes),
    New=nadd(Res,PassBin),
    log({ainit,{key,Key,nodes,Nodes,p,P},Res}),
    New!{init_new,P},
    New;
ainit(Nex,_,_,Res,PassBin) -> Nex!{add,{Res,PassBin}},loop.
nadd(Res,Bin) -> New=new([]),New!{add,{Res,Bin}},New.

%% fix this! if smallest reeturn self. search for pos, return one before.
prev(_,[])                  -> self();
prev(_,[{_,P}])             -> P;
prev(A,[{_,P},{A,_}])       -> P;
prev(_,[{_,_},{_,P}])       -> P;
prev(A,[{_,P},{A,_}|_])     -> P;
prev(A,[{_,_},{B,P}|Nodes]) -> prev(A,[{B,P}|Nodes]).


a(New,Nodes) -> a(New,Nodes,[]).
a({Key,New},[],Acc)                          -> lists:reverse(Acc)++[{Key,New}];
a({Key,New},[{Key,_}|Nodes],Acc)             -> lists:reverse(Acc)++[{Key,New}|Nodes];
a({Key,New},[{H,P}|Nodes],Acc) when Key >= H -> a({Key,New},Nodes,[{H,P}|Acc]);
a({Key,New},Nodes,Acc)                       -> lists:reverse(Acc)++[{Key,New}|Nodes].

pdel(Key,N)->proplists:delete(Key,N).
ran_list(N)-> lists:foldr(fun(_X,A) -> [ran()|A] end,[],lists:seq(1,N)).
sl(Ms)->timer:sleep(Ms).
log(Msg) -> sl(100),io:format("~p:~p~n",[self(),Msg]),Msg.

test()->[t:prev(s,[{a,a},{s,s}]),
         t:prev(s,[{a,a},{s,s},{b,b}]),
         t:prev(s,[{a,a},{b,b},{s,s}]),
         t:prev(s,[{a,a},{b,b},{c,c},{s,s}]),
         t:prev(s,[{s,s},{b,b}]),
         t:prev(s,[{s,s}]),
         t:prev(s,[{a,a}]),
         t:prev(s,[])].
