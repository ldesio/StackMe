
capture program drop gendist

program define gendist

	version 9.0
	
	

*set trace on										// *** STILL NEED WORK ON MULTIPLE PIPES SYNTAX ***
															
											// Command line is on `0'
	gettoken anything postcomma : 0, parse(",")					// Put everything from "," into `postcomma'

	if strrpos("`anything'"," if")>0  {						// See if there is an 'if' component 
		local anything = substr("`anything'",1,strrpos("`anything'"," if"))	// Strip `anything' of `if' clause
		local if = substr("`anything'",strrpos("`anything'"," if"),.) 		// Save to use with (all) varlist(s)
	}
	if substr("`postcomma'",1,1) != ","  {
		display as error("Need list of options, starting with comma")
		exit
	}
	local options = "`postcomma'"							// Save `options' for use with (all) varlist(s)

	

	// Prepare to process each varlist in turn by calling gendistP (the original program)
	
	local pipedsyntax = 0
	
	if (strpos("`anything'",":")!=0 | strpos("`anything'","||")!=0) { // If `anything' has a colon or pipes
		local pipedsyntax = 1
		display _newline "{pstd}{text}Command line suggests multiple varlists to be processed{break}" _newline
	} 
	
	display ".." _continue

	while ("`anything'" != "")  {
		
		if `pipedsyntax' == 0	 {
		
			local postcolon = "`anything'"					// No `postcolon': put `anything' there
			local anything = ""						// End of command if only one varlist
		}
		else  {									// `pipedsyntax' = 1

			gettoken string postpipes:anything, parse("||") 		// 'string' gets all up to "||" or to end of anything

			gettoken thisRef postcolon : string, parse(":") 		// 'thisRef' gets all up to ":" or to end of string

			local colon = 0
			if strlen("`postcolon'")>0  {
				if substr("`postcolon'",1,1) == ":"	local colon = 1	
			}
		
			if `colon' == 0 local thisRef = "`respondent'"			// We check below for no response var optioned
			if `colon' == 0 local postcolon = "`string'"			// No prefix: put varlist where it would have been

		} // endif
	  
	  	
		if "`thisRef'" == "" & strpos("`options'","res") == 0  {
			display as error "Need reference var in option {bf:respondent} if not in varlist prefix"
			exit
		}


		local varlist ""
		foreach var of varlist `postcolon' {					// We put varlist in postcolon even if no colon
			local varlist `varlist' `var'
		}
		
		gendistP `varlist' `if' `options'					// `options' starts with a comma
	
	} // Next pipe-delimited varlist, if any
	
	
	  // Remove following lines from gendistP since they are executed only following the last call on gendistP

	display ""
	display "done."
	
end	

