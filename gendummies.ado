capture program drop gendummies

program define gendummies



*!  Stata version 9.0; gendummies version 2, updated Apr'23 (with minor tweaks in Sept '24) by Mark from major re-write in June'22

	version 9.0
										// Here set stackMe command-specific options and call the stackMe wrapper program; lines 
										// that end with "**" need to be tailored to specific stackMe commands
										
														// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'		
	local optMask = "STUbprefix(name) CONtextvars(varlist) LIMitdiag(integer -1) INCludemissing NOSTUbprefix"					    	 //	**

														// Ensure stubprefix for this stackMe command is placed first and its 
														// negative is placed last; ensure options with arguments preceed toggle 														// (aka flag) options; limitdiag should folloow last argument, followed
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


														
										// On return from stackmeWrapper 
										
	local temp = "`0'"									// Create tempvar to hold just first varlist in `anything'
	
	
	local istpipes = strpos("`temp'","||")  			// Find location of first "||", if any, and remove them
	if `istpipes'>0 local temp = substr("`temp'",1,`istpipes'-3) // (syntax command does not like to see them)

	local 0 = "`temp', `opts'"							// Look for 'ifinw' exprssns in 'anything', filled in codeblk 0.2 line 70 

	
	******
	syntax anything [if] [in] [aw fw iw pw/], [ LIMitdiag(integer -1) NODiag *  ]
	******
	
		
	if "`nodiag'"!=""  local limitdiag = 0
	
	if `limitdiag'!=0  noisily display _newline "done." _newline


	
	
end gendummies			


*  CONtextvars NODiag EXTradiag REPlace NEWoptions MODoptions NOCONtexts NOSTAcks  (+ limitdiag) ARE COMMON TO MOST STACKME COMMANDS
*														// All of these except limitdiag are added in stackmeWrapper, codeblock(2)






******************************************************** PROGRAM gendu ************************************************************


capture program drop gendu

program define gendU

gendist `0'

end gendu

********************************************************* END gendu ***************************************************************




