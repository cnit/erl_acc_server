%%coding: latin-1
-module(account_handler).
-behaviour(cowboy_http_handler).


-export([init/3]).
-export([handle/2]).
-export([terminate/3]).


-record(state, {
}).



init(_, Req, _Opts) ->
	{ok, Req, #state{}}.

handle(Req, State) ->
	NewReq =	try
								QsVals = cowboy_req:qs_valist(Req),
							 	RespData = handle_action:handle(QsVals),
								handle_action:suc_reply(RespData,Req)
						catch
								throw:Reason ->
									RespData1 = 	common_json2:to_json([{suc,0},{reason,Reason}]),
									handle_action:error_reply(RespData1,Req);
							  _:Reason ->
									%%写入日志
									lager:critical("system error!!!!reason:~p stack:~p",[Reason,erlang:get_stacktrace()]),
									RespData2 = 	common_json2:to_json([{suc,0},{reason,"网络错误，请重试"}]),
									handle_action:error_reply(RespData2,Req)
						end,
	{ok, NewReq, State}.

terminate(_Reason, _Req, _State) ->
	ok.





