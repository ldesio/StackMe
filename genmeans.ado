
capture program drop genmeans

program define genmeans

version 9.1 

syntax varlist(min=1) [aw pw iw fw] [if/], [CWEight(varname)] [CONtextvars(varlist)] [STAckid(varname)] [NOStacks]
									// If/ puts expression into `if' instead of `ixp'


	local stkid = "`stackid'"					// Establish whether the data are stacked
	if ("`stackid'"=="")  {
		local stkid = "genstacks_stack"
		capture confirm string variable `stkid'
		if _rc>0  local stkid = ""				// There is no genstacks_stack variable
	}

	
	if "`weight'" != ""  {						// Defined in [aw pw iw fw]
		tokenize `weight', parse("=")
		if "`1'" != ""   {
			if "`1'" != "aweight"  {
				display as error "genmeans only allows a-weights"
				exit
			}
		}

		local wtvar = "`2'"					// Second token has what came after the "=" sign
	}
	
	
	if "`if'" != ""  local ifexp = "`if'"				// Call the expression what it is
	else local ifexp = "1"						// Make it true if empty
/*	
	tokenize "`if'"							// Code to use if `if' starts with the word "if"
	macro shift
	local ifexp "`*'"						// Expression following `if', if any
*/

	if "`cweight'" != "" & "`stkid'" == ""  {
		display as error "Cannot have cweight with unstacked data"
		exit
	}

	local pfix = "`prefix'"
	if ("`prefix'"=="") {
		local pfix = "`cweight'_"				// NOTE: Useful for naming substantively weighted means
		if "`pfix'" == "_"  local pfix = "`cweight'_"
		if "`pfix'" == "_"  local pfix = "p_"	// NOTE: a "_" pfix is an empty pfix (see line above)
	}

	set more off
	
									// Data have not (yet) been stacked

							
	capture drop _ctx_temp						// Drop any existing context selector
	capture label drop _ctx_temp


	if ("`stackid'" != "") & ("`nostacks'" == "") {
		local thisCtxVars = "`contextvars' `stackid'"
	}								// Treat stacks as additional contexts

	else {								// NOTE: `if' is constant across contexts
		local thisCtxVars = "`contextvars'"
	}
	
	if ("`contextvars'" == "" & "`stackid'" == "") {
		gen _ctx_temp = 1					//  Make context always true if no contexts or stacks
	}

	else {
	    noisily display "..." _continue
		quietly _mkcross `thisCtxVars' if `ifexp', generate(_ctx_temp) missing
 	}

	local ctxvar = "_ctx_temp"

									// MAYBE we should refer to placements only in genplace?
	if "`stkid'" != ""  display _newline "Generating placements of objects identified by `stkid',"
	else display _newline "Generating means of variables in varlist,"
	display "separately within contexts defined by `contextvars.'"
	if `ifexp' != 1  display "Selecting on `ifexp'"
*	if "`weight'" != "" & "`cweight'" != ""  display "Ignoring cweight (incompatible with weight)"
	if "`weight'" != "" display "Weighting respondents on `weight'"
	if "`cweight'" != "" display "Weighting items/stacks on `cweight'"
		

	foreach var of varlist `varlist' {

		local destvar = "`pfix'`var'"
		capture drop `destvar'
		qui gen `destvar' = .
		display _newline "Newvar `destvar'  " _continue
*		display "{text}{pstd}Context {result:`context'}: Generating: " _continue // Keep this syntax
		quietly levelsof `ctxvar', local(contexts)

		
		foreach context in `contexts' {	
			
			if "`cweight'" != ""  {				// Item weighting happens in two stages:

				tempvar temp				// (1) get means across respondents (can be weighted)

				if "`weight'" == "" quietly summarize `var' if `ctxvar'==`context', meanonly
				else quietly summarize `var' [aw=weight] if `ctxvar'==`context', meanonly

				quietly gen `temp' = r(mean)		// (2) Average those placements within contexts

				if "`cweight'" == "" quietly summarize `temp' if `ctxvar'==`context' & `ifexp', meanonly
				else qui summarize `temp' [aweight=`cweight'] if `ctxvar'==`context' & `ifexp', meanonly

				local rmean = r(mean)			// cweights can be combined with respondent weights

				drop `temp'				// NOTE: Mean resp positns are equivlane to expert-
									//       rated positns, constant across respondents
			}						//       (and often coded as such in, eg, CSES data)

			else  {	

				if "`weight'" != ""	 {		// Respondent weighting
					quietly summarize `var' [aw=`weight'] if `ctxvar'==`context' & `ifexp', meanonly
					local rmean = r(mean) 		// Respondent weighting only happens if no cweight
				}

				else  {					// Unweighted
					quietly summarize `var' if `ctxvar'==`context' & `ifexp', meanonly
					local rmean = r(mean) 					
				}
				
			}
			if `rmean'!=.  qui replace `destvar' = `rmean' if `ctxvar'==`context' & `ifexp'
			if trunc(`context'/5)*5 ==`context'  display "." _continue
		}
		
	} // next var	

	drop _ctx_temp
	display " "
	
end
