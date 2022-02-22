
capture program drop genplace

program define genplace

version 9.0
	
syntax varlist(min=1) [if] [weight], [PREfix(name)] [STAckid(varname)] [NOStacks] [CONtextvars(varlist)] [CWEight(varname)] [NOReport]

local varlist "plr"
local cweight "votepct"
local stackid "stack"
local contextvars "cid seq"

	if "`if'" != ""  local ifexp = "`if'"					// Call the expression what it is
	else local ifexp = "1"							// Make it true if empty
/*	
	tokenize "`if'"								// Code to use if `if' starts with the word "if" commented out
	macro shift
	local ifexp "`*'"							// Expression following `if', if any
*/
	if ("`stackid'" == "") | ("`nostacks'" != "")  {
		display as error "cweight requires stacked data without nostack option"
		exit
	}
	
	local stkid = "`stackid'"
	if ("`stackid'"=="")  local stkid = "genstacks_stack"
										// Data have not (yet) been stacked
	local pfix = "`prefix'"
	if ("`prefix'"=="") {
		local pfix = "`weight'_"					// NOTE: Especially useful for cweighted variables
		if "`pfix'" == "_"  local pfix = "`cweight'_"
		if "`pfix'" == "_"  local pfix = "p_"
	}
	set more off

										// Create crossed context selector
	capture drop _ctx_temp
	capture label drop _ctx_temp


	if ("`stackid'" != "") & ("`nostacks'" == "") {
		local thisCtxVars = "`contextvars' `stackid'"
	}									// Treat stacks as additional contexts w `if' if any
	else {
		local thisCtxVars = "`contextvars'"
	}
	
	if ("`contextvars'" == "" & "`stackid'" == "") {			// No context vars defined
		gen _ctx_temp = 1						//  so make context always true
	}
	else {
		quietly _mkcross `thisCtxVars' if `ifexp', generate(_ctx_temp) missing
 	}
	local ctxvar = "_ctx_temp"

	
	display "Generating placements of objects identified by `stkid',"
	display "separately within contexts defined by `context'"
	if "`weight'" != "" & "`cweight'" != ""  display "Ignoring item cweight (incompatible with weight)"
	if "`weight'" != "" display "weighting respondents on `weight'..."
	if "`weight'" != "" display "weighting items/stacks on `cweight'"
		
	quietly levelsof `ctxvar', local(contexts)
	foreach context in `contexts' {	
			
		display "{text}{pstd}Context {result:`context'}: Generating: " _continue

		foreach var of varlist `varlist' {

			local destvar = "`pfix'`var'"
			qui gen `destvar' = .
			if "`cweight'" !=""  {					// Item weighting			
				tempvar temp
				quietly summarize `var' if `ctxvar'==`context' & `ifexp', meanonly
				gen `temp' = r(mean)
				quietly summarize `temp' [aweight=`cweight'] if `ctxvar'==`context' & `ifexp', meanonly
				local rmean = r(mean)
			}
			else  {							// Respondent weighting
			
				quietly summarize `var' [aweight=`weight'] if `ctxvar'==`context' & `ifexp', meanonly
				local rmean = r(mean) 
			}
			qui replace `destvar' = `rmean' if `ctxvar'==`context' & `ifexp'
			
			display "`destvar' " _continue				// Terminate line of progress dots
			drop `temp'
	
		} // next var
		
		display _newline
		
	} // next context
	
	drop _ctx_temp
	
end
