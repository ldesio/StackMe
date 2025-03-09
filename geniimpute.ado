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
	
								
	local 0 = "`save0'"								// Saved just before call on 'stackmeWrapper'
	
	syntax anything [aw fw pw/] , [ IPRefix(name) MPRefix(name) LIMitdiag(integer -1) NODIAg REPlace MINofrange(string) ] ///
								  [ MAXofrange(string) RANgeofvalues IPRefix(name) MPRefix(name) LIMitdiag(integer -1)  ] ///
								  [ NODIAg ROUndedvalues BOUndedvalues NOInflate SELected FASt ] *
	
	if `limitdiag' == -1   local limitdiag = .					// Make that a very big number!
	
	if "`nodiag'"!=""  local limitdiag = 0
	
	if `limitdiag' {											// Report on clean-up operations if optioned
	
	    if "`fast'"!="" & "`noinflate'"==""  {					// If 'fast' was optioned need to inflate if optioned
		  noisily display _newline _newline "Inflating the variance of imputed outcome values, as optioned"
		}
	
	    if "`iprefix'`mprefix'"!=""  noisily display as error "NOTE: Reassigning prefix string(s), as optioned"
	
		if "`replace'"!=""  {
			if "`keepmissing'"!=""
			   noisily display _newline "Dropping originals of imputed variables and missing indicators, as optioned"
		}
		else  noisily display _newline "Dropping originals of imputed variables, as optioned"
		
	} //endif 'limitdiag'
	
	
	
	local nvl = 0
		
	while "`anything'"!=""  {									// While there is another varlist in 'anything'

			local nvl = `nvl' + 1								// Add to count of nvarlists
			
			gettoken prepipes postpipes : anything, parse("||") //`postpipes' then starts with "||" or is empty at end of cmd
																// (and prepipes holds the varlist)
			if "`postpipes'"==""  local anything = ""			// If that was last varlist tell that to 'anything'
			
			gettoken precolon postcolon : prepipes, parse(":") 	// See if varlist starts with prefixing indicator 
																//`precolon' gets all of varlist up to ":" or to end of string		
			if "`postcolon'"!=""  {								// If not empty we should have a prefix varlist
				unab addvars : `precolon'						// Replace with `precolon' whatever was optioned for addvars	**
				local prepipes = strltrim(substr("`postcolon'",2,.)) // strip off the leading ":" with any following blanks
			} //endif `postcolon'								// (and put in prepipes where it would be, absent the colon)
				
			unab thePTVs : `prepipes'							// Legacy names of vars for which missing data is imputed
			
			
				
			if "`fast'"!="" & "`noinflate'"==""  {				// If 'fast' was optioned need to inflate if optioned
																// (so need to get stdev by context and stack)
			   if "`contextvars'"==""  {						// If 'contextvar' were optioned they supercede any charactstic 
			
				  local contexts :  char _dta[contextvars]		// Retrieve contextvrs establishd by SMcontextvrs or prior 'cmd'
				  if "`contexts'"!="" & "`contexts'"!="nocontexts" {
				  	local contextvars = "`contexts'"
				  }
		
			   } //endif 'contextvars'
				  
			   capture confirm variable SMstkid					// If data are stacked then SMstkid is context or extends contxt
			   if _rc==0 local contextvars = "`contextvars' SMstkid"
			   	
			   
			   foreach var of local thePTVs {					// Cycle thru all outcome vars in this varlist
				  
			      tempvar osd
				  
				  if "`contextvars'"==""  {						// If there are no context vars or stacks ..
				  	 qui egen `osd' = sd(`var')					// Get stdev of original var across whole dtaset
				  }
				  else qui egen `osd' =sd(`var'), by(`contextvars')	// Else get stdev for each context/stack
																// (cannot weight w' egen but should make no diffrnce to inflatn)
				  quietly replace i_`var' = i_`var'+rnormal(0,`osd') if m_`var'
				  drop `osd'									// Inflate just those observatns that were missng before plugging
											
			   } //next 'var'  

			} //endif 'fast'
			   
			   
			if "`boundedvalues'"!=""  {							// If optioned, enforce bounds of outcome values

				 foreach var of local thePTVs  {				// Cycle thru all original vars in this varlist
					 tempvar omi oma
					 qui egen `omi' = min(`var')					// Want this across all contexts, so no 'by'
					 qui egen `oma' = max(`var') if `var'<.
					 quietly replace i_`var' = `omi' if i_`var'<`omi' & m_`var'==0  // Replace if i_var is not missing
					 quietly replace i_`var' = `oma' if i_`var'>`oma' & m_`var'==0  // Replace if i_var is not missing
					 drop `omi' `oma'
				 }

			} //endif `boundedvalues'	
			   
								
			if "`roundedvalues'"!="" {							// If optioned, round outcome values
		
				 foreach var of local thePTVs  {				// Cycle thru all original vars in this varlist
				  
					 tempvar oma
					 qui egen `oma' = max(`var') if `var'<.
					 if `oma' <= 1  {							// Round to nearest .1 if r(max)<=1
						quietly replace i_`var' = round(i_`var', .1) if oma<=1 & m_`var'==0 // Only if i_var not missng
					 }											// Else round to nearest 1
					 else quietly replace i_`var' = round(i_`var') if oma>1 & m_`var'==0 	// Only if i_var not missng
				 }	

			} //endif `roundedvalues'
			   
			   
			if "`rangeofvalues'"!=""  {							// Here map v2 syntax onto v1 syntax
				local minofrange = word("`rangeofvalues`",1)
				local maxofrange = word("`rangeofvalues`",2)
			}
			   
			   
			if "`minofrange'"!="" | "`maxofrange'"!=""  {		// No matter whether old or new syntax was used
			   
				foreach var of local thePTVs  {					// Cycle thru all original vars in this varlist
				     if "`minofrange'"!="" quietly replace i_`var' = `minofrange' if i_`var'<`minofrange'
				     if "`maxofrange'"!="" quietly replace i_`var' = `maxofrange' if i_`var'>`maxofrange' & i_var<.
				}
				  
			} //endif 'rangeofvalues'

				
			foreach var of local thePTVs  {						// Rename/drop outcome variables as optioned
				
				
				  if "`iprefix'"!=""  {							// If iprefix was optioned ..
					 if substr("`iprefix'",-1,1)!="_"   local iprefix = "`iprefix'_"
					 rename i_`var'  i`iprefix'`var'			// Append an end-of-prefix marker if user did not
				  }
			      else  rename i_`var'  ii_`var'				// Else rename to default iimpute prefix												
				  
			   
				  if "`mprefix'"!=""  {							// If mprefix was optioned ..
					 if substr("`mprefix'",-1,1)!="_"   local mprefix = "`mprefix'_"
					 rename m_`var'  i`mprefix'`var'			// Append an end-of-prefix marker if user did not
				  }
				  else  {
				  	 rename m_`var'  im_`var'
					 local mprefix = "m_"						// This will prefix name of var to drop, if optioned
				  }
				  
	
				  if "`replace'"!=""  {

					  capture drop `var'						// If replace, drop each input that became an i_`var' 
					  
					  if "`keepmissing'"==""  capture drop i`mprefix'`var'
																// Also missing indicator unless 'keepmssng' was optd
				  } //endif
						  
			} //next 'var'

	} //endwhile
	
	local nvarlst = `nvl'
	
	
	
	capture label var SMmisImpCount "N of missing values in `nvars' imputed variables (`first'...`last')"


	
	global prefixedvars = ""								// Empty these globals

	
	forvalues nvl = 1/`nvarlst'  {							// cycle thru all varlists
		local vlnvl = "vl`nvl'"
		global `vlnvl' = ""									// Empty the globals they reference
		local alnvl = "al`nvl'"
		global `alnvl' = ""
	}
	
	
	if `limitdiag'  noisily display _newline _newline "done." _newline

	
end // geniimpute			



*  EXTradiag REPlace NEWoptions MODoptions NODIAg NOCONtexts NOSTAcks  (+ limitdiag) ARE COMMON TO MOST STACKME COMMANDS
*  and so are added in 'stackmeWrapper'




************************************************** PROGRAM genii *********************************************************


capture program drop genii

program define genii

geniimpute `0'

end genii


*************************************************** END PROGRAM **********************************************************
