*! Mar 22'26

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
	
	
global errloc "gendistP(1)"						// Global that keeps track of execution location for benefit of 'errexit'





    syntax anything [aw fw pw iw/], [ SELfplace(varname) MISsing(string) PPRefix(string) MPRefix(string) DPRefix(string) ] 	///
			[ APRefix(string) MPLuggedcountname(name) LIMitdiag(integer -1) EXTradiag(integer 0) MCOuntname(name) ] 		///
			[ PLUgall ROUnd REPlace NOReplace NOStacks NODiag NOSELfplace NOCONtexts PROximities nvarlst(integer 1) ]		///
			[ nc(integer 0) c(integer 0) wtexplst(str) * ] 	// (xprefix not relevant in gendistP; only in wrapper)
															// now using label lname in lieu of ctxvar
						

								
* *****************											// Open braces enclosing code for which errors will be captured
  capture noisily {								
* *****************								


											// (1) Pre-process gendist-specific options not preprocessed in wrapper
			

	if `limitdiag'==-1  local limitdiag = .					// User wants unlimitd diagnostcs, make that a very big number!			** 
	if "`nodiag'"!=""  local limitdiag = 0

	if ("`missing'"=="") local missing = "all"				// Default if 'missing' option was not used
	if "`missing'"=="mean" local missing = "all"			// Permit legacy keyword "mean" for what is now "all"
	if "`missing'"!="dif2" local missing = substr("`missing'",1,3)	// Keep 4 chars if those are "dif2", else just 3 chars
	if "`missing'"=="di2" local missing = "dif2"			// (in case user thinks there is a 3-char minimum)
	
	local stkd = 0
	capture confirm variable SMstkid
	if _rc == 0  local stkd = 1								// This versn makes no distinctn between stacked and unstkd dta
	if "`nostacks'"!="" local stkd = 0						// Indicates whether context includes stack #

	local prx = 0
	if "`proximities'"!="" local prx = 1					// Switch set true if proximities were optioned
	
	local mo = ", meanonly"									// Set option for summarize, below
	if `prx'  local mo = ""
	
	
	
											// (2) HERE STARTS PROCESSING OF CURRENT CONTEXT (BUT HAVE if `c'==1 BELOW)				***
											
	local minN = .											// Make initial minN really big
	local maxN = 0											// Make initial maxN really small
	local nvl = 0											// Count of n of varlists processed
	
	while `nvl'<`nvarlst'  {					 			// Cycle thru set of varlists with same options (`nvl' was optioned)
	
	  local nvl = `nvl'+1									// (any prefix is in `selfplace' or `precolon')	
	  local varlist = VARLISTS`nvl'							// Retrieve varlist from scalar where it was stashed before wrapper(3)
	  if (PRFXVARS`nvl'!="") & !missing(PRFXVARS`nvl')  local selfplace = PRFXVARS`nvl' // Ditto
	  local nvars : list sizeof varlist
	  tokenize `varlist'
	  local first `1'
	  local last ``nvars''
	  
	  if "`wtexplst'"!=""  {
	    local weight = subinstr(word("`wtexplst'",`nvl'),"$"," ",.) 
															// Replace any "$" by " " (substituted to ensure 1 word per wt)		 	**
	    if "`weight'" == "null"  local weight = ""			// Duplicate weight expressions were handled in wrapper subprogram		***
	  }

	  
	  
	  

	  
global errloc "gendistP(3)"	  
pause gendistP(3)


											// (3) Diagnostics are displayed only for 1st context SHLD EVENTUALLY BE IN 'gendistO'	***
	  
	  if `c'==1 & `nvl'==1 {								// If this is first call on gendistP (1st varlist for 1st context)
 	
		if ("`missing'"=="dif2" & "`plugall'"=="")  {		// If "dif2" is optioned we also need "plugall"
	      display as error "Option {bf:missing(dif2)} requires option {bf:plugall} – assumed if ok{txt}"
		  capture stopbox rusure "Option {bf:missing(dif2)} requires option {bf:plugall} – assumed if ok"
		  if _rc  {
		  	errexit, msg("Absent permission to assume option plugall{txt}")
			exit 1
		  }
		}

	    if `limitdiag' !=0   {								// If diagnostics were not silenced, display 1st diagnostic
		  noisily display _newline "{p}{txt}Computing distances between R's position ({result:`selfplace'}) and their placement" _continue
*											12345678901234567892345678901234567892345678901234567892345678901234567890{result:`'}
		  noisily display "of objects: ({result:`varlist'}) {p_end}{txt}"
		}		
		
	  } //endif`c'==1


*	  ********	  
	  quietly {												// Don't report findings for commands in the following blocks
*	  ********	  	
		
	
	
		
	 
global errloc "gendistP(4)"	 




											// (4) Get plugging values separately for different 'missing' options
		
	 	local i = 0											// ASSUMING THIS CODEBLK SHOULD ONLY BE CONDUCTED ON CURRNT CONTXT ??		***
		while `i'<`nvars'  {
			
		   local i = `i' + 1
		   
		   local var = word("`varlist'",`i')					  // Put this varname into `var'
		   
*		   scalar SKIP`i' = 0							

		   if "`missing'"=="all"  qui sum `var' `weight' `mo'	  // If using all obs for `missing'=="all"			
		   if "`missing'"!="all" & "`missing'"!=""  {			  // If using only obs where R places `var' other than `selfplace'
		   	  qui sum `var' `weight'  if `selfplace'!=`var' `mo'  // (resulting mean works for "dif" & "dif2")							***
		   }													  // Only one call on 'summarize' leaves return code accessd below
   
		   if r(N)==0  {										  // If there are no relevant observations for this var in this context
*			 scalar SKIP = 1									  // Flag used in next codeblock to skip this var (NO MORE)
			 if "`missing'"!="all" & "`missing'"!=""  {
			 	local lbl = LBL
*		 		noisily display _newline "WARNING: No observations where `selfplace'!=`var' in context `lbl'" _newline
			 }													  // COMMENTED OUT BECAUSE TOO OBTRUSIVE; SAME INFO AVAILALE W EXTRADIAG
		     continue											  // Continue with next var
		   
		   } //endif r(N)==0

		   else  {											  	  // Else there are non-missing observations
			  scalar MEAN = r(mean)							  	  // This shld be the corrct mean for whichevr plugging var was optioned
		   }
		   
		   gen m_`var' = missing(`var')							  // Code m_var =0, or =1 if missing
		   gen p_`var' = abs(`selfplace' - MEAN)				  // Use apprriate mean to get pluggng value, missng if misng `selfplace'
		   gen d_`var' = abs(`selfplace' - `var')				  // Default distance, missing when either component is missing
		   
		   if "`missing'"=="all"  replace d_`var' = p_`var' if m_`var'					   // Plug if `var' is missing
		   if "`missing'"=="dif"  replace d_`var' = p_`var' if `selfplace'!=`var'& m_`var' // Only replace missing values w appropriate
		   if "`missing'"=="dif2" | "`plugall'"!=""  replace d_`var' =  p_`var' 		   // Same as p_var 'cos 'plugall' is implied
		   
		   if `prx'  {											  // If proximities were optioned..
		   	 if "`missing'"=="all"  qui sum d_`var' `weight' `mo' // Use all obs for `missing'=="all"			
			 if "`missing'"!="all" & "`missing'"!=""  {			  // Else use just obs where `selfplace'!=`var'
			   qui sum d_`var' `weight' if `selfplace'!=`var'`mo' // (resulting mean works for "dif" & "dif2")							***
			   scalar MAX  = r(max)								  // The right MAX for appropriate summarize
			   gen x_`var' = MAX - d_`var'
		  }
		}
			 
		} //next var
		
		 
		 
		 


global errloc "gendistP(5)"
				 
				 
				 
*	  **************				 
	  }  //end quietly
*	  **************

	
	
	
	

global errloc "gendistP(6)"
			
			
			
											// (6) Break out of `nvl' loop if `postpipes' is empty (common across all `cmd')
											// 	   (or pre-process syntax for next varlist)
											

	  	local nvl = `nvarlst'+1

	
				   
	} //next `nvl' 											// (next varlist having same options)
	
	local temp = ""											// Dummy command needed as target for ,break option

	
	local skipcapture = "skip"								// Local, if set, prevents capture code, below, from executing
	
	
	
	
*  **************
  } //end capture											// End-brace for code in which errors are captured
*  **************											// Any such error would cause execution to skip to here
															// (failing to trigger the 'skipcapture' flag two lines up)

															
if "`skipcapture'"==""  {									// If empty we got here due to stata error earlier in program
	
	if _rc  {
		local rc = _rc
		errexit, msg("Stata reports program error in $errloc") displ rc(`rc')
		exit `rc'											// Display in results window and process non-zero return code
	}
	
} //endif 'skipcapture'
	
	
	
	
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




