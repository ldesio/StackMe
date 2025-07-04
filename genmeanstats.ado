capture program drop genmeanstats

program define genmeanstats


*!  Stata version 9.0; genstats version 2, updated Aug'23 by Mark from major re-write in June'22; revised Nov'24 to add prog genme

	version 9.0
										// Here set stackMe command-specific options and call the stackMe wrapper program; lines 
										// that end with "**" need to be tailored to specific stackMe commands
										
														// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'		
	local optMask = "DUMmyprefix(name) CONtextvars(varlist) STAckid(varname) STAts(string) MNPrefix(name) SDPrefix(name) " ///  **
				  + "MIPrefix(name) MAPrefix(name) SKPrefix(name) KUPrefix(name) SWPrefix(name) " 					   	   ///  **
				  + "LIMitdiag(integer -1) INCludemissing NOCONtextvars NOSTAcks NODUMmyprefix"											//  **

														// This command has no prefixvar so its place is taken by a dummy opt; its 
														// negative is placed last; ensure options with arguments preceed toggle 
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
	
	local save0 = "`0'"									// Seems necessary, perhaps because called from gendi
	

*	***********************									   
	stackmeWrapper genmeanstats `0' \ prfxtyp(`prfxtyp') `multicntxt' `optMask' // Name of stackme cmd followed by rest of cmd					
*	***********************								// (local `0' has what user typed; `optMask'&`prfxtyp' were set above)	
														// (`prfxtyp' placed for convenience; will be moved to follow options)
														// (that happens on fifth line of stackmeWrapper's codeblock 0)
	
*  NODiag EXTradiag REPlace NEWoptions MODoptions NOCONtexts NOSTAcks  (+ limitdiag) ARE COMMON TO MOST STACKME COMMANDS
*														// All of these except limitdiag are added in stackmeWrapper, codeblock(2)
	
	
								// On return from wrapper ...
								
*	*****************								
	if "$SMreport"!="" {									// If return does not follow an errexit report
*	*****************

								
	if $exit  exit 1									// No post-processing if return from wrapper was an error return
	
								
	local 0 = "`save0'"									// Restore what the user typed
	
	
	syntax anything, [ LIMitdiag(integer -1) NODiag *  ]
	
	if "`nodiag'"!=""  local limitdiag = 0
	
	if `limitdiag'!=0  noisily display _newline "done." _newline
	
	
	
	global multivarlst									// Clear this global, retained only for benefit of caller programs
	global SMreport										// And these, retained for error processing
	global SMrc												
	capture erase $origdta 								// (and erase the tempfile in which it was held, if any)
	global origdta

	
*	*******************
    } //endif $SMreport
*	*******************


end genmeanstats			




************************************************** PROGRAM genme ****************************************************************


capture program drop genme


program define genme

genmeans `0'

end genme


**************************************************** END genme ****************************************************************



