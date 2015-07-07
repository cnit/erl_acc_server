{application, account_server, [
	{description, ""},
	{vsn, "0.1.0"},
	{id, ""},
	{modules, ['account_handler', 'account_server_sup', 'common_json2', 'mochijson2', 'account_server_app']},
	{registered, []},
	{applications, [
		kernel,
		stdlib,
		cowboy
	]},
	{mod, {account_server_app, []}},
	{env, []}
]}.
