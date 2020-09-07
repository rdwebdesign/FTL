/* Pi-hole: A black hole for Internet advertisements
*  (c) 2017 Pi-hole, LLC (https://pi-hole.net)
*  Network-wide ad blocking via your own hardware.
*
*  FTL Engine
*  Argument parsing routines
*
*  This file is copyright under the latest version of the EUPL.
*  Please see LICENSE file for your rights under this license. */

#include "FTL.h"
#include "args.h"
#include "version.h"
#include "memory.h"
#include "main.h"
#include "log.h"
// global variable killed
#include "signals.h"
// regex_speedtest()
#include "regex_r.h"
// init_shmem()
#include "shmem.h"
// run_dhcp_discover()
#include "dhcp-discover.h"

bool dnsmasq_debug = false;
bool daemonmode = true, cli_mode = false;
int argc_dnsmasq = 0;
const char** argv_dnsmasq = NULL;

static inline bool strEndsWith(const char *input, const char *end){
	return strcmp(input + strlen(input) - strlen(end), end) == 0;
}

void parse_args(int argc, char* argv[])
{
	bool quiet = false;
	// Regardless of any arguments, we always pass "-k" (nofork) to dnsmasq
	argc_dnsmasq = 2;
	argv_dnsmasq = calloc(argc_dnsmasq, sizeof(char*));
	argv_dnsmasq[0] = "";
	argv_dnsmasq[1] = "-k";

	bool consume_for_dnsmasq = false;
	// If the binary name is "dnsmasq" (e.g., symlink /usr/bin/dnsmasq -> /usr/bin/pihole-FTL),
	// we operate in drop-in mode and consume all arguments for the embedded dnsmasq core
	if(strEndsWith(argv[0], "dnsmasq"))
		consume_for_dnsmasq = true;

	// start from 1, as argv[0] is the executable name
	for(int i = 1; i < argc; i++)
	{
		bool ok = false;

		// Implement dnsmasq's test function, no need to prepare the entire FTL
		// environment (initialize shared memory, lead queries from long-term
		// database, ...) when the task is a simple (dnsmasq) syntax check
		if(strcmp(argv[i], "dnsmasq-test") == 0 ||
		   strcmp(argv[i], "--test") == 0)
		{
			const char *arg[2];
			arg[0] = "";
			arg[1] = "--test";
			main_dnsmasq(2, arg);
			ok = true;
		}

		// If we find "--" we collect everything behind that for dnsmasq
		if(strcmp(argv[i], "--") == 0)
		{
			// Remember that the rest is for dnsmasq ...
			consume_for_dnsmasq = true;

			// ... and skip the current argument ("--")
			continue;
		}

		// If consume_for_dnsmasq is true, we collect all remaining options for
		// dnsmasq
		if(consume_for_dnsmasq)
		{
			argc_dnsmasq = argc - i + 2;
			if(argv_dnsmasq != NULL)
				free(argv_dnsmasq);

			argv_dnsmasq = calloc(argc_dnsmasq, sizeof(const char*));
			argv_dnsmasq[0] = "";

			if(dnsmasq_debug)
				argv_dnsmasq[1] = "-d";
			else
				argv_dnsmasq[1] = "-k";

			if(dnsmasq_debug)
			{
				printf("dnsmasq options: [0]: %s\n", argv_dnsmasq[0]);
				printf("dnsmasq options: [1]: %s\n", argv_dnsmasq[1]);
			}

			int j = 2;
			while(i < argc)
			{
				argv_dnsmasq[j++] = strdup(argv[i++]);
				if(dnsmasq_debug)
					printf("dnsmasq options: [%i]: %s\n", j-1, argv_dnsmasq[j-1]);
			}

			// Return early: We have consumes all available command line arguments
			return;
		}

		// What follows beyond this point are FTL internal command line arguments

		if(strcmp(argv[i], "d") == 0 ||
		   strcmp(argv[i], "debug") == 0)
		{
			dnsmasq_debug = true;
			daemonmode = false;
			ok = true;

			// Replace "-k" by "-d" (dnsmasq_debug mode implies nofork)
			argv_dnsmasq[1] = "-d";
		}

		if(strcmp(argv[i], "test") == 0)
		{
			killed = 1;
			ok = true;
		}

		if(strcmp(argv[i], "-v") == 0 ||
		   strcmp(argv[i], "version") == 0 ||
		   strcmp(argv[i], "--version") == 0)
		{
			printf("%s\n", get_FTL_version());
			exit(EXIT_SUCCESS);
		}

		if(strcmp(argv[i], "-t") == 0 ||
		   strcmp(argv[i], "tag") == 0)
		{
			printf("%s\n",GIT_TAG);
			exit(EXIT_SUCCESS);
		}

		if(strcmp(argv[i], "-b") == 0 ||
		   strcmp(argv[i], "branch") == 0)
		{
			printf("%s\n",GIT_BRANCH);
			exit(EXIT_SUCCESS);
		}

		// Don't go into background
		if(strcmp(argv[i], "-f") == 0 ||
		   strcmp(argv[i], "no-daemon") == 0)
		{
			daemonmode = false;
			ok = true;
		}

		// Quiet mode
		if(strcmp(argv[i], "-q") == 0)
		{
			quiet = true;
			ok = true;
		}

		// Regex test mode
		if(strcmp(argv[i], "regex-test") == 0)
		{
			// Enable stdout printing
			cli_mode = true;
			if(argc == i + 2)
				exit(regex_test(dnsmasq_debug, quiet, argv[i + 1], NULL));
			else if(argc == i + 3)
				exit(regex_test(dnsmasq_debug, quiet, argv[i + 1], argv[i + 2]));
			else
			{
				printf("pihole-FTL: invalid option -- '%s' need either one or two parameters\nTry '%s --help' for more information\n", argv[i], argv[0]);
				exit(EXIT_FAILURE);
			}
		}

		// Regex test mode
		if(strcmp(argv[i], "dhcp-discover") == 0)
		{
			// Enable stdout printing
			cli_mode = true;
			exit(run_dhcp_discover());
		}

		// List of implemented arguments
		if(strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "help") == 0 || strcmp(argv[i], "--help") == 0)
		{
			printf("pihole-FTL - The Pi-hole FTL engine\n\n");
			printf("Usage:    sudo service pihole-FTL <action>\n");
			printf("where '<action>' is one of start / stop / restart\n\n");
			printf("Available arguments:\n");
			printf("\t    debug           More verbose logging,\n");
			printf("\t                    don't go into daemon mode\n");
			printf("\t    test            Don't start pihole-FTL but\n");
			printf("\t                    instead quit immediately\n");
			printf("\t-v, version         Return version\n");
			printf("\t-t, tag             Return git tag\n");
			printf("\t-b, branch          Return git branch\n");
			printf("\t-f, no-daemon       Don't go into daemon mode\n");
			printf("\t-h, help            Display this help and exit\n");
			printf("\tdnsmasq-test        Test syntax of dnsmasq's\n");
			printf("\t                    config files and exit\n");
			printf("\tregex-test str      Test str against all regular\n");
			printf("\t                    expressions in the database\n");
			printf("\tregex-test str rgx  Test str against regular expression\n");
			printf("\t                    given by rgx\n");
			printf("\tdhcp-discover       Discover DHCP servers in the local\n");
			printf("\t                    network\n");
			printf("\n\nOnline help: https://github.com/pi-hole/FTL\n");
			exit(EXIT_SUCCESS);
		}

		// Return success error code on this undocumented flag
		if(strcmp(argv[i], "--resolver") == 0)
		{
			printf("True\n");
			exit(EXIT_SUCCESS);
		}

		// Complain if invalid options have been found
		if(!ok)
		{
			printf("pihole-FTL: invalid option -- '%s'\nTry '%s --help' for more information\n", argv[i], argv[0]);
			exit(EXIT_FAILURE);
		}
	}
}

// Extended SGR sequence:
//
// "\x1b[%dm"
//
// where %d is one of the following values for commonly supported colors:
//
// 0: reset colors/style
// 1: bold
// 4: underline
// 30 - 37: black, red, green, yellow, blue, magenta, cyan, and white text
// 40 - 47: black, red, green, yellow, blue, magenta, cyan, and white background
//
// https://en.wikipedia.org/wiki/ANSI_escape_code#SGR
//
#define COL_NC		"\x1b[0m"  // normal font
#define COL_BOLD	"\x1b[1m"  // bold font
#define COL_ITALIC	"\x1b[3m"  // italic font
#define COL_ULINE	"\x1b[4m"  // underline font
#define COL_GREEN	"\x1b[32m" // normal foreground color
#define COL_YELLOW	"\x1b[33m" // normal foreground color
#define COL_GRAY	"\x1b[90m" // bright foreground color
#define COL_RED		"\x1b[91m" // bright foreground color
#define COL_BLUE	"\x1b[94m" // bright foreground color
#define COL_PURPLE	"\x1b[95m" // bright foreground color
#define COL_CYAN	"\x1b[96m" // bright foreground color

static inline bool __attribute__ ((const)) is_term(void)
{
	// test whether STDOUT refers to a terminal
	return isatty(fileno(stdout)) == 1;
}

// Returns green [✓]
const char __attribute__ ((const)) *cli_tick(void)
{
	return is_term() ? "["COL_GREEN"✓"COL_NC"]" : "[✓]";
}

// Returns red [✗]
const char __attribute__ ((const)) *cli_cross(void)
{
	return is_term() ? "["COL_RED"✗"COL_NC"]" : "[✗]";
}

// Returns [i]
const char __attribute__ ((const)) *cli_info(void)
{
	return is_term() ? COL_BOLD"[i]"COL_NC : "[i]";
}

// Returns [?]
const char __attribute__ ((const)) *cli_qst(void)
{
	return "[?]";
}

// Returns green "done!""
const char __attribute__ ((const)) *cli_done(void)
{
	return is_term() ? COL_GREEN"done!"COL_NC : "done!";
}

// Sets font to bold
const char __attribute__ ((const)) *cli_bold(void)
{
	return is_term() ? COL_BOLD : "";
}

// Resets font to normal
const char __attribute__ ((const)) *cli_normal(void)
{
	return is_term() ? COL_NC : "";
}
