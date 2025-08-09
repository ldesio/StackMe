capture program drop geniimpute				// Estimates multiply-imputed versions of stackMe variables
											// (the "multiple" in "multiply-imputed" is a feature of multi-country datasets)
											
											// Called by 'gendu' a separate program defined after this one
											// Calls subprogram stackmeWrapper

program define geniimpute					// SEE PROGRAM stackmeWrapper (CALLED  BELOW) FOR  DETAILS  OF  PACKAGE  STRUCTURE


*!  Stata version 9.0; genyhats version 2, updated May'23 from major re-write in June'22; unchanged in Nov'24

	version 9.0
								// Here set stackMe command-specific options and call the stackMe wrapper program; lines 
								// that end with "**" need to be tailored to specific stackMe commands
									
								// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'
	local optMask ="ADDvars(varlist) CONtextvars(varlist) STAckid(varname) MINofrange(string) MAXofrange(string) "   /// **
		 + "IPRefix(name) MPRefix(name) LIMitdiag(integer -1) NODIAg ROUndedvalues BOUndedvalues NOInflate SELected" //	 **
		   
								// Ensure prefix option for this stackMe command is placed first
								// and its negative is placed last; ensure options w args preceed 
								// (aka flag) options and that last option w arg is limitdiag
								// CHECK THAT NO OTHER OPTIONS, BEYOND FIRST 3, NAME ANY VARIABLE(S)					 **
														
	local prfxtyp = "var"/*"othr" "none"*/			// Nature of varlist prefix – var(list) or other. (`stubname'  //	 **
								// will be referred to as `opt1', the first word of `optMask', in codeblock 
								// (0) of stackmeWrapper called just below). `opt1' is always the name 
								// of an option that holds a varname or varlist (which must be referred
								// using double-quotes). Normally the variable named in `opt1' can be 
								// updated by the prefix to a varlist. In geniimpute the prefix can 
								// itself be a varlist.
		
		
	local multicntxt = "multicntxt"/*""*/			// Whether `cmd'P takes advantage of multi-context processing		 **
	
	local save0 = "`0'"
	
	
*	*************************
	stackmeWrapper geniimpute `0' \ prfxtyp(`prfxtyp') `multicntxt' `optMask' // Name of stackme cmd & rest of cmd-line				
*	*************************						// (`0' is what user typed; `prfxtyp' & `optMask' were set above)	
													// (`prfxtyp' placed for convenience; will be moved to follow optns)
													// ( that happens on fifth line of stackmeCaller's codeblock 0)

*  EXTradiag REPlace NEWoptions MODoptions NODIAg NOCONtexts NOSTAcks  (+ limitdiag) ARE COMMON TO MOST STACKME COMMANDS
*  and so are added in 'stackmeWrapper'
						
											
											
											
										// *****************************
										// On return from stackmeWrapper
										// *****************************
										
										
										
							
  
  capture erase $origdta 									// Erase the tempfile that held the unstacked data, if any as yet)
  capture confirm existence $SMrc 							// Confirm whether $SMrc holds a return code
  if _rc==0  scalar RC = $SMrc 								// If return code indicates that it does, stash it in scalar RC
  else scalar RC = 98765									// Else stash an unused return code
  if $limitdiag !=0 & RC == 98765  noisily display _newline "done."	// Display "done." if no error was reported, by Stata or by stackMe
  macro drop _all											// Drop all macros (including $SMrc, if extant)
  if RC != 98765  local rc = RC 							// Set local if scalar does not hold the word "null" (assigned just above)
  scalar drop _all 											// Drop all scalars, including RC


  exit `rc'

	
end // geniimpute			



************************************************** PROGRAM genii *********************************************************


capture program drop genii

program define genii
															// (should that be needed)
geniimpute `0'

end genii


*************************************************** END PROGRAM **********************************************************
