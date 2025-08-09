capture program drop genmeanstats

program define genmeanstats


*!  Stata version 9.0; genstats version 2, updated Aug'23 by Mark from major re-write in June'22; revised Nov'24 to add prog genme

	version 9.0
										// Here set stackMe command-specific options and call the stackMe wrapper program; lines 
										// that end with "**" need to be tailored to specific stackMe commands
										
														// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'		
	local optMask = "PLAceholder(name) STAckid(varname) STAts(string) MEAnprefix(name) MEDianprefix(name) "	/// **
				  + "MODeprefix(name) SDPrefix(name) MINprefix(name) MAXprefix(name) SKPrefix(name) KUPrefix(name) " /// 					   	   ///  **
				  + "SUMprefix(name) SUOfwts(name) LIMitdiag(integer -1) INCludemissing NOPLAceholder"								 // **

														// This commnd has no prefixvar so its place is taken by a placehoder
														// whose negative is placed last; ensure options with arguments preceed 
														// toggle (aka flag) options; final argument should be 'limitdiag(#)'.
														// Options common to all stackMe commands (apart from limitdiag) will 
														// be added in stackmeWrapper. CHECK THAT NO OTHER OPTIONS, BEYOND THE 
														// FIRST 3, NAME ANY VARIABLE(S) (THE ABOVE RESTICTIONS SIMPLIFY THE
														// PROGRAM CODE FOR PARSING A STACKME COMMAND WITHOUT AFFECTING USERS)	**

	local prfxtyp = "none"/*"var" "othr"*/				// Nature of varlist prefix – var(list) or other. (`depvarname will		**
														// be referred to as `opt1', the first word of `optMask', in codeblock 
														// (0) of stackmeWrapper called just below). `opt1' is always the name 
														// of an option that holds a varname or varlist (which must be referred
														// using double-quotes). Normally the variable named in `opt1' can be 
														// updated by the prefix to a varlist, but not in genyhats.
		
	local multicntxt = "multicntxt"/*""*/				// Whether `cmd'P takes advantage of multi-context processing			**
	
	local save0 = "`0'"									// Seems necessary, perhaps because called from gendi
	

*	***********************									   
	stackmeWrapper genmeanstats `0' \ prfxtyp(`prfxtyp') `multicntxt' `optMask' // Name of stackme cmd followed by rest of cmd					
*	***********************								// (local `0' has what user typed; `optMask'&`prfxtyp' were set above)	
														// (`prfxtyp' placed for convenience; will be moved to follow options)
														// (that happens on fifth line of stackmeWrapper's codeblock 0)
	
*  NODiag EXTradiag REPlace NEWoptions MODoptions NOCONtexts NOSTAcks  (+ limitdiag) ARE COMMON TO MOST STACKME COMMANDS
*														// All of these except limitdiag are added in stackmeWrapper, codeblock(2)
	
	
	
*								*****************************	
								// On return from wrapper ...
*								*****************************
								
	
	
	capture erase $origdta 									// Erase the tempfile that held the unstacked data, if any as yet)
	capture confirm existence $SMrc 						// Confirm whether $SMrc holds a return code
	if _rc==0  scalar RC = $SMrc 							// If return code indicates that it does, stash it in scalar RC
	else scalar RC = 98765									// Else stash an unused return code
	if $limitdiag !=0 & RC==98765  noisily display _newline "done." // Display "done." if no error was reported, by Stata or by stackMe
	macro drop _all											// Drop all macros (including $SMrc, if extant)
	if RC != 98765  local rc = RC 							// Set local if scalar does not hold the word "null" (assigned just above)
	scalar drop _all 										// Drop all scalars, including RC



end genmeanstats			




************************************************** PROGRAM genme ****************************************************************


capture program drop genme


program define genme

genmeans `0'

end genme


**************************************************** END genme ****************************************************************


