capture program drop gendist

program define gendist

	version 9.0

*set trace on


	gettoken anything options : 0, parse(",")				// Put everything from "," into `options'

	if strrpos("`anything'"," if")>0  {						// See if there is an 'if' component
		local anything = substr("`anything'",1,strrpos("`anything'"," if"))
		local if=substr("`anything'",strrpos("`anything'"," if"),.)	// `if' string will be passed to gendistP
	}
	if substr("`options'",1,1) != ","  {
		display as error("Need list of options, starting with comma")
		exit
	}
	
	// Process complex varlist syntax in preparation for processing each varlist in turn by calling gendistP (the original program)
	
	local pipedsyntax = 0
	
	if (strpos("`anything'",":")!=0 | strpos("`anything'","||")!=0) {
		local pipedsyntax = 1
	} 
	else {
		local thisRef = "`respondent'"						// Use `respondent' as reference if not pipedsyntax
		local varlist
		foreach var of varlist `anything' {
			local varlist `varlist' `var'
		}
	}
	
	display ".." _continue

	while ("`anything'" != "")  {
		
		if (`pipedsyntax'==1) {								// Here we process next segment of quasi-varlist
		
			gettoken string : anything, parse("||")		 	// 'string' gets all up to "||" or to end of anything
															//  (anything)
			//display "{pstd}{text}"

			//display "Processing {bf:`string'}:{break}"
			if (strpos("`string'",":")==0) {				// No colon in this segment
				local thisRef = "`respondent'"				// Use `respondent' as reference if no colon
				local varlist `string'
				}
			else {
				// colon
				gettoken thisRef postcolon: string, parse(": ") 
				gettoken varlist: postcolon, parse("||") 	// Previously up to ": " actually to end of segment
			}
		} 		
		else local anything	= ""							// Just one varlist so empty `anything'
		
		if "`thisResp'"==""&strpos("`options'","res")==0  { // Only need check for 1st 3 chars of 'respondent'
			display as error "{pstd}{text}Need a reference variable in option {bf:respondent}."
			exit
		}													// Only now do we know if there is a reference prefix
		
		gendistP `varlist' `if' `options'					// `options' starts with a comma
		

	} // next pipe-delimited varlist, if any
	
	
	  // Remove following from gendistP since they are executed only following the last call on gendistP

	display ""
	display "done."
	
end	

capture program drop createImputedCopy
program define createImputedCopy
	version 9.0
	syntax varname, type(string) imputeprefix(name)
	
	capture drop `imputeprefix'`varlist'
	quietly clonevar `imputeprefix'`varlist' = `varlist' 
	local varlab : variable label `varlist'
	local newlab = "* MEAN-PLUGGED (`type') * " + "`varlab'"
	label variable `imputeprefix'`varlist' "`newlab'"
	
end

capture program drop gendistP
program define gendistP
	version 9.0
	
	syntax varlist(min=1), [CONtextvars(varlist)] [PPRefix(name)] [DPRefix(name)] RESpondent(varname) [MISsing(string)] [ROUnd] [REPlace] [MPRefix(name)] [MCOuntname(name)] [MPLuggedcountname(name)] [STAckid(varname)] [NOStacks] [DROpmissing]

	if ("`missing'"=="" & "`pprefix'"!="") {
		display "{text}{pstd}ERROR: the {bf:missing} option was not specified, thus the {bf:pprefix} option is illegal."
		exit
	}
	
	local imputePref = "p_"
	if ("`pprefix'"!="") {
		local imputePref = "`pprefix'"
	}
	
	local distPref = "d_"
	if ("`dprefix'"!="") {
		local distPref = "`dprefix'"
	}
	
	local missingFlagPref = "m_"
	if ("`mprefix'"!="") {
		local missingFlagPref = "`mprefix'"
	}
	
	local missingCntName = "_gendist_mc"
	if ("`mcountname'"!="") {
		local missingCntName = "`mcountname'"
	}
	
	local missingImpCntName = "_gendist_mpc"
	if ("`mpluggedcountname'"!="") {
		local missingImpCntName = "`mpluggedcountname'"
	}
	
	local nvars : list sizeof varlist
	
	tokenize `varlist'
    	local first `1'
	local last ``nvars''

	noisily display "." _continue
	
	if ("`missing'"!="") {
		capture drop `missingCntName'
		capture label drop `missingCntName'
		quietly egen `missingCntName' = rowmiss(`varlist')
		capture label var `missingCntName' "N of missing values in `nvars' variables to impute (`first'...`last')"

		capture drop `missingImpCntName'
		capture label drop `missingImpCntName'
		capture label var `missingImpCntName' "N of missing values in mean-plugged versions of `nvars' variables (`first'...`last')"

		local imputedvars = ""

		foreach var of varlist `varlist' {
			capture drop `missingFlagPref'`var'
			quietly generate `missingFlagPref'`var' = missing(`var')
			capture label var `missingFlagPref'`var' "Was `var' originally missing?"
			local imputedvars = "`imputedvars' `imputePref'`var'"

		}
	}
	noisily display "." _continue

	capture drop _ctx_temp
	capture label drop _ctx_temp


	if ("`stackid'" != "") & ("`nostacks'" == "") {
		local thisCtxVars = "`contextvars' `stackid'"
	}
	else {
		local thisCtxVars = "`contextvars'"
	}
	
	if ("`thisCtxVars'" == "") {
		gen _ctx_temp = 1
		local ctxvar = "_ctx_temp"
	}
	else {
		quietly _mkcross `thisCtxVars', generate(_ctx_temp) missing
		local ctxvar = "_ctx_temp"
	}
	
	
	/* old naming too verbose
	
	if ("`missing'"!="") {
		local fullDistancePref = "`imputePref'`distPref'`respondent'_"
	}
	else {
		local fullDistancePref = "`distPref'`respondent'_"
	}
	*/
	local fullDistancePref = "`distPref'"
	
	
	
	// loads all values of the context variable
	quietly levelsof `ctxvar', local(contexts)
	
	display in smcl
	display as text
	display "{pstd}{text}Computing distances between R's position ({result:`respondent'}){break}"
	display "and her placement of different objects: {result:`varlist'}"
	display ""

	// create imputed copies first
	if ("`missing'"!="") {
		foreach var of varlist `varlist' {
			createImputedCopy `var', type("`missing'") imputeprefix("`imputePref'")
		}
	}

	noisily display "." _continue

	// create empty variables regardless of context
	if ("`missing'"!="") {
		foreach var of varlist `varlist' {
			capture drop `fullDistancePref'`var'
			capture quietly gen `fullDistancePref'`var' = .
			local newlab = "Euclidean distance between `respondent' and `imputePref'`var'"
			label variable `fullDistancePref'`var' "`newlab'"
		}
	} 
	else {
		foreach var of varlist `varlist' {
			capture drop `fullDistancePref'`var'
			capture quietly gen `fullDistancePref'`var' = .
			local newlab = "Euclidean distance between `respondent' and `var'"
			label variable `fullDistancePref'`var' "`newlab'"
		}
	}
		
	//display "{text}{pstd}"
	sort `ctxvar'										// Preparatory to 'statsby:'

*	display "{text}{pstd}Context {result:`context'}: Generating " _continue

	foreach var of varlist `varlist' {
		noisily display "." _continue

		preserve
		quietly {	
		if ("`missing'"=="mean") statsby theMean=r(mean)   /* if */								, 	///
			by(_ctx_temp) clear nodots nolegend: summarize `imputePref'`var'
				
		else if ("`missing'"=="same") statsby theMean=r(mean) if `respondent'==`imputePref'`var',	///
			by(_ctx_temp) clear nodots nolegend: summarize `imputePref'`var'
				
		else if ("`missing'"=="diff") statsby theMean=r(mean) if `respondent'!=`imputePref'`var',	///
			by(_ctx_temp) clear nodots nolegend: summarize `imputePref'`var'
			
		else  {
			statsby theMean=r(mean), by(_ctx_temp) clear nodots nolegend: summarize `imputePref'`var'
			capture replace `fullDistancePref'`var' = abs(`var' - `respondent')
			display "{result:`fullDistancePref'`var'}... " _continue
			continue, break
		}
		capture frame drop stats
		frame put _ctx_temp theMean, into(stats)
				
		restore
		frlink m:1 _ctx_temp, frame(stats)
		frget theMean, from(stats)
		frame drop stats
				
		if ("`round'"=="round") replace theMean = round(theMean)
				
		capture replace `imputePref'`var' = theMean if `imputePref'`var'==. 
		capture replace `fullDistancePref'`var' = abs(`imputePref'`var' - `respondent')
				
		display "{result:`imputePref'`var'},{result:`fullDistancePref'`var'}... " _continue
		
		drop stats theMean
		} // end quietly

	} // next `var'

	noisily display " "
	
	if ("`missing'"!="") {
		quietly egen `missingImpCntName' = rowmiss(`imputedvars')
	} 
	
	if ("`replace'" != "") {
		capture drop `varlist'
	}

	if ("`dropmissing'"!="") {
		capture drop `missingFlagPref'*
		capture drop `imputePref'*
	}
	
	capture drop _ctx_temp
	capture label drop _ctx_temp

	
end	

