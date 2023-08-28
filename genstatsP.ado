capture program drop genstatsP

program define genstatsP

	version 9.0												// genstatsP version 2.0, June 2022, updated May 2023

*!  Stata version 9.0; genstatsP (new in version 2), August '23'

    syntax varlist [aw fw pw/] , [ CONtextvars(varlist) STAckid(varname) ] STAts(string)		   ///
	[ MNPrefix(name) SDPrefix(name) MIPrefix(name) MAPrefix(name) SKPrefix(name) KUPrefix(name) ]  ///
	[ SWPrefix(name) MEPrefix(name) MOPrefix(name) LIMitdiag(integer -1) INCludemissing NOCONtextvars NOSTAcks ] ///
	[ nvarlst(integer 1) ctxvar(string) nc(integer 0) c(integer 0) ]


															// Context-by-context processing IS used by genstats
															
	local cmdvars = "`varlist'"								// Save this from overwriting by next `syntax' command															


												// Pre-process gendist-specific options not preprocessed in wrapper
												// (this version does not yet have pre-processing of multi-varlists)

	local wtexp = word("`exp'",2)							// Weight expression
  
	if `limitdiag'==-1  local limitdiag = .					// User wants unlimitd diagnostcs, make that a very big number!	** 

	if "`context'"==""  local nocontexts = "nocontexts"		// Change polarity to match legacy conventions
	if "`stackid'"==""  local nostacks = "nostacks"
	if "`weight'" !=""  local weight = "[`weight'=`exp']"	// Establish weight directive, if present
												
	local count = `c'										// Count of contexts processed, as basis for limitdiag & initializtn


	
	if `count'==1  {										// Put required stats & correspondng statvars into globals
		global prfxlist = ""								//  (only for first context)
		global stats = ""
		global sum = ""
		global detail = ""

		local 0 = ", `stats'"								// Local 0 is where syntx commnd expects to find user's command line
	
		syntax , [ N MEAn SD MIN MAX SKEwness KURtosis SUM SW MEDian MODe ] // Command syntax reduces this list to those optiond
		
		local s0 = lower("N MEAn SD MIN MAX SKEwness KURtosis SUM SW MEDian MODe")
		local s2 =       "n mn   sd mi  ma  sk       ku       su  sw me     mo " // Line up corresponding prefix initials

		local s1 = strltrim(stritrim(strrtrim("`n' `mean' `sd' `min' `max' `skewness' `kurtosis' `sum' `sw' `median' `mode'")))
															// Put list of stats actually optioned into `s1', trimmed of blanks
		foreach s of local s1  {							// Cycle thru list of expandd optiond stats, make `s' = each in turn
			local i = strpos("`s0'","`s'")					// Record char # of start of `s' in option-list'

			local s3 = strrtrim(substr("`s2'",`i', 2))		// Record 2-char default prefix for calculated stat in `prfx'
			local statprefix = "`s3'prefix"
			if "``statprefix''"=="" local `statprefix' = "`s3'_" // Replace missing prefix with default
			global prfxlist = "$prfxlist ``statprefix''"		 // Append to $prfxlist in same position as s
*			foreach var of varlist sumvars  {				// Initialize output vars as missing
*				gen `prfx'`var' = .							// (not needed since `prfx'`var' is not yet present in any `c')
*			}
			if (`i'==6|`i'==7)  global detail = "detail" 	// Need 'summarize , detail' if stat is skew or kurtosis
			if `i'<10 global sum = "summarize"
		} //next s
		
		if strpos("`s1'", "sw")>0  {						// If optioned stats include sum of weights
			local i = strpos("`s1'", "sw")					// Then replace the abbreviation with the stata r-return name
			global stats = substr("`s1'",1,`i'-1) + "sum_w " + substr("`s1'", `i'+3, .)
		}
		else global stats = "`s1'"							// Otherwise transfer `s1' back into $stats unchanged

	} //endif `count'==1
	
	
															
	
	
											// Calculate all optioned stats

	if "$sum"!="" & "$detail"!=""  quietly summarize `cmdvars' [`weight'], detail
	else if "$sum"!=""  quietly summarize `cmdvars' `weight'
	
	local i = 0
	foreach s of global stats  {
		local i = `i'+1
		local prfx = word("$prfxlist", `i')
		foreach var of varlist `cmdvars'  {
			if "`s'"!="median" & "`s'"!="mode"  {			
				gen `prfx'`var' = r(`s')	
			}
			if "`s'"=="median"  quietly egen `prfx'`var' = median(`var')
			if "`s'"=="mode"  quietly egen `prfx'`var' = mode(`var')
		}
	}
	
	
											// Empty globals after final context has been processed
										
	if `c'==`nc'  {
		global prefixlist = ""
		global stats = ""
		global sum = ""
		global detail = ""
	}
	
set trace off

end genstatsP


