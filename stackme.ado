
/*  THIS CODEBLOCK IS COMMENTED OUT BECUSE IT IS NO LONGER PART OF THE stackMe DESIGN; SEE UTILITY PROGRAMS THAT FOLLOW ...
    NOTE THAT THERE IS A stackMe HELP FILE TO ACCOMPANY THOSE UTILITY PROGRAMS, WHICH INTRODUCES THE WHOLE stacmMe PACKAGE

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
*! Written by Mark, Feb 2025, updated May 2025. First SMcontextvars, then SMitemvars ...


*********************************************** UTILITY PROGRAMS *****************************************************


capture program drop SMcontextvars

program define SMcontextvars							// This program should be invoked after 'use'ing the datafile to be processed

version 9.0

*set trace on

	syntax [varlist(default=none)] [, NOCONtexts CLEar DELete DISplay * ]

	global cmd = "SMcontextvars"
		
	quietly display "{smcl}" _continue
	
	if "`delete'"!=""  local clear = "clear"					// 'delete' is undocumented and included for user convenience

	if "`varlist'"=="" & "`nocontexts'"=="" & "`clear'"=="" & "`delete'"=="" & "`display'"==""  {
		display as error "Command SMcontextvars needs varlist or ', display' | ', nocontexts' | ', clear'"
		errexit "Command SMcontextvars needs varlist or ', display' or ', nocontexts' or ', clear'"
											
	}
	
	local vars = ""												// Default needed in case specified varlist is empty
	local contextvars = "`_dta[contextvars]'"					// See if there is an existing non-empty contextvars characteristic
																// If so it will now be in local 'contextvars'
	
	capture confirm variable SMstkid							// If there is an existing SMstkid then data are already stacked
	if _rc  local SMstkid = ""									// If 'confirm' returns a non-zero code then data are not stacked
	else local SMstkid = "SMstkid"								// Else data are stacked
	
	local notdone = 1											// Switch to permit exit from program
	
	while `notdone'  {											// Permits a 'continue, break' exit from program
																// (should not loop back here 'cos loop ends w 'continue, break')
	
	
																// Now go through the possible user requests

	if "`varlist'"!=""  {										// If there is a varlist..
	
	  if "`contextvars'"==""  {									// No contextvars characteristic so should initialize the dataset
																// (unless it is really screwed up, as will now check)
	    if "`SMstkid'"!=""  {
		  display as error "This dataset already has a SMstkid variable; cannot initialize a stacked dataset"
*    					    12345678901234567890123456789012345678901234567890123456789012345678901234567890
		  display as error "Reconfigure this dataset before continuing. See {help stackMe##SMcontextvars:contextvars} help text"
		  errexit "Cannot initialize a stacked dataset; reconfigure before continuing - type 'help SMcontextvars';"

		}														// (genstacks would have checked this so something wierd has happened)  
																
	  } //endif 'contextvar'
	
	} //endif 'varlist'											// Continue with establishing new contextvars
	
	
	if "`contextvars'"=="nocontexts" & "`varlist'"!=""  {  		// 'nocontexts' is a characteristic but varlist was supplied
		
		local nocontexts = "nocontexts"							// Flag that nocontexts was a characteristic
																// (cannot use `contextvars' 'cos will be emptied below)
		noisily display "This dataset's characteristic defines it as having no contexts; change that?"
*    					 12345678901234567890123456789012345678901234567890123456789012345678901234567890
		capture window stopbox rusure "This dataset's characteristic defines it as having no contexts; change that?"
		if _rc  window stopbox stop "You did not ok a change so `cmd' will exit on next 'OK'" // Will exit if change of mind

		else  {													// Else 'ok' was returned
			unab contextvars : `varlist'						// Stata will exit with error if variable(s) dont exist
			char define _dta[contextvars] `contextvars'			// User answered 'ok' so establish the optioned contextvars
			noisily display "Data characteristic now defines this dataset's contextvars as: `contextvars'"
*    					     12345678901234567890123456789012345678901234567890123456789012345678901234567890
*			***************
			continue, break										// Exit this program
*			***************
		}
	} //endif
		
		

	if "`SMstkid'"!="" & "`varlist'"!=""  {						// If there's already a stackid variable AND new contextvars are optnd
	   
	   noisily display "This dataset has established contextvars: `contextvars'"
	   display as error ///										// User needs warning of consequences for discarding the characteristc
			"Established contextvars should not change after stacking; use {help stackme##SMcontextvars:contextvars} option"
*    	     12345678901234567890123456789012345678901234567890123456789012345678901234567890
	   local msg = "Contextvars should not be changed after stacking – use contextvars option on any stackMe command"
	   errexit "`msg' to override established contexts just for that command – else start again with original data"
	   
	} //endif													// Continue if user responded 'OK'"														
			

			
	if "`varlist'"!=""  unab vars : `varlist'					// unab will check for valid varnames

	if "`vars'"!=""  {											// If varlist is not empty (it was set "" at top of program)

		if "`contextvars'"!=""  {								// If contextvars characteristic is not empty there are estblshd contexts

			local same : list contextvars === vars				// returns 1 in 'same' if 'contextvars' & 'vars' have same contents
																// (irrespective of variable ordering)
			if `same'  noisily display "Redundant contextvar names leaves contextvars characteristic unchanged"
	
			else  {												// Else varlist names vars different from established contextvars
				
			  if "`contextvars'"!="nocontexts"{					// If they do not say 'nocontexts'
			  
				noisily display "This dataset has established contextvars: use {help stackme##SMcontextvars:contextvars} option?"
*    						     12345678901234567890123456789012345678901234567890123456789012345678901234567890
				local msg = ///
				"This dataset has established contextvars; you can override these by using the 'contextvars' option on any stackMe "
				capture window stopbox rusure ///
				"`msg'command to override established contexts just for that command – do you insist on establishing new contextvars?"
				if _rc  errexit "You did not insist on a change so "
																// Else do as we were told!
				char define _dta[contextvars] `vars'			// Establish varlist as new contextvars	
				
				noisily display "Re-initialized contextvars characteristic in unstacked data now names: `vars'"
*    						    12345678901234567890123456789012345678901234567890123456789012345678901234567890
				noisily display "NOTE: a stacked dataset would have been tied to contexts establishd when stackng"
*    						 	 12345678901234567890123456789012345678901234567890123456789012345678901234567890
				
*				***************
				continue, break
*				***************

			  } //endif											// Already dealt above with characteristic saying 'nocontexts'
			  	
			} //endelse
			  
		} //endif 'contextvars'!=""
		   	   
		else  {													// Else there is no existing contextvars characteristic
		   
			noisily display "Named contextvar(s) are being established as a characteristic of this dataset"
*    						 12345678901234567890123456789012345678901234567890123456789012345678901234567890
			char define _dta[contextvars] `vars'				// Establish new data characteristic 'contextvars'

		} //endelse												// If program flow reaches this point, define (new) characteristi

		
	} //endif 'vars'
	
	
	else  {														// Else there is no varlist
	
	   if "`nocontexts'"!=""  {									// User wants to define the dataset as having no contexts
		
		  if "`SMstkid'"!=""  {									// But there is a SMstkid variable so dataset was stacked
		  
		    if "`contextvars'"==""								// Something bad happened: no contextvars are named by charactrstc

			  display as error ///
			  "Stacked data needs established contextvars but characteristic does not name any"
*    		   12345678901234567890123456789012345678901234567890123456789012345678901234567890
 			  local msg = ///
			  "A stacked dataset is defined by the contextvars used when stacking – somehow these have become disconnected; "
			  stopbox stop "`msg'start again with unstacked dataset"
		    } //endif
		   
		    else  {												// Else data are not stacked
		   	  
			  if "`clear'"!=""  {
			     char define _dta[contextvars]	/*`empty'*/		// This clears the characteristic; an empty string would not
			     display as error "The stackMe data characteristic 'contextvars has been deleted"
			  }
			  
			  else  {											// 'nocontexts' was optioned
			  	display as error "The stackMe contextvars data characteristic has been established as 'nocontexts'"
*    					          12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  }
			  
		   } //endelse 'SMstkid'
		   
		} //endif 'clear'|'nocontexts'		
		
		
		if "`display'"!=""  {									// If display was optioned
	  
		   if "`contextvars'"=="nocontexts"  { 
		      noisily display "This dataset's data characterstic establishes it as having no contexts"
		   }
		   
		   else {
		   
		      if "`contextvars'"==""  {							// Local 'contextvars' was initialized near top of program
			     local msg = "This dataset has not been initialized for use with {cmd:stackMe} commands; use this "
			     display as error "`msg'"
				 display as error "command to option 'nocontexts' or to name existing contextvars'{txt}
			     errexit "`msg'command to option 'nocontexts' or to name existing contextvars'"
		      }
		
		      else noisily display "This dataset has established contextvars: `contextvars'"
			  
		  } //endelse

	   } //endif

	} //endelse
	
	continue, break
	
	} //end while
	  
	
end SMcontextvars

********************************************************************************************************************************

capture program drop SMcon

program define SMcon

SMcontextvars `0'

end SMcon


********************************************************************************************************************************


capture program drop SMitemname

program define SMitemname

version 9.0

	global cmd = "SMitemname"

	syntax [varlist(default=none)] [, DISplay CLEar DELete ] 	// 'delete' is undocumented but included for user convenience

	if "`varlist'"=="" & "`clear'"=="" & "`display'"=="" & "`delete'"=="" { // See if user optioned something sensible
		display as error "Command SMitemname should supply a new SMitem name or ', display' or ', clear'"
		window stopbox stop "Command SMitemname should supply a new SMitem name or ', display' or ', clear'"
	} //endif

	
	if "`delete'"!=""  local clear = "clear"					// 'delete' is undocumented but included for user convenience


	local SMitem = "`_dta[SMitem]'"								// Get currently stored varname for this characteristic
	
	
	local msg = "You can temporarily override this charactristic by optioning {opt ite:mname} on any stackMe cmd"
																// 'msg', displayed by stopbox, is not limited to 80 char screenwidth
																// (but cannot contain any smcl syntax)
	if "`varlist'"!=""  {										// If varlist is not empty ...
		
		unab vars : `varlist'									// Stata will flag any mistaken variable name in varlist
		
		if wordcount("`vars'")>1  {
			display as error "Only one variable name should be supplied for SMitem"
			window stopbox stop  "Only one variable name should be supplied for SMitem; will exit on 'OK'"
		}

		local S2item = "`_dta[S2item]'"							// Get currently stored varname for the OTHER characteristic

		if "`S2item'"=="`vars'"  {
			display as error "Varname provided will link SMitem to the same var as is already linked to S2item"
*                	                  12345678901234567890123456789012345678901234567890123456789012345678901234567890			
			capture window stopbox rusure ///
						    "Varname provided will link SMitem to the var already linked to S2item; is this what you want?"

			if _rc  window stopbox stop "You did not click 'ok' so will exit on next 'OK'" // Subprogrm errexit (in wrapper ado file) uses window stopbox to exit 

		} //endif
		
				
		if "`SMitem'"!=""  {									// If 'SMitem' characteristic is not empty

			capture confirm variable `SMitem'					// (SMitem was extracted from characteristc before 'if varlist' above)
			if _rc  {
				noisily display "The variable you want linked to SMitem replaces a broken link to `SMitem'"
*                	                         12345678901234567890123456789012345678901234567890123456789012345678901234567890			
			}
			
			else  {												// Else SMitem names existing var
				if "`vars'"=="`SMitem  {									// (in any order; but unnecessary in current implementation)
					noisily display "NOTE: The variable you want linked to SMitem leaves SMitem unchanged"
				}
				
				else  {											// Else change an existing link
				   display as error "`msg'"
*                	          		     12345678901234567890123456789012345678901234567890123456789012345678901234567890
				   capture window stopbox rusure "`msg'; continue anyway?"

				   if _rc  window stopbox stop "You did not click 'ok'; will exit on next 'OK'"
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
				window stopbox stop "There is no SMitem data characteristic (use this utility program to establish one)"
			}
			
		} //endif 'display'
		
		
		
		if "`clear'"!="" {										// Else if 'clear' was optioned
		
			display as error "`msg'"
\			capture window stopbox rusure `msg'; continue anyway?
																// Else did not exit
			display as error "Established SMitem characteristic linked to `SMitem' has been deleted"

 			char define _dta[SMitem]							// This clears the characteristic; an empty string would not

		}
		
	} //endelse 'varlist'
	
		
end SMitemname

********************************************************************************************************************************

capture program drop SMite

program define SMite

SMitemname `0'

end SMite


********************************************************************************************************************************


capture program drop S2itemname

program define S2itemname

varsion 9.0

	global cmd = "S2itemname"

	syntax [varlist(default=none)] [, DISplay CLEar DELete ]	// 'delete' is undocumented and included for user convenience
	
	if "`varlist'"=="" & "`clear'"=="" & "`display'"=="" & "`delete'"==""  { 	// See if user has asked for something sensible

		errexit "Command S2itemname should supply a new S2item name or ', display' or ', clear'"
	
	} //endif
	
	
	if "`delete'"!=""  local clear = "clear"					// 'delete' is undocumented but included for user convenience

	local S2item = "`_dta[S2item]'"								// Get currently stored varname for this characteristic

	local msg = "You can temporarily override this charactristic by optioning {opt ite:mname} on any stackMe cmd"
																// 'msg', displayed by stopbox, is not limited to 80 char screenwidth
																// (but cannot contain any smcl syntax)

	if "`varlist'"!=""  {										// If varlist is not empty ...
		
		unab vars : `varlist'									// Stata will flag any mistaken variable name in varlist
		
		if wordcount("`vars'")>1  {
			display as error "Only one variable name should be supplied for S2item"
			window stopbox stop "Only one variable name should be supplied for S2item; will exit on 'OK'"
		}
		
		local SMitem = "`_dta[SMitem]'"							// Get currently stored varname for the OTHER S?item characteristic

		if "`SMitem'"=="`vars'"  {								// If the OtHER S?item names the same variable ...

			display as error "Varname provided will link S2item to the same var as is already linked to SMitem"
*							  12345678901234567890123456789012345678901234567890123456789012345678901234567890
			capture window stopbox rusure ///
						     "Varname provided would link S2item to same var as is already linked to SMitem; is this what you want?"
			if _rc  window stopbox stop "You did not click 'ok'; will exit on next 'OK'"				
				
		} //endif 'SMitem'										// NOTE this is the OTHER S?item
		
		
		if "`S2item'"!=""  {									// If characteristic S2item is not empty

			capture confirm variable `S2item'					// S2item was retrieved from characteristic befor 'if 'varlist'' above

			if _rc  {
				display as error "The variable you want linked to S2item replaces a broken link to `S2item'"
			}

			else  {												// Else `S2item' exists

				if "`SMitem'"=="`vars'"   {									// (in any order)
				   display as error "NOTE: The variable you want linked to S2item leaves S2item unchanged"
				}

				else  {											// Else change an existing link

				   display as error "`msg'"
				   capture window stopbox rusure `msg'; continue anyway?"
				   
				   if _rc  window stopbox stop "You did not click 'ok'; will exit on next 'OK'"

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
				}									 
				else noisily display "Established characteristic S2item is linked to variable `S2item'"
			}
			
			else  {												// No established link for this characteristic	
				display as error "Found no S2item data characteristic; use this utility program to establish one"
*                	              12345678901234567890123456789012345678901234567890123456789012345678901234567890
				window stopbox stop "There is no S2item data characteristic (use this utility program to establish one)"
			}
			
		} //endif 'display'
		
		else  {													// Else 'clear' must have been optioned
		
			display as error "You can temporarily override this charactristic with option {opt ite:mname}" on any cmd"
*                	          12345678901234567890123456789012345678901234567890123456789012345678901234567890
			capture window stopbox rusure `msg'; continue anyway?

			if _rc  window stopbox stop "You did not click 'ok'; will exit on next 'OK'"
																// Else did not exit
			display as error "Established SMitem characteristic linked to `SMitem' has been deleted"

			char define _dta[S2item]							// This clears the characteristic; an empty string would not

		}

	} //endelse 'varlist'


end S2itemname

********************************************************************************************************************************

capture program drop S2ite

program define S2ite

S2itemname `0'

end S2ite


******************************************************* END OF SUBPROGRAMS *****************************************************




