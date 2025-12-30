
capture program drop gendummies			// Transforms categorical variables into dummy vars, one dummy for each level of the original

										// SEE PROGRAM stackmeWrapper (CALLED  BELOW) FOR  DETAILS  OF  PACKAGE  STRUCTURE

program define gendummies								// Called by 'gendu' a separate program defined after this one
														// Calls subprogram stackmeWrapper
						

*!  Stata version 9.0; gendummies version 2, updated Apr'23 (with minor tweaks in '24 and '25) by Mark from major re-write in June'22

	version 9.0
										// Here set stackMe command-specific options and call the stackMe wrapper program; lines 
										// that end with "**" need to be tailored to specific stackMe commands
										
														// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'		//		**
	local optMask = "STUbname(name) DUPrefix(string) LIMitdiag(integer -1) INCludemissing RECordmissing REPlace NODuprefix NOSTUbname"

														// Ensure stubname for this stackMe command is placed first and its 
														// negative is placed last; ensure options with arguments preceed toggle 
														// (aka flag) options for this command. Options (apart from limitdiag) 
														// common to all stackMe `cmd's will be added in stackmeWrapper.
														// CHECK THAT NO OTHER OPTIONS, BEYOND THE FIRST 3, NAME ANY VARIABLE(S)	**

	local prfxtyp = /*"var"*/"othr"	/*"none"*/			// Nature of varlist prefix – var(list) or other. (`stubprefix' will		**
														// be referred to as `opt1', the first word of `optMask', in codeblock 
														// (0) of stackmeWrapper called just below). `opt1' is always the name 
														// of an option that holds a varname or varlist (which must be referred
														// using double-quotes). Normally the variable named in `opt1' can be 
														// updated by the prefix to a varlist, but not in genyhats.
		
	local multicntxt = ""/*"multicntxt"*/				// Whether `cmd'P takes advantage of multi-context processing				**
	
	local save0 = "`0'"									// Seems necessary, perhaps because called from gendi

	
*	*************************									   
	stackmeWrapper gendummies `0' \ prfxtyp(`prfxtyp') `multicntxt' `optMask' // Name of stackme cmd followed by rest of cmd-line					
*	*************************							// (local `0' has what user typed; `optMask'&`prfxtyp' were set above)	
														// (`prfxtyp' placed for convenience; will be moved to follow options)
														// (that happens on fifth line of stackmeWrapper's codeblock 0)

*  CONtextvars NODiag EXTradiag REPlace NEWoptions MODoptions NOCONtexts NOSTAcks  (+ limitdiag) ARE COMMON TO MOST STACKME COMMANDS
*														// All of these except limitdiag are added in stackmeWrapper, codeblock(2)


														
											// *****************************
											// On return from stackmeWrapper
											// *****************************
											
											
					
					
  global SMreport = "skip"									//*****************************************************************
															// HAS EFFECT OF SKIPPING ENTIRE ENSUING CODE, NOW FOUND IN WRAPPER
  *******************										*******************************************************************
  if "$SMreport"==""  {										// If this re-entry follows an error report (reported by program errexit)
  *******************										// ($SMreport being non-empty means error has been reported)
		
		

	global errloc "gendu"

		
		
		
	***************		
	capture noisily {										// Begin new capture block in case of errors to follow)
	***************


		local 0 = "`save0'"									// On return from stackmeWrapper restore what user typed


*		***************	
		syntax anything [if] [in] [aw fw iw pw/], [ STUbname LIMitdiag(integer -1) APRefix(str) NODiag *  ]
*		***************

		if "`aprefix'"!=""  {								// Ensure aprefix, if any, has trailing "_"	
			if substr("`aprefix'",-1,1) !="_"  local aprefix = "`aprefix'_"
			rename du_`var' du`aprefix'`var'				// Note that 'all-prefix' replaces the "_", not the 'du_'
		 }
		
		if "`nodiag'"!=""  local limitdiag = 0				// THE ONLY FUNCTION OF THIS CODEBLK1
	
*		local skipcapture = "skip"							// SO NO NEED TO skipcapture
		

*	  **************
	} //end capture											// Close braces delimit code skipped on return from error exit
*	  **************  

*	***************
  } //end $SMreport
*	*************** 
  
  if _rc & "`skipcapture'"=="" & "$SMreport"!="skip"  {
  
	 errexit  "Program error while post-processing"
	 exit _rc

  }

  
  capture erase $origdta 									// Erase the tempfile that held the unstacked data, if any as yet)
  capture confirm existence $SMrc 							// Confirm whether $SMrc holds a return code
  if _rc==0  scalar RC = $SMrc 								// If return code indicates that it does, stash it in scalar RC
  else scalar RC = 98765									// Else stash an unused return code
  if $limitdiag !=0 & RC == 98765 noisily display _newline "done." // Display "done." only if no error reported, by Stata or by stackMe
  macro drop _all											// Drop all macros (including $SMrc, if extant)
  if RC != 98765  local rc = RC 							// Set local if scalar does not hold the word "null" (assigned just above)
  scalar drop _all 											// Drop all scalars, including RC

  exit `rc'													// Local 'rc' will be dropped on exit
  
end gendummies			



*********************************************** PROGRAM GENDU *******************************************************************


capture program drop gendu									// Short command name for 'gendummies'

program define gendu

global abbrevcmd = "used"									// Lets `cmd' know that abbreviated command was employed

gendist `0'													// Invoke the command using its full name and append what user typed

global abbrevcmd 											// On return to abbreviatd caller ('cos 'cmd' was called from here)
															// (immediately clear the global used to indicate that fact)
if "$SMrc"!="" {											// If a non-empty return code was flagged anywhere in program chain
	local rc = $SMrc 										// Save that RC in a local
	global SMrc												// Empty the global
	exit `rc' 												// Then exit with that RC (the local will be cleared on exit)
}															// Else execute a normal end-of-program

global abbrevcmd											// Clear the global

end gendu


************************************************* END GENDU *******************************************************************
