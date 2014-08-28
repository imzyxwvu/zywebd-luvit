--
-- ZyWebD's FastCGI library.
-- This library provides Luvit the ability to access an FastCGI backend.
-- look at the LuaSocket version at github.com/imzyxwvu/lua-fastcgi
--
-- by Zyxwvu <imzyxwvu@gmail.com>
--

local net = require("net")
local schar, band = require("string").char, require("bit").band
local coroutine, table, math = require "coroutine", require("table"), require("math")
local coresume, coyield = coroutine.resume, coroutine.yield
local tinsert, tconcat, mmin = table.insert, table.concat, math.min
local function try1st(s, err) if not s and err then error(err) else return s, err end end

--
-- Transform the net library into coroutine-based LuaSocket-like api.
--
function connectAsSync(config)
	local ownerco = coroutine.running();
	local callback = function(...) try1st(coresume(ownerco, ...)); end;
	local rwstream, err = net.createConnection(config, callback);
	rwstream:on('error', callback); err = coyield();
	if err then return nil, err.message; end
	local cache, hasLen, waiting = {}, 0, nil;
	local function checkOutWaiting()
		if hasLen > waiting then
			local buffer = tconcat(cache);
			cache = { buffer:sub(waiting + 1, -1) };
			buffer = buffer:sub(1, waiting);
			hasLen = hasLen - waiting; waiting = nil; return buffer;
		elseif hasLen == waiting then
			local buffer = tconcat(cache);
			hasLen = 0; cache = {}; waiting = nil; return buffer;
		end
	end
	rwstream:on('data', function(data)
		tinsert(cache, data); hasLen = hasLen + #data;
		if waiting then
			local buffer = checkOutWaiting();
			if buffer then callback(buffer); end
		end
	end);
	rwstream:on('end', function()
		if waiting then if waiting >= hasLen then
			callback(nil, "close", tconcat(cache));
		end end
	end);
	return {
		send = function(datablk)
			rwstream:write(datablk, callback); coyield();
		end,
		receive = function(length)
			if length < 1 then return ""; end
			if waiting then error("bad status"); end
			waiting = length;
			local buffer = checkOutWaiting();
			if buffer then return buffer else return coyield(); end
		end,
		close = function() rwstream:destroy(); end
	}
end

local FCGISocket_MT = {}

function FCGISocket_MT:Header(t, len)
	assert(len < 0x10000)
	self.socket.send(schar(
		0x1, -- FCGI_VERSION_1
		t, -- unsigned char type
		0, 1, -- FCGI_NULL_REQUEST_ID
		band(len, 0xFF00) / 0x100, band(len, 0xFF),
		0, -- unsigned char paddingLength
		0 -- unsigned char reserved
	))
end

function FCGISocket_MT:Param(p, v)
	local vl
	if #v > 127 then
		vl = #v
		vl = schar(
			band(vl, 0x7F000000) / 0x1000000 + 0x80,
			band(vl, 0xFF0000) / 0x10000,
			band(vl, 0xFF00) / 0x100,
			band(vl, 0xFF))
	else vl = schar(#v) end
	local paramdata = schar(#p) .. vl .. p .. v
	self:Header(4, #paramdata)
	self.socket.send(paramdata)
end

function FCGISocket_MT:Receive()
	local raw = try1st(self.socket.receive(8))
	local data = self.socket.receive(raw:byte(5) * 0x100 + raw:byte(6))
	self.socket.receive(raw:byte(7))
	return raw:byte(2), data
end

FCGISocket_MT.__index = FCGISocket_MT

local FCGI = {}

function FCGI.FilterK(obj, vars, outputfunc, inputdata)
	obj:Header(1, 8)
	obj.socket.send(schar(
		0, 3, -- unsigned char roleB1, roleB0
		0, -- unsigned char flags
		0, 0, 0, 0, 0
	))
	for k, v in pairs(vars) do
		obj:Param(k, v)
	end
	obj:Header(4, 0) -- FCGI_PARAMS
	if inputdata then
		local pos = 1
		while pos <= #inputdata do
			local v = inputdata:sub(pos, mmin(pos + 32767, #inputdata))
			obj:Header(5, #v) -- FCGI_STDIN
			obj.socket.send(v)
			pos = pos + 32768
		end
	end
	obj:Header(5, 0) -- FCGI_STDIN
	while true do
		local rt, rv = obj:Receive(obj.socket)
		if rt == 6 then -- FCGI_STDOUT
			if outputfunc(rv) then
				obj:Header(2, 0) -- FCGI_ABORT_REQUEST
				obj.socket.close()
				break
			end
		elseif rt == 3 then -- FCGI_END_REQUEST
			obj.socket.close()
			break
		elseif rt == 7 then -- FCGI_STDERR
			if FCGI.ErrorLog then FCGI.ErrorLog:write(rv) end
		end
	end
end

return function(port, ...)
	local obj = setmetatable({ }, FCGISocket_MT)
	obj.socket = try1st(connectAsSync({ host = "127.0.0.1", port = port }));
	return FCGI.FilterK(obj, ...)
end