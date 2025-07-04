
capture program drop gendist				// Calculates distances (now also proximities) between respondent spatial locations and
											// the spatial location of battery items.// Called from program gendi
											
											// SEE PROGRAM stackmeWrapper (CALLED  BELOW) FOR  DETAILS  OF  PACKAGE  STRUCTURE

program define gendist										// Called by 'gendi' a separate program defined after this one
															// Calls subprogram stackmeWrapper and subprogram 'errexit'

*!  program gendist written for Stata version 9.0; gendist version 2, updated by Mark, May'23-May'25 from major re-write in June'22

version 9.0

															

											// (0 Here sets stackMe command-specific options and call the stackMe wrapper program;  
											//    lines ending with "**" need to be tailored to specific stackMe commands

global errloc "gendist(0)"									// $Records which codeblk is now executing, in case of Stata error


															// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'. Ensure
															// prefixvar (here SELfplace) is first option and its negative is last.
															
	local optMask = "SELfplace(varname) ITEmname(varname) MISsing(string) DPRefix(string) PPRefix(string) MPRefix(string) APRefix(string)" ///
				  + " MCOuntname(name) MPLuggedcountname(name) RESpondent(varname) LIMitdiag(integer -1) PROximities PLUgall" 		/// **
				  + " ROUnd NOREPlace NOSelfplace" 			// NOTE that 'noreplace' is not returned in macro 'replace'	**
	
															// First option in optMask has special status, generally naming a var or
															//  varlist	that may be overriden by a prefixing var or varlist (hence	
															//  the name). `prefixvar' is referred to as `opt1' in stackmeWrapper,  
															//  called below, and must be referenced using double-quotes. Its status
															//  in any given 'cmd' is shown by option 'prfxtyp' (next line).
															
	local prfxtyp = "var"/*"othr" "none"*/					// Nature of varlist prefix – var(list) or other. (NOTE that a varlist	**
															// may itself be prefixd by a string, but that leaves prfxtyp unchanged).
															
															// Ensure that options with args preceed toggle (aka flag) options, and	
															//  that the final pre-flag option is 'limitdiag', which served as 
															//  reference point for a previous version of 'staclmeWrapper' (no longer
															//  a feature of stackMe syntax but should be retained in case we should	 	
															//  want to revert to cumulating options at some point; similarly for 
															// 'NEWoptions' and 'MODoptions')						
															
	local multicntxt = "multicntxt"/*""*/					// Whether `cmd'P takes advantage of multi-context processing – saves	**
															//  (e.g.) call(s) on _mkcross if empty.										
															
	local save0 = "`0'"										// Saves what user typed, to be retrieved on return to this caller prog.**
	
	
*	**********************
	stackmeWrapper gendist `0' \prfxtyp(`prfxtyp') `multicntxt' `optMask' 	// Space after "\" must go from all calling programs
*	**********************									// (`0' is what user typed; `prfxtyp' & `optMask' strings were filled	
															//  above; `prfxtyp', placed for convenience, will be moved to follow 
															//  optns – that happens on 4th line of stackmeWrapper's codeblk(0.1))
															// `multicntxt', if empty, sets stackMeWrapper flag 'noMultiContxt'
			
*  CONtextvars NODiag EXTradiag REPlace NEWoptions MODoptions NOCONtexts NOSTAcks  (+ limitdiag) ARE COMMON TO MOST STACKME COMMANDS
*															// All of these except limitdiag are added in stackmeWrapper, codeblock(2)
	
	
								// **************************
								// On return from wrapper ...
								// **************************
								
								
*********************
if "$SMreport"!=""  {										// If this re-entry follows an error report (reported by program errexit)
*********************

	
															// Else continue with body of gendist ...
global errloc "gendi(1)"



**********	
capture  {													// Begin new capture block in case of errors to follow)
**********



	
	local 0 = "`save0'"										// On return from wrapper, re-create local `0', restoring what user typed
															// (so syntax cmd, below, can initialize option contents, not done above)
	

	
											// (1) Post-process active variables (after returning from stackmeWrapper)
											
*	***************	
	syntax anything [if] [in] [aw fw iw pw/], [ CONtextvars(varlist) MPRefix(string) PPRefix(string) DPRefix(string) XPRefix(string) ] /// ***
/*	***************/                          [ LIMitdiag(integer -1) ROUnd REPlace NODiag PROximities KEEpmissing          ] /// ***
											  [ APRefix(string) * ]
											  
															// APRefix(string) is not in `mask', above 'cos added in stackmeWrapper

	local multivarlst = "$multivarlst"						// get multivarlst from global saved in block (6) of stackmeWrapper
															// (not used in practice)
											  
	local contexts = "`_dta[contextvars]'"					// ONLY NEEDED IF WE MAKE USE OF CONTEXTS (PROBABLY NOT)
	if "`contextvars'"!="" local contexts = "`contextvars'" // Override 'contextvars' characteristic if there was a contextvars option
	local contextvars = "`contexts'"						// In this caller we don't actually make use of contextvars
	capture confirm variable SMstkid						// If data are stacked then SMstkid is context or extends contxt
	if _rc==0 local contextvars = "`contextvars' SMstkid"

	if "`nodiag'"!="" local limitdiag = 0
	if `limitdiag'<0  local limitdiag = .					// If =-1 make that a very big number
	if "`noreplace'"!=""  local replace = "replace"			// Actual option seen by user is 'noreplace'
				
	local non2missing = ""									// List of vars present across all varlists
	local skipvars = ""										// List of vars missing for all contexts, cumulates across varlists

	local more = 1											// Flag governs exit from the 'while' loop when =0
	
	local nvl = 0											// Count of # of pipe-separated varlists
	
	
global errloc "gendi(2)"	
	
											// (2) Extract the distance/proximity components from each varlist

	
	while `more'  {											// Parse each varlist in 'multivarlst'
	
	  local nvl = `nvl' + 1									// Increment number of varlists
		
	  gettoken vars postpipes : multivarlst, parse("||")	// Extract first varlist if more than one
	  if "`postpipes'"!=""  {								// If there is another varlist
	    local multivarlst = substr("`postpipes'", 3, .)+" " // Strip leading "||" from postpipes in preparation for next loop
	  }														// (and add a space, in case there was none before or after "||")
	  else  {												// Else this is final (or only) varlist
	  	local vars = "`multivarlst'"						// (redundant 'cos already got multivarlst from global on entry)
		local more = 0										// (and last time through the while loop)
	  }
	   														// Proceed with post-proccessing this varlist
									
	  gettoken temp rest : vars, parse(":")					// Any prefix is now in `temp' if `rest' starts with ":"
	  if "`rest'"!=""  {									// If there was a prefix ...
		local selfplace = "`temp'"							// Otherwise leave 'selfplace' unchanged
	  	local rest = substr("`rest'", 2, .) 				// Strip ":" from front of varlist
	  }	
	  else local rest = "`vars'"							// Otherwise varlist was not prefixed and rest gets `vars'
	  
	  unab varlist : `rest'									// The varlist that was processed in gendistP
	  	  
	  local nonmissing = ""									// Will hold list of vars present for at least 1 contxt
	  
	  foreach var of local varlist  {						// This varlist is still the original user-typed varlist

		qui count if !missing(`var')						// These counts are for the entire dataset
		if r(N)==0  {										// (unlike the counts by context made in 'stackmeWrapper')
			local skipvars = "`skipvars' `var' "
			continue										// Continue to next var if all-missing
		}
		else  {
		 	local nonmissing "`nonmissing' `var'"			// Else there are non-missing observations in this varlist
		}

	  } //next var											// Calculate proximities if optioned
	  
	  local non2missing = "`non2missing' `nonmissing'"		// Append vars from each 'nvl' varlist to 'non2missing'

    } //next while more										// Repeat for next varlist, if any
	
	
	
global errloc "gendi(3)"	
											// (3) Here create count measures
	
															
	local nvars : list sizeof non2missing					// `non2missing' relates to vars across all varlists
	local first = word("`non2missing'",1)
	local last = word("`non2missing'",`nvars')
	
	foreach SMvar in SMdmisCount SMdmisPlugCount {			// Cycle thru the two summary measures
	
		if "`SMvar'"=="SMdmisCount" local txt = "original " // Set text to be included in var label
		else local txt = "mean-plugged "

		local name = ""										// Name to be used in code that follows coming loop

		capture confirm variable `SMvar'					// See if variable exists from previous run
		if _rc==0  {										// If that var already exists

			  local msg = "Var `SMvar' already exists (left by some earlier stackMe command); replace?"
*					       12345678901234567890123456789012345678901234567890123456789012345678901234567890
		      if strlen("`msg'")>80 local msg = "Var `SMvar' exists (left by earlier stackMe command); replace?"
			  display as error "`msg'{txt}"					// If needed, shorten 'msg' to fit in 80 columns
			  capture window stopbox rusure ///
			  "Var `SMvar' already exists (left by some earlier stackMe command); provide new name?"
			  if _rc  errexit, msg("Exiting $cmd")			// _rc was non-zero so user is not 'OK'
			  else  {										// Else user clicked 'OK'
			    local txt = ""
			    while "`name'"==""  {
			  	  noisily display "`txt'Copy-paste '`SMvar'' into Command window and edit before returning" _newline _request(newname)
				  if "$newname"!=""`SMvar'  {				// If new name is not same as 'SMvar'
				    if "$newname'"=="BREAK"  exit 1			// User can type "BREAK" to exit 
				    local name = "$newname"					// Move new name into relevant local
				    global newname = ""						// And empty that global
				  }				  	
				  else local txt = "UNCHANGED! "			// Else name is unchanged so repeat loop whith that word heading display
				} //next while
				
				noisily display "With variable `SMvar' renamed to $newname execution continues..."
			  }

		} //endif _rc										// Either way 'egen' the var now named by local SMvar
		
		if "`name'"==""  {
			local name = "`SMvar'"							// If there was no newname, use 'SMvar' for egen
		}
		
		quietly egen `name' = rowmiss(`non2missing')		// Count of vars not all-missing for any varlist

		if "`first'"=="`last'" capture label var `name' "N of missing values for `txt'var (`first')"
		else {
			capture label var `name' "N of missing values for `txt'vars (`first'..`last')"
		}													// Contents of `txt' local was set above
	
	} //next SMvar
	
	if `limitdiag' noisily display " "						// Display a blank line to terminate per context diagnostics

	
	
global errloc "gendi(4)"	

											// (4) Here generate proximity measures if optioned
	
	local prx = 0
	
	if "`proximities'"!=""  {								// If proximities were optioned
	    local prx = 1

		foreach var of local non2missing  {					// Cycle thru all d_vars
			tempvar max				
			egen `max' = max(`var')							// Get max value of `var' over whole dataset
			gen x_`var' = `max' - d_`var'					// Invert the distance measures
		} //next var

		if "`replace'"!=""  {
			noisily display "Calculating proximities as optioned; dropping distances per 'replace' option"
*					 		  12345678901234567890123456789012345678901234567890123456789012345678901234567890
		}
		else noisily display "Calculatng proximities as optd; 'replace' was not optd so distances will be kept"
	} //endif 'proximities'

	else  {													// Else proximities are not being calculated
		if "`replace'"!=""  noisily display "Calculating proximities as optioned"
	}
	

	
global errloc "gendi(5)"
											// (5) Here label the outcome variables

															 
	if "`missing'"=="dif" local missing = "diff"			// Lengthen `missing'=="dif" for display purposes
	if "`missing'"=="di2" local missing = "dif2"			// Ditto for 'di2'
	if "`missing'"=="sam" local missing = "same"			// Ditto for "sam"	

	foreach var of local non2missing  {						//`non2missing' relates to vars across all varlists

	   local miss = "`missing'-assessed"					// Text string to insert into distance measure's (variable) label
 	   capture local lbl : variable label `var'				// Get existing var label, if any
	   if "`lbl'"!=""  local lbl = ": `lbl'"
	   local lbl1 = "Distance from `selfplace' to `miss' `var':`lbl'"
	   if `prx'  local lbl2 = "Proximity of `selfplace' to `miss' `var':`lbl'"
	   if strlen("`lbl1'")>78  local lbl1 = substr("`lbl1'",1,78) + ".."
	   if `prx' & strlen("`lbl2'")>78  local lbl2 = substr("`lbl2'",1,78) + ".."
	   
	   label var m_`var' "Whether variable `var' was originally missing" // NOTE that m_`var' was remamed but not labeled in wrapper
	   label var p_`var' "`miss' plugging values to replace missing values for variable `var'"
	   label var d_`var' "`lbl1'"	
	   if `prx'  label var x_`var' "`lbl2'"
	   	   
	} //next var   	
						


global errloc "gendi(6)"

											// (6) Here round the outcome variables

	if ("`round'"!="")  {									
	
	     if `limitdiag'  noisily display "Rounding outcome variables as optioned"
	
	     foreach var of local non2missing  {					// non2missing contains vars from all varlists
			
		   if strpos("`skipvars'","`var'")>0  continue		// Skip any that are all missing in all contexts
		   qui sum `var'
		   local max = r(max)
		   qui replace d_`var' = round(d_`var', .1) if `max'<=1
		   qui replace d_`var' = round(d_`var') if `max'>1
		   
		   if `prx'  {
		      qui replace x_`var' = round(x_`var', .1) if `max'<=1
		      qui replace x_`var' = round(x_`var') if `max'>1
		   }
		   
	     } //next `var'										// If max value of var is >1, round to nearest integer

	     capture drop mx*
	   
	} //endif `round'
	
	
	
	

global errloc "gendi(7)"
											// (7) Here alter variable prefix strings, renaming vars as optioned
											
																	
	if "`pprefix'`dprefix'`xprefix'"!="" {					 // 'aprefix' and 'mprefix' are handled in wrapper
	   if `limitdiag'  noisily display "Altering variable prefix strings as optioned"
	}
 	
	if "`mprefix'"!="" & substr("`mprefix'",-1,1)!="_" local mprefix = "`mprefix'_"	// setting up for optnd changes
	if "`pprefix'"!="" & substr("`pprefix'",-1,1)!="_" local pprefix = "`pprefix'_" // Insert "_" if user didn't
	if "`dprefix'"!="" & substr("`dprefix'",-1,1)!="_" local dprefix = "`dprefix'_"
	if "`xprefix'"!="" & substr("`xprefix'",-1,1)!="_" local xprefix = "`xprefix'_"
  
															 // Here we rename vars according to optioned prefixes
															 // (details depend on whether 'replace' was optioned)
															 // (applies to p_ vars and m_vars)
	foreach var of local non2missing  {						 // non2missing contains vars from all varlists
	  
	   if "`replace'"==""  {								 // Only need to rename vars not being replaced
	
		 if "`aprefix'"!=""  {									
			rename p_`var' dp`aprefix'`var'				 	 // Note that 'all-prefix' replaces the "_", not the 'd_'
			rename m_`var' dm`aprefix'`var'
		 }
		 else {											 	 // Else no all-prefix so look for pprefix & mprefix if any
			rename p_`var' dp_`var'							 // Else just prepend the 'd' to the default-prefixed name
			rename m_`var' dm_`var'							 // Else ditto for 'm'-prefix
		 } //endelse
		
	   } //endif 'replace'==""								 // Remaining renaming happens whether replacing or not
	  
	   else {												 // Else 'replace' was optioned, so no p_ or m_ prefixes
	  
		 if "`keepmissing'"!=""  {							 // (except for m_var which is subject to opt 'keepmissing')
			if "`aprefix'"!="" ren m_`var' dm`aprefix'`var'  // Note that 'aprefix' replaces the "_", not the 'd_'
			else  rename m_`var' dm_`var'					 // Else not an 'all-prefix'
		 } //endif 'keepmissing'
	   } //endelse
	  
	   if "`dprefix'"!=""  ren d_`var' `dprefix'`var' 	 	 // Finally we get to d_ and x_, which always get renamed
	   else rename d_`var' dd_`var'							 // (if optioned)
	   if "`xprefix'"!=""  ren x_`var' `xprefix'`var' 	 	 // 'x_prefix' can only be non-empty if 'proximities'!=""
	   if `prx' & "`xprefix'"=="" ren x_`var' dx_`var'  	 // (but if 'xprefix' must be empty then we check both)
	   
	  
	} //next var	
	
	  
	  
	  
global errloc "gendi(8)"
											// (8) HERE RENAME VARS THAT WERE TEMPORARILY RENAMED IN origdata, AVOIDING MERGE
											// 	   CONFLCTS (these could not be renamed until after user-optioned name changes)

	
	
	if "$namechange"!=""  {									// Placed in this global by getprfxdvars <-- isnewvar <-- wrapper(5)
	
		foreach var in $namechange  {						// These vars had first char of (generally stringprefix) name made
															//   upper case
			local origname = strlower(substr("`var'",1,1)) + substr("`var'",2,.) // Otherwise all prefixes start w lower case char
															// Append rest of `var' to lower-case version of its first char
			rename `var' `origname'							// Rename `var' to its original name 
	    }													// (changed in getprfxdvars <-- isnewvar <-- wrapper(5))
	
	} //endif

	capture drop p_* 										// These will be vars with missing obs for all cases
	capture drop m_*
	capture drop d_*
	capture drop x_*
	
    
	if `limitdiag'!=0  noisily display _newline "done." _newline
	
	
	scalar filename = "$filename'"							// Save, in a scalar, global filename – relevant for later stackMe cmds
    macro drop _all											// Drop all globals used to process this stackMe command (also locals,
	global filename = filename								//   but they are dropped anyway at end of program)
	scalar drop _all

	
	
	
	local skipcapture = "skip"								// Deal with possibility that there's a trailing non-zero return code
	

*  ************
} //end capture												// End capture brackets that enclosed all codeblocks since call on wrapper
*  ************

*  ****************
} //endif $SMreport
*. ****************

if _rc  & "`skipcapture'"=="" & "$SMreport"=="" {			// If there is a non-zero return code not already reported by errexit
															//   & if execution did not pass thru line before '} //end capture'
															// (which is to say that execution arrived here by way of error capture)
		

		
		
											// (9) Deal with any Stata-diagnosed errors in above codeblks unanticipated by stackMe code
														
	local rc = _rc
	local err = "Stata reports likely program error `rc' in $errloc during post-processing"
	dispLine "`err'; retain (partially) post-processed dta and clean it up yourself – ok?{txt}" "aserr"
*              	 12345678901234567890123456789012345678901234567890123456789012345678901234567890
	capture window stopbox rusure ///
			  "`err'; retain (partially) post-processed data and clean it up yourself – ok?"
	if _rc  {
		window stopbox note "Absent permission to retain partially-processed data, on 'OK' original data will be restored before exit"
		capture use $origdta, clear
		noisily display "{bf:NOTE: original dataset has been restored}"
	}
	else {													// Else 'ok' was clicked
		noisily display "{bf:NOTE: Partially post-processed data is retained in memory}"
	}
	
	

  *********************************
} //endif _rc & 'skip..' & 'report'							// End brace-delimited error-capture handling
  *********************************

 
  
global multivarlst											// Clear this global, retained only for benefit of caller programs
capture erase $origdta 										// Erase the 'origdta' tempfile whose name is held in $origdta
global origdta												// Clear that global
global SMreport												// And this one
															// (but if 'abbrevcmd' was empty we execute a normal end-of-program)

end gendist



****************************************************** PROGRAM gendi **********************************************************


capture program drop gendi									// Abbreviated command name for 'gendist'

program define gendi

gendist `0'													// Invoke the command using its full name and append what user typed

end gendi


******************************************************* END PROGRMES **********************************************************


