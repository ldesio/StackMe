capture program drop gendummies

program define gendummies																									

*!  Stata version 9.0; genyhats version 2, updated Apr'23 by Mark from major re-write in June'22

	version 9.0
										// Here set stackMe command-specific options and call the stackMe wrapper program; lines 
										// that end with "**" need to be tailored to specific stackMe commands
										
														// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'		
	local optMask = "STUbname(name) LIMitdiag(integer -1) INCludemissing NOSTUbnme"					    	 					//	**

														// Ensure prefixvar for this stackMe command is placed first and its 
														// negative is placed last; ensure options with arguments preceed toggle 
														// (aka flag) options; limitdiag should folloow last argument, followed
														// by any flag options for this command. Options (apart from limitdiag) 
														// common to all stackMe `cmd's will be added in stackmeWrapper.
														// CHECK THAT NO OTHER OPTIONS, BEYOND THE FIRST 3, NAME ANY VARIABLE(S)	**

	local prfxtyp = /*"var"*/"othr"						// Nature of varlist prefix – var(list) or other. (`depvarname will			**
														// be referred to as `opt1', the first word of `optMask', in codeblock 
														// (0) of stackmeWrapper called just below). `opt1' is always the name 
														// of an option that holds a varname or varlist (which must be referred
														// using double-quotes). Normally the variable named in `opt1' can be 
														// updated by the prefix to a varlist, but not in genyhats.
	
*	*************************									   
	stackmeWrapper gendummies `0' \ prfxtyp(`prfxtyp') `optMask' // Name of stackme cmd followed by rest of cmd-line					
*	*************************							// (local `0' has what user typed; `optMask'&`prfxtyp' were set above)	
														// (`prfxtyp' placed for convenience; will be moved to follow options)
														// (that happens on fifth line of stackmeWrapper's codeblock 0)
	

end gendummies			


*  NODiag EXTradiag REPlace NEWoptions MODoptions NOCONtexts NOSTAcks ARE COMMON TO MOST STACKME COMMANDS and are
*  added in stackMeWrapper (limitdiag is also common to other commands but is included here as a delimeter)

