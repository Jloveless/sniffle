-module(sniffle_dtrace).

-include("sniffle.hrl").

-export(
   [
    get/1,
    add/2,
    set/2,
    set/3,
    list/0,
    list/2,
    delete/1
   ]
  ).

-ignore_xref(
   [
    get/1,
    add/2,
    set/2,
    set/3,
    list/0,
    list/2,
    delete/1
   ]
  ).

-spec add(Name::binary(),
          Script::string()) ->
                 {ok, UUID::fifo:dtrace_id()} | {error, timeout}.
add(Name, Script) ->
    UUID = list_to_binary(uuid:to_string(uuid:uuid4())),
    do_write(UUID, create, [Name, Script]),
    {ok, UUID}.

-spec get(UUID::fifo:dtrace_id()) ->
                 not_found | {ok, DTrance::fifo:object()} | {error, timeout}.
get(UUID) ->
    sniffle_entity_read_fsm:start(
      {sniffle_dtrace_vnode, sniffle_dtrace},
      get, UUID
     ).

-spec delete(UUID::fifo:dtrace_id()) ->
                    not_found | {error, timeout} | ok.
delete(UUID) ->
    do_write(UUID, delete).

-spec list() ->
                  {ok, [UUID::fifo:dtrace_id()]} | {error, timeout}.
list() ->
    sniffle_coverage:start(
      sniffle_dtrace_vnode_master, sniffle_dtrace,
      list).

%%--------------------------------------------------------------------
%% @doc Lists all vm's and fiters by a given matcher set.
%% @end
%%--------------------------------------------------------------------
-spec list([fifo:matcher()], boolean()) -> {error, timeout} | {ok, [fifo:uuid()]}.

list(Requirements, true) ->
    {ok, Res} = sniffle_full_coverage:start(
                  sniffle_dtrace_vnode_master, sniffle_dtrace,
                  {list, Requirements, true}),
    Res1 = rankmatcher:apply_scales(Res),
    {ok,  lists:sort(Res1)};

list(Requirements, false) ->
    {ok, Res} = sniffle_coverage:start(
                  sniffle_dtrace_vnode_master, sniffle_dtrace,
                  {list, Requirements}),
    Res1 = rankmatcher:apply_scales(Res),
    {ok,  lists:sort(Res1)}.


-spec set(UUID::fifo:dtrace_id(),
          Attribute::fifo:keys(),
          Value::fifo:value()) ->
                 ok | {error, timeout}.
set(UUID, Attribute, Value) ->
    do_write(UUID, set, [{Attribute, Value}]).

-spec set(UUID::fifo:dtrace_id(),
          Attributes::fifo:attr_list()) ->
                 ok | {error, timeout}.
set(UUID, Attributes) ->
    do_write(UUID, set, Attributes).

%%%===================================================================
%%% Internal Functions
%%%===================================================================

-spec do_write(VM::fifo:uuid(), Op::atom()) -> not_found | ok.
do_write(VM, Op) ->
    sniffle_entity_write_fsm:write({sniffle_dtrace_vnode, sniffle_dtrace}, VM, Op).

-spec do_write(VM::fifo:uuid(), Op::atom(), Val::term()) -> not_found | ok.
do_write(VM, Op, Val) ->
    sniffle_entity_write_fsm:write({sniffle_dtrace_vnode, sniffle_dtrace}, VM, Op, Val).
