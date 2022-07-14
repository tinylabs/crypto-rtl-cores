/*
 * mor1kx-generic system Verilator testbench
 *
 * Author: Olof Kindgren <olof.kindgren@gmail.com>
 * Author: Franck Jullien <franck.jullien@gmail.com>
 *
 * This program is free software; you can redistribute  it and/or modify it
 * under  the terms of  the GNU General  Public License as published by the
 * Free Software Foundation;  either version 2 of the  License, or (at your
 * option) any later version.
 *
 */

#include <stdint.h>
#include <signal.h>
#include <argp.h>
#include <verilator_utils.h>

#include "VCrypto1Core.h"

// Global bitstream and indices
short eidx = 0, oidx = 0;
uint64_t bitstream = 0;

static bool done;

#define RESET_TIME		4

vluint64_t main_time = 0;       // Current simulation time
// This is a 64-bit integer to reduce wrap over issues and
// allow modulus.  You can also use a double, if you wish.

double sc_time_stamp () {   // Called by $time in Verilog
  return main_time;        // converts to double, to match
                           // what SystemC does
}

void INThandler(int signal)
{
	printf("\nCaught ctrl-c\n");
	done = true;
}

static int parse_opt(int key, char *arg, struct argp_state *state)
{
	switch (key) {
      // Add parsing of custom options here
      case  'b':
        bitstream = strtoull (arg, NULL, 0);
        break;
        
      case  'e':
        eidx = strtoul (arg, NULL, 0);
        break;
        
      case  'o':
        oidx = strtoul (arg, NULL, 0);
        break;

      case ARGP_KEY_INIT:
		state->child_inputs[0] = state->input;
		break;
	}

	return 0;
}


static int parse_args(int argc, char **argv, VerilatorUtils* utils)
{
	struct argp_option options[] = {
      // Add custom options here
      { "bitstream", 'b', "bitstream", 0, "48 bit output stream"},
      { "eidx", 'e', "eidx", 0, "Even index to search"},
      { "oidx", 'o', "oidx", 0, "Odd index to search"},
      { 0 }
	};
	struct argp_child child_parsers[] = {
		{ &verilator_utils_argp, 0, "", 0 },
		{ 0 }
	};
	struct argp argp = { options, parse_opt, 0, 0, child_parsers };

	return argp_parse(&argp, argc, argv, 0, 0, utils);
}

int main(int argc, char **argv, char **env)
{
	uint32_t insn = 0;
	uint32_t ex_pc = 0;
    
	Verilated::commandArgs(argc, argv);

	VCrypto1Core* top = new VCrypto1Core;
	VerilatorUtils* utils =
      new VerilatorUtils();

	parse_args(argc, argv, utils);
	signal(SIGINT, INThandler);
    top->CLK = 0;
    top->RESETn = 0;
	top->trace(utils->tfp, 99);

    // Set bitstream
    top->BITSTREAM = bitstream;

    // Set indices
    top->EIDX = eidx;
    top->OIDX = oidx;

    // Print info
    printf ("Search for %llX @(%u, %u)\n", bitstream, eidx, oidx);
    
	while (utils->doCycle() && !done) {
		if (utils->getTime() > RESET_TIME)
			top->RESETn = 1;

		top->eval();
        top->CLK = !top->CLK;

        // Break when finished
        if (top->DONE)
          break;
	}

    // Print out key
    if (top->VALID)
      printf ("Key found: %llX\n", top->KEY);
    else
      printf ("Key not found...\n");
    
	delete utils;
	exit(0);
}
