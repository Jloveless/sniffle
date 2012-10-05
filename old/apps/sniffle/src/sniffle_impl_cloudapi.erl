%%%-------------------------------------------------------------------
%%% @Author Heinz N. Gies <heinz@licenser.net>
%%% @copyright (C) 2012, Heinz N. Gies
%%% @doc
%%%
%%% @end
%%% Created :  7 May 2012 by Heinz N. Gies <heinz@licenser.net>
%%%-------------------------------------------------------------------
-module(sniffle_impl_cloudapi).

-behavior(sniffle_impl).
%% API

%% gen_server callbacks
-export([init/2, handle_call/4, handle_cast/3,
	 handle_info/2, terminate/2, code_change/3]).

-record(state, {uuid, host, auth}).

init(UUID, {Host, HAuth}) ->
    {ok, #state{uuid=UUID,
		host=Host,
		auth=HAuth}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------

handle_call(Auth, {machines, list}, _From,
	    #state{host = Host,
		   uuid=UUID,
		   auth=HAuth} = State) ->
    lager:info([{fifi_component, sniffle_impl_cloudapi}, {user, Auth}],
	       "machines:list.",
	       []),
    Res = case cloudapi:list_machines(Host, HAuth) of
	      {ok, {Ms, _, _}} ->
		  lager:error([{fifi_component, sniffle_impl_cloudapi}, {user, Auth}],
			      "machines:list - Machines: ~p.",
			      [Ms]),
		  Ms2 = [niceify_json(M) || M <- Ms],
		  sniffle_server:update_machines(UUID, Ms2),
		  {ok, Ms2};
	      E ->
	    lager:error([{fifi_component, sniffle_impl_cloudapi}, {user, Auth}],
			"machines:list - Error: ~p.",
			[E]),
		  {error, E}
	  end,
    {reply, Res, State};

handle_call(Auth, {machines, get, UUID}, _From, 
	    #state{host = Host,
		   auth=HAuth} = State) ->
    lager:info([{fifi_component, sniffle_impl_cloudapi}, {user, Auth}],
	       "machines:get - UUID: ~s.",
	       [UUID]),
    {ok, R} =  cloudapi:get_machine(Host, HAuth, ensure_list(UUID)),
    {reply, niceify_json(R), State};

handle_call(Auth, {machines, delete, UUID}, _From, 
	    #state{host = Host,
		   auth=HAuth} = State) ->
    lager:info([{fifi_component, sniffle_impl_cloudapi}, {user, Auth}],
	       "machines:delete - UUID: ~s.",
	       [UUID]),
    {ok, R} = cloudapi:delete_machine(Host, HAuth, ensure_list(UUID)),
    {reply, niceify_json(R), State};

handle_call(Auth, {machines, start, UUID}, _From, 
	    #state{host = Host,
		   auth=HAuth} = State) ->
    lager:info([{fifi_component, sniffle_impl_cloudapi}, {user, Auth}],
	       "machines:start - UUID: ~s.",
	       [UUID]),
    {ok, R} = cloudapi:start_machine(Host, HAuth, ensure_list(UUID)),
    {reply, niceify_json(R), State};

handle_call(Auth, {machines, stop, UUID}, _From, 
	    #state{host = Host,
		   auth=HAuth} = State) ->
    lager:info([{fifi_component, sniffle_impl_cloudapi}, {user, Auth}],
	       "machines:stop - UUID: ~s.",
	       [UUID]),
    {ok, R} = cloudapi:stop_machine(Host, HAuth, ensure_list(UUID)),
    {reply, niceify_json(R), State};

handle_call(Auth, {machines, reboot, UUID}, _From, 
	    #state{host = Host,
		   auth=HAuth} = State) ->
    lager:info([{fifi_component, sniffle_impl_cloudapi}, {user, Auth}],
	       "machines:reboot - UUID: ~s.",
	       [UUID]),
    {ok, R} = cloudapi:reboot_machine(Host, HAuth, ensure_list(UUID)),
    {reply, niceify_json(R), State};

handle_call(Auth, {packages, list}, _From, 
	    #state{host=Host,
		   uuid=UUID,
		   auth=HAuth} = State) ->
    lager:info([{fifi_component, sniffle_impl_cloudapi}, {user, Auth}],
	       "packages:list.",
	       []),
    case cloudapi:list_packages(Host, HAuth) of
	{ok, Ps} ->
	    sniffle_server:register_host_resource(
	      UUID, <<"packages">>, 
	      fun (P) ->
		      proplists:get_value(<<"name">>, P)
	      end, Ps),
	    {reply, {ok, niceify_json(Ps)}, State};
	E ->
	    lager:error([{fifi_component, sniffle_impl_cloudapi}, {user, Auth}],
			"packags:list - Error: ~p.",
			[E]),
	    {reply,
	     {error, E}, State}
    end;

handle_call(Auth, {datasets, list}, _From, 
	    #state{host = Host,
		   uuid=UUID,
		   auth=HAuth} = State) ->
    lager:info([{fifi_component, sniffle_impl_cloudapi}, {user, Auth}],
	       "datasets:list.",
	       []),
    case cloudapi:list_datasets(Host, HAuth) of
	{ok, Ds} ->
	    sniffle_server:register_host_resource(
	      UUID, <<"datasets">>, 
	      fun (E) ->
		      proplists:get_value(<<"id">>, E)
	      end, Ds),
	    {reply, {ok, niceify_json(Ds)}, State};
	E ->
	    lager:error([{fifi_component, sniffle_impl_cloudapi}, {user, Auth}],
			"datasets:list - Error: ~p.",
			[E]),
	    {reply,
	     {error, E}, State}
    end;

handle_call(Auth, {keys, list}, _From, 
	    #state{host = Host,
		   auth=HAuth} = State) ->
    lager:info([{fifi_component, sniffle_impl_cloudapi}, {user, Auth}],
	       "keys:list.",
	       []),
    case cloudapi:list_keys(Host, HAuth) of
	{ok, [{<<"keys">>, Ks}]} ->
	    {reply, {ok, niceify_json(Ks)}, State};
	E ->
	    lager:error([{fifi_component, sniffle_impl_cloudapi}, {user, Auth}],
			"keys:list - Error: ~p.",
			[E]),
	    {reply,
	     {error, E}, State}
    end;

handle_call(Auth, {keys, create, Auth, Pass, KeyID, PublicKey}, _From,
	    #state{host = Host,
		   auth=HAuth} = State) ->
    lager:info([{fifi_component, sniffle_impl_cloudapi}, {user, Auth}],
	       "keys:create - KeyID: ~p.",
	       [KeyID]),
    case cloudapi:create_key(Host, HAuth, ensure_list(Pass), ensure_list(KeyID), PublicKey) of
	{ok, D} ->
	    {reply, {ok, niceify_json(D)}, State};
    	E ->
	    lager:error([{fifi_component, sniffle_impl_cloudapi}, {user, Auth}],
			"keys:create - Error: ~p.",
			[E]),
	    {reply, {error, E}, State}
    end;
	
handle_call(Auth, Call, _From, State) ->
    lager:error([{fifi_component, sniffle_impl_cloudapi}, {user, Auth}],
		"sniffle_impl_cloudapi:unknwon - Call: ~p.",
		[Call]),
    {reply, {error, not_supported}, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast(_Auth, _Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

ensure_list(B) when is_binary(B) ->
    binary_to_list(B);
ensure_list(L) when is_list(L) ->
    L.

niceify_json([{K, V}|R]) when is_list(V), is_binary(K) ->
    [{binary_to_atom(K), niceify_json(V)}|niceify_json(R)];

niceify_json([{K, V}|R]) when is_list(V) ->
    [{K, niceify_json(V)}|niceify_json(R)];

niceify_json([{K, V}|R]) when is_binary(K) ->
    [{binary_to_atom(K), V}|niceify_json(R)];

niceify_json([H|R]) ->
    [H|niceify_json(R)];

niceify_json([]) ->
    [];

niceify_json(O) ->
    O.

binary_to_atom(B) ->
    list_to_atom(binary_to_list(B)).