capture program drop gendistP

program define gendistP

	version 9.0												// gendist version 2.0, June 2022, updated Aug 2023
	
*!  Stata version 9.0; gendistP (was gendist until now) version 2, updatd May'23 from major re-write in Mar'23
*!  Stata version 9.0; gendist version 2, updated Mar'23 from major re-write in June'22
	
	//    Version 2 removes recently introduced code to plug plr==rlr with diff-means, as though the plr 
	// value had been missing. (This treatment turns out to be only appropriate when distances are from 
	// constant-valued party positions, else varying plrs will have their variance arbitrarily truncated). 
	// It introduces a new "plugall" option that plugs all plr values with the same (mean) plugging value, 
	// producing the constant values suited to plugging plr==rlr as though they were missing. Version 2 
	// also introduces full [if][in][weight] processing, where appropriate. Context-by-context processing 
	// was tried and discarded because the current use of "egen...by" proved faster.
	

    syntax anything [if] [in] [aw fw pw/], [SELfplace(varname) CONtextvars(varlist) STAckid(varname) ]			///
		[ MISsing(string) PPRefix(name) MPRefix(name) DPRefix(name) MCOuntname(name) MPLuggedcountname(name) ]	///
		[ LIMitdiag(integer -1) PLUgall ROUnd REPlace NOSELfplace ctxvar(varname) nvarlst(integer 1) ]			///
		[ nc(integer 0) c(integer 0) ]

															// Context-by-context processing is not used by gendist
															
															
											// Pre-process gendist-specific options not preprocessed in wrapper
	
	local wtexp = word("`exp'",2)							// Weight expression
 
	local optns = "`contextvars' `stackid'"					// Used in diagnostic display, below
  
	if `limitdiag'==-1  local limitdiag = .					// User wants unlimitd diagnostcs, make that a very big number!	** 

	

	if "`context'"==""  local nocontexts = "nocontexts"		// Change polarity to match legacy conventions
	if "`stackid'"==""  local nostacks = "nostacks"

												
	local count = 0											// Count of contexts processed, as basis for limitdiag
	
	local missPrefx = "m_"
	if ("`mprefix'"!="") {
		local missPrefx = "`mprefix'"
	}

	local plugPrefx = "p_"
	if ("`pprefix'"!="") {
		local plugPrefx = "`pprefix'"
	}
	
	local distPrefx = "d_"
	if ("`dprefix'"!="") {
		local distPrefx = "`dprefix'"
	}
	
	if ("`plugall'"!="" & "`missing'"=="")  {
		display as error "The {opt plu:gall} option requires the {opt mis:sing} option – exiting gendist{txt}"
		window stopbox stop "The {opt plu:gall} option requires the {opt mis:sing} option"
	}
	
	local missingCntName = "SMmisCount"
	if ("`mcountname'"!="") {
		local missingCntName = "`mcountname'"
	}

	local missingImpCntName = "SMmisPlugCount"
	if ("`mpluggedcountname'"!="") {
		local missingImpCntName = "`mpluggedcountname'"
	}
		

	if ("`missing'"=="" & "`pprefix'"!="") {
		display as error "The {bf:pprefix} can only be optioned if the {bf:missing} option is provided – exiting gendist{txt}"
		window stopbox stop "The {bf:pprefix} can only be optioned if the {bf:missing} option is provided"
	}	


	
	local stackvars = "`contextvars' `stkid'"
		
	tempvar _temp_ctx
	if ("`stackvars'" == "") {
		gen `_temp_ctx' = 0
		quietly replace `_temp_ctx' = 1 `if' `in'
		local ctxvar = "`_temp_ctx'"
	}
	else {
		quietly _mkcross `stackvars', generate(`_temp_ctx') missing length(20) label ()
		local ctxvar = "`_temp_ctx'"						 
	}
	

	
	
	
											// HERE STARTS PROCESSING OF CURRENT CONTEXT (all contexts for gendist) . . .
	
	
	forvalues nvl = 1/`nvarlst'  {						 	// Cycle thru set of varlists with same options
															// (any prefix is in `depvarname' & 'dvar')											
	  gettoken anything postpipes:anything,parse("||") 		//`postpipes' then starts with "||" or is empty at end of cmd
																 	
	  gettoken precolon anything : anything,parse(":") 		// See if varlist starts with prefixing indicator 
															// `precolon' gets all of varlist up to ":" or to end of string
	  if "`anything'"!=""  {							 	// If not empty we have a prefix string
		local selfplace = "`precolon'"						// Replace with `precolon' whatever was optioned for selfplace	**
		local isprfx = "isprfx"								// And set `isprfx' flag, then	...	
		local anything = strltrim(substr("`anything'",2,.)) // strip off the leading ":" with any following blanks
	  } //endif `anything'
				
	  else  local anything = "`precolon'"					// If there was no colon then varlist was in `precolon'
	  
	
	  if `limitdiag' !=0 & `count'<`limitdiag'  {
		noisily display as text _continue
		noisily display "{pstd}{text}Computing distances between R's position ({result:`selfplace'}) " _continue
		noisily display "and their placement of objects: {break} {result:`anything'} {break}"
		noisily display "using cumulative options: `optns'{p_end}"
	  }
	  
	  unab varlist : `anything'

	  local nvars : list sizeof varlist
	
	  tokenize `varlist'
	  local first `1'
	  local last ``nvars''
	

	
	  if ("`missing'"!="") {
		local missing = substr("`missing'",1,3)				// Shorten option-name to 3 chars in case user did so
		if "`missing'"=="mea"  local missing = "all"		// Permit legacy keyword "mean" for what is now "all"
		capture drop `missingCntName'
		capture label drop `missingCntName'

		capture drop `missingImpCntName'
		capture label drop `missingImpCntName'

		local imputedvars = ""
		local istvar = word("`varlist'",1)
		
*		********
		isnewvar `istvar', prefix("`missPrefx'")			// Check this does not already exist (isnewvar is program below)
*		********

		foreach var of varlist `varlist' {
			capture drop `missPrefx'`var'
			quietly generate `missPrefx'`var' = missing(`var')
			capture label var `missPrefx'`var' "Was `var' originally missing?"
			local imputedvars = "`imputedvars' `plugPrefx'`var'"	
															// List of p_`var's corresponding to `varlist'
		} //next var
		
	  } //endif `missing'

	

	  // Clone imputed copies first
	  if ("`missing'"!="") {	

		local istvar = word("`varlist'",1)

*       ********											// Program (listed below) handles already existing var
		isnewvar `istvar', prefix("`plugPrefx'")			// Cloned vars are named "`plugPrefx'`var'"
*		********
		
		foreach var of varlist `varlist' {
			
*			*****************
			createImputedCopy `var', type("`missing'") plugPrefx("`plugPrefx'")  // Program is listed below
*			*****************

		} //next var										// Note: `plugPrefx' vars only initialized if "`missing'"!=""

	  } //endif `missing'
															// create empty variables regardless of context

	  if ("`missing'"!="") {
	  	
		local istvar = word("`varlist'",1)
		
*		********											// Program (listed below handles already existing var
		isnewvar `istvar', prefix("`distPrefx'")			// Cloned vars are named `distprefix'`var'
*		*******

		foreach var of varlist `varlist' {					// Here label as distances from p_`var'
			capture drop `distPrefx'`var'
			capture quietly gen `distPrefx'`var' = .
			local newlab = "Euclidean distance between `selfplace' and `plugPrefx'`var'"
			label variable `distPrefx'`var' "`newlab'"
		} //next `var'

	  } //endif`missing'
	
	  else {
	  	
		foreach var of varlist `varlist' {					// Here label as distances from original `var'
			capture drop `distPrefx'`var'
			capture quietly gen `distPrefx'`var' = .
			local newlab = "Euclidean distance between `selfplace' and `var'"
			label variable `distPrefx'`var' "`newlab'"
		}

	  } // end else
		

		

	  foreach var of varlist `varlist'  {
		
		 local count = `count' + 1							// Count of vars processed, basis for limitdiag
		
															
		 qui replace `distPrefx'`var' = abs(`selfplace' - `var') // Start with all distances, whether or not mean-plugging was optiond

		
	     if ("`missing'"!="") {								//   Missing treatment was optioned ...

	        quietly {	
	    
				tempvar temp								// `temp' is p-var value by context to use for plugging missing obs 
															// Weighting calls on _gwmean (type net search _gwmean)
				if ("`missing'"=="all")  {
					if "`weight'"!=""  {
						egen `temp' = wmean(`var'), by(`_temp_ctx') weight(`wtexp') //  for version 2a; 
					}										// Weighting calls on _gwmean (type 'net search _gwmean')
					else {
						egen `temp' = mean(`var') if `selfplace'==`plugPrefx'`var', by(`_temp_ctx')
					}
				}											// Otherwise we use the regular egen mean() function

				if ("`missing'"=="sam")  {
					if "`weight'"!=""      {
						egen `temp' = wmean(`var') if `selfplace'==`plugPrefx'`var', by(`_temp_ctx') weight(`wtexp')
					}										// Weighting calls on _gwmean (type 'net search _gwmean')
					else {
						egen `temp' = mean(`var') if `selfplace'==`plugPrefx'`var', by(`_temp_ctx')
					}										// Otherwise we use the regular egen mean() function
				}
				
				if ("`missing'"=="dif")  {
					if "`weight'"!=""  {
						egen `temp' = wmean(`var') if `selfplace'!=`plugPrefx'`var', by(`_temp_ctx') weight(`wtexp')
					}
					else  {
						egen `temp' = mean(`var') if `selfplace'!=`plugPrefx'`var', by(`_temp_ctx')
					}
				}
					


				
				tempvar temp2								// `temp2' gets mean over whole context, not just part in `temp'
				egen `temp2' = mean(`temp'), by(`_temp_ctx')
				
				replace `plugPrefx'`var' =`temp2'			// Replace `plugPrefx'`var' with `temp2', to use for 'plugall'
				drop `temp2'

				replace `distPrefx'`var' = abs(`selfplace' - `temp') if `missPrefx'`var'
															// By default, plug only observations that are missing
				drop `temp'
			
			} // end quietly

         } //endif 'missing'

		 if `limitdiag'==0 | `limitdiag'>`count' noisily display "." _continue // Extend row(s) of "busy" dots if no other diag

		 if "`plugall'"!=""  {								// If user optioned constant reference values across battry membrs
			quietly replace `distPrefx'`var' = abs(`selfplace' - `plugPrefx'`var')
		 }

	     if ("`round'"!="")  {
		 	quietly sum `var', meanonly
			if r(mean)<=1  quietly replace `distPrefx'`var' = round(`distPrefx'`var', .1) 
			else  {											// Round to nearest single digit decimal if `var' max <= 1
			   quietly replace `distPrefx'`var' = round(`distPrefx'`var')
			}
		 }
		 
	  } // next `var'

	
	  if "`missing'"!=""  {
		 if "`missingCntName'"!=""  {
			quietly egen `missingCntName' = rowmiss(`varlist')
			capture label var `missingCntName' "N of missing values in `nvars' variables now plugged (`first'...`last')"
		 }
	  }

	  if "`missingImpCntName'" !=""  {
		  quietly egen `missingImpCntName' = rowmiss(`imputedvars')
		  capture label var `missingImpCntName' "N of missng values in `nvars' mean-plugged vars (`first'...`last')"
	  }
	
	  if ("`replace'" != "") {
		  capture drop `varlist'
		  capture drop `missPrefx'*
		  capture drop `plugPrefx'*
	  }
	
	

			
											// (6) Break out of `nvl' loop if `postpipes' is empty (common across all `cmd')
											// 	   (or pre-process syntax for next varlist)

	  if "`postpipes'"==""  continue, break					// Break out of `nvl' loop if `anything' is empty (redndnt?)

	  local anything = strltrim(substr("`postpipes'",3,.))	// Strip leading "||" and any blanks from head of `postpipes'
															// (`anything' now contains next varlist and any later ones)
	  local isprfx = ""										// Switch off the prefix flag if it was on

				   
				   
	} //next `nvl' 											// (next list of vars having same options)

	

	
	
	
end //gendistP








capture program drop createImputedCopy

program define createImputedCopy
	version 9.0
	syntax varlist, type(string) plugPrefx(name)
	capture drop `plugPrefx'`varlist'				       // Presumably `varlist' is actually `varname'
	quietly clonevar `plugPrefx'`varlist' = `varlist' 	   // Plugged copy initially includes valid + missing data
	local varlab : variable label `varlist'	
	local newlab = "`type'-MEAN-PLUGD " + "`varlab'" 	   // `type' is type of missing treatment
	quietly label variable `plugPrefx'`varlist' "`newlab'" // In practice, syntax changes `plugPrefx' to `plugPrefx'

end //createimputed copy





capture program drop isnewvar

program isnewvar
	version 9.0
	syntax varlist, prefix(name)
	
	capture confirm variable `prefix'`varlist' 
	if _rc==0  {
		display as error _newline "`prefix'-prefixd vars already exist; type {bf:BREAK} (caps) to exit or {bf:q} to replace{txt}{break}"
		pause
	}
	
end //isnewvar



