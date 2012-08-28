-- Prosody IM
-- Copyright (C) 2008-2010 Matthew Wild
-- Copyright (C) 2008-2010 Waqas Hussain
-- 
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--



local hosts = hosts;
local tostring, pairs, ipairs, getmetatable, newproxy, setmetatable
    = tostring, pairs, ipairs, getmetatable, newproxy, setmetatable;

local fire_event = prosody.events.fire_event;
local logger_init = require "util.logger".init;

local log = logger_init("s2smanager");

local config = require "core.configmanager";

local prosody = _G.prosody;
incoming_s2s = {};
prosody.incoming_s2s = incoming_s2s;
local incoming_s2s = incoming_s2s;

module "s2smanager"

local open_sessions = 0;

function new_incoming(conn)
	local session = { conn = conn, type = "s2sin_unauthed", direction = "incoming", hosts = {} };
	if true then
		session.trace = newproxy(true);
		getmetatable(session.trace).__gc = function () open_sessions = open_sessions - 1; end;
	end
	open_sessions = open_sessions + 1;
	session.log = logger_init("s2sin"..tostring(conn):match("[a-f0-9]+$"));
	incoming_s2s[session] = true;
	return session;
end

function new_outgoing(from_host, to_host, connect)
	local host_session = { to_host = to_host, from_host = from_host, host = from_host,
		               notopen = true, type = "s2sout_unauthed", direction = "outgoing" };
	hosts[from_host].s2sout[to_host] = host_session;
	local conn_name = "s2sout"..tostring(host_session):match("[a-f0-9]*$");
	host_session.log = logger_init(conn_name);
	return host_session;
end

function make_authenticated(session, host)
	if not session.secure then
		local local_host = session.direction == "incoming" and session.to_host or session.from_host;
		if config.get(local_host, "core", "s2s_require_encryption") then
			session:close({
				condition = "policy-violation",
				text = "Encrypted server-to-server communication is required but was not "
				       ..((session.direction == "outgoing" and "offered") or "used")
			});
		end
	end
	if session.type == "s2sout_unauthed" then
		session.type = "s2sout";
	elseif session.type == "s2sin_unauthed" then
		session.type = "s2sin";
		if host then
			if not session.hosts[host] then session.hosts[host] = {}; end
			session.hosts[host].authed = true;
		end
	elseif session.type == "s2sin" and host then
		if not session.hosts[host] then session.hosts[host] = {}; end
		session.hosts[host].authed = true;
	else
		return false;
	end
	session.log("debug", "connection %s->%s is now authenticated for %s", session.from_host, session.to_host, host);
	
	mark_connected(session);
	
	return true;
end

-- Stream is authorised, and ready for normal stanzas
function mark_connected(session)
	local sendq, send = session.sendq, session.sends2s;
	
	local from, to = session.from_host, session.to_host;
	
	session.log("info", "%s s2s connection %s->%s complete", session.direction, from, to);

	local event_data = { session = session };
	if session.type == "s2sout" then
		prosody.events.fire_event("s2sout-established", event_data);
		hosts[from].events.fire_event("s2sout-established", event_data);
	else
		local host_session = hosts[to];
		session.send = function(stanza)
			host_session.events.fire_event("route/remote", { from_host = to, to_host = from, stanza = stanza });
		end;

		prosody.events.fire_event("s2sin-established", event_data);
		hosts[to].events.fire_event("s2sin-established", event_data);
	end
	
	if session.direction == "outgoing" then
		if sendq then
			session.log("debug", "sending %d queued stanzas across new outgoing connection to %s", #sendq, session.to_host);
			for i, data in ipairs(sendq) do
				send(data[1]);
				sendq[i] = nil;
			end
			session.sendq = nil;
		end
		
		session.ip_hosts = nil;
		session.srv_hosts = nil;
	end
end

local resting_session = { -- Resting, not dead
		destroyed = true;
		type = "s2s_destroyed";
		open_stream = function (session)
			session.log("debug", "Attempt to open stream on resting session");
		end;
		close = function (session)
			session.log("debug", "Attempt to close already-closed session");
		end;
		filter = function (type, data) return data; end;
	}; resting_session.__index = resting_session;

function retire_session(session, reason)
	local log = session.log or log;
	for k in pairs(session) do
		if k ~= "trace" and k ~= "log" and k ~= "id" and k ~= "conn" then
			session[k] = nil;
		end
	end

	session.destruction_reason = reason;

	function session.send(data) log("debug", "Discarding data sent to resting session: %s", tostring(data)); end
	function session.data(data) log("debug", "Discarding data received from resting session: %s", tostring(data)); end
	return setmetatable(session, resting_session);
end

function destroy_session(session, reason)
	if session.destroyed then return; end
	(session.log or log)("debug", "Destroying "..tostring(session.direction).." session "..tostring(session.from_host).."->"..tostring(session.to_host)..(reason and (": "..reason) or ""));
	
	if session.direction == "outgoing" then
		hosts[session.from_host].s2sout[session.to_host] = nil;
		session:bounce_sendq(reason);
	elseif session.direction == "incoming" then
		incoming_s2s[session] = nil;
	end
	
	local event_data = { session = session, reason = reason };
	if session.type == "s2sout" then
		prosody.events.fire_event("s2sout-destroyed", event_data);
		if hosts[session.from_host] then
			hosts[session.from_host].events.fire_event("s2sout-destroyed", event_data);
		end
	elseif session.type == "s2sin" then
		prosody.events.fire_event("s2sin-destroyed", event_data);
		if hosts[session.to_host] then
			hosts[session.to_host].events.fire_event("s2sin-destroyed", event_data);
		end
	end
	
	retire_session(session, reason); -- Clean session until it is GC'd
	return true;
end

return _M;
