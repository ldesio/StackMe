capture program drop genplace

program define genplace

*!  Stata version 9.0; genstats version 2, updated Aug'23 by Mark

	version 9.0
										// Here set stackMe command-specific options and call the stackMe wrapper program; lines 
										// that end with "**" need to be tailored to specific stackMe commands
										
														// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'		
	local optMask = "DUMmyprefix(name) CONtextvars(varlist) STAckid(varname) PPRefix(name) CWEight(name) MPRefix(name) "   ///  **
				  + "CALl(string) LIMitdiag(integer -1) TWOstep NODUMmyprefix NOCONtextvars NOSTAcks"									//  **						//  **

														// This command has no prefixvar. Its place is taken by dummy opt whose 
														// negative is placed last. Ensure options with arguments preceed toggle 
														// (aka flag) options; limitdiag should folloow last argument, followed
														// by any flag options for this command. Options (apart from limitdiag) 
														// common to all stackMe `cmd's will be added in stackmeWrapper.
														// CHECK THAT NO OTHER OPTIONS, BEYOND THE FIRST 3, NAME ANY VARIABLE(S)**

	local prfxtyp = "none"/*"var" "othr"*/				// Nature of varlist prefix – var(list) or other. (`depvarname will		**
														// be referred to as `opt1', the first word of `optMask', in codeblock 
														// (0) of stackmeWrapper called just below). `opt1' is always the name 
														// of an option that holds a varname or varlist (which must be referred
														// using double-quotes). Normally the variable named in `opt1' can be 
														// updated by the prefix to a varlist, but not in genyhats.
		
	local multicntxt = "multicntxt"/*""*/				// Whether `cmd'P takes advantage of multi-context processing			**
	
	
	local save0 = "`0'"

	
*	***********************									   
	stackmeWrapper genplace `0' \ prfxtyp(`prfxtyp') `multicntxt' `optMask' // Name of stackme cmd followed by rest of cmd-line					
*	***********************								// (local `0' has what user typed; `optMask'&`prfxtyp' were set above)	
														// (`prfxtyp' placed for convenience; will be moved to follow options)
														// (that happens on fifth line of stackmeWrapper's codeblock 0)
														
	if $exit  exit 1									// On error return go no further
	
	local 0 = "`save0'"
	
	:													// Incomplete
	:

end //gensplace			

*  NODiag EXTradiag REPlace NEWoptions MODoptions NOCONtexts NOSTAcks  (+ limitdiag) ARE COMMON TO MOST STACKME COMMANDS
*														// All of these except limitdiag are added in stackmeWrapper




********************************************** PROGRAM genlp *********************************************************************


capture program drop genpl

program define genpl

genplace `0'

end genpl


************************************************* END PROGRAM genpl ***************************************************************

