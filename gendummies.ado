
capture program drop gendummies			// Transforms categorical variables into dummy vars, one dummy for each level of the original

										// SEE PROGRAM stackmeWrapper (CALLED  BELOW) FOR  DETAILS  OF  PACKAGE  STRUCTURE

program define gendummies								// Called by 'gendu' a separate program defined after this one
														// Calls subprogram stackmeWrapper
						

*!  Stata version 9.0; gendummies version 2, updated Apr'23 (with minor tweaks in '24 and '25) by Mark from major re-write in June'22

	version 9.0
										// Here set stackMe command-specific options and call the stackMe wrapper program; lines 
										// that end with "**" need to be tailored to specific stackMe commands
										
														// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'		//	**
	local optMask = "STUbname(name) DUPrefix(string) LIMitdiag(integer -1) INCludemissing REPlace NODuprefix NOSTUbname"

														// Ensure stubname for this stackMe command is placed first and its 
														// negative is placed last; ensure options with arguments preceed toggle 
														// (aka flag) options for this command. Options (apart from limitdiag) 
														// common to all stackMe `cmd's will be added in stackmeWrapper.
														// CHECK THAT NO OTHER OPTIONS, BEYOND THE FIRST 3, NAME ANY VARIABLE(S)**

	local prfxtyp = /*"var"*/"othr"	/*"none"*/			// Nature of varlist prefix – var(list) or other. (`stubprefix' will	**
														// be referred to as `opt1', the first word of `optMask', in codeblock 
														// (0) of stackmeWrapper called just below). `opt1' is always the name 
														// of an option that holds a varname or varlist (which must be referred
														// using double-quotes). Normally the variable named in `opt1' can be 
														// updated by the prefix to a varlist, but not in genyhats.
		
	local multicntxt = ""/*"multicntxt"*/				// Whether `cmd'P takes advantage of multi-context processing			**
	
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
					
					
**********************														
if "$SMreport"!=""  {										// If this re-entry follows an error report (reported by program errexit)
															// ($SMreport is non-empty so error has been reported)
	if "$abbrevcmd"==""  {									// If the abbreviated command (next program) was NOT employed
															// (so user invoked this command by using the full stackMe cmdname)
		global multivarlst									// Clear this global, retained only for benefit of caller programs
		capture erase $origdta 								// Erase the 'origdta' tempfile whose name is held in $origdta
		global origdta										// Clear that global
		global SMreport										// And this one

		if "$SMrc"!="" {									// If a non-empty return code accompanies the error report
			local rc = $SMrc 								// Save that RC in a local (often the error is a user error w'out RC)
			global SMrc										// Empty the global
			exit `rc' 										// Then exit with that RC (the local will be cleared on exit)
		} //endif $SMrc										// ($SMrc will be re-evaluated on re-entry to abbreviated caller) 
	} //endif $abbrevcmd
	exit													// If got here via 'errexit' exit to gendi or Stata
															// (skip any further codeblocks, below, for this command)
} //endif $SMreport
************************									// ($SMreport non-empty so error has been reported)
		
		

	global errloc "gendu"

		
		
		
	***************		
	capture noisily {										// Begin new capture block in case of errors to follow)
	***************


		local 0 = "`save0'"									// On return from stackmeWrapper estore what user typed


*		***************	
		syntax anything [if] [in] [aw fw iw pw/], [ STUbname LIMitdiag(integer -1) APRefix(str) NODiag *  ]
*		***************

		if "`aprefix'"!=""  {									
			rename du_`var' du`aprefix'`var'				// Note that 'all-prefix' replaces the "_", not the 'd_'
		 }
		
		if "`nodiag'"!=""  local limitdiag = 0				// THE ONLY FUNCTION OF THIS CODEBLK1
	
*		if "`stubprefix'"!="" 								// SEEMINGLY NO POST-PROCESSING FOR THIS 'cmd'							***
	
		if `limitdiag'!=0  noisily display _newline _newline "done."
		
*		local skipcapture = "skip"							// SO NO NEED TO skipcapture
		

*	  **************
	} //end capture											// Close braces that delimit code skipped on return from error exit
*	  **************  

	
	global multivarlst										// Clear this global, retained for caller but unused above
	capture erase $origdta 									// Erase the `origdta' tempfile whose name is held in $origdta
	global origdta											// Clear that global
	global SMreport											// And this one
	
	if "$abbrevcmd"==""  {									// If the abbreviated command (next program) was NOT employed
															// (so user invoked this command by using the full stackMe cmdname)
	  if "$SMrc"!="" {										// If a non-empty return code was flagged anywhere in the program chain
		local rc = $SMrc 									// Save that RC in a local (often the error is a user error w'out RC)
															// (if not numeric will report same error as had it been used as cmd)
		global SMrc											// Empty the global
		exit `rc' 											// Then exit with that RC (the local will be deleted on exit)
	  }
	} //endif $abbrevcmd									// Else $SMrc can still be evluated on re-entry to abbreviated caller 

	
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


