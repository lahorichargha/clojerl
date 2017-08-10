-module('clojerl.TupleChunk').

-include("clojerl.hrl").

-behavior('clojerl.Counted').
-behavior('clojerl.IChunk').
-behavior('clojerl.Indexed').
-behavior('clojerl.IReduce').

-export([?CONSTRUCTOR/1, ?CONSTRUCTOR/2, ?CONSTRUCTOR/3]).

-export([count/1]).
-export([drop_first/1]).
-export([nth/2, nth/3]).
-export([reduce/2, reduce/3]).

-type type() :: #?TYPE{data :: {tuple(), pos_integer()}}.

-spec ?CONSTRUCTOR(tuple()) -> type().
?CONSTRUCTOR(Tuple) when is_tuple(Tuple) ->
  ?CONSTRUCTOR(Tuple, 0).

-spec ?CONSTRUCTOR(tuple(), pos_integer()) -> type().
?CONSTRUCTOR(Tuple, Offset) when is_tuple(Tuple), is_integer(Offset) ->
  ?CONSTRUCTOR(Tuple, Offset, erlang:tuple_size(Tuple)).

-spec ?CONSTRUCTOR(tuple(), pos_integer(), pos_integer()) -> type().
?CONSTRUCTOR(Tuple, Pos, End) when is_tuple(Tuple),
                                   is_integer(Pos),
                                   is_integer(End) ->
  #?TYPE{data = {Tuple, Pos, End}}.

%%------------------------------------------------------------------------------
%% Protocols
%%------------------------------------------------------------------------------

count(#?TYPE{name = ?M, data = {_, Offset, Size}}) ->
  Size - Offset.

drop_first(#?TYPE{name = ?M, data = {Tuple, Offset, Size}}) ->
  #?TYPE{name = ?M, data = {Tuple, Offset + 1, Size}}.

reduce(#?TYPE{name = ?M, data = {Tuple, Offset, Size}}, Fun) ->
  Size  = erlang:tuple_size(Tuple),
  Init  = erlang:element(Offset, Tuple),
  Items = case Offset + 1 < Size of
            true ->
              Indexes = lists:seq(Offset + 1, Size),
              [erlang:element(Index, Tuple)|| Index <- Indexes];
            false ->
              []
          end,
  Apply = fun(Item, Acc) -> clj_rt:apply(Fun, [Acc, Item]) end,
  lists:foldl(Apply, Init, Items).

reduce(#?TYPE{name = ?M, data = {Tuple, Offset, Size}}, Fun, Init) ->
  Size     = erlang:tuple_size(Tuple),
  Items    = [ erlang:element(Index, Tuple)
               || Index <- lists:seq(Offset + 1, Size)
             ],
  ApplyFun = fun(Item, Acc) -> clj_rt:apply(Fun, [Acc, Item]) end,
  lists:foldl(ApplyFun, Init, Items).

nth(#?TYPE{name = ?M, data = {Tuple, Offset, _}}, N) ->
  erlang:element(Offset + N + 1, Tuple).

nth(#?TYPE{name = ?M, data = {_, Offset, Size}} = TupleChunk, N, _Default)
  when N >= 0 andalso N < Size - Offset ->
  nth(TupleChunk, N);
nth(#?TYPE{name = ?M}, _N, Default) ->
  Default.
