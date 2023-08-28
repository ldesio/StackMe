capture program drop genplaceP

program define genplaceP
												// stackmeWrapper extracted working data before calling `genyplaceP', 
												//  afterwards it will merge the results back into the origial dataset
												
*! genplaceP version 2 for Stata version 9.0 (8/25/23 by Mark) processes multi-varlists prepared by stackmeWrapper 


												// (0) genplaceP version 2 preliminaries
	version 9.0
set trace on	
	syntax varlist [aw fw pw/], [ CONtextvars(varlist) STAckid(varname) PPRefix(name) CWEight(name) MPRefix(name) ]	///
				   [ CALl(string) LIMitdiag(integer -1) TWOstep /ctxvar(string) nc(integer 0) c(integer 0) nvarlst(integer 1) ]
				   
	
	
	
	
												// (1) deal with wts/optns (these are the same for all varlists in set)

	if "`weight'" !="" local wt = "[weight`exp']"				// Establish weight directive, if present

	if "`pprefix'"==""  local pprefix = "p_"					// Apply default prefixes, if needed
	if "`mprefix'"==""  local mprefix = "m_"
	
	if "`cweight'"!=""  local cweight = [weight=`cweight']
	
	if `limitdiag'==-1  local limitdiag = .						// If diagnostics not limited set to really big number
	

	
	
	// HERE STARTS PROCESSING OF CURRENT CONTEXT . . .
	
		local contextlabel : label (`ctxvar') `c'				// Retrieve the label for this context built by _mkcross
		
			
											// (2) Cycle thru all varlists included in this call on `cmd'P

		forvalues nvl = 1/`nvarlst'  {						 
																 											
			gettoken varlist postpipes : anything, parse("||") 	//`postpipes' starts with "||" or is empty at end of cmd
			
			if "`twostep'"!=""  {
				if `limitdiag'>0 & `c'==1 {						// If this is the first context
					display _newline "Generating `mprefix' means for `varlist' across `stackid' as first step"
				}
			}
			
			if `limitdiag'>0 & `c'==1  {						// If diagnostic limit not reached 
			
				display _newline "Generating `pprefix' placements of `varlist' batteries distinguished by `stackid'"

				if "`cweight'"!="" display "weighting the mean placements by `cweight'..."
				
			}

			
			foreach v of local varlist  {
				summarize v `wt' 								// Start by getting varlist stats
				if "`twostep'"!=""  local `mprefix'v = r(mean)	// Put means in `mprefix'v if twostep
				
				else  {
					if r(sd)!=0  { 								// Otherwise check for vars constant across stacks
						display as error "Not a two step placement, so varlist vars should be constant across stacks"
						window stopbox stop "Not a two step placement, so varlist vars should be constant across stacks"
					}
				}
				if "`cweight'"!="" & `limitdiag'>0 & `c'==1  {	// Either way, see if final placements are weighted
					display _newline "Weighting final placements by `cweight'"
				} 
				if "`twostep'"!="" quietly summarize `mprefix'v `cweight'
				else quietly summarize v `cweight'
				
				generate `pprefix'v = r(mean)
				
			} //next `v'
			
											// (3) Break out of `nvl' loop if `postpipes' is empty
											// 	   (or pre-process syntax for next varlist)

			if "`postpipes'"==""  continue, break					// Break out of `nvl' loop if `anything' is empty (redndnt?)

			local anything = strltrim(substr("`postpipes'",3,.))	// Strip leading "||" and any blanks from head of `postpipes'
																	// (`anything' now contains next varlist and any later ones)
				
		} //next `nvl'														 	
			
			
		quietly count 

		local numobs = r(N)											// N of observations in this context

		local contextlabel : label (`ctxvar') `c'					// Get label for this combination of contexts

		if `limitdiag'>0 & `c'<=`limitdiag'  {						// If diagnostic limit not reached
			
			noisily display _newline "Context `contextlabel' has `numobs' cases"	_continue
			
		}
				
		else  {
			if `nc'<38  noisily display ".." _continue
			else  noisily display "." _continue						// Halve the N of dots if would more than fill a line
		}
		
	// END OF CODE FOR CURRENT CONTEXT								// `stackmeWrapper' will collect up results by context

end //genplaceP
