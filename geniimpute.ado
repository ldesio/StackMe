capture program drop geniimpute

program define geniimpute

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
							
							
								// On return from wrapper ...
								
	if $exit  exit 1								// No post-processing if return from wrapper was an error return
	
								
	local 0 = "`save0'"
	
	syntax anything [aw fw pw/] , [ IPRefix(name) MPRefix(name) LIMitdiag(integer -1) NODIAg REPlace MINofrange(string) ] ///
								  [ MAXofrange(string)  ] *
	
	if "`nodiag'"!=""  local limitdiag = 0
	
	if "`iprefix'`nprefix'"!="" & `limitdiag'  {
		display as error "NOTE: Reassigning prefix string(s), as optioned"
	}
	
	if "`iprefix'"!=""  {
		rename i_* `iprefix'*
	}
	
	if "`mprefix'"!="" rename mi_* `mprefix'*
	
	if "`replace'"!=""  {										// If `replace' was optioned
		local nvl = 0
		while "`anything'"!=""  {
			local nvl = `nvl' + 1
			local vlnvl = "vl`nvl'"
			global vlnvl = ""									// Varlist (thePTVs) for this nvarlist (of multivarlist)
			local alnvl = "al`nvl'"
			global alnvl = ""									// Additional varlist for this `nvl' (as above)
		
			gettoken anything postpipes:anything,parse("||") 	//`postpipes' then starts with "||" or is empty at end of cmd
																 	
			gettoken precolon anything : anything,parse(":") 	// See if varlist starts with prefixing indicator 
																//`precolon' gets all of varlist up to ":" or to end of string		
				if "`anything'"!=""  {							// If not empty we should have a prefix varlist
				unab addvars : `precolon'						// Replace with `precolon' whatever was optioned for addvars		**
*		    	local isprfx = "isprfx"							// Not needed for geniimputeP										**
				local anything = strltrim(substr("`anything'",2,.))	// strip off the leading ":" with any following blanks
			} //endif `anything'
				
			else  local anything = "`precolon'"					// If there was no colon then varlist was in `precolon'
		
																				
			unab thePTVs : `anything'							// Legacy name for vars for which missing data wil be imputed
			local nvars : list sizeof thePTVs					// # of vars in this (sub-)varlist
			tokenize `thePTVs'
			forvalues i = 1/`nvars' {
				capture drop `i'								// Drop each var from which an i_`var' was generated
			}

		}
	} //endif 'replace'
	
	
	if `limitdiag'!=0  noisily display _newline "done." _newline

	

end // geniimpute			



*  EXTradiag REPlace NEWoptions MODoptions NODIAg NOCONtexts NOSTAcks  (+ limitdiag) ARE COMMON TO MOST STACKME COMMANDS
*




************************************************** PROGRAM genii *********************************************************


capture program drop genii

program define genii

geniimpute `0'

end genii


*************************************************** END PROGRAM **********************************************************
