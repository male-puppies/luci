-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.
local js = require("cjson")
module("luci.controller.admin.status", package.seeall)

function index()
	entry({"admin", "status"}, alias("admin", "status", "overview"), _("Status"), 20).index = true
	entry({"admin", "status", "overview"}, template("admin_status/index"), _("Overview"), 1)

	entry({"admin", "status", "dhcplease"}, template("admin_status/dhcplease"), _("DHCP列表"), 2)
	entry({"admin", "status", "action_dhcplease"}, call("action_dhcplease")).leaf = true

	entry({"admin", "status", "onlineuserlist"}, template("admin_status/onlineuserlist"), _("在线认证用户"), 3) 
	
	
	--entry({"admin", "status", "iptables"}, call("action_iptables"), _("Firewall"), 2).leaf = true
	entry({"admin", "status", "routes"}, template("admin_status/routes"), _("Routes"), 4)
	entry({"admin", "status", "syslog"}, call("action_syslog"), _("System Log"), 5)
	entry({"admin", "status", "dmesg"}, call("action_dmesg"), _("Kernel Log"), 6)
	--entry({"admin", "status", "processes"}, cbi("admin_status/processes"), _("Processes"), 6)

	entry({"admin", "status", "realtime"}, alias("admin", "status", "realtime", "load"), _("Realtime Graphs"), 7)

	entry({"admin", "status", "realtime", "load"}, template("admin_status/load"), _("Load"), 1).leaf = true
	entry({"admin", "status", "realtime", "load_status"}, call("action_load")).leaf = true

	entry({"admin", "status", "realtime", "bandwidth"}, template("admin_status/bandwidth"), _("Traffic"), 2).leaf = true
	entry({"admin", "status", "realtime", "bandwidth_status"}, call("action_bandwidth")).leaf = true

	--entry({"admin", "status", "realtime", "wireless"}, template("admin_status/wireless"), _("Wireless"), 3).leaf = true
	--entry({"admin", "status", "realtime", "wireless_status"}, call("action_wireless")).leaf = true

	--entry({"admin", "status", "realtime", "connections"}, template("admin_status/connections"), _("Connections"), 4).leaf = true
	--entry({"admin", "status", "realtime", "connections_status"}, call("action_connections")).leaf = true

	entry({"admin", "status", "nameinfo"}, call("action_nameinfo")).leaf = true
end

function action_dhcplease()
	os.execute("lua /ugw/script/lease.lua")
	local fp, err = io.open("/tmp/openwrt_leases.json", "rb")
	if not fp then
		luci.http.write_json({status = 1})
	end
	local s = fp:read("*a")
	fp:close()

	local data = js.decode(s)
	luci.http.write_json({status = 0, data = data})
end

function action_syslog()
	local syslog = luci.sys.syslog()
	local max = 100 * 1024
	if #syslog > max then 
		syslog = syslog:sub(1, max)
	end 
	luci.template.render("admin_status/syslog", {syslog=syslog})
end

function action_dmesg()
	local dmesg = luci.sys.dmesg()
	local max = 100 * 1024
	if #dmesg > max then 
		dmesg = dmesg:sub(1, max)
	end 
	luci.template.render("admin_status/dmesg", {dmesg=dmesg})
end

function action_iptables()
	if luci.http.formvalue("zero") then
		if luci.http.formvalue("zero") == "6" then
			luci.util.exec("ip6tables -Z")
		else
			luci.util.exec("iptables -Z")
		end
		luci.http.redirect(
			luci.dispatcher.build_url("admin", "status", "iptables")
		)
	elseif luci.http.formvalue("restart") == "1" then
		luci.util.exec("/etc/init.d/firewall restart")
		luci.http.redirect(
			luci.dispatcher.build_url("admin", "status", "iptables")
		)
	else
		luci.template.render("admin_status/iptables")
	end
end

function action_bandwidth(iface)
	luci.http.prepare_content("application/json")

	local bwc = io.popen("luci-bwc -i %q 2>/dev/null" % iface)
	if bwc then
		luci.http.write("[")

		while true do
			local ln = bwc:read("*l")
			if not ln then break end
			luci.http.write(ln)
		end

		luci.http.write("]")
		bwc:close()
	end
end

function action_wireless(iface)
	luci.http.prepare_content("application/json")

	local bwc = io.popen("luci-bwc -r %q 2>/dev/null" % iface)
	if bwc then
		luci.http.write("[")

		while true do
			local ln = bwc:read("*l")
			if not ln then break end
			luci.http.write(ln)
		end

		luci.http.write("]")
		bwc:close()
	end
end

function action_load()
	luci.http.prepare_content("application/json")

	local bwc = io.popen("luci-bwc -l 2>/dev/null")
	if bwc then
		luci.http.write("[")

		while true do
			local ln = bwc:read("*l")
			if not ln then break end
			luci.http.write(ln)
		end

		luci.http.write("]")
		bwc:close()
	end
end

function action_connections()
	local sys = require "luci.sys"

	luci.http.prepare_content("application/json")

	luci.http.write("{ connections: ")
	luci.http.write_json(sys.net.conntrack())

	local bwc = io.popen("luci-bwc -c 2>/dev/null")
	if bwc then
		luci.http.write(", statistics: [")

		while true do
			local ln = bwc:read("*l")
			if not ln then break end
			luci.http.write(ln)
		end

		luci.http.write("]")
		bwc:close()
	end

	luci.http.write(" }")
end

function action_nameinfo(...)
	local i
	local rv = { }
	for i = 1, select('#', ...) do
		local addr = select(i, ...)
		local fqdn = nixio.getnameinfo(addr)
		rv[addr] = fqdn or (addr:match(":") and "[%s]" % addr or addr)
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end
