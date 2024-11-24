capture program drop geniimpute

program define geniimpute

*!  Stata version 9.0; genyhats version 2, updated May'23 from major re-write in June'22; unchanged in Nov'24

	version 9.0
						// Here set stackMe command-specific options and call the stackMe wrapper program; lines 
						// that end with "**" need to be tailored to specific stackMe commands
									
								// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'
	local optMask ="ADDvars(varlist) CONtextvars(varlist) STAckid(varname) MINofrange(string) MAXofrange(string)"   /// **
	+ " IPRefix(name) MPRefix(name) LIMitdiag(integer -1) ROUndedvalues BOUndedvalues NOInflate SELected NOADDvarsx" //	**
		   
								// Ensure prefix option for this stackMe command is placed first
								// and its negative is placed last; ensure options w args preceed 
								// (aka flag) options and that last option w arg is limitdiag
								// CHECK THAT NO OTHER OPTIONS, BEYOND FIRST 3, NAME ANY VARIABLE(S)	**

																				
																
	local prfxtyp = "var"/*"othr" "none"*/			// Nature of varlist prefix – var(list) or other. (`stubname' will   ?/	**
								// be referred to as `opt1', the first word of `optMask', in codeblock 
								// (0) of stackmeWrapper called just below). `opt1' is always the name 
								// of an option that holds a varname or varlist (which must be referred
								// using double-quotes). Normally the variable named in `opt1' can be 
								// updated by the prefix to a varlist. In geniimpute the prefix can 
								// itself be a varlist.
		
		
	local multicntxt = "multicntxt"/*""*/			// Whether `cmd'P takes advantage of multi-context processing		**
	
*	*************************
	stackmeWrapper geniimpute `0' \ prfxtyp(`prfxtyp') `multicntxt' `optMask' // Name of stackme cmd followed by rest of cmd-line				
*	*************************				// (`0' is what user typed; `prfxtyp' & `optMask' were set above)	
								// (`prfxtyp' placed for convenience; will be moved to follow optns)
								// () that happens on fifth line of stackmeCaller's codeblock 0)
	

end // geniimpute			



*  EXTradiag REPlace NEWoptions MODoptions NODIAg NOCONtexts NOSTAcks  (+ limitdiag) ARE COMMON TO MOST STACKME COMMANDS
*




************************************************** PROGRAM genii *********************************************************


capture program drop genii

program define genii

geniimpute `0'

emd genii


*************************************************** END PROGRAM **********************************************************

