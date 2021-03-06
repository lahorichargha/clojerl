-module(clj_multimethod).

-include("clojerl.hrl").

-export([ init/1
        , is_init/1
        , dispatch_map_var/1
        , get_method/2
        , get_method/4
        , get_method_table/1
        , add_method/3
        , remove_all/1
        , remove_method/2
        ]).

%%------------------------------------------------------------------------------
%% API
%%------------------------------------------------------------------------------

-spec init('clojerl.Symbol':type()) -> ?NIL.
init(MultiFnSym) ->
  DispatchMapVar = dispatch_map_var(MultiFnSym),
  EmptyMap       = 'clojerl.Map':?CONSTRUCTOR([]),
  ok             = generate_dispatch_map(DispatchMapVar, EmptyMap),
  ?NIL.

-spec is_init('clojerl.Symbol':type()) -> boolean().
is_init(MultiFnSym) ->
  case 'clojerl.Namespace':find_var(MultiFnSym) of
    ?NIL -> false;
    Var  -> clj_rt:get('clojerl.Var':meta(Var), 'multi-method')
  end.

-spec get_method('clojerl.Var':type(), any()) -> any().
get_method(Var, Value) ->
  get_method(Var, Value, default, ?NIL).

-spec get_method('clojerl.Var':type(), any(), any(), map() | ?NIL) -> any().
get_method(MultiFnVar, Value, Default, _Hierarchy) ->
  Map = dispatch_map(MultiFnVar),
  case clj_rt:get(Map, Value) of
    ?NIL -> clj_rt:get(Map, Default);
    X -> X
  end.

-spec get_method_table('clojerl.Var':type()) -> any().
get_method_table(MultiFnVar) ->
  dispatch_map(MultiFnVar).

-spec add_method('clojerl.Var':type(), any(), any()) -> 'clojerl.Var':type().
add_method(MultiFnVar, DispatchValue, Method0) ->
  Assoc  = fun clj_rt:assoc/3,
  %% When Method is a var we need to make sure it's not
  %% marked as a fake function.
  Method = case clj_rt:'var?'(Method0) of
             true  -> 'clojerl.Var':fake_fun(Method0, false);
             false -> Method0
           end,
  Args   = [DispatchValue, Method],
  update_dispatch_map(MultiFnVar, Assoc, Args).

-spec remove_all('clojerl.Var':type()) -> 'clojerl.Var':type().
remove_all(MultiFnVar) ->
  Fun    = fun(_) -> clj_rt:hash_map([]) end,
  update_dispatch_map(MultiFnVar, Fun, []).

-spec remove_method('clojerl.Var':type(), any()) -> 'clojerl.Var':type().
remove_method(MultiFnVar, DispatchValue) ->
  Dissoc = fun clj_rt:dissoc/2,
  update_dispatch_map(MultiFnVar, Dissoc, [DispatchValue]).

%%------------------------------------------------------------------------------
%% Internal functions
%%------------------------------------------------------------------------------

-spec dispatch_map_var('clojerl.INamed':type()) -> 'clojerl.Var':type().
dispatch_map_var(VarOrSymbol) ->
  Ns      = case clj_rt:namespace(VarOrSymbol) of
              ?NIL ->
                CurrentNs = 'clojerl.Namespace':current(),
                'clojerl.Namespace':str(CurrentNs);
              X -> X
            end,
  Name    = clj_rt:name(VarOrSymbol),
  MapNs   = <<Ns/binary, ".", Name/binary, "__dispatch__">>,
  MapName = <<"map">>,
  'clojerl.Var':?CONSTRUCTOR(MapNs, MapName).

-spec update_dispatch_map('clojerl.Var':type(), function(), [any()]) -> any().
update_dispatch_map(MultiFnVar, Fun, Args) ->
  DispatchMapVar = dispatch_map_var(MultiFnVar),
  Map0           = 'clojerl.Var':deref(DispatchMapVar),
  Map            = apply(Fun, [Map0 | Args]),
  ok             = generate_dispatch_map(DispatchMapVar, Map),

  MultiFnVar.

-spec dispatch_map('clojerl.Var':type()) -> any().
dispatch_map(MultiFnVar) ->
  'clojerl.Var':deref(dispatch_map_var(MultiFnVar)).

-spec generate_dispatch_map('clojerl.Var':type(), any()) -> ok.
generate_dispatch_map(DispatchMapVar, Map) ->
  Module = 'clojerl.Var':module(DispatchMapVar),
  clj_module:ensure_loaded(<<>>, Module),

  ValName   = 'clojerl.Var':val_function(DispatchMapVar),
  ValAst    = cerl:abstract(Map),
  ValFunAst = clj_emitter:function_form(ValName, [], [], ValAst),

  clj_module:add_mappings([DispatchMapVar], Module),
  clj_module:add_functions([ValFunAst], Module),
  clj_module:add_exports([{ValName, 0}], Module),

  CljModule = clj_module:get_module(Module),
  clj_compiler:module(CljModule),

  ok.
