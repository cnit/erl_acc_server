%%coding : latin-1
%%%-------------------------------------------------------------------
%%% @author sunface
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 29. 六月 2015 17:18
%%%-------------------------------------------------------------------
-module(account_db).
-author("sunface").

%%-compile([{parse_transform, lager_transform}]).
%% API
-export([start/0]).
-export([dirty_read/2,
         dirty_write/2,
         dirty_last/1,
         delete/2]).

-record(user_account,{account, password, server_list, last_server}).
-record(server_info,{id,ip,name,status}).

start() ->
  init_db(),

  init_tables(),
  ok.

init_db() ->
  case mnesia:system_info(extra_db_nodes) of
    [] ->
      mnesia:create_schema([node()]);
    _ ->
      ok
  end,
  application:start(mnesia, permanent),
  mnesia:change_table_copy_type(schema, node(), disc_copies).

init_tables() ->
  mnesia:create_table(db_user_account,[{disc_copies, [node()]}, {type, set}, {record_name, user_account}, {attributes, record_info(fields, user_account)}]),

  mnesia:create_table(db_server_info,[{ram_copies, [node()]}, {type, ordered_set}, {record_name, server_info}, {attributes, record_info(fields, server_info)}]).


dirty_read(Tab,Key) ->
  mnesia:dirty_read(Tab,Key).

dirty_write(Tab,Record) ->
  mnesia:dirty_write(Tab,Record).

dirty_last(Tab) ->
  mnesia:dirty_last(Tab).

delete(Tab,Key) ->
  mnesia:dirty_delete(Tab,Key).

