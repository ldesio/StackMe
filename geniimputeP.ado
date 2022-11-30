capture program drop geniimpute_body

program define geniimpute_body

	version 13.0											// geniimpute+_body version 0.92
	
	// This program is called by geniimputeP (below) once for each context for which imputed variables are to be 
	// calculated. It is changed from previous versions by having all reference to contexts removed, since it is 
	// called by geniimputeP once per context per varlist instead of once per varlist.
	
																	// Syntax of call from geniimputeP, not of original user command
		
		syntax varlist, ctxvar(varname) c(integer) nc(integer) ip(name) mfp(name) mcn(name) mic(name) theptvs(varlist) ///	
		minofrange(string) maxofrange(string) imputedvars(varlist) addvars(varlist) contextlabel(string) [ extradiag(string) ///
		round(string) dropmissing(string) replace(string) boundvalues(string) limitdiag(string) select(string) noinflate(string) ]
																	// Some unprocessed flag options included in this list
				

		local ncontexts = `nc'										// Transfer local parameters set in iimputeP 
		local imputeprefix = "`ip'"
		local missingflagprefix = "`mfp'"
		local missingCntName = "`mcn'"								// Now a tempvar passed from geniimputeP										***
		local missingImpCntName = "`mic'"							// Ditto, due to complexities arising from multiple varlists (see help text)	***
		local thePTVs = "`theptvs'"									// thePTVs, created in geniimputeP, passed as `theptvs' (all lowercase)
		local rangemin = `minofrange'								// `rangemin' and `rangemax' were set in iimputeP according to user options
		local rangemax = `maxofrange'								
		local inflate = 1											// This flag must be post-processed so that it takes on two values
		if "`noinflate'"=="noinflate" inflate = 0					// Remaining options (`imputedvars'...) need no post-processing
																		
												/*	
												incremental simple imputation logic: select cases with 1 missing PTV, impute that PTV 
												(starting from PTVS with fewest missing cases...); then cases with 2, etc..., until you 
												reach cases with all PTVs missing. On PTVs in imputed cases, add random noise so that 
												variance equals variance in non-missing cases.
												
												`missingCntName and missingImpCntname are retained in the code itself, used for extra diagnostics'
												*/		
												
												
												// Variable processing moved from here to geniimputeP, below


																	
												// Set diagnostic display flags
								
*	foreach context in `contexts' {									// Commented out because this is now done in geniimputeP
	
*		local contextLabel : label (`contextvar') `context'			// Moved to geniimputeP
		
		local thiscontext = `c'										// Passed as argument from geniimputeP
		
		local showDiag = 1											// By default show all diagnostics
		local showMode = "noisily"
		
		if (`limitdiag' > -1 & (`thiscontext' > `limitdiag')) {		// If no limit or limit not yet reached . . .
			local showDiag = 0
			local showMode = "quietly"
		}
		
		
		
		
												// count observations in this context
												
		quietly count /*if `contextvar'==`context'*/				// This `if' removed ubiquitously as `geniimpute_body' now processes just 1 context
		local numobs = r(N)											// N of observations in this context
		
		local countUsedPTVs = 0										// Count of vars to be imputed and list of their names
		local usedPTVs ""											// `usedPTVs' was generalized some versions ago to refer to vars to be imputed
		local countPTVs = 0											// Ditto for other vars with PTVs in their names
		
		local nonmisPTVs = ""										// List of vars to be imputed that empirically have no missing observations
		local numPTV = ""
		
		
		
		
		foreach var of varlist `thePTVs' {		// Process each PTV (legacy name for vars to be imputed)
			
			quietly count if missing(`var') 
			local missingPTVs = r(N)									// N of missing cases for this PTV within this context
				
			if `missingPTVs'==0  local nonmisPTVs ="`nonmisPTVs' `var'" // Accumulate list of non-missing PTVs
			// if no. of missing values less than no. of observations, this PTV is used
			if `missingPTVs'<`numobs' & `missingPTVs'>0  {				// Mark added check for `missingPTVs'>0 
				local countUsedPTVs = `countUsedPTVs' + 1				// N of PTVs with some but not all missing cases
				local usedPTVs `usedPTVs' `var'
				local ptvobs = `numobs' - `missingPTVs'
				local miscnts = "`miscnts' " + string(`missingPTVs')
			}
			local countPTVs = `countPTVs' + 1							// N of vars specified by user in varlist
			
		} //next `var'
		
		
		
		
		
		if "`nonmisPTVs'" != ""  {				// Some vars in varlist had no missing values to be imputed
		
			display as error "Some var(s) to be imputed have no missing values: {bf:`nonmisPTVs'}."
			display as error "These should be optioned as additional()"
			error 999
		}

		local countUnusedPTVs = `countPTVs' - `countUsedPTVs'
		
		
	
	
	
		
												// Display diagnostics for each variable, if optioned
												
		if (`ncontexts' > 1  & `showDiag') {
			display _newline "{pstd}Context {result:`thiscontext'} ({result:`contextlabel'}) imputes "
		}	

		if (`showDiag') {						
			local uP = trim("`usedPTVs'")
			display "{result:`countUsedPTVs'} items" /*({bf:`uP'})*/ ", N = `numobs'"
		}																 // Suppress varnames, which will appear in list that follows
		

		local missingCounts ""
		local npty = 0
		foreach var of local usedPTVs {
			local npty = `npty' + 1
			local thisN = real(word("`miscnts'", `npty'))
				// very, very dirty trick:							 	 // Mark thinks its a pretty neat trick! 									***
			local missingCounts = "`missingCounts'" + ///
			   substr("000000",1,7-length("`thisN'")) + ///
			   "`thisN'_`var' "										 	 // Final space ensures one word per party
		} //next `var'

		local missingCounts : list sort missingCounts				 	 // Sort list of missingCounts_varname into ascending order by missingCounts
		local nvals = wordcount("`missingCounts'")
		
		
		
		
		if "`select'" != ""  {					// Selecting only additional vars with more missing cases than last in missingCounts ?? 			***
		
			local lastCount = word("`missingCounts'",`nvals')			 // Last count has greatest N of missing for any var to be imputed
			local maxval = substr("`lastCount'",1,7)
			local selected = ""
			foreach var of varlist `addvars'  {
				quietly count if missing(`var') 
				if r(N) > `maxval'  local selected = "`selected' `var'"	 // Append to list of vars with few enough missing cases (check if needed)	***
			}
			local addvars = "`selected'"								 // Replace `additional' with selected vars from `addoitional'
		} //endif `select'

		
		
		local prevnum = .
		local thesePTVs = ""
		local orderedPTVs = ""					// `orderedPTVs' collects up usedPTVs in order of size												***
		
*		foreach mc in "`missingCounts'"  {								 // This syntax didn't distinguish successive words; try `local missingcounts'?
		forvalues i = 1/`nvals'  {
			local mc = word("`missingCounts'",`i')
			local thisnum = real(substr("`mc'",1,7))
			local thisvar = substr("`mc'",9,.)							 // Skip over the "_" between `thisnum' and `thisvar'
*			if `thisnum' == `prevnum'  {
			local thesePTVs = "`thesePTVs'" + " `thisvar'"			 	 // Accumulate list of PTVs in order of N of missing values

/*			}
			else  {														 // Original idea was to group thesePTVs into sets with same N of missing values
				if "`thesePTVs'" == ""  continue						 // Previous set is empty
				local orderedPTVs = "`orderedPTVs' `thesePTVs' "		 // Extend ordered list by adding each group with same number of missing values
				display "{break}Imputing `thesePTVs' (missing in `thisnum' obs)"  // Previous set is complete
				local thesePTVs = "`thisvar'"							 // Initialize next (first?) set with first var in the set
				local prevnum = `thisnum'
			}	
*/		} //next /*`mc'*/ `i'




					
												// Impute each member of `thesePTVs' in turn, transferring it from `thesePTVs' to `imputedPTVs"'

		local remainingPTVs = "`thesePTVs'"							 	 // `remainingPTVs' are prdered by N of missing values
		local imputedPTVs = ""											 // List of imputed PTVs, to be used in following imputations
		
		while "`remainingPTVs'" != ""  {								 // Continue imputing until there arw no `remainingPTVs' 

			gettoken thisPTV remainingPTVs : remainingPTVs				 // Remove first varname from remainingPTVs; it is var to be imputed
			tempvar tmp

			if "`extradiag'"!="" & `showDiag'  display "{break}impute `thisPTV' `remainingPTVs' `imputedPTVs' `addvars'"
			quietly impute `thisPTV' `remainingPTVs' `imputedPTVs' `addvars', generate(`tmp')

			quietly replace `imputeprefix'`thisPTV' = `tmp'				 // Replace it with imputed version
			drop `tmp'
			
			local imputedPTVs = "`imputedPTVs' `imputeprefix'`thisPTV' " //  and add it to `imputedPTVs'
			
		} //endwhile													 //  ensuring subsequent imputations take advantage of already imputed var
		
		tempvar tmpXXX													 // Record n of missing values per case in `missingImpCntName'
		quietly egen `tmpXXX' = rowmiss(`imputedPTVs') 
		quietly replace `missingImpCntName' = `tmpXXX' - `countUnusedPTVs' // DK why we would subtract `countUnusedPTVs' ??????????				 	***
		quietly drop `tmpXXX'

		
					
					
	
												
												// If optioned, round, constrain, and/or enforce bounds of (plugged) values
		if ("`round'"=="round") {
		
			if (`showDiag') {													// Report that this is done, per context, if optioned
				display "rounded " _continue
			}

			foreach var in `usedPTVs' {
				//tab i_`var' if orig_mis_`var'==1, missing
				quietly replace `imputeprefix'`var' = round(`imputeprefix'`var') if `missingflagprefix'`var'==1 
				//tab i_`var' if missingflagprefix`var'==1, missing				
			}	
		} //endif `round'

				
		
		if (`rangemin' != 999999999) | (`rangemax' != -999999999) {
			if (`showDiag') {													// Report that this is done, per context, if optioned
				display "constrained " _continue
			}

			foreach var in `usedPTVs' {
				//tab i_`var' if orig_mis_`var'==1, missing
				if (`rangemin' != 999999999) {
				quietly replace `imputeprefix'`var' = `rangemin' if `imputeprefix'`var' < `rangemin'  & `missingflagprefix'`var'==1 
				}																
				if (`rangemax' != -999999999) {									
					if (`showDiag') {											
																			
						display " constrained `rangemin' - `rangemax'			
					}															
					quietly replace `imputeprefix'`var' =`rangemax' if `imputeprefix'`var'>`rangemax'&`imputeprefix'`var'<.&`missingflagprefix'`var'==1 
				} 
				//tab i_`var' if orig_mis_`var'==1, missing
			}	
		} //endif `rangemin'	
		
		
		if ("`boundvalues'" != "")  {	
			if (`showDiag') {													// Report that this is done, per context, if optioned
				display " bounded " _continue												
			}																	// Maybe we should do this in iimputeP so as to ensure same
			foreach var in `usedPTVs'  {										//  min and max across contexts. Put varname, min and max
				quietly sum `var'												//  in one word of multi-word local, passed to iimpute_body? 		***
				local boundmin = r(min)	
				local boundmax = r(max)	
				quietly replace `imputeprefix'`var' = `boundmin' if `imputeprefix'`var' < `boundmin'  & `missingflagprefix'`var'==1 
				quietly replace `imputeprefix'`var' = `boundmax' if `imputeprefix'`var' > `boundmax'  & `missingflagprefix'`var'==1 
			}
		} //endif `boundvalues'
		
		
		

		
		
		local lenN = length("`numobs'")			// Allow space for longest N (ie context N) in displayed diagnostics per variable
		
		foreach var in `usedPTVs' {
			local gap = 12 - length("`var'")									 // Get len of gap before varname while `var' is not yet a varname
			quietly summarize `imputeprefix'`var' if `missingflagprefix'`var'==0 // N and SD for items not originally missing
			local oN = r(N)
			local oSD = r(sd)
																						
			quietly summarize `imputeprefix'`var' /*if `missingflagprefix'`var'==1*/ // Get N and SD of imputed var, including unimputed values	
			local iSD = r(sd)													// (Doesn't affect inflation, only diagnostics)						***
			local iN = r(N)																	
			if (`iSD' != .) {

			  if (`showDiag')  {

				local gapo = `lenN' - length("`oN'")
				local gapi = `lenN' - length("`iN'")
				local blnk = " "
				if `gapo'==1  display "{break}`var': {space `gap'} original N `blnk'`oN' SD " %5.2f `oSD' ",{space `gapi'} imputed N `iN' SD " %5.2f `iSD' ","
				else display "{break}`var': {space `gap'} original N {space `gapo'} `oN' SD" %5.2f `oSD' ",{space `gapi'} imputed N `iN' SD " %5.2f `iSD' ","
			  }																	  // For some unfathomable reason {space `gapo'(=1)} prints as "   "

			  
								
			  if (`inflate' == 1) {												  // From option `noinflate' during option post-processing, above
				quietly replace `imputeprefix'`var' =`imputeprefix'`var'+rnormal(0, `oSD') if `missingflagprefix'`var'==1 //Inflate just imputed values
				quietly summarize `imputeprefix'`var' /*if `missingflagprefix'`var'==1*/ // Surely, need SD of all values, not just imputed values?	 ***
			
				local iSD = r(sd)
				if (`showDiag') {
					display " inflated SD " %5.2f `iSD' "{break}"
				}
			  } //endif `inflate'
			} //end if `iSD'
			
			else {
				if (`showDiag') {
					display "`var' original SD " %5.2f `originalSD'  " has no missing values"
				}

			}
			
		} //next `var'

		if `c' == `limitdiag' display  "{p_end}"						   		  // Ensure dots start on newline after limit of diagnostics reached

				
		if (`showDiag') {
			display "{break}"
		}

		
/*		if (`ncontexts' > 1) {
			if ("`extradiag'" == "`extradiag'") {
				display "{pstd}Results for context {result:`c'} ({result:`contextlabel'}):{break}"
			}
			else {
				if (`showDiag') {
					display "{pstd}Results:"
				}

			}
*/		
		
			if ("`extradiag'" != ""  & `showDiag')  {
			table `missingCntName' `missingImpCntName', missing stubwidth(30) cellwidth(20)
		}

		if (`ncontexts'==`limitdiag')  display "{p_end}" 		// Ensure dots do not occur on same line as last diagnostic
		if (`showDiag'==0)  display "." _continue	

		
		
				
*	} //next context											// Commented out because only one context on each call

end









capture program drop geniimputeP
program define geniimputeP


	// This program is called by geniimpute once for each varlist, if using pipes syntax. It, in turn, calls geniimpute_body 
	// once for each context, having first created needed variables and local vars (passed as arguments to geniimpute_body)


	version 9.0												// iimpute version 0.92

	
	syntax varlist, ///										// `0' is unchanged, so syntax can still be unpacked here
		[ADDitional(varlist)] [CONtextvars(varlist)] [MINofrange(integer 999999999)] [MAXofrange(integer -999999999)] [BOUndedvalues] ///
		[IPRefix(name)] [MPRefix(name)] /*[MCOuntname(name)] [MIMputedcountname(name)]*/ [LIMitdiag(integer -1)] [EXTradiag] ///
		[ROUndedvalues] [STAckid(varname)] [NOStacks] [DROpmissing] [NOInflate] [REPlace] [SELected] // MCOuntname and MIMputedcountname dropped 			***

*display "P limitdiag `limitdiag'"


												// Establish original default options (or revised defaults if using pipes syntax)
*set trace on		
															// $opt1 would hold prefix strings saved after processing any previous varlist/options
	if "$opt1" == ""  {										// If options were not saved after prior varlist/options then set defaults here
		local imputeprefix = "i_"							// This and following commands set documented default prefix strings
		local missingflagprefix = "m_"
*		local missingCntName = "_iimpute_mc"				// Dropped from this version of iimpute
*		local missingImpCntName = "_iimpute_mic"			// Ditto
		local usestacks 		  = "yes"					// Actually a flag, not a prefix, but saved with the prefixes for convenienc
	}
	else  {													// Options were saved: assign those values where a new option was not specified
		if ("`imputeprefix'"=="") 		local imputeprefix = word("$opt1",1)	
		if ("`missingflagprefix'"=="")  local missingflagprefix = word("$opt1",2)
*		if ("`missingCntName'"=="") 	local missingCntName = word("$opt1",3)		// Dropped from this version of iimpute
*		if ("`missingImpCntName'"=="")  local missingImpCntName = word("$opt1",4)	// Ditto
		if ("`usestacks'"=="") 			local usestacks = word("$opt1",5) // Actually a flag, not a prefix, but saved with prefixes for convenience
		if ("`usestacks'"=="no") 		local nostacks = "nostacks"		  // `nostacks', the user-supplied option, is not symmetrcal as needed for $opt3
	}
*display "imputeprefix `imputeprefix'; missingflagprefix `missingflagprefix'; missingCntName `missingCntName'; missingImpCntName `missingImpCntName';"
*display "usestacks `usestacks'"

	
	if "$opt2" != ""  {										// $opt2 would hold user-supplied flags after processing any prior varlist/ptions
		foreach parm of global opt2  {
		  local `parm'1 = "`parm'"							// When retrieved these need to be placed in corresponding locals to avoid naming problems	
		}													// There may be any number of flags from none to the number retrieved here
		if ("`extradiag'"=="" & "`extradiag1'"!="") local extradiag = "`extradiag1'"
		if ("`round'"=="" & "`round1'"!="") local round = "`round1'"
		if ("`noinflate'"=="" & "`noinflate1'"!="") local noinflate = "`noinflate1'"
		if ("`dropmissing'"=="" & "`dropmissing1'"!="") local dropmissing = "`dropmissing1'"
		if ("`boundvalues'"=="" & "`boundvalues1'"!="") local boundvalues = "`boundedvalues1'"
	}
*display "*** extradiag `extradiag'; round `round'; noinflate `noinflate'; dropmissing `dropmissing'; restrictvalues `restrictvalues'"


	if "$opt3" != ""  {										// $opt3 would hold user-supplied numeric options after processing prior varlist/options
		foreach parm of global opt3  {						// Stored as `option=number' words in a list of any langth
		  local loc = strpos("`parm'","=")					// I did try gettoken to handle these, but could not make that work
		  local dest = substr("`parm'",1,`loc'-1)
		  local orig = substr("`parm'",`loc'+1,.)
		  if ("`dest'" == "") local `dest' = `orig'
	    }
		if (`limitdiag' == -1) local limitdiag = `orig' 	// Defaults to -1, meaning not optioned, in which case assign final `orig' value
	}
*display "minofrange `minofrange'; maxofrange `maxofrange'; limitdiag `limitdiag'"	

	
	if ("`contextvars'"=="") local contextvars ="$contextvars" // Retrieve variable (list)s from global strings
	if ("`additional'"=="")  local additional  ="$additional"
	if ("`stackid'"=="") 	 local stackid 	   ="$stackid"

	
	
											
												// Update defaults with user-supplied options (for current varlist, if using pipes syntax)
	  
	if ("`iprefix'"!="") local imputeprefix ="`iprefix'"	  // If new options are specified, these override defaults or previous options	
	if ("`mprefix'"!="") local missingflagprefix ="`mprefix'" // Note first 2 option-names are all lower case, unlike the next two
*	if ("`mcountname'"!="")  local missingCntName ="`mcountname'" //
*	if ("`mimputedcountname'"!="") local missingImpCntName ="`mimputedcountname'"	
	if "`nostacks'" != ""  local usestacks ="no"
	if "`usestacks'"!="no" local usestacks ="yes"			  // Provides symmetrical flag, always one or the other
	if "`boundedvalues'"!="" local boundvalues ="boundvalues" // Remove two letters from option-name, as implemented below
	if "`roundedvalues'"!="" local round ="round" 			  // Shorten option-name, as implemented below


	
	

												// Pre-process varlist and variables saved by iimpute
	local nvars : list sizeof varlist	
	tokenize `varlist'
    local first `1'
	local last ``nvars''

	local thePTVs `varlist'										// from string to genuine list (Mark says not sure what is at issue here)			***
	
	local missingCntName = "_iimpute_mc"						// Tho no longer added to dataset, still needed for functionality					***
	local missingImpCntName = "_iimpute_mic"					// Ditto

	capture drop `missingCntName'								// Needed for subsequent varlists
	capture label drop `missingCntName'
	tempvar `missingCntName'
	quietly egen `missingCntName' = rowmiss(`varlist')			// Var holding N of missing cases for any variable to be impoted
	capture label var `missingCntName' "N of missing values in `nvars' variables to impute (`first'...`last')"

	capture drop `missingImpCntName'
	capture label drop `missingImpCntName'
	tempvar `missingImpCntName'
	quietly gen `missingImpCntName' = `missingCntName'			// Default N of missing imputed values to N of unimputed values
	capture label var `missingImpCntName' "N of missing values in imputed versions of `nvars' variables (`first'...`last')"

	
	if ("`stackid'" != "") & ("`nostacks'" == "") {
		local thisCtxVars = "`contextvars' `stackid'"			// In this version `stackid', if any, is included within each context
	}
	else {
		local thisCtxVars = "`contextvars'"
	}
	
	if ("`thisCtxVars'" == "") {
		quietly gen _hb_temp_ctx = 1
		local ctxvar = "_hb_temp_ctx"
	}
	else {
		quietly _mkcross `thisCtxVars', generate(_hb_temp_ctx) missing
		local ctxvar = "_hb_temp_ctx"
	}

	
	set more off
	
	
	
	
												// Variable processing moved here from geniimpute_body, above

	local imputedvars											// Will hold list of variables to be imputed									
	
	foreach var of varlist `thePTVs'  {
		capture drop `imputeprefix'`var'
		capture drop `missingflagprefix'`var'
	
		quietly clonevar `imputeprefix'`var' = `var' 
		local imputedvars `imputedvars' `imputeprefix'`var'
		local varlab : variable label `var'
		local newlab = "IMP " + "`varlab'"
		quietly label variable `imputeprefix'`var' "`newlab'"
	}
	
	foreach var of varlist `thePTVs' {
		quietly generate `missingflagprefix'`var' = missing(`var')
		capture label var `missingflagprefix'`var' "Was `var' originally missing?"
	}
		
	local nptvs: list sizeof varlist
	local nadd: list sizeof additional
	
	local addvars = "`additional'"								// Need a local that can be overwritten as `additional' cannot

	if (`nptvs' + `nadd' > 30) {
		if (`nptvs' > 30) {
			display as error "Cannot impute more than 30 variables."
			error 999
		}
		else {
			local newaddcount = 30 - `nadd'
			local newadditional
			local count = 0
			display as error "WARNING: Restricting additional variables to `newaddcount' to satisfy the 30-variable limit:"
			foreach var of varlist `additional' {
				local newadditional `newadditional' `var'
				local count = `count' + 1
				if (`count' >= `newaddcount') continue, break	// Break out of loop when reach max length of impute varlist
			}
			display as error "{text}{pstd}using only first `count' additional vars: {bf:`newadditional'}"
			display ""											// Maybe should use variables with greatest N of valid cases?						***
			local addvars = "`additional'"
		}
	} //endif `nptvs'
	

												// Here call geniimpute_body once for each context

	global temp = ""											// Name of file with imputed vars for first context
	global appendtemp = ""										// Names of files with imputed vars for all subsequent contexts
	
	quietly levelsof `ctxvar', local(C)
	local ncontexts : list sizeof C						

	if (`limitdiag' != 0)  display _newline "Looping over `ncontexts' contexts and/or stacks..."


	foreach c of local C   {									// Replace this with forvalues c = 1/`ncontexts' id _mkcross makes adjacent ids?	*** 							***

		local contextLabel : label (`ctxvar') `c'				// Moved from geniimpute_body

		preserve
			quietly keep if `ctxvar'==`c'						// `themin' references option `rangemin' changed from `minofrange'
					
			geniimpute_body `thePTVs',  ctxvar(`ctxvar') c(`c') nc(`ncontexts') ip(`imputeprefix') mfp(`missingflagprefix') select(`select') ///
				mcn(`missingCntName') mic(`missingImpCntName') theptvs(`thePTVs') imputedvars(`imputedvars') addvars(`addvars')	///
				contextlabel("`contextLabel'") extradiag(`extradiag') round(`round') dropmissing(`dropmissing') noinflate(`noinflate') /// 
				replace(`replace') boundvalues(`boundvalues') minofrange(`minofrange') maxofrange(`maxofrange') limitdiag(`limitdiag')
																
			tempfile `c'										// `c' becomes context-specific tempfile name
			
			keep `ctxvar' `iprefix'* `mprefix'* `missingCntName' `missingImpCntName'
																// Keep just additions to original data
			quietly save `c'									// Save in temp file for this context
			if `c'==1  global temp = "`c'.dta"					// Name of file holding imputed data for first contect
			if `c'>1  global appendtemp = "$appendtemp `c'.dta" // Extending list of files that hold imputed data for later contexts
		
		restore

	} //next c
	display ""

	
	

	preserve									// Here retrieve imputed data for first context then append imputed data for remaining contexts
	
																
		quietly use $temp, clear								// First context, saved in previous codeblock
		local napp = wordcount("$appendtemp")
		forvalues i = 1/`napp'  {
		  local a = word("$appendtemp",`i')
		  quietly append using "`a'", nonotes nolabel			// Maybe make this "using `i'" if _mkcros always creates adjacent ids
		}
		tempfile imputeddata
		quietly save `imputeddata'								// Save the imputed data to merge with the full dataset, below
		erase $temp 
		local napp = wordcount("$appendtemp")
		forvalues i = 1/`napp'  {
		  local a = word("$appendtemp",`i')
		  erase `a'												// Maybe make this "erase `i'" if _mkcros always creates adjacent ids
		} // next `a'
	
	restore														// Restore the original dataset as it was when genii was invoked

	
	
	
												// Here tidy up befpre proceeding with next varlist, if pipes syntax is in use, or exiting iimpute

	global temp ""												// Effectively drop these globals
	global appendtemp ""
	
	quietly merge m:m `ctxvar' using `imputeddata'				// Merge in the remaining (unimputed) variables
	drop _merge

	erase `imputeddata'											// Erase remaining temporary dataset

	if ("`replace'" != "") {
		capture drop `varlist'									// Drop unimputed versions of imputed vars if optioned
	}

	if ("`keepmissing'"=="") {
		capture drop `missingflagprefix'*						// Drop all m_ variables (flags denoting originally missing), if optioned
	}
	

	capture drop __000*											// In case any tempvars are left
	capture drop _hb_temp_ctx									// This var probably should be a tempvar ***
	capture label drop _hb_temp_ctx


	
	
	
	
												// Here establish defaults for following varlist, if any, in globals retrieved at start of geniimputeP
												
	global opt1 = ""											// Replace $opt1 with current $opt1 options in case there is another varlist
	foreach parm in `imputeprefix' `missingflagprefix' /*`missingCntName' `missingImpCntName'*/ `usestacks' { 
	  global opt1 = "$opt1 `parm'"								// Simple list needs to be matched with option-names when retrieved
	}

	
	global opt2 = ""											// $opt2 holds flag options
	foreach parm in `extradiag' `round' `dropmissing' `noinflate' `replace' `boundvalues' {
	  if "`parm'" !=""  global opt2 = "$opt2 `parm'"			// When retrieved, these need to be placed in corresponding locals
	}
		  
	global opt3 = ""											// $opt3 holds numeric options in "option=integer " with space before next option
	foreach parm in minofrange=`minofrange' maxofrange=`maxofrange' limitdiag=`limitdiag'  {
	  gettoken optname optval : parm, parse("=")				// Unfortunately I could not figure out how to do this for string options ($opt2)			***
	  global opt3 = "$opt3 `optname'=" + substr("`optval'",2,.) // Save all non-missing values for subsequent varlist/options
	}

	global contextvars = "`contextvars'"
	global additional = "`additional'"
	global stackid = "`stackid'"
		

set trace off

end




