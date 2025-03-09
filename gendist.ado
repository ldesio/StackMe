
capture program drop gendist

program define gendist

*!  Stata version 9.0; genyhats version 2, updated May'23 from major re-write in June'22

	version 9.0
										// Here set stackMe command-specific options and call the stackMe wrapper program;  
										// lines ending with "**" need to be tailored to specific stackMe commands
									
															// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'
															// Ensure prefixvar (SELfplace) is first and its nevative is last		**
	local optMask = "SELfplace(varname) CONtextvars(varlist) ITEmname(varname) MISsing(string) DPRefix(string) PPRefix(string)" ///	**
				  + " MPRefix(string) APRefix(string) MCOuntname(name) MPLuggedcountname(name) LIMitdiag(integer -1) PROximities" ///
				  + " RESpondent(varname) PLUgall ROUnd REPlace NOSELfplace" // `respondent' not valid in version 2 but permits /// **
															//  helpful error message. REPLACE ANY stackid WITH itemname.			**

															// Ensure prefix option for this stackMe command is placed first
															// and its negative is placed last; ensure options w args preceed 
															// toggle (aka flag) options.	
																				
																
	local prfxtyp = "var"/*"othr" "none"*/					// Nature of varlist prefix – var(list) or other. (`stubname' will		**
															// be referred to as `opt1', the first word of `optMask', in codeblock 
															// (0) of stackmeWrapper called just below). `opt1' is always the name 
															// of an option that holds a varname or varlist (must be referenced
															// using double-quotes). Normally the variable named in `opt1' can be 
															// updated by the prefix to a varlist, as in gendummies.
		
	local multicntxt = "multicntxt"							// Whether `cmd'P takes advantage of multi-context processing			**
	
	local save0 = "`0'"										// Seems necessary, perhaps because called from gendi
	
	
*	**********************
	stackmeWrapper gendist `0' \ prfxtyp(`prfxtyp') `multicntxt' `optMask' // Name of stackme cmd followed by rest of cmd-line				
*	**********************									 // (`0' is what user typed; `prfxtyp' `multicntxt' `optMask' set above)	
															 // (`prfxtyp' placed for convenience; will be moved to follow optns
 															 // – that happens on fifth line of stackmeCaller's codeblock 0) 
															 // (`multicntxt', if not blank, sets stackMeWrapper switch noMultiContxt)
			

*  EXTradiag REPlace NEWoptions MODoptions NODIAg NOCONtexts NOSTAcks  (+ limitdiag) ARE COMMON TO MOST STACKME COMMANDS
*															// All of these except limitdiag are added in stackmeWrapper, codeblock(2)

	if $exit  exit 1										// Exit may have been occasioned by wrapper or by 'cmd'P


	
	
											// On return from stackmeWrapper


	local 0 = "`save0'"										// On return from stackmeWrapper estore what user typed

	
	
											// (7) Post-process active variables (after returning from stackmeWrapper)
											
	syntax anything [if] [in] [aw fw iw pw/], [ CONtextvars MPRefix(string) PPRefix(string) DPRefix(string) APRefix(string) ] 	///
	                                          [ MISsing(string) LIMitdiag(integer -1) ROUnd REPlace NODiag PROximities     ]	///
											  [ XPRefix(string) KEEpmissing * ]
											  
	local contexts = "`_dta[contextvars]'"
	
	if "`nodiag'"!=""  local limitdiag = 0
	
	if `limitdiag'<0  local limitdiag = .					// If =-1 make that a very big number

	local multivarlst = "$multivarlst"						// get multivarlst from global saved in block (6) of stackmeWrapper

	if "`mprefix'"==""  local mprefix = "m_"				// If optioned prefix does not end with "_", insert it
	if "`pprefix'"==""  local pprefix = "p_"
	if "`dprefix'"==""  local dprefix = "d_"
	if "`xprefix'"==""  local xprefix = "x_"
	
	if "`proximities'"!=""  {
		if "`replace'"!=""  {
			noisily display "Calculating proximities as optioned; dropping distances per 'replace' option"
*					 		 12345678901234567890123456789012345678901234567890123456789012345678901234567890
		}
		else noisily display "Calculatng proximities as optd; 'replace' was not optd so distances will be kept"
	}

	
				
	local non2missng = ""									// List of vars present across all varlists
	local skipvars = ""										// List of vars missing for all contexts, cumulates across varlists

	local more = 1											// Flag governs exit from the 'while' loop when =0
	
	while `more'  {											// While any varlists remain in multivarlst
		
	  gettoken vars postpipes : multivarlst, parse("||")	// Extract first varlist if more than one
	  if "`postpipes'"!=""  {								// If there is another varlist
	    local multivarlst = substr("`postpipes'", 3, .)		// Strip leading "||" from postpipes in preparation for next loop
	  }
	  else  {												// Else this is final (or only) varlist
	  	local vars = "`multivarlst'"
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
	  
	  local nonmissng = ""									// Will hold list of vars present for at least 1 contxt
	  
	  
	  if "`proximities'"!=""	 {							// If proximities were optioned
	
	    local maxval = 0									// Find the max value of any var from which to subtract diffs
	    foreach var of local varlist  {
		  quietly summarize `var'
		  local max = r(max)
		  if `max' > `maxval' & `max'<.  {			
		     local maxval = `max'
		  }
		  else  {
		  	if `max'
		  }
	    } //next var

	  } //endif 'proximities'

	  	  
	  foreach var of local varlist  {

	     qui count if !missing(`var')						// These counts are for the entire dataset
		 if r(N)==0  {										// (unlike the counts by context made in gendistP)
			local skipvars = "`skipvars' `var' "
			continue										// Skip to next var if all-missing
		 }
		 else  {
		 	local nonmissng "`nonmissng' `var'"				// Else there are non-missing observations in this varlist
		 }

	  } //next var											// Calculate proximities if optioned
	  

	  local non2missng = "`non2missng' `nonmissng'"			// Append nonmissing list to multivarlst's non2missng list
	 
			
    } //next while more										// Repeat for next varlist, if any

	local non2missing : list uniq non2missng				// Eliminate duplicates

	

	local nvars : list sizeof non2missng					// `non2missing' relates to vars across all varlists
	local first = word("`non2missng'",1)
	local last = word("`non2missng'",`nvars')
	
	
	capture drop SMdmisCount
	quietly egen SMdmisCount = rowmiss(`non2missng')			// Count of vars not all-missing for any varlist

	if "`first'"=="`last'" capture label var SMmisCount "N of missing values for original var (`first')"
	else {
		capture label var SMmisCount "N of missing values for original vars (`first'..`last')"
	}
	
	local newlist = ""
	
	foreach var of local non2missng  {	
		local newlist = "`newlist' d_`var' "				// List of non-missing d_ vars used below
	} //next var

	
	capture drop SMdmisPlugCount
	quietly egen SMdmisPlugCount = rowmiss(`newlist') 		// Count is for same vars as SMmisCount
	
	if "`first'"=="`last'" capture label var SMdmisPlugCount "N of missing values for original var (d_`first')"
	else  {
*					 		             12345678901234567890123456789012345678901234567890123456789012345678901234567890
	  capture label var SMdmisPlugCount "N of missing values in `nvars' mean-plugged vars (d_`first'..d_`last')"
	}
	

	if "`aprefix'"!="" {
	   if `limitdiag'  noisily display "Altering variable prefix strings as optioned"
	}														// Other prefix options will have flagged error in wrapper
 
	
	if "`mprefix'"!="" & substr("`mprefix'",-1,1)!="_" local mprefix = "`mprefix'_"	// setting up for optnd changes
	if "`pprefix'"!="" & substr("`pprefix'",-1,1)!="_" local pprefix = "`pprefix'_" // Insert "_" if user didn't
	if "`dprefix'"!="" & substr("`dprefix'",-1,1)!="_" local dprefix = "`dprefix'_"
	if "`xprefix'"!="" & substr("`xprefix'",-1,1)!="_" local xprefix = "`xprefix'_"

	if "`missing'"=="dif" local missing = "diff"			// Lengthen `missing'=="dif" for display purposes
	if "`missing'"=="sam" local missing = "same"			// Ditto for "sam"	
  
	
	
	foreach var of local non2missng  {						//`non2missing' relates to vars across all varlists

	   local miss = "`missing'-assessed"					// Text string to insert into distance measure's (variable) label
 	   capture local lbl : variable label `var'				// Get existing var label, if any
	   if "`lbl'"!=""  local lbl = ": `lbl'"
	   local lbl1 = "Distance from `selfplace' to `miss' `var'`lbl'"
	   if "`proximities'"!=""  local lbl2 = "Proximity of `selfplace' to `miss' `var'`lbl'"
	   if strlen("`lbl1'")>78  local lbl1 = substr("`lbl1'",1,78) + ".."
	   if "`proximities'"!="" & strlen("`lbl2'")>78  local lbl2 = substr("`lbl2'",1,78) + ".."
	   
	   label var m_`var' "Whether variable `var' was originally missing" // Label default-prefixed versions
	   label var p_`var' "`miss'-plugging values to replace missing values for variable `var'"
	   label var d_`var' "`lbl1'"	
	   if "`proximities'"!=""  label var x_`var' "`lbl2'"
	   
	   if "`proximities'"!=""  { 							// Here we create the proximities measure (if optioned)
	   
*		  **************
	   	  qui gen x_`var' = `maxval' - d_`var'
*		  **************

	   	  label var x_`var' "`lbl2'"						// (and label it)
	   }
	   
	} //next var   	
										
	
	
	
	
	
	if ("`round'"!="")  {									// If `round' was optioned ...
	
	
	     if `limitdiag'  noisily display "Rounding outcome variables as optioned"
	
	     foreach var of local non2missng  {					// non2missing contains vars from all varlists
			
		   if strpos("`skipvars'","`var'")>0  continue		// Skip any that are all missing in all contexts
		   qui sum `var'
		   local max = r(max)
		   qui replace d_`var' = round(d_`var', .1) if `max'<=1
		   qui replace d_`var' = round(d_`var') if `max'>1
		   
		   if "`proximities'"!=""  {
		      qui replace x_`var' = round(x_`var', .1) if `max'<=1
		      qui replace x_`var' = round(x_`var') if `max'>1
		   }
		   
	     } //next `var'										// If max value of var is >1, round to nearest integer

	     capture drop mx*
	   
	} //endif `round'


	
															 // Here we rename vars according to optioned prefixes
															 // (details depend on whether 'replace' was optioned)
															 // (applies to p_ vars and m_vars)
	foreach var of local non2missng  {						 // non2missing contains vars from all varlists
	  
	  if "`replace'"==""  {								 	 // Only need to rename vars not being replaced
	
		if "`aprefix'"!=""  {								 
		  	 rename p_`var' dp`aprefix'`var'				 // Note that 'aprefix' replaces the "_", not the 'd_'
			 rename m_`var' dm`aprefix'`var'
		}
		
		else {											 	 // Else no aprefix so look for pprefix & mprefix if any
	  
			 if "`pprefix'"!=""  ren p_`var' d`pprefix'`var' // Rename according to p-prefix, if optioned
			 if "`mprefix'"!=""  ren m_`var' d`mprefix'`var' // Rename according to m-prefix, if optioned
			 else local mprefix = "m_"						 // So 'mprefix' will refer to the same var either way
		}
		
	  } //endif 'replace'==""								 // Remaining renaming happens whether replacing or not
	  
	  else  {												 // Else we will not be replacing anything
	  
		if "`keepmissing'"!=""  {							 // (except for m_var which is subject to opt 'keepmissing')
		  if "`aprefix'"!="" rename m_`var' dm`aprefix'`var'
		  else  {
		  	if "`mprefix'"!="" ren m_`var' d`mprefix'`var'	// Note that 'aprefix' replaces the "_", not the 'd_'
			else local mprefix = "m_"						// So 'mprifix' will refer to the same var w either naming
		  }													// Note that 'aprefix' overrides 'mprefix', if present
	    }
	   
	   
	    if "`aprefix'"!=""  {								// Applies to d_ & x_ vars whether or not replacing originls
	  
		  rename d_`var' dd`aprefix'`var'					// Note that 'aprefix' replaces the "_", not the 'd_'
		  if "`proximities'"!="" ren x_`var' dx`aprefix'`var'
	    }
	  
	    else {												// Else no aprefix so look for dprefix and xprefix, if any
	  
		  if "`dprefix'"!="" rename d_`var' d`dprefix'`var' // (and rename according to d-prefix, if optioned)
		  else local dprefix = "d_"
		  if "`proximities'"!=""  {
		    if "`xprefix'"!="" rename x_`var' d`xprefix'`var' // Ditto for x-prefix
		  }
		
	    } //endelse
	  
	  
	    if "`replace'"!=""  {								// If optioned, drop droppable vars
		 if "`keepmissing'"==""  drop d`mprefix'`var'		// Drop whichever version of mprefix`var' unless 'keepmissing'
	  	 if "`proximities'"!=""  drop d`dprefix'`var'		// Ditto for originally d-prefixed vars if proximities were optd
	     drop `var'
		 
	    } //endif
		
	  } //endelse
  
	} //next 'var'

											// HERE RENAME VARS THAT WERE TEMPORARILY RENAMED IN origdata, AVOIDING MERGE CONFLCTS
											// (These could not be renamed until after user-optioned name changes, above)

	if "$prefixedvars"!=""  {								// They were placed in this global in wrapper
		
	  foreach var of $prefixedvars  {						// This global was used in wrapper's codeblock (10) 
															// (to disguise prefixed vars in ordata to avoid conflicted merging)
	    local prefix = strupper(substr("`var'",1,2))		// This is what the prefix was changed to before merging
	    local tempvar = "`prefix'" + substr("`var'",3,.)	// (all prefixes are 2 chars long and all were lower case)
	    rename `tempvar' `var'				
	  
	  } //next prefixedvar

	} //endif "$prefixedvars"		
	
	
	capture drop p_* 										// These will be vars with missing obs for all cases
	capture drop m_*
	capture drop d_*

	if "`proximities'"!=""  capture drop x_*
	
    
	if `limitdiag'!=0  noisily display _newline "done." _newline
	
	

	
end gendist





**************************************************** SUBROUTINE gendi **********************************************************



capture program drop gendi

program define gendi

gendist `0'

end gendist



**************************************************** END SUBROUTINES **********************************************************



