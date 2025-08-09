
capture program drop gendist				// Calculates distances (now also proximities) between respondent's self-placed spatial 
											// locations and the spatial location of battery items.
											
											// Called from program gendi (appended); calls stackmeWrapper, errexit
											
											// SEE PROGRAM stackmeWrapper (CALLED  BELOW) FOR  DETAILS  OF  PACKAGE  STRUCTURE

program define gendist										// Called by 'gendi' a separate program defined after this one
															// Calls subprogram stackmeWrapper and subprogram 'errexit'

*!  program gendist written for Stata version 9.0; gendist version 2, updated by Mark, May'23-May'25 from major re-write in June'22

version 9.0

															

											// (0 Here sets stackMe command-specific options and call the stackMe wrapper program;  
											//    lines ending with "**" need to be tailored to specific stackMe commands

global errloc "gendist(0)"									// $Records which codeblk is now executing, in case of Stata error


															// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'. Ensure
															// prefixvar (here SELfplace) is first option and its negative is last.
															
	local optMask = "SELfplace(varname) ITEmname(varname) MISsing(str) DPRefix(str) PPRefix(str) MPRefix(string) APRefix(string)"  ///
				  + " XPRefix(str) MCOuntname(name) MPLuggedcountname(name) RESpondent(varname) LIMitdiag(integer -1) PROximities" ///
				  + " PLUgall ROUnd NOREPlace NOSelfplace" 	// NOTE that 'noreplace' is not returned in macro 'replace'				**
	
															// First option in optMask has special status, generally naming a var or
															//  varlist	that may be overriden by a prefixing var or varlist (hence	
															//  the name). `prefixvar' is referred to as `opt1' in stackmeWrapper,  
															//  called below, and must be referenced using double-quotes. Its status
															//  in any given 'cmd' is shown by option 'prfxtyp' (next line).
															
	local prfxtyp = "var"/*"othr" "none"*/					// Nature of varlist prefix – var(list) or other. (NOTE that a varlist	**
															// may itself be prefixd by a string, but that leaves prfxtyp unchanged).
															
															// Ensure that options with args preceed toggle (aka flag) options, and	
															//  that the final pre-flag option is 'limitdiag', which served as 
															//  reference point for a previous version of 'staclmeWrapper' (no longer
															//  a feature of stackMe syntax but should be retained in case we should	 	
															//  want to revert to cumulating options at some point; similarly for 
															// 'NEWoptions' and 'MODoptions')						
															
	local multicntxt = "multicntxt"/*""*/					// Whether `cmd'P takes advantage of multi-context processing – saves	**
															//  (e.g.) call(s) on _mkcross if empty.										
															
	local save0 = "`0'"										// Saves what user typed, to be retrieved on return to this caller prog.**
	
	
*	**********************
	stackmeWrapper gendist `0' \prfxtyp(`prfxtyp') `multicntxt' `optMask' 	// Space after "\" must go from all calling programs
*	**********************									// (`0' is what user typed; `prfxtyp' & `optMask' strings were filled	
															//  above; `prfxtyp', placed for convenience, will be moved to follow 
															//  optns – that happens on 4th line of stackmeWrapper's codeblk(0.1))
															// `multicntxt', if empty, sets stackMeWrapper flag 'noMultiContxt'
			
*  CONtextvars NODiag EXTradiag REPlace NEWoptions MODoptions NOCONtexts NOSTAcks  (+ limitdiag) ARE COMMON TO MOST STACKME COMMANDS
*															// All of these except limitdiag are added in stackmeWrapper, codeblock(2)
	
	
	
	
								// **************************
								// On return from wrapper ...
								// **************************
								
								
								
  

  capture erase $origdta 									// Erase the tempfile that held the unstacked data, if any as yet)
  capture confirm existence $SMrc 							// Confirm whether $SMrc holds a return code
  if _rc==0  scalar RC = $SMrc 								// If return code indicates that it does, stash it in scalar RC
  else scalar RC = 98765									// Else stash an unused return code
  if $limitdiag !=0 & RC==98765  noisily display _newline "done." // Display "done." if no error was reported, by Stata or by stackMe
  macro drop _all											// Drop all macros (including $SMrc, if extant)
  if RC != 98765  local rc = RC 							// Set local if scalar does not hold the word "null" (assigned just above)
  scalar drop _all 											// Drop all scalars, including RC

  
  
  exit `rc'													// Local 'rc' will be dropped on exit
															// (is empty if not non-zero, which has the same effect as 0)

  
end gendist



****************************************************** PROGRAM gendi **************************************************************


capture program drop gendi									// Abbreviated command name for 'gendist', which can me called directly

program define gendi

gendist `0'													// Invoke the command using its full name and append what user typed

end gendi


******************************************************* END PROGRMES **************************************************************





