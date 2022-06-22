capture program drop gendist

program define gendist

	version 9.0									// gendist version 0.91, June 2022
	
	// This program is a front-end for what used to be gendist (now gendistP), calling gendistP once for
	// each user-supplied varlist (separated by "||"), each varlist optionally prefixed by a reference 
	// variable that effectively (re-)defines the `respondent' option (reference variable) for that varlist). 
	// It uses a tempfile to save and merge the missing data plugging variables, though code is included 
	// (commented out for now) to use data frames instead, should we learn how to implement stataversion()
	// (which currently yields an "Unknown function" error, perhaps because introduced after Version 9).
	
	// QUESTION: Should we permit weights to be used when generating means for plugging missing data, as we
	//           do for genmeans and genplace? (NOTE those only permit aweight, fweight and iweight because
	//	     of limitations to Stata's 'summarize' command).
	

											// Command line is in `0'
	gettoken anything postcomma : 0, parse(",")					// Put everything from "," into `postcomma'
	
	
	if substr("`postcomma'",1,1) != ","  {
		display as error("Need list of options, starting with comma")
		exit
	}
	local options = "`postcomma'"							// Save `options' for use with each varlist
	local optionsT = "`options'"							// Temp version will be sent on to gendispP

	// Prepare to process each varlist in turn by calling gendistP (the original program)
	
	local pipedsyntax = 0
	
	if (strpos("`anything'", ":")>0 | strpos("`anything'", "||")>0) { // If `anything' has a colon or pipes
		local pipedsyntax = 1
		display _newline "{pstd}{text}{bf:gendist} is processing prefixed or multiple varlists"
	} 
	

	while ("`anything'" != "") {
		
		if `pipedsyntax' == 0	 {
		
			local postcolon = "`anything'"					// No `postcolon': put `anything' there
			local anything = ""						// Fall out of while loop if only one varlist
		}
		else  {									// `pipedsyntax' = 1
			
			gettoken string postpipes:anything, parse("||") // 'string' gets all up to "||" or to end of anything

			gettoken precolon postcolon:string, parse(":")	// `precolon' gets all up to ":" or to end of string

			local thisRef = ""								// Assume no prefixed reference variable
			if strlen("`postcolon'")>0  {					// If there was a colon ...
				local postcolon=substr("`postcolon'", 2, .) // Strip the colon from front of `postcolon'
				local thisRef = "`precolon'"				//  and store the reference varname
			}
			
			else local postcolon = "`precolon'"				// Else put varlist where it would have been
			if "`postcolon'"==""  {
				display as error("Need at least one var(list)")
				exit
			}

		} // end else
	  
	  	
		if "`thisRef'" == "" & strpos("`options'","res") == 0  {
			display as error "If no varlist, prefix need reference var in option {bf:respondent}"
			exit
		}
		else  {
			if "`thisRef'"!=""  {
				if strpos("`options'","res") == 0  {
					local optionsT = "`options'"+" respondent("+"`thisRef'"+")"
				}
				else  {
					display as error "Cannot option {bf:respondent} if varlist prefix is used"
					exit
				}
			}
		}


		local varlist ""
		foreach var of varlist `postcolon' {					// We put varlist in postcolon even if no colon
			local varlist `varlist' `var'
		}
		
		
		gendistP `varlist' `optionsT'						// `options' (& `optionsT') start with a comma
		

		local start = strpos("`postpipes'", "||") + 2
		local anything = substr("`postpipes'",`start', .)			// If there are more varlist(s) put into `anything'
	

	} // next while
	
	
	  // Execute next line only following last call on gendistP

	display _newline "done."
		
end	




capture program drop createImputedCopy

program define createImputedCopy
	version 9.0
	syntax varname, type(string) imputeprefix(name)
	
	capture drop `imputeprefix'`varlist'						// Presumably this is actually `varname'
	quietly clonevar `imputeprefix'`varlist' = `varlist' 				// Imputed copy initially includes valid + missing data
	local varlab : variable label `varlist'	
	local newlab = "* MEAN-PLUGGED (`type') * " + "`varlab'"
	quietly label variable `imputeprefix'`varlist' "`newlab'"			// In practice, syntax changes `imputeprefix' to `imputePref'
	
end




capture program drop gendistP

program define gendistP
	version 9.0
	
	
	syntax varlist(min=1), [CONtextvars(varlist)] [PPRefix(name)] [DPRefix(name)] RESpondent(varname) [MISsing(string)] [ROUnd] ///
	       [REPlace] [MPRefix(name)] [MCOuntname(name)] [MPLuggedcountname(name)] [STAckid(varname)] [NOStacks] [DROpmissing]

	if ("`missing'"=="" & "`pprefix'"!="") {
		display "{text}{pstd}ERROR: The {bf:pprefix} can only be optioned if the {bf:missing} option was specified."
		exit
	}
	
	local imputePref = "p_"
	if ("`pprefix'"!="") {
		local imputePref = "`pprefix'"
	}
	
	local distPref = "d_"
	if ("`dprefix'"!="") {
		local distPref = "`dprefix'"
	}
	
	local missingFlagPref = "m_"
	if ("`mprefix'"!="") {
		local missingFlagPref = "`mprefix'"
	}
	
	local missingCntName = "_gendist_mc"
	if ("`mcountname'"!="") {
		local missingCntName = "`mcountname'"
	}
	
	local missingImpCntName = "_gendist_mpc"
	if ("`mpluggedcountname'"!="") {
		local missingImpCntName = "`mpluggedcountname'"
	}
	
	local nvars : list sizeof varlist
	
	tokenize `varlist'
    	local first `1'
	local last ``nvars''
	
	if ("`missing'"!="") {
		capture drop `missingCntName'
		capture label drop `missingCntName'
		quietly egen `missingCntName' = rowmiss(`varlist')
		capture label var `missingCntName' "N of missing values in `nvars' variables to plug (`first'...`last')"

		capture drop `missingImpCntName'
		capture label drop `missingImpCntName'
		capture label var `missingImpCntName' "N missing values in mean-plugged versions of `nvars' variables (`first'...`last')"

		local imputedvars = ""

		foreach var of varlist `varlist' {
			capture drop `missingFlagPref'`var'
			quietly generate `missingFlagPref'`var' = missing(`var')
			capture label var `missingFlagPref'`var' "Was `var' originally missing?"
			local imputedvars = "`imputedvars' `imputePref'`var'"			// List of p_`var's

		}
	}
	
	capture drop _ctx_temp
	capture label drop _ctx_temp


	if ("`stackid'" != "") & ("`nostacks'" == "") {
		local thisCtxVars = "`contextvars' `stackid'"
	}
	else {
		local thisCtxVars = "`contextvars'"
	}
	
	if ("`thisCtxVars'" == "") {
		gen _ctx_temp = 1
		local ctxvar = "_ctx_temp"
	}
	else {
		quietly _mkcross `thisCtxVars', generate(_ctx_temp) missing
		local ctxvar = "_ctx_temp"
	}
	

	local fullDistancePref = "`distPref'"
	
		
	// loads all values of the context variable
	quietly levelsof `ctxvar', local(contexts)
	
	noisily display in smcl _continue
	noisily display as text
	noisily display "{pstd}{text}Computing distances between R's position ({result:`respondent'}) " _continue
	noisily display "and her placement of objects: {break} {result:`varlist'}"
	noisily display ""


	// Clone imputed copies first
	if ("`missing'"!="") {									// Cloned vars are named "`imputePref'`var'"
		foreach var of varlist `varlist' {
			createImputedCopy `var', type("`missing'") imputeprefix("`imputePref'")
		}										// Note: `imputePref' vars only initialized if "`missing'"!=""
	}


	// create empty variables regardless of context
	
	if ("`missing'"!="") {
		  foreach var of varlist `varlist' {
			capture drop `fullDistancePref'`var'
			capture quietly gen `fullDistancePref'`var' = .
			local newlab = "Euclidean distance between `respondent' and `imputePref'`var'"
			label variable `fullDistancePref'`var' "`newlab'"
		  } // next `var'
	}
	
	else {
		foreach var of varlist `varlist' {
			capture drop `fullDistancePref'`var'
			capture quietly gen `fullDistancePref'`var' = .
			local newlab = "Euclidean distance between `respondent' and `var'"
			label variable `fullDistancePref'`var' "`newlab'"
		}
	} // end else
		

		
	sort `ctxvar'										// Preparatory to 'statsby:'


	foreach var of varlist `varlist' {
	     if "`missing'"==""  {									// If missing treatment was not optioned there are no p_vars
	     capture replace `fullDistancePref'`var' = abs(`var'-`respondent')
	display "..{result:`fullDistancePref'`var'}." _continue
	    }											// (Lorenzo coded the above in an else clause)
	    else  {										// If missing treatment was optioned
		
	        quietly {	
	    
		    preserve

		    if ("`missing'"=="mean") statsby theMean=r(mean)						///
			  by(_ctx_temp) clear nodots nolegend: summarize `imputePref'`var', meanonly
				
		    else if ("`missing'"=="same") statsby theMean=r(mean) if `respondent'==`imputePref'`var',	///
			  by(_ctx_temp) clear nodots nolegend: summarize `imputePref'`var', meanonly
				
		    else if ("`missing'"=="diff") statsby theMean=r(mean) if `respondent'!=`imputePref'`var',	///
			  by(_ctx_temp) clear nodots nolegend: summarize `imputePref'`var', meanonly

/*		    if stataversion()>=1600  {							// Frame syntax is available **Commented out due to "unknown function"

			  capture frame drop stats
		      frame put _ctx_temp theMean, into(stats)
			  
		    }
		    else {									// Frame syntax is not available
*/			  keep _ctx_temp theMean
			  tempfile tempfile
			  save `tempfile'
		  restore									// Move this to follow "} // end else" if stataversion can be made to work

/*			} // end else								// **Commented out because "unknown function stataversion()"

		  if stataversion()>=1600  {							// Frame syntax is available
		  	frlink m:1 _ctx_temp, frame(stats)
		  	frget theMean, from(stats)
		  	frame drop stats
		  }
		  else  {									// Frame syntax is not available
*/		  	merge m:1 _ctx_temp using `tempfile', nogen
*		  } // end else

		  if ("`round'"=="round") replace theMean = round(theMean)

		  if "`missing'"!="diff"  capture replace `imputePref'`var' = theMean if `imputePref'`var'==. 
		  else capture replace `imputePref'`var' = theMean if `respondent'!=`imputePref'`var' | `imputePref'`var'==.
												// Treat `respondent'==`imputePref' as though missing (fearing PID bias)
		  capture replace `fullDistancePref'`var' = abs(`imputePref'`var'-`respondent')
												// Distance from plugged party location to resp location
		  drop /*stats*/ theMean							// Uncpmment /*stats*/ if stataversion() can be made to work
	      } // end quietly
	  
	      display "..{result:`imputePref'`var'},{result:`missingFlagPref'`var'},{result:`fullDistancePref'`var'}." _continue

          } //end else

    } // next `var'

    noisily display " "
	
	if ("`missing'"!="") {
		capture drop `missingCntName'
		quietly egen `missingCntName' = rowmiss(`varlist') 
		capture drop `missingImpCntName'
		quietly egen `missingImpCntName' = rowmiss(`imputedvars')			// This line changed by MNF
	}

	if ("`dropmissing'" != "") {
		capture drop `missingFlagPref'*
		capture drop `imputePref'*
	}
	
	if ("`replace'" != "") {
		capture drop `varlist'
	}
	
	capture drop _ctx_temp
	capture label drop _ctx_temp

set trace off

end	
