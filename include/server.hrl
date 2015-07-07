-include("type.hrl").

-record(user_account,{acc, password, server_list=[], last_server}).
-record(server_info,{id,ip,name,status}).

-define(AUTH_KEY,   <<"ew2123jdsa2">>).
-define(NEW_SERVER, 1).
-define(EMPTY_RESP, <<>>).




-define(STATUS_SUCCESS, 0).
-define(STATUS_ERROR,   1).
-define(STATUS_USAGE,   2).
-define(STATUS_BADRPC,  3).


