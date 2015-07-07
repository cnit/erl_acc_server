<?php

//当前支持的APP
$appList = array('account_server','hot_update');
$cookie = account_server;
$master_name   = 'account_server';
$master_host   = '127.0.0.1';
// 第一个参数是命令名称
$command = strtolower($argv[1]);

// 第二个参数是目标APP
$targetApp = strtolower($argv[2]);

$arg  = strtolower($argv[3]);

if (!in_array($targetApp, $appList)) {
	echo '提示：节点名不存在，目前支持的有:\'account_server\'等'."\n";
	exit();
}

if ($command == 'get_start_command') {
	if ($targetApp == 'account_server') {
		echo "./_rel/account_server_release/bin/account_server_release console -K true -sbt db -spp true -sub true";
	}
} 
else if ($command == 'get_stop_command') {
	if ($targetApp == 'account_server'){
		$command = "erl -pa ./ebin -pa ./deps/lager/ebin -name ctl-{$targetApp}@{$master_host} -setcookie {$cookie} -s acc_ctl";

		echo $command. " -extra {$master_name}@{$master_host} stop_all";
	}
}
else if ($command == 'hot_update') {
	$command = "erl -pa ./ebin -pa ./deps/lager/ebin -name {$targetApp}_hot_update@{$master_host}  -setcookie {$cookie} ";
	echo $command. " -s acc_ctl -extra {$master_name}@{$master_host} hot_update {$arg}" ;
}

else if ($command == 'backup') {
	$command = "erl -pa ./ebin -pa ./deps/lager/ebin -name {$targetApp}_backup@{$masterHost}  -setcookie {$cookie} ";

	echo $command. " -s acc_ctl -extra {$master_name}@{$master_host} backup" ;
}
echo "\n";
exit(0);
	
