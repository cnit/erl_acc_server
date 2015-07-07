acc_server
==========


The game account server which is implemented with Erlang.

The main purpose of this server is to provide account handling for all of the game servers.

To get concrete information,you may have to read handle_action.erl and the files in doc directory!


Scripts
-------
Control server with bash file <b>acc_ctl</b>:

get help
  ./acc_ctl help

start or stop server:
   ./acc_ctl start | stop 
   
   
rebuild or make server:
   ./acc_ctl rebuild | make
  
backup mnesia:
  ./acc_ctl backup
   
hot update erl files:
  ./acc_ctl hot_update ErlFileName

