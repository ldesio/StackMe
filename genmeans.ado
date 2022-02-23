
capture program drop genmeans

program define genmeans

version 9.0
	
syntax varlist(min=1) [if] [weight], [PREfix(name)] [STAckid(varname)] [NOStacks] [CONtextvars(varlist)] [CWEight(varname)] [NOReport] [BY(varlist)]

	if "`by'" != ""  {
		display as error("genmeans does not accept option by(varlist); use contextvars(varlist)")
		exit
	}

	if "`if'" != ""  local ifexp = "`if'"				// Call the expression what it is
	else local ifexp = "1"						// Make it true if empty
/*	
	tokenize "`if'"							// Code to use if `if' starts with the word "if"
	macro shift
	local ifexp "`*'"						// Expression following `if', if any
*/
	if ("`"`cweight'" != "")  {
		display as error "cweight not permitted for genmeans (used in genplace)"
		exit
	}
	
	local stkid = "`stackid'"
	if ("`stackid'"=="")  local stkid = "genstacks_stack"
									// Data have not (yet) been stacked
	local pfix = "`prefix'"
	if ("`prefix'"=="") {
		local pfix = "`weight'_"				// NOTE: Especially useful for cweighted variables
		if "`pfix'" == "_"  local pfix = "`cweight'_"
		if "`pfix'" == "_"  local pfix = "p_"
	}
	set more off

									// Create crossed context selector
	capture drop _ctx_temp
	capture label drop _ctx_temp


	if ("`stackid'" != "") & ("`nostacks'" == "") {
		local thisCtxVars = "`contextvars' `stackid'"
	}								// Treat stacks as additional contexts w `if' if any
	else {								// NOTE: `if' is constant across contexts
		local thisCtxVars = "`contextvars'"
	}
	
	if ("`contextvars'" == "" & "`stackid'" == "") {		// No context vars defined
		gen _ctx_temp = 1					//  so make context always true
	}
	else {
		quietly _mkcross `thisCtxVars' if `ifexp', generate(_ctx_temp) missing
 	}
	local ctxvar = "_ctx_temp"

	
	display "Generating means of objects identified by `stkid',"
	display "separately within contexts defined by `context'"
	if "`weight'" != "" display "weighting respondents on `weight'..."
		
	quietly levelsof `ctxvar', local(contexts)
	foreach context in `contexts' {	
			
		display "{text}{pstd}Context {result:`context'}: Generating: " _continue
*set trace on
		foreach var of varlist `varlist' {

			local destvar = "`pfix'`var'"
			qui gen `destvar' = .
			if "`cweight'" !=""  {				// cweight always empty for genmeans			
				tempvar temp
				quietly summarize `var' if `ctxvar'==`context', meanonly
				gen `temp' = r(mean)
				quietly summarize `temp' [aweight=`cweight'] if `ctxvar'==`context' & `ifexp', meanonly
				local rmean = r(mean)
			}
			else  {						// Respondent weighting
				quietly summarize `var' [aweight=`weight'] if `ctxvar'==`context' & `ifexp', meanonly
				local rmean = r(mean) 
			}
			qui replace `destvar' = `rmean' if `ctxvar'==`context' & `ifexp'
			display "`destvar' " _continue
			drop `temp'
	
		}
		display _newline
	}		
	drop _ctx_temp
	
end
