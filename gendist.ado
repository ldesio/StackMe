
capture program drop gendist

program define gendist

*!  Stata version 9.0; genyhats version 2, updated May'23 from major re-write in June'22

	version 9.0
										// Here set stackMe command-specific options and call the stackMe wrapper program;  
										// lines ending with "**" need to be tailored to specific stackMe commands
									
															// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'
															// Ensure prefixvar (SELfplace) is first and its nevative is last		**
	local optMask = "SELfplace(varname) CONtextvars(varlist) ITEmname(varname) MISsing(string) DPRefix(string) PPRefix(string)" ///	**
				  + " MPRefix(string) APRefix(string) MCOuntname(name) MPLuggedcountname(name) LIMitdiag(integer -1)" 			///	**
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
											
	syntax anything [if] [in] [aw fw iw pw/], [ CONtextvars MPRefix(string) PPRefix(string) DPRefix(string) APRefix(string) ] 	   ///
	                                          [ MISsing(string) LIMitdiag(integer -1) ROUnd REPlace NODiag *    ]
	
	if "`nodiag'"!=""  local limitdiag = 0
	
		

	
											// Get varlist from original call (this 20-line codeblock required on return to
											//  each 'cmd' calling program except for genstacks)

	local multivarlst = "$multivarlst"						// get multivarlst from global saved in block (6) of stackmeWrapper

	local var1 = word("`multivarlst'", 1)					// Restore original prefix strings, if present	
	capture confirm variable D_`var1'						// Capitalized in stackmeWrapper to avoid glitch mentioned below

	if _rc==0  {											// If it was capitalized, M_* and P_* will be dealt with later
		capture rename (D_*) (d_*)							// (allows for possibility that option replace will be used,
	}														//  affecting m_* and p_*)

/*															// 3 LINES COMMENTED OUT 'COS SEEMINGLY REDUNDANT
	local frstwrd = word("`multivarlst'",1)					// `multivarlst' was filled with varnames or stubs in block (4)
	local test = real(substr("`frstwrd'",-1,1))				// See if final char of first word is numeric suffix
	local isStub = `test'==.								//`isStub is true if result of conversion is missing
*/		
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

	  foreach var of local varlist  {

	     qui count if !missing(`var')						// These counts are for the entire dataset
		 if r(N)==0  {										// (unlike the counts by context made in gendistP)
			local skipvars = "`skipvars' `var' "
			continue										// Skip to next var if all-missing
		 }
		 else  local nonmissng "`nonmissng' `var'"			// Else there are non-missing observations in this varlist
			
	  } //next var
	  

	  local non2missng = "`non2missng' `nonmissng'"			// Append nonmissing list to multivarlst's non2missng list
	 
			
    } //next while more										// Repeat for next varlist, if any

	

	
										
	
	if ("`round'"!="")  {									  // If `round' was optioned ...
	
	    foreach var of local non2missng  {					  // non2missing contains vars from all varlists
			
		   if strpos("`skipvars'","`var'")>0  continue		  // Skip any that are all missing in all contexts
		   
		   qui egen mx`var' = max(`var'), by("`contextvars'") // If max value of var is <=1, round to nearest 0.1
		   capture confirm variable "`var'"
		   if _rc==0  {										  // If variable does not exist
		      qui replace d_`var' = round(d_`var', .1) if mx`var'<=1
		      qui replace d_`var' = round(d_`var') if mx`var'>1 & `var'<.
		   }
		   
		} //next `var'										  // If max value of var is >1, round to nearest integer

		capture drop mx*
	   
	} //endif `round'


		
	

																
	if "`skipvars'" != "" {
	   if `limitdiag'!=0  {									 // skipvars was cumulated across all varlists
	      noisily display _newline "NOTE: Some vars are all-missing for all contexts and will be dropped: 
		  noisily display "`skipvars'{txt}"
 					              // 12345678901234567890123456789012345678901234567890123456789012345678901234567890
	   }
	   foreach var of local skipvars {
	      local dskip = "`dskip' d_`var'"
		  local pskip = "`pskip' p_`var'"
		  local mskip = "`mskip' m_`var'"
	   }
	   capture drop `dskip' `pskip' `mskip'
	}


	local nvars : list sizeof non2missng					// `non2missing' relates to vars across all varlists
	local first = word("`non2missng'",1)
	local last = word("`non2missng'",`nvars')
	
	
	capture drop SMmisCount
	quietly egen SMmisCount = rowmiss(`non2missng')			// Count of vars not all-missing for any varlist

	if "`first'"=="`last'" capture label var SMmisCount "N of missing values for original var (`first')"
	else {
		capture label var SMmisCount "N of missing values for original vars (`first'...`last')"
	}
	
	local newlist = ""
	
	foreach var of local non2missng  {	
		local newlist = "`newlist' d_`var' "				// List of non-missing d_ vars used below
	} //next var

	
	capture drop SMplugMisCount
	quietly egen SMplugMisCount = rowmiss(`newlist') 		// Count is for same vars as SMmisCount
	
	if "`first'"=="`last'" capture label var SMplugMisCount "N of missing values for original var (d_`first')"
	else  {
		capture label var SMplugMisCount "N of missing values in `nvars' mean-plugged vars (d_`first'...d_`last'"
	}
	

	if "`aprefix'"!="" {
	   if `limitdiag'  noisily display "Altering variable prefix strings as optioned"
	}														// Other prefix options will have flagged error in wrapper
 
	
	if "`mprefix'"!="" & substr("`mprefix'",-1,1)!="_" local mprefix = "`mprefix'_"
	if "`pprefix'"!="" & substr("`pprefix'",-1,1)!="_" local pprefix = "`pprefix'_"
	if "`dprefix'"!="" & substr("`dprefix'",-1,1)!="_" local dprefix = "`dprefix'_"

	if "`missing'"=="dif" local missing = "diff"			// Lengthen `missing'=="dif" for display purposes
	if "`missing'"=="sam" local missing = "same"			// Ditto for "sam"	
  

	foreach var of local non2missng  {						//`non2missing' relates to vars across all varlists

	   local miss = "`missing'-assessed"					// Text string to insert into distance measure's (variable) label
 	   capture local lbl : variable label `var'				// Get existing var label, if any
	   if "`lbl'"!=""  local lbl = ": `lbl'"
	   local lbl = "Distance from `selfplace' to `miss'-assessed `var'`lbl'"
	   if strlen("`lbl'")>78  {
	   	  local lbl = substr("`lbl'",1,78) + ".."
	   }
	   
	   label var m_`var' "Whether variable `var' was originally missing" // Label default-prefixed versions
	   label var p_`var' "`miss' plugging values to replace missing values for variable `var'"
	   label var d_`var' "`lbl'"
 					   // 12345678901234567890123456789012345678901234567890123456789012345678901234567890
					   // Distance from RLRSP to all-judged RLRPP1: Respondent-assessed position of party 1
	   if "`replace'"==""  {								// Only need to rename vars not being replaced
		  if "`aprefix'"!=""  {								// (applies to p_ vars and m_vars)
		  	 rename p_`var' p`aprefix'`var'
			 rename m_`var' m`aprefix'`var'
		  }
		  else {											// Else no aprefix so look for p-prefix & m-prefix if any
			 if "`pprefix'"!=""  ren p_`var' `pprefix'`var' // Rename according to p-prefix, if optioned
			 if "`mprefix'"!=""  ren m_`var' `mprefix'`var' // Rename according to m-prefix, if optioned
		  }
	   } //endif 'replace'==""
	   
	   if "`aprefix'"!=""  {								// Applies to d_ vars whether or not replacing originals
		  rename d_`var' d`aprefix'`var'
	   } 
	   else {												// Else no aprefix so label default-prefixed version
		  if "`dprefix'"!="" rename d_`var' d`dprefix'`var' // (and rename according to d-prefix, if optioned)
	   } //endelse
	   
	   if "`replace'"!=""  {								// If optioned, drop original versions of vars to be dropped
	   	  drop m_`var'										// These prefixed vars were not renamed 
		  drop p_`var'										// ('cos we knew they would be dropped)
	      drop `var'
	   }
  
	} //next var
	

							
															// Delete original, missing and plugging vars if 'replace'
	if ("`replace'" != "") {								//  was optioned
	
	    capture drop `varlist'								// These are just the newly created prefix-vars
		capture drop m_*
		capture drop p_*

		capture rename (M_* P_*) (m_* p_*)					// Maybe rename before merging with origdta in stackmeWrapper? 			***

	}
	
	
	
    
	if `limitdiag'!=0  noisily display _newline "done." _newline
	
	

	
end gendist





**************************************************** SUBROUTINE gendi **********************************************************



capture program drop gendi

program define gendi

gendist `0'

end gendist



**************************************************** END SUBROUTINES **********************************************************



