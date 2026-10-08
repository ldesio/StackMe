*! Oct 07'26

capture program drop gendistP					// Program that does the heavy lifting for gendist, context by context

program define gendistP										// Called by 'stackmeWrapper'; calls subprograms 'errexit'

	version 9.0												// gendist version 2.0, June 2022, updated May'23-Oct'26
	
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



															// SYNTAX COMMAND MOVED FROM HERE TO CODEBLK 2
															// (in stackMe version 10)
								
* *****************											// Open braces enclosing code for which errors will be captured
  capture noisily {								
* *****************								
			
	
											// (2) HERE STARTS PROCESSING OF CURRENT CONTEXT (WITH if `c'==1' REMOVED BELOW)		***
											
	local nvl = 0											// Count of n of varlists processed
	local nvarlsts : char _dta[NVARLISTS]					// Charactrstcs here and below were set in wrapper before codeblk(3)
															// We nee
*	***************************	
	while `nvl' < `nvarlsts'  {					 			// Cycle thru set of varlists with same options (`nvl' was optioned)
*	***************************								// (any prefix is in `selfplace' or `precolon')	

	  local nvl = `nvl' + 1	
	  
	  local varlist : char _dta[VARLISTS`nvl']
	  local options : char _dta[OPTIONS`nvl']
*local show = "`varlist'"
	  
	  local 0 = ", `options'"
															// MOVED HERE IN VERSION 10 FROM TOP OF 'gendistP'
      syntax [varlist] [aw fw pw iw/], [ SELfplace(varname) MISsing(string) PPRefix(string) MPRefix(string) ] 				///
			[ DPRefix(string) MPLuggedcountname(name) LIMitdiag(integer -1) EXTradiag(integer 0) MCOuntname(name) ] 		///
			[ PLUgall ROUnd REPlace NOReplace NOStacks NODiag NOSELfplace NOCONtexts PROximities nvarlst(integer 1) ]		///
			[ nc(integer 0) c(integer 0) wtexplst(str) * ] 	// (xprefix not relevant in gendistP; only in wrapper)
															// now using label lname in lieu of ctxvar
	  global c = `c'										// local c somehow gets lost prior to access, below
															
*
	  local varlist : char _dta[VARLISTS`nvl']				// Getting these from chars permits use of prefixing format
*	  local selfplace : char _dta[PRFXVARS`nvl']			// Ditto (`varlist' is in either source)
	  local minN = .										// Make initial minN really big
	  local maxN = 0										// Make initial maxN really small

	  local nvars : list sizeof varlist
	  tokenize `varlist'									// Puts varnames into `1', `2', ... , ``nvars''
	  local first `1'
	  local last ``nvars''									// Double quotes to get name pointed to last numbered local
	  
	  if "`wtexplst'"!=""  {
	    local weight = subinstr(word("`wtexplst'",`nvl'),"$"," ",.) 
															// Replace any "$" by " " (substituted to ensure 1 word per wt)		 	**
	    if "`weight'" == "null"  local weight = ""			// Duplicate weight expressions were handled in wrapper subprogram		***
	  }

	  if `limitdiag'==-1  local limitdiag = .				// User wants unlimitd diagnostcs, make that a very big number!			** 
	  if "`nodiag'"!=""  local limitdiag = 0

	  if ("`missing'"=="") local missing = "all"			// Default if 'missing' option was not used
	  if "`missing'"=="mean" local missing = "all"			// Permit legacy keyword "mean" for what is now "all"
	  if "`missing'"!="dif2" local missing = substr("`missing'",1,3) // Keep 4 chars if those are "dif2", else just 3 chars
	  if "`missing'"=="di2" local missing = "dif2"			// (in case user thinks there is a 3-char minimum)
	
	  local stkd = 0
	  capture confirm variable SMstkid
	  if _rc == 0  local stkd = 1							// This versn makes no distinctn between stacked and unstkd dta
	  if "`nostacks'"!="" local stkd = 0					// Indicates whether context includes stack #

	  local prx = 0
	  if "`proximities'"!="" local prx = 1					// Switch set true if proximities were optioned
	
	  local mo = ", meanonly"								// Set option for summarize, below
	  if `prx'  local mo = ""
	
	
	  
	  	  
global errloc "gendistP(3)"	  
pause gendistP(3)

	  if $c==1  {											// Only display for first context for each varlist

		if `limitdiag' !=0   {								// If diagnostics were not silenced, display 1st diagnostic
		  noisily display _newline ///
			"{p}{txt}Computing distances between R's position ({result:`selfplace'}) and their placement" _continue
*					 12345678901234567892345678901234567892345678901234567892345678901234567890{result:`'}
			noisily display "of objects: ({result:`varlist'}) {p_end}{txt}"
		}		
		
		
	  } //endif `c'==1


*	  ********	  
	  quietly {												// Don't report dignostics for commands in the following blocks
*	  ********	  	
		
	
	
		
	 
global errloc "gendistP(4)"	 




											// (4) Get plugging values separately for different 'missing' options
		
	 	local i = 0												  // ASSUMING THIS CODEBLK SHOULD ONLY APPLY TO CURRNT CONTXT			***
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
		   
		   if `prx'  {											   // If proximities were optioned..
		   
		   	  if "`missing'"=="all"  qui sum d_`var' `weight' `mo' // Use all obs for `missing'=="all"	
			  
			  if "`missing'"!="all" & "`missing'"!=""  {		   // Else use just obs where `selfplace'!=`var'
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
			
			
			
											// (6) COULD break out of `nvl' loop if `postpipes' is empty (common across all `cmd')
											// 	   (or pre-process syntax for next varlist)
											
	
				   
	} //next `nvl' 											// (next varlist having same options)
	
	local temp = ""											// Dummy command needed as target for ,break option

	
	local skipcapture = "skip"								// Local, if set, prevents capture code, below, from executing
	
*pause on
pause gendistP(6)	
pause off	
	
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






