
capture program drop geniimputeP

*! this ado file contains programs geniimputeP and geniimputeP_body

program define geniimputeP

*! geniimputeP (was geniimpute) version 2 is called by geniimpute version 2 to run under Stata versions 9/16, updated Feb,Apr'23 by MNF
*! Minor tweaks in Nov 2024

	// This program is called by geniimpute once for each varlist, if user employs piped syntax. It, in turn, calls geniimpute_body, 
	// which impliments the multi-varlist technology to process on one pass all varlists grouped by the wrapper on the basis that
	// they have identical options in effect.
	// (below) once for each context, having first created needed variables and local vars (passed as arguments to geniimpute_body)
	//    Lines terminating in "**" should be inspected if this code is adapted for use in a different `cmd'							**
	//    Lines terminating in "***" are for Lorenzo to inspect and hopefully agree with changes in logic								**
	 
	// NOTE: ORIGINAL DATA IS SAVED OR PRESERVED IN A DIFFERNT FRAME/FILE AT LINE 210, SO ALL IMPUTATION IS DONE ON WORKING DATA/FRAME) **



	version 11													// iimputeP version 2.0

	
	syntax anything  ,   ///		
		[ ADDvars(varlist) CONtextvars(varlist) STAckid(varname) MINofrange(integer 0) MAXofrange(integer 0) IPRefix(name) MPRefix(name)] ///	**
		[ ROUndedvalues BOUndedvalues LIMitdiag(integer -1) EXTradiag KEEpmissing NOInflate SELected EXTradiag REPlace NEWoptions ]	///	**
		[ MODoptions NODIAg NOCONtexts NOSTAcks nvarlst(integer 1) ctxvar(varname) nc(integer 0) c(integer 0) wtexplst(string) ] 									//	**

										// MCOuntname and MIMputedcountname dropped to conform with gendist 	***
	local cmd = "geniimpute" 

	
	mata: st_numscalar("VERSION", statasetversion())			// Get stata verion # (*100) from Mata (PUT SCALAR IN ALL CAPS)


	
	
												// Convert original default options (or revised defaults) for piped syntax)

	local imputeprefix = "i_"									// This and next cmds set documented default prefix strings
	local missingflagprefix = "mi_"
	  
	if ("`stackid'" == "")  local usestacks ="no"
	if ("`stackid'"!="")  local usestacks ="yes"				// Provides symmetrical flag, always one or the other
	if ("`boundedvalues'"!="") {
		local boundvalues = "boundvalues"						// for conformity with legacy usage
	}
	else local boundvalues = ""							  		// Empty the flag for conformity with version 1

	if ("`roundedvalues'"!="") {
		local roundvalues = "roundvalues" 						// Shorten option-name, as implemented below
	}
	else local roundvalues = ""
	
	local inflate = 1											// Translate into positive dummy var
	if "`noinflate'"!=""  local inflate = 0

	if (`limitdiag'==0) {
		global noisily = "no"
	}
	else global noisily = "yes"									// Also sets flag for subsequent calls on geniimputeP
	
/*	if ("`extradiag'"=="extradiag") & `limitdiag' ==0  {		// Cannot have extra diagnostics with no diagnostics
		local limitdiag = -1									// Set unlimited if no limit set
		global noisily = "yes"
	}
*	if (`limitdiag'==-1)  local limitdiag = .					// Make it a really big number, always greater than `ctxvar'
*/																// (comment out because done in genii_body)
	
	
	capture confirm variable SMmiscnt							// See if SMmiscnt still has values from previous calL
	
	if _rc==0  {
	  	if `c' == 1  {											// If this is first context...
			display as error "Variable SMmiscnt has values from previous call on geniimpute. Replace them?"
*                		      12345678901234567890123456789012345678901234567890123456789012345678901234567890
			capture window stopbox rusure "Variable SMmiscnt has values from previous call on geniimpute. Replace them?"
			if _rc {
				global exit = 1
				exit 1
			}
			else  {
				drop SMmiscnt
*				quietly generate SMmiscnt = .					// Will be initialized with egen below
				noisily display _newline "Execution continues..." _newline
			}
		} //endif 'c'==1	
		
	} //endif _rc==0											// Next command involving this var generates it


	
	capture confirm variable SMmisimpcnt
	
	if _rc==0  {												// Else drop and re-initialize the variable
		if `c'==1  {
			display as error "Variable SMmisimpcnt has values from previous call on geniimpute. Replace them?"
			capture window stopbox rusure ///
							 "Variable SMmisimpcnt has values from previous call on geniimpute. Replace them?"
			if _rc  {
				global exit = 1
				exit 1
			}
			else  {
				drop SMmisimpcnt
				quietly generate SMmiscnt = .					// Next reference involving this var replaces it
				noisily display _newline "Execution continues..." _newline
			}
		} //endif `c'==1
	}
	
	else  quietly generate SMmisimpcnt = .						// Next reference to this var replaces it

			


	local missingCntName = "SMmiscnt"							// Though no longer addd to data, still needd for functnlty ***
	local missingImpCntName = "SMmisimpcnt"						// Ditto

	
	
	
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
	

	
	
												// HERE STARTS PRE-PROCESSING OF CURRENT CONTEXT (for current context) ...
																// (preparatory to using results for actual processing)
	forvalues nvl = 1/`nvarlst'  {						

		local vl`nvl' = ""										// Will hold list of PTVs to be imputed for this varlist
		local al`nvl' = ""										// Will hold addvars for this varlist

		gettoken anything postpipes:anything,parse("||") 		//`postpipes' then starts with "||" or is empty at end of cmd
																 	
		gettoken precolon anything : anything,parse(":") 		// See if varlist starts with prefixing indicator 
																//`precolon' gets all of varlist up to ":" or to end of string		
		if "`anything'"!=""  {							 		// If not empty we should have a prefix varlist
		    unab addvars : `precolon'							// Replace with `precolon' whatever was optioned for addvars		**
*		    local isprfx = "isprfx"								// Not needed for geniimputeP										**
		    local anything = strltrim(substr("`anything'",2,.))	// strip off the leading ":" with any following blanks
		} //endif `anything'
				
		else  local anything = "`precolon'"						// If there was no colon then varlist was in `precolon'
		
																				
		unab thePTVs : `anything'								// Legacy name for vars for which missing data wil be imputed
		unab addvars : `addvars'

		
		local nvars : list sizeof thePTVs						// # of vars in this (sub-)varlist
		tokenize `anything'
		local first `1'
		local last ``nvars''
		
			
		quietly egen SMmiscnt = rowmiss(`thePTVs')			// Var holding N of missing cases for variable to be impoted
		capture label var SMmiscnt "N of missing values in `nvars' variables to impute (`first'...`last')"
		capture label var SMmisimpcnt "N of missing values in `nvars' imputed variables (`first'...`last')"

		
		
		foreach var of local thePTVs  {							// Faster than using (now redundant) varlist
		
			capture drop `imputeprefix'`var'
			capture drop `missingflagprefix'`var'
	
			quietly clonevar i_`var' = `var' 					// Initialize imputed version of 'var' with original values
			local imputedvars `imputedvars' i_`var'				// (stata will exit with error if this is not a variable)
			local varlab : variable label `var'
			local newlab = "IMPUTD " + "`varlab'"				// (and label it)
			quietly label variable i_`var' "`newlab'"

			quietly generate mi_`var' = missing(`var')
			capture label var mi_`var' "Was `var' originally missing? (1=yes)"
			local missingvars `missingvars' mi_`var'
*		  }
			
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
		
		local vlnvl = "vl`nvl'"
		global vlnvl = "`thePTVs'"								// Varlist (thePTVs) for this nvarlist (of multivarlist)
		local alnvl = "al`nvl'"
		global alnvl = "`alladdv'"								// Additional varlist for this `nvl' (as above)

		if "`postpipes'"==""  continue, break					// Break out of multi-varlist loop if no more varlists				**
		local anything = strltrim(substr("`postpipes'", 3, .))	// Else put remaining varlist(s) in `anything'						**
*		local isprfx = ""										// Switch off the prefix flag if it was on (not used in geniimpute)	**
		
	} //next `nvl' (varlist) 									// (in this multi-varlist)
	
	
	local added = "`alladdv'"									// Need a local that can be overwritten, as `addvars' cannot

	local maximpvar = `maxPTVs' + `maxaddv'
	if (`maximpvar' > 30) {
		display as error "Max of 30 vars for varlist + additional – you have specified `maximpvar'{txt}"
		window stopbox note ("Max of 30 vars for varlist + additional – you have specified `maximpvar'")
		global exit = 1
	}

	if $exit  exit 1
	
												// HERE DO ACTUAL PROCESSING OF CURRENT CONTEXT ...	
	
	geniiP_body , weight(`weight') c(`c') nc(`nc') limitdiag(`limitdiag') nvarlst(`nvarlst') inflate(`inflate')
						

			
			
end //geniimputeP



******************************************************** END geniimputeP **************************************************************



****************************************************** BEGIN geniiP_body **************************************************************




capture program drop genii_body

program define geniiP_body

*! geniimpute_body version 2 is called from geniimputeP version 2 (above) to run under Stata version 9, updated Feb'23 by Mark Franklin
*! geniimpute_body calls the superseded Stata 'impute' command

	version 16.1												// geniimputeP_body version 2.0

	// This program is called by geniimputeP (above) once for each context for which imputed variables are to be 
	// calculated. It is changed from previous versions by having all reference to contexts removed, since it is 
	// called by geniimputeP once per context per (multi-)varlist instead of once per varlist.

	
	syntax , [ wtexplst(string) nc(integer 0) c(integer 0) limitdiag(integer -1) nvarlst(integer 0) inflate(integer 0) selected ] ///
			 [ rounded bounded extradiag ] *
	
																// varlist is passed in a set of globals, one for each nvl
	
	if "`wtexplst'"!="" local weight = word("`wtexplst'",`nvl')															
																// limitdiag(string) presumably allows that string to sometimes be "."

	local thiscontext = `c'										// Transfer local parameters set in wrapper & transferred thru `cmd'P 

												/*	
												incremental simple imputation logic: select cases with 1 missing PTV, impute that PTV 
												(starting from PTVS with fewest missing cases...); then cases with 2, etc..., until you 
												reach cases with all PTVs missing. On PTVs in imputed cases, add random noise so that 
												variance equals variance in non-missing cases.
												
												`missingCntName and missingImpCntname are retained in the code, used for extra diagnostics'
												*/		
												
												
	local nonmisPTVs = ""										// Local to hold relevant liist
												
												// count observations in this context (same count for each sub-varlist in any multi-varlist)
												
	quietly count /*if `contextvar'==`context'*/				// All these `if's removed as working data comes from just 1 context

	local numobs = r(N)											// N of observations in this context
				
	local thiscontext = `c'										// Passed as argument from geniimputeP from stackmeWrapper
		
	if `limitdiag'==-1  local limitdiag = .						// Make that a very large number
	local showDiag = 1											// By default show all diagnostics
	local showMode = "noisily"

	if (`limitdiag'==0 | (`thiscontext' > `limitdiag')) {		// If diagnostics limited to 0 or non-0 limit reached . . .
		local showDiag = 0
		local showMode = "quietly"
	}
	local lbl : label lname `c'
		
	
	
	
	
	forvalues nvl = 1/`nvarlst'  {								// Pre-process (each) varlist in (any) multi-varlist
	  
	  local vlnvl = "vl`nvl'"									// Varlist for each nlv was stored in global by geniimputeP
	  local varlist = "$vlnvl" 
	  global vlnvl = ""
	  local alnvl = "al`nvl'"
	  local added = "$alnvl"									// Varlist for added vars derived as for main varlist, above
	  global alnvl = ""
	  local thePTVs = "`varlist'"								// Varlist derived from global above, originating in geniimputeP
	  local usedPTVs = ""

	  local countPTVs = 0
	  local countUsedPTVs = 0
	  local miscnts = ""										// List of missing counts per PTV
		
	  foreach var of local varlist {							// Process each PTV (legacy name for vars to be imputed)
			
		quietly count if missing(`var') 
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
		
		
	  if "`nonmisPTVs'" != "" & `c'==1  {						// Some vars in varlist had no missing values to be imputed
		
		display as error _newline "Option as 'addional' any vars that have no missing values: {bf:`nonmisPTVs'}{txt}"
		window stopbox note "Option as 'addional' any vars that have no missing values (see displayed list)"
		global exit = 1
		exit 1 
	  }
	  
	  local countUnusedPTVs = `countPTVs' - `countUsedPTVs'		
	  
	  
	  if `showDiag' noisily display _newline _newline "   Context `lbl' has `numobs' cases "	_continue

		
	  if `countUsedPTVs' > 0  {										// No further processing if this context has no cases		
		  local missingCounts ""
		  local npty = 0
		  foreach var of local usedPTVs {
			local npty = `npty' + 1
			local thisN = word("`miscnts'", `npty')					//`thisN' now holds N missing for this usedPTV
				// very, very dirty trick:							// Mark thinks its a pretty neat trick! 								***
			local missingCounts = "`missingCounts'" +   ///
			  substr("000000",1, 7-strlen("`thisN'")) + ///
			  "`thisN'_`var' "										// Final space ensures one word per party
		  } //next var
			  
	  } //endif count

	  local missingCounts : list sort missingCounts				// Sort missingCounts_varname into ascending order by missingCounts
	  local nvals = wordcount("`missingCounts'")

		
		
		
	  if "`selected'" != ""  {				// This option selects only additional vars with more missing cases than in missingCounts	***
		
			local lastCount = word("`missingCounts'",`nvals')		// Last count has greatest N of missing for any var to be imputed
			local maxval = real(substr("`lastCount'",1,7))
			local select = ""										// Initialize list of vars selected as above
			foreach var of varlist `added'  {						// Go thru list of vars optioned as additional
		 		quietly count if missing(`var') 
				if r(N)<=`maxval' local select ="`select' `var'"	// Append to list of vars with few enough missng cases (check if needd) ***
			}														// (thus, add vars with fewer than 'maxval' missing cases)
			local added = "`select'"								// Keep only selected vars in `added'
	  } //endif `select'


	
	  local prevnum = .
	  local thesePTVs = ""
	  local orderedPTVs = ""					// `orderedPTVs' collects up usedPTVs, already ordered by N missing in 'missingcounts'		***
			
*	  foreach mc in local "`missingCounts'"  {						 	// Doesnt work with 'foreach mc of local missingCounts'
	  forvalues i = 1/`nvals'  {										 // 'nvals' is wordcount of missingCounts (found above)
			local mc = word("`missingCounts'",`i')						 // `missingCounts' was sorted into order of thisN above
			local thisnum = real(substr("`mc'",1,7))
			local thisvar = substr("`mc'",9,.)							 // Skip over the "_" between `thisnum' and `thisvar'
			local thesePTVs = "`thesePTVs'" + " `thisvar'"			 	 // Accumulate list of PTVs in order of N of missing values
	  } //next /*`mc'*/ `i'

		

	  if "`weight'"!="" local weight = word("`wtexp'",`nvl')			 // Needed for call on cmd impute below

		
		
					
					
					
												// Impute each member of `thesePTVs' in turn, moving it from `thesePTVs' to `imputedPTVs"'

		local remainingPTVs = "`thesePTVs'"							 	 // `thesePTVs' are already ordered by N of missing values
		local imputedPTVs = ""											 // List of imputed PTVs, to be used in following imputations
		while "`remainingPTVs'" != ""  {								 // Continue imputing until there are no `remainingPTVs' 

			gettoken thisPTV remainingPTVs : remainingPTVs			 	 // Remove first varname from remaining PTVs; is var to be imputed
			quietly count if missing(`thisPTV')							 // Get N of missing cases for this PTV within this context
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
			
			} //endif														
			
		} //endwhile													 // Ensure subsequnt imputatns benefit from already imputed vars
		

		tempvar SMmiscnt												// Needed for subsequent varlists
		quietly egen `SMmiscnt' = rowmiss(`varlist')					// Var holding N of missing cases for variables to be impoted
		capture label var `SMmiscnt' "N of missing values in `nvars' variables to impute (`first'...`last')"

		tempvar SMmisimpcnt												 // Record n of missing values in imputed variables per case 
		quietly egen `SMmisimpcnt' = rowmiss(`imputedPTVs') 			 
*		quietly replace `SMmisimpcnt' = `tmpXXX'-`countUnusedPTVs' 		 // DK why we would subtract `countUnusedPTVs' ??????????			***


		
					

												// Display diagnostics for vars in original varlist


		local lenN = strlen(string(`numobs'))							// Allow space for longest N with most characters 
*		local savendiag = `ndiag'										// DK whar for
		local ndiag = 0													// Cluge to stop multiple inflate diagnostics		
		local npty: list sizeof varlist									// Re-using a now redundant local

	
	
*set trace on	
		foreach var in `varlist' {
			
			quietly summarize `var' /*if mi_`var'==0*/ 					// Get stats for just non-missing values
			local oM = string(r(max))									// Don't use this 'cos different vars have different max
			local oN = string(r(N))										// Instead use length of N (guaranteed big enough)
			local oSD = string(r(sd))									// DIAGNOSTIC FOR N=0 is in wrapper									***
			local oSD = substr("`oSD'",1,4)
																						
			quietly summarize i_`var' /*if !missing(i_`var')*/				// Get N and SD of imputed var, including unimputed values	
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
				local space1 = substr("          ",1,9-`lenwrd')
				local space2 = substr("          ",1,`lenN'-strlen("`iN'"))
				display _newline "`name':`space1'original N`blnk'`oN' SD `oSD',`space2' imputed N `iN' SD `iSD'," _continue
				local ndiag = `ndiag' + 1

			  }															// For some unfathomable reason {space `gapo'(=1)} prints as "   "

			  

			  
			  if (`inflate' & `showDiag')  {							// From  `noinflate' during option post-processing in cmd'P

				quietly replace i_`var' = i_`var'+rnormal(0,`iSD') if mi_`var'==0 
																		// Replace just imputed non-missing values
				quietly summarize i_`var' /*if !missing(`i_var')*/	 	// Surely, need SD of all values, not just imputed values?	 		***	
																		// (but inflated SD still seems high even if we use all values)
				local iSD = string(r(sd))
				local iSD = substr("`iSD'",1,4)
				if (`showDiag')  {
					display " inflated SD `iSD'" _continue
				}

			  } //endif `inflate'

			} //end if r(sd)
			
			else {
				if (`showDiag') {
					display "`var' original SD " %5.2f `originalSD' " has no missing values"
				}

			} // endelse
			
		} //next `var'


	
	
	
													// If optioned, round constrain and/or enforce bounds of (plugged) values
		if ("`rounded'"!="") {
		
			if (`showDiag') {											// Report that this is done, per context, if optioned
				display " rounded" _continue
			}

			foreach var in `usedPTVs' {
			   if `oM' <= 1  {											// Round to nearest .1 if r(max)<=1
				   quietly replace i_`var' = round(i_`var', .1) if mi_`var'==0  // Replace if i_var is not missing
			   }														// Else round to nearest .1
				   else quietly replace i_`var' = round(i_`var') if mi_`var'==0 // Replace if i_var is not missing
			}	

		} //endif `rounded'

				
				

		if ("`bounded'" != "")  {	

			if (`showDiag') {											// Report that this is done, per context, if optioned
				display " bounded " _continue												
			}															// Maybe we should do this in iimputeP so as to ensure same

			foreach var in `usedPTVs'  {								//  min and max across contexts. Put varname, min and max
				quietly sum `var'										//  in one word of multi-word local, passed to iimpute_body? 		***
				local boundmin = r(min)	
				local boundmax = r(max)	
				quietly replace i_`var' = `boundmin' if i_`var' < `boundmin'  & mi_`var'==0  // Replace if i_var is not missing
				quietly replace i_`var' = `boundmax' if i_`var' > `boundmax'  & mi_`var'==0  // Replace if i_var is not missing
			}

		} //endif `bounded'
		
				
		 if ("`extradiag'" != ""  & `showDiag' & `oN'>0)  {
			table `SMmiscnt' `SMmisimpcnt', missing stubwidth(30) cellwidth(20)
		 }
		
		 if (`limitdiag'>0 & `thiscontext'==(`limitdiag'+1))  display " " 	// Ensure dots do not occur on same line as last diagnostic
		 if (`showDiag'==0)  display "." _continue	

			  

	} // next nvl
	
	
	
		
end //geniiP_body


****************************************************** END PROGRAM geniiP_body ***************************************************

