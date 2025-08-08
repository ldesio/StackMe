
*! 														stackMe.ado

*! THIS ado file CONTAINS THE VARIOUS 'utility programs' NEEDED BY USERS OF stackMe COMMANDS. See first paragraph of 'help stackMe'

*! Written by Mark, Feb 2025.

									// stackMe.ado contains stackMe utility programs (programs with names starting with 'SM) as follows:
									//
									// SMsetcontexts: invoked, after opening a file, to establish or update context-defining vars as 
									//  characteristics of that dataset. It also establishes the filename and filepath for the file 
									//  being initialized. File characteristics can be updated by using SMsavefile to save the (possibly 
									//  renamed) file in a new location (see below)
									//  
									// SMsavefile: invoked to save the active file under a new name and/or directory location
									//
									// SMitemname: invoked to supply the name of a linkage variable, to be linked to varname SMitem
									

									
capture program drop SMsetcontexts


program define SMsetcontexts					// This program should be invoked after first 'use' of the datafile to be processed
												// SEE PROGRAM stackmeWrapper (CALLED  BELOW) FOR  DETAILS  OF  PACKAGE  STRUCTURE
version 9.0

global cmd = "SMsetcontexts"

												// SEE IF THIS IS INITIAL CALL on stackMe utility for a new dataset
															
	local filename : char _dta[filename]					// Get established filename if already set as dta characteristic
	local dirpath  : char _dta[dirpath]						// Ditto for dirpath; if empty then datafile was not initialized

															// Either way, get name and dirpath for currently used file
	local fullname = c(filename)							// Path+name of datafile most recently used or saved
	if strpos("`fullname'", c(tmpdir))>0  {					// If c(tmpdir) is contained in dirpath then this is a tempfile...
		if "`filename'" = ""								// And we don't have an existing filename in filename characteristic
		display as error "{bf:SMsetcontexts} can't get name of datafile; invoke this cmd closer to relevant {bf:{help use}}"
*						  12345678901234567890123456789012345678901234567890123456789012345678901234567890
		window stopbox stop "'SMsetcontexts' cannot access name of datafile; invoke this command closer to relevant 'use' command"
	}														// (should not happen)
	
															// Otherwise we have a useable supposed (new) filename
	
	local nameloc = strrpos("`fullname'","`c(dirsep)'") + 1	// Loc of first char after FINAL dirsep ("/" or "\") of dirpath
	local newpath = substr("`fullname'",1,`nameloc'-1) 		// `newpath' ends w last `c(dirsep)' (i.e. 1 char before name)
	local newname = substr("`fullname'",`nameloc',.)		// Update filename with latest filename saved or used by Stata
  
	if "`filename'"=="" {									// If filename characteristic is empty
		char define _dta[filename] `newname' 				// Establish most recent filename as characteristic of dataset
		char define _dta[dirpath]  `newpath' 				// Initialization still needs contextvars, added far below
		noisily display "NOTE: File named `newname' initialized as new stackMe datafile"
	} //endif 'newname'
	
	else  {													// Else file has already been initialized with existing filename
	
	  if "`newname'"!="`filename'"  {						// If existing char differnt from new name we have potential conflict...
		 local msg = "Name of open file doesn't match its filename characterstic"
		 display as err "`msg'; replace charctrstic?"
*					     12345678901234567890123456789012345678901234567890123456789012345678901234567890
		 capture window stopbox rusure "`msg'; if you renamed the file with that name stackMe can continue"
		 if _rc  {										// Check on return code from rusure
		  	display as error "Else best restart analysis with most recent coherent file" // Non-zero RC is a 'no'
		  	window stopbox stop "stackMe recommends you restart analysis with most recent coherent file"
		 } //endif
	  } //endif `newname'
    } //endelse `filename'


												// CONTINUE WITH establishing contextvars
												

	syntax [varlist(default=none)] [, NOCONtexts CLEar DELete DISplay * ]

	quietly display "{smcl}" _continue
	
	if "`delete'"!=""  local clear = "clear"					// 'delete' is undocumented and included for user convenience

	if "`varlist'"=="" & "`nocontexts'"=="" & "`clear'"=="" & "`delete'"=="" & "`display'"==""  {
		display as error "Command SMsetcontexts needs varlist or ', display' | ', nocontexts' | ', clear'"
		window stopbox stop "Command SMsetcontexts needs varlist or ', display' or ', nocontexts' or ', clear'"
											
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
		  display as error "Reconfigure this dataset before continuing. See {help stackMe##SMsetcontexts:contextvars} help text"
		  window stopbox stop "Cannot initialize a stacked dataset; reconfigure before continuing - type 'help SMsetcontexts'"

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
			char define _dta[contextvars] `contextvars'			// User answered 'ok' so establish the optioned contextvars
			noisily display "Data charactristc now has this dataset's contxtvars as: `contextvars'"
*    					     12345678901234567890123456789012345678901234567890123456789012345678901234567890
*			***************
			continue, break										// Exit this program
*			***************
		}
	} //endif
		
		
		

	if "`SMstkid'"!="" & "`varlist'"!=""  {						// If there's already a stackid variable AND new contextvars are optnd
	   
	   noisily display "This dataset has established contextvars: `contextvars'"
	   display as error ///										// User needs warning of consequences for discarding the characteristc
			"Established contextvars should not change after stacking; use {help stackme##SMsetcontexts:contextvars} option"
*    	     12345678901234567890123456789012345678901234567890123456789012345678901234567890
	   local msg = "Contextvars characterstic should not change after stacking – use contextvars option on any stackMe command"
	   window stopbox stop "`msg' to override established contexts just for that command – else start again with original data"
	   
	} //endif													// Continue if user responded 'OK'"														
			

			

	if "`varlist'"!=""  {										// If varlist is not empty (it was set "" at top of program)
	
		local vars = "`varlist'"

		if "`contextvars'"!=""  {								// If contextvars characteristic is not empty there are estblshd contexts

			local same : list contextvars === vars				// returns 1 in 'same' if 'contextvars' & 'vars' have same contents
																// (irrespective of variable ordering)
			if `same'  noisily display "Redundant contextvar name(s) leave(s) contextvars characteristic unchanged"
*    						   			12345678901234567890123456789012345678901234567890123456789012345678901234567890
	
			else  {												// Else varlist names vars different from established contextvars
				
			  if "`contextvars'"!="nocontexts"{					// If they do not say 'nocontexts'
			  
				local msg1 = "This dataset has established contextvars: `contextvars'. "
				local msg2 = "You can override these for a specific command by using the 'contextvars' option "
*    						  12345678901234567890123456789012345678901234567890123456789012345678901234567890
				display as err "`msg1'" 
				capture window stopbox rusure ///
				"`msg1' `msg2'for any stackMe command (except genStacks) – continue anyway? (note that a stacked " ///
				  dataset is normally tied to the contexts established when stacking)
				if _rc  {
				  window stopbox stop "Absent permission to establish new contextvars, will exit on next 'OK'"
				}
				else char define _dta[contextvars] `vars'		// Else re-establish varlist as new contextvars	
				
				noisily display "Re-initialized contextvars characteristic now names: `vars'"
*    						     12345678901234567890123456789012345678901234567890123456789012345678901234567890
				noisily display "NOTE: a stacked dataset would have been tied to contexts establishd when stackng"
*    						 	 12345678901234567890123456789012345678901234567890123456789012345678901234567890

*				***************
				continue, break									// Break out of 'while' loop
*				***************

			  } //endif											// Already dealt above with characteristic saying 'nocontexts'
			  	
			} //endelse
			  
		} //endif 'contextvars'!=""
		   	   
		else  {													// Else there is no existing contextvars characteristic
		   
			noisily display "Named contextvar(s) now established as characteristic of this dataset"
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
			  "A stacked dataset is characterized by the contextvars used when stacking – somehow these have become disconnected; "
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
			     local msg = "This dataset has not been initialized for use with {cmd:stackMe} commands; invoke "
*    					      12345678901234567890123456789012345678901234567890123456789012345678901234567890
			     display as error "`msg'"
				 display as error "this command to option 'nocontexts' or to name existing contextvars"{txt}
			     window stopbox stop "`msg'command to option 'nocontexts' or to name existing contextvars'"
		      }
		
		      else noisily display "This dataset has established contextvars: `contextvars'"
			  
		  } //endelse

	   } //endif

	} //endelse
	
	continue, break												// Prevents while loop repeating indefinitely
	
	} //end while
	
	noisily display _newline "done." _newline
	  
	
end SMsetcontexts


********************************************************************************************************************************


capture program drop SMsetcon

program define SMsetcon

SMsetcontexts `0'

end SMcon



capture program drop SMset

program define SMset

SMsetcontexts `0'

end SMcon



********************************************************************************************************************************



capture program drop SMsavefile

program define SMsavefile									// Utility to save a stackMe file under new name and/or directory

version 9.0

global cmd "SMsavefile"



	local filename : char _dta[filename]					// Filename established by setcontexts
	local dirpath  : char _dta[dirpath]						// Dirpath established by setcontexts
	
	global newfile = "`dirpath'" + "`filename'" 			// Default filename and dirpath in global required by fsave
	
	capture window fsave newfile "Edit name and choose folder for file in which to save stackMe data" "Stata Data (*.dta)|*.dta" dta
*              		              12345678901234567890123456789012345678901234567890123456789012345678901234567890	
	
	if _rc  {
		noisily display "File not saved."					// Non-zero RC means user did not supply a filename
		exit	
	}

	
	else {													// Else user supplied a filename
	
	   capture save $newfile
	
	   if _rc!=0  {											// If file already exists..

		   noi display as error _newline "Overwrite existing file?{txt}" 
*              		         		   12345678901234567890123456789012345678901234567890123456789012345678901234567890
		   capture window stopbox rusure "Overwrite existing file?"
		   
		   if _rc==0  {										// If user responded with 'OK'
		   
			   noi display "This file replaces existing $newfile"
			   
		   } //endif _rc
		   
		   else  {
		   
			   window stopbox stop "Absent permission to overwrite existing file will exit on OK"
			   
		   }
		   
		   local nameloc = strrpos("$newfile","`c(dirsep)'") +1 // Loc of first char after FINAL dirsep "/" or "\" of dirpath
		   global SMdirpath = substr("$newfile",1,`nameloc'-1) 	// `dirpath' ends w last `c(dirsep)' (i.e. 1 char before name)
		   global SMfilename = substr("$newfile",`nameloc',.)	// Update filename with latest filename saved or used by Stata

		   char define _dta[filename] "$SMfilename"			// Establish this filename as characteristic of dataset			   
		   char define _dta[dirpath] "$SMdirpath"			// And the directory path to that name
															// (globals support legacy code that did not use data characteristics)
			
		   noisily display "file $newfile saved."
		   		
	   } //endif _rc!=0										// Otherwise file does not already exist and has been saved
	  
	} //endelse 											


end SMsavefile



***********************************************************************************************************************************


capture program drop SMsave

program define SMsave

SMsavefile `0'

end SMsave



capture program drop SMsav

program define SMsav

SMsavefile `0'

end SMsav



***********************************************************************************************************************************



capture program drop SMitemname								// Utility enables establishment of, or change to, data characteristics
															//  that name SMitem and S2item variables that provide stack linkage
															//  variables that supplement SMstkid and S2stkid by providing alternative  
															//  identifiers linking stacks to substantive variables regarding each stack
program define SMitemname

version 9.0

	global cmd "SMitemname"
	
												  // SEE IF THIS IS INITIAL CALL on stackMe utility for a new dataset
												  
	local filename : char _dta[filename]					// Get established filename if already set as dta characteristic
	local dirpath  : char _dta[dirpath]						// Ditto for dirpath; if empty then datafile was not initialized

															// Either way, get name and dirpath for currently used file
	local fullname = c(filename)							// Path+name of datafile most recently used or saved
	if strpos("`fullname'", c(tmpdir))>0  {					// If c(tmpdir) is contained in dirpath then this is a tempfile...
		if "`filename'" = ""								// And we don't have an existing filename in filename characteristic
		display as error "{bf:SMsetcontexts} can't get name of datafile; invoke this cmd closer to relevant {bf:{help use}}"
*						  12345678901234567890123456789012345678901234567890123456789012345678901234567890
		window stopbox stop "'SMsetcontexts' cannot access name of datafile; invoke this command closer to relevant 'use' command"
	}														// (should not happen)
	
															// Otherwise we have a useable supposed (new) filename
	
	local nameloc = strrpos("`fullname'","`c(dirsep)'") + 1	// Loc of first char after FINAL dirsep ("/" or "\") of dirpath
	local newpath = substr("`fullname'",1,`nameloc'-1) 		// `newpath' ends w last `c(dirsep)' (i.e. 1 char before name)
	local newname = substr("`fullname'",`nameloc',.)		// Update filename with latest filename saved or used by Stata
  
	if "`filename'"=="" {									// If filename characteristic is empty
		char define _dta[filename] `newname' 				// Establish most recent filename as characteristic of dataset
		char define _dta[dirpath]  `newpath' 				// Initialization still needs contextvars, added far below
		noisily display "NOTE: File named `newname' initialized as new stackMe datafile"
	} //endif 'newname'
	
	else  {													// Else file has already been initialized with existing filename
	
	  if "`newname'"!="`filename'"  {						// If existing char differnt from new name we have potential conflict...
		 local msg = "Name of open file doesn't match its filename characterstic"
		 display as err "`msg'; replace charctrstic?"
*					     12345678901234567890123456789012345678901234567890123456789012345678901234567890
		 capture window stopbox rusure "`msg'; if you renamed the file with that name stackMe can continue"
		 if _rc  {											// Check on return code from rusure
		  	display as error "Else best restart analysis with most recent coherent file" // Non-zero RC is a 'no'
		  	window stopbox stop "stackMe recommends you restart analysis with most recent coherent file"
		 } //endif
	  } //endif `newname'
	  
    } //endelse `filename'


													// CONTINUE WITH INITIALIZING OR UPDATING ITEMNAME LINKS
													

	syntax [varlist(default=none)] [, DISplay CLEar DELete ] 	// 'delete' is undocumented but included for user convenience

	if "`varlist'"=="" & "`clear'"=="" & "`display'"=="" & "`delete'"=="" { // See if user optioned something sensible
		display as error "Command SMitemname should supply a new SMitem name or ', display' or ', clear'"
		window stopbox stop "Command SMitemname should supply a new SMitem name or ', display' or ', clear'"
	} //endif

	
	if "`delete'"!=""  local clear = "clear"					// 'delete' is undocumented but included for user convenience


	local SMitem = "`_dta[SMitem]'"								// Get currently stored varname for this characteristic
	
	
	local msg = "You can temporarily override this charactristic by optioning {opt ite:mname} on any stackMe cmd"
*                12345678901234567890123456789012345678901234567890123456789012345678901234567890			
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

			if _rc  errexit "You did not click 'ok'" 

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
			capture window stopbox rusure `msg'; continue anyway?
																// Else did not exit
			display as error "Established SMitem characteristic linked to `SMitem' has been deleted"

 			char define _dta[SMitem]							// This clears the characteristic; an empty string would not

		}
		
	} //endelse 'varlist'
	
	noisily display _newline "done." _newline
	
		
end SMitemname


********************************************************************************************************************************


capture program drop SMitem

program define SMitem

SMitemname `0'

end SMitem


capture program drop SMite

program define SMite

SMitemname `0'

end SMite



********************************************************************************************************************************



capture program drop S2itemname

program define S2itemname

varsion 9.0

	global cmd = "S2itemname"
	
	if "$filename"==""  {										// If filename was not recorded by previous stacmMe command...
		local fullname = c(filename)							// Path+name of datafile most recently used or saved
		local nameloc = strrpos("`fullname'","`c(dirsep)'") + 1	// Loc of first char after FINAL "/" or "\" of dirpath
		if strpos("`fullname'", c(tmpdir)) == 0  {				// Unless c(tmpdir) is contained in dirpath ...
			global dirpath = substr("`fullname'",1,`nameloc'-1)	// `dirpath' ends w last `c(dirsep)' (i.e. 1 char before name)
			global filename = substr("`fullname'",`nameloc',.)	// Update filename with latest name saved or used by Stata
		}														// (used by genstacks as default name for newly-stackd dtafile)
	
		else  {													// Else a tempfile was opened since any datafile
			gettoken cmd rest : 0								// Get the command name from head of local `0' (what the user typed)
			display as error "{bf:cmd} cannot access name of datafile; invoke this command closer to relevant {bf:use}"
*    				  	   12345678901234567890123456789012345678901234567890123456789012345678901234567890
			window stopbox stop "`cmd' cannot access name of datafile; invoke '`cmd'' or 'SMsetcontexts' closer to relevant 'use' command"
		} //endelse
	
	} //endif


	syntax [varlist(default=none)] [, DISplay CLEar DELete ]	// 'delete' is undocumented and included for user convenience
	
	if "`varlist'"=="" & "`clear'"=="" & "`display'"=="" & "`delete'"==""  { 	// See if user has asked for something sensible

		display as error "Command S2itemname should supply a new S2item name or ', display' or ', clear'"
		window stopbox stop "Command S2itemname should supply a new S2item name or ', display' or ', clear'"
	
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
	
	
	else  {														// Else change an existing link

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
	
	noisily display _newline "done." _newline



end S2itemname


********************************************************************************************************************************


capture program drop S2item

program define S2item

SMitemname `0'

end S2item


capture program drop S2ite

program define S2ite

SMitemname `0'

end S2ite



********************************************************************************************************************************



capture program drop SMfilename

program define SMfilename

	syntax [anything] [, DIRpath CLEar DELete DISplay * ]

	global cmd = "SMfilename"
		
	quietly display "{smcl}" _continue
	
	syntax [anything], [DIRpath CLEar DELete DISplay]
	
	if "`delete'"!=""  local clear = "clear"					// 'delete' is undocumented and included for user convenience
*FIX THIS
	if "`anything'"=="" & "`dirpath'"=="" & "`clear'"=="" & "`delete'"=="" & "`display'"==""  {
	  display as error "Command SMfilename needs filename or ', display' | ', dirpath' | ', clear'"
	  errexit "Command SMfilename needs varlist or ', display' or ', dirpath' or ', clear'"
	}
	
	local name = "`_dta[filename]'"								// Get established filename & dirpath, if any
	local path = "`_dta[dirpath]'"
	
	if "`dirpath'"!=""  {										// If user optioned 'dirpath'..
	  
	  if "`path'"==""  {
	  	local msg = "Dataset not yet initialized by"
	  	display as error "`msg' {help SMutilities##SMsetcontexts:SMsetcontexts} so it has no established dirpath"
*                	         12345678901234567890123456789012345678901234567890123456789012345678901234567890
		window stopbox stop "`msg 'SMsetcontexts' so it has no established dirpath; will exit on next 'OK'"
	  }
	
	  global fname = "`path'"+"`name'"							// Puts whatever we have into $fname
	  capture window fopen fname "" dta
	  if _rc  window stopbox stop "No such file; will exit on 'OK'"
	  else  {													// Here decompose the returned $fsave into name and path
		local nameloc = strrpos("$fsave","`c(dirsep)'") + 1		// Loc of 1st char after FINAL "/" of $fsave (NOTE "rr" in 'strr')
		local newpath = substr("$fsave",1,`nameloc'-1)			// $fsave ends w last `c(dirsep)' (i.e. 1 char before name)
		local newname = substr("$fsave",`nameloc',.)			// Update filename with latest name saved or used by Stata
		char define _dta[filename] `newname'					// Put that filename into the _dta characteristic named 'SMitem'
		char define _dta[dirpath]  `newpath'					// Same for dirpath
	  }
	} //endif 'dirpath'
	
	else  {														// 'dirpath' was not optioned
	
	  if "`anything'"!=""  {									// If user supplied a filename in 'anything'
	  	global fname = "`path'" + "`anything'"					// If `path' is empty user can choose a path
		capture window fopen fname "" dta
		if _rc  window stopbox stop "No such file; will exit on next 'OK'"
		else  {
		  local nameloc = strrpos("$fsave","`c(dirsep)'") + 1	// Loc of 1st char after FINAL "/" of $fsave (NOTE "rr" in 'strr')
		  local newpath = substr("$fsave",1,`nameloc'-1)		// $fsave ends w last `c(dirsep)' (i.e. 1 char before name)
		  local newname = substr("$fsave",`nameloc',.)			// Update filename with latest name saved or used by Stata
		  char define _dta[filename] `newname'					// Put that filename into the _dta characteristic named 'SMitem'
		  char define _dta[dirpath]  `newpath'					// Same for dirpath
		}
	  } //endif 'anything'
	  
	  else  {													// 'anything' does not contain filename
	  	if "`clear'"!=""  {										// 'clear' was optioned
		  char define _dta[filename]							// Clear the filename characteristic
		  char define _dta[dirpath]								// Same for dirpath	
		  noisily display _newline "File characteristics deleted as per user request" _newline
		}
	  }
	}

	if "`display'"!=""  {
	  local name = "`_dta[filename]'"							// Get (newly) established filename & dirpath
	  local path = "`_dta[dirpath]'"
	  noisily display "(znewly) established directory path and filename are:" _newline
	  noisily display "`path'`name'"
	}															

	noisily display _newline "done." _newline

	
end SMfilename


********************************************************************************************************************************


capture program drop SMfile

program define SMfile

SMitemname `0'

end SMfile


capture program drop SMfil

program define SMfil

SMitemname `0'

end SMfil



**************************************************** END OF stakMe UTILITIES ***************************************************


