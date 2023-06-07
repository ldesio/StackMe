capture program drop geniimputeP

*! this ado file contains programs geniimputeP and geniimputeP_body. It also calls Stata's impute command.

program define geniimputeP

*! geniimputeP (was geniimpute) version 2 is called by stackMeBody version 2 to run under Stata versions 9/16, updated Feb,Apr'23 by MNF

	// This program is called by stackMeWrapper once for each set of varlists, grouped on the basis of having the same options in 
	// effect, if user employs piped syntax. It, in turn, calls geniimpute_body, (below) once for each context, having first created 
	// needed variables and locals, passed as arguments to geniimpute_body, which impliments the multi-varlist technology to process 
	// on one pass all varlists grouped by the wrapper on the basis that they have identical options in effect.
	// 
	//    Lines terminating in "**" should be inspected if this code is adapted for use in a different `cmd' in case of needed changes	**
	//    Lines terminating in "***" are for Lorenzo to inspect and hopefully agree with changes program in logic						**
	 

	version 11												// iimputeP version 2.0

	
	syntax anything [aw fw pw/],   ///		
		[ ADDvars(varlist) CONtextvars(varlist) STAckid(varname) MINofrange(string) MAXofrange(string) IPRefix(name) MPRefix(name)] ///	**
		[ ROUndedvalues BOUndedvalues LIMitdiag(integer -1) EXTradiag KEEpmissing NOINFlate SELected EXTradiag REPlace NEWoptions ]	///	**
		[ MODoptions NODIAg NOCONtexts NOSTAcks nvarlst(integer 1) ctxvar(varname) nc(integer 0) c(integer 0) ] 									//	**
		
																// MCOuntname and MIMputedcountname dropped to conform with gendist 	***
	local cmd = "geniimpute" 									// (these were re-introduced into gendist, as they should be here)		***

	if "`weight'"!="" local wetyp = " [`weight'"				// As in wrapper, two items to store: the weight type
	if "`exp'"!="" local weexp = "=`exp']"						// (types are aw fw pw iw); expression also must be stored
	

	
	mata: st_numscalar("VERSION", statasetversion())			// Get stata verion # (*100) from Mata (PUT SCALAR IN ALL CAPS)
	
		
		
												// Establish original default options (or revised defaults if using piped syntax)


	local imputeprefix = "i_"									// This and next cmds set documented default prefix strings
	local missingflagprefix = "m_"
	  
	if ("`iprefix'"!="") local imputeprefix ="`iprefix'"		// New options override defaults or previous options	
	if ("`mprefix'"!="") local missingflagprefix ="`mprefix'"
	if ("`stackid'" == "")  local usestacks ="no"
	if ("`stackid'"!="")  local usestacks ="yes"				// Provides symmetrical flag, always one or the other
	if ("`boundedvalues'"!="") {
		local boundvalues ="boundvalues"						// for conformity with legacy usage
	}
	else local boundvalues = ""							  		// Empty the flag for conformity with version 1

	if ("`roundedvalues'"!="") {
		local round = "round" 									// Shorten option-name, as implemented below
	}
	else local round = ""

	if (`limitdiag'==0) {
		global noisily = "no"
	}
	else global noisily = "yes"									// Also sets flag for subsequent calls on geniimputeP
	
	if ("`extradiag'"=="extradiag") & `limitdiag' ==0  {		// Cannot have extra diagnostics with no diagnostics
		local limitdiag = -1									// Set unlimited if no limit set
		global noisily = "yes"
	}
	if (`limitdiag'==-1)  local limitdiag = .					// Make it a really big number, always greater than `ctxvar'

	local missingCntName = "_iimpute_mc"						// Though no longer addd to data, still needd for functnlty ***
	local missingImpCntName = "_iimpute_mic"					// Ditto

	capture drop `missingCntName'								// Needed for subsequent varlists
	capture label drop `missingCntName'
	tempvar `missingCntName'
	
	quietly egen `missingCntName' = rowmiss(`varlist')			// Var holding N of missing cases for variable to be impoted
	capture label var `missingCntName' "N of missing values in `nvars' variables to impute (`first'...`last')"

	capture drop `missingImpCntName'
	capture label drop `missingImpCntName'
	tempvar `missingImpCntName'
	
	quietly gen `missingImpCntName' = `missingCntName'			// Default N of missing imputd values to N of unimputd values
	capture label var `missingImpCntName' "N of missing values in imputed versions of `nvars' variables (`first'...`last')"

	
	if ("`stackid'" != "") & ("`nostacks'" == "") {
		local thisCtxVars = "`contextvars' `stackid'"			// In this version `stackid', if any, is included in context
	}
	else  local thisCtxVars = "`contextvars'"

	
	set more off	
	
												// Variable processing moved here from geniimpute_body, below
												// Pre-process multi-varlist, variables saved by iimpute, and contextvars

	local postpipes = "`anything'"							// Pretend `anything' started with (already removed) pipes ("||")
	local maxPTVs = 0										// Initialize count of max # of vars to be imputed
	local allPTVs = ""										// Will hold list of vars from which to generage imputd versns
	local maxaddv = 0										// Will hold count of max # of additional vars
	local alladdv = ""										// Will hold list of all additional vars supportng all imputatns
	local imputedvars = ""									// Will hold list of variables to impute (in all multi-varlsts)
	local missingvars = ""									// Ditto list of vars  with cases where unimputd var was missng
	

	
	
												// HERE STARTS PRE-PROCESSING OF CURRENT CONTEXT 
																// (preparatory to using results for actual processing)
	forvalues nvl = 1/`nvarlst'  {						

		local vl`nvl' = ""										// Will hold list of PTVs to be imputed for this varlist
		local al`nvl' = ""										// Will hold addvars for this varlist

		gettoken anything postpipes:anything,parse("||") 		//`postpipes' then starts with "||" or is empty at end of cmd
																 	
		gettoken precolon anything : anything,parse(":") 		// See if varlist starts with prefixing indicator 
																//`precolon' gets all of varlist up to ":" or to end of string		
		if "`anything'"!=""  {							 		// If not empty we should have a prefix varlist
		  unab addvars : `precolon'								// Replace with `precolon' whatever was optioned for addvars		**
*		  local isprfx = "isprfx"								// Not needed for geniimputeP										**
		  local anything = strltrim(substr("`anything'",2,.))	// strip off the leading ":" with any following blanks
		} //endif `anything'
				
		else  local anything = "`precolon'"						// If there was no colon then varlist was in `precolon'
																				
		unab thePTVs : `anything'								// Legacy name for vars for which missing data wil be imputed
		
		local nvars : list sizeof thePTVs						// # of vars in this (sub-)varlist
		tokenize `anything'
		local first `1'
		local last ``nvars''
		
	
		foreach var of local thePTVs  {							// Faster than using (now redundant) varlist

			capture drop `imputeprefix'`var'
			capture drop `missingflagprefix'`var'
	
			quietly clonevar `imputeprefix'`var' = `var' 		// Initialize imputed version of 'var' with original values
			local imputedvars `imputedvars' `imputeprefix'`var'	// Stata will exit with error if this is not a variable
			local varlab : variable label `var'
			local newlab = "IMPUTD " + "`varlab'"				// (and label it)
			quietly label variable `imputeprefix'`var' "`newlab'"

			quietly generate `missingflagprefix'`var' = missing(`var')
			capture label var `missingflagprefix'`var' "Was `var' originally missing? (1=yes)"
			local missingvars `missingvars' `missingflagprefix'`var'
			
		} //next var 											// (in this varlist)
		
		local nptvs: list sizeof thePTVs						// Get length of (longest sub-)varlist
		if `nptvs'>`maxPTVs'  {
			local maxPTVs = `nptvs'
			local maxPTVlst = "`thePTVs'"
		}
		local allPTVs = "`allPTVs' `thePTVs'"					// Append `thePTV's to accumulting list of `allPTVs'
			
		local naddv: list sizeof addvars						// Same for any additional vars in a multi-varlist
		if `naddv'>`maxaddv'  {
			local maxaddv = `naddv'
			local maxaddvlst = "`addvars'"
		}
		foreach var of varlist `addvars'  {
			if strpos("`alladdv'", "`var'")==0  {				// If this 'var' is not already in the list of 'addvars'
				local alladdv = "`alladdv' `var'"
			}
		}
		
		local vl`nvl' = "`thePTVs'"
		local al`nvl' = "`addvars'"

		if "`postpipes'"==""  continue, break					// Break out of multi-varlist loop if no more varlists				**
		local anything = strltrim(substr("`postpipes'", 3, .))	// Else put remaining varlist(s) in `anything'						**
*		local isprfx = ""										// Switch off the prefix flag if it was on (not used in geniimpute)	**
		
	} //next `nvl' (varlist) 									// (in this multi-varlist)
	
	
	local added = "`alladdv'"									// Need a local that can be overwritten, as `addvars' cannot

	local maximpvar = `maxPTVs' + `maxaddv'
	if (`maximpvar' > 30) {
		display as error "Max of 30 vars for varlist + additional – you have specified `maximpvar'"
		window stopbox stop ("Max of 30 vars for varlist + additional – you have specified `maximpvar'")
	}


	
	
												// HERE DO ACTUAL PROCESSING OF CURRENT CONTEXT ...	
	noisily display " "

	forvalues nvl = 1/`nvarlst'  {								// Pre-process (each) varlist in (any) multi-varlist
			
*		***************
		geniimputeP_body `wetyp'`weexp' `vl`nvl'' `wetyp'`weexp', added(`al`nvl'') c(`c') ctxvar(`ctxvar') nc(`nc') ///
		ip(`imputeprefix') mfp(`missingflagprefix') mcn(`missingCntName') mic(`missingImpCntName') ///
		nvl(`nvl') minofrange(`string') maxofrange(`string') limitdiag(`limitdiag') /*nvarlst(`nvarlst')*/ ///
		`selected' `round' `replace' `extradiag' `dropmissing' `noinflate' `boundvalues' 
*		***************											// 'round' set by option 'roundedvalues'; 'boundvalues' by 'boundedvalues'

	} //next `nvl' 												// (next list of vars having same options)

	
			
			
end //geniimputeP




*------------------------------------------------------Begin geniimputeP_body----------------------------------------------------------



capture program drop geniimputeP_body

program define geniimputeP_body

*! geniimpute_body version 2 is called from geniimputeP version 2 (above) to run under Stata version 9, updated Feb'23 by Mark Franklin

	version 16.1												// geniimputeP_body version 2.0

	// This program is called by geniimputeP (below) once for each context for which imputed variables are to be 
	// calculated. It is changed from previous versions by having all reference to contexts removed, since it is 
	// called by geniimputeP once per context per (multi-)varlist instead of once per varlist.


	syntax varlist [aw fw pw/] ///
				 , added(varlist) c(integer) ctxvar(varname) nc(integer) ip(string) mfp(string) mcn(varname) mic(string) ///
				   limitdiag(string) /*nvarlst(integer)*/ nvl(integer) [ minofrange(string) maxofrange(string) ] ///
				   [ selected round replace extradiag dropmissing noinflate boundvalues ] 

					
	
	// Some unprocessed flag options included in this list
																// limitdiag(string) presumably allows that string to sometimes be "."

	local ncontexts = `nc'										// Transfer local parameters set in iimputeP 
	local imputeprefix = "`ip'"
	local missingflagprefix = "`mfp'"
	local missingCntName = "`mcn'"								// Now a tempvar passed from geniimputeP									***
	local missingImpCntName = "`mic'"							// Ditto, due to complexities arisng from multiple varlists (see help text)	***
	local thePTVs = "`theptvs'"									// thePTVs, created in geniimputeP, passed as `theptvs' (all lowercase)
	if "`minofrange'"!=""  local rangemin = `minofrange'		// `rangemin' and `rangemax' were set earlier according to user options
	if "`maxofrange'"!=""  local rangemax = `maxofrange'		// These commands convert from string to numeric						
	local inflate = 1											// This flag must be post-processed so that it takes on two values
	if "`noinflate'"=="noinflate" inflate = 0					// Remaining options (`imputedvars'...) need no post-processing
																		
												/*	
												incremental simple imputation logic: select cases with 1 missing PTV, impute that PTV 
												(starting from PTVS with fewest missing cases...); then cases with 2, etc..., until you 
												reach cases with all PTVs missing. On PTVs in imputed cases, add random noise so that 
												variance equals variance in non-missing cases.
												
												`missingCntName and missingImpCntname are retained in the code, used for extra diagnostics'
												*/		

												
												
												// count observations in this context (same count for each sub-varlist in any multi-varlist)
												
	quietly count /*if `contextvar'==`context'*/				// All these `if's removed as `geniimpute_body' now handles just 1 context

	local numobs = r(N)											// N of observations in this context
				
	local thiscontext = `c'										// Passed as argument from geniimputeP from stackmeWrapper
		
	local showDiag = 1											// By default show all diagnostics
	local showMode = "noisily"
		
	if (`limitdiag' ==0 | (`thiscontext' > `limitdiag')) {		// If diagnostics limited or limit reached . . .
			local showDiag = 0
			local showMode = "quietly"
	}
	else  {

		if `nvl'==1 {											// If this is 1st varlist of possible multi-varlist set
		
			local contextlabel : label (`ctxvar') `c'			// Get label for this combination of contexts

			noisily display "Context `contextlabel' has `numobs' cases"	
			
		}
	}	

	local countPTVs = 0
	local countUsedPTVs = 0
		
	foreach var of varlist `varlist' {		// Process each PTV (legacy name for vars to be imputed)
			
		quietly count if missing(`var') 
		local missing = r(N)									// N of missing cases for this PTV within this context
				
		if `missing'==0  local nonmisPTVs ="`nonmisPTVs' `var'" // Accumulate list of non-missing PTVs
		// if no. of missing values less than no. of observations, this PTV is used
		if `missing'<`numobs' & `missing'>0  {					// Mark added check for `missingPTVs'>0 (now redundant?) 
			local countUsedPTVs = `countUsedPTVs' + 1			// N of PTVs with some but not all missing cases
			local usedPTVs `usedPTVs' `var'
			local ptvobs = `numobs' - `missing'
			local miscnts = "`miscnts' " + string(`missing')
		}
		local countPTVs = `countPTVs' + 1						// N of vars specified by user in varlist
			
	} //next `var'
		
		
		
		
		
	if "`nonmisPTVs'" != "" & `c'==1  {			// Some vars in varlist had no missing values to be imputed
		
		display as error _newline "Option as 'addional' any vars that have no missing values: {bf:`nonmisPTVs'}"
		window stopbox stop "Option as 'addional' any vars that have no missing values (see displayed list)"
	}

	local countUnusedPTVs = `countPTVs' - `countUsedPTVs'		
		
		
		
		
	if `countUsedPTVs' > 0  {								// No further processing if this context has no cases
		
				
		
		
		local missingCounts ""
		local npty = 0
		foreach var of local usedPTVs {
			local npty = `npty' + 1
			local thisN = real(word("`miscnts'", `npty'))
				// very, very dirty trick:							// Mark thinks its a pretty neat trick! 								***
			local missingCounts = "`missingCounts'" +  ///
			  substr("000000",1,7-length("`thisN'")) + ///
			  "`thisN'_`var' "										// Final space ensures one word per party
		} //next `var'

		local missingCounts : list sort missingCounts				// Sort missingCounts_varname into ascending order by missingCounts
		local nvals = wordcount("`missingCounts'")
		
		
		
		if "`selected'" != ""  {				// This option selects only additional vars with more missing cases than in missingCounts	***
		
			local lastCount = word("`missingCounts'",`nvals')		// Last count has greatest N of missing for any var to be imputed
			local maxval = substr("`lastCount'",1,7)
			local select = ""										// Initialize list of vars selected as above
			foreach var of varlist `added'  {
				quietly count if missing(`var') 
				if r(N)>`maxval' local select ="`select' `var'"		// Append to list of vars with few enough missng cases (check if needd) ***
			}
			local added = "`select'"								// Replace 'added' (was `addvars') with selected vars
		} //endif `select'

		
		
		local prevnum = .
		local thesePTVs = ""
		local orderedPTVs = ""					// `orderedPTVs' collects up usedPTVs, already ordered by N missing in 'missingcounts'		***
			
*		foreach mc in "`missingCounts'"  {								 // This syntax didn't distinguish successive words
		forvalues i = 1/`nvals'  {										 // 'nvals' is number of missingCounts
			local mc = word("`missingCounts'",`i')
			local thisnum = real(substr("`mc'",1,7))
			local thisvar = substr("`mc'",9,.)							 // Skip over the "_" between `thisnum' and `thisvar'
*			if `thisnum' == `prevnum'  {								 // Initialized for use in 'else' block below, now commented out
			local thesePTVs = "`thesePTVs'" + " `thisvar'"			 	 // Accumulate list of PTVs in order of N of missing values

		} //next /*`mc'*/ `i'


		local wt = ""
		if "`weight'" != ""  local wt = "[`weight'=`exp']"
		
		
		
		
		
					
												// Impute each member of `thesePTVs' in turn, moving it from `thesePTVs' to `imputedPTVs"'

		local remainingPTVs = "`thesePTVs'"							 	 // `thesePTVs' are already ordered by N of missing values
		local imputedPTVs = ""											 // List of imputed PTVs, to be used in following imputations
		
		while "`remainingPTVs'" != ""  {								 // Continue imputing until there are no `remainingPTVs' 

			gettoken thisPTV remainingPTVs : remainingPTVs			 	 // Remove first varname from remaining PTVs; is var to be imputed
			quietly count if missing(`thisPTV')							 // Get N of missing cases for this PTV within this context
			local availableN = _N - r(N)
			if `availableN'<=(_N-`countUsedPTVs'-wordcount("`added'")) { // Cannot predct vals for var whose N < _N - N of predictrs (N-k)
				tempvar tmp												 // Create tempvar for imputed variable

				if "`extradiag'"!="" & `showDiag'  display "{break}impute `thisPTV' `remainingPTVs' `imputedPTVs' `added'"

*				**************				
				quietly impute `thisPTV' `remainingPTVs' `imputedPTVs' `added' `wt', generate(`tmp')
*				**************

				quietly replace `imputeprefix'`thisPTV' = `tmp'			  // Replace it with imputed version
				drop `tmp'
			
				local imputedPTVs="`imputedPTVs' `imputeprefix'`thisPTV' " //  and add it to `imputedPTVs'
			
			} //endif														
			
		} //endwhile													 // Ensure subsequnt imputatns benefit from already imputed vars
		
		tempvar tmpXXX													 // Record n of missing values per case in `missingImpCntName'
		quietly egen `tmpXXX' = rowmiss(`imputedPTVs') 
		quietly replace `missingImpCntName' = `tmpXXX'-`countUnusedPTVs' // DK why we would subtract `countUnusedPTVs' ??????????			***
		quietly drop `tmpXXX'

		
					
					

		
		
		local lenN = length("`numobs'")			// Allow space for longest N (ie context N) in displayed diagnostics per variable
		
		foreach var in `usedPTVs' {
			local gap = 12 - length("`var'")							// Get len of gap before varname while `var' is not yet a varname
			quietly summarize `imputeprefix'`var' if `missingflagprefix'`var'==0 
			local oN = r(N)												// N and SD for items not originally missing
			local oSD = r(sd)											// *** SHOULD HAVE DIAGNOSTIC FOR N=0 (now just omitted)			***
																						
			quietly summarize `imputeprefix'`var' 						// Get N and SD of imputed var, including unimputed values	
			local iSD = r(sd)											// (Doesn't affect inflation, only diagnostics)						***
			local iN = r(N)				
			
			if (`iSD' != .) {

			  if (`showDiag')  {

				local gapo = `lenN' - length("`oN'")
				local gapi = `lenN' - length("`iN'")
				local blnk = " "
				if `gapo'==1  display "`var': {space `gap'} original N `blnk'`oN' SD " %5.2f `oSD' ",{space `gapi'} imputed N `iN' SD " %5.2f `iSD' "," _continue
				else display "`var': {space `gap'} original N {space `gapo'} `oN' SD" %5.2f `oSD' ",{space `gapi'} imputed N `iN' SD " %5.2f `iSD' "," _continue
			  }															// For some unfathomable reason {space `gapo'(=1)} prints as "   "

			  
								
			  if (`inflate' == 1) {										// From option `noinflate' during option post-processing, above
				quietly replace `imputeprefix'`var' =`imputeprefix'`var'+rnormal(0, `oSD') if `missingflagprefix'`var'==1 
																		//Inflate just imputed values
				quietly summarize `imputeprefix'`var' /*if `missingflagprefix'`var'==1*/ 
																		// Surely, need SD of all values, not just imputed values?	 		***
			
				local iSD = r(sd)
				if (`showDiag') {
					display " inflated SD " %5.2f `iSD' /*"{break}"*/
				}
			  } //endif `inflate'
			} //end if `iSD'
			
			else {
				if (`showDiag') {
					display "`var' original SD " %5.2f `originalSD'  " has no missing values"
				}

			} // endelse

		} //next `var'
	  		
	
												
												// If optioned, round, constrain, and/or enforce bounds of (plugged) values
		if ("`round'"=="round") {
		
			if (`showDiag') {											// Report that this is done, per context, if optioned
				display "rounded " _continue
			}

			foreach var in `usedPTVs' {
				quietly replace `imputeprefix'`var' = round(`imputeprefix'`var') if `missingflagprefix'`var'==1 
			}	

		} //endif `round'

				
		
		if ("`minofrange'" != "") | ("`maxofrange'" != "") {

			local nconstr = 0
			foreach var in `usedPTVs' {

				if ("`minofrange'" != "") {
					quietly replace `imputeprefix'`var' = `rangemin' if `imputeprefix'`var' < `rangemin'  & ///
														  `missingflagprefix'`var'==1 
					local nconstr = 1
				}																
				if ("`maxofrange'" != "") {	
					local nconst = `nconstr' + 1
					if (`showDiag') {											
						if `nconstr'==1  display "constrained " _continue
						if `nconstr'==2  display "constrained `rangemin' - `rangemax'" _continue			
					}															
					quietly replace `imputeprefix'`var' = `rangemax' if `imputeprefix'`var'>`rangemax' & ///
														  `imputeprefix'`var'<. & `missingflagprefix'`var'==1 
				} //endif 'maxofrange'
				if (`showDiag') {										// Report that this is done, per context, if optioned
					display "constrained " _continue
				}
			}	

		} //endif `minofrange'	
		
		
		if ("`boundvalues'" != "")  {	

			if (`showDiag') {											// Report that this is done, per context, if optioned
				display " bounded " _continue												
			}															// Maybe we should do this in iimputeP so as to ensure same

			foreach var in `usedPTVs'  {								//  min and max across contexts. Put varname, min and max
				quietly sum `var'										//  in one word of multi-word local, passed to iimpute_body? 		***
				local boundmin = r(min)	
				local boundmax = r(max)	
				quietly replace `imputeprefix'`var' = `boundmin' if `imputeprefix'`var' < `boundmin'  & `missingflagprefix'`var'==1 
				quietly replace `imputeprefix'`var' = `boundmax' if `imputeprefix'`var' > `boundmax'  & `missingflagprefix'`var'==1 
			}

		} //endif `boundvalues'
		
				
		if ("`extradiag'" != ""  & `showDiag')  {
			table `missingCntName' `missingImpCntName', missing stubwidth(30) cellwidth(20)
		}
		
		if (`ncontexts'==`limitdiag')  display " " 						// Ensure dots do not occur on same line as last diagnostic
		if (`showDiag'==0)  display "." _continue	

	} //if `countUsedPTVs'
	
		
end //geniimpute_body


