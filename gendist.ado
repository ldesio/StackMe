
capture program drop gendist

program define gendist

*!  Stata version 9.0; genyhats version 2, updated May'23 from major re-write in June'22

	version 9.0
										// Here set stackMe command-specific options and call the stackMe wrapper program; lines 
										// that end with "**" need to be tailored to specific stackMe commands
									
															// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'

	local optMask = "SELfplace(varname) CONtextvars(varlist) STAckid(varname) MISsing(string) PPRefix(name) MPRefix(name) "     ///	**
				  + "DPRefix(name) MCOuntname(name) MPLuggedcountname(name) RESpondent(varname) LIMItdiag(integer -1) PLUgall " ///	**
				  + "ROUnd REPlace NOSELfplace "			// `respondent' is not valid in version 2 but included to permit		**
															//  helpful error message												**

															// Ensure prefix option for this stackMe command is placed first
															// and its negative is placed last; ensure options w args preceed 
															// toggle (aka flag) options.	
																				
																
	local prfxtyp = "var"/*"othr" "none"*/					// Nature of varlist prefix – var(list) or other. (`stubname' will		**
															// be referred to as `opt1', the first word of `optMask', in codeblock 
															// (0) of stackmeWrapper called just below). `opt1' is always the name 
															// of an option that holds a varname or varlist (which must be referred
															// using double-quotes). Normally the variable named in `opt1' can be 
															// updated by the prefix to a varlist, as in gendummies.
		
	local multicntxt = ""/*"multicntxt"*/					// Whether `cmd'P takes advantage of multi-context processing			**
	
*	**********************
	stackmeWrapper gendist `0' \ prfxtyp(`prfxtyp') `multicntxt' `optMask' // Name of stackme cmd followed by rest of cmd-line				
*	**********************									  // (`0' is what user typed; `prfxtyp' `multicntxt' `optMask' set above)	
															  // (`prfxtyp' placed for convenience; will be moved to follow optns
															  // – that happens on fifth line of stackmeCaller's codeblock 0) 
															  // (`multicntxt', if not blank, sets stackMeWrapper switch noMultiContxt)
	

end // gendummies			



*  EXTradiag REPlace NEWoptions MODoptions NODIAg NOCONtexts NOSTAcks  (+ limitdiag) ARE COMMON TO MOST STACKME COMMANDS
*														// All of these except limitdiag are added in stackmeWrapper, codeblock(2)


