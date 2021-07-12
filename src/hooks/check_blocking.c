/* Pi-hole: A black hole for Internet advertisements
*  (c) 2021 Pi-hole, LLC (https://pi-hole.net)
*  Network-wide ad blocking via your own hardware.
*
*  FTL Engine
*  dnsmasq interfacing routines
*
*  This file is copyright under the latest version of the EUPL.
*  Please see LICENSE file for your rights under this license. */

#define FTL_PRIVATE
#include "check_blocking.h"
#include "../config/config.h"
#include "../log.h"
#include "../datastructure.h"
// force_next_DNS_reply
#include "make_answer.h"
// in_allowlist
#include "../database/gravity-db.h"
// getstr
#include "../shmem.h"
// get_blockingstatus
#include "../setupVars.h"
// query_blocked()
#include "query_blocked.h"
// special_domain()
#include "special_domain.h"

static bool check_domain_blocked(const char *domain, const int clientID,
                                 clientsData *client, queriesData *query, DNSCacheData *dns_cache,
                                 unsigned char *new_status)
{
	// Check domains against exactly denied domains
	// Skipped when the domain is allowed
	bool blockDomain = false;
	if(in_denylist(domain, client))
	{
		// We block this domain
		blockDomain = true;
		*new_status = QUERY_DENYLIST;
		blockingreason = "exactly denied";

		// Mark domain as exactly denied for this client
		dns_cache->blocking_status = DENYLIST_BLOCKED;
		return true;
	}

	// Check domains against gravity domains
	// Skipped when the domain is allowed or blocked by exact blacklist
	if(!query->flags.allowed && !blockDomain &&
	   in_gravity(domain, client))
	{
		// We block this domain
		blockDomain = true;
		*new_status = QUERY_GRAVITY;
		blockingreason = "gravity blocked";

		// Mark domain as gravity blocked for this client
		dns_cache->blocking_status = GRAVITY_BLOCKED;
		return true;
	}

	// Check domain against blacklist regex filters
	// Skipped when the domain is allowed or blocked by exact blacklist or gravity
	int regex_idx = 0;
	if(!query->flags.allowed && !blockDomain &&
	   (regex_idx = match_regex(domain, dns_cache, client->id, REGEX_DENY, false)) > -1)
	{
		// We block this domain
		blockDomain = true;
		*new_status = QUERY_REGEX;
		blockingreason = "regex denied";

		// Mark domain as regex matched for this client
		dns_cache->blocking_status = REGEX_BLOCKED;
		dns_cache->deny_regex_id = regex_idx;
		return true;
	}

	// Not blocked
	return false;
}

bool _FTL_check_blocking(int queryID, int domainID, int clientID,
                         const char* file, const int line)
{
	// Only check blocking conditions when global blocking is enabled
	if(get_blockingstatus() == BLOCKING_DISABLED)
	{
		return false;
	}

	// Get query, domain and client pointers
	queriesData *query  = getQuery(queryID,   true);
	domainsData *domain = getDomain(domainID, true);
	clientsData *client = getClient(clientID, true);
	if(query == NULL || domain == NULL || client == NULL || client == NULL)
	{
		log_err("No memory available, skipping query analysis");
		return false;
	}
	unsigned int cacheID = findCacheID(domainID, clientID, query->type);
	DNSCacheData *dns_cache = getDNSCache(cacheID, true);
	if(dns_cache == NULL)
	{
		log_err("No memory available, skipping query analysis");
		return false;
	}

	// Skip the entire chain of tests if we already know the answer for this
	// particular client
	enum domain_client_status blockingStatus = dns_cache->blocking_status;
	char *domainstr = (char*)getstr(domain->domainpos);
	switch(blockingStatus)
	{
		case UNKNOWN_BLOCKED:
			// New domain/client combination.
			// We have to go through all the tests below
			log_debug(DEBUG_QUERIES, "%s is not known", domainstr);

			break;

		case DENYLIST_BLOCKED:
			// Known as exactly denied, we
			// return this result early, skipping
			// all the lengthy tests below
			blockingreason = "exactly denied";
			log_debug(DEBUG_QUERIES, "%s is known as %s", domainstr, blockingreason);

			// Do not block if the entire query is to be permitted
			// as something along the CNAME path hit is explicitly allowed
			if(!query->flags.allowed)
			{
				force_next_DNS_reply = dns_cache->force_reply;
				query_blocked(query, domain, client, QUERY_DENYLIST);
				return true;
			}
			break;

		case GRAVITY_BLOCKED:
			// Known as gravity blocked, we
			// return this result early, skipping
			// all the lengthy tests below
			blockingreason = "gravity blocked";
			log_debug(DEBUG_QUERIES, "%s is known as %s", domainstr, blockingreason);

			// Do not block if the entire query is to be permitted
			// as something along the CNAME path hit is explicitly allowed
			if(!query->flags.allowed)
			{
				force_next_DNS_reply = dns_cache->force_reply;
				query_blocked(query, domain, client, QUERY_GRAVITY);
				return true;
			}
			break;

		case REGEX_BLOCKED:
			// Known as regex denied, we
			// return this result early, skipping
			// all the lengthy tests below
			blockingreason = "regex denied";
			log_debug(DEBUG_QUERIES, "%s is known as %s", domainstr, blockingreason);

			// Do not block if the entire query is to be permitted
			// as something along the CNAME path hit is explicitly allowed
			if(!query->flags.allowed)
			{
				force_next_DNS_reply = dns_cache->force_reply;
				query_blocked(query, domain, client, QUERY_REGEX);
				return true;
			}
			break;

		case ALLOWED:
			// Known as allowed, we
			// return this result early, skipping
			// all the lengthy tests below
			log_debug(DEBUG_QUERIES, "%s is known as not to be blocked (allowed)", domainstr);

			query->flags.allowed = true;

			return false;
			break;

		case SPECIAL_DOMAIN:
			// Known as a special domain, we
			// return this result early, skipping
			// all the lengthy tests below
			blockingreason = "special domain";
			log_debug(DEBUG_QUERIES, "%s is known as special domain", domainstr);

			force_next_DNS_reply = dns_cache->force_reply;
			query_blocked(query, domain, client, QUERY_CACHE);
			return true;
			break;

		case NOT_BLOCKED:
			// Known as not blocked, we
			// return this result early, skipping
			// all the lengthy tests below
			log_debug(DEBUG_QUERIES, "%s is known as not to be blocked", domainstr);

			return false;
			break;
	}

	// Not in FTL's cache. Check if this is a special domain
	if(special_domain(query, domainstr))
	{
		// Set DNS cache properties
		dns_cache->blocking_status = SPECIAL_DOMAIN;
		dns_cache->force_reply = force_next_DNS_reply;

		// Adjust counters
		query_blocked(query, domain, client, QUERY_CACHE);

		// Debug output
		log_debug(DEBUG_QUERIES, "Special domain: %s is %s", domainstr, blockingreason);

		return true;
	}

	// Skip all checks and continue if we hit already at least one allowed domain in the chain
	if(query->flags.allowed)
	{
		log_debug(DEBUG_QUERIES, "Query is permitted as at least one allowlist entry matched");

		return false;
	}

	// Make a local copy of the domain string. The string memory may get
	// reorganized in the following. We cannot expect domainstr to remain
	// valid for all time.
	domainstr = strdup(domainstr);
	const char *blockedDomain = domainstr;

	// Check allowed domains (exact + regex) for match
	query->flags.allowed = in_allowlist(domainstr, dns_cache, client);

	bool blockDomain = false;
	unsigned char new_status = QUERY_UNKNOWN;

	// Check blacklist (exact + regex) and gravity for queried domain
	if(!query->flags.allowed)
	{
		blockDomain = check_domain_blocked(domainstr, clientID, client, query, dns_cache, &new_status);
	}

	// Check blacklist (exact + regex) and gravity for _esni.domain if enabled (defaulting to true)
	if(config.blockESNI && !query->flags.allowed && !blockDomain && strncasecmp(domainstr, "_esni.", 6u) == 0)
	{
		blockDomain = check_domain_blocked(domainstr + 6u, clientID, client, query, dns_cache, &new_status);

		if(blockDomain)
		{
			// Truncate "_esni." from queried domain if the parenting domain was the reason for blocking this query
			blockedDomain = domainstr + 6u;
			// Force next DNS reply to be NXDOMAIN for _esni.* queries
			force_next_DNS_reply = REPLY_NXDOMAIN;
			dns_cache->force_reply = REPLY_NXDOMAIN;
		}
	}

	// Common actions regardless what the possible blocking reason is
	if(blockDomain)
	{
		// Adjust counters
		query_blocked(query, domain, client, new_status);

		// Debug output
		log_debug(DEBUG_QUERIES, "Blocking %s as %s is %s", domainstr, blockedDomain, blockingreason);
	}
	else
	{
		// Explicitly mark as not blocked to skip the entire
		// gravity/blacklist chain when the same client asks
		// for the same domain in the future. Explicitly store
		// domain as allowed if this is the case
		dns_cache->blocking_status = query->flags.allowed ? ALLOWED : NOT_BLOCKED;
	}

	free(domainstr);
	return blockDomain;
}
