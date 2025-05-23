
capture program drop genyhats				// Estimates inflated imputed values of listed variables for multiple imputation of
											//   contextual data (multiply-imputed thanks to the multiple context\s)

											// SEE PROGRAM stackmeWrapper (CALLED  BELOW) FOR  DETAILS  OF  PACKAGE  STRUCTURE
program define genyhats																									

*!  Stata version 9.0; genyhats version 2, updated Apr'23 by Mark from major re-write in June'22

	version 9.0
										// Here set stackMe command-specific options and call the stackMe wrapper program; lines 
										// that end with "**" need to be tailored to specific stackMe commands
										
														// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'		
	local optMask = "DEPvarname(name) CONtextvars(varlist) ITEmname(varname) ADJust(string) EFFects(string) EFOrmat(string) " ///**
				  + "YDPrefix(name) YIPrefix(name) LIMitdiag(integer -1) LOGit REPlace NODepvars"					    	 //	**

														// Ensure prefixvar for this stackMe command is placed first and its 
														// negative is placed last; ensure options with arguments preceed toggle 
														// (aka flag) options; limitdiag should folloow last argument, followed
														// by any flag options for this command. Options (apart from limitdiag) 
														// common to all stackMe `cmd's will be added in stackmeWrapper.
														// CHECK THAT NO OTHER OPTIONS, BEYOND THE FIRST 3, NAME ANY VARIABLE(S)**		**

	local prfxtyp = "var"/*"othr" "none"*/				// Nature of varlist prefix – var(list) or other. (`depvarname will		**
														// be referred to as `opt1', the first word of `optMask', in codeblock 
														// (0) of stackmeWrapper called just below). `opt1' is always the name 
														// of an option that holds a varname or varlist (which must be referred
														// using double-quotes). Normally the variable named in `opt1' can be 
														// updated by the prefix to a varlist, but not so in genyhats.
		
	local multicntxt = "multicntxt"/*""*/				// Whether `cmd'P takes advantage of multi-context processing			**
	
	local save0 = "`0'"									// Seems necessary, perhaps because called from gendi
	
	
	
*	***********************									   
	stackmeWrapper genyhats `0' \ prfxtyp(`prfxtyp') `multicntxt' `optMask' // Name of stackme cmd followed by rest of cmd-line					
*	***********************								// (local `0' has what user typed; `optMask'&`prfxtyp' were set above)	
														// (`prfxtyp' placed for convenience; will be moved to follow options)
														// (that happens on fifth line of stackmeWrapper's codeblock 0)
*  Additionally, NODiag EXTradiag REPlace NEWoptions MODoptions NOCONtexts NOSTAcks  (+ limitdiag) ARE COMMON TO MOST STACKME COMMANDS
*														// All of those except limitdiag are added in stackmeWrapper, codeblock(2)
														
														
											// *****************************
											// On return from stackmeWrapper
											// *****************************
											
* *********************														
  if "$SMreport"==""  {								// If return does not follow an errexit report
* ********************								// (if an error was reported we skip all processing otherwise done in caller)

	
	
	local 0 = "`save0'"								// On return from stackmeWrapper restore what user typed
	
	syntax anything, [ LIMitdiag(integer -1) NODiag *  ]
	
	if "`nodiag'"!=""  local limitdiag = 0
	
	if `limitdiag'!=0  noisily display _newline "done." _newline


* *******************
  } //endif $SMreport
* *******************


end genyhats			


************************************************* PROGRAM genyh **************************************************************

 
capture program drop genyh

program define genyh

genyhats `0'

end genyh


**************************************************** END genyh **************************************************************



**************************************************** END genyh **************************************************************

