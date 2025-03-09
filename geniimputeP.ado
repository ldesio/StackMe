
capture program drop geniimputeP

*! this ado file contains programs geniimputeP and geniimputeP_body

program define geniimputeP

*! geniimputeP (was geniimpute) version 2 is called by stackmeWrapper version 2 to run under Stata versions 9/16, updated Feb,Apr'23 by MNF
*! Minor tweaks in Nov 2024. Reorganized in March 2025 when previous geiimputeP became geniimputeO; here iimputeP_body becomes iimputeP

	// This program is called by stackmeWrapper once for each context, if user employs piped syntax. It, in turn, calls geniimpute_body, 
	// which impliments the multi-varlist technology to process on one pass all varlists grouped by the wrapper on the basis that
	// they have identical options in effect.
	// (below) once for each context, having first created needed variables and local vars (passed as arguments to geniimpute_body)
	//    Lines terminating in "**" should be inspected if this code is adapted for use in a different `cmd'							**
	//    Lines terminating in "***" are for Lorenzo to inspect and hopefully agree with changes in logic								**



	local cmd = "geniimpute" 

*! geniimpute_body version 2 is called from geniimputeP version 2 (above) to run under Stata version 9, updated Feb'23 by Mark Franklin
*! geniimpute_body calls the superseded Stata 'impute' command; reconstructed to be called from 'stackmeWrapper' March '24'

	version 11												// geniimputeP_body version 2.0

	// This program is called by stackmeWrapper once for each context for which imputed variables are to be 
	// calculated. It is changed from previous versions by having all reference to contexts removed, since it is 
	// called by geniimputeP once per context per (multi-)varlist instead of once per varlist.

*set trace on
	
	syntax anything, [ LIMitdiag(integer -1) EXTradiag NOInflate SELected ROUndedvalues BOUndedvalues MINofrange(integer 0) ] ///
			 [ MAXofrange(integer 0) FASt ctxvar(varname) nvarlst(integer 1) nc(integer 0) c(integer 0) wtexplst(string) ] *
			 
			 // rangeofvalues used in geniimputeO to initialize 
	
																 // varlist is passed in a set of globals, one for each nvl

	local thiscontext = `c'										 // Transfer local parameters set in wrapper & transferred thru `cmd'P 

												/*	
												incremental simple imputation logic: select cases with 1 missing PTV, impute that PTV 
												(starting from PTVS with fewest missing cases...); then cases with 2, etc..., until you 
												reach cases with all PTVs missing. On PTVs in imputed cases, add random noise so that 
												variance equals variance in non-missing cases.
												
												`missingCntName and missingImpCntname are retained in the code, used for extra diagnostics'
												*/		

	local inflate = 1
	if "`noinflate'"!="" local inflate = 0
	
	local rounded = 0
	if "`roundedvalues'"!="" local rounded = 1
	
	local bounded = 0
	if "`boundedvalues'"!="" local bounded = 1
												
												
	local nonmisPTVs = ""										// Local to hold relevant list
												
	quietly count /*if `contextvar'==`context'*/				// All these `if's removed as working data comes from just 1 context

	local numobs = r(N)											// N of observations for this context (& stack)
		
	if `limitdiag'==-1  local limitdiag = .						// Make that a very large number

	local showDiag = 1											// By default show all diagnostics
	local showMode = "noisily"
	if (`limitdiag'==0 | (`c' > `limitdiag')) {					// If diagnostics limited to 0 or non-0 limit reached . . .
		local showDiag = 0
		local showMode = "quietly"
	}
	local lbl : label lname `c'
		
	
	
	forvalues nvl = 1/`nvarlst'  {								// Pre-process (each) varlist in (any) multi-varlist
	  
	  local vlnvl = "vl`nvl'"
	  local varlist = "$`vlnvl'" 								// Varlist for each nlv was stored in global by geniimputeP
*	  global `vlnvl' = ""										// Empty that global after transferring contents to local `varlist'
	  local alnvl = "al`nvl'"
	  local added = "$`alnvl'"									// Varlist for added vars derived as for main varlist, above
*	  global `alnvl' = ""
	  local thePTVs = "`varlist'"								// Varlist derived from global above, originating in geniimputeP
	  local usedPTVs = ""

	  local countPTVs = 0
	  local countUsedPTVs = 0
	  local miscnts = ""										// List of missing counts per PTV
		
	  foreach var of local varlist {							// Process each PTV (legacy name for vars to be imputed)
			
		quietly count if missing(`var') 						// MOVE THIS CHECK TO WRAPPER OR TO geniimputeO							***
		local missing = r(N)									// N of missing cases for this PTV within this context
				
		if `missing'==0  local nonmisPTVs ="`nonmisPTVs' `var'" // Accumulate list of non-missing PTVs
		// if no. of missing values less than no. of observations, this PTV is used
		if `missing'<`numobs' & `missing'>0  {					// Mark added check for `missing'>0 (now redundant?) 
			local countUsedPTVs = `countUsedPTVs' + 1			// N of PTVs with some but not all missing cases
			local usedPTVs "`usedPTVs' `var'"					// Store only if some but not all ditto
			local miscnts = "`miscnts' " + string(`missing')
		}
		local countPTVs = `countPTVs' + 1						// N of vars specified by user in varlist
			
	  } //next `var'
		

	  if `c'==2  {												// THIS IS A CLUGE TO SUPPRESS A BLANK LINE AFTER 1ST CONTEXT			***
	     if `showDiag' noisily display /*_newline*/ "   Context `lbl' has `numobs' observations " _continue
	  }
	  else  if `showDiag' noisily display _newline "   Context `lbl' has `numobs' observations " _continue
		
	  if `countUsedPTVs' > 0  {										// Further pre-processing only if more useable PTVs		
		  local missingCounts ""
		  local npty = 0
		  foreach var of local usedPTVs {
			local npty = `npty' + 1
			local thisN = word("`miscnts'", `npty')					//`thisN' now holds N missing for this usedPTV
				// very, very dirty trick:							// Mark thinks its a pretty neat trick! 							***
			local missingCounts = "`missingCounts'" +   ///
			  substr("000000",1, 7-strlen("`thisN'")) + ///
			  "`thisN'_`var' "										// Final space ensures one word per party
		  } //next var
			  
	  } //endif count

	  local missingCounts : list sort missingCounts					// Sort missingCounts_varname into ascending order by missingCounts
	  local nvals = wordcount("`missingCounts'")


	  if "`fast'"==""  {												// 'fast' overrides 'selected' if optioned
		
	     if "`selected'" != ""  {				// This option selects only additional vars with more missing cases than in missingCounts	***
		
			local lastCount = word("`missingCounts'",`nvals')		// Last count has greatest N of missing for any var to be imputed
			local maxval = real(substr("`lastCount'",1,7))
			local select = ""										// Initialize list of vars selected as above
			foreach var of varlist `added'  {						// Go thru list of vars optioned as additional
		 		quietly count if missing(`var') 					// Count N of missing observations
				if r(N)<=`maxval' local select ="`select' `var'"	// Append to list of vars with few enough missng cases (check if needd) ***
			}														// (thus, add vars with fewer than 'maxval' missing cases)
			local added = "`select'"								// Keep only selected vars in `added'
			
	     } //endif `selected'

	  } //endif 'fast'												// 'fast' overrides 'selected' if optioned
	
	  local prevnum = .
	  local thesePTVs = ""
	  local orderedPTVs = ""					// `orderedPTVs' collects up usedPTVs, already ordered by N missing in 'missingcounts'		***
			
*	  foreach mc of local "`missingCounts'"  {						// Doesnt work with 'foreach mc of local missingCounts'
	  forvalues i = 1/`nvals'  {								 	// 'nvals' is wordcount of missingCounts (found above)
			local mc = word("`missingCounts'",`i')					// `missingCounts' was sorted into order of thisN above
			local thisnum = real(substr("`mc'",1,7))
			local thisvar = substr("`mc'",9,.)					 	// Skip over the "_" between `thisnum' and `thisvar'
			local thesePTVs = "`thesePTVs'" + " `thisvar'"			// Accumulate list of PTVs in order of N of missing values
	  } //next `i'
		
		
	  if "`wtexplst'"!=""  {										// Needed for call on 'impute', below
		local weight =subinstr(word("`wtexplst'",`nvl'),"$"," ",.) 	// Replace all "$" by " " (substituted to ensure 1 word per wtexp)
		if "`weight'" == "null"  local weight = ""				 	// Duplicate weight expressions were handled in wrapper program		***
	  }															 	// limitdiag(string) presumably allows that string to sometimes be "."

					
					
					
												// Impute each member of `thesePTVs' in turn, moving it from `thesePTVs' to `imputedPTVs"'

	  local remainingPTVs = "`thesePTVs'"							// `thesePTVs' are already ordered by N of missing values
	  local imputedPTVs = ""										// List of imputed PTVs, to be used in following imputations
	  
	  while "`remainingPTVs'" != ""  {								// Continue imputing until there are no `remainingPTVs' 

			gettoken thisPTV remainingPTVs : remainingPTVs			// Remove first varname from remaining PTVs; is var to be imputed
			quietly count if missing(`thisPTV')						// Get N of missing obs for this PTV within this context
			local availableN = _N - r(N)
			if `availableN'<=(_N-`countUsedPTVs'-wordcount("`added'")) { // Cannot predct vals for var whose N < _N - N of predictrs (N-k)
				tempvar tmp												 // Create tempvar for imputed variable

				if "`extradiag'"!="" & `showDiag'  display "{break}impute `thisPTV' `remainingPTVs' `imputedPTVs' `added'" _continue

				
				
*				**************				
				quietly impute `thisPTV' `remainingPTVs' `imputedPTVs' `added' `weight', generate(`tmp')
*				**************	

				quietly replace i_`thisPTV' = `tmp'			  			// Replace it with imputed version
				drop `tmp'
			
				local imputedPTVs = "`imputedPTVs' i_`thisPTV' " 		//  and add it to `imputedPTVs'
			
			} //endif `available'														
			
	  } //endwhile														// Ensure subsequnt imputatns benefit from already imputed vars
		
		
		

	  if "`fast'"==""  {												// Only display dianostics if 'fast' was not optioned

		local lenN = strlen(string(`numobs'))							// Allow space for longest N with most characters 
		local ndiag = 0													// Cluge to stop multiple inflate diagnostics		
		local npty: list sizeof varlist									// Re-using a now redundant local

	
			
		foreach var in `varlist' {
			
			quietly summarize `var' /*if m_`var'==0*/ 					// Get stats for just non-missing values
			scalar omi = r(min)
			scalar oma = r(max)											// Determine N of chars needed to display max value
			local oM = string(r(max))									// Note that different vars have different max
			local oN = string(r(N))										// Instead use length of N (guaranteed big enough)
			local oSD = string(r(sd))									// DIAGNOSTIC FOR N=0 is in wrapper									***
			local oSD = substr("`oSD'",1,4)
																						
			quietly summarize i_`var' 									// Get N and SD of imputed var, including unimputed values	
			local iN = string(r(N))				
			local iSD = string(r(sd))									// (Doesn't affect inflation, only diagnostics)						***
			local iSD = substr("`iSD'",1,4)
			
			if (r(sd) != .)  {											// This should have generated an earlier error

			  if (`showDiag')  {

				local gapo = `lenN' - strlen("`oM'")
				local gapi = `lenN' - strlen("`iN'")
				local blnk = " "
				local lenwrd = strlen("`var'")
				local name = "`var'"
				if `lenwrd'>8 local name = substr("`name'",1,7) + "~" + substr("`name'",-1,1) 
				local space1 = substr("          ",1,8-`lenwrd')
				local space2 = substr("          ",1,`lenN'-strlen("`iN'"))
				if (`inflate'|`rounded'|`bounded')  {					// Only append '_continue' if more to come
				   display _newline "`name':`space1'originl N`blnk'`oN' SD `oSD',`space2' imputd N `iN' SD `iSD'," _continue
				}
				else  display _newline "`name':`space1'originl N`blnk'`oN' SD `oSD',`space2' imputd N `iN' SD `iSD'"
				   local ndiag = `ndiag' + 1

			  } //endif showdiag										// For some unfathomable reason {space `gapo'(=1)} prints as "   "

			  

			  
			  if "`inflate'"!=""  {										// From  `noinflate' during option post-processing in cmd'P

				quietly replace i_`var' = i_`var'+rnormal(0,`oSD') if m_`var'
																		// Replace just imputed non-missing values
				quietly summarize i_`var' 								// Need SD of all values, not just imputed values	 		***	
	
				local iSD = string(r(sd))
				local iSD = substr("`iSD'",1,4)
				if (`showDiag')  { 
				   local optd = ""
				   if `rounded' local optd = "rounded"
				   if `bounded' local optd = "bounded"
				   if `rounded' & `bounded'  local optd = "r&bnded"
				   if (`rounded'|`bounded')  {
					  noisily display " inflatd SD `iSD' `optd'" 		// Only append '_continue' if more to come
					} 
					else noisily display " inflatd SD `iSD'"
				}

			  } //endif `inflate'
			  
			  else  {													// Else inflate not optioned
			  	local optd = ""
				if `rounded' local optd = "rounded"
				if `bounded' local optd = "bounded"
				if `rounded'&`bounded' local optd = "r&bded"
			  	noisily display " `optd'"

			  } //endelse
			  
			} //endif r(sd)
			
			else {														// Else r(SD) is missing
				if (`showDiag') {
					noisily display "`var' original SD " %5.2f `originalSD' " has no missing values"
				}
			} // endelse

		} //next `var'

	  } //endif !'fast'			
				


	  if !`showDiag' & "`fast'"==""  display "." _continue								// Only show progress dots if diagnostics not optioned

			  

	} // next nvl
	
	
		
end //geniiP_body


****************************************************** END PROGRAM geniimputeP ***************************************************

