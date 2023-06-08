

capture program drop genstacks

program define genstacks

*!  Stata version 9.0; genyhats version 2, updated Feb-May'23 b MNF from major re-write in June'22

	version 9.0
										// Here set stackMe command-specific options and call the stackMe wrapper program; lines 
										// that end with "**" need to be tailored to specific stackMe commands
									
															// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'
	local optMask = " ITEmname(varname) CONtextvars(varlist) STAckid(name) UNItname(name) TOTstackname(name) " ///					**
				  + "FE(namelist) FEPrefix(string) LIMitdiag(integer -1) KEEpmisstacks NOCheck"					//					**
															// NOTE that, for this `cmd', stackid is a name not a variable			**
															// NOTE that, for this `cmd', first option is not also a prefix			**
															// and does not have a negative counterpart
																				
																
	local prfxtyp = /*"var" "othr"*/"none"					// Nature of varlist prefix – var(list) or other. (`stubname' will		**
															// be referred to as `opt1', the first word of `optMask', in codeblock 
															// (0) of stackmeWrapper called just below). `opt1' is always the name 
															// of an option that holds a varname or varlist (which must be referred
															// using double-quotes). Normally the variable named in `opt1' can be 
															// updated by the prefix to a varlist. In geniimpute the prefix can 
															// itself be a varlist.
		
	
*	************************
	stackmeWrapper genstacks `0' \ prfxtyp(`prfxtyp') `optMask' // Name of stackme cmd followed by rest of cmd-line				
*	************************								  	// (`0' is what user typed; `prfxtyp' & `optMask' were set above)	
																// (`prfxtyp' placed for convenience; will be moved to follow optns)
																// () that happens on fifth line of stackmeCaller's codeblock 0)
	

end //genstacks			

*  EXTradiag REPlace NEWoptions MODoptions NEWexpression MODexpression NODIAg NOCONtexts NOSTAcks  ARE COMMON TO MOST STACKME COMMANDS
*  and are introduced in stackmeWrapper. `limitdiag' is also common to other stackme commands but serves as a marker in `optMask'



