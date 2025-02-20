
/*  THIS CODEBLOCK IS COMMENTED OUT BECUSE IT IS NO LONGER PART OF THE stackMe DESIGN; SEE UTILITY PROGRAMS THAT FOLLOW ...

capture program drop stackme
program define stackme

	local subcommands gendist gendummies genmeans genplace genstacks genyhats iimpute
	local commandpos : list posof "`1'" in subcommands
	
	if (`commandpos'==0) {
		// not a StackMe sub command
		display as error "'`1'' is not a StackMe subcommand"
		exit 199
	}
	else {
		// runs everything after "stackme"
		`0'
	}
end program

*/



*! This ado file contains the various 'utility programs' needed by users of {cmd:stackMe} commands
*! Written by Mark, Feb 2025.


capture program drop SMcontextvars

program define SMcontextvars

version 9.0

*set trace on

	syntax [varlist(default=none)] [, NOCONtexts CLEar DELete DISplay * ]

	global cmd = "SMcontextvars"

	if "`varlist'"=="" & "`nocontexts'"=="" & "`clear'"=="" & "`delete'"=="" & "`display'"==""  {
		display as error "Command SMcontextvars needs varlist or ', display' | ', nocontexts' | ', clear'"
		errexit "Command SMcontextvars needs varlist or ', display' or ', nocontexts' or ', clear'"
																// 'delete' is undocumented and included for user convenience
	}
	
	
	if "`delete'"!=""  local clear = "clear"
	
	capture confirm variable SMstkid							// If there is an existing SMstkid then data are already stacked
	if _rc  local SMstkid = ""									// If 'confirm' returns a non-zero code then data are not stacked
	

	local contextvars = "`_dta[contextvars]'"					// See if there is an existing non-empty contextvars characteristic
	
	if "`contextvars'"==""  {									// No contextvars characteristic so should initialize the dataset
																// (unless it is really screwed up, as will now check)
	   if "`SMstkid'"!=""  {										
		  display as error "This dataset has SMstkid but no contextvars; should initialize before stacking"
*    					    12345678901234567890123456789012345678901234567890123456789012345678901234567890
		  window stopbox stop ///
		  "This dataset has SMstkid but no contextvar characteristic – it should have been initialized before stacking – will exit on 'OK'"
	   }														// Can go no further  
																// (SMstkid would have checked this so something wierd has happened)
	} //endif 'contextvar'
	
	
	
	if "`contextvars'"=="nocontexts" & "`varlist'"!=""  {  		// 'nocontexts' is a characteristic but varlist was supplied
		
		local nocontexts = "nocontexts"							// Flag that nocontexts were a characteristic
																// (cannot use `contextvars' 'cos will be emptied below)
		noisily display "This dataset's characteristic establishes it as having no contexts; change that?"
*    					  12345678901234567890123456789012345678901234567890123456789012345678901234567890
		capture window stopbox rusure "This dataset's characteristic establishes it as having no contexts; change that?"
		if _rc  window stopbox stop "You did not click 'ok' so `cmd' will exit on next 'OK'"  // Will exit now if user changed their mind

		else  local contextvars = ""							// User answered 'ok' so pretend there are no established contextvars

	} //endif
		

	if "`SMstkid'"!="" & "`contextvars'"!=""  {					// If there's already a stackid variable AND new contextvars are optnd
	   
	   noisily display "This dataset has established contextvars: `contextvars'"
	   display as error ///										// User needs warning of consequences for discarding the characteristc
	   "For stacked dataset {cmd:stackMe} expects unchanged contextvars; use {help stackme##SMcontextvars:contextvars} optn?"
	   local msg = "stackMe expects unchanged contextvars – instead use contextvars option on any stackMe command?"
	   capture window stopbox rusure ///
							  "`msg' to override established contexts just for that command – continue to establish new contextvars?"
	   if _rc  window stopbox stop "You did not click 'ok' so `cmd' will exit on next 'OK'"

	   else  local contextvars = ""								// User answered 'ok' so pretend there are no established contextvars
																// 'msg' will be competed according to nature of risk
	} //endif													// Continue if user responded 'OK'"
	
	

	if "`varlist'"!=""  unab vars : `varlist'					// unab will check for valid varnames

	if "`vars'"!=""  {											// If varlist is not empty

		if "`contextvars'"!=""  {								// If contextvars characteristic is not empty it defines new contexts

		   noisily display "This dataset has established contextvars: `contextvars'"

		   if "`SKstkid'"!=""  {								// If there is a SMstkid variable then data are already stacked
		   
			  display as error ///								// User needs warning of consequences for discarding the characteristc
			  "For stacked data {cmd:stackMe} expects unchanged contextvars; use {help stackme##SMcontextvars:contextvars} optn?"
			  capture window stopbox rusure ///
		      "`msg' to override established contexts just for that command – proceed to establish new contextvars?"
			  if _rc  {
				  window stopbox stop "You did not click 'ok' so `cmd' will exit on next 'OK'"
			  }
																// Otherwise do as we were told!
			  noisily display "Re-initialized contextvars characteristic now names: `vars'"
*    						   12345678901234567890123456789012345678901234567890123456789012345678901234567890
				  
		   } //endif 'SMstkid'
		   
			   
		   else  {												// Else there is no SMstkid so data are not stacked
		   
			  local same : list contextvars === vars			// returns 1 in 'same' if 'contextvars' & 'vars' have same contents
																// (irrespective of variable ordering)
			  if `same'  noisily display "Optioned contextvars leave contextvars characteristic unchanged"
*			   
			  else  {
			  	
			  	noisily display "Established contextvars are being replaced by: `vars'"
				noisily display "NOTE: a stacked dataset would have been tied to contexts establishd when stackng"
*    						     12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  }
			  
		   } //endelse

		} //endif 'contextvars'
		
		else  {													// Contextvars characteristic is empty
			
			noisily display "Optioned contextvar(s) are being established as a characteristic of this dataset"
*    						 12345678901234567890123456789012345678901234567890123456789012345678901234567890
			char define _dta[contextvars] `vars' 				// Establish new data characteristic 'contextvars'


		} //endelse												// If program flow reaches this point, define (new) characteristic
		
		
		char define _dta[contextvars] `vars'					// Establish new data characteristic 'contextvars'

		
		
	} //endif 'varlist'
	
	
	
	else  {														// Else there was no varlist
	
		if "`clear'"!="" | "`nocontexts'"!=""  {				// So see whether 'clear'/'delete' or 'nocontexts' was optioned
		
		   if "`SMstkid'"!=""  {								// If there is a SMstkid variable then dataset was stacked

			  display as error ///
			  "Stacked dataset needs established contextvars; instead use {help stackme##SMcontextvars:contextvars} option?"
 			  local msg = ///
			  "A stacked dataset is defined by the contextvars used when stacking – you could instead use the contextvars option on "

			  window stopbox stop ///
		      "`msg' any stackMe command to override established contexts just for that command – else start again with original data"
			  
		   } //endif
		   
		   else  {
		   	  
			  if "`clear'"!=""  {
			     char define _dta[contextvars]	/*`empty'*/		// This clears the characteristic; an empty string would not
			     display as error "stackMe data characteristic '`contextvars'' has been deleted"
			  }
			  
		   } //endelse 'SMstkid'
		   
		} //endif 'clear'
		
		else  {													// Else 'nocontexts' was optioned
					   
		   char define _dta[contextvars] nocontexts				// Otherwise put "nocontexts" into that characteristic
		   noisily display "This dataset has been re-initializd with the charactristic of having no contexts"
*    					     12345678901234567890123456789012345678901234567890123456789012345678901234567890
		}
		
		
		if "`display'"!=""  {									// If desplay was optioned
	  
		   if "`contextvars'"=="`nocontexts'" | "`nocontexts'"!=""  {
		      noisily display "This dataset's data characterstic establishes it as having no contexts"
		   }
		   
		   else {
		   
		      if "`contextvars'"=="" & "`nocontexts'"==""  {
		   	
			     display as error "This dataset has not been initialized for use with {cmd:stackMe} commands"
			     local msg = "use SMcontextvars to option 'nocontexts' or to name existing contextvars'"
			     display as error "`msg'"
			     stopbox stop "This dataset has not been initialized for use with {cmd:stackMe} commands; `msg'"
			
			  }
		
			  else  {
			     noisily display "This dataset has established contextvars: `contextvars'"
*    					   12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  } //endelse
			  
		   } //endelse

		} //endif

		
	} //endelse
	  
	
end SMcontextvars



capture program drop SMcon

program define SMcon

SMcontextvars `0'

end SMcon



capture program drop SMitemname

program define SMitemname

version 9.0

	global cmd = "SMitemname"

	syntax [varlist(default=none)] [, DISplay CLEar DELete ] 	// 'delete' is undocumented but included for user convenience

	if "`varlist'"=="" & "`clear'"=="" & "`display'"=="" & "`delete'"=="" { // See if user optioned something sensible
	
		errexit "Command SMitemname should supply a new SMitem name or ', display' or ', clear'"

	} //endif

	
	if "`delete'"!=""  local clear = "clear"					// 'delete' is undocumented but included for user convenience


	local SMitem = "`_dta[SMitem]'"								// Get currently stored varname for this characteristic
	
	
	local msg = "You can temporarily override this charactristic by optioning 'itemname' on any stackMe cmd"
																// 'msg', displayed by stopbox, is not limited to 80 char screenwidth
																// (but cannot contain any smcl syntax)
	if "`varlist'"!=""  {										// If varlist is not empty ...
		
		unab vars : `varlist'									// Stata will flag any mistaken variable name in varlist
		
		if wordcount("`vars'")>1  {
			errexit "Only one variable name should be supplied for SMitem"
		}

		local S2item = "`_dta[S2item]'"							// Get currently stored varname for the OTHER characteristic

		if "`S2item'"=="`vars'"  {
			display as error "Varname provided will link SMitem to the same var as is already linked to S2item"
*                	          12345678901234567890123456789012345678901234567890123456789012345678901234567890
			display as error "Is this what you want?"
			
			capture window stopbox rusure ///
						    "Varname provided will link SMitem to the same var as is already linked to S2item; is this what you want?"

			if _rc  errexit "You did not click 'ok'"			// Subprogrm errexit (in wrapper ado file) uses window stopbox to exit 

		} //endif
		
				
		if "`SMitem'"!=""  {									// If 'SMitem' characteristic is not empty

			capture confirm variable `SMitem'					// (SMitem was extracted from characteristc before 'if varlist' above)
			if _rc  {
				noisily display "The variable to be linked to SMitem replaces a broken link to `SMitem'"
			}
			
			else  {												// Else SMitem names existing var
			    local same : list contextvars === vars			// returns 1 in 'same' if 'contextvars' & 'vars' have same contents
				if `same'  {									// (in any order; but unnecessary in current implementation)
					noisily display "NOTE: The variable you want linked to SMitem leaves SMitem unchanged"
				}
				
				else  {											// Else change an existing link
				   display as error "You can temporarily override this charactristic with option {opt ite:mname}" on any cmd"
*                	          		 12345678901234567890123456789012345678901234567890123456789012345678901234567890
				   capture window stopbox rusure "`msg'; continue anyway?"

				   if _rc  window stopbox stop "You did not click 'ok' so will exit `cmd' on next 'OK'"
																// Else did not exit
				   display as error "Established SMitem characteristic linked to `SMitem' is changed to `vars'"
																// Actual change will be made after 'endif SMitem' below
				} //endelse

			} //endelse 'if _rc'
			
		} //endif 'SMitem'										// Else SMitem is empty (no existing link)
		
		else  noisily display "Newly established data characterstc SMitem is linked to var `vars'" 
*                	           12345678901234567890123456789012345678901234567890123456789012345678901234567890

		char define _dta[SMitem] `vars'							// Put that varname into the _dta characteristic named 'SMitem'
		label var SMitem "(linked to `vars')"					// And a copy in the variable's label
																// (presumably won't cause an error if this leaves the link unchanged)
																
	} //endif 'varlist'											// Note that this is not actually a varlist but just one var
																// (original idea was to change both characteristics with one cmd)

	
	else {														// Else no varlist was provided
	
		if "`display'"!=""  {									// If 'display' was optioned
		
			if "`SMitem'" !=""  {								// SMitem was retrieved from characteristic before 'if varlist', above

				capture confirm variable `SMitem'
				if _rc  {
					noisily display "Data characteristic SMitem has no established link to an existing variable"
*									 12345678901234567890123456789012345678901234567890123456789012345678901234567890
				}
				
				else  noisily display "Established data characteristic SMitem is linked to variable `SMitem'"
			}													// 'display' does not change anything
			
			else  {												// No established link for this characteristic
				 		
			    display as error "Found no SMitem data characteristic; use this utility program to establish one"
				errexit "There is no SMitem data characteristic (use this utility program to establish one)"
			}
			
		} //endif 'display'
		
		
		
		if "`clear'"!="" {										// Else if 'clear' was optioned
		
			display as error "You can temporarily override this charactristic with option {opt ite:mname}" on any cmd"
*                	          12345678901234567890123456789012345678901234567890123456789012345678901234567890
			capture window stopbox rusure `msg'; continue anyway?
																// Else did not exit
			display as error "Established SMitem characteristic linked to `SMitem' has been deleted"

 			char define _dta[SMitem]							// This clears the characteristic; an empty string would not

		}
		
	} //endelse 'varlist'
	
		
end SMitemname




capture program drop SMite

program define SMite

SMitemname `0'

end SMite




capture program drop S2itemname

program define S2itemname

varsion 9.0

	global cmd = "S2itemname"

	syntax [varlist(default=none)] [, DISplay CLEar DELete ]	// 'delete' is undocumented and included for user convenience
	
	if "`varlist'"=="" & "`clear'"=="" & "`display'"=="" & "`delete'"==""  { 	// See if user has asked for something sensible

		errexit "Command S2itemname should supply a new S2item name or ', display' or ', clear'"
	
	} //endif
	
	
	if "`delete'"!=""  local clear = "clear"					// 'delete' is undocumented but included for user convenience

	local SMitem = "`_dta[SMitem]'"								// Get currently stored varname for this characteristic

	local msg = "You can temporarily override this charactristic by optioning 'itemname' on any stackMe cmd"
																// 'msg', displayed by stopbox, is not limited to 80 char screenwidth
																// (but cannot contain any smcl syntax)

	if "`varlist'"!=""  {										// If varlist is not empty ...
		
		unab vars : `varlist'									// Stata will flag any mistaken variable name in varlist
		
		if wordcount("`vars'")>1  {
			errexit "Only one variable name should be supplied for S2item"
		}
		
		local SMitem = "`_dta[SMitem]'"							// Get currently stored varname for the OTHER S?item characteristic

		if "`SMitem'"=="`vars'"  {								// If the OtHER S?item names the same variable ...

			display as error "Varname provided will link S2item to the same var as is already linked to SMitem"
*							  12345678901234567890123456789012345678901234567890123456789012345678901234567890
			display as error "Is this what you want?"
			capture window stopbox rusure ///
						     "Varname provided would link S2item to same var as is already linked to SMitem; is this what you want?"
			if _rc  errexit "You did not click 'ok'"				// Subprogram errexit (in wrappr ado file) uses window stopbox to exit
				
		} //endif 'SMitem'										// NOTE this is the OTHER S?item
		
		
		if "`S2item'"!=""  {									// If characteristic S2item is not empty

			capture confirm variable `S2item'					// S2item was retrieved from characteristic befor 'if 'varlist'' above

			if _rc  {
				display as error "The variable to be linked to S2item replaces a broken link to `S2item'"
			}

			else  {												// Else `S2item' exists

				local same : list contextvars === vars			// returns 1 in 'same' if characteristic & 'vars' have same contents
				if `same'   {									// (in any order)
				   display as error "NOTE: The variable you want linked to S2item leaves S2item unchanged"
				}

				else  {											// Else change an existing link

				   display as error "You can temporarily override this charactristic with option {opt ite:mname}" on any cmd"
*                	          		  12345678901234567890123456789012345678901234567890123456789012345678901234567890
				   capture window stopbox rusure `msg'; continue anyway?"
				   
				   if _rc  window stopbox stop "You did not click 'ok' so will exit on next 'OK'"

				  char define _dta[S2item]						// This clears the characteristic; an empty string would not

			      display as error "Established SMitem characteristic linked to `SMitem' has been deleted"

			   } //endelse

			} //endelse
			
		} //endif S2item
																// Else S2item is empty (no existing link)
			
		else  noisily display "Newly established S2item data characteristic is linked to `vars'" 
		
		char define _dta[S2item] `vars'							// Put optioned varname into the _dta characteristic named 'S2Mitem'
		label var S2item "(linked to `vars')"					// And a copy in the variable's label

																// (presumably won't cause an error if this leaves the link unchanged)
	} //endif 'varlist'
	
	
		
	else {														// Else user has provided no varlist
	
		if "`display'"!=""  {									// If 'display' was optioned
		
			if "`S2item'" !=""  {								// S2item was retrieved from characteristic before 'if varlist', above

				capture confirm variable `S2item'
				
				if _rc  {
				   noisily display "S2item has no established link to an existing variable"
				} //endif									 
				
				else noisily display "Established characteristic S2item is linked to variable `S2item'"
			}
			
			else  {												// No established link for this characteristic	
			    display as error "Found no S2item data characteristic; use this utility program to establish one"
*                	              12345678901234567890123456789012345678901234567890123456789012345678901234567890
				errexit "There is no S2item data characteristic (use this utility program to establish one)"
			}
			
		} //endif 'display'
		
		else  {													// Else 'clear' must have been optioned
		
			display as error "You can temporarily override this charactristic with option {opt ite:mname}" on any cmd"
*                	          12345678901234567890123456789012345678901234567890123456789012345678901234567890
			capture window stopbox rusure `msg'; continue anyway?

			if _rc  window stopbox stop "You did not click 'ok' so will exit on next 'OK'"
																// Else did not exit
			display as error "Established SMitem characteristic linked to `SMitem' has been deleted"

			char define _dta[S2item]							// This clears the characteristic; an empty string would not

		}

	} //endelse 'varlist'


end S2itemname



capture program drop S2ite

program define S2ite

S2itemname `0'

end S2ite

