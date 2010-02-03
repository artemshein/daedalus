module http.appserver;

import std.conv, std.stdarg, core.thread;
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
			.writeln("Closing socket");
			socket.shutdown(SocketShutdown.BOTH);
			socket.close;
		}
		auto opCall ()
		{
			.writeln("Dispatching client request");
			socket.send("HTTP/1.1 200 " ~ responseCodesStrings[200] ~ "\r\nStatus: 200 " ~ responseCodesStrings[200] ~ "\r\nContent-Type: text/html\r\n\r\nOK!");
			.writeln("Answer: HTTP/1.1 200 " ~ responseCodesStrings[200] ~ "\r\nStatus: 200 " ~ responseCodesStrings[200] ~ "\r\nContent-Type: text/html\r\n\r\nOK!");
			return true;
		}
		WsApi write(...)
		{
			auto o = "";
			foreach (arg; _arguments)
				if (typeid(string) == arg)
					o ~= va_arg!(string)(_argptr);
				else if (typeid(byte) == arg)
					o ~= to!(string)(va_arg!(byte)(_argptr));
				else if (typeid(short) == arg)
					o ~= to!(string)(va_arg!(short)(_argptr));
				else if (typeid(int) == arg)
					o ~= to!(string)(va_arg!(int)(_argptr));
				else if (typeid(long) == arg)
					o ~= to!(string)(va_arg!(long)(_argptr));
				else if (typeid(ubyte) == arg)
					o ~= to!(string)(va_arg!(ubyte)(_argptr));
				else if (typeid(ushort) == arg)
					o ~= to!(string)(va_arg!(ushort)(_argptr));
				else if (typeid(uint) == arg)
					o ~= to!(string)(va_arg!(uint)(_argptr));
				else if (typeid(ulong) == arg)
					o ~= to!(string)(va_arg!(ulong)(_argptr));
				else if (typeid(float) == arg)
					o ~= to!(string)(va_arg!(float)(_argptr));
				else if (typeid(double) == arg)
					o ~= to!(string)(va_arg!(double)(_argptr));
				else
					throw new Exception("not implemented");
			socket.send(o);
			return this;
		}
		WsApi writef(...) { assert(0); return this;}
		WsApi writeln(...) { assert(0); return this;}
		WsApi writefln(...) { assert(0); return this;}
}

class ConnectionFiber: Fiber
{
	private:
		Connection conn;
		void run ()
		{
			try
			{
				conn();
			}
			catch (Exception e)
			{
				conn.write("HTTP/1.1 500 " ~ WsApi.responseCodesStrings[500] ~ "\r\nStatus: 500 " ~ WsApi.responseCodesStrings[500] ~ "\r\n\r\nInternal Server Error");
				.writeln("Exception: " ~ to!(string)(e));
			}
		}
	public:
		this (Connection conn)
		{
			//this.yield;
			this.conn = conn;
			super(&run);
		}
}

class AppServer
{
	private:
		TcpSocket socket;
		InternetAddress addr;
	public:
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
				foreach (i, ref fiber; fibers)
					if (Fiber.State.TERM == fiber.state)
						idx = i;
				if (-1 == idx)
				{
					idx = fibers.length;
					fibers.length += 1;
				}
				fibers[idx] = new ConnectionFiber(new Connection(socket.accept, tmpDir));
				fibers[idx].call;				
			}
		}
		this (string addr, ushort port, string tmpDir)
		{
			this(new InternetAddress(addr, port), tmpDir);
		}
		this (ushort port, string tmpDir)
		{
			this(new InternetAddress(port), tmpDir);
		}
} 
