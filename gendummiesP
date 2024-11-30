

capture program drop gendummiesP

program define gendummiesP

*! Stata version 9.0; gendummies version 2, updated Mar'23 (with minor tweaks in Sept '24) from major re-write in June'22

   version 9.0												// GendummiesP version 2 (was previously 'gendummies')
	
   // Version 2 allows varlists to be processed, either "naked" (using varnames as stubs) or with different stubs in different
   // varlists, grouping together successive varlists having the same options.

   // NOTE that codeblocks importd from genyhatsP, which should be common across`cmd'Ps, needed some tweekng (see lines flagged **)
	

	syntax anything, [ STUbprefix(name) INCludemissing LIMitdiag(integer -1) CONtextvars(varlist) ] ///
					 [ /*prfx(str) isprfx*/ nvarlst(integer 1) nc(integer 0) c(integer 0) wtexplst(string)] 
															// `prfx' string and `isprfx' not used in gendummies


															
	quietly count 	
	local numobs = r(N)										// N of observations in this context
	if `limitdiag'==-1  local limitdiag = .					// Make that a very big number
	

	
												// GENDUMMIES TREATS WHOLE DATASET AS ONE CONTEXT
												
	local warn = 0											// Flag to warn about stubprefix override
	
	forvalues nvl = 1/`nvarlst'  {						 	// Cycle thru set of varlists with same options
	
		local stubPrefix = ""								// Any prefix comes from `stubprefix' (small p) or `precolon'	
		
		gettoken prepipes postpipes : anything, parse("||") //`postpipes' now starts with "||" or is empty at end of cmd
		if "`postpipes'"=="" local prepipes = "`anything'"	// (if empty make like imaginary pipes follow at end of cmd)
		
		gettoken precolon postcolon : prepipes, parse(":") 	// See if varlist has prefixing indicator; would be in postcolon
															// `precolon' would get all of varlist before ":"
		if "`postcolon'"!=""  {							 	// If not empty we have a prefix string
			local vars = substr("`postcolon'",2,.)			// (and ': vars' are in `postcolon')
			local stubPrefix = "`precolon'"					// Replace with `precolon' whatever was optned for stubprefix	**
			if substr("`stubPrefix'",-1,1)!="_" local stubPrefix = "`precolon'_"
			local stubprefix = ""							// (and override the stubprefix option for later varlists)
			local warn = 1									// Flag to display warning about prefix strings
		} 													// Dont want to display this for each 
 		
		else  {												// Else `postcolon' is empty
			local vars = "`prepipes'"						// If there was no colon then varlist is in `prepipes'
			local stubPrefix = "`stubprefix'"				// (and we get stubPrefix, if any, from option 'stubprefix')
			if substr("`stubprefix'",-1,1)!="_" local stubPrefix = "`stubprefix'"+"_" // (note latter has lower case 'p')
		}													
	   
	   
		unab varlist : `vars'
				   
  
		foreach var of local varlist  {				  		// Cycle thru varlist(s) in `anything'								

			capture confirm numeric variable `var'			
			if _rc!=0  {
				display as error "Variable `var' is not a numeric variable{txt}"
				window stopbox note "Variable `var' is not a numeric variable. Click 'OK' to exit"
				global exit = 1
				exit 1											// Break out of `var' loop
			}
			
			quietly levelsof `var', local(values)				// Enumerate the category values for this variable

			
			
			
 
 
 
												// (5) For each var, cycle thru all values
												
		
			foreach val of local values  {
				
				confirm number `val'							// If real conversion of value is missing
				if _rc  {
					display as error "For variable `var', found non-integer value `val'. Ignore that value?{txt}"
*                		  		      12345678901234567890123456789012345678901234567890123456789012345678901234567890
					window stopbox note "For displayed variable, found non-integer value `val'. Ignore that value?{txt}"
					if _rc  {
						global exit = 1
						exit 1
					}
				}
				
				
				capture confirm variable `stubPrefix'`var'`val'
				if _rc==0  {
*					if `nvl'==`nvarlst'  continue, break		// Not sure why suffix matching N of varlsts is ok
					display as error "variable `stubPrefix'`var'`val' already exists{txt}"
					window stopbox note "variable `stubPrefix'`var'`val' already exists. Click OK to exit"
					global exit = 1
					exit 1
				}

				
*				**************************
				gen `stubPrefix'`var'`val' = (`var'==`val') 	// This is the money command that creates a new var for each value
*				**************************

	
				local label : label (`var') `val'				// Value label for each category of `var' 
				local len = strlen("`label'")					// ('var' may also have a variable label referenced in genstacks)
				capture confirm number `label'					// If `label' is all numeric then it was found unlabeled by numlabel
				if _rc  {										// If _rc is non-0 then there is a proper label for this var
					forvalues i = 1/`len'  {					// See if 'val' is repeated as label prefix
						local j = `i'							// Store value of 'i', which has no value outside this loop
						local k = substr("`label'",1,`j')		// Convert string to number if numeric
						capture confirm number `k'				// Not numeric if last char is end-of-value character
						if _rc>0  continue, break				// Found non-numeric char signalling end of label prefix
					} //next value								//  (dk what value that is, but must be non-numeric)

					local nprefix = substr("`label'", 1, `j'-1)	// Numeric prefix ends one char before end-of-prefix char
					if `nprefix'==`val'  {						// If label prefix duplicates 'val' then 
						local label =substr("`label'",`j'+1, .) // Strip 'labelprefix' & following char from start of 'label'
						local label = strltrim("`label'")		// Strip any leading blanks following label prefix
					}											// Ensures label does not end up with value repeated 3 times!
					label variable `stubPrefix'`var'`val' "`var'==`val' `label'"
				} //endif 'len'>1								// (even twice, as happened with version 0.9, is arguably overkill)
		

				if ("`includemissing'"!="") {					// See if user optioned values of 0 for missing data
					foreach newvar of varlist `stubPrefix'`var'*  {
						if ("`newvar'"!="`var'") {				// Exclude the stub itself
						   qui replace `stubPrefix'`var'`val' = 0 if `var'>=.
						}
					} //next `newvar'
				} //endif
			
				else {											// Otherwise make the new dummy missing if original value missng
					qui replace `stubPrefix'`var'`val'=. if `var'>=.
				} //end else
				
*				order `stubPrefix':`var'`val', last				// 'options not allowed' error ??
				
			} //next val

*			if $exit continue, break

		} //next `var'
		
		if $exit continue, break								// Should not get here as earlier errors all have own exit cmd
		
		
		
	  
											// (6) Break out of `nvl' loop if `postpipes' is empty (common across all `cmd')
											// 	   (or pre-process syntax for next varlist)
											

		if "`postpipes'"=="" | "`postpipes'"=="||" continue,break // Break out of `nvl' loop if `postpipes' is empty

		local anything = strltrim(substr("`postpipes'",3,.))	  // Strip leading "||" and any blanks from head of `postpipes'
																  // (`anything' now contains next varlist and any later ones)
		local isprfx = ""										  // Switch off the prefix flag if it was on

				   
	} //next `nvl' 												  // (next list of vars having same options)
	
	if `warn' & `limitdiag' noisily display _newline "NOTE: Prefix to varlist overrides, for that varlist, any stubprefix option{txt}"
	
	
	if `limitdiag'  noisily display _newline "Done." _newline

 
	
	if $exit  exit 1											  // Should not get here as earlier error now itself has exit cmd
	

   
end //gendummiesP



******************************************************* END gendummiesP ***************************************************************



