-module('clojerl.Indexed').

-clojure(true).
-protocol(true).

-export([nth/2, nth/3]).

-type type() :: any().

-callback nth(A :: type(), K :: any()) -> any().
-callback nth(A :: type(), K :: any(), NotFound :: any()) -> any().

-spec nth(type(), integer()) -> any().
nth(Coll, N) ->
  'clojerl.protocol':resolve(?MODULE, nth, [Coll, N]).

-spec nth(type(), integer(), any()) -> any().
nth(Coll, N, NotFound) ->
  'clojerl.protocol':resolve(?MODULE, nth, [Coll, N, NotFound]).
