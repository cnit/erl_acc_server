%%%-------------------------------------------------------------------
%%% @author Sunface
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 01. 七月 2015 12:55
%%%-------------------------------------------------------------------
-module(acc_ctl).
-author("Administrator").

%% API
-export([init/0,
        start/0,
        process/1,
        hot_update/1]).

-include("server.hrl").


start() ->
  case init:get_plain_arguments() of
    [SNode | Args]->
      lager:error("node:~p,arg:~p!",[SNode,Args]),
      SNode1 = case string:tokens(SNode, "@") of
                 [_Node, _Server] ->
                   SNode;
                 _ ->
                   case net_kernel:longnames() of
                     true ->
                       SNode ++ "@" ++ inet_db:gethostname() ++
                         "." ++ inet_db:res_option(domain);
                     false ->
                       SNode ++ "@" ++ inet_db:gethostname();
                     _ ->
                       SNode
                   end
               end,
      Node = erlang:list_to_atom(SNode1),
      Status = case erlang:length(Args) > 1 of
                  true ->
                    [Command | Args2] = Args,
                    case Command of
                    %% Ŀǰֻ��֧���ȸ��µĵ�������
                      "hot_update" ->
                         case rpc:call(Node, ?MODULE, hot_update, [[Node|Args2]]) of
                                   {badrpc, _Reason} ->
                                     ?STATUS_BADRPC;
                                   S ->
                                     S
                                 end;
                      _ ->
                        ?STATUS_BADRPC
                    end;
                  false ->
                     case rpc:call(Node, ?MODULE, process, [Args]) of
                               {badrpc,_Reason} ->
                                 ?STATUS_BADRPC;
                               S ->
                                 S
                             end
                end,
      halt(Status);
    _ ->
      print_usage(),
      halt(?STATUS_USAGE)
  end.

init() ->
  ok.



process(["stop"]) ->
  init:stop(),
  ?STATUS_SUCCESS;


process(["stop_all"]) ->
  lager:error("starting stop all!"),
  lager:error("stoping mnesia"),
  mnesia:dump_log(),
  mnesia:stop(),
  timer:sleep(2000),
  lager:error("mnesia stopped"),

  init:stop(),
  lager:error("already stop all!"),
  timer:sleep(2000),
  halt(),
  ?STATUS_SUCCESS;

process(["stop_app"]) ->
  ?STATUS_SUCCESS;

process(["backup"]) ->
  lager:error("starting backup"),
  {{Y, M, D}, {H, _, _}} = erlang:localtime(),
  BackFileName = lists:concat([Y, M, D, ".", H]),
  File = lists:concat(["/data/account_server/database/", BackFileName]),

  ok = mnesia:backup(File),
  TarFileName = BackFileName,
  os:cmd(lists:concat(["cd /data/account_server/database","/; tar cfz ", TarFileName, ".tar.gz ", BackFileName, "; rm -f ", BackFileName])),
  lager:error("backup sucessful"),
  ?STATUS_SUCCESS;


process(["restart"]) ->
  init:restart(),
  ?STATUS_SUCCESS.

hot_update([Node,Module]) ->
  Result = rpc:call(Node, c, l, [erlang:list_to_atom(Module)]),
  lager:error("hot_update result:~p",[Result]),
  ?STATUS_SUCCESS.




print_usage() ->
  CmdDescs =
    [{"status", "get node status"},
      {"stop", "stop node"},
      {"restart", "restart node"}
    ] ++
    ets:tab2list(manager_ctl_cmds),
  MaxCmdLen =
    lists:max(lists:map(
      fun({Cmd, _Desc}) ->
        length(Cmd)
      end, CmdDescs)),
  NewLine = io_lib:format("~n", []),
  FmtCmdDescs =
    lists:map(
      fun({Cmd, Desc}) ->
        ["  ", Cmd, string:chars($\s, MaxCmdLen - length(Cmd) + 2),
          Desc, NewLine]
      end, CmdDescs),
  lager:error(
    "Usage: managerctl [--node nodename] command [options]~n"
    "~n"
    "Available commands in this node node:~n"
    ++ FmtCmdDescs ++
      "~n"
      "Examples:~n"
      "  mgeectl restart~n"
      "  mgeectl --node node@host restart~n"
      "  mgeectl vhost www.example.org ...~n",
    []).
