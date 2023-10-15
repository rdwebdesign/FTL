#!./test/libs/bats/bin/bats

#@test "Version, Tag, Branch, Hash, Date is reported" {
#  run bash -c 'echo ">version >quit" | nc -v 127.0.0.1 4711'
#  printf "%s\n" "${lines[@]}"
#  [[ ${lines[1]} == "version "* ]]
#  [[ ${lines[2]} == "tag "* ]]
#  [[ ${lines[3]} == "branch "* ]]
#  [[ ${lines[4]} == "hash "* ]]
#  [[ ${lines[5]} == "date "* ]]
#  [[ ${lines[6]} == "" ]]
#}
#
#@test "DNS server port is reported over Telnet API" {
#  run bash -c 'echo ">dns-port >quit" | nc -v 127.0.0.1 4711'
#  printf "%s\n" "${lines[@]}"
#  [[ ${lines[1]} == "53" ]]
#  [[ ${lines[2]} == "" ]]
#}
#
#@test "Maxlogage value is reported over Telnet API" {
#  run bash -c 'echo ">maxlogage >quit" | nc -v 127.0.0.1 4711'
#  printf "%s\n" "${lines[@]}"
#  [[ ${lines[1]} == "86400" ]]
#  [[ ${lines[2]} == "" ]]
#}
#
@test "Running a second instance is detected and prevented" {
  run bash -c 'su pihole -s /bin/sh -c "/home/pihole/pihole-FTL -f"'
  printf "%s\n" "${lines[@]}"
  [[ "${lines[@]}" == *"CRIT: Initialization of shared memory failed."* ]]
  [[ "${lines[@]}" == *"INFO: pihole-FTL is already running"* ]]
}

@test "dnsmasq options as expected" {
  run bash -c './pihole-FTL -vv | grep "cryptohash"'
  printf "%s\n" "${lines[@]}"
  if [[ "${CI_ARCH}" == "x86_64_full" ]]; then
    [[ ${lines[0]} == "Features:        IPv6 GNU-getopt DBus no-UBus no-i18n IDN DHCP DHCPv6 Lua TFTP conntrack ipset nftset auth cryptohash DNSSEC loop-detect inotify dumpfile" ]]
  else
    [[ ${lines[0]} == "Features:        IPv6 GNU-getopt no-DBus no-UBus no-i18n IDN DHCP DHCPv6 Lua TFTP no-conntrack ipset no-nftset auth cryptohash DNSSEC loop-detect inotify dumpfile" ]]
  fi
  [[ ${lines[1]} == "" ]]
}

@test "Starting tests without prior history" {
  run bash -c 'grep -c "Total DNS queries: 0" /var/log/pihole/FTL.log'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
}

@test "Initial blocking status is enabled" {
  run bash -c 'grep -c "Blocking status is enabled" /var/log/pihole/FTL.log'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} != "0" ]]
}

@test "Number of compiled regex filters as expected" {
  run bash -c 'grep "Compiled [0-9]* allow" /var/log/pihole/FTL.log'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == *"Compiled 2 allow and 11 deny regex for 1 client in "* ]]
}

@test "denied domain is blocked" {
  run bash -c "dig denied.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "0.0.0.0" ]]
  [[ ${lines[1]} == "" ]]
}

@test "Gravity domain is blocked" {
  run bash -c "dig gravity.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "0.0.0.0" ]]
  [[ ${lines[1]} == "" ]]
}

@test "Gravity domain is blocked (TCP)" {
  run bash -c "dig gravity.ftl @127.0.0.1 +tcp +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "0.0.0.0" ]]
  [[ ${lines[1]} == "" ]]
}

@test "Gravity domain + allowed exact match is not blocked" {
  run bash -c "dig allowed.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "192.168.1.4" ]]
}

@test "Gravity domain + allowed regex match is not blocked" {
  run bash -c "dig gravity-allowed.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "192.168.1.5" ]]
}

@test "Gravity + antigravity exact matches are not blocked" {
  run bash -c "dig antigravity.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "192.168.1.6" ]]
}

@test "Regex denied match is blocked" {
  run bash -c "dig regex5.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "0.0.0.0" ]]
  [[ ${lines[1]} == "" ]]
}

@test "Regex denylist mismatch is not blocked" {
  run bash -c "dig regexA.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "192.168.2.4" ]]
}

@test "Regex denylist match + allowlist exact match is not blocked" {
  run bash -c "dig regex1.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "192.168.2.1" ]]
}

@test "Regex denylist match + allowlist regex match is not blocked" {
  run bash -c "dig regex2.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "192.168.2.2" ]]
}

@test "Client 2: Gravity match matching unassociated allowlist is blocked" {
  run bash -c "dig allowed.ftl -b 127.0.0.2 @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "0.0.0.0" ]]
}

@test "Client 2: Regex denylist match matching unassociated whitelist is blocked" {
  run bash -c "dig regex1.ftl -b 127.0.0.2 @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "0.0.0.0" ]]
}

@test "Same domain is not blocked for client 1 ..." {
  run bash -c "dig regex1.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "192.168.2.1" ]]
}

@test "... or client 3" {
  run bash -c "dig regex1.ftl -b 127.0.0.3  @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "192.168.2.1" ]]
}

@test "Client 2: Unassociated denylist match is not blocked" {
  run bash -c "dig denied.ftl -b 127.0.0.2 @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "192.168.1.3" ]]
}

@test "Client 3: Exact denylist domain is not blocked" {
  run bash -c "dig denied.ftl -b 127.0.0.3 @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "192.168.1.3" ]]
}

@test "Client 3: Regex denylist domain is not blocked" {
  run bash -c "dig regex1.ftl -b 127.0.0.3 @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "192.168.2.1" ]]
}

@test "Client 3: Gravity domain is not blocked" {
  run bash -c "dig a.ftl -b 127.0.0.3 @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "192.168.1.1" ]]
}

@test "Client 4: Client is recognized by MAC address" {
  run bash -c "dig TXT CHAOS version.bind -b 127.0.0.4 @127.0.0.1 +short"
  run sleep 0.1
  run bash -c "grep -c \"Found database hardware address 127.0.0.4 -> aa:bb:cc:dd:ee:ff\" /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c \"Gravity database: Client aa:bb:cc:dd:ee:ff found. Using groups (4)\" /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} != "0" ]]
  run bash -c "grep -c 'Regex deny: Querying groups for client 127.0.0.4: \"SELECT id from vw_regex_blacklist WHERE group_id IN (4);\"' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c 'Regex allow: Querying groups for client 127.0.0.4: \"SELECT id from vw_regex_whitelist WHERE group_id IN (4);\"' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c 'get_client_querystr: SELECT id from vw_whitelist WHERE domain = ? AND group_id IN (4);' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} != "0" ]]
  run bash -c "grep -c 'get_client_querystr: SELECT id from vw_blacklist WHERE domain = ? AND group_id IN (4);' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} != "0" ]]
  run bash -c "grep -c 'get_client_querystr: SELECT domain from vw_gravity WHERE domain = ? AND group_id IN (4);' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} != "0" ]]
  run bash -c "grep -c 'Regex allow ([[:digit:]]*, DB ID [[:digit:]]*) .* NOT ENABLED for client 127.0.0.4' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "2" ]]
  run bash -c "grep -c 'Regex deny ([[:digit:]]*, DB ID [[:digit:]]*) .* NOT ENABLED for client 127.0.0.4' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "11" ]]
}

@test "Client 5: Client is recognized by MAC address" {
  run bash -c "dig TXT CHAOS version.bind -b 127.0.0.5 @127.0.0.1 +short"
  run sleep 0.1
  run bash -c "grep -c \"Found database hardware address 127.0.0.5 -> aa:bb:cc:dd:ee:ff\" /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c \"Gravity database: Client aa:bb:cc:dd:ee:ff found. Using groups (4)\" /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} != "0" ]]
  run bash -c "grep -c 'Regex deny: Querying groups for client 127.0.0.5: \"SELECT id from vw_regex_blacklist WHERE group_id IN (4);\"' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c 'Regex allow: Querying groups for client 127.0.0.5: \"SELECT id from vw_regex_whitelist WHERE group_id IN (4);\"' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c 'get_client_querystr: SELECT id from vw_whitelist WHERE domain = ? AND group_id IN (4);' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} != "0" ]]
  run bash -c "grep -c 'get_client_querystr: SELECT id from vw_blacklist WHERE domain = ? AND group_id IN (4);' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} != "0" ]]
  run bash -c "grep -c 'get_client_querystr: SELECT domain from vw_gravity WHERE domain = ? AND group_id IN (4);' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} != "0" ]]
  run bash -c "grep -c 'Regex allow ([[:digit:]]*, DB ID [[:digit:]]*) .* NOT ENABLED for client 127.0.0.5' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "2" ]]
  run bash -c "grep -c 'Regex deny ([[:digit:]]*, DB ID [[:digit:]]*) .* NOT ENABLED for client 127.0.0.5' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "11" ]]
}

@test "Client 6: Client is recognized by interface name" {
  run bash -c "dig TXT CHAOS version.bind -b 127.0.0.6 @127.0.0.1 +short"
  run sleep 0.1
  run bash -c "grep -c \"Found database hardware address 127.0.0.6 -> 00:11:22:33:44:55\" /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c \"There is no record for 00:11:22:33:44:55 in the client table\" /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c \"Found database interface 127.0.0.6 -> enp0s123\" /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c \"Gravity database: Client 00:11:22:33:44:55 found (identified by interface enp0s123). Using groups (5)\" /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c 'Regex deny: Querying groups for client 127.0.0.6: \"SELECT id from vw_regex_blacklist WHERE group_id IN (5);\"' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c 'Regex allow: Querying groups for client 127.0.0.6: \"SELECT id from vw_regex_whitelist WHERE group_id IN (5);\"' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c 'get_client_querystr: SELECT id from vw_whitelist WHERE domain = ? AND group_id IN (5);' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c 'get_client_querystr: SELECT id from vw_blacklist WHERE domain = ? AND group_id IN (5);' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c 'get_client_querystr: SELECT domain from vw_gravity WHERE domain = ? AND group_id IN (5);' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c 'Regex allow ([[:digit:]]*, DB ID [[:digit:]]*) .* NOT ENABLED for client 127.0.0.6' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "2" ]]
  run bash -c "grep -c 'Regex deny ([[:digit:]]*, DB ID [[:digit:]]*) .* NOT ENABLED for client 127.0.0.6' /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "11" ]]
}

@test "Normal query (A) is not blocked" {
  run bash -c "dig A a.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "192.168.1.1" ]]
}

@test "Normal query (AAAA) is not blocked (TCP query)" {
  run bash -c "dig AAAA aaaa.ftl @127.0.0.1 +short +tcp"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "fe80::1c01" ]]
}

@test "Mozilla canary domain is blocked with NXDOMAIN" {
  run bash -c "dig A use-application-dns.net @127.0.0.1"
  printf "dig: %s\n" "${lines[@]}"
  [[ ${lines[3]} == *"status: NXDOMAIN"* ]]
  run bash -c 'grep -c "Mozilla canary domain use-application-dns.net is NXDOMAIN" /var/log/pihole/pihole.log'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
}

@test "Local DNS test: A a.ftl" {
  run bash -c "dig A a.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "192.168.1.1" ]]
  [[ ${lines[1]} == "" ]]
}

@test "Local DNS test: AAAA aaaa.ftl" {
  run bash -c "dig AAAA aaaa.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "fe80::1c01" ]]
  [[ ${lines[1]} == "" ]]
}

@test "Local DNS test: ANY any.ftl" {
  run bash -c "dig ANY any.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[@]} == *"192.168.3.1"* ]]
  [[ ${lines[@]} == *"fe80::3c01"* ]]
}

@test "Local DNS test: CNAME cname-ok.ftl" {
  run bash -c "dig CNAME cname-ok.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "a.ftl." ]]
  [[ ${lines[1]} == "" ]]
}

@test "Local DNS test: SRV srv.ftl" {
  run bash -c "dig SRV srv.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "0 1 80 a.ftl." ]]
  [[ ${lines[1]} == "" ]]
}

@test "Local DNS test: SOA ftl" {
  run bash -c "dig SOA ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "ns1.ftl. hostmaster.ftl. 0 10800 3600 604800 3600" ]]
  [[ ${lines[1]} == "" ]]
}

@test "Local DNS test: PTR ptr.ftl" {
  run bash -c "dig PTR ptr.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "ptr.ftl." ]]
  [[ ${lines[1]} == "" ]]
}

@test "Local DNS test: TXT txt.ftl" {
  run bash -c "dig TXT txt.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "\"Some example text\"" ]]
  [[ ${lines[1]} == "" ]]
}

@test "Local DNS test: NAPTR naptr.ftl" {
  run bash -c "dig NAPTR naptr.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[@]} == *'10 10 "u" "smtp+E2U" "!.*([^.]+[^.]+)$!mailto:postmaster@$1!i" .'* ]]
  [[ ${lines[@]} == *'20 10 "s" "http+N2L+N2C+N2R" "" ftl.'* ]]
}

@test "Local DNS test: MX mx.ftl" {
  run bash -c "dig MX mx.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "50 ns1.ftl." ]]
  [[ ${lines[1]} == "" ]]
}

@test "Local DNS test: NS ftl" {
  run bash -c "dig NS ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "ns1.ftl." ]]
  [[ ${lines[1]} == "" ]]
}

@test "Local DNS test: SVCB svcb.ftl" {
  run bash -c "dig SVCB svcb.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == '1 port=\"80\".' ]]
  [[ ${lines[1]} == "" ]]
}

@test "Local DNS test: HTTPS https.ftl" {
  run bash -c "dig HTTPS https.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == '1 . alpn="h3,h2"' ]]
  [[ ${lines[1]} == "" ]]
}

@test "CNAME inspection: Shallow CNAME is blocked" {
  run bash -c "dig A cname-1.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "0.0.0.0" ]]
  [[ ${lines[1]} == "" ]]
}

@test "CNAME inspection: Deep CNAME is blocked" {
  run bash -c "dig A cname-7.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "0.0.0.0" ]]
  [[ ${lines[1]} == "" ]]
}

@test "CNAME inspection: NODATA CNAME targets are blocked" {
  run bash -c "dig A a-cname.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "0.0.0.0" ]]
  [[ ${lines[1]} == "" ]]
  run bash -c "dig AAAA a-cname.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "::" ]]
  [[ ${lines[1]} == "" ]]
  run bash -c "dig A aaaa-cname.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "0.0.0.0" ]]
  [[ ${lines[1]} == "" ]]
  run bash -c "dig AAAA aaaa-cname.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "::" ]]
  [[ ${lines[1]} == "" ]]
}

@test "DNSSEC: SECURE domain is resolved" {
  run bash -c "dig A dnssec.works @127.0.0.1"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[@]} == *"status: NOERROR"* ]]
}

@test "DNSSEC: BOGUS domain is rejected" {
  run bash -c "dig A fail01.dnssec.works @127.0.0.1"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[@]} == *"status: SERVFAIL"* ]]
}

@test "ABP-style matching working as expected" {
  run bash -c "dig A special.gravity.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "0.0.0.0" ]]
  [[ ${lines[1]} == "" ]]
  run bash -c "dig A a.b.c.d.special.gravity.ftl @127.0.0.1 +short"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "0.0.0.0" ]]
  [[ ${lines[1]} == "" ]]
}

@test "pihole-FTL.db schema is as expected" {
  run bash -c './pihole-FTL sqlite3 /etc/pihole/pihole-FTL.db .dump'
  printf "%s\n" "${lines[@]}"
  [[ "${lines[@]}" == *"CREATE TABLE IF NOT EXISTS \"query_storage\" (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp INTEGER NOT NULL, type INTEGER NOT NULL, status INTEGER NOT NULL, domain INTEGER NOT NULL, client INTEGER NOT NULL, forward INTEGER, additional_info INTEGER, reply_type INTEGER, reply_time REAL, dnssec INTEGER, regex_id INTEGER);"* ]]
  [[ "${lines[@]}" == *"CREATE INDEX idx_queries_timestamps ON \"query_storage\" (timestamp);"* ]]
  [[ "${lines[@]}" == *"CREATE TABLE ftl (id INTEGER PRIMARY KEY NOT NULL, value BLOB NOT NULL);"* ]]
  [[ "${lines[@]}" == *"CREATE TABLE counters (id INTEGER PRIMARY KEY NOT NULL, value INTEGER NOT NULL);"* ]]
  [[ "${lines[@]}" == *"CREATE TABLE IF NOT EXISTS \"network\" (id INTEGER PRIMARY KEY NOT NULL, hwaddr TEXT UNIQUE NOT NULL, interface TEXT NOT NULL, firstSeen INTEGER NOT NULL, lastQuery INTEGER NOT NULL, numQueries INTEGER NOT NULL, macVendor TEXT, aliasclient_id INTEGER);"* ]]
  [[ "${lines[@]}" == *"CREATE TABLE IF NOT EXISTS \"network_addresses\" (network_id INTEGER NOT NULL, ip TEXT UNIQUE NOT NULL, lastSeen INTEGER NOT NULL DEFAULT (cast(strftime('%s', 'now') as int)), name TEXT, nameUpdated INTEGER, FOREIGN KEY(network_id) REFERENCES network(id));"* ]]
  [[ "${lines[@]}" == *"CREATE TABLE aliasclient (id INTEGER PRIMARY KEY NOT NULL, name TEXT NOT NULL, comment TEXT);"* ]]
  [[ "${lines[@]}" == *"INSERT INTO ftl VALUES(0,13);"* ]] # Expecting FTL database version 13
  # vvv This has been added in version 10 vvv
  [[ "${lines[@]}" == *"CREATE VIEW queries AS SELECT id, timestamp, type, status, CASE typeof(domain) WHEN 'integer' THEN (SELECT domain FROM domain_by_id d WHERE d.id = q.domain) ELSE domain END domain,CASE typeof(client) WHEN 'integer' THEN (SELECT ip FROM client_by_id c WHERE c.id = q.client) ELSE client END client,CASE typeof(forward) WHEN 'integer' THEN (SELECT forward FROM forward_by_id f WHERE f.id = q.forward) ELSE forward END forward,CASE typeof(additional_info) WHEN 'integer' THEN (SELECT content FROM addinfo_by_id a WHERE a.id = q.additional_info) ELSE additional_info END additional_info, reply_type, reply_time, dnssec, regex_id FROM query_storage q;"* ]]
  [[ "${lines[@]}" == *"CREATE TABLE domain_by_id (id INTEGER PRIMARY KEY, domain TEXT NOT NULL);"* ]]
  [[ "${lines[@]}" == *"CREATE TABLE client_by_id (id INTEGER PRIMARY KEY, ip TEXT NOT NULL, name TEXT);"* ]]
  [[ "${lines[@]}" == *"CREATE TABLE forward_by_id (id INTEGER PRIMARY KEY, forward TEXT NOT NULL);"* ]]
  [[ "${lines[@]}" == *"CREATE UNIQUE INDEX domain_by_id_domain_idx ON domain_by_id(domain);"* ]]
  [[ "${lines[@]}" == *"CREATE UNIQUE INDEX client_by_id_client_idx ON client_by_id(ip,name);"* ]]
  # vvv This has been added in version 11 vvv
  [[ "${lines[@]}" == *"CREATE TABLE addinfo_by_id (id INTEGER PRIMARY KEY, type INTEGER NOT NULL, content NOT NULL);"* ]]
  [[ "${lines[@]}" == *"CREATE UNIQUE INDEX addinfo_by_id_idx ON addinfo_by_id(type,content);"* ]]
}

@test "Ownership, permissions and type of pihole-FTL.db correct" {
  run bash -c 'ls -l /etc/pihole/pihole-FTL.db'
  printf "%s\n" "${lines[@]}"
  # Depending on the shell (x86_64-musl is built on busybox) there can be one or multiple spaces between user and group
  [[ ${lines[0]} == *"pihole"?*"pihole"* ]]
  [[ ${lines[0]} == "-rw-rw-r--"* ]]
  run bash -c 'file /etc/pihole/pihole-FTL.db'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "/etc/pihole/pihole-FTL.db: SQLite 3.x database"* ]]
}

@test "Test fail on invalid CLI argument" {
  run bash -c '/home/pihole/pihole-FTL abc'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "pihole-FTL: invalid option -- 'abc'" ]]
  [[ ${lines[1]} == "Command: '/home/pihole/pihole-FTL abc'" ]]
  [[ ${lines[2]} == "Try '/home/pihole/pihole-FTL --help' for more information" ]]
}

@test "Help CLI argument return help text" {
  run bash -c '/home/pihole/pihole-FTL help'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "The Pi-hole FTL engine - "* ]]
}

#@test "No WARNING messages in FTL.log (besides known capability issues)" {
#  run bash -c 'grep "WARNING" /var/log/pihole/FTL.log'
#  printf "%s\n" "${lines[@]}"
#  run bash -c 'grep "WARNING" /var/log/pihole/FTL.log | grep -c -v -E "CAP_NET_ADMIN|CAP_NET_RAW|CAP_SYS_NICE|CAP_IPC_LOCK|CAP_CHOWN"'
#  printf "%s\n" "${lines[@]}"
#  [[ ${lines[0]} == "0" ]]
#}

#@test "No FATAL messages in FTL.log (besides error due to starting FTL more than once)" {
#  run bash -c 'grep "FATAL" /var/log/pihole/FTL.log'
#  printf "%s\n" "${lines[@]}"
#  run bash -c 'grep "FATAL:" /var/log/pihole/FTL.log | grep -c -v "FATAL: create_shm(): Failed to create shared memory object \"FTL-lock\": File exists"'
#  printf "%s\n" "${lines[@]}"
#  [[ ${lines[0]} == "0" ]]
#}

@test "No \"database not available\" messages in FTL.log" {
  run bash -c 'grep -c "database not available" /var/log/pihole/FTL.log'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "0" ]]
}

# Regex tests
@test "Compiled deny regex as expected" {
  run bash -c 'grep -c "Compiling deny regex 0 (DB ID 6): regex\[0-9\].ftl" /var/log/pihole/FTL.log'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "2" ]]
}

@test "Compiled allow regex as expected" {
  run bash -c 'grep -c "Compiling allow regex 0 (DB ID 3): regex2" /var/log/pihole/FTL.log'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "2" ]]
  run bash -c 'grep -c "Compiling allow regex 1 (DB ID 4): ^gravity-allowed" /var/log/pihole/FTL.log'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "2" ]]
}

@test "Regex Test 1: \"regex7.ftl\" vs. [database regex]: MATCH" {
  run bash -c './pihole-FTL regex-test "regex7.ftl"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "Regex Test 2: \"a\" vs. \"a\": MATCH" {
  run bash -c './pihole-FTL regex-test "a" "a"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "Regex Test 3: \"aa\" vs. \"^[a-z]{1,3}$\": MATCH" {
  run bash -c './pihole-FTL regex-test "aa" "^[a-z]{1,3}$"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "Regex Test 4: \"aaaa\" vs. \"^[a-z]{1,3}$\": NO MATCH" {
  run bash -c './pihole-FTL regex-test "aaaa" "^[a-z]{1,3}$"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 2 ]]
}

@test "Regex Test 5: \"aa\" vs. \"^a(?#some comment)a$\": MATCH (comments)" {
  run bash -c './pihole-FTL regex-test "aa" "^a(?#some comment)a$"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "Regex Test 6: \"abc.abc\" vs. \"([a-z]*)\.\1\": MATCH" {
  run bash -c './pihole-FTL regex-test "abc.abc" "([a-z]*)\.\1"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "Regex Test 7: Complex character set: MATCH" {
  run bash -c './pihole-FTL regex-test "__abc#LMN012$x%yz789*" "[[:digit:]a-z#$%]+"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "Regex Test 8: Range expression: MATCH" {
  run bash -c './pihole-FTL regex-test "!ABC-./XYZ~" "[--Z]+"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "Regex Test 9: Back reference: \"aabc\" vs. \"(a)\1{1,2}\": MATCH" {
  run bash -c './pihole-FTL regex-test "aabc" "(a)\1{1,2}"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "Regex Test 10: Back reference: \"foo\" vs. \"(.)\1$\": MATCH" {
  run bash -c './pihole-FTL regex-test "foo" "(.)\1$"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "Regex Test 11: Back reference: \"foox\" vs. \"(.)\1$\": NO MATCH" {
  run bash -c './pihole-FTL regex-test "foox" "(.)\1$"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 2 ]]
}

@test "Regex Test 12: Back reference: \"1234512345\" vs. \"([0-9]{5})\1\": MATCH" {
  run bash -c './pihole-FTL regex-test "1234512345" "([0-9]{5})\1"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "Regex Test 13: Back reference: \"12345\" vs. \"([0-9]{5})\1\": NO MATCH" {
  run bash -c './pihole-FTL regex-test "12345" "([0-9]{5})\1"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 2 ]]
}

@test "Regex Test 14: Complex back reference: MATCH" {
  run bash -c './pihole-FTL regex-test "cat.foo.dog---cat%dog!foo" "(cat)\.(foo)\.(dog)---\1%\3!\2"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "Regex Test 15: Approximate matching, 0 errors: MATCH" {
  run bash -c './pihole-FTL regex-test "foobarzap" "foo(bar){~1}zap"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "Regex Test 16: Approximate matching, 1 error (inside fault-tolerant area): MATCH" {
  run bash -c './pihole-FTL regex-test "foobrzap" "foo(bar){~1}zap"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "Regex Test 17: Approximate matching, 1 error (outside fault-tolert area): NO MATCH" {
  run bash -c './pihole-FTL regex-test "foxbrazap" "foo(bar){~1}zap"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 2 ]]
}

@test "Regex Test 18: Approximate matching, 0 global errors: MATCH" {
  run bash -c './pihole-FTL regex-test "foobar" "^(foobar){~1}$"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "Regex Test 19: Approximate matching, 1 global error: MATCH" {
  run bash -c './pihole-FTL regex-test "cfoobar" "^(foobar){~1}$"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "Regex Test 20: Approximate matching, 2 global errors: NO MATCH" {
  run bash -c './pihole-FTL regex-test "ccfoobar" "^(foobar){~1}$"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 2 ]]
}

@test "Regex Test 21: Approximate matching, insert + substitute: MATCH" {
  run bash -c './pihole-FTL regex-test "oobargoobaploowap" "(foobar){+2#2~2}"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "Regex Test 22: Approximate matching, insert + delete: MATCH" {
  run bash -c './pihole-FTL regex-test "3oifaowefbaoraofuiebofasebfaobfaorfeoaro" "(foobar){+1 -2}"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "Regex Test 23: Approximate matching, insert + delete (insufficient): NO MATCH" {
  run bash -c './pihole-FTL regex-test "3oifaowefbaoraofuiebofasebfaobfaorfeoaro" "(foobar){+1 -1}"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 2 ]]
}

@test "Regex Test 24: Useful hint for invalid regular expression \"f{x}\": Invalid contents of {}" {
  run bash -c './pihole-FTL regex-test "fbcdn.net" "f{x}"'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[1]} == "Invalid regex CLI filter \"f{x}\": Invalid contents of {}" ]]
  [[ $status == 1 ]]
}

@test "Regex Test 25: Useful hint for invalid regular expression \"a**\": Invalid use of repetition operators" {
  run bash -c './pihole-FTL regex-test "fbcdn.net" "a**"'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[1]} == "Invalid regex CLI filter \"a**\": Invalid use of repetition operators" ]]
  [[ $status == 1 ]]
}

@test "Regex Test 26: Useful hint for invalid regular expression \"x\\\": Trailing backslash" {
  run bash -c './pihole-FTL regex-test "fbcdn.net" "x\\"'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[1]} == "Invalid regex CLI filter \"x\\\": Trailing backslash" ]]
  [[ $status == 1 ]]
}

@test "Regex Test 27: Useful hint for invalid regular expression \"[\": Missing ']'" {
  run bash -c './pihole-FTL regex-test "fbcdn.net" "["'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[1]} == "Invalid regex CLI filter \"[\": Missing ']'" ]]
  [[ $status == 1 ]]
}

@test "Regex Test 28: Useful hint for invalid regular expression \"(\": Missing ')'" {
  run bash -c './pihole-FTL regex-test "fbcdn.net" "("'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[1]} == "Invalid regex CLI filter \"(\": Missing ')'" ]]
  [[ $status == 1 ]]
}

@test "Regex Test 29: Useful hint for invalid regular expression \"{1\": Missing '}'" {
  run bash -c './pihole-FTL regex-test "fbcdn.net" "{1"'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[1]} == "Invalid regex CLI filter \"{1\": Missing '}'" ]]
  [[ $status == 1 ]]
}

@test "Regex Test 30: Useful hint for invalid regular expression \"[[.foo.]]\": Unknown collating element" {
  run bash -c './pihole-FTL regex-test "fbcdn.net" "[[.foo.]]"'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[1]} == "Invalid regex CLI filter \"[[.foo.]]\": Unknown collating element" ]]
  [[ $status == 1 ]]
}

@test "Regex Test 31: Useful hint for invalid regular expression \"[[:foobar:]]\": Unknown character class name" {
  run bash -c './pihole-FTL regex-test "fbcdn.net" "[[:foobar:]]"'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[1]} == "Invalid regex CLI filter \"[[:foobar:]]\": Unknown character class name" ]]
  [[ $status == 1 ]]
}

@test "Regex Test 32: Useful hint for invalid regular expression \"(a)\\2\": Invalid back reference" {
  run bash -c './pihole-FTL regex-test "fbcdn.net" "(a)\\2"'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[1]} == "Invalid regex CLI filter \"(a)\\2\": Invalid back reference" ]]
  [[ $status == 1 ]]
}

@test "Regex Test 33: Useful hint for invalid regular expression \"[g-1]\": Invalid character range" {
  run bash -c './pihole-FTL regex-test "fbcdn.net" "[g-1]"'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[1]} == "Invalid regex CLI filter \"[g-1]\": Invalid character range" ]]
  [[ $status == 1 ]]
}

@test "Regex Test 34: Quiet mode: Match = Return code 0, nothing else" {
  run bash -c './pihole-FTL -q regex-test "fbcdn.net" "f"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "Regex Test 35: Quiet mode: Invalid regex = Return code 1, with error message" {
  run bash -c './pihole-FTL -q regex-test "fbcdn.net" "g{x}"'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "Invalid regex CLI filter \"g{x}\": Invalid contents of {}" ]]
  [[ $status == 1 ]]
}

@test "Regex Test 36: Quiet mode: No Match = Return code 2, nothing else" {
  run bash -c './pihole-FTL -q regex-test "fbcdn.net" "g"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 2 ]]
}

@test "Regex Test 37: Option \";querytype=A\" working as expected (ONLY matching A queries)" {
  run bash -c 'dig A regex-A @127.0.0.1'
  printf "dig A: %s\n" "${lines[@]}"
  run bash -c 'dig A regex-A @127.0.0.1 +short'
  [[ ${lines[0]} == "0.0.0.0" ]]
  run bash -c 'dig AAAA regex-A @127.0.0.1'
  printf "dig AAAA: %s\n" "${lines[@]}"
  run bash -c 'dig AAAA regex-A @127.0.0.1 +short'
  [[ ${lines[0]} != "::" ]]
}

@test "Regex Test 38: Option \";querytype=!A\" working as expected (NOT matching A queries)" {
  run bash -c 'dig A regex-notA @127.0.0.1'
  printf "dig A: %s\n" "${lines[@]}"
  run bash -c 'dig A regex-notA @127.0.0.1 +short'
  [[ ${lines[0]} != "0.0.0.0" ]]
  run bash -c 'dig AAAA regex-notA @127.0.0.1'
  printf "dig AAAA: %s\n" "${lines[@]}"
  run bash -c 'dig AAAA regex-notA @127.0.0.1 +short'
  [[ ${lines[0]} == "::" ]]
}

@test "Regex Test 39: Option \";invert\" working as expected (match is inverted)" {
  run bash -c './pihole-FTL -q regex-test "f" "g;invert"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
  run bash -c './pihole-FTL -q regex-test "g" "g;invert"'
  printf "%s\n" "${lines[@]}"
  [[ $status == 2 ]]
}

@test "Regex Test 40: Option \";querytype\" sanity checks" {
  run bash -c './pihole-FTL regex-test "f" g\;querytype=!A\;querytype=A'
  printf "%s\n" "${lines[@]}"
  [[ "${lines[@]}" == *"Overwriting previous querytype setting (multiple \"querytype=...\" found)"* ]]
}

@test "Regex Test 41: Option \"^;reply=NXDOMAIN\" working as expected" {
  run bash -c 'dig A regex-NXDOMAIN @127.0.0.1'
  printf "dig: %s\n" "${lines[@]}"
  [[ ${lines[3]} == *"status: NXDOMAIN"* ]]
}

@test "Regex Test 42: Option \"^;reply=NODATA\" working as expected" {
  run bash -c 'dig A regex-NODATA @127.0.0.1'
  printf "dig (full): %s\n" "${lines[@]}"
  [[ ${lines[3]} == *"status: NOERROR"* ]]
}

@test "Regex Test 43: Option \";reply=REFUSED\" working as expected" {
  run bash -c 'dig A regex-REFUSED @127.0.0.1'
  printf "dig (full): %s\n" "${lines[@]}"
  [[ ${lines[3]} == *"status: REFUSED"* ]]
}

@test "Regex Test 44: Option \";reply=1.2.3.4\" working as expected" {
  run bash -c 'dig A regex-REPLYv4 @127.0.0.1 +short'
  printf "dig A: %s\n" "${lines[@]}"
  [[ ${lines[0]} == "1.2.3.4" ]]
  run bash -c 'dig AAAA regex-REPLYv4 @127.0.0.1 +short'
  printf "dig AAAA: %s\n" "${lines[@]}"
  [[ ${lines[0]} == "::" ]]
}

@test "Regex Test 45: Option \";reply=fe80::1234\" working as expected" {
  run bash -c 'dig A regex-REPLYv6 @127.0.0.1 +short'
  printf "dig A: %s\n" "${lines[@]}"
  [[ ${lines[0]} == "0.0.0.0" ]]
  run bash -c 'dig AAAA regex-REPLYv6 @127.0.0.1 +short'
  printf "dig AAAA: %s\n" "${lines[@]}"
  [[ ${lines[0]} == "fe80::1234" ]]
}

@test "Regex Test 46: Option \";reply=1.2.3.4;reply=fe80::1234\" working as expected" {
  run bash -c 'dig A regex-REPLYv46 @127.0.0.1 +short'
  printf "dig A: %s\n" "${lines[@]}"
  [[ ${lines[0]} == "1.2.3.4" ]]
  run bash -c 'dig AAAA regex-REPLYv46 @127.0.0.1 +short'
  printf "dig AAAA: %s\n" "${lines[@]}"
  [[ ${lines[0]} == "fe80::1234" ]]
}

@test "Regex Test 47: Option \";querytype=A\" reported on CLI" {
  run bash -c './pihole-FTL regex-test "f" f\;querytype=A'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
  [[ ${lines[5]} == *"- A"* ]]
}

@test "Regex Test 48: Option \";querytype=!TXT\" reported on CLI" {
  run bash -c './pihole-FTL regex-test "f" f\;querytype=!TXT'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
  [[ "${lines[@]}" != *"- TXT"* ]]
}

@test "Regex Test 49: Option \";reply=NXDOMAIN\" reported on CLI" {
  run bash -c './pihole-FTL regex-test "f" f\;reply=NXDOMAIN'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
  [[ ${lines[4]} == "    Hint: This regex forces reply type NXDOMAIN" ]]
}

@test "Regex Test 50: Option \";invert\" reported on CLI" {
  run bash -c './pihole-FTL regex-test "f" g\;invert'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
  [[ ${lines[4]} == "    Hint: This regex is inverted" ]]
}

@test "Regex Test 51: Option \";querytype=A,HTTPS\" reported on CLI" {
  run bash -c './pihole-FTL regex-test "f" f\;querytype=A,HTTPS'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
  [[ ${lines[5]} == *"- A"* ]]
  [[ ${lines[6]} == *"- HTTPS"* ]]
}

@test "Regex Test 52: Option \";querytype=ANY,HTTPS,SVCB;reply=refused\" working as expected (ONLY matching ANY, HTTPS or SVCB queries)" {
  run bash -c 'dig A regex-multiple.ftl @127.0.0.1'
  printf "dig A: %s\n" "${lines[@]}"
  [[ "${lines[@]}" == *"status: NOERROR"* ]]
  run bash -c 'dig AAAA regex-multiple.ftl @127.0.0.1'
  printf "dig AAAA: %s\n" "${lines[@]}"
  [[ "${lines[@]}" == *"status: NOERROR"* ]]
  run bash -c 'dig SVCB regex-multiple.ftl @127.0.0.1'
  printf "dig SVCB: %s\n" "${lines[@]}"
  [[ "${lines[@]}" == *"status: REFUSED"* ]]
  run bash -c 'dig HTTPS regex-multiple.ftl @127.0.0.1'
  printf "dig HTTPS: %s\n" "${lines[@]}"
  [[ "${lines[@]}" == *"status: REFUSED"* ]]
  run bash -c 'dig ANY regex-multiple.ftl @127.0.0.1'
  printf "dig ANY: %s\n" "${lines[@]}"
  [[ "${lines[@]}" == *"status: REFUSED"* ]]
}

@test "Regex Test 53: Option \";querytype=!ANY,HTTPS,SVCB;reply=refused\" working as expected (NOT matching ANY, HTTPS or SVCB queries)" {
  run bash -c 'dig A regex-notMultiple.ftl @127.0.0.1'
  printf "dig A: %s\n" "${lines[@]}"
  [[ "${lines[@]}" == *"status: REFUSED"* ]]
  run bash -c 'dig AAAA regex-notMultiple.ftl @127.0.0.1'
  printf "dig AAAA: %s\n" "${lines[@]}"
  [[ "${lines[@]}" == *"status: REFUSED"* ]]
  run bash -c 'dig SVCB regex-notMultiple.ftl @127.0.0.1'
  printf "dig SVCB: %s\n" "${lines[@]}"
  [[ "${lines[@]}" == *"status: NOERROR"* ]]
  run bash -c 'dig HTTPS regex-notMultiple.ftl @127.0.0.1'
  printf "dig HTTPS: %s\n" "${lines[@]}"
  [[ "${lines[@]}" == *"status: NOERROR"* ]]
  run bash -c 'dig ANY regex-notMultiple.ftl @127.0.0.1'
  printf "dig ANY: %s\n" "${lines[@]}"
  [[ "${lines[@]}" == *"status: NOERROR"* ]]
}

# x86_64-musl is built on busybox which has a slightly different
# variant of ls displaying three, instead of one, spaces between the
# user and group names.

@test "Ownership and permissions of pihole-FTL.db correct" {
  run bash -c 'ls -l /etc/pihole/pihole-FTL.db'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == *"pihole pihole"* || ${lines[0]} == *"pihole   pihole"* ]]
  [[ ${lines[0]} == "-rw-rw-r--"* ]]
}

# "ldd" prints library dependencies and the used interpreter for a given program
#
# Dependencies on shared libraries are displayed like
#    libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x00007fa7d28be000)
#
# In this test, we use ldd and check for the dependency arrow "=>" to check if
# our generated binary depends on shared libraries in the way we expect it to

@test "Dependence on shared libraries" {
  run bash -c 'ldd ./pihole-FTL'
  printf "%s\n" "${lines[@]}"
  [[ "${STATIC}" != "true" && "${lines[@]}" == *"=>"* ]] || \
  [[ "${STATIC}" == "true" && "${lines[@]}" != *"=>"* ]]
}

# "file" determines the file type of our generated binary
#
# We use its ability to test whether a specific interpreter is
# required by the given executable. What the interpreter is, is not
# really well documented in "man elf(5)", however, one can say that
# the interpreter is a program that finds and loads the shared
# libraries needed by a program, prepares the program to run, and then
# runs it.
#
# In this test, we use "file" to confirm the absence of the dependence
# on an interpreter for the static binary.

@test "Dependence on specific interpreter" {
  run bash -c 'file ./pihole-FTL'
  printf "%s\n" "${lines[@]}"
  [[ "${STATIC}" != "true" && "${lines[@]}" == *"interpreter"* ]] || \
  [[ "${STATIC}" == "true" && "${lines[@]}" != *"interpreter"* ]]
}

@test "Architecture is correctly reported on startup" {
  run bash -c 'grep "Compiled for" /var/log/pihole/FTL.log'
  printf "Output: %s\n\$CI_ARCH: %s\nuname -m: %s\n" "${lines[@]:-not set}" "${CI_ARCH:-not set}" "$(uname -m)"
  [[ ${lines[0]} == *"Compiled for ${CI_ARCH:-$(uname -m)}"* ]]
}

@test "Building machine (CI) is reported on startup" {
  [[ ${CI_ARCH} != "" ]] && compiled_str="on CI" || compiled_str="locally" && export compiled_str
  run bash -c 'grep "Compiled for" /var/log/pihole/FTL.log'
  printf "Output: %s\n\$CI_ARCH: %s\n" "${lines[@]:-not set}" "${CI_ARCH:-not set}"
  [[ ${lines[0]} == *"(compiled ${compiled_str})"* ]]
}

@test "Compiler version is correctly reported on startup" {
  compiler_version="$(${CC} --version | head -n1)" && export compiler_version
  run bash -c 'grep "Compiled for" /var/log/pihole/FTL.log'
  printf "Output: %s\n\$CC: %s\nVersion: %s\n" "${lines[@]:-not set}" "${CC:-not set}" "${compiler_version:-not set}"
  [[ ${lines[0]} == *"using ${compiler_version}"* ]]
}

@test "No errors on setting busy handlers for the databases" {
  run bash -c 'grep -c "Cannot set busy handler" /var/log/pihole/FTL.log'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "0" ]]
}

@test "Blocking status is correctly logged in pihole.log" {
  run bash -c 'grep -c "gravity blocked gravity.ftl is 0.0.0.0" /var/log/pihole/pihole.log'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "2" ]]
}

@test "HTTP server responds with JSON error 404 to unknown API path" {
  run bash -c 'curl -s 127.0.0.1/api/undefined'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == '{"error":{"key":"not_found","message":"Not found","hint":"/api/undefined"},"took":'*'}' ]]
}

@test "HTTP server responds with normal error 404 to path outside /admin" {
  run bash -c 'curl -s 127.0.0.1/undefined'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "Error 404: Not Found" ]]
}

@test "LUA: Interpreter returns FTL version" {
  run bash -c './pihole-FTL lua -e "print(pihole.ftl_version())"'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "v"* ]]
}

@test "LUA: Interpreter loads and enabled bundled library \"inspect\"" {
  run bash -c './pihole-FTL lua -e "print(inspect(inspect))"'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[@]} == *'_DESCRIPTION = "human-readable representations of tables"'* ]]
  [[ ${lines[@]} == *'_VERSION = "inspect.lua 3.1.0"'* ]]
}

@test "EDNS(0) analysis working as expected" {
  # Get number of lines in the log before the test
  before="$(grep -c ^ /var/log/pihole/FTL.log)"

  # Run test command
  #                                  CLIENT SUBNET          COOKIE                       MAC HEX                     MAC TEXT                                          CPE-ID
  run bash -c 'dig localhost +short +subnet=192.168.1.1/32 +ednsopt=10:1122334455667788 +ednsopt=65001:000102030405 +ednsopt=65073:41413A42423A43433A44443A45453A4646 +ednsopt=65074:414243444546 @127.0.0.1'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "127.0.0.1" ]]
  [[ $status == 0 ]]

  # Get number of lines in the log after the test
  after="$(grep -c ^ /var/log/pihole/FTL.log)"

  # Extract relevant log lines
  log="$(sed -n "${before},${after}p" /var/log/pihole/FTL.log)"
  printf "%s\n" "${log}"

  # Start actual test
  run bash -c "grep -c \"EDNS0: CLIENT SUBNET: 192.168.1.1/32\"" <<< "${log}"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c \"EDNS0: COOKIE (client-only): 1122334455667788\"" <<< "${log}"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c \"EDNS0: MAC address (BYTE format): 00:01:02:03:04:05\"" <<< "${log}"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c \"EDNS0: MAC address (TEXT format): AA:BB:CC:DD:EE:FF\"" <<< "${log}"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c "grep -c \"EDNS0: CPE-ID (payload size 6): \\\"ABCDEF\\\" (0x41 0x42 0x43 0x44 0x45 0x46)\"" <<< "${log}"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
}

@test "EDNS(0) ECS can overwrite client address (IPv4)" {
  # Get number of lines in the log before the test
  before="$(grep -c ^ /var/log/pihole/FTL.log)"

  # Run test command
  run bash -c 'dig localhost +short +subnet=192.168.47.97/32 @127.0.0.1'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "127.0.0.1" ]]
  [[ $status == 0 ]]

  # Get number of lines in the log after the test
  after="$(grep -c ^ /var/log/pihole/FTL.log)"

  # Extract relevant log lines
  run bash -c "sed -n \"${before},${after}p\" /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ "${lines[@]}" == *"**** new UDP IPv4 query[A] query \"localhost\" from lo/192.168.47.97#53 "* ]]
}

@test "EDNS(0) ECS can overwrite client address (IPv6)" {
  # Get number of lines in the log before the test
  before="$(grep -c ^ /var/log/pihole/FTL.log)"

  # Run test command
  run bash -c 'dig localhost +short +subnet=fe80::b167:af1e:968b:dead/128 @127.0.0.1'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "127.0.0.1" ]]
  [[ $status == 0 ]]

  # Get number of lines in the log after the test
  after="$(grep -c ^ /var/log/pihole/FTL.log)"

  # Extract relevant log lines
  run bash -c "sed -n \"${before},${after}p\" /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ "${lines[@]}" == *"**** new UDP IPv4 query[A] query \"localhost\" from lo/fe80::b167:af1e:968b:dead#53 "* ]]
}

@test "alias-client is imported and used for configured client" {
  run bash -c 'grep -c "Added alias-client \"some-aliasclient\" (aliasclient-0) with FTL ID 0" /var/log/pihole/FTL.log'
  printf "Added: %s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c 'grep -c "Aliasclient ID 127.0.0.6 -> 0" /var/log/pihole/FTL.log'
  printf "Found ID: %s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
  run bash -c 'grep -c "Client .* (127.0.0.6) IS  managed by this alias-client, adding counts" /var/log/pihole/FTL.log'
  printf "Adding counts: %s\n" "${lines[@]}"
  [[ ${lines[0]} == "1" ]]
}

@test "EDNS(0) ECS skipped for loopback address (IPv4)" {
  # Get number of lines in the log before the test
  before="$(grep -c ^ /var/log/pihole/FTL.log)"

  # Run test command
  run bash -c 'dig localhost +short +subnet=127.0.0.1/32 @127.0.0.1'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "127.0.0.1" ]]
  [[ $status == 0 ]]

  # Get number of lines in the log after the test
  after="$(grep -c ^ /var/log/pihole/FTL.log)"

  # Extract relevant log lines
  run bash -c "sed -n \"${before},${after}p\" /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ "${lines[@]}" == *"EDNS0: CLIENT SUBNET: Skipped 127.0.0.1/32 (IPv4 loopback address)"* ]]
}

@test "EDNS(0) ECS skipped for loopback address (IPv6)" {
  # Get number of lines in the log before the test
  before="$(grep -c ^ /var/log/pihole/FTL.log)"

  # Run test command
  run bash -c 'dig localhost +short +subnet=::1/128 @127.0.0.1'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "127.0.0.1" ]]
  [[ $status == 0 ]]

  # Get number of lines in the log after the test
  after="$(grep -c ^ /var/log/pihole/FTL.log)"

  # Extract relevant log lines
  run bash -c "sed -n \"${before},${after}p\" /var/log/pihole/FTL.log"
  printf "%s\n" "${lines[@]}"
  [[ "${lines[@]}" == *"EDNS0: CLIENT SUBNET: Skipped ::1/128 (IPv6 loopback address)"* ]]
}

@test "Embedded SQLite3 shell available and functional" {
  run bash -c './pihole-FTL sqlite3 -help'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "Usage: sqlite3 [OPTIONS] [FILENAME [SQL]]" ]]
}

@test "Embedded SQLite3 shell is called for .db file" {
  run bash -c './pihole-FTL abc.db ".version"'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "SQLite 3."* ]]
}

@test "Embedded SQLite3 shell prints FTL version in interactive mode" {
  # shell.c contains a call to print_FTL_version
  run bash -c "echo -e '.quit\n' | ./pihole-FTL sqlite3 -interactive"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "Pi-hole FTL"* ]]
}

@test "Embedded LUA engine is called for .lua file" {
  echo 'print("Hello from LUA")' > abc.lua
  run bash -c './pihole-FTL abc.lua'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "Hello from LUA" ]]
  rm abc.lua
}

@test "Pi-hole PTR generation check" {
  run bash -c "bash test/hostnames.sh | tee ptr.log"
  printf "%s\n" "${lines[@]}"
  [[ "${lines[@]}" != *"ERROR"* ]]
}

@test "No ERROR messages in FTL.log (besides known index.html error)" {
  run bash -c 'grep "ERR: " /var/log/pihole/FTL.log'
  printf "%s\n" "${lines[@]}"
  run bash -c 'grep "ERR: " /var/log/pihole/FTL.log | grep -c -v -E "(index\.html)|(Failed to create shared memory object)"'
  printf "count: %s\n" "${lines[@]}"
  [[ ${lines[0]} == "0" ]]
}

@test "No CRIT messages in FTL.log (besides error due to testing to start FTL more than once)" {
  run bash -c 'grep "CRIT: " /var/log/pihole/FTL.log'
  printf "%s\n" "${lines[@]}"
  run bash -c 'grep "CRIT: " /var/log/pihole/FTL.log | grep -c -v "Initialization of shared memory failed."'
  printf "count: %s\n" "${lines[@]}"
  [[ ${lines[0]} == "0" ]]
}

@test "No config errors in pihole.toml" {
  run bash -c 'grep "DEBUG_CONFIG: " /var/log/pihole/FTL.log'
  printf "%s\n" "${lines[@]}"
  run bash -c 'grep "DEBUG_CONFIG: " /var/log/pihole/FTL.log | grep -c "DOES NOT EXIST"'
  printf "DOES NOT EXIST count: %s\n" "${lines[@]}"
  [[ ${lines[0]} == "0" ]]
}

@test "Check dnsmasq warnings in source code" {
  run bash -c "bash test/dnsmasq_warnings.sh"
  printf "%s\n" "${lines[@]}"
  [[ "${lines[0]}" == "" ]]
}

@test "Pi-hole uses dns.reply.host.IPv4/6 for pi.hole" {
  run bash -c "dig A pi.hole +short @127.0.0.1"
  printf "A: %s\n" "${lines[@]}"
  [[ "${lines[0]}" == "10.100.0.10" ]]
  run bash -c "dig AAAA pi.hole +short @127.0.0.1"
  printf "AAAA: %s\n" "${lines[@]}"
  [[ "${lines[0]}" == "fe80::10" ]]
}

@test "Pi-hole uses dns.reply.host.IPv4/6 for hostname" {
  run bash -c "dig A $(hostname) +short @127.0.0.1"
  printf "A: %s\n" "${lines[@]}"
  [[ "${lines[0]}" == "10.100.0.10" ]]
  run bash -c "dig AAAA $(hostname) +short @127.0.0.1"
  printf "AAAA: %s\n" "${lines[@]}"
  [[ "${lines[0]}" == "fe80::10" ]]
}

@test "Pi-hole uses dns.reply.blocking.IPv4/6 for blocked domain" {
  run bash -c 'grep "mode = \"NULL\"" /etc/pihole/pihole.toml'
  printf "grep output: %s\n" "${lines[@]}"
  [[ "${lines[0]}" == '    mode = "NULL"' ]]
  run bash -c './pihole-FTL --config dns.blocking.mode IP'
  printf "setting config: %s\n" "${lines[@]}"
  run bash -c 'grep "mode = \"IP" /etc/pihole/pihole.toml'
  printf "grep output (before reload): %s\n" "${lines[@]}"
  [[ "${lines[0]}" == *'mode = "IP" ### CHANGED, default = "NULL"' ]]
  run bash -c "kill -HUP $(cat /run/pihole-FTL.pid)"
  sleep 1
  run bash -c 'grep "mode = \"IP" /etc/pihole/pihole.toml'
  printf "grep output (after reload): %s\n" "${lines[@]}"
  [[ "${lines[0]}" == *'mode = "IP" ### CHANGED, default = "NULL"' ]]
  run bash -c "dig A denied.ftl +short @127.0.0.1"
  printf "A: %s\n" "${lines[@]}"
  [[ "${lines[0]}" == "10.100.0.11" ]]
  run bash -c "dig AAAA denied.ftl +short @127.0.0.1"
  printf "AAAA: %s\n" "${lines[@]}"
  [[ "${lines[0]}" == "fe80::11" ]]
}

@test "Antigravity domain is not blocked" {
  run bash -c "dig A antigravity.ftl +short @127.0.0.1"
  printf "A: %s\n" "${lines[@]}"
  [[ "${lines[0]}" == "192.168.1.6" ]]
}

@test "Antigravity ABP-domain is not blocked" {
  run bash -c "dig A x.y.z.abp.antigravity.ftl +short @127.0.0.1"
  printf "A: %s\n" "${lines[@]}"
  [[ "${lines[0]}" == "192.168.1.7" ]]
}

@test "API domain search: Non-existing domain returns expected JSON" {
  run bash -c 'curl -s 127.0.0.1/api/search/non.existent'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == '{"search":{"domains":[],"gravity":[],"results":{"domains":{"exact":0,"regex":0},"gravity":{"allow":0,"block":0},"total":0},"parameters":{"N":20,"partial":false,"domain":"non.existent","debug":false}},"took":"took":'*'}' ]]
}

@test "API domain search: antigravity.ftl returns expected JSON" {
  run bash -c 'curl -s 127.0.0.1/api/search/antigravity.ftl'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == '{"search":{"domains":[],"gravity":[{"domain":"antigravity.ftl","type":"block","address":"https://pi-hole.net/block.txt","comment":"Fake block-list","enabled":true,"id":1,"date_added":1559928803,"date_modified":1559928803,"type":"block","date_updated":1559928803,"number":2000,"invalid_domains":2,"abp_entries":0,"status":1,"groups":[0,2]},{"domain":"antigravity.ftl","type":"allow","address":"https://pi-hole.net/allow.txt","comment":"Fake allow-list","enabled":true,"id":2,"date_added":1559928803,"date_modified":1559928803,"type":"allow","date_updated":1559928803,"number":2000,"invalid_domains":2,"abp_entries":0,"status":1,"groups":[0]},{"domain":"@@||antigravity.ftl^","type":"allow","address":"https://pi-hole.net/allow.txt","comment":"Fake allow-list","enabled":true,"id":2,"date_added":1559928803,"date_modified":1559928803,"type":"allow","date_updated":1559928803,"number":2000,"invalid_domains":2,"abp_entries":0,"status":1,"groups":[0]}],"results":{"domains":{"exact":0,"regex":0},"gravity":{"allow":2,"block":1},"total":3},"parameters":{"N":20,"partial":false,"domain":"antigravity.ftl","debug":false}},"took":'*'}' ]]
}

@test "API authorization (without password): No login required" {
  run bash -c 'curl -s 127.0.0.1/api/auth'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == '{"session":{"valid":true,"totp":false,"sid":null,"validity":-1},"took":'*'}' ]]
}

@test "API authorization: Setting password" {
  # Password: ABC
  run bash -c 'curl -s -X PATCH http://127.0.0.1/api/config/webserver/api/password -d "{\"config\":{\"webserver\":{\"api\":{\"password\":\"ABC\"}}}}"'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "{\"config\":{\"webserver\":{\"api\":{\"password\":\"********\"}}},\"took\":"*"}" ]]
}

@test "API authorization (with password): Incorrect password is rejected if password auth is enabled" {
  # Password: ABC
  run bash -c 'curl -s -X POST 127.0.0.1/api/auth -d "{\"password\":\"XXX\"}" | jq .session.valid'
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "false" ]]
}

@test "API authorization (with password): Correct password is accepted" {
  session="$(curl -s -X POST 127.0.0.1/api/auth -d "{\"password\":\"ABC\"}")"
  printf "Session: %s\n" "${session}"
  run jq .session.valid <<< "${session}"
  printf "%s\n" "${lines[@]}"
  [[ ${lines[0]} == "true" ]]
}

@test "Test TLS/SSL server using self-signed certificate" {
  # -s: silent
  # -I: HEAD request
  # --cacert: use this CA certificate to verify the server certificate
  # --resolve: resolve pi.hole:443 to 127.0.0.1
  #            we need this line because curl is not using FTL as resolver
  #            and would otherwise not be able to resolve pi.hole
  run bash -c 'curl -sI --cacert /etc/pihole/test.crt --resolve pi.hole:443:127.0.0.1 https://pi.hole/'
  printf "%s\n" "${lines[@]}"
  [[ "${lines[0]}" == "HTTP/1.1 "* ]]
  run bash -c 'curl -I --cacert /etc/pihole/test.crt --resolve pi.hole:443:127.0.0.1 https://pi.hole/'
}

@test "Test embedded GZIP compressor" {
  run bash -c './pihole-FTL gzip test/pihole-FTL.db.sql'
  printf "Compression output:\n"
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
  [[ ${lines[0]} == "Compressed test/pihole-FTL.db.sql (2.0KB) to test/pihole-FTL.db.sql.gz (689.0B), 66.0% size reduction" ]]
  printf "Uncompress (FTL) output:\n"
  run bash -c './pihole-FTL gzip test/pihole-FTL.db.sql.gz test/pihole-FTL.db.sql.1'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
  [[ ${lines[0]} == "Uncompressed test/pihole-FTL.db.sql.gz (677.0B) to test/pihole-FTL.db.sql.1 (2.0KB), 199.3% size increase" ]]
  printf "Uncompress (gzip) output:\n"
  run bash -c 'gzip -dkc test/pihole-FTL.db.sql.gz > test/pihole-FTL.db.sql.2'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
  printf "Remove generated GZIP file:\n"
  run bash -c 'rm test/pihole-FTL.db.sql.gz'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
  printf "Compare uncompressed files (original vs. FTL uncompressed):\n"
  run bash -c 'cmp test/pihole-FTL.db.sql test/pihole-FTL.db.sql.1'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
  printf "Compare uncompressed files (original vs. gzip uncompressed):\n"
  run bash -c 'cmp test/pihole-FTL.db.sql test/pihole-FTL.db.sql.2'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
  printf "Remove generated files:\n"
  run bash -c 'rm test/pihole-FTL.db.sql.[1-2]'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "API validation" {
  run python3 test/api/checkAPI.py
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
}

@test "CLI config output as expected" {
  # Partial match printing
  run bash -c './pihole-FTL --config dns.upstream'
  printf "%s\n" "${lines[@]}"
  [[ "${lines[0]}" == "dns.upstreams = [ 127.0.0.1#5555 ]" ]]

  # Exact match printing
  run bash -c './pihole-FTL --config dns.upstreams'
  printf "%s\n" "${lines[@]}"
  [[ "${lines[0]}" == "[ 127.0.0.1#5555 ]" ]]
  run bash -c './pihole-FTL --config dns.piholePTR'
  printf "%s\n" "${lines[@]}"
  [[ "${lines[0]}" == "PI.HOLE" ]]
  run bash -c './pihole-FTL --config dns.hosts'
  printf "%s\n" "${lines[@]}"
  [[ "${lines[0]}" == "[]" ]]
  run bash -c './pihole-FTL --config webserver.port'
  printf "%s\n" "${lines[@]}"
  [[ "${lines[0]}" == "80,[::]:80,443s" ]]
}

@test "Create, verify and re-import Teleporter file via CLI" {
  run bash -c './pihole-FTL --teleporter'
  printf "%s\n" "${lines[@]}"
  [[ $status == 0 ]]
  # Get filename from last line printed by FTL
  filename="${lines[-1]}"
#  run bash -c 'zipinfo ${filename}'
#  printf "%s\n" "${lines[@]}"
#  [[ $status == 0 ]]
  run bash -c "./pihole-FTL --teleporter ${filename}"
  printf "%s\n" "${lines[@]}"
  [[ "${lines[-3]}" == "Imported etc/pihole/pihole.toml" ]]
  [[ "${lines[-2]}" == "Imported etc/pihole/dhcp.leases" ]]
  [[ "${lines[-1]}" == "Imported etc/pihole/gravity.db" ]]
  [[ $status == 0 ]]
  run bash -c "rm ${filename}"
}
