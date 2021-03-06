%% @doc Interface for sniffle-admin commands.
-module(sniffle_console_vms).
-export([command/2, help/0]).

-define(F(Hs, Vs), sniffle_console:fields(Hs,Vs)).
-define(H(Hs), sniffle_console:hdr(Hs)).

help() ->
    fmt("Usage~n"
        "  list [-j]~n"
        "  get [-j] <uuid>~n"
        "  logs [-j] <uuid>~n"
        "  snapshots [-j] <uuid>~n"
        "  snapshot <uuid> <comment>~n"
        "  start <uuid>~n"
        "  stop <uuid>~n"
        "  reboot <uuid>~n"
        "  delete <uuid>~n").

command(text, ["start", UUID]) ->
    case sniffle_vm:start(list_to_binary(UUID)) of
        ok ->
            io:format("VM ~s starting.~n", [UUID]),
            ok;
        E ->
            io:format("VM ~s did not start (~p).~n", [UUID, E]),
            ok
    end;

command(text, ["stop", UUID]) ->
    case sniffle_vm:stop(list_to_binary(UUID)) of
        ok ->
            io:format("VM ~s stopping.~n", [UUID]),
            ok;
        E ->
            io:format("VM ~s did not stop (~p).~n", [UUID, E]),
            ok
    end;

command(text, ["reboot", UUID]) ->
    case sniffle_vm:reboot(list_to_binary(UUID)) of
        ok ->
            io:format("VM ~s rebooting.~n", [UUID]),
            ok;
        E ->
            io:format("VM ~s did not reboot (~p).~n", [UUID, E]),
            ok
    end;

command(text, ["delete", UUID]) ->
    case sniffle_vm:delete(list_to_binary(UUID)) of
        ok ->
            io:format("VM ~s deleted.~n", [UUID]),
            ok;
        E ->
            io:format("VM ~s did not delete (~p).~n", [UUID, E]),
            ok
    end;

command(json, ["get", UUID]) ->
    case sniffle_vm:get(list_to_binary(UUID)) of
        {ok, VM} ->
            sniffle_console:pp_json(
              jsxd:thread([{select, [<<"hypervisor">>, <<"state">>]},
                           {merge, jsxd:get(<<"config">>, [], VM)}],
                          VM)),
            ok;
        _ ->
            sniffle_console:pp_json([]),
            ok
    end;

command(text, ["get", UUID]) ->
    H = [{"UUID", 36},
         {"Hypervisor", 17},
         {"Name", 10},
         {"State", -15}],
    ?H(H),
    case sniffle_vm:get(list_to_binary(UUID)) of
        {ok, VM} ->
            ?F(H, [UUID,
                   jsxd:get(<<"hypervisor">>, <<"-">>, VM),
                   jsxd:get(<<"state">>, <<"-">>, VM),
                   jsxd:get(<<"config.alias">>, <<"-">>, VM)]),
            ok;
        _ ->
            ok
    end;

command(json, ["logs", UUID]) ->
    case sniffle_vm:get(list_to_binary(UUID)) of
        {ok, VM} ->
            sniffle_console:pp_json(jsxd:get(<<"log">>, [], VM)),
            ok;
        _ ->
            sniffle_console:pp_json([]),
            ok
    end;

command(text, ["logs", UUID]) ->
    H = [{"Timestamp", 17},
         {"Log", n}],
    ?H(H),
    case sniffle_vm:get(list_to_binary(UUID)) of
        {ok, VM} ->
            lists:map(fun (Log) ->
                              ?F(H, [jsxd:get(<<"date">>, <<"-">>, Log),
                                     jsxd:get(<<"log">>, <<"-">>, Log)])
                      end, jsxd:get(<<"log">>, [], VM)),
            ok;
        _ ->
            ok
    end;


command(text, ["snapshot", UUID | Comment]) ->
    case sniffle_vm:snapshot(list_to_binary(UUID),
                             iolist_to_binary(join(Comment, " "))) of
        {ok, Snap} ->
            io:format("New snapshot created: ~s.~n", [Snap]),
            ok;
        E ->
            io:format("Failed to create: ~p.~n", [E]),
            error
    end;

command(json, ["snapshots", UUID]) ->
    case sniffle_vm:get(list_to_binary(UUID)) of
        {ok, VM} ->
            sniffle_console:pp_json(jsxd:get(<<"snapshots">>, [], VM)),
            ok;
        _ ->
            sniffle_console:pp_json([]),
            ok
    end;

command(text, ["snapshots", UUID]) ->
    H = [{"Timestamp", 16},
         {"UUID", 36},
         {"Comment", 100}],
    ?H(H),
    case sniffle_vm:get(list_to_binary(UUID)) of
        {ok, VM} ->
            jsxd:map(
              fun (SUUID, Snapshot) ->
                      ?F(H, [jsxd:get(<<"timestamp">>, <<"-">>, Snapshot),
                             SUUID,
                             jsxd:get(<<"comment">>, <<"-">>, Snapshot)])
              end, jsxd:get(<<"snapshots">>, [], VM)),
            ok;
        _ ->
            ok
    end;

command(json, ["list"]) ->
    case sniffle_vm:list() of
        {ok, VMs} ->
            sniffle_console:pp_json(
              lists:map(fun (UUID) ->
                                {ok, VM} = sniffle_vm:get(UUID),
                                jsxd:thread(
                                  [{select, [<<"hypervisor">>, <<"state">>]},
                                   {merge, jsxd:get(<<"config">>, [], VM)}],
                                  VM)
                        end, VMs)),
            ok;
        _ ->
            sniffle_console:pp_json([]),
            ok
    end;

command(text, ["list"]) ->
    H = [{"UUID", 36},
         {"Hypervisor", 17},
         {"Name", 15},
         {"State", 10}],
    ?H(H),
    case sniffle_vm:list() of
        {ok, VMs} ->
            lists:map(
              fun (UUID) ->
                      {ok, VM} = sniffle_vm:get(UUID),
                      ?F(H, [UUID,
                             jsxd:get(<<"hypervisor">>, <<"-">>, VM),
                             jsxd:get(<<"config.alias">>, <<"-">>, VM),
                             jsxd:get(<<"state">>, <<"-">>, VM)])
              end, VMs);
        _ ->
            []
    end;

command(_, C) ->
    io:format("Unknown parameters: ~p", [C]),
    error.


join([ Head | [] ], _Sep) ->
    [Head];

join([ Head | Rest], Sep) ->
    [Head,Sep | join(Rest,Sep) ].

fmt(S) ->
    io:format(S).


