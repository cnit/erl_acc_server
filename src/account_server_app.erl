-module(account_server_app).
-behaviour(application).

-export([start/2]).
-export([stop/1]).

-include("server.hrl").
start(_Type, _Args) ->

	account_db:start(),

	start_cowboy(),

	ets:new(ets_new_server,[named_table,public,set,{read_concurrency,true}]),
	ets:new(ets_server_info,[named_table,public,set,{keypos,#server_info.id},{read_concurrency,true}]),
	ets:new(ets_login_cache,[named_table,public,set,{keypos,#user_account.acc},{read_concurrency,true}]),

	account_server_sup:start_link().

stop(_State) ->
	ok.

start_cowboy() ->
	Dispatch = cowboy_router:compile([
		{'_', [{"/", account_handler, []}]}
	]),
	{ok, _} = cowboy:start_http(my_http_listener, 100, [{port, 8080}],
		[{env, [{dispatch, Dispatch}]}]
	),
	ok.

