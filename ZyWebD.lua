--
-- ZyWebD's main library.
--
-- by Zyxwvu <imzyxwvu@gmail.com>
--

local fs = require("fs");
local os = require("os");
local http = require("http");
local table = require("table");
local tinsert = table.insert;
local urlParse = require("url").parse;
local schar = require("string").char;
local coroutine = require("coroutine");
local FCGI_Filter = require("./FastCGI");

--
-- Define this library.
--
local Server = { ServerVer = "ZyWebD-Luvit" };

--
-- Define some mime types.
--
local mimeTypes = {
	atom = "application/atom+xml",
	hqx = "application/mac-binhex40",
	mathml = "application/mathml+xml",
	doc = "application/msword",
	bin = "application/octet-stream",
	exe = "application/octet-stream",
	class = "application/octet-stream",
	so = "application/octet-stream",
	dll = "application/octet-stream",
	dmg = "application/octet-stream",
	ogg = "application/ogg",
	pdf = "application/pdf",
	ps = "application/postscript", eps = "application/postscript",
	xul = "application/vnd.mozilla.xul+xml",
	xls = "application/vnd.ms-excel",
	ppt = "application/vnd.ms-powerpoint",
	rm = "application/vnd.rn-realmedia",
	wbxml = "application/vnd.wap.wbxml",
	wmlc = "application/vnd.wap.wmlc",
	wmlsc = "application/vnd.wap.wmlscriptc",
	bcpio = "application/x-bcpio", cpio = "application/x-cpio",
	spl = "application/x-futuresplash",
	xhtml = "application/xhtml+xml", xht = "application/xhtml+xml",
	js = "application/x-javascript",
	lua = "application/x-lua",
	py = "application/x-python",
	rb = "application/x-ruby",
	latex = "application/x-latex",
	xml = "application/xml", xsl = "application/xml",
	dtd = "application/xml-dtd",
	sh = "application/x-sh",
	swf = "application/x-shockwave-flash",
	xslt = "application/xslt+xml",
	sv4cpio = "application/x-sv4cpio", sv4crc = "application/x-sv4crc",
	tar = "application/x-tar",
	tcl = "application/x-tcl",
	tex = "application/x-tex",
	texinfo = "application/x-texinfo", texi = "application/x-texinfo",
	t = "application/x-troff", tr = "application/x-troff",
	roff = "application/x-troff", man = "application/x-troff-man",
	me = "application/x-troff-me", ms = "application/x-troff-ms",
	zip = "application/zip",
	au = "audio/basic", snd = "audio/basic",
	mid = "audio/midi", midi = "audio/midi", kar = "audio/midi",
	mpga = "audio/mpeg", mp2 = "audio/mpeg", mp3 = "audio/mpeg",
	aif = "audio/x-aiff", aiff = "audio/x-aiff", aifc = "audio/x-aiff",
	m3u = "audio/x-mpegurl",
	ram = "audio/x-pn-realaudio", ra = "audio/x-pn-realaudio",
	wav = "audio/x-wav",
	pdb = "chemical/x-pdb",
	bmp = "image/bmp", cgm = "image/cgm",
	gif = "image/gif", ief = "image/ief", png = "image/png",
	jpeg = "image/jpeg", jpg = "image/jpeg", jpe = "image/jpeg",
	svg = "image/svg+xml", svgz = "image/svg+xml",
	tiff = "image/tiff", tif = "image/tiff",
	wbmp = "image/vnd.wap.wbmp",
	ras = "image/x-cmu-raster",
	ico = "image/x-icon",
	pnm = "image/x-portable-anymap",
	pbm = "image/x-portable-bitmap",
	pgm = "image/x-portable-graymap",
	ppm = "image/x-portable-pixmap",
	rgb = "image/x-rgb",
	xbm = "image/x-xbitmap", xpm = "image/x-xpixmap",
	xwd = "image/x-xwindowdump",
	igs = "model/iges", iges = "model/iges",
	msh = "model/mesh", mesh = "model/mesh", silo = "model/mesh",
	wrl = "model/vrml", vrml = "model/vrml",
	ics = "text/calendar", ifb = "text/calendar",
	css = "text/css",
	html = "text/html", htm = "text/html", zyml = "text/html",
	asc = "text/plain", pod = "text/plain", txt = "text/plain",
	rtx = "text/richtext", rtf = "text/rtf",
	sgml = "text/sgml", sgm = "text/sgml",
	tsv = "text/tab-separated-values",
	wml = "text/vnd.wap.wml", wmls = "text/vnd.wap.wmlscript",
	etx = "text/x-setext",
	mpeg = "video/mpeg", mpg = "video/mpeg", mpe = "video/mpeg",
	qt = "video/quicktime",
	qmv = "video/qvod",
	mov = "video/quicktime",
	mxu = "video/vnd.mpegurl",
	avi = "video/x-msvideo",
	movie = "video/x-sgi-movie"
};

--
-- Determin the Directory Seperator by os.type()
--
local dirSep = os.type() == "win32" and "\\" or "/";
Server.DS = dirSep;

--
-- Translate URL-encoded string to UTF-8
--
function decodeURI(s)
	return s:gsub("%%([A-Fa-f0-9][A-Fa-f0-9])", function(hex)
		return schar(tonumber(hex, 16))
	end)
end

--
-- Handle a Request by Passing it to Another Server
--
local function doProxyPass(req, res, port, host)
	local pass = http.request({
		port = port, host = host, path = req.url, method = req.method,
		headers = {
			["If-Modified-Since"] = req.headers["if-modified-since"],
			["If-None-Match"] = req.headers["if-none-match"],
			["Cookie"] = req.headers["cookie"],
			["User-Agent"] = req.headers["user-agent"],
			["Content-Type"] = req.headers["content-type"],
			["Content-Length"] = req.headers["content-length"],
			["Host"] = req.headers["host"]
		}
	}, function(pres)
		res:writeHead(pres.status_code, {
			["Content-Length"] = pres.headers["content-length"],
			["Content-Type"] = pres.headers["content-type"],
			["Set-Cookie"] = pres.headers["set-cookie"],
			["Last-Modified"] = pres.headers["last-modified"],
			["Etag"] = pres.headers["etag"]
		})
		pres:pipe(res);
	end);
	req:on('error', function(e)
		res:writeHead(502, {
			["Content-Type"] = "text/html",
			Server = Server.ServerVer
		});
		res:finish[[<html>
<head><title>HTTP Error 502</title></head>
<body><h1>502 Bad Gateway</h1><p>ZyWebD is acting a gateway server, and the backend server didn't reply. It may be not running at the expected port or under too much pressure.</p></body>
</html>]];
	end)
	req:pipe(pass);
end

--
-- Handle a Request with a General VHost
--
function doRequest(req, res, vhost)
	local url = urlParse(req.url, false);
	--
	-- Handle redirect VHosts
	--
	if vhost.Redirect then
		local redir = vhost.Redirect;
		local mode = 302;
		if redir[1] == 301 then mode = 301; end
		res:writeHead(mode, {
			Location = string.gsub(redir[2], "%$%[([a-z]+)%]", {
				resource = url.pathname,
				query = url.query
			}),
			Server = Server.ServerVer,
			["Content-Length"] = 0
		});
		return res:finish();
	end
	--
	-- Write a Log.
	--
	print(os.date("[%m-%d %H:%M:%S] ") .. req.method .. " " .. req.url)
	--
	-- f_path: rebuilt relative file path
	-- fIndex: [flag] we should find the default document
	-- s: file exists and fStat is usable
	--
	local f_path, fIndex = "", true;
	local s, fStat;
	--
	-- We should decode the URL-encoded pathname to support UTF-8 characters,
	-- and rebuild the URL string to avoid injection attacks.
	--
	for p in decodeURI(url.pathname):gmatch("([^/\\]+)") do
		if p:match("^%.") then
			fStat, fIndex = nil, false; break;
		elseif not p:match("^%.*$") then
			f_path = f_path .. dirSep .. p;
			s, fStat = pcall(fs.statSync, vhost.DocRoot .. f_path);
			if s then
				if fStat.is_file then
					fIndex = false; break;
				end
			else
				fStat, fIndex = nil, false; break;
			end
		end
	end
	if fIndex then
		if url.pathname:sub(-1) == "/" then
			local base_path = f_path;
			for i, v in ipairs(vhost.DefaultDoc) do
				f_path = base_path .. dirSep .. vhost.DefaultDoc[i];
				s, fStat = pcall(fs.statSync, vhost.DocRoot .. f_path);
				if s then break; end
			end
		else
			--
			-- Redirect to the directory if the browser regards it as a file.
			--
			res:writeHead(302, {
				Location = url.pathname .. "/",
				Server = Server.ServerVer,
				["Content-Length"] = 0
			});
			return res:finish();
		end
	end
	--
	-- Try to rewrite the not-found requests.
	--
	if not s and vhost.Rewriting then
		for k, v in pairs(vhost.Rewriting) do
			local args = { url.pathname:match(k) }
			if next(args) then
				local query
				f_path, query = v:gsub("([%%$])([0-9])", function(m, n)
					if m == "$" then return args[tonumber(n)]
					elseif m == "%" and n == "1" then return req.query end
				end):match("([^%?]+)%??(.*)")
				if #query > 0 then url.query = query end
				s, fStat = pcall(fs.statSync, vhost.DocRoot .. f_path);
				break;
			end
		end
	end
	--
	-- Try to find the defined 404 document.
	--
	if not s and vhost.Error404 then
		f_path = dirSep .. vhost.Error404;
		s, fStat = pcall(fs.statSync, vhost.DocRoot .. f_path);
	end
	if s then
		local mimetype = f_path:match("%.([A-Za-z0-9]+)$");
		if mimetype then mimetype = mimetype:lower(); end
		if mimetype == "php" and vhost.phpCGIport then
			local pc = {}
			req:on('data', function(blk) tinsert(pc, blk); end)
			req:on('end', function(...)
				if next(pc) then pc = table.concat(pc) else pc = nil end
				--
				-- Because the FastCGI library is coroutine-based,
				-- we have to wrap the following code with a coroutine.
				--
				coroutine.resume(coroutine.create(function()
					local firstBlk = true;
					local shouldStop = false;
					res.socket:on('close', function() shouldStop = true end)
					local s = pcall(FCGI_Filter, vhost.phpCGIport, {
						SCRIPT_FILENAME = vhost.DocRoot .. f_path,
						SCRIPT_NAME = f_path,
						SERVER_SOFTWARE = Server.ServerVer,
						SERVER_PROTOCOL = "HTTP/1.1",
						SERVER_NAME = req.headers["host"],
						HTTP_USER_AGENT = req.headers["user-agent"],
						HTTP_REFERER = req.headers["referer"],
						HTTP_ACCEPT = req.headers["accept"],
						HTTP_HOST = req.headers["host"],
						HTTP_COOKIE = req.headers["cookie"],
						REQUEST_URI = url.pathname,
						PHP_VALUE = vhost.phpValue,
						DOCUMENT_ROOT = vhost.DocRoot,
						QUERY_STRING = url.query,
						CONTENT_TYPE = req.headers["content-type"],
						CONTENT_LENGTH = req.headers["content-length"],
						REMOTE_ADDR = req.socket:address().address,
						REQUEST_METHOD = req.method,
					}, function(blk)
						--
						-- The first block contains the HTTP headers,
						-- so it should be specially parsed.
						if firstBlk then
							local headEnd, bodyStart = blk:find("\r\n\r\n");
							assert(headEnd and bodyStart);
							local head = { };
							local status = "200 OK";
							for l in blk:sub(1, headEnd - 1):gmatch("([^\r\n]+)") do
								local k, v = l:match("^([%a%d%-_]+): (.+)$");
								if k and v then
									--
									-- Handle the PHP's Status header, by editing php.ini,
									-- PHP can also send RFC-compliant status headers,
									-- but its default option is sending the Status header.
									--
									if k == "Status" then
										status = v;
									else
										tinsert(head, l);
									end
								end
							end
							--
							-- We shouldn't use Luvit's own res:writeHead API because
							-- PHP sends more than one Set-Cookie headers.
							--
							res.socket:write(
								("HTTP/1.1 %s\r\nServer: %s\r\nTransfer-Encoding: chunked\r\n")
								:format(status, Server.ServerVer))
							res.socket:write(table.concat(head, "\r\n") .. "\r\n")
							firstBlk = false
							if bodyStart >= #blk then return end
							blk = blk:sub(bodyStart + 1, -1);
						end
						res.socket:write(("\r\n%x\r\n"):format(#blk))
						res.socket:write(blk)
						return shouldStop
					end, pc)
					if s then
						res.socket:write("\r\n0\r\n\r\n")
					else
						res:writeHead(502, {
							["Content-Type"] = "text/html",
							Server = Server.ServerVer
						})
						res:finish[[<html>
<head><title>HTTP Error 502</title></head>
<body><h1>502 Bad Gateway</h1><p>ZyWebD is acting a gateway server, and the backend server didn't reply. It may be not running at the expected port or under too much pressure.</p></body>
</html>]];
					end
				end))
			end)
		else
			if req.method ~= "GET" and req.method ~= "HEAD" then
				res:writeHead(405, {
					["Content-Type"] = "text/html",
					Server = Server.ServerVer
				});
				return res:finish[[<html>
	<body><h1>405 Method Not Allowed</h1></body>
</html>]];
			end
			--
			-- Check if the browser's cached version is avilable.
			--
			local lastmod = os.date("!%a, %d %b %Y %H:%M:%S GMT", fStat.mtime);
			if lastmod == req.headers["if-modified-since"] then
				res:writeHead(304, { Server = Server.ServerVer });
			else
				res:writeHead(200, {
					["Last-Modified"] = lastmod,
					["Content-Length"] = fStat.size,
					["Content-Type"] = mimeTypes[mimetype],
					Server = Server.ServerVer
				});
				if req.method == "GET" then
					s = fs.createReadStream(vhost.DocRoot .. f_path);
					res:on('error', function() end);
					s:on('error', function() res:finish() end);
					s:pipe(res);
				end
			end
		end
	else
		res:writeHead(404, { Server = Server.ServerVer });
		res:finish[[<html>
	<head><title>HTTP Error 404</title></head>
	<body><h1>404 Not Found</h1></body>
</html>]];
	end
end

--
-- Create a Server.
--
function Server.Create(config, port)
	http.createServer(function(req, res)
		local hostn = req.headers.host:lower();
		if hostn:sub(-1, -1) == "." then
			hostn = hostn:sub(1, -2);
		end
		local vhost = config[hostn] or config[1];
		local s, err
		if type(vhost) == "function" then
			s, err = pcall(vhost, req, res);
		elseif vhost.ProxyTo then
			s, err = pcall(doProxyPass, req, res, 80, "54df.net");
		else
			s, err = pcall(doRequest, req, res, vhost);
		end
		if not s and err then
			res:writeHead(500, { Server = Server.ServerVer });
			res:write[[<html>
	<head><title>HTTP Error 500</title></head>
	<body>
		<h1>500 Internal Server Lua Error</h1>
		<p>]]
			res:write(err)
			res:finish[[</p>
	</body>
</html>]];
		end
	end):listen(port or 80);
end

return Server