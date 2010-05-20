/**
 * Application HTTP web-server
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2009 - 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module http.appserver;

import std.conv, std.stdarg, core.thread, std.string;
import std.socket;
import http.wsapi;
import std.stdio;

class Connection: WsApi
{
	private:
		Socket socket;
		
	public:
		this (Socket s, string tmpDir)
		{
			super(tmpDir);
			socket = s;
		}
		this (string tmpDir)
		{
			super(tmpDir);
		}
		~this ()
		{
			debug .writeln("Closing socket");
			flush;
			socket.shutdown(SocketShutdown.BOTH);
			socket.close;
		}
		auto opCall ()
		{
			string data;
			data.length = 4096;
			uint curIdx = 0, len = 0;
			debug .writeln("Receiving data");
			while (true)
			{
				len = socket.receive(cast(ubyte[])data[curIdx .. $]);
				if (curIdx + len < data.length)
				{
					data.length = curIdx + len;
					break;
				}
				else
				{
					curIdx = data.length;
					data.length += 4096;
				}
			}
			debug .writefln("Recieved %d", data.length);
			if (!data.length)
				return false;
			auto headerEndPos = indexOf(data, "\r\n\r\n");
			if (-1 == headerEndPos)
				return false; //or not???
			string header = data[0 .. headerEndPos];
			data = data[headerEndPos .. $];
			string[] headers = split(header, "\r\n");
			// Request header
			string[] reqHeader = split(headers[0]);
			string method = reqHeader[0], uri = reqHeader[1], protocol = reqHeader[2];
			requestHeader("Request-Method", method);
			requestHeader("Request-Uri", uri);
			if (reqHeader[2] != "HTTP/1.1")
				throw new Exception("unsupported protocol " ~ protocol);
			requestHeader("Protocol", protocol);
			// Headers
			headers = headers[1 .. $];
			parseRequestHeaders(headers);
			// Body
			if ("GET" == method)
			{
				auto signPos = indexOf(uri, "?");
				if (-1 != signPos && uri.length > signPos + 1)
					parseGetParams(uri[signPos + 1 .. $]);
			}
			else if ("POST" == method)
				parsePostData(data);
			.writeln("Dispatching client request");
			return false; //!!! for now
		}
		WsApi sendHeaders ()
		{
			if (headersSent)
				return this;
			WsApi.sendHeaders;
			string headers;
			if (!responseCode || (responseCode in responseCodesStrings) is null)
				responseCode = 200;
			headers ~= "HTTP/1.1 " ~ to!(string)(responseCode) ~ " " ~ responseCodesStrings[responseCode] ~ "\r\n";
			if (responseHeader("Content-Type") is null)
				responseHeader("Content-Type", "text/html");
			foreach (key, value; responseHeaders)
				headers ~= key ~ ": " ~ value ~ "\r\n";
			headers ~= "\r\n";
			dataToSend = headers ~ dataToSend;
			return this;
		}
		WsApi flush ()
		{
			WsApi.flush;
			if (dataToSend.length)
			{
				socket.send(dataToSend);
				dataToSend.length = 0;
			}
			return this;
		}
}

class ConnectionFiber: Fiber
{
	private:
		Connection conn;
		void function (WsApi) fAction;
		void delegate (WsApi) dAction;
		
		void run ()
		{
			scope(exit) delete conn;
			try
			{
				conn();
				debug writeln("Executing action");
				synchronized
				{
					if (fAction !is null)
						fAction(conn);
					else
						dAction(conn);
				}
				debug writeln("Closing connection");
			}
			catch (Exception e)
			{
				conn.write("HTTP/1.1 500 " ~ WsApi.responseCodesStrings[500] ~ "\r\nStatus: 500 " ~ WsApi.responseCodesStrings[500] ~ "\r\n\r\nInternal Server Error");
				.writeln("Exception: " ~ to!(string)(e));
			}
		}
		
	public:
		this (Connection conn, void function (WsApi) app)
		in
		{
			assert(app !is null);
		}
		body
		{
			this.conn = conn;
			fAction = app;
			super(&run);
		}
		this (Connection conn, void delegate (WsApi) app)
		in
		{
			assert(app !is null);
		}
		body
		{
			this.conn = conn;
			dAction = app;
			super(&run);
		}
}

class AppServer
{
	private:
		TcpSocket socket;
		InternetAddress addr;
		void function (WsApi) fAction;
		void delegate (WsApi) dAction;
		
		this (InternetAddress addr, string tmpDir)
		{
			debug writeln("Starting AppServer");
			this.addr = addr;
			socket = new TcpSocket();
			socket.bind(addr);
			socket.listen(10);
			debug writeln("Dispatching loop");
			ConnectionFiber[] fibers;
			while (true)
			{
				auto idx = -1;
				foreach (i, fiber; fibers)
					if (Fiber.State.TERM == fiber.state)
					{
						idx = i;
						fiber.reset;
						fiber.conn = new Connection(socket.accept, tmpDir);
					}
				if (-1 == idx)
				{
					idx = fibers.length;
					fibers.length += 1;
					fibers[idx] = fAction !is null
						? new ConnectionFiber(new Connection(socket.accept, tmpDir), fAction)
						: new ConnectionFiber(new Connection(socket.accept, tmpDir), dAction);
				}
				assert(Fiber.State.HOLD == fibers[idx].state);
				fibers[idx].call;				
			}
		}

	public:
		this (InternetAddress addr, string tmpDir, void function (WsApi) app)
		{
			assert(app !is null);
			fAction = app;
			this(addr, tmpDir);
		}
		this (InternetAddress addr, string tmpDir, void delegate (WsApi) app)
		{
			assert(app !is null);
			dAction = app;
			this(addr, tmpDir);
		}
		this (string addr, ushort port, string tmpDir, void function (WsApi) app)
		{
			this(new InternetAddress(addr, port), tmpDir, app);
		}
		this (string addr, ushort port, string tmpDir, void delegate (WsApi) app)
		{
			this(new InternetAddress(addr, port), tmpDir, app);
		}
		this (ushort port, string tmpDir, void function (WsApi) app)
		{
			this(new InternetAddress(port), tmpDir, app);
		}
		this (ushort port, string tmpDir, void delegate (WsApi) app)
		{
			this(new InternetAddress(port), tmpDir, app);
		}
} 
