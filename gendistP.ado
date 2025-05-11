
capture program drop gendistP					// Program that does the heavy lifting for gendist, context by context

program define gendistP										// Called by 'stackmeWrapper'; calls subprograms 'errexit'

	version 9.0												// gendist version 2.0, June 2022, updated May 2023
	
*!  Stata version 9.0; gendistP (was gendist until now) version 2, updatd May'23 from major re-write in Mar'23
*!  Stata version 9.0; gendist version 2, updated Mar'23 from major re-write in June'22
*!  Stata version 9.0; gemdistP version 2a updated July'24 to implement unstacked capabilities
	
	//    Version 2 removes recently introduced code to plug plr==rlr with diff-means, as though the plr 
	// value had been missing. (This treatment turns out to be only appropriate when distances are from 
	// constant-valued party positions, else varying plrs will have their variance arbitrarily truncated). 
	// It introduces a new "plugall" option that plugs all plr values with the same (mean) plugging value, 
	// producing the constant values suited to plugging plr==rlr as though they were missing. Full [if][in] 
	// processing now done in wrapper. [weight] processing still done in gendistP. Previous use of 'egen, by'
	// was unable to handle new weighting requirements.
	
	
global errloc "gendistP"						// Global that keeps track of execution location for benefit of 'errexit'

********
capture {										// Open capture braces mark start ot code where errors will be captured
********	
	

    syntax anything [aw fw pw iw/], [ SELfplace(varname) CONtextvars(varlist) MISsing(string) PPRefix(string) ] ///
		[ MPRefix(string) DPRefix(string) APRefix(string) MPLuggedcountname(name) LIMitdiag(integer -1) ] 		///
		[ EXTradiag(integer 0) MCOuntname(name) PLUgall ROUnd REPlace NOStacks NODiag NOSELfplace NOCONtexts ]	///
		[ nvarlst(integer 1) nc(integer 0) c(integer 0) wtexplst(string) * ] 	
															// now using label lname in lieu of ctxvar
						

								
								
								
								
											// (1) Pre-process gendist-specific options not preprocessed in wrapper
			

	if `limitdiag'==-1  local limitdiag = .					// User wants unlimitd diagnostcs, make that a very big number!	** 

	if ("`missing'"=="") local missing = "all"				// Default if 'missing' option was not used
	if "`missing'"=="mean" local missing = "all"			// Permit legacy keyword "mean" for what is now "all"
	if "`missing'"!="dif2"  local missing = substr("`missing'",1,3)	// Keep 4 chars if those are "dif2", else just 3 chars
	
	local stkd = 0
	capture confirm variable SMstkid
	if _rc == 0  local stkd = 1								// This versn makes no distinctn between stacked and unstkd dta
	if "`nostacks'"!="" local stkd = 0						// Idiucates whether context includes stack #

	
	
	
											// (2) HERE STARTS PROCESSING OF CURRENT CONTEXT (BUT HAVE `c'==1 BELOW)		***
											
	local minN = .											// Make initial minN really big
	local maxN = 0											// Make initial maxN really small
	local nvl = 0											// Count of n of varlists processed
	
	while `nvl'<`nvarlst'  {					 			// Cycle thru set of varlists with same options
	  local nvl = `nvl'+1									// (any prefix is in `selfplace' or `precolon')											
	  gettoken prepipes postpipes : anything, parse("||") 	//`postpipes' then starts with "||" or is empty at end of cmd
	  if "`postpipes'"=="" local prepipes = "`anything'"	// (if empty make like imaginary pipes follow at end of cmd)
		
	  gettoken precolon postcolon : prepipes, parse(":") 	// See if varlist has prefixing indicator 
															// `precolon' gets all of varlist up to ":" or to end of string
	  if "`postcolon'"!=""  {							 	// If `postcolon' is not empty we have a prefix string
		local selfplace = "`precolon'"						// Replace with `precolon' whatever was optioned for selfplace	**
		local isprfx = "isprfx"								// And set `isprfx' flag (not used in gendist), then ...	
		local vars = strtrim(substr("`postcolon'",2,.)) 	// strip off the leading "`prefix:'" and any following blanks
	  } //endif 											// (start with pre-colon prefix)

	  else local vars = "`prepipes'"						// If there was no colon then varlist was in `prepipes'
	   
	  unab varlist : `vars'
	  local nvars : list sizeof varlist
	  tokenize `varlist'
	  local first `1'
	  local last ``nvars''
	  
	  if "`wtexplst'"!=""  {
	    local weight = subinstr(word("`wtexplst'",`nvl'),"$"," ",.) // Replace any "$" by " " (substd to ensure 1 word per wt)
	    if "`weight'" == "null"  local weight = ""			// Duplicate weight expressions were handled in wrapper program	***
	  }

	  
	  
	  

	  
											// (3) Diagnostics are displayed only for 1st context SHOULD BE IN 'gendistO'`***
	  
	  if `c'==1 & `nvl'==1 {								// If this is first call on gendistP (1st context)
 	
	    if ("`pprefix'"!="" & "`missing'"=="") {			// Redundant 'cos already substituted "all" for empty
	      display as error "Option {bf:pprefix} requires option {bf:missing} – exiting gendist"
		  window stopbox note "Option pprefix requires option missing"
		  global exit = 1									// Tells wrapper to exit after restoring origdata
		  continue, break									// Break out of 'nvl' loop
	    }

		if ("`missing'"=="dif2" & "`plugall'"=="")  {
	      display as error "Option {bf:missing(dif2)} requires option {bf:plugall} – exiting gendist"
		  window stopbox note "Option missing(dif2) requires option plughall – exiting gendist"
		  global exit = 1									// Tells wrapper to exit after restoring origdata
		  continue, break									// Break out of 'nvl' loop
		}

		gettoken precolon postcolon : anything, parse(":")	// See if varlist contained prefix var & remove it if so
		if "`postcolon'"!="" local anything = substr("`postcolon'",2,.)
	    if `limitdiag' !=0 & `c'<`limitdiag'  {				// If diagnostics were not silenced, display 1st diagnostic
		  noisily display _newline "{p}Computing distances between R's position ({result:`selfplace'}) " _continue
		  noisily display "and their placement of objects: ({result:`varlist'}) {p_end}{txt}"
		}

		capture drop SMmisCount
		capture drop SMplugMisCount
		
		
	  } //endif`c'==1

	  
	  
	  if `limitdiag'>`c' noisily display "." _continue
	  
	 
	  quietly {
	 
	 
											// (4) Get plugging values separately for different 'missing' options
		
	 	local i = 0											// THIS CODEBLK SHOULD BE CONDUCTED ON WHOLE DATASET			***
		while `i'<`nvars'  {
		   local i = `i' + 1
		   local var = word("`varlist'",`i')

		   qui gen m_`var' = missing(`var')					// Code m_var =0, or =1 if missing
		   scalar skip`i' = 0
		   qui count if ! m_`var'							// Yields r(N)==0 if var does not exist
*noisily display "r(N) = " r(N)
		   if r(N)==0  {									// If there are no observations for this var in this context
			 scalar skip`i' = 1								// Flag used in next codeblock to skip this var
			 continue										// Skip any vars with no obs by continuing w next var
		   }

		   capture {
			 if "`missing'"=="all"  qui mean `var' `weight'	// Use all obs to derive mean only for option missing(all)			
			 if "`missing'"=="sam"  qui mean `var' `weight'  if `selfplace'==`var'
			 if "`missing'"=="dif"  qui mean `var' `weight'  if `selfplace'!=`var'										//	***
			 if "`missing'"=="dif2" qui mean `var' `weight'  if `selfplace'!=`var' // (distinction from dif is made below)
		   }

		   matrix b = e(b)									// Retrieve mean for this context from 'ereturn'
		   scalar mean`i' = b[1,1]
		   gen p_`var' = mean`i'							// Store that mean as plugging value to replace miss val

		} //next var
		
		 




	 
											// (5) Get distances and replace with plugging values as required
	
	    local i = 0
		while `i'<`nvars'  {								// Process each var separately
		  local i = `i' + 1
		  local var = word("`varlist'",`i')
		  if skip`i'  {										// scalar skip`i' was set in previous codeblock
		    qui gen p_`var' = .								// Put relevant mean into p_`var' for all obs on each var
			qui gen d_`var' = .
		  	continue										// If var was skipped above, skip it here as well
		  }													// (continue with next var)

		  if "`plugall'"!="" qui gen d_`var' =abs(`selfplace'-p_`var') // Subtract same mean value for all obs if plugall
		
		  else  {											// Else plug only missing values (more if mis=="dif" optned)
		
		     qui gen d_`var' = abs(`selfplace' - `var')		// Default distance, missng when either component is missng
															// These vars will be renamed before merging in case already
															//  exist, in which case gendist caller will adjudicate
			 if "`missing'"=="all"  qui replace d_`var' = abs(`selfplace' - p_`var') if m_`var'
			 if "`missing'"=="sam"  qui replace d_`var' = abs(`selfplace' - p_`var') if m_`var'
			 if "`missing'"=="dif"  qui replace d_`var' = abs(`selfplace' - p_`var') if m_`var'
			 if "`missing'"=="dif2" qui replace d_`var' = abs(`selfplace' - p_`var') if m_`var' | `selfplace'==`var'
															// dif2 treats `selfplace'==`var' as equivalent to missing
		  } //endelse										// (requires `plugall'!="" 'cos otherwise variance is truncated)
		
	    } //next var


/*	    if `limitdiag'>=`c' /*"`smstkid'"*/ {				// `c' is updated for each different stack
	  	  local lbl : label lname `c'
	  	  noisily display "Vars in context `lbl' have at least `minN' and at most `maxN' valid obs"
	    }
*/		 
				 
				 
				 
	  } //end quietly
	

	


			
											// (6) Break out of `nvl' loop if `postpipes' is empty (common across all `cmd')
											// 	   (or pre-process syntax for next varlist)
											

	  if "`postpipes'"==""  {
	  	local nvl = `nvarlst'+1
*	  	continue, break										// Break out of `nvl' loop if `postpipes' is empty (redndnt?)
	  }
	  else {
	    local anything =strltrim(substr("`postpipes'",3,.)) // Strip leading "||" and any blanks from head of `postpipes'
															// (`anything' now contains next varlist and any later ones)
	    local isprfx = ""									// Switch off the prefix flag if it was on
	  }
*	  if `nvl'>`nvarlst' continue, break
				   
	} //next `nvl' 											// (next varlist having same options)
	
	local temp = ""											// Dummy command needed as target for ,break option

	
	local skipcapture = "skipcapture"						// Local, if set, prevents capture code, below, from executing
	
	
* *************
} //end capture												// Endbrace for code in which errors are captured
* *************												// Any such error would cause execution to skip to here
															// (failing to trigger the 'skipcapture' flag two lines up)

if "`skipcapture'"==""  {									// If not empty we did not get here due to stata error
	
	if _rc  errexit, msg("Stata reports program error in $errloc") displ orig("`origdta'")
	
}
	
end gendistP


*************************************************** END gendistP **********************************************************




**************************************************** SUBPROGRAM **********************************************************

capture program drop createactiveCopy						// APPARENTLY NO LONGER CALLED IN VERSION 2

program define createactiveCopy
	version 9.0
	syntax varlist, type(string) plugPrefx(name)
	capture drop `plugPrefx'`varlist'				       // Presumably `varlist' is actually `varname'
	quietly clonevar `plugPrefx'`varlist' = `varlist' 	   // Plugged copy initially includes valid + missing data
	local varlab : variable label `varlist'	
	local newlab = "`type'-MEAN-PLUGD " + "`varlab'" 	   // `type' is type of missing treatment
	quietly label variable `plugPrefx'`varlist' "`newlab'" // In practice, syntax changes `plugPrefx' to `plugPrefx'

end //createActive copy

************************************************** END SUBPROGRAM **********************************************************
