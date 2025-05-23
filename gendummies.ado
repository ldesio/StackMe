

capture program drop gendummies			// Transforms categorical variables into dummy vars, one dummy for each level of the original

										// SEE PROGRAM stackmeWrapper (CALLED  BELOW) FOR  DETAILS  OF  PACKAGE  STRUCTURE

program define gendummies								// Called by 'gendu' a separate program defined after this one
														// Calls subprogram stackmeWrapper
						

*!  Stata version 9.0; gendummies version 2, updated Apr'23 (with minor tweaks in Sept '24) by Mark from major re-write in June'22

	version 9.0
										// Here set stackMe command-specific options and call the stackMe wrapper program; lines 
										// that end with "**" need to be tailored to specific stackMe commands
										
														// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'		//	**
	local optMask = "STUbname(name) /*DUPrefix(string) */LIMitdiag(integer -1) INCludemissing REPlace /*NODUPrefix */NOSTUbname"

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
											
   *********************														
	if "$SMreport"==""  {								// If return does not follow an errexit report
*	*********************								// (exit 1 exits to caller, if any, or to Stata)

		local 0 = "`save0'"								// On return from stackmeWrapper estore what user typed

*		***************	
		syntax anything [if] [in] [aw fw iw pw/], [ STUbname LIMitdiag(integer -1) NODiag *  ]
*		***************
	
		
		if "`nodiag'"!=""  local limitdiag = 0			// THE ONLY FUNCTION OF THIS CODEBLK1
	
*		if "`stubprefix'"!="" 							// SEEMINGLY NO POST-PROCESSING FOR THIS 'cmd'							***
	
		if `limitdiag'!=0  noisily display _newline "done." _newline

*	  *****************
	} //endif $SMreport									// Close braces that delimit code skipped on return from error exit
*	  *****************	  
	
	global multivarlst									// Clear this global, unused above
	global SMreport										// Ditto
	global origdta										// Ditto
	
end gendummies			


*********************************************** PROGRAM GENDU *******************************************************************


capture program drop gendu								// Short command name for 'gendummies'

program define gendu

gendist `0'

end gendu

************************************************* END GENDU *******************************************************************
