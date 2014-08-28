ZyWebD for Luvit
============

ZyWebD is a FastCGI-enabled (currently only PHP) web server that works on the Copas framework with LuaSocket that is easy to be dynamically configured without restarting or reloading. I found Lua is powerful to process binary data because its coroutine support and binary-buffer string type, so I implemented FastCGI in it for fun. And I see Lua is powerful.

This version is for Luvit. I ported ZyWebD so it can have Luvit's great performance. If you are interested in this project, try it and give me some suggestions or report bugs to me.

Features
============

* Default Documents
* FastCGI-based PHP support
* Rewriting support
* Proxy-pass Handler
* Just depended on Luvit

Example Code
============

```
local ZyWebD = require("./ZyWebD")

--
-- Optional: Modify the Server Header
--
ZyWebD.ServerVer = "ZyWebD-Example"

--
-- Add a Server
--
ZyWebD.Create({
	{ -- [1] defines the default VHost
		--
		-- The VHost's absolute root directory.
		--
		DocRoot = process.cwd() .. "\\htdocs",
		DefaultDoc = { "index.php", "index.html" },
		phpCGIport = 9000, -- defined the port php-cgi bind to
		--
		-- Rewrite all not-found requests to index.php.
		-- For performance, Error404 is suggested.
		-- ZyWebD.DS is the directory seperator.
		--
		-- Rewriting = { ["^(/.+)"] = ZyWebD.DS .. "index.php" }
		Error404 = "index.php"
	},
	--
	-- Define a VHost.
	-- The hostname must be lower-cased, without the last dot.
	--
	["zywebd.imzyx.com"] = {
		DocRoot = "/var/www/zywebd.imzyx.com",
		DefaultDoc = { "index.html" },
	},
	--
	-- Define a Proxy-Pass VHost.
	--
	["local.imzyx.com"] = {
	  ProxyTo = 1234 -- pass to the web server working at port 1234.
	}
}, 80) -- If you want the 80th port, you don't have to provide the 2nd arg.
```

Details
============

* Because Luvit doesn't support UNIX sockets currently, so the FastCGI library doesn't support php-fpm working on UNIX sockets. If you must use the UNIX sockets for PHP CGI, try the LuaSocket and Copas version.
* To use the 80 port on Linux, root permission is required.
* If a VHost is defined with a Lua function, it will recevice the two args from the http.createServer callback.
