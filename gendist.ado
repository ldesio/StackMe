
program define gendummies

	version 9.0										// gendummies version 0.92, June 2022
	
	// This program is a front-end for what used to be gendummies (now gendummiesP), calling gendummiesP once 
	// for each user-supplied varname, those varname(s) being optionally prefixed by a reference variable that 
	// effectively (re-)defines the `stub' option (stub variable) for the varlist). The 'stub' option can still 
	// be used (applying to varlist containing just one varname), for conformity with previous versions of 
	// gendummies.
	
	// In the absence of a stub prefix (or option in the single-variable syntax) then such variable(s) become   
	// the stub(s) for the dummies that it generates. 
	
	
	
												// Command line is in `0'
	gettoken anything postcomma : 0, parse(",")						// Put everything from "," into `postcomma'
	
	
	if ((strpos("`postcomma'","pre")>0) & (wordcount("`anything'"))>1)  {
		display as error "'prefix' option may not accompany multi-variable varlist"
		exit										// Legacy command format may not be mixed with new format
	}
	
/*	if substr("`postcomma'",1,1) != ","  {
		display as error("Need list of options, starting with comma")
		exit										// Not the case for gendummies
	}
*/	
	local options = "`postcomma'"								// Save `options', if any, for use with each varlist
	if substr("`options'",1,1)=="," local options = substr("`options'",2,.) // strip comma from front of `options'
	local optionsT = "`options'"								// Temp version will be sent on to gendummiesP

	
	// Prepare to process each varlist in turn by repeatedly calling gendistP (the original program)
	
	if (strpos("`anything'", "||")>0) { 							// If `anything' has pipes
		display as error "Piped syntax (using '||') not appropriate for gendummies" _newline
		exit
	} 
	
	while strpos("`anything'","  ")>0  {
		subinstr("`anything'","  "," ",.)						// Change any occurrences of double space to single
	}											// Repeat, removing any triple-spaces, etc.


	
	while ("`anything'" != "")  {								// While varnames remain in `anything'
		
		if (substr("`anything'",1,1)==" ")  local anything = substr("`anything'",2,.)	// Strip leading " " if any
		
		gettoken nextword anything:anything						// Remainder of 'anything' stays untouched until next loop	
		

		
		gettoken precolon varname:nextword, parse(":")					// Now focus on current variable (and possible prefix)
		
		if (substr("`varname'",1,1)==":")	 {					// Got a colon before 'varname'
			local varname = substr("`varname'",2,.)					// Strip it from start of 'varname'
			if "`precolon'"==""  {
				display as error "Need stubname before colon"
				exit
			}

			else  {									//'precolon' is not empty
				local thisStub = "`precolon'"
				if "`thisStub'"!=""  {						// 'thisStub' is not empty
					if (strpos("`options'","stu")> 0)  {			// Was it also specified as an option?
						display as error "Cannot option {bf:stubname} if also have a pre-colon stub"
						exit
					}	
					else  { 						// Use 'optionsT', leaving `options' unchanged for next var(list)
						local optionsT = "`options'"+" prefix("+"`thisStub'"+")" // Pretend the prefix was an option
					} //endelse
				} //endif				
			} //endelse
		}	
		else  {										// There was no colon, so this 'nextword' has unprefixed varname
			local varname = "`nextword'"						// Put it where it would have been had there been a colon
		}




		gendummiesP `varname', `optionsT' 						// Call gendummies once for each var in varlist
		
		local optionsT = "`options'"							// Replace with user-chosen options before processing
												//  next variable, if any

	} //next word of 'anything'	
	

	display _newline "done."
		
end








capture program drop gendummiesP

program define gendummiesP

	version 9.0												// GendummiesP version 0.92 (was 'gendummies' previously)
	syntax varlist, [PREfix(name)] [INCludemissing]
	
	local varname = "`varlist'"

	confirm numeric variable `varname'
	quietly levelsof `varname', local(values)
		
	local thePrefix = "`varname'"
	if ("`prefix'"!="") {
		local thePrefix = "`prefix'"
	}


	foreach v in `values' {
		//display `v'
		capture drop `thePrefix'`v'
		gen `thePrefix'`v' = (`varname'==`v')
		
		local labellist : value label `varname'
		local label : label (`varname') `v'
		
		label variable `thePrefix'`v' "`varname'==`v' `label'"
		
		
		if ("`includemissing'"=="includemissing") {
			foreach var of varlist `thePrefix'* {
				if ("`var'"!="`varname'") {
					qui replace `thePrefix'`v' = 0 if `varname'>=.
				}
			}
		}
		else {
			qui replace `thePrefix'`v'=. if `varname'>=.
		}
	}

end
	
	
