%%coding: latin-1
%%%-------------------------------------------------------------------
%%% @author Sunface
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%请求行为处理模块
%%% @end
%%% Created : 30. 六月 2015 10:21
%%%-------------------------------------------------------------------
-module(handle_action).
-author("sunface").

%% API
-export([handle/1,
         suc_reply/2,
         error_reply/2]).

-include_lib("stdlib/include/ms_transform.hrl").

-include("server.hrl").


handle(Vals) ->
  [{<<"action">>,Action} | NewVals] = Vals,
  handle(Action,NewVals).


%%@doc
%%处理请求
-spec handle(Action :: action(), NewVals :: list()) -> Data::json().

%%
%%玩家请求
%%

%%@doc
%%一键注册
handle(<<"auto_reg">>,Vals) ->
  [{<<"acc">>,Acc},{<<"pw">>,Password},{<<"key">>,Key}] = Vals,
  check_account(Acc,Password,Key),
  %%判断用户是否存在
 NewAcc =  case account_db:dirty_read(db_user_account,Acc) of
              [] ->
                %%用户不存在
                account_db:dirty_write(db_user_account,#user_account{acc = Acc,password = Password}),
                Acc;
              _ ->
                %%用户存在，重新生成一个账号
                NewAcc1 = list_to_binary(integer_to_list(erlang:system_time())),
                account_db:dirty_write(db_user_account,#user_account{acc = NewAcc1,password = Password}),
                NewAcc1
            end	,
  Account = #user_account{acc = NewAcc,password = Password},
  ets:insert(ets_login_cache,Account),
  get_new_server(NewAcc);




%%@doc
%%使用自定义账号注册
handle(<<"reg">>,Vals) ->
  [{<<"acc">>,Acc},{<<"pw">>,Password},{<<"key">>,Key}] = Vals,
  check_account(Acc,Password,Key),
  %%判断用户是否存在
  case account_db:dirty_read(db_user_account,Acc) of
    [] ->
      %%用户不存在
      Account = #user_account{acc = Acc,password = Password},
      ets:insert(ets_login_cache,Account),
      account_db:dirty_write(db_user_account,Account);
    _ ->
      erlang:throw("账号已存在")
  end	,
  get_new_server(Acc);


%%@doc
%%登录账号
handle(<<"login_acc">>,Vals) ->
  [{<<"acc">>,Acc},{<<"pw">>,Password},{<<"key">>,Key}] = Vals,
  check_account(Acc,Password,Key),

  case account_db:dirty_read(db_user_account,Acc) of
    [] ->
      %%用户不存在
      erlang:throw("该用户不存在");
    [UserAccount] ->
      if
        UserAccount#user_account.password == Password ->
          %%验证成功
          ets:insert(ets_login_cache,UserAccount),
          %%返回玩家上次登录的服务器
          get_role_last_login_server(UserAccount);
        true ->
          erlang:throw("密码错误")
      end
  end;

%%@doc
%%登出账号
handle(<<"logout_acc">>,Vals) ->
  [{<<"acc">>,Acc},{<<"pw">>,Password},{<<"key">>,Key}] = Vals,
  check_account(Acc,Password,Key),
  ensure_already_login(Acc,Password),
  ets:delete(ets_login_cache,Acc),

  common_json2:to_json([{suc,1}]);


%%@doc
%%切换server
handle(<<"change_new">>,Vals) ->
  [{<<"acc">>,Acc},{<<"pw">>,Password},{<<"key">>,Key}] = Vals,
  check_account(Acc,Password,Key),
  UserAccount = ensure_already_login(Acc,Password),
  case  UserAccount#user_account.server_list of
    [] ->
      %%返回最近新开的服
      get_new_server(Acc);
    [UserAccount] ->
      %%返回玩家角色列表
      UserServerList = UserAccount#user_account.server_list,
      ServerList = [[ServerID,ServerIP,ServerName,RoleLevel] || {ServerID,ServerIP,ServerName,RoleLevel} <- UserServerList],
      common_json2:to_json([{suc,1},{server_list,ServerList}])
  end;

handle(<<"change">>,Vals) ->
  [{<<"acc">>,Acc},{<<"pw">>,Password},{<<"key">>,Key},{<<"num">>,ServerNum}] = Vals,

  check_key(Key),
  ensure_already_login(Acc,Password),
  %%返回[N-9,N]服务器列表
  get_spec_server_list(ServerNum);


handle(<<"bind_acc">>,Vals) ->
  io:format("vals:~p~n",[Vals]),
  [{<<"acc">>,Acc},{<<"new_acc">>,NewAcc},{<<"pw">>,Password},{<<"new_pw">>,NewPassword},{<<"key">>,Key}] = Vals,
  check_account(Acc,Password,Key),
  ensure_already_login(Acc,Password),
  bind_acc(Acc,NewAcc,NewPassword),
  common_json2:to_json([{suc,1}]);
%%
%%服务器请求
%%
handle(<<"update_server">>,Vals) ->
  [{<<"id">>,ServerID},{<<"name">>,ServerName},{<<"status">>,ServerStatus},{<<"ip">>,ServerIP}] = Vals,
  %%从服务器发送过来，更新服务器列表
  NewServer = #server_info{
    id = ServerID,
    ip = ServerIP,
    name = ServerName,
    status = ServerStatus},
  account_db:dirty_write(db_server_info,NewServer),
  ets:insert(ets_server_info,NewServer),

  %%更新最新服务器的ETS表
  NewKey = account_db:dirty_last(db_server_info),
  [NewestServer] = account_db:dirty_read(db_server_info,NewKey),
  if
    NewestServer#server_info.id =< ServerID ->
      ets:insert(ets_new_server,{?NEW_SERVER,NewestServer});
    true ->
      ignore
  end,
  <<"update server suc">>;

%%@doc
%%玩家角色下线时对账号进行更新
handle(<<"update_acc">>,Vals) ->
  [{<<"acc",Acc>>},{<<"id">>,ServerID},{<<"lv">>,RoleLevel}] = Vals,
  case account_db:dirty_read(db_user_account,Acc) of
    [] ->
      throw("不存在的账号");
    [Account] ->
      [ServerInfo] = get_server_info(ServerID),
      ServerName = ServerInfo#server_info.name,
      ServerIP = ServerInfo#server_info.ip,
      NewServerList = lists:keyreplace(ServerID,1,Account#user_account.server_list,{ServerID,ServerIP,ServerName,RoleLevel}),
      NewAccount = Account#user_account{
              server_list = NewServerList,
              last_server = {ServerID,ServerName}
      },
      account_db:dirty_write(db_user_account,NewAccount)
  end,
  common_json2:to_json([{suc,1}]).



%%内部API

%%@doc
%%检查玩家账号合法性
-spec check_account(Acc::acc(), Password::password(), Key::key()) -> ok.
check_account(Acc,Password,Key) ->
  %%检查KEY的合法性
  check_key(Key),
  %%检查账号信息(空账号，字符串合法性)
  if
    Acc == <<"">> ->
      erlang:throw("账号不能为空");
    true ->
      next
  end,

  %%检查密码信息(空账号，字符串合法性)
  if
    Password == <<"">> ->
      erlang:throw("密码不能为空");
    true ->
      next
  end,

  ok.

-spec check_key(Key:: key()) -> ok.
check_key(Key) ->
  if
    Key == ?AUTH_KEY ->
      ok;
    true ->
      erlang:throw("Key验证错误")
  end.

%%@doc
%%确保用户已经登录，若找不到登录缓存信息，则验证密码
-spec ensure_already_login(Acc::acc(), Password::password()) ->ok.
ensure_already_login(Acc,Password) ->
  case ets:lookup(ets_login_cache,Acc) of
    [] ->
      case account_db:dirty_read(db_user_account,Acc) of
        [] ->
          erlang:throw("请先注册");
        [DbAccount] ->
          if
            DbAccount#user_account.password == Password ->
              ets:insert(ets_login_cache,DbAccount),
              DbAccount;
            true ->
              erlang:throw("验证失败，密码错误")
          end
      end;
    [EtsAccount] ->
      EtsAccount
  end.
%%@doc
%%获取最新server
-spec get_new_server(NewAcc::acc()) -> ServerInfo::json().
get_new_server(NewAcc) ->
  Server =  case ets:lookup(ets_new_server,?NEW_SERVER) of
                [] ->
                  NewKey = account_db:dirty_last(db_server_info),
                  [NewServer] = account_db:dirty_read(db_server_info,NewKey),
                  ets:insert(ets_new_server,{?NEW_SERVER,NewServer}),
                  NewServer;
                [{_,NewServer1}] ->
                  NewServer1
            end,
  common_json2:to_json([{suc,1},
                        {id,Server#server_info.id},
                        {ip,Server#server_info.ip},
                        {name,Server#server_info.name},
                        {new_acc,NewAcc}]).


%%@doc
%%返回指定的服务器区间列表
-spec get_spec_server_list(UpLimitNum::binary()) -> json().
get_spec_server_list(UpLimitNum) ->
  LowerLimitNum = integer_to_binary(binary_to_integer(UpLimitNum)-4),
  MS =ets:fun2ms(fun(#server_info{id = ServerID} = Data)  when (ServerID >= LowerLimitNum) andalso(ServerID =< UpLimitNum) -> Data end),

  MSResult = ets:select(ets_server_info ,MS),
  ServerList = [[ServerID,ServerIP,ServerName,ServerStatus] || #server_info{id = ServerID,
                                                                              ip = ServerIP,
                                                                              name = ServerName,
                                                                              status = ServerStatus} <- MSResult],
  common_json2:to_json([{suc,1},{server_list,ServerList}]).
%%@doc
%%获取玩家上次登录服务器
-spec get_role_last_login_server(Account::account()) -> ServerInfo::json().
get_role_last_login_server(Account) ->
  case Account#user_account.last_server of
    {ServerID,ServerName} ->
        #server_info{
            name = ServerName,
            ip = ServerIP
        } = get_server_info(ServerID),

        common_json2:to_json([{suc,1},{id,ServerID},{ip,ServerIP},{name,ServerName}]);
      _Other ->
        get_new_server(Account#user_account.acc)
  end.

%%@doc
%%从缓存ETS或者数据库获取服务器信息
-spec get_server_info(ServerID::integer) ->ServerInfo::#server_info{}.
get_server_info(ServerID) ->
  case ets:lookup(ets_server_info,ServerID) of
    [] ->
      case account_db:dirty_read(db_server_info,ServerID) of
        [] ->
          erlang:throw("服务器未开放");
        [ServerInfo] ->
          ets:insert(ets_server_info,#server_info{id = ServerID,ip = ServerInfo#server_info.ip}),
          ServerInfo
      end;
    [ServerInfo] ->
      ServerInfo
  end.

%%@doc
%%绑定账号
-spec bind_acc(OldAcc::acc(),NewAcc::acc(), NewPassword:: password()) ->ok.
bind_acc(OldAcc,NewAcc,NewPassword) ->
  %%查看要绑定的账号是否存在
  case account_db:dirty_read(db_user_account,NewAcc) of
    [] ->
      next;
    _ ->
      erlang:throw("要绑定的新账号已存在，请重新选择")
  end,
  %%更新数据库
  case account_db:dirty_read(db_user_account,OldAcc) of
    [] ->
      erlang:throw("无法绑定，旧账号不存在");
    [OldAccount] ->
      %%删除旧账号
      account_db:delete(db_user_account,OldAcc),
      %%插入新账号
      NewAccount = OldAccount#user_account{acc = NewAcc,password = NewPassword},
      account_db:dirty_write(db_user_account,NewAccount),
      %%更新登陆缓存
      case ets:lookup(ets_login_cache,OldAcc) of
        [] ->
          ignore;
        [_OldAccount1] ->
          ets:delete(ets_login_cache,OldAcc),
          ets:insert(ets_login_cache,NewAccount)
      end
  end,


  ok.
%%@doc
%%成功并回复
-spec suc_reply(Data::json(), Req) -> Req.
suc_reply(Data,Req) ->
  {ok,NewReq} = cowboy_req:reply(200,
      [{<<"content-type">>, <<"text/plain">>}],
      Data,
      Req),
  NewReq.

%%@doc
%%失败并回复
-spec error_reply(Data::json(), Req) -> Req.
error_reply(Data,Req) ->
  {ok,NewReq} = cowboy_req:reply(200,
    [{<<"content-type">>, <<"text/plain">>}],
    Data,
    Req),
  NewReq.

